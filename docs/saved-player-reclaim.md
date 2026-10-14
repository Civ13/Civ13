# Saved player bodies

World persistence excludes `client`, `key`, `ckey` and HUD objects. A connected
human instead records a canonical `persistence_owner_ckey`. Normal human Login
and save preparation retain one body claim per authenticated account and clear
superseded claims. Physical inventory stays in the normal saved contents graph.

Import validates ownership encoding and rejects duplicate accounts across all
levels before clearing the world. Only actually restored human bodies enter the
runtime claim registry. Claims remain unavailable until the complete world and
metadata load succeeds. Failed restoration resets the registry.

A connected lobby client claims its unique body through the ordinary living
Login path, which rebuilds HUD and updates its mind. Later lobby logins use the
same path. A different account, ambiguous ownership, occupied or dead body,
unfinished load, or persistence error cannot claim a body. Reclaim reserves the
claim before assigning the authenticated client's key without a intervening
wait. It preserves location, inventory and medical state; owned bodies bypass
the historical import rejuvenation.

## Older generations

An old `lastKnownCkey` is login history, not a durable body claim. Older saves
without explicit ownership still load, but do not automatically attach a client.
Never infer ownership from character name, position, or first/last matching
history. The current legacy test generation requires a separately reviewed,
generation-bound migration identifying the authenticated client's exact saved
body. Preserve the original generation and record source hashes, entry identity,
provenance and the derived generation's hashes. Migration and actual client
control acceptance are separate from fixture success.

## Verification

`tests/world_save/run-string-path.py` exercises actual production owner export,
import, unchanged medical state and nested inventory, load readiness, account
matching, duplicates, native key occupancy, dead bodies and failed-generation
guards. `--player-reclaim-negative-control owner|state|duplicate|ready` mutates
generated source only and requires each exact failure. These offline checks have
no real client and cannot prove HUD reconstruction or player control. The sole
runtime owner must verify those with the actual saved world and launcher.
