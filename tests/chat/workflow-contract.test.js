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
  'node tests/chat/chat-filter.browser.test.js',
  'node tests/chat/chat-connection.browser.test.js',
  'node tests/chat/chat-history.browser.test.js',
  'node tests/chat/chat-repeat.browser.test.js',
  'node tests/chat/chat-translate.browser.test.js',
  'node tests/chat/chat-plain.browser.test.js',
  'node tests/chat/chat-local-speech.browser.test.js']) {
  assert.ok(workflow.includes(marker), marker);
}
assert.ok(!/DreamDaemon|DreamMaker|workflow_dispatch|schedule:/.test(workflow), 'no native/manual/scheduled execution');
assert.ok(/browse\((?:client, )?'interface\/chat\/chat\.html'/.test(backend), 'chat page browse call');
assert.ok(backend.includes('browser_chat:receiveMessage'));
assert.ok(chat.includes('window.receiveMessage = receiveMessage;'));
assert.ok(chat.includes('window.clearChat = clearChat;'));
assert.ok(chat.includes("const TAB_STORAGE_KEY = 'civ13-chat-tabs-v1';"), 'chat tab settings key');
assert.ok(read('code/__defines/chat.dm').includes("#define CHAT_TYPED(kind, message) (\"<span class='chattype-\" + kind"), 'server chat type tag');
assert.ok(backend.includes('browser_chat:startChatHeartbeat'), 'server starts the connection watchdog');
assert.ok(read('code/modules/client/client_procs.dm').includes('browser_chat:chatPong'), 'server answers chat pings');
assert.ok(chat.includes('window.chatPong = heardFromServer;') && chat.includes("'byond://?chat_ping='"), 'page ping bridge');
assert.ok(backend.includes('browser_chat:setChatIdentity') && chat.includes('window.setChatIdentity = setChatIdentity;'), 'server names the ckey for chat history');
assert.ok(chat.includes("const HISTORY_KEY_PREFIX = 'civ13-chat-history-v1:';"), 'chat history key');
const clientProcs = read('code/modules/client/client_procs.dm');
const mobCheck = clientProcs.indexOf('if (!usr || usr != mob)');
assert.ok(mobCheck > 0 && clientProcs.indexOf('href_list["chat_ready"]') > 0 && clientProcs.indexOf('href_list["chat_ready"]') < mobCheck, 'chat_ready is handled before the mob check');
assert.ok(/href_list\["chat_ping"\][\s\S]{0,600}if \(chat && !chat\.is_ready\)\s+chat\.on_ready\(\)/.test(clientProcs), 'a ping from a page this world never heard ready flushes the queue');
assert.ok(chat.includes('window.chatSendReady = chatSendReady;') && chat.includes("'byond://?chat_ready=1&again=1'"), 'page re-announces ready after a lost connection');
assert.ok(clientProcs.includes('watch_browser_panels()') && read('code/modules/statpanel/statpanel.dm').includes('/client/proc/watch_browser_panels()'), 'unanswered side panels are resent');
const hear = read('code/game/mob/hear_say.dm');
const listener = hear.slice(hear.indexOf('/mob/proc/hear_say('), hear.indexOf('/mob/proc/on_hear_say('));
assert.match(listener, /if \(understood && !italics && !animal && !accent && ishuman\(src\) && ishuman\(speaker\).*\n\s*message = "<span class='chat-local-voice'>\[message\]<\/span>"/);
assert.equal(hear.split('chat-local-voice').length, 2, 'only recipient-visible direct IC can be spoken');
assert.ok(!/play_tts|config\.tts_on/.test(hear + read('code/game/mob/living/chat_overlay.dm')), 'server speech synthesis removed');
console.log('PASS chat workflow and delivery contracts');
