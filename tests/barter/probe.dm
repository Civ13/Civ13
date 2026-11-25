// Native barter probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/barter.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/barter_probe/New()
	map = src
/mob/living/human/barter_probe/New()
	icon_update = FALSE
	return
var/barter_failures = 0
var/barter_runtime_error = FALSE
/proc/barter_check(condition, label)
	if (!condition)
		barter_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	barter_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/barter_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		barter_trade_checks()
	catch(var/exception/e)
		barter_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = barter_failures, "runtime_error" = barter_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/barter_probe_human(x, y)
	var/mob/living/human/barter_probe/H = new(locate(x, y, 1))
	H.real_name = "Trader [x]"
	H.stat = CONSCIOUS
	return H

/proc/barter_trade_checks()
	var/obj/structure/barter_mat/M = new(locate(10, 10, 1))
	var/mob/living/human/A = barter_probe_human(9, 10)
	var/mob/living/human/B = barter_probe_human(11, 10)
	var/mob/living/human/C = barter_probe_human(10, 11)
	var/obj/item/stack/barter_beads/stone/beads = new(locate(9, 10, 1), 5)
	var/obj/item/stack/barter_beads/bone/bone = new(locate(11, 10, 1), 3)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/W = new(locate(11, 10, 1))
	barter_check(M.offer(A, beads) && beads.loc == M, "a trader lays an offer on the mat")
	barter_check(!M.agree(A, M.agreement_revision), "nobody can agree alone")
	barter_check(M.offer(B, bone) && M.traders.len == 2, "a second trader joins")
	var/obj/item/stack/barter_beads/stone/extra = new(locate(10, 11, 1))
	barter_check(!M.offer(C, extra) && extra.loc != M, "a third person cannot join")
	barter_check(!M.agree(A, M.agreement_revision) && (A in M.agreed), "the first agreement waits")
	var/old_revision = M.agreement_revision
	M.offer(B, W)
	barter_check(!length(M.agreed), "changing an offer clears agreement")
	barter_check(!M.agree(A, old_revision) && !length(M.agreed), "a stale acceptance is not recorded")
	barter_check(!M.agree(B, M.agreement_revision) && (B in M.agreed), "one current acceptance cannot finish the trade")
	barter_check(!M.agree(A, old_revision) && beads.loc == M, "a stale acceptance cannot finish a trade")
	M.agree(A, M.agreement_revision)
	barter_check(M.agree(B, M.agreement_revision), "both agreeing swaps the offers")
	barter_check(beads.loc == get_turf(B) && bone.loc == get_turf(A) && W.loc == get_turf(A), "each side gets the other's goods")
	barter_check(!M.traders.len && !length(M.contents), "the mat is clear after a trade")
	var/obj/item/stack/barter_beads/bone/more = new(locate(9, 10, 1))
	M.offer(A, more)
	A.forceMove(locate(20, 20, 1))
	M.tidy()
	barter_check(!M.traders.len && more.loc == get_turf(M), "walking away returns the offer to the mat's tile")
	var/obj/item/stack/barter_beads/stone/kept = new(locate(11, 10, 1))
	M.offer(B, kept)
	M.after_load()
	barter_check(!M.traders.len && kept.loc == get_turf(M), "a reloaded mat drops what lay on it")
