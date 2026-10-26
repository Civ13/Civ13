# Dictionary era checks

Offline checks (use a verified full Python executable on Windows):

```text
<python> -B -m unittest discover -s tests/dictionary_era -p test_sources.py -v
<python> -B tests/dictionary_era/prepare.py --output <fresh-temporary-directory>
```

The tests check production guards and rejected omission controls, exact legacy
speech/whisper whole-file projections, loader wiring, unchanged dictionary data,
and deterministic preparation/source hashes. They do not execute DM semantics.
The test's legacy file hashes bind the reviewed unchanged speech bodies and default
dictionary; unrelated future changes to those files need explicit reconciliation.

The normal CI offline baseline registers `test_sources.py` and
`test_slang_content.py` and `test_phrase_mode.py` for dictionary source/configuration changes. Content tests
model ASCII case-insensitive literal/phrase replacement and era eligibility offline;
they do not execute BYOND. They check the pinned editorial row inventory, legacy
preservation, duplicates, fragment boundaries, cycles, cascades, all matching and
nonmatching eras, multiple substitutions and compatibility overlap. Negative
controls reject unsafe padding, conflicting definitions and cyclic/cascading rows.
The baseline does not register the preparer or DM probe as
executables, and does not change introduced-suite or native admission policy.

Preparation only writes source and a manifest. It has no compiler/runtime runner.
The generated fixture uses the actual dictionary parser/helper, production text
helpers, and production speech prefixes. Old replacement loops provide a native
legacy-output comparison. An inert map datum replaces game metadata; no normal
world startup, mobs, listeners, radio routing, saves or external services run.
Geometry is 1x1x1. Source hashes use UTF-8 with normalized LF; statuses remain
`not_run` until separate evidence establishes native execution.

The prepared native assertions compare all 66 original entries against the full
legacy-plus-wiki pipeline across nine eras. They also check every appended entry
in matching/nonmatching eras through both speech prefixes, multiple substitutions,
and adjacent phrase matches. The existing checks cover
sanitization/case parity in both prefixes, all 81 selector/active-era combinations,
era zero, malformed/empty selectors, selector CRLF/whitespace, source/replacement
whitespace, ordered cascades, duplicate sources, live era changes and missing map.
Invalid-input assertions intentionally emit parser diagnostics; an authorized
runner must reconcile those expected lines and reject unexpected diagnostics.
The fixture closes/refuses ports and clients; these source controls are not an
external zero-listener observation. Require separate approval and existing process
containment before any native execution. Target compiler is the repository's
`tools/byond/version.json` (currently 516.1688).

Remaining acceptance: native compile and fixture results, default game compile,
independent review, hosted CI results, and any full-game/client checks
needed to resolve remaining uncertainty. This patch does not activate native CI
or authorize a launch, push, merge, deployment or restart.

Phrase-mode checks also cover all 128 ASCII neighbor values, conservative Unicode
neighbors, standalone/edge/punctuation matches, repeated adjacent matches, mixed
literal/phrase order, malformed modes, literal metacharacters and no inserted-output
rescan. Source omission controls bind the scanner and exact delimiter allowlist.
The fixture includes production parser/scanner functions unchanged; native compile
and execution results remain separate from the offline model.
