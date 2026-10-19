# Restored-round faction browser assets

The accepted `60748fdfebdc0070580f14652c61723525fb1b5b` source registers
NanoUI resources only from its roundstart hook. Restored active rounds skip
that hook. `get_asset_datum()` previously constructed an unregistered datum,
so Create Faction could browse an empty shell without its JavaScript, CSS and
main template. The client startup's small legacy template list does not include
these assets. This can produce a blank white browser without a server runtime.

The getter now registers a newly constructed asset datum before returning it.
`New()` has already published its identity, and the existing register bodies
do not call the getter. Cached lookups and normal roundstart remain unchanged.
There are no faction, permission, Topic, save-format or gameplay changes.

Source/offline checks (no native compiler or browser):

```powershell
py -3 -B -m unittest discover -s tests/faction_ui_assets -v
node tests/faction_ui_assets/check_templates.mjs
py -3 -B tests/faction_ui_assets/run.py --prepare-only --evidence-dir <fresh-path>
py -3 -B tests/faction_ui_assets/run.py --prepare-only --omit-registration --evidence-dir <other-fresh-path>
```

The JavaScript check executes the actual repository doT/NanoTemplate/helpers
against creation/editor/basic templates with an injected data/bootstrap boundary.
It verifies a complete 1,024-cell canvas and action hrefs. It does not run a DOM,
browser resource delivery or native client.

The prepared native fixture compiles the full production DME without maps or
normal startup. It calls actual restored-phase ticker setup, the Create Faction
verb, wizard data construction, NanoUI constructor/get_html, asset getter,
directory registration and cache APIs. A read-only counter observes registration.
Inert actor/map constructors and a UI subtype capture the browse boundary. The
fixture never founds a faction, sends a game Topic or admits a client; its port
always closes and its Topic returns nothing. Repeated disconnected sends test
the existing no-client path, not client delivery acknowledgements.

Only the coordinator may use the exclusive native slot:

```powershell
py -3 -B tests/faction_ui_assets/run.py --byond-bin <516.1681-bin> --evidence-dir <fresh-path>
py -3 -B tests/faction_ui_assets/run.py --byond-bin <516.1681-bin> --omit-registration --evidence-dir <other-fresh-path>
```

There are 18 native checks. The control removes only the new registration call
and must fail exactly the five named cold-registration/resource checks; unrelated
diagnostics, timeout, wrong counts or missing completion invalidate it. The normal
roundstart hook itself is checked separately after cold-cache evidence is frozen.

Native execution exports actual `get_html()` to `browser/index.html`, the actual
cache resources beside it, and actual initial data to `draft.json`. Root can render
that isolated bundle in its controlled browser session, serving that directory
with its existing local fixture server if file AJAX is restricted. Compare the
positive bundle with the omission bundle, which retains only the HTML shell and
one fixture sentinel. Do not navigate a live game or reuse live session references.
Expected positive DOM: “Found a new faction”, name controls, 1,024 `.fs-cell`
elements and the founding button. A static browser render establishes layout and
script/template boot, not connected BYOND delivery or permission enforcement.

Native, browser and client checks are pending until separately executed. Source
preparation is never reported as a native or live fix acceptance.
