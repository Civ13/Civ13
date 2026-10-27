# Acceptance and bounded native plan

No native game/client run is authorized by this document. The coordinating owner
must review the bounded plan before any DreamDaemon/DreamSeeker launch. No server
restart, deploy, public activation, live save access, security/network setting or
credential change is needed for design, source editing or compilation.

## First source slice

The independent slice implements finite charge, powered lifecycle admission and
an immutable colony/content snapshot ABI, with no physical actor movement.
Tests must cover exact maintenance/startup boundaries, same-time idempotence,
loss immediately before admission, interruption during startup, late service,
shutdown/restart spending, depleted charge, invalid/fractional input, different
colony/content/era restoration and rejection without mutation. Disk round trips
must preserve charge/identity and restore OFF/disconnected, never runtime clocks.

Offline tests may inspect source contracts and prepare a byte-exact isolated DM
fixture. They are not native execution or gameplay. Compile against the actual
tools/byond/version.json target **516.1688**, retain full diagnostics, and report
compile versus execution separately. Historical 516.1681 probes stay unchanged.

Proposed native fixture for review: one standalone 1x1x1 headless world using only
the production gateway datums and deterministic assertions; no game startup,
assets, maps, clients, bots, SQL, HTTP, shell or live saves. Temporary directory
only; at most one trusted DreamDaemon process, 20-second deadline, bounded logs,
owned-process cleanup. Reject clients, disable hub visibility, close the port and
refuse reopening. An external socket census must prove no listener; Windows can
bind before world.New even with -close, so preserve any startup-socket failure
instead of relaxing the rule. No repeated launch or fallback to a live install.
Only a reviewed harness can launch it. The committed preparer does not launch.

Native fixture controls should independently remove outage admission, finite
debit and restore-OFF behavior in generated temporary copies, and must fail their
named assertions. Do not modify repository sources for controls. Save/load tests
use a new private test file per case. Preserve failed assertions and diagnostics.

## Physical integration and playable acceptance

Later separate source slices require these tests before activation:

- Landing occupied/dense/deleted; 4-pad deterministic exhaustion; exact actor
  clearance and real movement callbacks; same-tick competition for one pad.
- Power loss before reservation, during a delayed request, immediately before
  commit and immediately after successful movement; stale tokens after restart.
- Nonmembers, observers, dead/incapacitated actors, nested inventory, pulling,
  buckles, cargo, vehicles, reentrancy and shared bidirectional cooldowns.
- Save admitted before/after transfer, concurrent save refusal, paired-level
  durable save and fresh-process restore, mismatched/missing/duplicate identity,
  damaged metadata rejection before mutation, actual nested colony contents.
- Return at full capacity, disconnected bodies retaining slots/entitlements,
  all explorers inside during outage, independent supplies, paid emergency
  reserve exhaustion, protected landing/build limits and facility rescue role.
- Every loadout/loot/recipe's year/tier/research/prerequisite allowlist, including
  attempts to unlock Modern generators via an apparent 1990 date label.
- Exact selected yellow hazmat/half-mask/glove/boot kit from DESIGN.md: real
  equip/unequip/slot packing, four worn directions and transparent face opening,
  separate mask overlay, visibility/eyes, nested survey gear and reconnect/save
  without duplicate issuance. Compare suit-only, mask-only and full-kit behavior
  through actual smoke/filter/covered-body radiation paths before enabling any
  hazard that relies on them. Armor/flags and sprite inspection alone do not
  establish sealing, breathing protection or immunity. No consumable filter or
  oxygen mechanic is assumed. Initial rooms need none of those hazards.
- Shared generator export replay/parse-back, no escape flags required for return,
  unreachable branch/blocked egress rejection and no duplicate generator code.
- Bounded two-plane lighting, weather/temperature policy, ordinary hunger and
  inventory, save/import memory headroom; population/capacity remains a design
  target until measured at the exact footprint and body count.

First full-game review plan should name exact commit, two-plane map dimensions,
toolchain/executable hashes, independent temporary state and adapters, exclusive
screen turn, process/port/deadline caps and cleanup. Then demonstrate genuine
surface startup -> deliberate powered entry -> exploration/build -> outage with
occupants intact -> independent survival -> powered emergency/ordinary return ->
reconnect/save restoration. Include actual screenshots and reproduction steps,
and video for startup/crossing interruption timing. Do not call the foundation,
an offline proof or a compiled fixture a working gameplay scenario.
