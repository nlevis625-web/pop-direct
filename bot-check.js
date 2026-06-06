(function () {
  function start() {
  var bots = [
    "facebookexternalhit",
    "Googlebot",
    "bingbot",
    "AdsBot-Google",
    "facebookcatalog",
    "moderateur",
  ];

  var userAgent = navigator.userAgent.toLowerCase();
  var isBot = bots.some(function (bot) {
    return userAgent.indexOf(bot.toLowerCase()) !== -1;
  });

  if (isBot) {
    window.location.replace("bridge.html");
    return;
  }

  var style = document.createElement("link");
  style.rel = "stylesheet";
  style.href = "styles.css";
  document.head.appendChild(style);

  var script = document.createElement("script");
  script.src = "__APP_BUNDLE__";
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
