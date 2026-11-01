# Expanded character flavor reader

This independent source slice migrates the existing character-examine More...
reader, audited at `fb0e5c41cd4fc7f399cb6cf90d7dbf9cb6741c62` and based on
master `1c41467eaf0900f938830c2a55e34414460c1520` after #3467. It does not depend
on the proposed Notes or Photo readers. Those routes must all be retained when
integrated later. Stored flavor text, editing/cancellation, preview shortening,
human face-cover preview filtering and save behavior are untouched.

Admission is the original `src in view(usr)` check, rechecked by the fixed
optional presentation hook before it collects data. There is no new human,
distance-number, mask, dead or target-client rule. A reader-only state binds the
exact subject and viewer. Transfer to a new viewer mob cannot reuse that lease,
even after its client is linked. Ghosts retain the original in-view admission.
This preserves the original static browser snapshot: walking out of view or
subsequent subject edits do not recollect or erase already-delivered content.
Only explicit More rechecks view and refreshes the snapshot. Changing visibility
or masking policy is outside this presentation change.

The existing editor sanitizes with HTML encoding and retains newlines. For
text that passes the native encode/decode canonical roundtrip, the view uses
inert React text and literal-LF line breaks, with a monospace content font like
the original TT wrapper. Encoded numeric LF remains whitespace text, rather
than becoming an invented hard break. Decoding happens exactly once.

The complete original HTML is captured first. Imported raw markup, improper
formatting, ambiguous/unsupported entities or controls and over-budget content
use that full cached classic snapshot. Nothing is truncated or rewritten in
storage. The server aggregate limit is 65,536 native length units and 2,048
literal-LF lines; the frontend independently caps UTF-16 units and lines. Names
with markup/entity ambiguity also retain the original renderer. Native builtin
encoding/Unicode parity has not been executed; conservatively rejected modern
payloads request classic fallback through the existing root error boundary.
The classic HTML execution boundary is unchanged. No raw React HTML host, new
rich-text dialect or Notes-parser dependency is introduced.

The new window identity follows the subject reference, avoiding name-collision
reuse, while keeping the original 500x200 requested size. The complete cached
HTML is delivered only after the current reader state is checked. Manager
refresh is status-only; no data polling, broadcast or domain action exists.
Close clears that cache and calls the existing parent cleanup once. The
reader disables inherited machine-close logic: the old generic onclose callback
could clear unrelated using_object state, despite this reader not acquiring it.
This narrow close-side correction requires independent review with the slice.

Offline source contracts freeze and compare the original Topic path, editor
cancel/preview behavior, canonical/fallback bounds, owner/ghost/transfer lease,
cached HTML delivery and close cleanup. Component and production DOM/Chromium
fixtures use fictional text, Unicode and malformed/over-budget inputs. They do
not establish native view() semantics, encode/decode/indexing, actual bridge,
cache/focus/scroll, concurrent-window close or transfer behavior.

No native compiler, DreamDaemon, DreamSeeker/client, publication, merge,
deployment, live-server, security or dependency-install action is part of this
local candidate. Main review precedes publication; normal exact-head compiler
and frontend/offline CI would be required afterward.
