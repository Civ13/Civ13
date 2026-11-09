# Recipe book distribution regressions

Run `python tests/book_distribution/run.py --byond-bin <516.1688 bin>` only with
explicit authorization for the isolated native runtime. `--compile-only` does
not launch DreamDaemon. The fixture uses a temporary world with no listening
port, no ordinary startup and no live saves. It retains its evidence directory.

The complete production source is compiled. The fixture replaces only the
client-presence predicate and action waits, and uses a human subtype that skips
physiology and simplifies inventory transfers. It executes resource validation,
post-wait cancellation and research changes, printing, timed teaching segments,
chapter-ID sanitation and native savefile strings, cache bounds/cooldowns and
shop flag/price/stock rules. The shortened waits and absent clients are not
real-time multiplayer or graphical acceptance. The chapter savefile test is not
a production whole-world compendium round trip.

Offline `python -m unittest discover -s tests/book_distribution` checks source
wiring, durable fields, explicit bounds and the absence of map placements.

The extended `tests/recipe_knowledge/game.dm` covers compendium IDs and cache
cooldowns through the actual production Save_World/Load_World path. Its runtime
result must be reported separately; compile-only is not save/load evidence.
