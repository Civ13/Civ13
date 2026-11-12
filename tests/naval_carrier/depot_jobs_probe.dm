// Depot work (code/modules/naval/depot_jobs.dm, docs/craft-core.md): the
// surveys and lost cargo a freight depot offers on land. A job names a spot
// some way off; a registered vehicle's crew takes it, the stake or the note
// reads the way, and the depot pays for a stake driven in or a crate brought
// back.
/world
	hub = ""
	hub_password = ""
	maxx = 200
	maxy = 24
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand on the land level with a strip of sea along
// the north edge, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(y >= 21 ? /turf/floor/beach/water/deep/saltwater : /turf/floor/beach/sand)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/datum/craft_drive/probe_push
	thrust = 1000

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

// The fixture's people have no body to redraw: hands are plain fields.
/mob/living/human/naval_probe/remove_from_mob(var/obj/O)
	if (l_hand == O)
		l_hand = null
	if (r_hand == O)
		r_hand = null
	O.forceMove(loc)
	return TRUE
/mob/living/human/naval_probe/update_icons()
	return
/mob/living/human/naval_probe/update_eyes()
	return
/mob/living/human/naval_probe/put_in_hands(var/obj/item/W)
	W.forceMove(src)
	return TRUE

// A registered vehicle stood in for by the one tile it is parked on.
/datum/craft_body/probe_spot
	var/turf/at
/datum/craft_body/probe_spot/placed()
	return !isnull(at)
/datum/craft_body/probe_spot/cells()
	return at ? list(at) : list()
/datum/craft_body/probe_spot/origin()
	return at

/proc/freight_person(char_name, faction, turf/T)
	var/mob/living/human/naval_probe/H = new(T)
	H.real_name = char_name
	H.name = char_name
	H.civilization = faction
	return H

// A closed crate with a wrench in it.
/proc/freight_crate(x, y)
	var/obj/structure/closet/crate/C = new(locate(x, y, 2))
	new /obj/item/weapon/wrench(C)
	return C

// Puts a fresh hammer in a character's active hand, as a reward to offer.
/proc/freight_reward(mob/living/human/H)
	var/obj/item/weapon/hammer/I = new(H)
	if (H.hand)
		H.l_hand = I
	else
		H.r_hand = I
	return I

/proc/naval_checks()
	naval_fixture()
	var/obj/structure/berth/quay/depot/D = new(locate(10, 10, 2))
	D.harbour = "Mill Yard"
	var/mob/living/human/naval_probe/ann = freight_person("Ann", "Reds", locate(10, 9, 2))
	var/mob/living/human/naval_probe/bob = freight_person("Bob", "Blues", locate(11, 9, 2))
	var/reds = party_train_party_of(ann)

	// ---- Where work can be ----
	naval_check(depot_job_ground(locate(100, 10, 2)) && !depot_job_ground(locate(100, 22, 2)) && !depot_job_ground(locate(100, 10, 1)), "open ground can hold a job; the sea and rock cannot")
	new /obj/structure/probe_rock(locate(101, 10, 2))
	naval_check(!depot_job_ground(locate(101, 10, 2)), "nor a tile with something standing on it")
	var/good = 0
	for (var/i = 1, i <= 20, i++)
		var/turf/found = D.find_spot()
		if (found && found.z == 2 && get_dist(D, found) >= 60 && get_dist(D, found) <= 220 && depot_job_ground(found))
			good++
	naval_check(good >= 15, "the depot finds spots 60 to 220 tiles off on open ground ([good] of 20)")

	naval_check(depot_bearing(locate(10, 10, 2), locate(130, 12, 2)) == "east" && depot_bearing(locate(10, 10, 2), locate(60, 20, 2)) == "east" && depot_bearing(locate(60, 5, 2), locate(20, 20, 2)) == "west" && depot_bearing(locate(10, 2, 2), locate(20, 12, 2)) == "northeast" && depot_bearing(locate(10, 20, 2), locate(12, 2, 2)) == "south", "a bearing is the nearest compass point")

	// ---- The board ----
	naval_check(!D.jobs().len && findtext(D.jobs_text(), "no work"), "an unread board has no work")
	naval_check(D.fill_jobs() == 3 && D.jobs(CONTRACT_OPEN).len == 3 && D.fill_jobs() == 0, "reading it fills three places, and not again at once")
	naval_check(!D.contracts().len && findtext(D.status_text(), "3 jobs of the depot's own") && findtext(D.freight_text(get_turf(D)), "No freight"), "its own work is not freight")
	for (var/obj/craft_contract/land/old in D.jobs())
		qdel(old)

	// ---- A survey ----
	var/turf/spot = locate(130, 12, 2)
	var/obj/craft_contract/land/survey/V = D.offer_job(/obj/craft_contract/land/survey, spot)
	var/obj/item/stack/money/real/coins = locate() in V
	naval_check(V && V.far == 120 && V.way == "east" && coins && coins.amount == 10 && findtext(V.describe(null), "Survey the land 120 tiles east"), "a survey names how far and which way, and what it pays ([V.describe(null)])")
	naval_check(!D.take_job(ann, V) && findtext(D.job_refusal, "registered crews") && V.state == CONTRACT_OPEN, "without a registered vehicle near it cannot be taken ([D.job_refusal])")
	var/datum/craft_body/probe_spot/parked = new
	parked.at = locate(14, 10, 2)
	var/datum/craft/vehicle/truck = new(parked)
	truck.name = "truck"
	truck.register = new /datum/craft_register
	truck.register.party = reds
	naval_check(D.take_job(ann, V) && V.state == CONTRACT_TAKEN && V.taker_party == reds && V.taker_craft == "truck", "Ann takes it for her truck")
	var/obj/item/depot_guide/stake/stake = locate() in ann
	naval_check(stake && stake.job_id == V.contract_id && findtext(V.way_from(get_turf(ann)), "about 120 tiles east"), "and is handed a stake that reads the way ([V.way_from(get_turf(ann))])")
	stake.attack_self(ann)
	naval_check(!QDELETED(stake) && !V.done && D.report_jobs(ann) == 0 && findtext(D.job_refusal, "not been driven in"), "used far from the spot it only reads the way, and nothing is paid yet")
	ann.forceMove(locate(127, 10, 2))
	naval_check(findtext(V.way_from(get_turf(ann)), "This is the spot"), "near the spot it says so")
	stake.attack_self(ann)
	naval_check(QDELETED(stake) && V.done && findtext(V.describe(null), "done and waiting"), "there the stake is driven in and the survey is done")
	ann.forceMove(locate(10, 9, 2))
	naval_check(D.report_jobs(bob) == 0 && D.report_jobs(ann) == 1 && QDELETED(V) && (coins.loc == ann || coins.loc == get_turf(ann)), "reported at the depot by her party, it is paid")

	// ---- Lost cargo ----
	spot = locate(100, 5, 2)
	var/obj/craft_contract/land/cargo/L = D.offer_job(/obj/craft_contract/land/cargo, spot)
	coins = locate() in L
	naval_check(L && coins.amount == 14 && !L.crate() && findtext(L.describe(null), "Lost cargo 90 tiles east"), "lost cargo pays more, and no crate lies out until it is taken ([L.describe(null)])")
	naval_check(D.take_job(ann, L) && L.state == CONTRACT_TAKEN, "Ann takes it")
	var/obj/structure/closet/crate/lost = L.crate()
	var/obj/item/depot_guide/note = null
	for (var/obj/item/depot_guide/G in ann)
		if (G.job_id == L.contract_id)
			note = G
	naval_check(lost && get_turf(lost) == spot && lost.name == "lost cargo crate" && note && !istype(note, /obj/item/depot_guide/stake), "the crate lies at the spot and she is handed a note of where")
	naval_check(D.hand_in_cargo(ann) == 0 && findtext(D.job_refusal, "within 2 tiles"), "nothing is paid while the crate is out there")
	new /obj/item/weapon/wrench(lost)
	lost.forceMove(locate(11, 11, 2))
	naval_check(D.hand_in_cargo(bob) == 0 && D.hand_in_cargo(ann) == 1 && QDELETED(L) && QDELETED(lost) && QDELETED(note) && (coins.loc == ann || coins.loc == get_turf(ann)), "brought to the depot it is paid; the depot keeps the crate and the note is done with")
	naval_check(locate(/obj/item/weapon/wrench) in locate(11, 11, 2), "what was put in the crate stays with the crew")

	// ---- Giving up, the limit and a blocked road ----
	var/obj/craft_contract/land/cargo/one = D.offer_job(/obj/craft_contract/land/cargo, locate(90, 5, 2))
	var/obj/craft_contract/land/survey/two = D.offer_job(/obj/craft_contract/land/survey, locate(95, 5, 2))
	var/obj/craft_contract/land/survey/three = D.offer_job(/obj/craft_contract/land/survey, locate(96, 5, 2))
	naval_check(D.take_job(ann, one) && D.take_job(ann, two) && !D.take_job(ann, three) && findtext(D.job_refusal, "already holds 2"), "a party holds two of a depot's jobs at most")
	var/obj/structure/closet/crate/out = one.crate()
	naval_check(!D.give_up_job(bob, one) && D.give_up_job(ann, one) && QDELETED(one) && QDELETED(out), "given up, a job is struck off with its crate")
	naval_check(D.take_job(ann, three), "which frees a place")
	truck.register.crew[bob.real_name] = "driver"
	naval_check(D.job_party(bob) == reds && D.give_up_job(bob, three) && QDELETED(three), "a hired driver on the truck's crew answers for her party at the board")
	var/obj/craft_contract/land/cargo/blocked = D.offer_job(/obj/craft_contract/land/cargo, locate(101, 10, 2))
	truck.register.party = party_train_party_of(bob)
	naval_check(!D.take_job(bob, blocked) && QDELETED(blocked) && findtext(D.job_refusal, "struck off"), "a lost cargo job whose spot is built over is struck off when someone tries it")
	var/obj/item/depot_guide/left = null
	for (var/obj/item/depot_guide/G in depot_guides)
		if (G.job_id == two.contract_id)
			left = G
	qdel(D)
	naval_check(QDELETED(two) && QDELETED(three) && QDELETED(left) && !depot_guides.len && !craft_contracts.len, "a depot that is destroyed takes its work with it")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
