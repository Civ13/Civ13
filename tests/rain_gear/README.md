# Rain gear probe

Native probe for rain gear (`code/modules/1713/rain_gear.dm`) and ballistic
plate weight (`code/modules/1713/armor_weight.dm`).

Run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/rain_gear/probe.dm

Checks: rain and wind reads, lean-to shelter, worn layers stacking, the 95%
cap, closed and inside-out umbrellas, grease finishes wearing off only in rain,
capes fastened over a coat or uniform and returned intact, wet slowdown only on
settlement maps, fire drying, umbrella shade, and plate weight in a carrier.
