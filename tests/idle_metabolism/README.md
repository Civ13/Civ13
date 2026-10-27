# Idle food and water consumption

Conscious connected players consume 10% of their ordinary food/water rate after
60 seconds without input, movement or a timed action. Movement, clicks, client
input, combat cooldowns, training and `do_after`/`do_mob` keep normal rates.
Timed actions count independently, including overlapping unrestricted actions;
finishing/cancelling one starts a new 60-second grace period. No world scan or
per-mob timer is added. NPC/disconnected, unconscious, bed sleep, induced SSD and
trait rules retain their existing rates. Hot-weather/desert thirst is still
proportionally higher while idle. This applies only where Life already enables
hunger and thirst; it does not change survival-mode selection.

The factor and threshold are Civ13 tuning choices. The read-only local reference
`D:/GitHub/Pocket-Stronghold-13` at
`a354dae33450a698deeb48238896615f072a5369`,
`code/modules/mob/living/carbon/human/species.dm:1138-1157`, suppresses hunger
while sleeping and applies mood/satiety modifiers. That inspected code does not
establish equivalent awake-idle behavior or water tuning.

Run with pinned BYOND 516.1681 and a fresh output directory:

```text
<verified-python> tests/idle_metabolism/run.py --byond-bin <516.1681-bin> --output <new-directory>
```

Repeat with `--negative-control idle`, `action` and `persistence` in separate
output directories. Controls must fail their specific production contract;
compile errors, unrelated failures and runtime diagnostics are rejected.
The runner extracts the actual Life consumption block, activity helpers,
do_after/do_mob bodies and inherited runtime exclusions. It adapts clock/input,
traits and unrelated infrastructure in a tiny offline world with temporary
storage, disabled hub and a closed listening port. No game startup, live save,
client or external service is used. Hashes, tested head, dirty diff and logs are
recorded. These checks establish isolated arithmetic/activity/exclusion behavior,
not full-game player acceptance or a disk save round trip. Normal PR compilation
checks the complete game; new-suite CI runs this positive case and three controls.

Per Life call, unmodified ordinary food/water loss is 0.0864 each, compared with
0.00864 once idle. Hot-weather water loss is 0.224 active / 0.0224 idle. These
are production arithmetic, not measured elapsed starvation times. Bed sleep
remains 0.0032 each and induced SSD remains zero. Runtime activity clocks/counts
are explicitly excluded on save export and import while forwarding parent rules.
