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
hidden until admin output arrives, that custom tabs are saved, that a flood of
one type does not trim another, and that malformed saved settings fall back to
the defaults. Set `CHAT_SCREENSHOT` to a path to save a picture of the
settings panel.
