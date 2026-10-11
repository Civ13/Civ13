# Train collision regression

## Confirmed defect and scope

Connections point from a leading wagon to its follower. Opposed adjacent wagons can be hitched in both directions on baseline master `0d38999d5f9f987a944493f11c456537f39ac2f6`, forming a cycle. `Move()` recursively follows that cycle even after failed parent movement. Unhitch also clears the wrong connection. These are confirmed defects; the reported production hard-crash cause is not established.

On Windows BYOND 516.1681, actual opposed hitch calls followed by movement produce `Maximum recursion level reached` in `check_connections`/`Move`. The END marker is not reached and the 15-second watchdog terminates the owned daemon. With loop checks disabled at compile time, the baseline does not finish or log a runtime before the same watchdog. Neither result proves a native process crash. The persistence-beta startup contains an attempted runtime assignment to `loop_checks`; the tiny 516.1681 probe rejects runtime assignment, so its effective production setting cannot be inferred from that code alone. BYOND documents that unchecked infinite recursion can exhaust the stack: https://www.byond.com/docs/ref/info.html#/world/var/loop_checks

## Behavior

The patch prevents cyclic hitching, disconnects the actual leader on unhitch, guards recursive/reentrant wagon movement, and returns failure before carrying riders/cargo/followers after blocked movement. Train bump callbacks cannot start a train push cascade. Ordinary human pushing remains allowed. Automatic train contact, including contact with another car in its consist, retains the existing stop and five-health damage rule. No collision damage is globally disabled.

## Safe replication

Use an isolated checkout and BYOND 516.1681; never run the baseline against production.

- Normal regression: `./tests/train_collision/run.ps1 -ByondBin <bin>`.
- Checked baseline: add `-Revision 0d38999d5f9f987a944493f11c456537f39ac2f6 -Baseline`.
- Unchecked comparison: add `-Unchecked` to either command. This deliberately produces the compiler's loop-check warning; it is fixture-only.
- Linux: after loading the pinned BYOND environment, run `bash tests/train_collision/run.sh`.

The generated 20x10x1 fixture extracts production train procedures, replaces audiovisual resources with null, and injects no-op map/effect adapters plus the deferred bump callback. Windows processes are bounded by 15 seconds, 5 CPU seconds and a sampled 256 MiB working-set ceiling; Linux uses timeout and CPU/address-space limits. The runner stops only its own PID, waits for exit and prints temporary log paths. A sampled ceiling is not a Windows OS hard memory limit. No production storage or train is touched.

Thirty assertions cover actual hitch/unhitch, cycle rejection, malformed existing cycles, three-car movement, blocked movement, cargo/riders, head-on/rear/side train contact and deferred bumps, same-consist contact, deleted followers and normal automatic movement. Fixture results do not prove full-game integration or visual behavior. Full `civ13.dme` compilation on 516.1681 separately passed with zero errors/warnings.

## Gameplay acceptance still required

In an isolated local game at the final commit, place a locomotive and two wagons on straight rails. Hitch the rear cars and run the train, verifying following positions and transported cargo. Stop it, oppose adjacent wagons and attempt reciprocal hitching; the second hitch must fail. Unhitch must release the front car's connection. Exercise head-on, rear and side contact between independent trains, plus a blocked route and self-consist contact: movement must stop, collision health loss must remain, and the server must remain responsive. Capture genuine before/after screenshots and a movement/collision video linked to the tested commit/map and steps. Upload as verified PR attachments, without committing media. Graphical evidence is outstanding.
