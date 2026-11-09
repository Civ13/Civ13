# Laundry probe

Native probe for laundry treatments: washing clothes with soap or detergent
leaves a dirt-resistant finish that slows worn dirt for a number of life ticks.

Run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/laundry/probe.dm

Checks: the finish reduces and then stops reducing worn dirt; hand washing uses
soap or detergent from the other hand (lard soap is weaker); a washing machine
takes one dose and spends it on every garment in the finished cycle; the finish
and a loaded dose are saved fields; and after a load the machine rebuilds its
wash list from the clothes inside.
