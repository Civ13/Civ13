// Offline checks for delivery wiring and the narrowly scoped browser workflow.
'use strict';
const assert = require('assert/strict');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const workflow = read('.github/workflows/chat-browser.yml');
const chat = read('interface/chat/chat.html');
const backend = read('code/modules/chat/chat.dm');
for (const target of ['interface/chat/**', 'interface/fonts/**', 'code/js/purify.min.js', 'code/modules/chat/chat.dm', 'tests/chat/**', 'tgui/package-lock.json']) {
  assert.equal(workflow.split("'" + target + "'").length - 1, 2, 'PR and master path filters: ' + target);
}
for (const marker of ['timeout-minutes: 10', 'timeout-minutes: 5', 'timeout-minutes: 2',
  "node-version: '24.22.1'", 'npm ci --ignore-scripts --prefix tgui',
  'CHAT_NO_RESIZE_OBSERVER=1 node tests/chat/chat-scroll.browser.test.js',
  'CHAT_NEGATIVE_CONTROL=1 node tests/chat/chat-scroll.browser.test.js',
  'node tests/chat/chat-filter.browser.test.js']) {
  assert.ok(workflow.includes(marker), marker);
}
assert.ok(!/DreamDaemon|DreamMaker|workflow_dispatch|schedule:/.test(workflow), 'no native/manual/scheduled execution');
assert.ok(backend.includes("browse('interface/chat/chat.html'"));
assert.ok(backend.includes('browser_chat:receiveMessage'));
assert.ok(chat.includes('window.receiveMessage = receiveMessage;'));
assert.ok(chat.includes('window.clearChat = clearChat;'));
assert.ok(chat.includes("const TAB_STORAGE_KEY = 'civ13-chat-tabs-v1';"), 'chat tab settings key');
assert.ok(read('code/__defines/chat.dm').includes("#define CHAT_TYPED(kind, message) (\"<span class='chattype-\" + kind"), 'server chat type tag');
console.log('PASS chat workflow and delivery contracts');
