// Local chat translation service for Civ13 (docs/chat-translation.md).
// Runs Microsoft Edge with its built-in on-device Translator and answers the
// game world on 127.0.0.1 only:
//   POST /translate {"text": "...", "target": "en"} -> {"source": "es", "translation": "..."}
//   GET  /health -> {"ok": true, ...}
// Nothing is logged or saved except Edge's own language packs in the profile.
//
// Usage: node edge_translator.js [--port 55581] [--profile <dir>] [--edge <msedge.exe>] [--headed]
'use strict';
const fs = require('fs');
const http = require('http');
const path = require('path');
const { detect, LANGS } = require('./detect');

const MAX_CHARS = 500;
const MAX_BODY = 8192;
const MAX_WAITING = 40;
const TRANSLATE_TIMEOUT_MS = 15000;

const PAGE = `<!doctype html><meta charset="utf-8"><title>Civ13 translator</title>
<button id="go">translate</button>
<script>
  const translators = {};
  const creating = {};
  window.__pair = null;
  window.pairState = async (s, t) => translators[s + '>' + t] ? 'available' : await Translator.availability({ sourceLanguage: s, targetLanguage: t });
  // create() needs a user click when a pack is downloadable; the service clicks this button.
  document.getElementById('go').addEventListener('click', () => {
    const p = window.__pair; if (!p) return;
    const key = p.s + '>' + p.t;
    if (translators[key] || creating[key]) return;
    creating[key] = Translator.create({ sourceLanguage: p.s, targetLanguage: p.t })
      .then(tr => { translators[key] = tr; }).catch(() => {}).finally(() => { delete creating[key]; });
  });
  window.translateWith = async (s, t, text) => {
    const tr = translators[s + '>' + t];
    return tr ? await tr.translate(text) : null;
  };
  window.hasTranslator = () => typeof Translator !== 'undefined';
</script>`;

function parseArgs(argv) {
  const opts = { port: 55581, profile: path.join(__dirname, 'edge-profile'), edge: null, headed: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--port') opts.port = Number(argv[++i]);
    else if (a === '--profile') opts.profile = argv[++i];
    else if (a === '--edge') opts.edge = argv[++i];
    else if (a === '--headed') opts.headed = true;
  }
  return opts;
}

function findEdge() {
  const candidates = [
    process.env['ProgramFiles(x86)'] && path.join(process.env['ProgramFiles(x86)'], 'Microsoft/Edge/Application/msedge.exe'),
    process.env.ProgramFiles && path.join(process.env.ProgramFiles, 'Microsoft/Edge/Application/msedge.exe'),
    '/usr/bin/microsoft-edge',
  ].filter(Boolean);
  return candidates.find(p => fs.existsSync(p)) || null;
}

// The Edge side: one hidden page that holds a translator per language pair.
class EdgeBackend {
  constructor(opts) { this.opts = opts; this.page = null; this.pending = {}; }

  async start() {
    const { chromium } = require('playwright-core');
    const pageServer = http.createServer((req, res) => { res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }); res.end(PAGE); });
    await new Promise(r => pageServer.listen(0, '127.0.0.1', r));
    this.context = await chromium.launchPersistentContext(this.opts.profile, {
      executablePath: this.opts.edge || findEdge(),
      headless: !this.opts.headed,
      // Edge fetches its language packs through the component updater, which
      // Playwright turns off by default.
      ignoreDefaultArgs: ['--disable-component-update'],
      args: ['--no-first-run', '--no-default-browser-check'],
    });
    this.page = this.context.pages()[0] || await this.context.newPage();
    await this.page.goto('http://127.0.0.1:' + pageServer.address().port + '/');
    if (!await this.page.evaluate(() => window.hasTranslator())) throw new Error('This Edge has no Translator API');
  }

  // 'available', 'downloadable', 'downloading' or 'unavailable'.
  async state(source, target) {
    try { return await this.page.evaluate(([s, t]) => window.pairState(s, t), [source, target]); } catch (e) { return 'unavailable'; }
  }

  // Starts creating (and if needed downloading) a pair; never waits for it.
  async prepare(source, target) {
    const key = source + '>' + target;
    if (this.pending[key] && Date.now() - this.pending[key] < 60000) return;
    this.pending[key] = Date.now();
    await this.page.evaluate(([s, t]) => { window.__pair = { s, t }; }, [source, target]);
    await this.page.click('#go');
  }

  async translate(source, target, text) {
    let state = await this.state(source, target);
    if (state === 'unavailable') return null;
    await this.prepare(source, target);
    // A pair already on disk is ready within a second or two.
    for (let i = 0; i < 20; i++) {
      const out = await this.page.evaluate(([s, t, x]) => window.translateWith(s, t, x), [source, target, text]);
      if (out !== null) return out;
      await new Promise(r => setTimeout(r, 100));
    }
    return null; // still downloading; later lines will get it
  }

  async close() { if (this.context) await this.context.close(); }
}

function withTimeout(promise, ms) {
  return Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), ms))]);
}

// The HTTP side, separate from Edge so it can be tested with a stand-in backend.
function createService(backend) {
  let chain = Promise.resolve();
  let waiting = 0;
  const stats = { translated: 0, skipped: 0, failed: 0, busy: 0 };

  async function handle(text, target) {
    const source = detect(text);
    if (source === 'und' || source === target) { stats.skipped++; return { source, translation: '' }; }
    const out = await backend.translate(source, target, text);
    const translation = typeof out === 'string' ? out.trim() : '';
    if (translation && translation !== text) stats.translated++; else stats.skipped++;
    return { source, translation: translation && translation !== text ? translation : '' };
  }

  const server = http.createServer((req, res) => {
    const reply = (code, body) => { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(body)); };
    if (req.method === 'GET' && req.url === '/health') return reply(200, Object.assign({ ok: true, waiting }, stats));
    if (req.method !== 'POST' || req.url !== '/translate') return reply(404, { error: 'not found' });
    let raw = '';
    let size = 0;
    req.setEncoding('utf8');
    req.on('data', chunk => { size += Buffer.byteLength(chunk); if (size > MAX_BODY) { reply(413, { error: 'too large' }); req.destroy(); } else raw += chunk; });
    req.on('end', () => {
      if (size > MAX_BODY) return;
      let body;
      try { body = JSON.parse(raw); } catch (e) { return reply(400, { error: 'bad json' }); }
      const text = typeof body.text === 'string' ? body.text.slice(0, MAX_CHARS).trim() : '';
      const target = typeof body.target === 'string' ? body.target : '';
      if (!text || !LANGS.includes(target)) return reply(400, { error: 'text and a supported target are needed' });
      if (waiting >= MAX_WAITING) { stats.busy++; return reply(503, { error: 'busy' }); }
      waiting++;
      // One line at a time through Edge.
      const job = chain.then(() => withTimeout(handle(text, target), TRANSLATE_TIMEOUT_MS));
      chain = job.catch(() => {});
      job.then(result => reply(200, result), () => { stats.failed++; reply(500, { error: 'translation failed' }); })
        .finally(() => { waiting--; });
    });
  });
  return server;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const backend = new EdgeBackend(opts);
  await backend.start();
  const server = createService(backend);
  server.listen(opts.port, '127.0.0.1', () => console.log('Civ13 Edge translator listening on http://127.0.0.1:' + opts.port));
  const stop = () => { server.close(); backend.close().finally(() => process.exit(0)); };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

if (require.main === module) main().catch(e => { console.error('Civ13 Edge translator could not start: ' + e.message); process.exit(1); });

module.exports = { createService, parseArgs, PAGE };
