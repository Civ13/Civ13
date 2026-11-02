# Verified access-file consumer

Offline checks: `py -3 -B -m unittest discover -s tests/access_lists -p "test_*.py" -v`.
The complete three production helper bodies run through the existing audited
save-movement source projector, imported into a private module; only its global
field mapping is extended locally. DM raw regex literals are mapped lexically
to Python raw literals; the unbound DM catch maps to a Python exception binding
which is also ignored. No executable helper lines are omitted.
Files, regex, ckey, trim and DM list semantics are fake boundaries. Gate/startup
wiring checks inspect source and do not execute the full Topic/admin/startup.
This is not BYOND compilation, native regex/ckey acceptance or live access evidence.

Each fixed SQL target is independent: startup and Reload Lists stage, fully
validate and replace its list. A bad file cannot partially publish; missing,
unreadable, malformed or zero-byte input retains list object and readiness.
A single byte LF is the ONLY authoritative empty-set payload. It sets ready=true
with empty membership. Initial unavailable sets ready=false. Enabled approved
joining denies in both cases, with a distinct unavailable message. Enabled
whitelisted-job admission denies nonmembers only under the existing
`actual_job.whitelisted && clients.len > 12` condition. This population exception
is retained explicitly. Existing customization/perk consumers already deny empty
membership and receive canonical keys. Configuration flags are unchanged.

Producer canonical wire: ASCII `ckey=DiscordID` plus LF per row, keys
`[a-z0-9]{1,256}`, IDs `[1-9][0-9]{16,19}`, unique keys and unique IDs.
IDs remain lexical strings and are discarded after validation. No numeric
conversion is used. Consumer accepts unsorted input and these explicit legacy
extensions: nonempty CRLF records, ASCII letter case, spaces/tabs/underscores in
keys normalized through ckey, and spaces/tabs around IDs. A key must normalize to
the canonical grammar; duplicate canonical keys reject the whole file. Other
punctuation, controls, Unicode, extra fields, missing final LF and blank rows fail.
CRLF-only empty and whitespace-only empty fail. Producer remains stricter.

`producer-vectors.json` is copied byte-for-byte from the producer owner's
`tests/local/access-list-vectors.json` (schema civ13.access-lines.v1, 16 synthetic
vectors). The test explicitly labels its three compatibility extensions rather
than claiming producer and consumer reject sets are identical. No real users,
Discord IDs, SQL files, guild calls or live writes are used.

Preparation failures preserved in the review record: initial new test encoding
was Windows CP1252 rather than UTF-8; next projection rejected spaced catch
syntax; next run passed 11 tests but failed one default-encoding source read.
The initial CI registry check also caught the new registration using `shared`
instead of the registry's `shared_paths` key (72 passed, one failed). The next registry run passed 72 and failed the preexisting world.dm selection
expectation; it is extended additively for this new suite. These were offline
preparation results, not native results.
The first hosted compile at730690f40 failed because ordinary DM string
literals interpreted regex character classes as embedded expressions. Both
patterns now use DM raw strings; a focused regression requires noninterpolating
literals. The original compiler failure is preserved in publication evidence. The recipe
branch compiler also proved that DM rejects the carriage-return escape; CRLF
normalization uses the existing ascii2text(13) idiom, with a fake character-code
boundary in this offline projection.
Source PR publication is authorized; no configuration activation, live reload,
restart or native access fixture has been performed.

Corrected98f0d112d compiled with zero errors but one unused catch-variable
warning; the existing CI gate rejected that warning. Use the established bare
catch syntax, retaining the same failure-preserves-state behavior. No warning
policy or compiler gate was changed.
