# Disease immunity and poison tolerance

`python3 tests/disease_immunity/test_source.py` checks that an illness builds resistance to itself every tick (faster while medicine supports the body), clears once resistance is full and blocks reinfection until it fades, that untreated severe illness reaches natural immunity without a timer death, ordinary flu does not damage the brain, and that repeated toxin doses do up to half damage.

Not covered: a full in-game run. `tests/survival` exercises the severe illness rules in a live world but is pinned to BYOND 516.1681 and times out on the current pin.

Balance: otherwise stable patients recover from named severe illnesses in about 2000 active disease calls (nominally 33 minutes), or about 180 continuously treated calls at full medicine strength. Severe weakness and drowsiness remain, and existing starvation, oxygen loss, injury and infected-organ hazards are not cleared. Zombie disease retains its exceptional lethal transformation. These are game-balance rules, not medical claims.

`python3 tests/disease_immunity/test_check_illnesses.py` checks that the read-only Check Illnesses admin verb and the agent `players` read share one illness summary and change nothing.

`python3 tests/disease_immunity/test_carriers.py` checks that a sick person's drawn blood and butchered raw meat carry their illness (malaria only in blood, worms only in meat, never flu), that cooking kills every germ, that dirty water also brings intestinal worms, that bed rest doubles resistance gain (chairs do not count), that worms build no resistance, never spread, clear with healing herbs or absinthe but not penicillin and pass on their own in about 90 minutes (45 in bed), and that the doctor's handbook names a treatment for each illness.
