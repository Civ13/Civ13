# Functional floors and reuse

## First playable conversion: packed dirt road → garden

Use a plough on **Disarm** to make a dirt road as usual. To reclaim a newly
player-packed section, hold a plough in your active hand, stand beside it and
use it on the visible road on **Help** intent. Removing the road with a shovel
instead still just exposes the original ground.

Reclaiming takes ordinary tilling work and replaces the road with one regular
ploughed plot. Grass takes the time of clearing and then tilling; bare earth
takes the normal tilling time. There is no material refund. Current soil
nutrition, its recovery deadline, and loose dirt are retained when starting from dirt; the existing
crop, season and watering rules still apply. Terrain grade and pollution are
not reset. Clear snow, water, crops, other covers and structures first. This
does not make dunes, jungle, wetlands, mines or ship decks farmable.

Only newly hand-laid dirt roads get the reclaim action. Existing saves and
authored roads keep their established meaning and shovel behavior. The stone
rammer's **tamped earth** is a separate natural turf that already stays firm in
the rain and makes hills easier to climb; the mine's dense **packed earth** is
a different terrain again. Neither is changed here.

## Next slices (design, not implemented here)

| Surface upgrade | Practical use and limit |
| --- | --- |
| Packed earth → gravel → cobble | Tamped earth already handles rain without mud. Make gravel the affordable surface for wheels on wet ground and give it a distinct cost, such as rutting under heavy loads. Cobble then earns its stone and labor through durability and better heavy-cart footing, not another generic speed bonus. Measure loaded and unloaded carts in wet and dry conditions before choosing numbers. |
| Rough → treated → fitted boards | Treat construction wood for outdoor use rather than giving every stained sprite a special bonus. Fitted boards could reduce snagging or noise in workshops and living rooms, subject to costs and counterplay; keep placement and recovery tied to the exact paid build. |
| Rough → dressed → polished stone | Dressed stone makes a durable workshop surface. Polished stone should trade easier cleaning for less traction when wet, but first verify a real water-to-traction hook; the existing wet-floor flag is not evidence that bath spills or rain activate it. Keep decorative variants available independent of mechanical treatment. |

For **cobble → rail bed**, build on current sleepers → rails → spikes. Cobbled
ground already accepts track; a later ballast improvement needs a distinct
benefit such as slower wear, not free sleepers, instant rails or a change to
route admission. Reuse the existing track-wear and teardown rules; check buried
track and saved route continuity before extending it.

For **stone workshop → drained wash bay**, start with real pitched stone and
the existing floor drain grate, connected outlet or cesspit, and washing
fixtures. They already provide drainage and washing; reuse them rather than
adding water removal to an ordinary floor. A measurable later bonus should
require a connected, working drain, preserve runoff destination and stop when
the grate clogs or is removed.

Future floor upgrades should preserve saved identity and terrain grade, carry
only intended movement/maintenance effects and never turn authored finishes
into refundable materials. Keep large-area compaction from ordinary foot
traffic out of this slice.
