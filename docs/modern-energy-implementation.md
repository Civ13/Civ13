# Modern solar generation

Solar array controllers require the Modern era, completed Digital Computing,
crafting skill 105 and 20 electronics. Build the controller outdoors, attach
 a cable coil to connect it to a matching adjacent cable, then use the controller
to enable generation. Cut the cable before unfastening it with a wrench.

Clear midday output is 30 PU. Morning and evening output is lower; wet, smog
and extreme weather reduce it further. Indoors, night and unknown time labels
produce no output. Charge accumulators during daylight for later use. The
existing solar_screen DMI state represents the controller.

One shared scheduler supports at most 128 registered generators. Output expires
after one second; delayed processing does not backfill missed generation.
Connected demand is reserved before accumulator charging, and charging debits
each interval's remaining source budget. Toggles and reconnects cannot replay
spent output. Movement, deletion and reload stop generation. Runtime wiring,
registration and charge/output ledgers are excluded from saves.

Solar source commit 602d6654f57308bbfa72c1eb334b69a1cb4b794a passed pinned
BYOND 516.1681 compilation and native isolated generation/storage, crafting,
save restoration and omitted-charge-debit negative-control checks in
[CI run 38408275121](https://github.com/Civ13/Civ13/actions/runs/38408275121).
These checks establish bounded production contracts, not full-game graphical
acceptance, sustained balance or deployment. No local native runtime was used.

Nuclear machinery and its pending-acceptance player fuel acquisition route are
separate draft work in [PR #3141](https://github.com/Civ13/Civ13/pull/3141).

## Nuclear draft boundary

PR #3141 adds finite cartridge fuel, coolant, wear, maintenance, safe controls and
bounded local heat effects. Native isolated contracts at 1679a19c7d6cf738ee27e9b424a6faaca7d376ba
passed CI run 38410067410, including an omitted-fuel-debit negative control.
The draft now implements a finite uranium-only fallback after existing common
underground mining outcomes in the Modern era. A paid processor consumes one
raw ore unit per sealed 1800 PU-second cartridge; canceled or invalidated work
must consume nothing. Processing and both machine recipes require Nuclear Power
research and crafting 105. The processor costs 20 steel; the reactor costs 40
electronics. The geiger-counter prerequisite uses the existing Factories node.

Raw uranium emits one local radius-3, severity-7 pulse each second on its source
z-level. Lead crates shield it. Retirement stops its single callback chain;
the opt-in local pulse cannot change global radiation. Existing default pulse
callers retain their behavior. Chemical extraction pays one ore unit for the
existing five reagent units and preserves the remaining stack.

The reactor exposes a safe final fuel/coolant interval until normal output
expiry. Its next settlement stops on exhausted inputs. An interval that would
reach the heat or wear safety limit is rejected before spending inputs.

These changes still require current exact-head remote native tests and the
radiation owner's final review. Ordinary-player route acceptance, sustained
balance and deployment remain separate from isolated fixture results. PR #3141
remains draft until the route acceptance is resolved.
