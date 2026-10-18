# Optional gameplay help checks

`run.py` also executes `render-cases.json` through the actual production
`render_answer()` and Markdown helpers. Cases cover the reported winter-help
bullet/bold answer, headings, numbered/indented lists, paragraphs and CRLF,
code-span/fence precedence, unmatched input, raw HTML, encoded injection,
unsafe/obfuscated link schemes and image suppression. `render-results.json`
retains the actual HTML. `render_contract.py` independently checks required
text, forbidden output, balanced allowed tags and HTTP/HTTPS-only attributes.
`test_markdown.py` proves the oracle rejects injected markup/unsafe links and
malformed structure. The existing escaping mutation now removes the actual
Markdown text encoder and must still fail its original escaped-HTML assertion.
These checks do not prove native browser layout; verify the actual Help dialog
separately under an exclusive UI allocation, without contacting a model for the
deterministic rendering cases.

`run.py --byond-bin <516.1681-bin> --prepare-only --output <new-directory>`
writes the exact fixture and hashes without compiling or starting BYOND. This
supports an external coordinator's bounded process supervisor while a native
resource hold is active. The normal runner retains its existing CLI behavior.

Run Python bridge tests with `python3 -m unittest discover -s tests/player_help -v`.
`python3 tests/player_help/run-spool-controls.py` requires temporary source
mutations of the old ID validator, admission marker and completion marker to fail
the native scientific-notation ID plus CRLF round trip. The spool tests also
reject malformed/oversized IDs, path or command characters, embedded/repeated
line endings and stale completion markers. These use injected model transports.
All storage is temporary and HTTP is an injected transport; no remote Ollama calls.

`test_recipe_context.py` checks the actual primitive-sawmill legacy catalog row
against its material recipe and captures the real bridge prompt through an
injected transport. Exact Material condition grammar maps floor/one-per-tile
0/1 flags to surface/duplicate rules and labels deciseconds as a base simulation
duration adjusted by strength and crafting (crafting squared), with rounding and
interruptions. All recognized installed Material rows retain their research/map
gate clauses. Unknown, malformed and unrelated conditions are not reinterpreted;
expansion beyond the existing 500-character budget reports unknown requirements
instead of silently dropping a gate. Existing recipe/prompt/privacy bounds stay
in force. These tests generate no model answer and do not establish live answer
quality. The running helper builds its corpus at startup; source changes need a
separately reviewed helper reload before they can affect it. No game build or
catalog regeneration is needed for this legacy-catalog formatting correction.

The transport deadline test verifies the child-process timeout contract, not a
network benchmark. Cases cover identity reuse, no replay, disabled/failure,
bounded answers, no source metadata and exclusive worker ownership.

Run `run.py --byond-bin <516.1681-bin>` and repeat with
`--negative-control escaping`, `heartbeat`, and `identity`. These compile the
actual production DM help service with minimal process/global adapters and no
normal world startup. The native fixture verifies heartbeat startup/expiry,
malformed files, escaped HTML, request identity and disconnected-slot cleanup.
It closes its port immediately and uses isolated disk files.

Client ownership and absence of a duplicate mob verb are source-checked. The
production verb/helper bodies run relocated to a mob proxy with injected
connected/input/submit boundaries. The submit adapter calls actual server enqueue;
same-account proxy reuse checks admission, not real login or body transfers. The probe
checks prompt-first unavailable handling, cancellation without allowance,
ready request publication and failure cleanup. Native input/browser delivery
and client timeout notification, login/reconnect and body transfers remain
unverified by this isolated fixture.
No remote endpoint, deployed bridge or model knowledge is tested. Game compilation
is separate; screenshots are unnecessary for these file/protocol contracts.

CI selects this suite when its executable tests are newly introduced by this PR,
or when extensive regressions are explicitly enabled. Ordinary future edits do
not enable existing regressions automatically.

The native probe checks season/time, asking-human condition, active fire and detached fresh snapshots. `--negative-control player-context` replaces real health with a constant and must be rejected. Bridge tests verify the final prompt carries projected context while excluding identities, diagnoses, unrecognized effects, booleans used as numbers and nonfinite values. These are production-path fixtures with minimal human/area adapters, not client or complete-world acceptance.

The combined inventory budget probe counts entry and child visits in a generated
copy of production code. A bag with 70 non-item children must stop at exactly 64
combined inspections; `--negative-control inventory-budget` restores the faulty
doubled-child counter and must fail that boundary assertion.

Rate-limit probes exercise production account reservations, cooldown, burst and
long-window quotas, account-state capacity, global quota/queue saturation,
disconnect retention, timeout, response failure and write-failure cleanup.
Repeat with `--negative-control rate-limit`, `prompt-first` and `disconnect` to
remove those guards in generated source. Each must fail its named assertion
without runtime errors. `--output <new-directory>` preserves logs and source
hashes. These probes never connect to the retained game or an external LLM.

The Python suite also calls the real bridge dispatch boundary directly with
injected transport/clock: rapid repeats, account continuity, concurrency,
global saturation, state capacity/expiry and transport timeout are covered.
`run-bridge-control.py` removes admission from generated production source and
requires the direct rapid-repeat assertion to catch it. Account hashes must
never appear in the captured model payload.
