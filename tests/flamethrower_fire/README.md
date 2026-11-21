# Flamethrower firing guard

`test_incapacitated.py` runs the production `/obj/item/weapon/flamethrower/proc/fire`
body through the shared source adapter, with messages, the fuel tank and
`process_fire` as inert boundaries. A stunned, paralysed, weakened or unconscious
holder cannot discharge a lit flamethrower; an able holder still can.

Run with `python3 -B -m unittest tests.flamethrower_fire.test_incapacitated -v`.
Native click delivery and fire spread are not exercised.
