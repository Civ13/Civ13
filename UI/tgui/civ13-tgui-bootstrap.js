/* Civ13's ES5 bootstrap deliberately runs before the modern React bundle. */
(function () {
  'use strict';
  var body = document.body;
  var ref = body.getAttribute('data-ref');
  var windowId = body.getAttribute('data-window');
  var generation = body.getAttribute('data-generation');
  // Versioned file names, so a reconnect to an updated world never reuses
  // the browser's remembered copy of the old bundle.
  var assets = body.getAttribute('data-assets');
  var suffix = assets && /^[0-9a-f]{1,32}$/.test(assets) ? '.' + assets : '';
  var stopped = false;
  var ready = false;
  var snapshotReceived = false;
  var acknowledged = false;
  var timer;
  var send = function (type, payload) {
    if (stopped) { return; }
    var url = 'byond://?src=' + encodeURIComponent(ref)
      + '&window_id=' + encodeURIComponent(windowId)
      + '&generation=' + encodeURIComponent(generation)
      + '&type=' + encodeURIComponent(type);
    if (payload !== undefined) { url += '&payload=' + encodeURIComponent(JSON.stringify(payload)); }
    try {
      if (window.cef_to_byond) { window.cef_to_byond(url); }
      else { window.location.href = url; }
    } catch (error) { /* The bounded server watchdog owns silent-bridge recovery. */ }
  };
  // The modern screen cannot run or rejected its data. The server swaps in a
  // plain page for the few windows that keep one; otherwise this notice stays.
  var fallback = function () {
    if (stopped) { return; }
    send('fallback');
    stopped = true;
    window.clearTimeout(timer);
    var loading = document.getElementById('tgui-loading');
    if (loading) {
      loading.style.display = '';
      loading.textContent = 'This window could not load. Close it and open it again.';
    }
  };
  var completeStartup = function () {
    if (stopped || !ready || !snapshotReceived || acknowledged) { return; }
    acknowledged = true;
    send('ack');
    window.clearTimeout(timer);
    var loading = document.getElementById('tgui-loading');
    if (loading) { loading.style.display = 'none'; }
  };
  var bridge = window.Civ13Tgui = {
    queue: [],
    send: send,
    fallback: fallback,
    ready: function () {
      if (stopped || ready) { return; }
      ready = true;
      send('ready');
      completeStartup();
    },
    acceptSnapshot: function (config) {
      if (stopped || !config || config.ref !== ref || config.window !== windowId
          || String(config.generation) !== generation || typeof config.template !== 'string'
          || (config.status !== -1 && config.status !== 0 && config.status !== 1 && config.status !== 2)) { return false; }
      snapshotReceived = true;
      completeStartup();
      return true;
    }
  };
  // The page carries its first snapshot, so the screen draws without waiting
  // for the ready round trip. The server still sends a fresh one on ready.
  var initial = document.getElementById('tgui-initial');
  if (initial && initial.textContent) { bridge.queue.push(initial.textContent); }
  window.receiveUpdateData = function (raw) {
    if (bridge.queue.length >= 32) { fallback(); return; }
    bridge.queue.push(raw);
  };
  // Do not infer the browser from the Dream Seeker version. Old engines never
  // parse the modern bundle, even when they are attached to a newer server.
  var match = navigator.userAgent.match(/(?:Chrome|Edg)\/(\d+)/);
  if (!match || Number(match[1]) < 123 || !window.Promise || !window.Map
      || !window.Set || !window.Symbol || !Object.assign || !Array.from) {
    fallback();
    return;
  }
  window.onerror = function () { fallback(); return true; };
  window.onunhandledrejection = function () { fallback(); };
  timer = window.setTimeout(function () { if (!acknowledged) { fallback(); } }, 15000);
  var css = document.createElement('link');
  css.rel = 'stylesheet';
  css.href = 'civ13-tgui' + suffix + '.css';
  css.onerror = fallback;
  document.head.appendChild(css);
  var script = document.createElement('script');
  script.src = 'civ13-tgui' + suffix + '.js';
  script.onerror = fallback;
  document.head.appendChild(script);
}());
