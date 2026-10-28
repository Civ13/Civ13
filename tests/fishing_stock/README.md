# Fishing-stock completion source contracts

Run from the repository root:

```sh
python3 -m unittest discover -s tests/fishing_stock -p 'test_*.py' -v
```

This suite is **offline source and model evidence**, not DM execution. It extracts
the three production `attackby` completion blocks and rejects changes outside its
reviewed, indentation-sensitive subset. A bounded Python projection covers stock
admission, the existing chance/debit/product ordering, contested completions,
cancellation, failed bites, species selection and a refill between completions.
Removing each route's new guard independently reproduces a deficit in the model.

The immutable pre-fix source at
`083cbf20f0d64abffdbef9b478bf1eda74458f65` admits two actors against one remaining
fish; after two successful waits/bites it can decrement twice and create two fish.
All nine ordered pairs of modern rod, ordinary pole/net and sharpened-branch
routes reproduce `counter=-1`, two products and two refill callbacks in the
source-bound projection. The changed source returns immediately when the stock
is empty after a successful wait, before its chance roll, message or debit.

The patch preserves the 120/150/120 waits and 40/30/20 percent chances for stock
that remains available. Empty entry and cancelled waits still do not roll or
debit. Product construction remains after the debit. No callback owner, refill
delay, capacity, species, fish cage or persistence policy changes are included.

Actual DM scheduling, `do_after`, chat effects, constructors, deletion and
save/load are not executed by these tests. Compile/native acceptance is still
required before claiming an engine-verified fix. The present refill procedure's
save/reload lifecycle needs a separate policy and source review; a passing model
does not establish sustainable fishing rates or aquaculture.

## Isolated native completion fixture

`prepare_only.py` extracts the byte-identical production `fish/attackby` from
`76406ef6d26e2fd01fa3a3fbf87d4bded0577417` (Git blob
`2a8a7803320d1ba5987bf986e718c6a59bd4303e`) and fails closed on source/template drift.
It builds four standalone targets: the candidate and one exact two-line guard
omission per route. Each target has 24 cases: nine ordered competing route pairs,
three cancellations, three failed bites and nine route/species successes. Each
omission must fail exactly its three outer-route pairs; unrelated failures and
unexpected passes are rejected.

The fixture executes the extracted DM procedure, but **does not execute real
`do_after`, chance generation, chat, food constructors, refill timers or a game
world**. A controlled nested wait adapter completes a second actor before the
first resumes, with both admitted against stock 1. Inert product constructors
record subtype/location and stock at construction. This establishes a controlled
completion boundary, not real-player scheduling, multiplayer latency or refill
lifecycle acceptance. The fixture is a 5x4x1 standalone world, not `civ13.dmb`.

Prepare sources without acquiring or executing BYOND:

```sh
python3 -B tests/fishing_stock/prepare_only.py --prepare-only \
  --source code/game/mob/living/simple_animal/friendly/static.dm \
  --output /tmp/fishing-prepared-new --expected-byond-version 516.1688
```

`test_preparation.py` has 14 source/generator/synthetic-receipt checks;
`test_native_runner.py` uses injected process/identity seams and blocks real
process/network calls. Its synthetic passes are explicitly marked
`injected_offline_test=true, native_attempted=false`. They are not native results.
The reviewed `fishing_stock` offline registry explicitly loads these two files
plus the original 13-contract module; it never invokes the native entry point.

## Bounded Linux CI admission

The ordinary PR workflow uses its existing introduced-suite/extensive predicate;
metadata-only informational edits do not admit native work. The opt-in command
requires explicit `--execute` and `--expected-byond-version 516.1688`. It uses the
existing bootstrap's `BYOND/pinned.zip`, `BYOND/byond/bin` and
`.ci/compile/byond-download.json`; it neither downloads nor selects a fallback.
Historical 516.1681 helpers/defaults are unchanged.

The driver pins and reuses the unchanged animal-registry lifecycle helpers:
30 seconds per compiler/daemon, CPU 20 seconds, address space 512 MiB, output
2 MiB, core dumps disabled, owned process-group kill/reap on every exit. Its
coordinator also has a 512 MiB address-space limit and a 280-second aggregate
work budget inside the workflow's five-minute wall bound. There are exactly
four compile/daemon pairs and no retries or live-server operations.

Before every launch, passive identity checks verify the pinned archive,
acquisition receipt and four installed engine members; they do not attest host
loader libraries. Exact tracked checkout inputs and generated source bytes are
recorded and checked again. Each world starts bound to loopback, immediately
closes its port before cases, refuses reopening and rejects clients/Topics.
Acceptance requires the ordered engine loopback-open, closure and completion
logs plus closed-port, zero-client/Topic and cleanup receipts. This is not an OS
listener census or a general network sandbox. No fixture code performs outbound
network I/O.

The workflow retains the generated sources, manifest, bounded logs, process
receipts and summary on success or failure. The original pre-fix model failure
remains distinct from each causal omission control. A native pass may only be
claimed from the exact newly published head's actual compile/runtime receipts;
source preparation or injected offline tests alone do not establish one.
