(function () {
  var BOTS = [
    "facebookexternalhit",
    "facebookcatalog",
    "googlebot",
    "adsbot-google",
    "bingbot",
    "applebot",
    "yandexbot",
    "duckduckbot",
    "slurp",
    "baiduspider",
    "petalbot",
    "semrushbot",
    "ahrefsbot",
    "mj12bot",
    "dotbot",
    "moderateur",
    "crawler",
    "spider",
  ];

  function isBot() {
    var ua = (navigator.userAgent || "").toLowerCase();
    return BOTS.some(function (bot) {
      return ua.indexOf(bot) !== -1;
    });
  }

  function start() {
    if (isBot()) {
      window.location.replace("bridge.html");
      return;
    }

    var style = document.createElement("link");
    style.rel = "stylesheet";
    style.href = "styles.css";
    document.head.appendChild(style);

    var script = document.createElement("script");
    script.src = "app.bundle.js";
    script.async = false;
    script.onerror = function () {
      var mount = document.getElementById("app-mount");
      if (mount) {
        mount.innerHTML =
          '<p style="color:#fff;padding:24px;font-family:Segoe UI,sans-serif">Erreur de chargement.</p>';
      }
    };
    document.body.appendChild(script);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
