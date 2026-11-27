/world
	hub = ""
	hub_password = ""
	maxx = 164
	maxy = 4
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/simple_animal/pigeon/post_probe/New()
	return

/mob/living/human/post_probe/New()
	return

/mob/living/human/post_probe/update_icons()
	return

var/post_probe_failures = 0
var/post_probe_runtime = FALSE

/proc/post_probe_check(condition, label)
	if (!condition)
		post_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	post_probe_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		post_probe_run()
	catch (var/exception/e)
		post_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = post_probe_failures, "runtime_error" = post_probe_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/post_probe_floor(x, z)
	var/turf/T = locate(x, 2, z)
	var/area/A = T.loc
	A.location = AREA_OUTSIDE
	return T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)

/proc/post_probe_run()
	var/turf/home = post_probe_floor(2, 1)
	var/turf/origin = post_probe_floor(162, 1)
	var/turf/far = post_probe_floor(163, 1)
	var/turf/cross_level = post_probe_floor(162, 2)
	var/mob/living/simple_animal/pigeon/P = new /mob/living/simple_animal/pigeon/post_probe(origin)
	var/obj/structure/pigeon_loft/L = new(home)
	post_probe_check(!P.pigeon_post_destination(), "untrained and older birds have no route")
	P.pigeon_post_train(L)
	var/saved_id = P.pigeon_home_id
	post_probe_check(saved_id && P.pigeon_post_destination() == L, "trained pigeon resolves its exact home at 160 tiles")
	var/list/bird_fields = P.get_saved_vars()
	var/list/loft_fields = L.get_saved_vars()
	post_probe_check(("pigeon_home_id" in bird_fields) && ("pigeon_home_x" in bird_fields) && ("pigeon_home_y" in bird_fields) && ("pigeon_home_z" in bird_fields) && ("pigeon_loft_id" in loft_fields), "production persistence selects home identity and coordinates")
	P.forceMove(far)
	post_probe_check(!P.pigeon_post_destination(), "over-range release is refused")
	P.forceMove(cross_level)
	post_probe_check(!P.pigeon_post_destination(), "another z-level cannot dispatch")
	P.forceMove(home)
	post_probe_check(!P.pigeon_post_destination(), "no flight to the current tile")
	P.forceMove(origin)
	var/area/A = home.loc
	A.location = AREA_INSIDE
	post_probe_check(!P.pigeon_post_destination(), "indoor home cannot receive a bird")
	A.location = AREA_OUTSIDE
	var/obj/structure/barrier = new /obj/structure(home)
	barrier.density = TRUE
	post_probe_check(!P.pigeon_post_destination(), "blocked home cannot receive a bird")
	barrier.density = FALSE
	post_probe_check(P.pigeon_post_destination() == L, "clearing the loft restores the route")
	qdel(L)
	var/obj/structure/pigeon_loft/replacement = new(home)
	post_probe_check(!P.pigeon_post_destination(), "replacement at the same coordinates does not inherit the old route")
	P.pigeon_post_train(replacement)
	post_probe_check(P.pigeon_post_destination() == replacement && replacement.pigeon_loft_id != saved_id, "retraining at replacement restores only its new route")

	var/obj/item/weapon/paper/letter = new(origin)
	var/obj/item/weapon/storage/envelope/env = new(origin)
	post_probe_check(pigeon_post_letter(letter) && !pigeon_post_letter(env), "loose sheets work and empty envelopes do not")
	letter.forceMove(env)
	post_probe_check(!pigeon_post_letter(env), "open envelopes are refused")
	env.opened = FALSE
	post_probe_check(pigeon_post_letter(env), "closed envelope containing exactly one sheet works")
	var/obj/item/weapon/paper/second = new(env)
	post_probe_check(!pigeon_post_letter(env), "more than one sheet is refused")
	qdel(second)
	env.knifed = TRUE
	post_probe_check(!pigeon_post_letter(env), "cut envelope is refused")

	// Use the real hand custody and movement hooks without a Dream Seeker client.
	var/mob/living/human/post_probe/H = new(origin)
	H.pulling = P
	P.pulledby = H
	letter.forceMove(H)
	H.r_hand = letter
	letter.nodrop = TRUE
	post_probe_check(!P.pigeon_post_deliver(H, letter, replacement) && letter.loc == H && P.loc == origin, "unreleasable paper stays in hand without moving the bird")
	letter.nodrop = FALSE
	post_probe_check(P.pigeon_post_deliver(H, letter, replacement) && P.loc == home && letter.loc == home && !H.item_is_in_hands(letter) && !H.pulling && !P.pulledby, "delivery moves the original bird and sheet and clears the sender's hand and pull")
