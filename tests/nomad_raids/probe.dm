/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/raid_failures = 0
var/raid_checks = 0
var/raid_runtime_error = FALSE
/obj/map_metadata/raid_probe/New()
	return
/proc/raid_check(condition, label)
	raid_checks++
	if (!condition)
		raid_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	raid_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/raid_probe
		if (!all_species.len)
			makeDatumRefLists()
		raid_ground()
		raid_helper_checks()
		raid_party_checks()
		raid_lifecycle_checks()
	catch(var/exception/e)
		raid_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("checks" = raid_checks, "failures" = raid_failures, "runtime_error" = raid_runtime_error)), "result.json")
	del(world)

/proc/raid_ground()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)

/proc/raid_helper_checks()
	var/turf/T = locate(20, 20, 1)
	raid_check(isnull(nomad_raid_spawn_error(T)), "open outdoor grass is a spawn site")
	// A roof also turns its turf's area indoors; either refusal keeps raiders outside.
	var/turf/roofed = locate(5, 5, 1)
	new /obj/roof(roofed)
	raid_check(!isnull(nomad_raid_spawn_error(roofed)), "roofed ground is refused")
	var/obj/structure/closet/crate/dense = new(locate(6, 5, 1))
	dense.density = TRUE
	raid_check(nomad_raid_spawn_error(get_turf(dense)) == "occupied", "occupied ground is refused")
	var/obj/item/weapon/material/spear/S = new(T)
	raid_check(nomad_raid_worth(S) >= 6, "a loose spear is worth taking")
	S.anchored = TRUE
	raid_check(nomad_raid_worth(S) == 0, "anchored items are left alone")
	qdel(S)

	var/list/site = nomad_raid_edge_site(locate(20, 26, 1))
	var/turf/at = site ? site["turf"] : null
	raid_check(at && at.z == 1, "an edge site is found on the target's level")
	if (at)
		var/edge_distance = min(at.x - 1, 40 - at.x, at.y - 1, 40 - at.y)
		raid_check(edge_distance <= 6, "the site is at the map edge ([at.x],[at.y])")
		raid_check(site["edge"] == "north", "the nearest edge is chosen")
	raid_check(isnull(nomad_raid_edge_site(null)), "no target, no site")

	nomad_raid_cooldowns = list("old" = world.realtime - 72001, "fresh" = world.realtime - 10)
	raid_check(!nomad_raid_on_cooldown("old"), "a raid over two hours ago has cooled down")
	raid_check(nomad_raid_on_cooldown("fresh"), "a recent raid is on cooldown")
	raid_check(!nomad_raid_on_cooldown("never"), "an unknown ckey is not on cooldown")
	nomad_raid_save_cooldowns()
	var/list/saved = json_decode(file2text(NOMAD_RAID_COOLDOWN_FILE))
	raid_check(islist(saved) && ("fresh" in saved) && !("old" in saved), "the cooldown file keeps live entries and prunes expired ones")
	nomad_raid_cooldowns = null
	raid_check(nomad_raid_on_cooldown("fresh"), "cooldowns reload from the file after a restart")

	var/list/near = nomad_raid_edge_site(locate(20, 33, 1))
	raid_check(near && near["edge"] != "north", "an edge too close to see past is skipped")
	var/list/picked = nomad_raid_pick(list(list("turf" = T, "ckeys" = list(), "score" = 3)))
	raid_check(picked && picked["turf"] == T, "a single candidate is picked")
	raid_check(isnull(nomad_raid_pick(list())), "no candidates, no target")

/proc/raid_party_checks()
	var/turf/target = locate(20, 26, 1)
	var/datum/nomad_raid/R = new
	raid_check(isnull(R.setup(target, list("victim"), 9, "probe")), "a party sets up at the edge")
	raid_check(R.members.len == NOMAD_RAID_MAX_MEMBERS, "party size is capped at [NOMAD_RAID_MAX_MEMBERS]")
	raid_check(R.leader && (R.leader in R.members), "the party has a leader")
	var/all_unsaved = TRUE
	var/all_armed = TRUE
	for (var/mob/living/human/H in R.members)
		if (H.should_save)
			all_unsaved = FALSE
		var/obj/item/W = R.weapon[H]
		if (!W || W.loc != H || !istype(H.back, /obj/item/weapon/storage/backpack))
			all_armed = FALSE
	raid_check(all_unsaved, "raiders are never saved")
	raid_check(all_armed, "each raider holds a weapon and wears a bag")
	raid_check(R.tribute_demand == NOMAD_RAID_TRIBUTE_PER_RAIDER * NOMAD_RAID_MAX_MEMBERS, "tribute scales with party size")

	// A second raid is refused while one runs.
	nomad_raid = R
	raid_check(start_nomad_raid(target, list(), 3, "probe") == "a raid is already running", "one raid at a time")

	// Marching: a step brings the leader closer to the target.
	var/before = get_dist(R.leader, target)
	R.next_step[R.leader] = 0
	R.step_toward(R.leader, target, 2)
	raid_check(get_dist(R.leader, target) < before, "the leader marches toward the target")
	raid_check(R.next_step[R.leader] > world.time, "marching respects the movement delay")

	// Parley: tribute at the leader's feet ends the threat.
	var/mob/living/human/L = R.leader
	R.begin_parley()
	raid_check(R.state == "parley", "parley begins")
	var/turf/feet = get_turf(L)
	var/list/tribute = list()
	for (var/i = 1, i <= 3, i++)
		tribute += new /obj/item/weapon/material/spear(feet)
	R.tick_parley(R.alive_members(), FALSE, TRUE)
	raid_check(R.state == "loot" && R.outcome == "tribute paid", "enough tribute ends the parley peacefully")
	raid_check(R.pick_loot(L) in tribute, "after tribute, raiders take only the tribute")

	// Refusal: an attack during parley starts the assault.
	R.state = "parley"
	R.outcome = ""
	R.tick_parley(R.alive_members(), TRUE, TRUE)
	raid_check(R.state == "assault", "an attack during parley starts the assault")

	// Carrying and a fallen raider's drop.
	var/mob/living/human/H = R.members[2]
	var/obj/item/weapon/material/spear/loot = new(get_turf(H))
	raid_check(R.carry(H, loot), "a raider can carry loot")
	R.stolen += loot
	raid_check(nomad_raid_holder(loot) == H, "the loot is on the raider")
	var/turf/fell_at = get_turf(H)
	var/obj/item/W = R.weapon[H]
	H.stat = DEAD
	R.drop_loot(H)
	raid_check(loot.loc == fell_at, "a fallen raider drops what they stole")
	raid_check(W.loc == fell_at, "a fallen raider drops their weapon")
	raid_check(!H.back, "a fallen raider drops their bag")

	// Removal: survivors drop loot and the raid clears itself.
	var/mob/living/human/K = R.members[3]
	var/obj/item/weapon/material/spear/carried = new(get_turf(K))
	R.carry(K, carried)
	R.stolen += carried
	var/turf/K_at = get_turf(K)
	R.remove_all("probe")
	raid_check(R.state == "ended" && isnull(nomad_raid), "removing the raid ends it")
	raid_check(carried.loc == K_at, "removed raiders leave their loot behind")
	raid_check(!R.members.len, "no raiders remain")

// The real controller loop: with nobody home, the party marches in, turns
// back and leaves the map on its own.
/proc/raid_lifecycle_checks()
	var/turf/target = locate(20, 20, 1)
	raid_check(isnull(start_nomad_raid(target, list(), 3, "probe")), "a raid starts through the public entry point")
	var/datum/nomad_raid/R = nomad_raid
	var/turf/home = R.home
	var/start_distance = get_dist(R.leader, target)
	var/closest = start_distance
	var/saw_leave = FALSE
	for (var/i = 1, i <= 600 && nomad_raid, i++)
		sleep(1)
		if (R.leader && !QDELETED(R.leader))
			closest = min(closest, get_dist(R.leader, target))
		if (R.state == "leave")
			saw_leave = TRUE
	raid_check(closest <= 3 && closest < start_distance, "the party marched to the target ([start_distance] to [closest] tiles)")
	raid_check(saw_leave, "with nobody home the party turned back")
	raid_check(R.state == "ended" && isnull(nomad_raid), "the raid ended by itself")
	raid_check(R.escaped == R.initial_size && !R.members.len, "every raider left the map near home ([home.x],[home.y])")
