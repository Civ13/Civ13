# Save, restart and resume

Server admins with `R_SERVER` can use **Server > Save, Restart and Resume** on
native BYOND Gaia and Europe. Confirming starts one transaction: complete a world
save, validate every level and the durable round metadata, publish and read back
`map_saves/restart_intent.json`, then immediately request the native reboot.
Startup restores that exact generation and deletes the intent only after the
world, player ownership, round state, metadata and durable timers load successfully.
The next ordinary startup does not replay a consumed intent. This also works
when the server configuration does not select the PERSISTENCE gamemode.

Stop gameplay before confirming. The existing serializer yields while saving;
this command does not provide a globally atomic gameplay snapshot. The completed
generation is the recovery point. Actions during serialization may not survive.
There is no additional 15-second reboot window after validation. Players receive
save progress and a restart/reconnect notice. Native parent `world.Reboot` retains
the engine's shutdown and automatic client relogin behavior. Ordinary reboots
retain their existing delay and scheduler shutdown path.

## Failure and recovery

- A failed save or validation leaves the server running without requesting a
  reboot. Concurrent saves, imports and restart transactions are rejected.
- A returned/rejected native restart releases transaction guards and removes
  only its matching intent. If removal fails, the admin error explicitly says
  cleanup failed. Gameplay can continue, but saves and imports cannot overwrite
  the unresolved recovery point. Preserve the files and inspect the intent before
  deliberately removing it from the host. Never remove an intent from a running
  startup recovery hold to start a fresh round.
- A crash after intent publication resumes the intended generation on startup.
  Missing, malformed, mismatched or incomplete generation files produce a recovery
  hold rather than starting a fresh round. The server stays available for admin
  diagnostics; character admission/reclaim, round startup, world clocks, durable
  callbacks, saves and scheduled maintenance reboot cannot progress through the hold.
- Preserve the entire `map_saves` directory before repairs. The intent binds the
  completion nonce and hashes of `map.txt` and `round.json`; do not edit the nonce
  to fit unrelated files. Restore the matching generation from a known backup.
  **Server > Resume Pending Recovery** retries validation if import has not begun.
- Once an import has begun and failed, do not retry it in the partially replaced
  world. Stop that host and restart the original compiled map with the repaired,
  matching save and retained intent. There is no automatic retry/reboot loop.
  If only deletion after a successful import failed, the same admin command retries
  consumption without importing the world a second time.

Manual Save Map and Load Map retain their legacy formats and behavior outside an
active transaction or unresolved intent. Existing persistence-mode autoload skips
its ordinary path when an intent owns startup. OpenDream is rejected before saving;
its supervisor protocol is outside this native transaction's acceptance.

The round-start webhook and OOC log entry wait for the startup decision. Fresh
rounds use the generated ID; an automatic, manual or intent-driven recovery sends
only after successful import and validation that the saved ID matches the active
ID. A process sends at most one notice. Failed or incomplete recovery, including
unreadable or different-map save metadata, sends no notice; a later successful
manual recovery can send it. Legacy saves without a
historical ID cannot supply an authoritative ID, so their notice is suppressed.
Webhook transport remains asynchronous and does not guarantee delivery.

## Verification boundary

`tests/world_save/run-restart-transaction.py` compiles the production state machine
and immediate reboot guards with isolated filesystem, saver/loader and native
restart adapters. It does not reboot a real game. Its generation, consumption and
import and deferred-reboot mutation controls must fail their specific assertions.
The deferred path uses the production reboot body, shortens its initial delay,
activates transaction ownership during its final yield, and injects only native
restart/scheduler effects. A full-map native
save/restart/rejoin test remains separate acceptance, including the native parent
reboot behavior on BYOND 516.1681. This change makes no save-speed claim.
