#!/usr/bin/env node

import http from "node:http";
import os from "node:os";
import { execFile } from "node:child_process";

const HOST = process.env.HOST_AUTOMATION_HOST || "127.0.0.1";
const PORT = Number(process.env.HOST_AUTOMATION_PORT || 4567);
const MODE = (process.env.HOST_AUTOMATION_MODE || "read-only").toLowerCase();
const TOKEN = process.env.HOST_AUTOMATION_TOKEN || "";
const ALLOW_SCREENSHOT = /^(1|true|yes)$/i.test(process.env.HOST_AUTOMATION_ALLOW_SCREENSHOT || "");
const BODY_LIMIT_BYTES = 256 * 1024;

const CHROME_FAMILY_APPS = new Set([
  "Google Chrome",
  "Chromium",
  "Brave Browser",
  "Microsoft Edge",
]);

function json(res, status, body) {
  const text = JSON.stringify(body, null, 2);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(text),
  });
  res.end(text);
}

function requireAuth(req, res, url) {
  if (!TOKEN) return true;
  const auth = req.headers.authorization || "";
  const bearerToken = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  const queryToken = url.searchParams.get("token") || "";
  if (bearerToken !== TOKEN && queryToken !== TOKEN) {
    json(res, 401, {
      error: {
        message: "Unauthorized",
        type: "invalid_request_error",
      },
    });
    return false;
  }
  return true;
}

function isMac() {
  return process.platform === "darwin";
}

function modeAtLeast(target) {
  const levels = {
    "read-only": 0,
    "browser-write": 1,
    "desktop-write": 2,
    "system-write": 3,
  };
  return (levels[MODE] ?? 0) >= (levels[target] ?? 0);
}

function canBrowserWrite() {
  return modeAtLeast("browser-write");
}

function appleScriptString(value) {
  return `"${String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n")}"`;
}

function readBody(req, maxBytes = BODY_LIMIT_BYTES) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        const error = new Error("Request body too large");
        error.status = 413;
        reject(error);
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

async function readJsonBody(req) {
  const raw = await readBody(req);
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw);
  } catch {
    const error = new Error("Invalid JSON body");
    error.status = 400;
    throw error;
  }
}

function execFileText(file, args, options = {}) {
  return new Promise((resolve, reject) => {
    execFile(
      file,
      args,
      {
        timeout: options.timeout ?? 5000,
        maxBuffer: options.maxBuffer ?? 1024 * 1024,
        encoding: "utf8",
      },
      (error, stdout, stderr) => {
        if (error) {
          error.stderr = stderr;
          reject(error);
          return;
        }
        resolve(String(stdout || "").trim());
      },
    );
  });
}

function execFileBuffer(file, args, options = {}) {
  return new Promise((resolve, reject) => {
    execFile(
      file,
      args,
      {
        timeout: options.timeout ?? 8000,
        maxBuffer: options.maxBuffer ?? 20 * 1024 * 1024,
        encoding: "buffer",
      },
      (error, stdout, stderr) => {
        if (error) {
          error.stderr = Buffer.isBuffer(stderr) ? stderr.toString("utf8") : String(stderr || "");
          reject(error);
          return;
        }
        resolve(Buffer.isBuffer(stdout) ? stdout : Buffer.from(stdout || ""));
      },
    );
  });
}

async function runAppleScript(lines) {
  if (!isMac()) {
    const error = new Error("macOS-only endpoint");
    error.status = 501;
    throw error;
  }
  const args = [];
  for (const line of lines) {
    args.push("-e", line);
  }
  return execFileText("/usr/bin/osascript", args);
}

function parseCsvLine(raw) {
  if (!raw) return [];
  return raw
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

async function getMacVersion() {
  if (!isMac()) return null;
  try {
    const productName = await execFileText("/usr/bin/sw_vers", ["-productName"]);
    const productVersion = await execFileText("/usr/bin/sw_vers", ["-productVersion"]);
    const buildVersion = await execFileText("/usr/bin/sw_vers", ["-buildVersion"]);
    return { productName, productVersion, buildVersion };
  } catch {
    return null;
  }
}

async function listVisibleApps() {
  if (!isMac()) return [];
  const raw = await runAppleScript([
    'tell application "System Events" to get name of every application process whose background only is false',
  ]);
  return parseCsvLine(raw);
}

async function getFrontmostWindow() {
  if (!isMac()) {
    return {
      appName: null,
      windowTitle: null,
    };
  }

  const raw = await runAppleScript([
    'tell application "System Events"',
    'set frontApp to name of first process whose frontmost is true',
    'set windowTitle to ""',
    'tell process frontApp',
    'if (count of windows) > 0 then set windowTitle to name of front window',
    'end tell',
    'return frontApp & linefeed & windowTitle',
    'end tell',
  ]);

  const [appName = "", windowTitle = ""] = raw.split(/\r?\n/);
  return {
    appName: appName.trim() || null,
    windowTitle: windowTitle.trim() || null,
  };
}

function browserForQuery(url) {
  const app = url.searchParams.get("app");
  if (app) return app;
  return null;
}

function pickBrowserApp(preferredApp) {
  if (preferredApp) return preferredApp;
  return "Google Chrome";
}

async function getBrowserFrontmost() {
  const { appName, windowTitle } = await getFrontmostWindow();
  if (!appName) {
    return {
      appName: null,
      windowTitle,
      activeTab: null,
      supported: false,
    };
  }

  if (CHROME_FAMILY_APPS.has(appName)) {
    const raw = await runAppleScript([
      `if application "${appName}" is running then`,
      `tell application "${appName}"`,
      'if (count of windows) > 0 then',
      'set tabTitle to title of active tab of front window',
      'set tabUrl to URL of active tab of front window',
      'return tabTitle & linefeed & tabUrl',
      'end if',
      'end tell',
      'end if',
      'return ""',
    ]);
    const [title = "", currentUrl = ""] = raw.split(/\r?\n/);
    return {
      appName,
      windowTitle,
      supported: true,
      activeTab: {
        title: title.trim() || null,
        url: currentUrl.trim() || null,
      },
    };
  }

  if (appName === "Safari") {
    const raw = await runAppleScript([
      'if application "Safari" is running then',
      'tell application "Safari"',
      'if (count of windows) > 0 then',
      'set tabTitle to name of current tab of front window',
      'set tabUrl to URL of current tab of front window',
      'return tabTitle & linefeed & tabUrl',
      'end if',
      'end tell',
      'end if',
      'return ""',
    ]);
    const [title = "", currentUrl = ""] = raw.split(/\r?\n/);
    return {
      appName,
      windowTitle,
      supported: true,
      activeTab: {
        title: title.trim() || null,
        url: currentUrl.trim() || null,
      },
    };
  }

  return {
    appName,
    windowTitle,
    activeTab: null,
    supported: false,
  };
}

async function listBrowserTabs(appName) {
  if (!appName) {
    const current = await getBrowserFrontmost();
    appName = current.appName;
  }

  if (!appName) {
    return {
      appName: null,
      supported: false,
      tabs: [],
    };
  }

  if (CHROME_FAMILY_APPS.has(appName)) {
    const raw = await runAppleScript([
      `if application "${appName}" is running then`,
      `tell application "${appName}"`,
      'set outputLines to ""',
      'repeat with windowIndex from 1 to count of windows',
      'repeat with tabIndex from 1 to count of tabs of window windowIndex',
      'set tabTitle to title of tab tabIndex of window windowIndex',
      'set tabUrl to URL of tab tabIndex of window windowIndex',
      'set outputLines to outputLines & windowIndex & "|||" & tabIndex & "|||" & tabTitle & "|||" & tabUrl & linefeed',
      'end repeat',
      'end repeat',
      'return outputLines',
      'end tell',
      'end if',
      'return ""',
    ]);

    return {
      appName,
      supported: true,
      tabs: raw
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => {
          const [windowIndex, tabIndex, title, url] = line.split("|||");
          return {
            windowIndex: Number(windowIndex),
            tabIndex: Number(tabIndex),
            title: title || null,
            url: url || null,
          };
        }),
    };
  }

  if (appName === "Safari") {
    const raw = await runAppleScript([
      'if application "Safari" is running then',
      'tell application "Safari"',
      'set outputLines to ""',
      'repeat with windowIndex from 1 to count of windows',
      'repeat with tabIndex from 1 to count of tabs of window windowIndex',
      'set tabTitle to name of tab tabIndex of window windowIndex',
      'set tabUrl to URL of tab tabIndex of window windowIndex',
      'set outputLines to outputLines & windowIndex & "|||" & tabIndex & "|||" & tabTitle & "|||" & tabUrl & linefeed',
      'end repeat',
      'end repeat',
      'return outputLines',
      'end tell',
      'end if',
      'return ""',
    ]);

    return {
      appName,
      supported: true,
      tabs: raw
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => {
          const [windowIndex, tabIndex, title, url] = line.split("|||");
          return {
            windowIndex: Number(windowIndex),
            tabIndex: Number(tabIndex),
            title: title || null,
            url: url || null,
          };
        }),
    };
  }

  return {
    appName,
    supported: false,
    tabs: [],
  };
}

function normalizeUrl(rawUrl) {
  if (typeof rawUrl !== "string" || !rawUrl.trim()) {
    const error = new Error("url is required");
    error.status = 400;
    throw error;
  }

  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    const error = new Error("Invalid URL");
    error.status = 400;
    throw error;
  }

  if (!["http:", "https:"].includes(parsed.protocol)) {
    const error = new Error("Only http and https URLs are allowed");
    error.status = 400;
    throw error;
  }

  return parsed.toString();
}

async function activateBrowser(appName) {
  const targetApp = pickBrowserApp(appName);
  await runAppleScript([
    `tell application ${appleScriptString(targetApp)} to activate`,
  ]);
  return {
    ok: true,
    action: "activate",
    appName: targetApp,
  };
}

async function openBrowserUrl({ appName, targetUrl, newTab = true }) {
  const targetApp = pickBrowserApp(appName);
  const safeUrl = normalizeUrl(targetUrl);

  if (newTab) {
    await execFileText("/usr/bin/open", ["-a", targetApp, safeUrl], {
      timeout: 10000,
    });
  } else if (CHROME_FAMILY_APPS.has(targetApp)) {
    await runAppleScript([
      `tell application ${appleScriptString(targetApp)}`,
      "activate",
      "if (count of windows) = 0 then make new window",
      `set URL of active tab of front window to ${appleScriptString(safeUrl)}`,
      "end tell",
    ]);
  } else if (targetApp === "Safari") {
    await runAppleScript([
      'tell application "Safari"',
      "activate",
      "if (count of windows) = 0 then make new document",
      `set URL of current tab of front window to ${appleScriptString(safeUrl)}`,
      "end tell",
    ]);
  } else {
    const error = new Error(`Unsupported browser app: ${targetApp}`);
    error.status = 400;
    throw error;
  }

  return {
    ok: true,
    action: "open-url",
    appName: targetApp,
    url: safeUrl,
    newTab: Boolean(newTab),
  };
}

async function reloadBrowser(appName) {
  const targetApp = pickBrowserApp(appName);

  if (CHROME_FAMILY_APPS.has(targetApp)) {
    await runAppleScript([
      `tell application ${appleScriptString(targetApp)}`,
      "if (count of windows) = 0 then error \"No browser window is open\"",
      "activate",
      "reload active tab of front window",
      "end tell",
    ]);
  } else if (targetApp === "Safari") {
    await runAppleScript([
      'tell application "Safari"',
      "if (count of windows) = 0 then error \"No browser window is open\"",
      "activate",
      "do JavaScript \"window.location.reload();\" in current tab of front window",
      "end tell",
    ]);
  } else {
    const error = new Error(`Unsupported browser app: ${targetApp}`);
    error.status = 400;
    throw error;
  }

  return {
    ok: true,
    action: "reload",
    appName: targetApp,
  };
}

async function selectBrowserTab({ appName, windowIndex, tabIndex }) {
  const targetApp = pickBrowserApp(appName);
  const targetWindow = Number(windowIndex ?? 1);
  const targetTab = Number(tabIndex);

  if (!Number.isInteger(targetWindow) || targetWindow < 1) {
    const error = new Error("windowIndex must be a positive integer");
    error.status = 400;
    throw error;
  }
  if (!Number.isInteger(targetTab) || targetTab < 1) {
    const error = new Error("tabIndex must be a positive integer");
    error.status = 400;
    throw error;
  }

  if (CHROME_FAMILY_APPS.has(targetApp)) {
    await runAppleScript([
      `tell application ${appleScriptString(targetApp)}`,
      `if (count of windows) < ${targetWindow} then error "Window index out of range"`,
      `if (count of tabs of window ${targetWindow}) < ${targetTab} then error "Tab index out of range"`,
      "activate",
      `set active tab index of window ${targetWindow} to ${targetTab}`,
      "end tell",
    ]);
  } else if (targetApp === "Safari") {
    await runAppleScript([
      'tell application "Safari"',
      `if (count of windows) < ${targetWindow} then error "Window index out of range"`,
      `if (count of tabs of window ${targetWindow}) < ${targetTab} then error "Tab index out of range"`,
      "activate",
      `set current tab of window ${targetWindow} to tab ${targetTab} of window ${targetWindow}`,
      "end tell",
    ]);
  } else {
    const error = new Error(`Unsupported browser app: ${targetApp}`);
    error.status = 400;
    throw error;
  }

  return {
    ok: true,
    action: "select-tab",
    appName: targetApp,
    windowIndex: targetWindow,
    tabIndex: targetTab,
  };
}

async function systemInfo() {
  return {
    mode: MODE,
    hostname: os.hostname(),
    platform: process.platform,
    arch: process.arch,
    cpus: os.cpus().length,
    uptimeSeconds: Math.floor(os.uptime()),
    localTime: new Date().toISOString(),
    macos: await getMacVersion(),
  };
}

async function takeScreenshot() {
  if (!ALLOW_SCREENSHOT) {
    const error = new Error("Screenshot is disabled. Set HOST_AUTOMATION_ALLOW_SCREENSHOT=1 to enable it.");
    error.status = 403;
    throw error;
  }
  if (!isMac()) {
    const error = new Error("Screenshot endpoint is macOS-only");
    error.status = 501;
    throw error;
  }
  return execFileBuffer("/usr/sbin/screencapture", ["-x", "-t", "png", "-"], {
    timeout: 10000,
    maxBuffer: 30 * 1024 * 1024,
  });
}

async function handleRequest(req, res) {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
  if (!requireAuth(req, res, url)) return;

  if (req.method !== "GET" && !(canBrowserWrite() && req.method === "POST")) {
    return json(res, 405, {
      error: {
        message: canBrowserWrite() ? "Method not allowed" : "Only GET is enabled in read-only mode",
        type: "invalid_request_error",
      },
    });
  }

  if (url.pathname === "/health") {
    return json(res, 200, {
      ok: true,
      mode: MODE,
      host: HOST,
      port: PORT,
      macos: isMac(),
      features: {
        browserRead: true,
        desktopRead: true,
        systemRead: true,
        screenshot: ALLOW_SCREENSHOT,
        browserWrite: canBrowserWrite(),
        writeActions: canBrowserWrite(),
      },
    });
  }

  if (url.pathname === "/v1/system/info") {
    return json(res, 200, await systemInfo());
  }

  if (url.pathname === "/v1/system/apps") {
    return json(res, 200, {
      apps: await listVisibleApps(),
    });
  }

  if (url.pathname === "/v1/desktop/frontmost") {
    return json(res, 200, await getFrontmostWindow());
  }

  if (url.pathname === "/v1/browser/frontmost") {
    return json(res, 200, await getBrowserFrontmost());
  }

  if (url.pathname === "/v1/browser/tabs") {
    return json(res, 200, await listBrowserTabs(browserForQuery(url)));
  }

  if (url.pathname === "/v1/desktop/screenshot") {
    const png = await takeScreenshot();
    res.writeHead(200, {
      "Content-Type": "image/png",
      "Content-Length": png.length,
      "Cache-Control": "no-store",
    });
    res.end(png);
    return;
  }

  if (req.method === "POST" && canBrowserWrite()) {
    const body = await readJsonBody(req);

    if (url.pathname === "/v1/browser/activate") {
      return json(res, 200, await activateBrowser(body.app));
    }

    if (url.pathname === "/v1/browser/open-url") {
      return json(
        res,
        200,
        await openBrowserUrl({
          appName: body.app,
          targetUrl: body.url,
          newTab: body.newTab !== false,
        }),
      );
    }

    if (url.pathname === "/v1/browser/reload") {
      return json(res, 200, await reloadBrowser(body.app));
    }

    if (url.pathname === "/v1/browser/select-tab") {
      return json(
        res,
        200,
        await selectBrowserTab({
          appName: body.app,
          windowIndex: body.windowIndex,
          tabIndex: body.tabIndex,
        }),
      );
    }
  }

  return json(res, 404, {
    error: {
      message: "Not found",
      type: "invalid_request_error",
    },
  });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((error) => {
    const status = Number(error.status) || 500;
    json(res, status, {
      error: {
        message: error.message || "Internal server error",
        type: status >= 500 ? "server_error" : "invalid_request_error",
        details: error.stderr || undefined,
      },
    });
  });
});

server.listen(PORT, HOST, () => {
  const tokenState = TOKEN ? "enabled" : "disabled";
  console.log(`host-automation-agent listening on http://${HOST}:${PORT}`);
  console.log(`mode=${MODE} auth=${tokenState} screenshot=${ALLOW_SCREENSHOT ? "enabled" : "disabled"}`);
});
