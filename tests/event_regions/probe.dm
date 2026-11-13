// Full-source probe: an event transfer keeps a home character out of play in
// a hidden stash on its tile, stops its clock, and puts it back exactly as it
// was: where it stood, beside its assigned bed, or on the nearest safe floor
// when its tile was built over. Real humans, beds and food; no clients.
/world
	hub = ""
	visibility = 0
	maxx = 20
	maxy = 20
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/event_regions_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/event_regions_probe/New()
	map = src

/turf/floor/plating/event_regions_probe

/mob/living/human/event_regions_probe/human_subtile_authority(client/owner)
	return TRUE

var/event_regions_probe_checks = 0

/proc/event_regions_probe_assert(ok, label)
	event_regions_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/event_regions_probe_actor(tx, ty, account)
	var/mob/living/human/event_regions_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Traveller [account]"
	H.name = H.real_name
	H.persistence_owner_ckey = account
	return H

/proc/event_regions_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/event_regions_probe
	event_regions_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// Someone else's character, a dead one, or one riding cannot be sent.
	var/mob/living/human/event_regions_probe/H = event_regions_probe_actor(5, 5, "alice")
	event_regions_probe_assert(event_stash_refusal(H, "bob") == "is not playing their own character", "own_character_only")
	H.stat = DEAD
	event_regions_probe_assert(event_stash_refusal(H, "alice") == "is dead", "dead_refused")
	H.stat = CONSCIOUS
	event_regions_probe_assert(isnull(event_stash_refusal(H, "alice")), "living_owner_accepted")

	// Kept: carried food, hunger and wounds stay as they were.
	var/obj/item/weapon/reagent_containers/food/snacks/F = new /obj/item/weapon/reagent_containers/food/snacks/grown/apple(H.loc)
	H.put_in_r_hand(F)
	H.adjustBruteLoss(12)
	H.nutrition = 321
	var/brute = H.getBruteLoss()
	var/obj/structure/event_stash/S = event_stash_character(H, "alice", "fair", "spot")
	event_regions_probe_assert(S && H.loc == S && S.loc == locate(5, 5, 1), "stashed_on_its_tile")
	event_regions_probe_assert(S.invisibility > INVISIBILITY_MAXIMUM && !S.density && !S.mouse_opacity && S.anchored, "stash_hidden_and_harmless")
	event_regions_probe_assert(S.owner_ckey == "alice" && S.event_region == "fair" && S.return_mode == "spot" && S.body() == H, "stash_records_owner")
	event_regions_probe_assert(event_stash_of("alice") == S && (S in event_stashes()) && isnull(event_stash_of("bob")), "stash_found_by_account")
	event_regions_probe_assert(event_stash_holds(H) && event_stash_holds(F) && !event_stash_holds(S), "clock_stopped_inside")
	event_regions_probe_assert(isnull(event_stash_character(H, "alice", "fair")), "not_stashed_twice")
	// Nothing on the tile reaches the stashed character.
	var/mob/living/human/event_regions_probe/passer = event_regions_probe_actor(5, 6, "carol")
	event_regions_probe_assert(S.CanPass(passer, S.loc) && persistence_character_turf_safe(S.loc, passer), "tile_stays_walkable")
	passer.forceMove(locate(5, 5, 1))
	event_regions_probe_assert(!(H in range(1, passer)) && !(H in view(7, passer)), "out_of_reach_and_sight")
	S.Move(locate(6, 5, 1))
	event_regions_probe_assert(S.loc == locate(5, 5, 1), "stash_does_not_move")
	passer.forceMove(locate(2, 2, 1))

	// Back where it stood, as it was.
	event_regions_probe_assert(S.release(), "released")
	event_regions_probe_assert(H.loc == locate(5, 5, 1) && QDELETED(S) && isnull(event_stash_of("alice")), "back_where_it_stood")
	event_regions_probe_assert(H.r_hand == F && H.getBruteLoss() == brute && H.nutrition == 321 && !event_stash_holds(H), "unchanged_after_return")

	// Back beside its assigned bed when asked.
	var/obj/structure/bed/B = new(locate(12, 12, 1))
	B.anchored = TRUE
	B.persistence_bed_owner_ckey = "alice"
	S = event_stash_character(H, "alice", "fair", "spot")
	event_regions_probe_assert(S && H.loc == S, "stashed_again")
	S.return_mode = "bed"
	event_regions_probe_assert(S.release() && H.loc == B.loc, "back_at_bed")

	// Bed mode without a usable bed: where it stood.
	H.forceMove(locate(3, 3, 1))
	S = event_stash_character(H, "alice", "fair", "spot")
	B.persistence_bed_owner_ckey = "someone_else"
	event_regions_probe_assert(S.release("bed") && H.loc == locate(3, 3, 1), "no_bed_falls_back_to_spot")

	// Its tile built over meanwhile: the nearest safe floor.
	S = event_stash_character(H, "alice", "fair", "spot")
	var/obj/structure/barricade = new /obj/structure(locate(3, 3, 1))
	barricade.density = TRUE
	event_regions_probe_assert(S.release("spot") && H.loc != locate(3, 3, 1) && get_dist(H, locate(3, 3, 1)) == 1, "blocked_tile_nearest_safe")
	qdel(barricade)

	// A stash destroyed by anything never takes the character with it.
	H.forceMove(locate(8, 8, 1))
	S = event_stash_character(H, "alice", "fair", "spot")
	qdel(S)
	event_regions_probe_assert(H.loc == locate(8, 8, 1) && !QDELETED(H) && isnull(event_stash_of("alice")), "destroyed_stash_releases")

	// Outside a region group nothing answers the loopback messages.
	var/datum/world_topic/event_return/answer = new
	var/list/reply = answer.Run(list("token" = "x", "mode" = "spot", "ckeys" = "\[\"alice\"]"))
	event_regions_probe_assert(reply["ok"] == 0, "no_group_no_answer")

/world/New()
	OpenPort("none")
	var/error = null
	try
		event_regions_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = event_regions_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
