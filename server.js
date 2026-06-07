const http = require("http");
const fs = require("fs");
const path = require("path");

const publicDir = path.join(__dirname, "public");
const port = Number(process.env.PORT) || 8080;

// CLOAKING_ENABLED = true | false (bots -> bridge.html, humains -> vraie page)
const CLOAKING_ENABLED = process.env.CLOAKING_ENABLED !== "false";

const BOT_PATTERN =
  /bot|crawl|spider|google|bing|facebook|facebookexternalhit|facebookcatalog|moderateur|googlebot|adsbot|mediapartners|applebot|msnbot/i;

const BLOCKED_SOURCE =
  /^\/(app\.js|bot-check\.js|build\.js|server\.js)$/i;

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".mp3": "audio/mpeg",
};

const PAGE_404 = `<!doctype html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>404 — Page introuvable</title>
  <style>
    body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
      font-family: system-ui, sans-serif; background: #f4f4f5; color: #3f3f46; }
    .box { text-align: center; padding: 32px; }
    h1 { font-size: 72px; margin: 0 0 8px; color: #d4d4d8; }
    p { margin: 0; font-size: 16px; }
  </style>
</head>
<body>
  <div class="box">
    <h1>404</h1>
    <p>Page introuvable</p>
  </div>
</body>
</html>`;

function isRealBrowser(userAgent) {
  var ua = (userAgent || "").toLowerCase();
  if (BOT_PATTERN.test(ua) && !/(chrome\/|crios\/|edg\/|firefox\/)/.test(ua)) {
    return false;
  }
  return (
    /mozilla\/5\.0/.test(ua) &&
    /(?:chrome\/|crios\/|edg\/|firefox\/|version\/)/.test(ua)
  );
}

function isBot(userAgent) {
  if (isRealBrowser(userAgent)) return false;
  return BOT_PATTERN.test(userAgent || "");
}

function isHtmlDocument(urlPath) {
  return (
    urlPath === "/" ||
    urlPath === "/index.html" ||
    (urlPath.endsWith(".html") && urlPath !== "/bridge.html")
  );
}

function sendText(res, status, type, body) {
  res.writeHead(status, { "Content-Type": type });
  res.end(body);
}

function send404(res) {
  sendText(res, 404, "text/html; charset=utf-8", PAGE_404);
}

function serveFile(res, filePath) {
  fs.readFile(filePath, function (err, data) {
    if (err) {
      send404(res);
      return;
    }

    var ext = path.extname(filePath).toLowerCase();
    var headers = { "Content-Type": mimeTypes[ext] || "application/octet-stream" };
    if (ext === ".html") {
      headers["Cache-Control"] = "no-store, no-cache, must-revalidate";
      headers["Pragma"] = "no-cache";
    }
    if (ext === ".js") {
      headers["Cache-Control"] = "no-store";
      headers["X-Content-Type-Options"] = "nosniff";
    }
    res.writeHead(200, headers);
    res.end(data);
  });
}

const server = http.createServer(function (req, res) {
  if (req.method !== "GET") {
    sendText(res, 405, "text/plain; charset=utf-8", "Method Not Allowed");
    return;
  }

  var urlPath = decodeURIComponent((req.url || "/").split("?")[0]);
  if (urlPath === "/") urlPath = "/index.html";

  if (BLOCKED_SOURCE.test(urlPath)) {
    send404(res);
    return;
  }

  if (urlPath === "/health") {
    sendText(res, 200, "text/plain; charset=utf-8", "ok");
    return;
  }

  if (urlPath === "/bridge.html") {
    serveFile(res, path.join(publicDir, "bridge.html"));
    return;
  }

  var userAgent = req.headers["user-agent"] || "";

  if (CLOAKING_ENABLED && isBot(userAgent)) {
    if (isHtmlDocument(urlPath)) {
      serveFile(res, path.join(publicDir, "bridge.html"));
      return;
    }
  }

  var filePath = path.join(publicDir, urlPath);

  if (!filePath.startsWith(publicDir)) {
    sendText(res, 403, "text/plain; charset=utf-8", "Forbidden");
    return;
  }

  fs.access(filePath, fs.constants.F_OK, function (err) {
    if (!err) {
      serveFile(res, filePath);
      return;
    }

    if (isHtmlDocument(urlPath)) {
      serveFile(res, path.join(publicDir, "index.html"));
      return;
    }

    send404(res);
  });
});

server.listen(port, "0.0.0.0", function () {
  console.log("Serveur : http://127.0.0.1:" + port);
});
