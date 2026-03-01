import http from "node:http";
import { randomUUID } from "node:crypto";

const env = process.env;

const HOST = env.HOST || "127.0.0.1";
const PORT = Number(env.PORT || 8787);
const BRIDGE_API_KEY = env.BRIDGE_API_KEY || "";
const OPENAI_MODEL_ID = env.OPENAI_MODEL_ID || "opencode-local";
const OPENCODE_BASE_URL = (env.OPENCODE_BASE_URL || "http://127.0.0.1:4096").replace(/\/+$/, "");
const OPENCODE_AUTH_MODE = (env.OPENCODE_AUTH_MODE || "basic").toLowerCase();
const OPENCODE_AUTH_USERNAME = env.OPENCODE_AUTH_USERNAME || "opencode";
const OPENCODE_AUTH_PASSWORD = env.OPENCODE_AUTH_PASSWORD || env.OPENCODE_SERVER_PASSWORD || "";
const OPENCODE_DIRECTORY = env.OPENCODE_DIRECTORY || "";
const DEFAULT_PROVIDER_ID = env.OPENCODE_PROVIDER_ID || "";
const DEFAULT_MODEL_ID = env.OPENCODE_MODEL_ID || "";
const DEFAULT_AGENT = env.OPENCODE_AGENT || "";
const DEFAULT_SYSTEM = env.OPENCODE_SYSTEM || "";
const OPENCODE_SESSION_TIMEOUT_MS = Number(env.OPENCODE_SESSION_TIMEOUT_MS || 15000);
const OPENCODE_MESSAGE_TIMEOUT_MS = Number(env.OPENCODE_MESSAGE_TIMEOUT_MS || 60000);
const OPENCODE_RETRY_COUNT = Number(env.OPENCODE_RETRY_COUNT || 1);
const OPENCODE_RETRY_DELAY_MS = Number(env.OPENCODE_RETRY_DELAY_MS || 750);

let modelMap = {};
if (env.MODEL_MAP_JSON) {
  try {
    modelMap = JSON.parse(env.MODEL_MAP_JSON);
  } catch (error) {
    console.error("Invalid MODEL_MAP_JSON:", error.message);
    process.exit(1);
  }
}

function json(res, status, body) {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(text),
  });
  res.end(text);
}

function sse(res) {
  res.writeHead(200, {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no",
  });
}

function readBody(req, maxBytes = 2 * 1024 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        reject(new Error("Request body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      resolve(Buffer.concat(chunks).toString("utf8"));
    });
    req.on("error", reject);
  });
}

function unauthorized(res, message = "Unauthorized") {
  return json(res, 401, { error: { message, type: "invalid_request_error" } });
}

function requireBridgeAuth(req, res) {
  if (!BRIDGE_API_KEY) return true;
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (token !== BRIDGE_API_KEY) {
    unauthorized(res);
    return false;
  }
  return true;
}

function opencodeHeaders(extra = {}) {
  const headers = { ...extra };
  if (OPENCODE_AUTH_PASSWORD) {
    if (OPENCODE_AUTH_MODE === "bearer") {
      headers.Authorization = `Bearer ${OPENCODE_AUTH_PASSWORD}`;
    } else if (OPENCODE_AUTH_MODE === "basic") {
      const raw = `${OPENCODE_AUTH_USERNAME}:${OPENCODE_AUTH_PASSWORD}`;
      headers.Authorization = `Basic ${Buffer.from(raw, "utf8").toString("base64")}`;
    }
  }
  return headers;
}

function opencodeUrl(pathname) {
  const url = new URL(pathname, `${OPENCODE_BASE_URL}/`);
  if (OPENCODE_DIRECTORY) {
    url.searchParams.set("directory", OPENCODE_DIRECTORY);
  }
  return url;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseResponseBody(text) {
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  return data;
}

function isAbortLikeError(error) {
  return error?.name === "AbortError" || error?.code === "ABORT_ERR";
}

async function opencodeFetch(pathname, init = {}, options = {}) {
  const timeoutMs = Number(options.timeoutMs) > 0 ? Number(options.timeoutMs) : 0;
  const controller = timeoutMs > 0 ? new AbortController() : null;
  const timer = controller ? setTimeout(() => controller.abort(), timeoutMs) : null;

  let res;
  try {
    res = await fetch(opencodeUrl(pathname), {
      ...init,
      headers: opencodeHeaders(init.headers || {}),
      signal: controller ? controller.signal : init.signal,
    });
  } catch (error) {
    if (timer) clearTimeout(timer);
    if (isAbortLikeError(error)) {
      const timeoutError = new Error(`opencode timeout after ${timeoutMs}ms`);
      timeoutError.status = 504;
      timeoutError.code = "OPENCODE_TIMEOUT";
      throw timeoutError;
    }
    throw error;
  }
  let text;
  try {
    text = await res.text();
  } catch (error) {
    if (timer) clearTimeout(timer);
    if (isAbortLikeError(error)) {
      const timeoutError = new Error(`opencode timeout after ${timeoutMs}ms`);
      timeoutError.status = 504;
      timeoutError.code = "OPENCODE_TIMEOUT";
      throw timeoutError;
    }
    throw error;
  }
  if (timer) clearTimeout(timer);
  const data = parseResponseBody(text);
  if (!res.ok) {
    const msg =
      (data && typeof data === "object" && (data.message || data.error?.message)) ||
      `opencode error ${res.status}`;
    const error = new Error(msg);
    error.status = res.status;
    error.payload = data;
    throw error;
  }
  return data;
}

function textFromOpenAIContent(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((part) => {
      if (!part || typeof part !== "object") return "";
      if (part.type === "text") return part.text || "";
      if (part.type === "input_text") return part.text || "";
      return "";
    })
    .filter(Boolean)
    .join("\n");
}

function buildPromptFromMessages(messages) {
  const lines = [];
  const systemLines = [];

  for (const msg of messages || []) {
    if (!msg || typeof msg !== "object") continue;
    const role = String(msg.role || "user");
    const text = textFromOpenAIContent(msg.content);
    if (!text) continue;
    if (role === "system") {
      systemLines.push(text);
      continue;
    }
    const label = role.toUpperCase();
    lines.push(`${label}:\n${text}`);
  }

  return {
    prompt: lines.join("\n\n"),
    system: systemLines.join("\n\n").trim(),
  };
}

function resolveOpencodeModel(openaiModel) {
  if (openaiModel && modelMap[openaiModel]) return modelMap[openaiModel];

  if (openaiModel && typeof openaiModel === "string") {
    if (openaiModel.includes("/")) {
      const [providerID, ...rest] = openaiModel.split("/");
      if (providerID && rest.length) {
        return { providerID, modelID: rest.join("/") };
      }
    }
    if (openaiModel.includes(":")) {
      const [providerID, ...rest] = openaiModel.split(":");
      if (providerID && rest.length) {
        return { providerID, modelID: rest.join(":") };
      }
    }
  }

  if (DEFAULT_PROVIDER_ID && DEFAULT_MODEL_ID) {
    return { providerID: DEFAULT_PROVIDER_ID, modelID: DEFAULT_MODEL_ID };
  }
  return null;
}

function extractAssistantText(opencodeResponse) {
  const parts = Array.isArray(opencodeResponse?.parts) ? opencodeResponse.parts : [];
  return parts
    .filter((p) => p && p.type === "text" && typeof p.text === "string")
    .map((p) => p.text)
    .join("");
}

function summarizePartTypes(opencodeResponse) {
  const parts = Array.isArray(opencodeResponse?.parts) ? opencodeResponse.parts : [];
  return parts
    .map((part) => (part && typeof part === "object" && part.type ? String(part.type) : "unknown"))
    .filter(Boolean);
}

function toOpenAICompletion({ reqBody, content, usage }) {
  const now = Math.floor(Date.now() / 1000);
  return {
    id: `chatcmpl-${randomUUID()}`,
    object: "chat.completion",
    created: now,
    model: reqBody.model || OPENAI_MODEL_ID,
    choices: [
      {
        index: 0,
        message: {
          role: "assistant",
          content,
        },
        finish_reason: "stop",
      },
    ],
    usage: {
      prompt_tokens: usage?.input ?? 0,
      completion_tokens: usage?.output ?? 0,
      total_tokens: (usage?.input ?? 0) + (usage?.output ?? 0),
    },
  };
}

function writeOpenAIStream(res, reqBody, content) {
  sse(res);
  const id = `chatcmpl-${randomUUID()}`;
  const created = Math.floor(Date.now() / 1000);
  const model = reqBody.model || OPENAI_MODEL_ID;

  const chunk1 = {
    id,
    object: "chat.completion.chunk",
    created,
    model,
    choices: [{ index: 0, delta: { role: "assistant" }, finish_reason: null }],
  };
  res.write(`data: ${JSON.stringify(chunk1)}\n\n`);

  if (content) {
    const chunk2 = {
      id,
      object: "chat.completion.chunk",
      created,
      model,
      choices: [{ index: 0, delta: { content }, finish_reason: null }],
    };
    res.write(`data: ${JSON.stringify(chunk2)}\n\n`);
  }

  const chunk3 = {
    id,
    object: "chat.completion.chunk",
    created,
    model,
    choices: [{ index: 0, delta: {}, finish_reason: "stop" }],
  };
  res.write(`data: ${JSON.stringify(chunk3)}\n\n`);
  res.write("data: [DONE]\n\n");
  res.end();
}

async function createAndPromptOpencode(reqBody) {
  const messages = Array.isArray(reqBody.messages) ? reqBody.messages : [];
  if (!messages.length) {
    const error = new Error("messages is required");
    error.status = 400;
    throw error;
  }

  const resolvedModel = resolveOpencodeModel(reqBody.model);
  const { prompt, system } = buildPromptFromMessages(messages);
  if (!prompt.trim()) {
    const error = new Error("No usable text found in messages");
    error.status = 400;
    throw error;
  }

  const session = await opencodeFetch("/session", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "openclaw-bridge" }),
  }, {
    timeoutMs: OPENCODE_SESSION_TIMEOUT_MS,
  });

  const body = {
    parts: [{ type: "text", text: prompt }],
  };
  if (resolvedModel) body.model = resolvedModel;
  if (DEFAULT_AGENT) body.agent = DEFAULT_AGENT;
  if (DEFAULT_SYSTEM || system) body.system = [DEFAULT_SYSTEM, system].filter(Boolean).join("\n\n");

  const response = await opencodeFetch(`/session/${encodeURIComponent(session.id)}/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }, {
    timeoutMs: OPENCODE_MESSAGE_TIMEOUT_MS,
  });

  return response;
}

function shouldRetryOpencodeError(error) {
  const status = Number(error?.status) || 0;
  if (error?.code === "OPENCODE_TIMEOUT") return false;
  return status === 408 || status === 429 || status >= 500;
}

async function createAndPromptOpencodeWithRetry(reqBody) {
  const maxAttempts = Math.max(1, OPENCODE_RETRY_COUNT + 1);
  let lastError = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const opencodeResp = await createAndPromptOpencode(reqBody);
      const content = extractAssistantText(opencodeResp);
      if (content && content.trim()) {
        return {
          opencodeResp,
          content,
          usage: opencodeResp?.info?.tokens,
        };
      }

      const error = new Error("Model returned no assistant text");
      error.status = 502;
      error.code = "EMPTY_ASSISTANT_TEXT";
      error.payload = {
        finish: opencodeResp?.info?.finish || null,
        partTypes: summarizePartTypes(opencodeResp),
      };
      throw error;
    } catch (error) {
      lastError = error;
      const canRetry = attempt < maxAttempts && (error.code === "EMPTY_ASSISTANT_TEXT" || shouldRetryOpencodeError(error));
      if (!canRetry) break;
      console.warn(
        `[bridge] retrying opencode request attempt=${attempt + 1}/${maxAttempts} reason=${error.code || error.message}`,
      );
      if (OPENCODE_RETRY_DELAY_MS > 0) {
        await sleep(OPENCODE_RETRY_DELAY_MS);
      }
    }
  }

  throw lastError;
}

async function handleChatCompletions(req, res) {
  if (!requireBridgeAuth(req, res)) return;

  let reqBody;
  try {
    const raw = await readBody(req);
    reqBody = raw ? JSON.parse(raw) : {};
  } catch (error) {
    return json(res, 400, { error: { message: error.message, type: "invalid_request_error" } });
  }

  try {
    const { content, usage } = await createAndPromptOpencodeWithRetry(reqBody);

    if (reqBody.stream) {
      return writeOpenAIStream(res, reqBody, content);
    }
    return json(res, 200, toOpenAICompletion({ reqBody, content, usage }));
  } catch (error) {
    const status = Number(error.status) || 500;
    return json(res, status, {
      error: {
        message: error.message || "Internal error",
        type: status >= 500 ? "server_error" : "invalid_request_error",
        details: error.payload || undefined,
      },
    });
  }
}

function handleModels(req, res) {
  if (!requireBridgeAuth(req, res)) return;
  const model = {
    id: OPENAI_MODEL_ID,
    object: "model",
    created: 0,
    owned_by: "opencode-bridge",
  };
  return json(res, 200, { object: "list", data: [model] });
}

function handleHealth(res) {
  return json(res, 200, {
    ok: true,
    service: "openclaw-opencode-bridge",
    opencodeBaseUrl: OPENCODE_BASE_URL,
    model: OPENAI_MODEL_ID,
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

  try {
    if (req.method === "GET" && url.pathname === "/health") {
      return handleHealth(res);
    }
    if (req.method === "GET" && url.pathname === "/v1/models") {
      return handleModels(req, res);
    }
    if (req.method === "POST" && url.pathname === "/v1/chat/completions") {
      return handleChatCompletions(req, res);
    }
    return json(res, 404, { error: { message: "Not found" } });
  } catch (error) {
    console.error("Unhandled error:", error);
    return json(res, 500, { error: { message: "Internal server error" } });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`openclaw-opencode-bridge listening on http://${HOST}:${PORT}`);
  console.log(`opencode base: ${OPENCODE_BASE_URL}`);
});
