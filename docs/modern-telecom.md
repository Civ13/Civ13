# Modern civilian communications and skills

This work is in draft. Its final runtime, crafting, sprite and native save checks
have not yet passed. It is not a production deployment announcement.

## Intended player loop

Research utilities for network landlines, factories for broadcast equipment,
and assembly-line manufacturing for television and local terminals. Recipes
use existing materials and modern-era gates. Drag an adjacent electrical cable
onto each powered device. Phones and computers use the same cable network for
power and communications; this is an abstract game rule rather than a physical
simulation of mains wiring or real VoIP equipment.

Landlines show their number on examination. Click to dial, answer or hang up.
Both phones must have power and a valid route. Calls end on equipment removal,
lost routes or unanswered timeout. Local terminals send immediate text to other
powered terminals on the same network, with no message history or Internet
service. Delivery is limited to 32 terminals and 32 unique nearby listeners.

Place an antenna adjacent to a radio or television program desk, connect power,
choose a frequency and prepare a course with at least 100 raw skill. Powered
receivers of the matching medium and frequency receive broadcasts within 60
tiles on the same level. Six original lessons air ten seconds apart, followed
by a five-minute interval. At most 32 nearby characters receive each lesson.

Crafting, farming and medical courses each have six durable lesson credits.
Online, conscious hearing characters with current skill at least 10 and both
current and trained skill below 100 receive one percent per unique lesson.
Repeated broadcasts cannot repeat a credit. Existing practice multipliers,
books, mood effects and native maximums remain in use. Skill Progress displays
ten derived levels from the trained maximum; magic scales its native 100-point
maximum to the same ten-level display. These display levels do not replace the
native crafting or combat thresholds.

## Primary-source audit and provenance

The implementation was written independently for Civ13's legacy process system,
native cable reservations, stats and persistence. No upstream source, artwork,
broadcast script or Project Zomboid asset was copied.

Reviewed upstream telecom and power lifecycle concepts:

| Repository | Audited revision | Paths | License reported by repository |
| --- | --- | --- | --- |
| tgstation/tgstation | `49afd5fd7cbf9de60ce81419a9bc97947fc55dc9` | `code/game/machinery/telecomms/telecomunications.dm`, `code/modules/power/powernet.dm` | AGPL-3.0 |
| Baystation12/Baystation12 | `ca90ce8b501c4e04f24c1510990fc6f86623d4f1` | same telecom and powernet paths | AGPL-3.0 |
| cmss13-devs/cmss13 | `0973208b906a1e69f09a567ee5595319065426e9` | same telecom and powernet paths | AGPL-3.0 |

Explicit links, frequency filtering, powered relays and lifecycle cleanup were
useful conceptual references. Their subsystem and signal implementations are
not drop-in replacements for this codebase.

Project Zomboid's official [broadcast development post](https://projectzomboid.com/blog/news/2014/12/turbo-to-the-finishing-line/)
describes learning crafting and cooking from radio/TV. Its official
[RecordedMedia API](https://projectzomboid.com/modding/zombie/radio/media/RecordedMedia.html)
exposes media identity and listened-line bookkeeping. These informed the
bounded, per-character credit concept, without copying timings, reward tables
or program text. The six-line courses above are original Civ13 game guidance.

## Verification boundaries

Equipment uses existing DMI states. Actual state/pixel audits and static previews
are still pending. The initial broadcast-only draft compiled with BYOND
516.1681, zero errors and zero warnings; subsequent landline, terminal,
curriculum and recipe changes require fresh verification.

Required remaining checks include powered reception, incompatible frequencies,
unpowered routes, topology changes, call interruption, repeated credits,
reconnect/save restoration, native recipe registration and research gates.
Local fixtures do not prove public-server performance or human UI acceptance.
