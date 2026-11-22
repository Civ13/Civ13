// Full-source probe for Send Player to Region (region_admin_send.dm): the
// landing request and its payload check, where an arrival lands (the nearest
// dry shore walking in from the sea, or the nearest safe floor to given
// coordinates), the refusals the dry run lists, the hidden gate, and the
// audit notes. Real humans and turfs; no clients and no region group, so
// nothing travels.
/world
	hub = ""
	visibility = 0
	maxx = 30
	maxy = 20
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/region_admin_send_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/region_admin_send_probe/New()
	map = src

/turf/floor/plating/region_admin_send_probe

/mob/living/human/region_admin_send_probe/human_subtile_authority(client/owner)
	return TRUE

var/region_admin_send_probe_checks = 0

/proc/region_admin_send_probe_assert(ok, label)
	region_admin_send_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/region_admin_send_probe_actor(tx, ty, account)
	var/mob/living/human/region_admin_send_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Traveller [account]"
	H.name = H.real_name
	H.persistence_owner_ckey = account
	return H

/proc/region_admin_send_probe_run()
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
	map = new /obj/map_metadata/region_admin_send_probe
	region_admin_send_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// The sea: the six western columns, then land.
	for (var/tx = 1 to 6)
		for (var/ty = 1 to world.maxy)
			new /turf/floor/beach/water/deep(locate(tx, ty, 1))

	// Landing requests: three kinds, coordinates as whole x,y,z.
	var/list/shore = region_admin_send_landing("shore", null, "val")
	region_admin_send_probe_assert(islist(shore) && shore["landing"] == "shore" && shore["by"] == "val" && isnull(shore["at"]), "shore_landing")
	var/list/coords = region_admin_send_landing("coords", " 15, 10 ,1", "val")
	region_admin_send_probe_assert(islist(coords) && coords["at"][1] == 15 && coords["at"][2] == 10 && coords["at"][3] == 1, "coords_landing")
	for (var/bad in list("15,10", "a,b,c", "1.5,2,3", "0,1,1", "1,2,3,4"))
		region_admin_send_probe_assert(istext(region_admin_send_landing("coords", bad, "val")), "bad_coords_[bad]")
	region_admin_send_probe_assert(istext(region_admin_send_landing("sky", null, "val")), "bad_mode")

	// The travel payload check: only these fields, coordinates only for coords.
	region_admin_send_probe_assert(region_admin_send_payload_ok(list()), "absent_ok")
	region_admin_send_probe_assert(region_admin_send_payload_ok(list("admin_send" = shore)), "shore_ok")
	region_admin_send_probe_assert(region_admin_send_payload_ok(list("admin_send" = coords)), "coords_ok")
	region_admin_send_probe_assert(!region_admin_send_payload_ok(list("admin_send" = list("landing" = "shore", "by" = "val", "at" = list(1, 1, 1)))), "shore_with_at")
	region_admin_send_probe_assert(!region_admin_send_payload_ok(list("admin_send" = list("landing" = "coords", "by" = "val"))), "coords_without_at")
	region_admin_send_probe_assert(!region_admin_send_payload_ok(list("admin_send" = list("landing" = "shore", "by" = "val", "extra" = 1))), "unknown_field")
	region_admin_send_probe_assert(!region_admin_send_payload_ok(list("admin_send" = list("landing" = "shore", "by" = ""))), "nobody_sent_it")
	region_admin_send_probe_assert(!region_admin_send_payload_ok(list("admin_send" = "shore")), "not_a_list")

	// The nearest dry shore: walking in from the sea's side, the first land tile.
	var/turf/T = region_admin_send_shore(list(WEST), 1)
	region_admin_send_probe_assert(T && T.x == 7 && !istype(T, /turf/floor/beach/water), "west_shore_found")
	region_admin_send_probe_assert(isnull(region_admin_send_shore(list(EAST, NORTH), 1)), "no_coast_there")
	region_admin_send_probe_assert(region_admin_send_shore(list(EAST, WEST), 1) == T, "first_side_with_a_coast")
	// A wall on the beach is no landing there; another line along the coast is used.
	var/obj/structure/wall = new /obj/structure(T)
	wall.density = TRUE
	var/turf/other = region_admin_send_shore(list(WEST), 1)
	region_admin_send_probe_assert(other && other != T && other.x == 7, "blocked_beach_skipped")
	qdel(wall)

	// Coordinates: the tile itself when safe, else the nearest safe floor, never water.
	region_admin_send_probe_assert(region_admin_send_near(locate(15, 10, 1)) == locate(15, 10, 1), "coords_exact")
	wall = new /obj/structure(locate(15, 10, 1))
	wall.density = TRUE
	var/turf/near = region_admin_send_near(locate(15, 10, 1))
	region_admin_send_probe_assert(near && get_dist(near, locate(15, 10, 1)) == 1, "coords_nearest_safe")
	qdel(wall)
	near = region_admin_send_near(locate(3, 10, 1))
	region_admin_send_probe_assert(near && near.x == 7, "coords_in_the_sea_go_ashore")

	// Where an arrival lands: the admin's choice for arrivals only.
	var/list/P = list("from" = "elsewhere", "admin_send" = coords)
	region_admin_send_probe_assert(region_admin_send_arrival_turf(P, TRUE) == locate(15, 10, 1) && P["admin_placed"], "arrival_at_coords")
	region_admin_send_probe_assert(isnull(region_admin_send_arrival_turf(list("from" = "elsewhere", "admin_send" = coords), FALSE)), "turned_back_not_placed")
	region_admin_send_probe_assert(isnull(region_admin_send_arrival_turf(list("from" = "elsewhere", "admin_send" = list("landing" = "arrival", "by" = "val")), TRUE)), "normal_arrival")
	region_admin_send_probe_assert(isnull(region_admin_send_arrival_turf(list("from" = "elsewhere"), TRUE)), "ordinary_traveller")

	// What the dry run refuses.
	var/mob/living/human/region_admin_send_probe/H = region_admin_send_probe_actor(10, 10, "alice")
	region_admin_send_probe_assert(isnull(region_admin_send_refusal(H)), "owner_can_go")
	H.stat = DEAD
	region_admin_send_probe_assert(region_admin_send_refusal(H) == "They are dead.", "dead_refused")
	H.stat = CONSCIOUS
	var/mob/living/human/region_admin_send_probe/nobody = region_admin_send_probe_actor(11, 10, null)
	region_admin_send_probe_assert(findtext(region_admin_send_refusal(nobody), "BYOND account"), "no_account_refused")
	var/obj/structure/closet/crate/box = new(locate(12, 10, 1))
	H.forceMove(box)
	region_admin_send_probe_assert(findtext(region_admin_send_refusal(H), "They are inside"), "inside_refused")
	H.forceMove(locate(10, 10, 1))
	var/obj/structure/bed/chair/seat = new(locate(10, 10, 1))
	H.buckled = seat
	var/list/warnings = region_admin_send_warnings(H)
	region_admin_send_probe_assert(length(warnings) && findtext(warnings[1], "leave"), "seat_left_behind")
	H.buckled = null

	// Outside a region group nothing can be sent, and the dry run says why.
	region_admin_send_probe_assert(region_admin_send_destination_refusal("gaia") == "This server is not part of a region group.", "no_group")
	var/list/rows = region_admin_send_preflight(list(H), "gaia", shore)
	region_admin_send_probe_assert(rows.len == 1 && !rows[1]["ok"] && rows[1]["ckey"] == "alice" && findtext(rows[1]["reason"], "region group"), "dry_run_refuses")
	var/list/host = region_admin_send_host(list("ckeys" = "alice,zed", "to" = "gaia", "landing" = "shore", "dry_run" = "1"))
	region_admin_send_probe_assert(host["send"] == "dry_run" && length(host["rows"]) == 2, "host_dry_run")
	host = region_admin_send_host(list("ckeys" = "alice", "to" = "gaia", "landing" = "shore", "dry_run" = "0"))
	region_admin_send_probe_assert(host["send"] == "refused:nobody can be sent now" && !region_admin_send_running, "host_send_refused")
	// Send held them, checked again, and let go of them when the check refused.
	region_admin_send_probe_assert(!H.travel_held() && !H.travel_hold && !H.incapacitated() && !travel_holds, "refused_send_releases")

	// Held still for a trip: no clicks, steps or actions until released.
	var/mob/living/human/region_admin_send_probe/stranger = region_admin_send_probe_actor(14, 12, "carol")
	var/obj/structure/closet/crate/cart = new(locate(11, 11, 1))
	var/obj/item/weapon/pen/pocket = new(H)
	var/datum/travel_hold/hold = travel_hold_begin(list(H), "Gaia", list(cart), list(locate(20, 15, 1)))
	region_admin_send_probe_assert(H.travel_held() && H.travel_hold.where == "Gaia" && travel_holds.len == 1, "trip_holds")
	region_admin_send_probe_assert(H.incapacitated() && H.incapacitated(INCAPACITATION_RESTRAINED) && !H.canClick() && travel_hold_input(H), "held_cannot_act")
	region_admin_send_probe_assert(!stranger.travel_held() && !travel_hold_input(stranger), "others_still_act")
	region_admin_send_probe_assert(isnull(region_admin_send_refusal(H)), "held_can_still_go")
	region_admin_send_probe_assert(H.persistence_runtime_var("travel_hold") && H.persistence_runtime_var("travel_hold_told"), "hold_not_saved")
	// Their body, what they carry, what they pull and the ground of their craft are guarded from others.
	region_admin_send_probe_assert(travel_hold_refuses(stranger, H) && travel_hold_refuses(stranger, pocket) && travel_hold_refuses(stranger, cart), "belongings_guarded")
	region_admin_send_probe_assert(travel_hold_refuses(stranger, locate(20, 15, 1)) && travel_hold_bars_step(stranger, locate(20, 15, 1)), "deck_guarded")
	region_admin_send_probe_assert(!travel_hold_refuses(stranger, locate(19, 15, 1)) && !travel_hold_bars_step(stranger, locate(19, 15, 1)), "elsewhere_free")
	region_admin_send_probe_assert(!travel_hold_guarding(H, cart) && !travel_hold_bars_step(H, locate(20, 15, 1)), "travellers_not_guarded_from_their_own")
	// A second hold over the same traveller: ending one leaves them in the other.
	var/datum/travel_hold/outer = travel_hold_begin(list(H), "Asia")
	travel_hold_end(outer)
	region_admin_send_probe_assert(H.travel_hold == hold && H.travel_held() && travel_holds.len == 1, "nested_hold_restored")
	travel_hold_release(hold, H)
	region_admin_send_probe_assert(!H.travel_held() && !H.incapacitated() && !travel_hold_input(H) && travel_hold_refuses(stranger, cart), "release_frees_traveller_only")
	travel_hold_end(hold)
	region_admin_send_probe_assert(!travel_holds && !travel_hold_refuses(stranger, cart) && !travel_hold_bars_step(stranger, locate(20, 15, 1)), "end_unguards")
	// A hold nothing renews lapses by itself, and the next one sweeps it away.
	hold = travel_hold_begin(list(H), "Gaia")
	hold.until = world.time - 1
	region_admin_send_probe_assert(!H.travel_held() && !H.incapacitated() && !travel_hold_refuses(stranger, H), "hold_lapses")
	var/datum/travel_hold/fresh = travel_hold_begin(list(stranger), "Gaia")
	region_admin_send_probe_assert(travel_holds.len == 1 && travel_holds[1] == fresh && !H.travel_hold, "lapsed_swept")
	travel_hold_end(fresh)
	qdel(pocket)
	qdel(cart)
	// Hold and check: everyone refused is let go at once, with the refusal in its row.
	var/list/checked = region_admin_send_hold_and_check(list(H, nobody), "gaia", shore, FALSE)
	var/list/checked_rows = checked["rows"]
	region_admin_send_probe_assert(checked_rows.len == 2 && !length(checked["ready"]) && !H.travel_held() && !nobody.travel_held() && !travel_holds, "hold_and_check_releases_refused")

	// The hidden gate: never an arrival point, never saved, carries the landing.
	var/obj/structure/region_gate/admin_send/gate = new(locate(20, 10, 1))
	gate.landing = shore
	region_admin_send_probe_assert(!gate.accepts_arrivals() && !gate.should_save && gate.invisibility > INVISIBILITY_MAXIMUM, "gate_hidden")
	var/list/extra = gate.travel_extra(H)
	region_admin_send_probe_assert(extra["admin_send"] == shore, "gate_carries_landing")
	qdel(gate)

	// The audit: the arrival names where it landed and who sent it; joining clears it.
	region_admin_send_arrived(H, list("owner" = "alice", "from" = "elsewhere", "admin_send" = coords, "admin_placed" = TRUE), TRUE, locate(15, 10, 1))
	var/list/note = region_admin_send_recent[region_admin_send_recent.len]
	region_admin_send_probe_assert(H.region_admin_sent == "val" && findtext(note["text"], "arrived") && findtext(note["text"], "15,10,1") && findtext(note["text"], "sent by val"), "arrival_logged")
	region_admin_send_probe_assert(H.persistence_runtime_var("region_admin_sent"), "audit_mark_not_saved")
	region_admin_send_claimed(H)
	region_admin_send_probe_assert(isnull(H.region_admin_sent) && findtext(region_admin_send_recent[region_admin_send_recent.len]["text"], "joined"), "join_logged")

	region_admin_send_probe_roundtrip()

// 1:1: a full before-and-after diff of a character sent through the travel
// record. Bags inside bags, a satchel, waterskins with water, primitive
// clothing, stacks, a master book, skills, research, people and languages.
/proc/region_admin_send_probe_roundtrip()
	var/turf/T = locate(20, 5, 1)
	var/mob/living/human/region_admin_send_probe/V = region_admin_send_probe_actor(20, 5, "voyager")
	var/obj/item/clothing/suit/prehistoricfurcoat/coat = new(T)
	coat.name = "Sigmundr's pelt coat"
	var/obj/item/clothing/under/leaves_skirt/au_naturel/leaves = new(T)
	var/obj/item/weapon/storage/backpack/pack_basket/basket = new(T)
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/skin = new(T)
	skin.reagents.add_reagent("water", 25)
	var/obj/item/weapon/storage/backpack/satchel/satchel = new(T)
	var/obj/item/stack/material/bone/bones = new(T, 7)
	var/obj/item/stack/ore/iron/ore = new(T, 4)
	var/obj/item/weapon/storage/backpack/pack_basket/inner = new(T)
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/skin2 = new(T)
	skin2.reagents.add_reagent("water", 10)
	inner.handle_item_insertion(skin2, TRUE)
	for (var/obj/item/I in list(bones, ore, inner))
		basket.handle_item_insertion(I, TRUE)
	var/obj/item/stack/material/bone/more_bones = new(T, 3)
	satchel.handle_item_insertion(more_bones, TRUE)
	// A preset coin pile travels as coins of the same amount.
	var/obj/item/stack/money/coppercoin/twohundred/coins = new(T)
	satchel.handle_item_insertion(coins, TRUE)
	var/obj/item/weapon/paddle/paddle = new(T)
	V.equip_to_slot_or_del(leaves, slot_w_uniform)
	V.equip_to_slot_or_del(coat, slot_wear_suit)
	V.equip_to_slot_or_del(basket, slot_back)
	V.equip_to_slot_or_del(skin, slot_wear_id)
	V.put_in_l_hand(paddle)
	V.put_in_r_hand(satchel)
	region_admin_send_probe_assert(V.back == basket && V.r_hand == satchel && V.w_uniform == leaves, "voyager_dressed")
	var/list/first = V.stats["crafting"]
	if (islist(first))
		// Trained skills are long fractions; JSON keeps six digits of them.
		V.stats["crafting"] = list(first[1] + 7.364746123, first[2] + 3.0049871)
	V.region_travel_restore_tongues(list("known" = list("Latin" = 100, "Old Norse" = 41.5), "default" = "Latin", "origin" = "latins", "land" = "Gaia"))
	V.nutrition = 321
	V.water = 222
	// Wounds stay on their own limbs: a cut leg, a burnt arm, a broken leg,
	// a lost foot and some poisoning, none of it worse on arrival.
	var/obj/item/organ/external/leg = V.organs_by_name["l_leg"]
	leg.createwound(CUT, 15)
	leg.update_damages()
	var/obj/item/organ/external/arm = V.organs_by_name["r_arm"]
	arm.createwound(BURN, 8)
	arm.update_damages()
	var/obj/item/organ/external/shin = V.organs_by_name["r_leg"]
	shin.status |= ORGAN_BROKEN
	var/obj/item/organ/external/foot = V.organs_by_name["l_foot"]
	foot.removed(null)
	qdel(foot)
	V.setToxLoss(5)
	V.updatehealth()
	var/list/limbs = V.region_travel_limbs()
	region_admin_send_probe_assert(json_encode(limbs["l_leg"]) == "\[15,0,0]" && json_encode(limbs["r_arm"]) == "\[0,8,0]" && json_encode(limbs["r_leg"]) == "\[0,0,1]" && limbs["l_foot"] == "missing", "limbs_recorded: [json_encode(limbs)]")
	var/list/before = region_admin_send_fingerprint(V)
	region_admin_send_probe_assert(length(before["items"]) == 6 && length(before["tongues"]) >= 3, "fingerprint_sees_everything")
	var/list/carried = V.region_travel_items()
	region_admin_send_probe_assert(islist(carried), "voyager_refused: [carried]")
	var/list/landing = list("landing" = "shore", "by" = "val", "check" = md5(json_encode(before)))
	var/list/P = region_travel_decode(V.region_travel_payload(carried, null, FALSE, list("admin_send" = landing)))
	region_admin_send_probe_assert(islist(P), "payload_decodes")
	var/mob/living/human/arrived = region_travel_build(P, locate(25, 15, 1))
	var/list/after = region_admin_send_fingerprint(arrived, TRUE)
	var/obj/item/organ/external/arrived_shin = arrived.organs_by_name["r_leg"]
	var/obj/item/organ/external/arrived_leg = arrived.organs_by_name["l_leg"]
	region_admin_send_probe_assert(arrived_shin && (arrived_shin.status & ORGAN_BROKEN) && !arrived.organs_by_name["l_foot"] && arrived_leg && !(arrived_leg.status & ORGAN_BROKEN), "wounds_where_they_were")
	region_admin_send_probe_assert(arrived.getToxLoss() == 5, "poison_carried")
	var/list/diff = region_admin_send_fingerprint_diff(before, after)
	region_admin_send_probe_assert(!diff.len, "one_to_one: [jointext(diff, "; ")] | before [json_encode(before)] | after [json_encode(after)]")
	region_admin_send_probe_assert(md5(json_encode(after)) == landing["check"], "arrival_check_matches")
	var/list/sent_checks = region_admin_send_checks(before)
	region_admin_send_probe_assert(!length(region_admin_send_checks_diff(sent_checks, region_admin_send_checks(after))), "part_checks_match")
	// Heavy wounds arrive whole, on the same limbs, with nothing broken or cut off by the trip.
	var/list/hurt = P.Copy()
	hurt["limbs"] = list("chest" = list(70, 0, 0), "l_arm" = list(55, 20, 0))
	var/mob/living/human/hurt_arrival = region_travel_build(hurt, locate(26, 15, 1))
	var/list/hurt_limbs = hurt_arrival.region_travel_limbs()
	region_admin_send_probe_assert(json_encode(hurt_limbs["chest"]) == "\[70,0,0]" && json_encode(hurt_limbs["l_arm"]) == "\[55,20,0]" && hurt_limbs.len == 2, "heavy_wounds_carried_exactly: [json_encode(hurt_limbs)]")
	// The check catches a lost item, a changed amount and a dropped language.
	var/obj/item/stack/material/bone/b2 = locate() in arrived.back
	b2.amount = 6
	region_admin_send_probe_assert(length(region_admin_send_fingerprint_diff(before, region_admin_send_fingerprint(arrived, TRUE))) == 1, "changed_amount_caught")
	region_admin_send_probe_assert(("items:back" in region_admin_send_checks_diff(sent_checks, region_admin_send_checks(region_admin_send_fingerprint(arrived, TRUE)))), "changed_amount_named")
	b2.amount = 7
	qdel(arrived.l_hand)
	region_admin_send_probe_assert(length(region_admin_send_fingerprint_diff(before, region_admin_send_fingerprint(arrived, TRUE))) == 1, "lost_item_caught")
	arrived.region_travel_restore_tongues(list("known" = list("Latin" = 100), "default" = "Latin", "origin" = "latins", "land" = "Gaia"))
	region_admin_send_probe_assert(length(region_admin_send_fingerprint_diff(before, region_admin_send_fingerprint(arrived, TRUE))) == 2, "lost_language_caught")

/world/New()
	OpenPort("none")
	var/error = null
	try
		region_admin_send_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = region_admin_send_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
