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

Guests can still use ordinary gameplay when server configuration allows it,
but never receive durable ownership. Canonical guest ownership in a saved file
is rejected. Reclaim checks both Playing and Server bans before consuming any
claim, so rejected clients retain their lobby and the body remains unclaimed.

## Older generations

An old `lastKnownCkey` is login history, not a durable body claim. Older saves
without explicit ownership still load, but do not automatically attach a client.
Never infer ownership from character name, position, or first/last matching
history. The current legacy test generation requires a separately reviewed,
generation-bound migration identifying the authenticated client's exact saved
body. Preserve the original generation and record source hashes, entry identity,
provenance and the derived generation's hashes. Migration and actual client
control acceptance are separate from fixture success.

`build-player-migration.py` compares every saved human against the recorded
single live client's account audit, exact type, name, state, coordinates and
all direct physical inventory types/names. It requires one match, binds its
exact native serialized contents/fields to all four generation hashes, and
records the observation's limits. Review this concrete manifest before passing
it to `build-generation-inspector.py --migration-manifest`. Native execution
then checks the full saved fingerprint and account again, writes only the owner
field in a fresh derived copy, and runs the production validator. Original
generations stay untouched. No test adapter assigns a player's key.

## Verification

`tests/world_save/run-string-path.py` exercises actual production owner export,
import, unchanged medical state and nested inventory, load readiness, account
matching, duplicates, native key occupancy, dead bodies and failed-generation
guards and absence of optional legacy owner fields. `--player-reclaim-negative-control
owner|state|duplicate|ready|legacy|ban|guest` mutates
generated source only and requires each exact failure. These offline checks have
no real client and cannot prove HUD reconstruction or player control. The sole
runtime owner must verify those with the actual saved world and launcher.

`--player-admission` runs the actual production reclaim flow with injected
client and key-transfer effects. It checks Playing/Server bans and guest
rejection preserve the lobby/claim, and an eligible admission reserves/transfers
once without changing physical inventory. This is adapter evidence, separate
from the real client reconnect acceptance.
