# Interchange Mall design and implementation

This is an original Civ13 shopping-centre raid, inspired by the mall, parking,
service-space and perimeter-extraction concept of Escape from Tarkov's
Interchange. No Tarkov geometry, trademarks, textures or game assets are imported.

## Master plan

All five levels default to 256 x 256, with a generator size parameter supporting
160..512. The raid uses z1 parking/exterior, z4 retail and
z5 upper gallery. z2 private homes and z3 safehouse hub retain their original
96 x 96 layout inside the enlarged level, surrounded by inaccessible walls.
These are separate secure spaces, never stair destinations.

| Level | Spatial role | Main routes |
| --- | --- | --- |
| z1 | Perimeter highways, sheltered parking, loading aisles | Broad drivable perimeter loop, parking through-routes, six stair cores |
| z4 | Hearth furnishings southwest, Foundry hardware southeast, Harvest hypermarket north | Central north-south concourse, east-west shopping street, two side service aisles |
| z5 | Smaller stores, electronics, pharmacy, food court and operations rooms | Gallery loop with cross passages, same six stair cores |

The following coordinates are on a normalized 160-unit design grid, scaled
by the generator for the selected size. Mall envelope x24..136/y24..136.
Six cores at (30,30), (130,30), (30,94),
(130,94), (54,126), (106,126) connect parking to retail and retail to gallery.
Every core is human-only and validates owned raid state, conscious/unrestrained
actor, actual adjacency, source/destination mission level and a clear landing.
Cars never use these stairs. No auto-teleporting vehicle or car clone is created.

Three anchor stores have distinct native floor palettes and named signs.
Hearth has six furnished apartment display suites, a consultation office and
receiving store. Foundry has sales aisles, checkout counters, repair benches,
a stockroom and the reserved hardware cage. Harvest has checkout queues,
broken-up shelf islands and rear bakery, cold storage, receiving, staff and
accounts rooms. The upper gallery contains 20 named shops with separate staff
rooms and distinct clinic, fitting-room, kitchen, office and sales layouts,
plus common dining and two washrooms with toilet cubicles and sinks.

Parking has marked bays, pedestrian crossings, circulation lanes and enclosed
security, maintenance, dispatch and utility rooms. Sixteen wrecks and scattered
debris occupy bays while preserving the road approaches and highway loop.
Fixtures use map-specific variants of existing native structures. Closets and
fridges begin empty; ovens and plumbing are disused. Tool, dismantling and
damage callbacks cannot convert fixed dressing into saleable resources outside
the loot journal. Native furniture on other maps keeps its existing behavior.

Shop rows, shelf ends and side aisles interrupt indoor sightlines. Wide public
concourse routes contrast with narrower service routes; furnishings stay out
of core landings. NPC and loot markers occupy stores on both retail floors.
The bounded existing NPC AI operates locally on each floor; it is not a
cross-level pathfinding system.

## Entries and exits

Two road infil markers at southwest and northeast highway approaches are the
only car arrival candidates. Four additional perimeter markers admit foot raids.
Road vehicle footprints and highway approaches have no dense props.

West and east highway evacuation points support foot and car return. North
rail embankment and east service footgate accept foot extraction only. West
drain access retains the existing no-backpack rule and rejects cars. Exit names
state these restrictions. The existing return journal, fee checks, vehicle
identity, fuel/wear, nested cargo, passengers and private-bay preflight remain
authoritative. Capability checks apply before and after extraction waits.

## Validation stages

The mall is a scavenged post-war site. Every shop contains scattered rubbish,
collapsed masonry, displaced seating and damaged flooring. Parking has abandoned
car wrecks with native 3x2-tile bounds. These props are not usable garage cars or
free loot. The generator restores clear stair landings after dressing; route
checks account for wreck footprints as well as furniture and walls.

1. Generate the deterministic DMM and verify equal dimensions, dictionary and
   atom ordering, protected home/hub contents and all marker types.
2. Flood-fill actual passable cells and stair edges; require every entry,
   exit, shop loot tile, room sign and core to connect, with reachable approaches
   to cabinets, appliances, beds and plumbing fixtures. Check separate vehicle footprint
   paths from both road infils to both highway exits.
3. Compile the selected mall with BYOND 516.1681, then run native traversal,
   raid-floor and vehicle restriction regressions in temporary offline storage.
4. Accept each behavior through the smallest meaningful automated source,
   topology, native interaction and negative-control checks. Human/admin review
   and connected-client capture are not default prerequisites. Use a genuine
   capture only for a named material uncertainty that these checks cannot resolve.
   Compilation alone does not establish runtime movement or storage behavior.

Generate with the verified Python interpreter and `tests/extraction/build_mall.py`
(optional `--size 320`, for example). The generator adds proportional shelf rows;
scale changes still require layout and travel-time review. 256 x 256 x 5 allocates
327,680 turfs; 512 x 512 x 5 allocates 1,310,720. Wall padding is allocated too.
Generation/topology support is not startup, memory, performance or balance
acceptance for larger sizes. Budgets are 62 ordinary containers plus two keyed
caches, at most
64 allowed container IDs, 2,048 tracked item nodes, 12 NPCs, 32 participants and
16 private homes.
Do not hand-edit the generated map. This map is selectable through the existing
launcher and safehouse next-map catalog; implementation does not deploy it.

All three raid floors have searchable loot containers: six on parking, 16
ordinary plus two keyed on retail, and 40 on the upper gallery. Parking has
workshop salvage in maintenance, dispatch and utility rooms, supplies in the
staff and delivery offices, and ammunition in the security office. These use
the existing first-access tables and journals, not loose-item constructors.
Parking uses IDs 57-60 and 63-64; existing shop IDs 1-56 and keyed IDs 61/62
stay unchanged. A searched source retains its rolled contents and consumed
claims within the loot epoch. Runtime item identities and FIR tracking alone
do not provide durable ownership for loose surface spawns. There is currently
no shelf/counter/ground loot-population system; static renders show scenery
and source containers, not their randomized contents. Native restart recovery
and active-raid acceptance remain separate verification requirements.

Forty disabled surface-source markers reserve future loose-loot locations:
12 parking, 20 retail and eight gallery. Their IDs 1..40 are separate from the
container namespace. Eight use clear floor, 22 use store shelves, four use cafe
tables and six use ransacked register fixtures on existing counters. Registers
use the native open-drawer sprite and have no closet storage, stock or currency
behavior. These placements preserve the existing turf and furniture and have
reachable approaches at sizes 160, 256 and 320. All five reserved pools remain
disabled; these markers do not spawn items. Core materialization, custody,
food/currency support and restart reconciliation are still required.

Transit security and Foundry hardware each have one exact-key cache on the
retail floor. Their keys can be recovered on any Extraction map and retain
their remaining uses when extracted. See [container keys](extraction-container-keys.md)
for the catalog, acquisition rule and verification boundaries.

## Automated acceptance checklist

The October 13, 2026 acceptance policy removes blanket human, admin and capture
holds. Automated agent review and meaningful tests can establish acceptance.
An unresolved architectural decision or actual runtime/resource lease remains
an explicit dependency. The checklist below records behavior, not a requirement
for someone to click through a demonstration.

The audit baseline is `71be023f3e6f0f9737b816e11c36668f126e9388`.
Its standard CI compiled production with BYOND 516.1681 and zero errors/warnings;
opt-in native Extraction tests were skipped. The following native assertions
must not be described as passed merely because their fixture compiles.

| Requirement | Existing automated evidence path | Remaining work |
| --- | --- | --- |
| Five equal-sized levels, protected homes/hub, all loot/support locations and walk routes | `test_mall.py` parses generated maps, checks IDs and flood-fills scaled routes; disconnected-stair control detects loss of upper-floor access | Run unchanged checks on the selected acceptance head; topology is not native movement. |
| Highway clearance | `test_mall.py` checks conservative 3x3 footprints from both road entries to both highway exits at 160, 256 and 320 | Execute an assembled car's actual movement/turning through representative mall approaches; static clearance alone does not exercise vehicle callbacks. |
| Floor travel and denied stair use | `mall_probe.dm` requires six distinct cores and 24 unique directed links, exercises every round trip, and checks dense turf, dense/nondense living occupancy and missing/mismatched returns alongside the existing actor restrictions | Compile/run the amended probe and `stair_landing`/`stair_return` omission controls. Authored assertions are not runtime results. |
| First-search loot on all three floors | Counts require 6 parking, 18 retail and 40 upper containers; the native probe claims one ordinary item per floor through the journal and compares actual item and raid-registry identities across repeat refusal/reopening | Compile/run the amended probe and `ordinary_replay` omission control. This is representative ordinary-source coverage; the injected pool tests journal behavior, not random-drop frequency. |
| Exact-map consumable keys and durable extraction | `test_key_maps.py`, shared key probes and `run_mall.py` cover target placement, unlock/retry, remaining uses, nested foreign-map keys, extraction and redeployment | Run normal mall and `key_charge`/`key_construction` controls; core owner covers journal/concurrency/drop-rule assertions. |
| Fixed scenery cannot mint supplies | Native mall probe constructs each fixture and exercises tool, damage and dismantling callbacks with an item-count invariant | Run the existing probe. Nonempty icon/overlay checks are limited appearance evidence, not proof of every rendered pixel. |
| Car arrival and return only through highway-capable points | Mall probe checks actual marker/exit policy and rejects pedestrian exits; its `vehicle` control removes the highway guard | Run the control, then add a positive actual mall car deployment/return with the same IDs, fuel/wear, cargo and garage debit/credit. Reuse core vehicle/party contracts without duplicating their ownership. |
| Crash/restart custody and loose surface loot | Core account, equipment, vehicle and surface recovery suites own these shared contracts | Complete actual missing implementation and native recovery controls. All 40 mall surface markers stay disabled until their dependencies pass. |

Start with the offline launcher/topology/key-map checks. After an authorized
clean positive native run, execute `mission`, `vehicle`, `key_charge`,
`key_construction`, `stair_landing`, `stair_return` and `ordinary_replay`. An
omission control must fail at its expected assertion; a compiler error, timeout
or unrelated runtime failure does not establish detection.

Using a verified Python interpreter, run `-m unittest discover -s
tests/extraction -p test_mall_runner.py -v` for the 27 mocked launcher cases and
`-m unittest discover -s tests/extraction -p test_mall.py -v` for the 11 offline
map checks. Launcher children are injected fakes; these commands do not launch
BYOND. The shared CI owner must register the new launcher file and three added
native omission controls in the existing opt-in Extraction job.

`run_mall.py` requires the pinned BYOND bin directory, uses unique generated
source names and temporary save storage, and rejects outbound Export/port
opening. `mall_run_support.py` records commands, stage output, failures and
direct-child exit/cleanup results under `data/mall-fixture/`, including compiler
failures before a daemon can launch. Its stage waits share a 240-second budget
(Git up to 10 seconds, compiler up to 120, daemon up to 90), followed by a shared
15-second cleanup allowance. Success prints only after receipt retention and
cleanup complete. Failed retention or uncertain direct-child exit preserves
owned files; runtime removal also checks the original directory identity.
Atomic receipt replacement retries Windows sharing/access denials at most four
times with three 50 ms pauses. Exhaustion retains the previous receipt and
prepared temporary file; other errors propagate without retry.

The helper owns direct child handles, not descendants. Process creation and
filesystem I/O can block outside these wait budgets, and abrupt interpreter
termination can bypass cleanup, so an outer watchdog remains necessary. Run
the injected-process contracts with `test_mall_runner.py` before native use.
No runtime grant is implied by this document.

Required run receipts identify the exact Git head, fixture/control, command,
result and relevant negative assertion. Preserve timeout/runtime diagnostics;
verify the task-owned compiler/daemon exited and generated files were removed.
Do not terminate another task's process. If the positive run fails, diagnose that
failure before spending the queue slot on omission controls. Standard CI, source
review, topology, native assertions and deployment remain distinct evidence.

## Ground and support loot prerequisites

Visible ground and support loot remains an incomplete required feature. Container
counts do not satisfy it. The 40 reserved locations comprise eight ground sources,
22 shelves, four tables and six registers. Staged core paths cover four fuel
sources, four wheel sources and 14 repair-parts sources. Twelve food sources and
six cash sources cannot issue their intended items, even when the service is
explicitly enabled by an isolated fixture. No source is active on this map.

Core owns the service lifecycle, pool/item codecs, currency authority, custody,
durable epoch and complete world/account/shared ownership reconciliation. The
final durable API and actual host provider are not available. The mall owner must
receive that implemented contract before installing the service or enabling any
of these locations. Shared faction persistence work keeps its existing priority.

`test_mall.py` checks connected interaction approaches at 160, 256 and 320, with
deliberate blocked-approach controls for ground, shelf, table and register
sources. A source tile must not also carry an independent container source or
unmanaged preplaced item. Native tests must additionally
prove one materialization and claim per source graph, exact root/nested IDs,
unchanged surrounding container journals, and no refill after extraction or
reconciliation. Distinct sources may roll the same item type; duplicate custody
or reward for one graph is the failure. Food/register rejection tests document
the missing implementation and cannot count as positive loot acceptance.

The all-core stair/all-floor ordinary-loot and support-placement amendments are
now integrated with the launcher. The October 15 source-review baseline remains
`71be023f`; later test receipts must identify their own candidate. Offline Python
checks do not compile or execute the DM assertions, establish actual car travel,
or enable any of the forty reserved surface sources.
