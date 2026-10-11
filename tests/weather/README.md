# Winter survival regression

Run with BYOND 516.1681 and a verified Python interpreter:

```
python tests/weather/run.py --byond-bin <BYOND-bin>
python tests/weather/run.py --byond-bin <BYOND-bin> --baseline
python tests/weather/run.py --byond-bin <BYOND-bin> --negative-control
```

On Windows use an absolute Python executable, never the Store alias. The runner
compiles complete production sources, retains global initialization and actual
human/clothing constructors, disables normal world startup, copies configuration
into isolated storage, closes the fixture's port and replaces organ damage with
an accumulated damage adapter. The fixture invokes production `handle_environment`,
`stabilize_body_temperature`, `get_temp`, insulation and species discomfort procs.
No production save, restart, player connection or external action is involved.

Results are in an ignored unique `data/weather-*` directory: compiler/runtime
logs, metadata, tested patch and CSV. Generated DME/DM/DMB/RSC files are unique
and removed even after failures. The daemon has a 60-second wall limit. Any
runtime error or missing completion invalidates a passing result. An OS sandbox
can terminate native DreamDaemon before world startup; do not count that as a
successful run. On Windows these tests were run outside that process sandbox.

Each iteration is one nominal one-second Life step, matching
`code/processes/mob.dm`. These are accelerated calls, not measured elapsed player
survival or full scheduler acceptance. Damage numbers accumulate actual damage
requests without health, organ healing, metabolism, movement or death side effects.

The comparable uniform is a fixture-rated torso/arm/leg layer (200 K minimum),
the coat is the real fur-coat template, and full coverage adds head/hand/foot
coverage at 160 K. The fixture also checks an unmodified ordinary uniform, its
240 K limit and the existing protection-disabled state. Actual Mayan loincloth
and Celtic shorts templates retain lower-torso-only insulation. Underclothing
insulation intersects physical coverage and any declared thermal mask.
This separates coverage
math from catalog ratings without granting equipment to live players.

The `--baseline` mode loads the three original thermal/clothing sources from
`e4967a4e0`. Before tuning, naked first damage was 27 nominal calls, coat/uniform
42, overlapping layers also 42, and full coverage had zero damage over 3,600.
With real human construction in the final fixture, tuned results were:

| Case | Calls | First cold harm | Accumulated damage |
| --- | ---: | ---: | ---: |
| Naked, temperate winter | 600 | 264 | 387.56 |
| One rated layer or fur coat | 600 | 470 | 72.05 |
| Overlapping layers | 600 | 567 | 18.70 |
| Full dry coverage | 3,600 | 2,184 | 70.85 |
| Full coverage in rain | 1,200 | 302 | 44.95 |
| Full coverage, tundra | 2,400 | 1,458 | 11.65 |
| Full coverage, blizzard | 600 | 174 | 362.95 |
| Layered shelter during blizzard | 600 | 0 | 0 |

Shelter improves the same outdoor exposure. A lit brazier prevents new cold
harm, dries wet insulation and recovers a 250 K patient to normal temperature.
Immersion saturates wetness at one. Wetness is a durable bounded mob scalar,
not a timer or retained reference. No timestamp needs custom-save exclusion.

The negative control restores the old divisor only in a generated copy while
retaining the new maximum cooling rate. It must fail the ten-minute cold-damage
response-window assertion. CI runs the normal and negative-control probes on
every game-selected build; other extensive suites remain opt-in.

No sprites or rendering assets change. Source review and runtime checks cover
this arithmetic change; graphical capture is unnecessary unless new interaction
or rendering uncertainty emerges. Full-world long-duration memory, live gameplay,
lag-dependent scheduler behavior and production survival are not established.
