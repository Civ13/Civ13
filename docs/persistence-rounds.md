# Continuous persistence rounds

Persistence rounds keep playing across server sessions. Explicit administrative
save/restarts and configured daily maintenance save/restarts remain available;
loading resumes the saved round. Victory conditions and automatic map rotation cannot finish
the round. Restart votes are unavailable; after play begins, map, epoch and game
mode votes are also rejected. Existing votes of those kinds are cancelled before
their results or callbacks can change the round. Ordinary custom polls remain
available, and the initial lobby can still select a map and epoch.

The policy applies when `map.persistence`, `map.perschadplus`, or the configured
`PERSISTENCE` game mode is active. Other game modes retain their usual ending and
voting behavior. Administrative save/restart operations remain separate from
round-ending votes; this change does not create a save or install server updates.

Implementation: [vote policy](../code/datums/vote.dm),
[ticker completion](../code/game/gameticker.dm),
[automatic rotation](../code/processes/mapswap.dm), and
[map victory checks](../code/game/objects/map_metadata/_map_metadata.dm).
Verification and limits are recorded in
[the regression suite](../tests/persistence_round/README.md).
