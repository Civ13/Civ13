# Device speech comprehension

The radio, telephone and voicepipe hearing paths share the exact same language
visibility/understanding transformation. Ordinary `hear_say` intentionally stays
separate: it has alternate messages, agent observation and language learning.

`comprehend_device_speech` returns a one-element list for delivery, and null only
for the existing unintelligible-animal/no-vocabulary early return. A plain text
return with a truthiness check would incorrectly suppress empty messages.
Device-specific sleeping/deafness, formatting, contacts and substitutions remain
in their original callers and original order.

Run `python3 scripts/ci_baseline.py unit --suite device_hearing --output /tmp/device-hearing.json`.
The frozen pre-extraction block is from master e567f23. Source contract tests
verify its branch/call ordering and each caller's integration, not native DM
behavior. The helper adds one proc call/list allocation per delivered device
message; this is a maintenance refactor, not a measured performance improvement.
Native BYOND/client testing remains separate acceptance evidence.
