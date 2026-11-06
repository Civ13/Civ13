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
		raid_coordinator_checks()
		raid_trade_checks()
		raid_reputation_checks()
		raid_capture_checks()
		raid_lifecycle_checks()
		raid_boat_checks()
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
	raid_check(R.leader && (R.leader in R.members) && R.leader.is_leader, "the party has a leader")
	// The walk is planned once and handed out in short legs.
	var/list/route = R.walk_route
	raid_check(islist(route) && route[1] == R.home && get_dist(route[route.len], target) <= NOMAD_RAID_ROUTE_REACH, "the walk to the target is planned from home")
	if (islist(route) && route.len > NOMAD_RAID_ROUTE_LEG + 2)
		var/turf/leg = R.route_waypoint(R.leader, target)
		raid_check(leg && (leg in route) && get_dist(R.leader, leg) <= NOMAD_RAID_ROUTE_LEG + 2, "the leader walks one short leg of the route at a time")
	var/turf/far_off = locate(2, 2, 1)
	var/mob/living/simple_animal/hostile/human/nomad_raider/stray = R.members[R.members.len]
	var/turf/stray_was = get_turf(stray)
	stray.loc = far_off
	raid_check(R.route_waypoint(stray, target) == target || get_dist(far_off, route[1]) <= NOMAD_RAID_ROUTE_LEG, "a member far off the route paths straight to the target")
	stray.loc = stray_was
	// Players who moved away are followed; a short move is not.
	var/turf/first_target = R.target
	raid_check(!R.retarget_to(get_step(target, WEST)) && R.target == first_target, "a target that barely moved is kept")
	var/turf/moved = locate(target.x - 12, target.y - 4, 1)
	raid_check(R.retarget_to(moved) && R.target == moved && islist(R.walk_route) && get_dist(R.walk_route[R.walk_route.len], moved) <= NOMAD_RAID_ROUTE_REACH, "the march follows players who moved away")
	R.target = first_target
	R.plan_walk(R.home, first_target)
	// Leaving plans the walk home from where the party stands.
	R.plan_walk(get_turf(R.leader), R.home)
	raid_check(islist(R.walk_route) && get_dist(R.walk_route[R.walk_route.len], R.home) <= NOMAD_RAID_ROUTE_REACH, "the walk home is planned from where the party stands")
	R.plan_walk(R.home, first_target)
	var/all_npcs = TRUE
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in R.members)
		if (M.should_save || M.party != R || M.faction != NOMAD_RAID_FACTION || M.weapon != /obj/item/weapon/material/spear)
			all_npcs = FALSE
	raid_check(all_npcs, "members are unsaved NPC raiders of the party, armed for the age")
	raid_check(R.tribute_demand == NOMAD_RAID_TRIBUTE_PER_RAIDER * NOMAD_RAID_MAX_MEMBERS, "tribute scales with party size")
	var/mob/living/simple_animal/hostile/human/nomad_raider/gunner = new(locate(2, 2, 1))
	gunner.arm_for_age(6)
	raid_check(gunner.ranged && gunner.gun && gunner.gun.loc == gunner && !gunner.gun.should_save, "late-age raiders carry an unsaved sidearm")
	qdel(gunner)

	nomad_raid = R
	raid_check(start_nomad_raid(target, list(), 3, "probe") == "a visit is already running", "one visit at a time")

	// The combat AI only picks fights while the party is hostile.
	var/mob/living/simple_animal/hostile/human/nomad_raider/F = R.members[2]
	var/mob/living/human/victim = new(get_step(F, get_dir(F, target)))
	raid_check(R.foe_ok(victim) && !R.foe_ok(F), "people are foes, party members are not")
	raid_check(isnull(F.FindTarget()), "peaceful raiders pick no fights")
	R.set_hostile(TRUE)
	raid_check(F.behaviour == "hostile" && F.FindTarget() == victim, "hostile raiders use the NPC AI to find a target")
	R.set_hostile(FALSE)
	raid_check(F.behaviour == "defends" && isnull(F.target_mob), "calling off the fight clears targets")
	victim.stat = UNCONSCIOUS
	raid_check(!R.foe_ok(victim), "downed people are left alone")
	victim.stat = CONSCIOUS

	// Marching uses the shared NPC pathfinding.
	R.order_move(R.leader, target)
	raid_check(R.leader.moving && R.leader.target_obj == target, "the leader is ordered to march by pathfinding")
	R.order_halt(R.leader)
	raid_check(!R.leader.moving, "the leader can be halted")

	// Parley: tribute at the leader's feet ends the threat. Gear already
	// lying nearby is not tribute, even once the leader steps beside it.
	var/turf/stash = get_step(get_step(R.leader, SOUTH), SOUTH)
	var/list/tribute = list()
	for (var/i = 1, i <= NOMAD_RAID_MAX_MEMBERS, i++)
		tribute += new /obj/item/weapon/material/spear(stash)
	R.begin_parley()
	raid_check(R.state == "parley", "parley begins")
	R.leader.loc = get_step(R.leader, SOUTH)
	R.next_decide = 0
	R.tick_parley(R.alive_members(), FALSE, TRUE)
	raid_check(R.state == "parley" && !R.outcome, "loose gear lying nearby is not taken as tribute")
	// The same gear laid at the leader's feet is.
	var/turf/feet = get_turf(R.leader)
	for (var/obj/item/I in tribute)
		I.loc = feet
	R.next_decide = 0
	R.tick_parley(R.alive_members(), FALSE, TRUE)
	raid_check(R.state == "loot" && R.outcome == "tribute paid", "enough tribute ends the parley peacefully")
	raid_check(R.pick_loot(R.leader) in tribute, "after tribute, raiders take only the tribute")

	// Refusal: an attack during parley starts the assault.
	R.state = "parley"
	R.outcome = ""
	R.tick_parley(R.alive_members(), TRUE, TRUE)
	raid_check(R.state == "assault" && R.hostile, "an attack during parley starts the assault")

	// Carrying, and a fallen raider drops what they took.
	var/obj/item/weapon/material/spear/loot = new(get_turf(F))
	raid_check(F.take_item(loot) && (loot in F.carried) && nomad_raid_holder(loot) == F, "a raider can carry loot")
	var/turf/fell_at = get_turf(F)
	R.member_fell(F)
	raid_check(loot.loc == fell_at && !F.carried.len, "a fallen raider drops what they stole")

	// Removal: survivors drop loot and the visit clears itself.
	var/mob/living/simple_animal/hostile/human/nomad_raider/K = R.members[3]
	var/obj/item/weapon/material/spear/carried = new(get_turf(K))
	K.take_item(carried)
	var/turf/K_at = get_turf(K)
	R.remove_all("probe")
	raid_check(R.state == "ended" && isnull(nomad_raid), "removing the visit ends it")
	raid_check(carried.loc == K_at, "removed raiders leave their loot behind")
	raid_check(!R.members.len, "no raiders remain")
	qdel(victim)

// What an agent-control coordinator may see and order.
/proc/raid_coordinator_checks()
	var/turf/target = locate(20, 26, 1)
	var/datum/nomad_raid/R = new
	R.setup(target, list(), 4, "probe")
	nomad_raid = R
	var/mob/living/human/bob = new(get_step(R.leader, get_dir(R.leader, target)))
	bob.real_name = "Bob"
	var/list/S = R.coordinator_status()
	raid_check(S["active"] && S["state"] == "march" && S["party"]:len == 4, "status lists the party")
	raid_check(R.voice_active(), "reading status attaches the voice")
	var/list/allowed = S["allowed"]
	raid_check(("say" in allowed) && ("retreat" in allowed) && !("tactic" in allowed), "marching allows only talk and retreat")
	var/list/people = S["people"]
	raid_check(people.len == 1 && people[1]["ref"] == "\ref[bob]", "status lists nearby people by ref")

	R.begin_parley()
	raid_check(R.pending_cue && R.leader_ok(), "with a voice attached, the controller's line waits as a cue")
	var/list/O = R.order(list("order" = "say", "text" = "Pay, <b>Bob</b>.", "emote" = "glares."), "probe")
	raid_check(O["ok"] && isnull(R.pending_cue), "the coordinator speaks for the leader and replaces the cue")
	raid_check(!findtext(O["detail"], "<b>"), "coordinator speech is sanitized")
	O = R.order(list("order" = "say", "text" = "Again."), "probe")
	raid_check(!O["ok"], "speech is rate limited")
	O = R.order(list("order" = "tactic", "tactic" = "flank"), "probe")
	raid_check(!O["ok"], "fight orders are refused during parley")
	O = R.order(list("order" = "bargain", "decision" = "refuse"), "probe")
	raid_check(!O["ok"] && R.state == "parley", "defenders get time to answer before a refusal")
	O = R.order(list("order" = "bargain", "decision" = "counter", "demand" = R.tribute_base * 3), "probe")
	raid_check(!O["ok"], "a demand above the bound is refused")
	O = R.order(list("order" = "bargain", "decision" = "counter", "demand" = R.accept_floor()), "probe")
	raid_check(O["ok"] && R.tribute_demand == R.accept_floor(), "a demand within bounds is set")
	O = R.order(list("order" = "bargain", "decision" = "accept"), "probe")
	raid_check(!O["ok"] && R.state == "parley", "nothing offered cannot be accepted")
	O = R.order(list("order" = "launch_nukes"), "probe")
	raid_check(!O["ok"], "unknown orders are refused")

	R.state_at -= NOMAD_RAID_EARLY_ASSAULT
	O = R.order(list("order" = "bargain", "decision" = "refuse"), "probe")
	raid_check(O["ok"] && R.state == "assault" && R.hostile, "after the grace time a refusal starts the assault")
	O = R.order(list("order" = "focus", "target" = "\ref[bob]"), "probe")
	raid_check(O["ok"] && R.focus == bob, "the coordinator can name a focus target")
	O = R.order(list("order" = "focus", "target" = "\ref[R.leader]"), "probe")
	raid_check(!O["ok"] && R.focus == bob, "party members cannot be the focus")
	O = R.order(list("order" = "tactic", "tactic" = "hold"), "probe")
	raid_check(O["ok"] && R.tactic == "hold", "the coordinator can set a tactic")
	O = R.order(list("order" = "loot"), "probe")
	raid_check(O["ok"] && R.state == "loot", "the coordinator can order looting")
	O = R.order(list("order" = "retreat"), "probe")
	raid_check(O["ok"] && R.state == "leave" && !R.hostile, "the coordinator can order a retreat")
	S = R.coordinator_status(0)
	var/list/kinds = list()
	for (var/list/E in S["events"])
		kinds |= E["kind"]
	raid_check(("said" in kinds) && ("bargain" in kinds) && ("focus" in kinds), "events record what happened")
	var/list/later = R.coordinator_status(S["last_event"])
	raid_check(!later["events"]:len, "events can be read incrementally")
	R.remove_all("probe")
	qdel(bob)

/proc/raid_trade_checks()
	var/turf/target = locate(20, 26, 1)
	var/datum/nomad_raid/R = new
	raid_check(isnull(R.setup(target, list(), 2, "probe", "trade")) && R.kind == "trade", "a caravan sets up")
	nomad_raid = R
	raid_check(findtext(R.leader.name, "trader"), "the caravan has a trader")
	raid_check((/obj/item/stack/farming/seeds/tea in nomad_trade_goods(0)) && !(/obj/item/weapon/reagent_containers/pill/penicillin in nomad_trade_goods(5)) && (/obj/item/weapon/reagent_containers/pill/penicillin in nomad_trade_goods(6)), "caravans carry tea seeds, and medicine pills from the sixth age")
	var/turf/yard = get_step(get_step(R.leader, SOUTH), SOUTH)
	var/obj/item/weapon/material/spear/lying = new(yard)
	lying.fingerprintslast = "Neighbour"
	R.begin_trade()
	raid_check(R.state == "trade" && !R.hostile, "trading begins peacefully")
	// Gear already lying near the stall is not payment when the trader steps onto it.
	R.leader.loc = yard
	R.tick_trade(R.alive_members(), FALSE, TRUE)
	raid_check(!R.credit["neighbour"] && lying.loc == yard, "loose gear near the stall is not taken as payment")
	raid_check(R.goods.len >= 1 && R.goods.len <= NOMAD_TRADE_GOODS, "goods are laid out ([R.goods.len])")
	var/goods_ok = TRUE
	for (var/obj/item/I in R.goods)
		if (I.should_save || !(I.loc in R.stall) || R.goods[I] < 3)
			goods_ok = FALSE
	raid_check(goods_ok, "goods lie on the stall, priced and unsaved")
	var/list/S = R.coordinator_status()
	raid_check(S["goods"]:len == R.goods.len && ("price" in S["allowed"]), "status lists goods and allows repricing")

	var/obj/item/first = R.goods[1]
	var/base = R.base_price[first]
	var/list/O = R.order(list("order" = "price", "target" = "\ref[first]", "price" = base * 3), "probe")
	raid_check(!O["ok"], "prices are bounded")
	O = R.order(list("order" = "price", "target" = "\ref[first]", "price" = base * 2), "probe")
	raid_check(O["ok"] && R.goods[first] == base * 2, "the coordinator can reprice a good")

	// Paying: an item dropped at the trader's feet credits whoever last handled it.
	var/obj/item/weapon/material/spear/pay = new(get_turf(R.leader))
	pay.fingerprintslast = "Buyer"
	R.tick_trade(R.alive_members(), FALSE, TRUE)
	raid_check(R.credit["buyer"] == nomad_raid_worth(pay, TRUE) && (pay in R.leader.carried), "a payment is taken and credited")

	// Buying: a good taken by someone with enough credit is sold.
	R.credit["buyer"] = 1000
	first.forceMove(locate(2, 2, 1))
	first.fingerprintslast = "Buyer"
	R.tick_trade(R.alive_members(), FALSE, TRUE)
	raid_check(!(first in R.goods) && R.sold == 1 && first.should_save, "a paid-for good is sold and becomes a normal item")
	raid_check(R.credit["buyer"] == 1000 - base * 2, "the sale spends credit")

	// Theft: taking a good without credit warns, then turns the guards on the thief.
	if (R.goods.len)
		var/obj/item/second = R.goods[1]
		second.forceMove(locate(2, 3, 1))
		second.fingerprintslast = "Thief"
		R.tick_trade(R.alive_members(), FALSE, TRUE)
		raid_check(R.thieves["thief"] && R.state == "trade", "a theft gets a warning first")
		var/list/T = R.thieves["thief"]
		T[1] -= NOMAD_TRADE_THEFT_GRACE
		R.tick_trade(R.alive_members(), FALSE, TRUE)
		raid_check(R.state == "assault" && R.hostile, "a thief who keeps the good is attacked")
		raid_check(!R.goods.len, "the stall is packed up")
		raid_check(pay.loc == get_turf(R.leader), "unspent payments are handed back")
	R.remove_all("probe")

/proc/raid_reputation_checks()
	nomad_reputation = list()
	fdel(NOMAD_REP_FILE)
	raid_check(nomad_rep_score("nobody") == 0 && nomad_rep_standing(0) == "stranger", "unknown players are strangers")
	for (var/i = 1, i <= 5, i++)
		nomad_rep_record("good", "trade")
	raid_check(nomad_rep_score("good") == 5 && nomad_rep_standing(5) == "trusted", "steady trading earns trust")
	raid_check(nomad_rep_price(20, "good") == 18 && nomad_rep_price(20, "nobody") == 20, "trusted buyers get better prices")
	nomad_rep_record("bad", "theft")
	raid_check(nomad_rep_price(20, "bad") == 25, "distrusted buyers pay more")
	nomad_rep_record("bad", "theft")
	raid_check(nomad_rep_standing(nomad_rep_score("bad")) == "wanted", "repeated theft makes a player wanted")
	for (var/i = 1, i <= 20, i++)
		nomad_rep_record("saint", "tribute")
	raid_check(nomad_rep_score("saint") == NOMAD_REP_LIMIT && nomad_rep_price(20, "saint") == 15, "reputation is capped, and friends pay least")
	raid_check(!nomad_rep_record("good", "nonsense"), "unknown deeds change nothing")
	nomad_reputation["bad"]["at"] -= 3 * NOMAD_REP_DAY
	raid_check(nomad_rep_score("bad") == -5, "reputation fades a point a day ([nomad_rep_score("bad")], at [nomad_reputation["bad"]["at"]], now [world.realtime])")
	nomad_rep_save()
	nomad_reputation = null
	raid_check(nomad_rep_score("good") == 5 && nomad_rep_score("bad") == -5, "reputation survives a restart")
	var/list/row = nomad_reputation["good"]
	raid_check(row["trades"] == 5, "deeds are counted")

	// A trader refuses a wanted player's payment, and sells at the buyer's price.
	nomad_reputation["bad"]["score"] = -20
	var/datum/nomad_raid/R = new
	R.setup(locate(20, 26, 1), list(), 2, "probe", "trade")
	nomad_raid = R
	R.begin_trade()
	var/obj/item/weapon/material/spear/dirty = new(get_turf(R.leader))
	dirty.fingerprintslast = "Bad"
	R.tick_trade(R.alive_members(), FALSE, TRUE)
	raid_check(!R.credit["bad"] && dirty.loc == get_turf(R.leader), "wanted players cannot trade")
	var/obj/item/good = R.goods[1]
	var/full = R.goods[good]
	R.credit["good"] = nomad_rep_price(full, "good")
	good.forceMove(locate(2, 2, 1))
	good.fingerprintslast = "Good"
	R.tick_trade(R.alive_members(), FALSE, TRUE)
	raid_check(!(good in R.goods) && R.credit["good"] == 0, "a trusted buyer pays the lower price ([nomad_rep_price(full, "good")] of [full])")
	raid_check(nomad_rep_score("good") == 6, "a purchase raises reputation")

	// Striking a peaceful party first, and killing a trader, are remembered.
	var/mob/living/human/brute = new(locate(3, 3, 1))
	brute.ckey = "brute"
	var/mob/living/simple_animal/hostile/human/nomad_raider/guard = R.members[2]
	guard.lastattacker = brute
	guard.health -= 10
	R.tick()
	R.tick()
	raid_check(nomad_rep_score("brute") == -3 && ("brute" in R.struck), "striking a peaceful party first costs reputation, once")
	R.member_fell(guard)
	raid_check(nomad_rep_score("brute") == -9, "killing a trader's guard costs more")
	R.remove_all("probe")
	qdel(brute)
	nomad_reputation = list()
	fdel(NOMAD_REP_FILE)

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
	for (var/i = 1, i <= 900 && nomad_raid, i++)
		sleep(1)
		if (R.leader && !QDELETED(R.leader))
			closest = min(closest, get_dist(R.leader, target))
		if (R.state == "leave")
			saw_leave = TRUE
	raid_check(closest <= 3 && closest < start_distance, "the party marched to the target ([start_distance] to [closest] tiles)")
	raid_check(saw_leave, "with nobody home the party turned back")
	raid_check(R.state == "ended" && isnull(nomad_raid), "the raid ended by itself")
	raid_check(R.escaped == R.initial_size && !R.members.len, "every raider left the map near home ([home.x],[home.y])")

// An island target: the party cannot walk there, so it comes by raft and leaves the same way.
/proc/raid_boat_checks()
	for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
		if (T.x >= 16 && T.x <= 24 && T.y >= 16 && T.y <= 24)
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		else
			T.ChangeTurf(/turf/floor/beach/water/deep, FALSE, FALSE)
	for (var/obj/O in block(locate(1, 1, 1), locate(40, 40, 1)))
		qdel(O)
	var/turf/target = locate(20, 20, 1)
	raid_check(!nomad_raid_land_reachable(locate(2, 20, 1), target), "the island cannot be walked to")
	var/datum/nomad_raid/R = new
	var/error = R.setup(target, list(), 3, "probe")
	raid_check(isnull(error) && R.sail_path && R.landing, "a party for an island target plans a water crossing ([error])")
	if (!R.sail_path)
		R.remove_all("probe")
		return
	raid_check(agent_deep_water(R.home) && !agent_deep_water(R.landing), "it starts on deep water and lands on dry ground")
	raid_check(get_dist(R.landing, target) <= 4, "the landing is on the island")
	R.launch_boats()
	raid_check(R.state == "sail" && R.rafts.len == R.members.len, "each member sets off on a raft")
	var/rafts_unsaved = TRUE
	for (var/M in R.rafts)
		var/obj/structure/vehicle/raft/raft = R.rafts[M]
		if (raft.should_save)
			rafts_unsaved = FALSE
	raid_check(rafts_unsaved, "party rafts are never saved")
	var/list/alive = R.alive_members()
	for (var/i = 1, i <= 200 && R.state == "sail", i++)
		R.next_sail = 0
		R.tick_sail(alive)
	raid_check(R.state == "march", "the party lands and marches")
	var/ashore = TRUE
	for (var/mob/living/M in alive)
		if (agent_deep_water(get_turf(M)) || get_dist(M, R.landing) > 1)
			ashore = FALSE
	raid_check(ashore, "every member stands ashore at the landing")
	R.set_state("leave", "probe")
	for (var/i = 1, i <= 200 && R.alive_members().len, i++)
		for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in R.alive_members())
			R.leave_by_boat(M)
		R.next_sail = 0
		R.sail_step()
	raid_check(!R.alive_members().len && R.escaped == alive.len, "the party paddles back out and leaves the map ([R.escaped] of [alive.len])")
	R.finish("probe")
	var/left = 0
	for (var/obj/structure/vehicle/raft/raft in world)
		if (!QDELETED(raft) && isturf(raft.loc))
			left++
	raid_check(!left && !R.rafts.len, "no party raft is left behind")

// Raiders with restraints disarm, knock down, bind and strip a foe; others chase.
/proc/raid_capture_checks()
	raid_check(nomad_raid_cuff_type(0) == /obj/item/weapon/handcuffs/rope && nomad_raid_cuff_type(4) == /obj/item/weapon/handcuffs/old && nomad_raid_cuff_type(6) == /obj/item/weapon/handcuffs, "restraints suit the age")
	var/turf/target = locate(20, 26, 1)
	var/datum/nomad_raid/R = new
	R.setup(target, list(), 2, "probe")
	nomad_raid = R
	var/mob/living/simple_animal/hostile/human/nomad_raider/M = R.leader
	var/obj/item/weapon/handcuffs/C = M.give_cuffs(0)
	raid_check(C && C.loc == M && !C.should_save, "a raider can carry unsaved rope restraints")
	var/turf/at = get_step(M, SOUTH)
	var/mob/living/human/V = new(at)
	var/obj/item/weapon/material/spear/held = new(at)
	V.put_in_hands(held)
	var/obj/item/clothing/shoes/S = new /obj/item/clothing/shoes/leather(at)
	V.equip_to_slot(S, slot_shoes)
	R.state = "assault"
	R.set_hostile(TRUE)
	M.target_mob = V
	var/steps = 0
	while (steps < 60 && V.get_active_hand() == held)
		R.capture_step(M)
		steps++
	raid_check(held.loc == at, "the raider wrenches the weapon out of their hands")
	steps = 0
	while (steps < 60 && !V.lying)
		R.capture_step(M)
		steps++
	raid_check(V.lying, "the raider knocks them down")
	R.capture_step(M)
	raid_check(V.handcuffed == C && !M.cuffs && C.should_save && R.captives[M] == V, "a downed foe is bound with the raider's restraints")
	raid_check(!R.foe_ok(V), "a bound prisoner is no longer fought")
	steps = 0
	while (steps < 20 && R.captives[M])
		R.capture_step(M)
		steps++
	raid_check(!V.shoes && (S in M.carried) && R.stripped == 1 && V.handcuffed == C, "the prisoner is stripped and stays bound")
	// A foe who runs is chased while near the target, and let go when far.
	var/mob/living/simple_animal/hostile/human/nomad_raider/F = R.members[2]
	var/mob/living/human/runner = new(locate(target.x + 8, target.y, 1))
	R.quarry[F] = runner
	raid_check(R.chase_step(F) && F.pathfind_target == get_turf(runner), "a raider chases a foe who ran")
	raid_check(R.quarry_left(), "a fleeing foe near the target keeps the fight going")
	runner.stat = UNCONSCIOUS
	raid_check(!R.chase_step(F) && !R.quarry_left(), "a foe who is down is no longer chased")
	R.remove_all("probe")
	qdel(runner)
	qdel(V)
