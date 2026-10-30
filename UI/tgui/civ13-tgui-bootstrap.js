/* Civ13's ES5 bootstrap deliberately runs before the modern React bundle. */
(function () {
  'use strict';
  var body = document.body;
  var ref = body.getAttribute('data-ref');
  var windowId = body.getAttribute('data-window');
  var generation = body.getAttribute('data-generation');
  var stopped = false;
  var ready = false;
  var timer;
  var send = function (type, payload) {
    if (stopped) { return; }
    var url = 'byond://?src=' + encodeURIComponent(ref)
      + '&window_id=' + encodeURIComponent(windowId)
      + '&generation=' + encodeURIComponent(generation)
      + '&type=' + encodeURIComponent(type);
    if (payload !== undefined) { url += '&payload=' + encodeURIComponent(JSON.stringify(payload)); }
    if (window.cef_to_byond) { window.cef_to_byond(url); }
    else { window.location.href = url; }
  };
  var fallback = function () {
    if (stopped) { return; }
    send('fallback');
    stopped = true;
    window.clearTimeout(timer);
  };
  var bridge = window.Civ13Tgui = {
    queue: [],
    send: send,
    fallback: fallback,
    ready: function () {
      if (stopped || ready) { return; }
      ready = true;
      window.clearTimeout(timer);
      send('ready');
      var loading = document.getElementById('tgui-loading');
      if (loading) { loading.style.display = 'none'; }
    }
  };
  window.receiveUpdateData = function (raw) {
    if (bridge.queue.length >= 32) { fallback(); return; }
    bridge.queue.push(raw);
  };
  document.getElementById('tgui-legacy').onclick = function () { fallback(); return false; };
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
  timer = window.setTimeout(fallback, 15000);
  var css = document.createElement('link');
  css.rel = 'stylesheet';
  css.href = 'civ13-tgui.css';
  css.onerror = fallback;
  document.head.appendChild(css);
  var script = document.createElement('script');
  script.src = 'civ13-tgui.js';
  script.onerror = fallback;
  document.head.appendChild(script);
}());
