// Full-source probe: peep-holes, judas hatches, mail slots and pet doors
// (door_features.dm). Each fits with a screwdriver from the side it serves,
// and all of a door's features serve one side; the peep-hole looks out one
// way; an open hatch lets both sides see through the shut door; post goes
// through to the slot's side; small animals pass a shut door with a pet door
// unless it is locked, people never; a screwdriver takes them off again.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/door_features_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/door_features_probe/New()
	map = src

/turf/floor/plating/door_features_probe

var/door_features_probe_checks = 0
var/door_features_runtime = null

/world/Error(exception/e)
	if (!door_features_runtime)
		door_features_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/door_features_assert(ok, label)
	door_features_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/door_features_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

/proc/door_features_open(obj/structure/simple_door/D)
	D.Open()
	sleep(12)

/proc/door_features_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)


// A door with walls north and south: people pass east-west.
/proc/door_features_door(tx, ty, path, wall = /turf/wall)
	new wall(locate(tx, ty + 1, 1))
	new wall(locate(tx, ty - 1, 1))
	var/obj/structure/simple_door/D = new path(locate(tx, ty, 1))
	sleep(10)
	return D

/proc/door_features_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/door_features_probe

	var/obj/structure/simple_door/key_door/anyone/wood/D = door_features_door(5, 5, /obj/structure/simple_door/key_door/anyone/wood)
	var/mob/living/human/inside = door_features_actor(6, 5, "Inside")
	var/mob/living/human/outside = door_features_actor(4, 5, "Outside")
	var/obj/item/weapon/screwdriver/driver = new
	var/obj/item/weapon/screwdriver/driver2 = new

	// A peep-hole needs a screwdriver and serves the fitter's side.
	var/obj/item/door_feature/peephole/peep = new
	door_features_hands(inside, peep, null)
	D.attackby(peep, inside)
	door_features_assert(!D.door_features && !QDELETED(peep), "peephole_needs_screwdriver")
	door_features_hands(inside, peep, driver)
	D.attackby(peep, inside)
	door_features_assert(D.door_has_feature(1) && D.door_feature_side == EAST && QDELETED(peep), "peephole_fitted")
	door_features_assert(D.door_can_look_through(inside) && !D.door_can_look_through(outside), "peephole_one_way")
	door_features_assert(D.door_view_turf(inside) == locate(4, 5, 1), "peephole_shows_outside")
	door_features_assert(D.fitting_images && D.fitting_images.len, "feature_overlay")

	// Every feature serves the same side.
	var/obj/item/door_feature/mail_slot/slot = new
	door_features_hands(outside, slot, driver2)
	D.attackby(slot, outside)
	door_features_assert(!D.door_has_feature(4) && !QDELETED(slot), "same_side_only")

	// The judas hatch slides from its side and lets both sides see through.
	var/obj/item/door_feature/judas_hatch/hatch = new
	door_features_hands(inside, hatch, driver)
	D.attackby(hatch, inside)
	door_features_assert(D.door_has_feature(2), "hatch_fitted")
	door_features_assert(!D.slide_judas_hatch(outside) && !D.judas_open, "hatch_slides_from_inside_only")
	door_features_assert(D.slide_judas_hatch(inside) && D.judas_open && !D.opacity, "hatch_open")
	door_features_assert(D.door_can_look_through(outside), "outside_sees_through_hatch")
	D.Open()
	sleep(12)
	D.Close()
	sleep(12)
	door_features_assert(!D.state && D.judas_open && !D.opacity, "hatch_stays_open_when_shut")
	D.slide_judas_hatch(inside)
	door_features_assert(!D.judas_open && D.opacity && !D.door_can_look_through(outside), "hatch_shut")

	// Post from outside drops through to the inside, into a crate if one stands there.
	door_features_hands(inside, slot, driver)
	D.attackby(slot, inside)
	door_features_assert(D.door_has_feature(4), "mail_slot_fitted")
	var/turf/mail_landing = locate(6, 5, 1)
	var/obj/item/weapon/paper/letter = new
	door_features_hands(outside, letter, null)
	D.attackby(letter, outside)
	door_features_assert(letter.loc == mail_landing, "letter_posted")
	var/obj/item/weapon/paper/back = new
	door_features_hands(inside, back, null)
	D.attackby(back, inside)
	door_features_assert(back.loc != locate(4, 5, 1), "no_posting_outwards")
	var/obj/item/weapon/hammer/hammer = new
	door_features_assert(!door_mail_postable(hammer) && door_mail_postable(letter), "only_flat_things")
	letter.forceMove(locate(6, 6, 1))
	var/obj/structure/closet/crate/box = new(mail_landing)
	box.storagecap = 1
	box.close()
	var/obj/item/weapon/paper/letter2 = new
	door_features_hands(outside, letter2, null)
	D.attackby(letter2, outside)
	door_features_assert(letter2.loc == box, "letter_into_crate")
	var/obj/item/weapon/paper/overflow_letter = new
	door_features_hands(outside, overflow_letter, null)
	D.attackby(overflow_letter, outside)
	door_features_assert(overflow_letter.loc == mail_landing && closet_item_count(box) == 1, "full_crate_leaves_letter_on_floor")
	qdel(box)
	overflow_letter.forceMove(locate(6, 6, 1))

	var/obj/structure/closet/crate/wall_mailbox/wood_mailbox/mailbox = new(mail_landing)
	mailbox.storagecap = 2
	mailbox.close()
	var/obj/item/weapon/paper/mail = new
	door_features_hands(outside, mail, null)
	D.attackby(mail, outside)
	door_features_assert(mail.loc == mailbox && closet_item_count(mailbox) == 1, "door_delivery_counts_as_mail")
	var/obj/item/weapon/paper/direct_mail = new
	door_features_hands(inside, direct_mail, null)
	mailbox.attackby(direct_mail, inside)
	door_features_assert(direct_mail.loc == mailbox && closet_item_count(mailbox) == 2, "direct_mail_shares_capacity_with_door_delivery")
	var/obj/item/weapon/paper/extra_mail = new
	door_features_hands(inside, extra_mail, null)
	mailbox.attackby(extra_mail, inside)
	door_features_assert(extra_mail.loc == inside, "full_mailbox_rejects_direct_mail")
	inside.drop_r_hand()
	door_features_hands(outside, extra_mail, null)
	D.attackby(extra_mail, outside)
	door_features_assert(extra_mail.loc == mail_landing && closet_item_count(mailbox) == 2, "full_mailbox_leaves_letter_on_floor")
	qdel(mailbox)

	// A pet door lets small animals through the shut door, not people.
	var/obj/item/door_feature/pet_door/flap = new
	door_features_hands(inside, flap, driver)
	D.attackby(flap, inside)
	door_features_assert(D.door_has_feature(8), "pet_door_fitted")
	var/mob/living/simple_animal/pet/cat/cat = new(locate(4, 6, 1))
	door_features_assert(D.density && D.CanPass(cat, get_turf(D)) && !D.CanPass(outside, get_turf(D)), "pet_door_admits_cat")
	door_features_assert(!D.toggle_pet_door_lock(outside) && !D.pet_door_locked, "pet_lock_inside_only")
	door_features_assert(D.toggle_pet_door_lock(inside) && D.pet_door_locked && !D.CanPass(cat, get_turf(D)), "pet_door_locked")
	D.toggle_pet_door_lock(inside)

	// A screwdriver from the inside takes one off again; not from outside.
	door_features_hands(outside, driver2, null)
	door_features_assert(!D.remove_door_feature(1, driver2, outside) && D.door_has_feature(1), "no_removal_outside")
	door_features_hands(inside, driver, null)
	door_features_assert(D.remove_door_feature(1, driver, inside) && !D.door_has_feature(1), "peephole_removed")
	door_features_assert(locate(/obj/item/door_feature/peephole) in list(inside.l_hand, inside.r_hand), "peephole_returned")

	// Windows refuse them.
	var/obj/structure/window_frame/frame = new(locate(9, 9, 1))
	new /turf/wall(locate(9, 10, 1))
	new /turf/wall(locate(9, 8, 1))
	var/obj/structure/simple_door/key_door/anyone/window_shutters/S = new(get_turf(frame))
	sleep(10)
	var/obj/item/door_feature/pet_door/flap2 = new
	var/mob/living/human/shutterer = door_features_actor(10, 9, "Shutterer")
	door_features_hands(shutterer, flap2, new /obj/item/weapon/screwdriver)
	S.attackby(flap2, shutterer)
	door_features_assert(!S.door_features && !QDELETED(flap2), "windows_refuse")

	// Taking the door down returns its features.
	D.door_feature_parts_returned(get_turf(D))
	door_features_assert(!D.door_features && (locate(/obj/item/door_feature/mail_slot) in get_turf(D)) && (locate(/obj/item/door_feature/pet_door) in get_turf(D)), "parts_returned")

/world/New()
	OpenPort("none")
	var/error = null
	try
		door_features_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && door_features_runtime)
		error = door_features_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = door_features_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
