# Research bench maintenance

`python3 -m unittest discover -s tests/research_bench -v`

The offline projection executes complete production `attackby`, `maintain_bench`,
`Destroy`, coin identification and faction bench-count procedures. It covers:

- Harm + wrench fastening/unfastening and Harm + hammer dismantling, including
  idle and maximum-tier benches and ordinary faction members without staff roles.
- Help tool samples, existing Disarm/Grab research behavior, staff and research
  gates, books, prototypes and the idle-coin upgrade route.
- Wrong-faction, unclaimed, factionless and non-human refusal, canceled waits,
  changed ownership/intent/tool/reach, deletion and competing wrench actions.
- Existing movement/disassembly flags and cable guards before and after waits.
- Generic one-wood-stack salvage and registry removal freeing only the owning
  faction's bench slot, without resetting faction research.
- The always-visible examine hint and three source mutation controls for intent,
  post-wait ownership and registry cleanup.

The tests use production research constants. Engine time, inventory/range,
messages, constructors, deletion and research-map APIs are explicit adapters.
Coin charging itself is outside the fixture; its existing entry point is checked.
These are source-control-flow checks, not DM compilation, native timing, client
interaction, gameplay or save/load acceptance. No server or compiler is launched.

The `research_bench` suite is registered in `scripts/ci_baseline.py`. Production
research source retains its conservative all-offline-suite selection; test-only
changes select this suite. Hosted native admission is not added by this fix.
