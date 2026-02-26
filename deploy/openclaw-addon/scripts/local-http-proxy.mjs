import http from "node:http";
import net from "node:net";
import { URL } from "node:url";

const HOST = process.env.PROXY_HOST || "127.0.0.1";
const PORT = Number(process.env.PROXY_PORT || "58591");

const server = http.createServer((req, res) => {
  let target;
  try {
    target = new URL(req.url);
  } catch {
    res.writeHead(400);
    res.end("Bad Request");
    return;
  }

  const isHttps = target.protocol === "https:";
  const upstream = http.request(
    {
      host: target.hostname,
      port: target.port || (isHttps ? 443 : 80),
      method: req.method,
      path: `${target.pathname}${target.search}`,
      headers: {
        ...req.headers,
        host: target.host,
      },
    },
    (upstreamRes) => {
      res.writeHead(upstreamRes.statusCode || 502, upstreamRes.headers);
      upstreamRes.pipe(res);
    },
  );

  upstream.on("error", () => {
    res.writeHead(502);
    res.end("Bad Gateway");
  });

  req.pipe(upstream);
});

server.on("connect", (req, clientSocket, head) => {
  const [host, portText] = String(req.url || "").split(":");
  const port = Number(portText || 443);
  if (!host || Number.isNaN(port)) {
    clientSocket.write("HTTP/1.1 400 Bad Request\r\n\r\n");
    clientSocket.destroy();
    return;
  }

  const upstreamSocket = net.connect(port, host, () => {
    clientSocket.write("HTTP/1.1 200 Connection Established\r\n\r\n");
    if (head?.length) upstreamSocket.write(head);
    upstreamSocket.pipe(clientSocket);
    clientSocket.pipe(upstreamSocket);
  });

  const closeBoth = () => {
    upstreamSocket.destroy();
    clientSocket.destroy();
  };

  upstreamSocket.on("error", closeBoth);
  clientSocket.on("error", closeBoth);
});

server.on("clientError", (err, socket) => {
  if (!socket.writable) return;
  socket.end("HTTP/1.1 400 Bad Request\r\n\r\n");
});

server.listen(PORT, HOST, () => {
  console.log(`local-http-proxy listening on http://${HOST}:${PORT}`);
});
