const fs = require("fs");
const path = require("path");

const root = __dirname;
const publicDir = path.join(root, "public");
const LOADER_NAME = "loader.js";
const APP_NAME = "app.bundle.js";

const staticFiles = [
  "bridge.html",
  "bsod-qr.svg",
  "script-audio.mp3",
  "script-audio-2.mp3",
];

fs.mkdirSync(publicDir, { recursive: true });

console.log("Build public/...");

let indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");
indexHtml = indexHtml.replace(/bot-check\.js/g, LOADER_NAME);
fs.writeFileSync(path.join(publicDir, "index.html"), indexHtml);

let loader = fs.readFileSync(path.join(root, "bot-check.js"), "utf8");
loader = loader.replace(/__APP_BUNDLE__/g, APP_NAME);
fs.writeFileSync(path.join(publicDir, LOADER_NAME), loader);

fs.copyFileSync(path.join(root, "app.js"), path.join(publicDir, APP_NAME));

let styles = fs.readFileSync(path.join(root, "styles.css"), "utf8");
styles = styles.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\s+/g, " ").trim();
fs.writeFileSync(path.join(publicDir, "styles.css"), styles);

const audioFallbackDir = path.join(root, "..");

for (const file of staticFiles) {
  let src = path.join(root, file);
  if (!fs.existsSync(src) && file.endsWith(".mp3")) {
    const fallback = path.join(audioFallbackDir, file);
    if (fs.existsSync(fallback)) {
      fs.copyFileSync(fallback, src);
      src = path.join(root, file);
    }
  }
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(publicDir, file));
  } else if (file.endsWith(".mp3")) {
    console.warn("Attention : fichier audio manquant -> " + file);
  }
}

const oldJs = fs.readdirSync(publicDir).filter(function (f) {
  return f.endsWith(".js") && f !== LOADER_NAME && f !== APP_NAME;
});
for (const f of oldJs) {
  fs.unlinkSync(path.join(publicDir, f));
}

console.log("Termine : " + LOADER_NAME + " -> " + APP_NAME);
