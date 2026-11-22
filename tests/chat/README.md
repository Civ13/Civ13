# Chat browser checks

`chat-scroll.browser.test.js` loads the actual chat page and its tracked fonts
and sanitizer in headless Chromium. It replaces the BYOND-ready navigation with
an inert test marker and uses fictional messages; it does not launch BYOND or
prove embedded-client delivery. Browser requests other than file/data are
aborted by the Playwright context, in addition to disabled background networking.
This is not a kernel network sandbox.

Install the repository's locked TGUI dependencies with lifecycle scripts disabled,
then set `CHROMIUM_PATH` (or `CHROME_BIN`) to an existing Chromium executable and
`CHAT_TEST_TMP` to a disposable evidence directory. Run:

```sh
node tests/chat/workflow-contract.test.js
node tests/chat/chat-scroll.browser.test.js
CHAT_NO_RESIZE_OBSERVER=1 node tests/chat/chat-scroll.browser.test.js
CHAT_NEGATIVE_CONTROL=1 node tests/chat/chat-scroll.browser.test.js
```

The original-page fixture is pinned to the pre-change SHA-256. Its negative
control must fail the named scroll assertions. The fallback run disables
ResizeObserver and explicitly fires resize and font-completion events; it does
not establish behavior for all legacy browser engines. Generated HTML and browser
cleanup receipts are retained under `CHAT_TEST_TMP` with synthetic content only.
The separate workflow runs these cases on relevant PR and master changes.

`chat-filter.browser.test.js` uses the same harness for the filter tabs. It
checks that messages tagged by `CHAT_TYPED` (`code/__defines/chat.dm`) and untagged
OOC, PM, dead, whisper, warning and plain messages land in the right type,
that tabs hide other types and count unread lines, that the Admin tab stays
hidden until admin output arrives, that prayers and answers from the gods get
their own Prayer tab (hidden until the first prayer and kept out of Admin),
that tabs saved before the Prayer tab gain it once, that custom tabs are saved, that a flood of
one type does not trim another, and that malformed saved settings fall back to
the defaults. Set `CHAT_SCREENSHOT` to a path to save a picture of the
settings panel.

`chat-connection.browser.test.js` checks the connection watchdog. The server
starts it from `on_ready()` and answers each `chat_ping` with `chatPong`. The
test captures pings instead of sending them and checks that nothing pings
before the start, that answered pings never warn, that unanswered pings warn
once with a "Connection lost" notice shown on every tab, that an answer or any
game message reports "Connection restored" and announces `chat_ready` again
(the answering world may be a new one after a handover), and that timer ticks further apart
than the timeout (a throttled hidden window) do not raise a false alarm.

`chat-history.browser.test.js` checks the history kept across a reconnect,
such as moving to another region. The server calls `setChatIdentity(ckey)`
from `on_ready()` before the queued messages; the page keeps recent lines in
hub storage under that ckey and puts them back above the new output with a
divider. The test loads the page, feeds fictional lines, reloads it and checks
that lines sent just before leaving survive, types and tab filters carry over,
restored lines raise no unread badges, game links from the old world are
disabled while web links stay, storage is capped per type and in total, stored
markup is sanitized again, other ckeys see nothing, history older than a day
is ignored and Clear Chat wipes it.

`chat-repeat.browser.test.js` checks repeated lines. A message identical to
the line just before it adds an x2, x3 counter to that line instead of a new
line; a different message, a connection notice or Clear Chat in between starts
a new line. It also checks that similar but different warnings stay separate,
that a counted line keeps its type and raises unread counts on other tabs, and
that the counter goes past ten. Set `CHAT_SCREENSHOT` to save a picture.

`chat-translate.browser.test.js` checks on-device chat translation with a fake
Translator and LanguageDetector: on by default into English, only the marked
body of understood speech and OOC is sent, garbled (`chat-notr`) speech is
never sent, a language pack downloads only after a click, translations are not
saved in history or applied to restored lines, the setting saves locally, and
bursts are capped. It proves nothing about Dream Seeker's real browser.

`chat-plain.browser.test.js` checks the Plain chat text switch under Tabs...:
names on OOC lines are bold and upright, the switch is off by default, and
with it on no chat line is italic or underlined while links keep their colour
and bold stays. The choice is saved and survives a reload. Set
`CHAT_SCREENSHOT` to save a picture (`CHAT_PLAIN=1` with the switch on,
`CHAT_SMALL=1` for a small window, `CHAT_SETTINGS=1` with the panel open).
