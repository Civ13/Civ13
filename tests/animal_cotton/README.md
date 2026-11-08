# Animal cotton diet

Run `python3 -m unittest discover -s tests/animal_cotton -v`, or the registered
CI suite with `python3 scripts/ci_baseline.py unit --suite animal_cotton --output /tmp/animal-cotton.json`.

Cotton plants and cotton seeds are only food for ruminants (`ruminant = TRUE`:
cattle, goats, sheep, camels, deer, buffalo and bison). The suite executes the
production `animal_can_eat()` body through the shared source adapter, checks the
crop and seed guards in `check_food()` (eating and walking toward crops) and in
hand-feeding, and checks that no crop-eating (`granivore`) animal is flagged as a
ruminant. This is source/control-flow evidence, not an in-game test.
