# Restored-round faction browser assets

The accepted `60748fdfebdc0070580f14652c61723525fb1b5b` source registers
NanoUI resources only from its roundstart hook. Restored active rounds skip
that hook. `get_asset_datum()` previously constructed an unregistered datum,
so Create Faction could browse an empty shell without its JavaScript and CSS. This can produce a blank white browser without a server runtime.

The getter now registers a newly constructed asset datum before returning it.
`New()` has already published its identity, and the existing register bodies
do not call the getter. Cached lookups and normal roundstart remain unchanged.
There are no faction, permission, Topic, save-format or gameplay changes.

Source/offline checks (no native compiler or browser):

```powershell
py -3 -B -m unittest discover -s tests/faction_ui_assets -v
py -3 -B tests/faction_ui_assets/run.py --prepare-only --evidence-dir <fresh-path>
py -3 -B tests/faction_ui_assets/run.py --prepare-only --omit-registration --evidence-dir <other-fresh-path>
```

The unique guarded CI step, immediately before the optional player-help step,
runs these checks and both native profiles only for this introduced suite or
explicit extensive mode. The selection regression uses real temporary Git
commits to distinguish an added substantive DM helper from edits and pushes.

The prepared native fixture compiles the full production DME without maps or
normal startup. It calls actual restored-phase ticker setup, the Create Faction
verb, wizard data construction, shared TGUI opener, constructor/get_html,
asset getter, registration and cache APIs. Read-only counters observe
registration. The modern window first checks only its own versioned resources,
then the fixture separately exercises classic NanoUI's cold getter.
Inert actor/map constructors and a UI subtype capture the browse boundary. The
fixture never founds a faction, sends a game Topic or admits a client; its port
always closes and its Topic returns nothing. Repeated disconnected sends test
the existing no-client path, not client delivery acknowledgements.

Only the coordinator may use the exclusive native slot:

```powershell
py -3 -B tests/faction_ui_assets/run.py --byond-bin <516.1688-bin> --evidence-dir <fresh-path>
py -3 -B tests/faction_ui_assets/run.py --byond-bin <516.1688-bin> --omit-registration --evidence-dir <other-fresh-path>
```

There are 21 native checks. The control removes only the new registration call
and must fail exactly the eight named cold-registration/resource checks; unrelated
diagnostics, timeout, wrong counts or missing completion invalidate it. The normal
roundstart hook itself is checked separately after cold-cache evidence is frozen.

Native execution exports actual `get_html()` to `browser/index.html`, the actual
cache resources beside it, and actual initial data to `draft.json`. The page is
the modern tgui shell; there is no classic template renderer.

Native, browser and client checks are pending until separately executed. Source
preparation is never reported as a native or live fix acceptance.

## Emblem editor regressions

Run the isolated emblem probe with the repository's pinned BYOND:

    python3 tests/ecology_spawning/run_linux.py . tests/faction_ui_assets/emblem_probe.dm 300

This validates the shipped Big Cross pixels, the real editor paint and Undo
actions, real NanoUI window identity and refresh data, rename reuse, and
retirement after a faction change or loss of the leader verb. It registers
the first UI at the absent browse boundary; it does not show a game client.
