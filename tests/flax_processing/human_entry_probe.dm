// Prepared source only. No inventory/drop/slot/icon or soak override on this actor.
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/human/flax_entry_actor
	var/entry_waits = 0
	var/entry_delay = 0
	var/entry_mode = "interrupt"
	var/entry_clean_at_wait = FALSE

/mob/living/human/flax_entry_actor/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	defaultHUD = "1713Style"
	create_HUDinventory()
	stat = CONSCIOUS
	lying = FALSE
	sleeping = 0

// Observe entry, then invoke the real production wait with its implicit delay
// and target. Movement cancels a real wait; no success result is manufactured.
/mob/living/human/flax_entry_actor/flax_processing_wait(delay, atom/target)
	entry_waits++
	entry_delay = delay
	var/obj/item/flax_bundle/B = target
	entry_clean_at_wait = B && istype(B.loc, /turf/floor/beach/water) && !item_is_in_hands(B) && !B.screen_loc
	if (client)
		entry_clean_at_wait = entry_clean_at_wait && !(B in client.screen)
	if (entry_mode == "interrupt" || (entry_mode == "partial" && entry_waits > 1))
		spawn(1)
			forceMove(locate(7,7,1))
	return ..()

// Failure injection only at the physical movement/special-nodrop seams.
/obj/item/flax_bundle/entry_move
	var/turf/entry_water
	var/turf/entry_redirect
	var/entry_deny = FALSE
	var/entry_special = FALSE

/obj/item/flax_bundle/entry_move/nodrop_special_check()
	return entry_special || ..()

/obj/item/flax_bundle/entry_move/forceMove(atom/destination, special_event)
	if (destination == entry_water)
		if (entry_deny)
			return FALSE
		if (entry_redirect)
			return ..(entry_redirect, special_event)
	return ..()

// Anatomical-list membership tests use real organ types with constructor-only
// adapters; they do not simulate attachment/biology or alter either human guard.
/obj/item/organ/flax_entry/New()
	return

/obj/item/organ/external/flax_entry/New()
	return

// Only table construction is isolated; MouseDrop_T and physical step are real.
/obj/structure/table/flax_entry/New()
	return

/proc/flax_entry_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "ENTRY PASS: [message]"

/proc/flax_entry_count(atom/site, path)
	var/count = 0
	for (var/obj/item/I in site)
		if (istype(I, path))
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				count += S.amount
			else
				count++
	return count

/proc/flax_entry_held(mob/living/human/U, obj/item/I)
	flax_entry_assert(U.put_in_active_hand(I) && I.loc == U && U.get_active_hand() == I && I.screen_loc, "production pickup owns item and screen location")
	if (U.client)
		flax_entry_assert(I in U.client.screen, "connected pickup owns actual client screen membership")

/proc/flax_entry_clean(mob/living/human/U, obj/item/I)
	flax_entry_assert(!U.item_is_in_hands(I) && !I.screen_loc && I.plane == GAME_PLANE && I.layer == initial(I.layer), "production drop clears slots and HUD item state")
	flax_entry_assert(!U.overlays_standing[L_HAND_LAYER] && !U.overlays_standing[R_HAND_LAYER], "production drop clears hand overlays")
	if (U.client)
		flax_entry_assert(!(I in U.client.screen), "connected drop clears actual client screen membership")

/proc/flax_entry_afterattack_regressions(mob/living/human/flax_entry_actor/U, turf/site, turf/floor/beach/water/W)
	// This is the first oracle, including in the generated legacy-return control.
	// It consumes real raw flax and enters through afterattack, never manual soak.
	for (var/left in list(FALSE, TRUE))
		U.forceMove(site)
		U.hand = left
		U.entry_waits = 0
		U.entry_mode = "interrupt"
		var/obj/item/stack/material/flax/raw = new(site, 2, FALSE)
		flax_entry_assert(!raw.extraction_surface_source, "paid flax uses ordinary unowned pickup admission")
		flax_entry_held(U, raw)
		flax_entry_assert(raw.tie_bundle(U), "production bundle binding pays two flax")
		var/obj/item/flax_bundle/B = locate() in U
		flax_entry_assert(B && B.loc == U && U.get_active_hand() == B && !flax_entry_count(U, /obj/item/stack/material/flax), "actual paid bundle is held")
		B.afterattack(W, U, TRUE)
		flax_entry_assert(B.loc == W && !U.item_is_in_hands(B) && !B.screen_loc, "afterattack physically places the paid bundle before the entry oracle")
		flax_entry_assert(U.entry_waits == 1 && U.entry_delay == 100 && U.entry_clean_at_wait, "human afterattack enters production wait")
		flax_entry_assert(B.loc == W && B.soak_stage == 0 && !B.soaking && !flax_entry_count(W, /obj/item/stack/rotten_flax), "real interrupted first wait emits nothing")
		flax_entry_clean(U, B)
		qdel(B)
	U.forceMove(site)
	for (var/mode in list("nodrop", "special", "denied", "redirected", "salty", "irradiated"))
		U.entry_waits = 0
		var/obj/item/flax_bundle/entry_move/B = new(site)
		B.entry_water = W
		B.nodrop = mode == "nodrop"
		B.entry_special = mode == "special"
		B.entry_deny = mode == "denied"
		if (mode == "redirected")
			B.entry_redirect = locate(5,3,1)
		W.salty = mode == "salty"
		W.radiation = mode == "irradiated" ? 1 : 0
		flax_entry_held(U, B)
		B.afterattack(W, U, TRUE)
		flax_entry_assert(!U.entry_waits && !B.soak_stage && !B.soaking, "refused or misplaced entry does not wait: [mode]")
		if (mode == "denied" || mode == "redirected")
			flax_entry_assert(B.loc == (mode == "denied" ? site : B.entry_redirect), "failed or redirected move retains actual destination: [mode]")
			flax_entry_clean(U, B)
		else
			flax_entry_assert(B.loc == U && U.get_active_hand() == B && B.screen_loc, "pre-drop refusal preserves held ownership: [mode]")
			B.nodrop = FALSE
			B.entry_special = FALSE
			U.drop_from_inventory(B, site)
		qdel(B)
	W.salty = FALSE
	W.radiation = 0
	// Genuine 100-ds waits: one completed stage, interruption, then two remaining
	// stages via the ordinary placed-item click. Total waiting is about 301 ds.
	U.entry_waits = 0
	U.entry_mode = "partial"
	var/obj/item/flax_bundle/partial = new(site)
	flax_entry_held(U, partial)
	partial.afterattack(W, U, TRUE)
	flax_entry_assert(partial.loc == W && partial.soak_stage == 1 && U.entry_waits == 2 && !partial.soaking, "afterattack real wait interruption retains one completed stage")
	flax_entry_assert(!flax_entry_count(W, /obj/item/stack/rotten_flax), "partial production entry emits no output")
	U.forceMove(site)
	U.entry_mode = "complete"
	partial.attack_hand(U)
	flax_entry_assert(!partial.loc && flax_entry_count(W, /obj/item/stack/rotten_flax) == 2, "ordinary resume completes exactly two rotten flax")
	if (partial)
		partial.afterattack(W, U, TRUE)
	flax_entry_assert(flax_entry_count(W, /obj/item/stack/rotten_flax) == 2, "consumed bundle cannot replay afterattack")

/proc/flax_entry_drop_contracts(mob/living/human/flax_entry_actor/U, turf/site, turf/W)
	flax_entry_assert(!U.drop_from_inventory(null, W), "null drop rejected")
	for (var/left in list(FALSE, TRUE))
		U.hand = left
		var/obj/item/flax_bundle/B = new(site)
		flax_entry_held(U, B)
		flax_entry_assert(!U.drop_from_inventory(B, W, TRUE) && B.loc == U && U.get_active_hand() == B, "implicit third TRUE preserves existing parent refusal")
		flax_entry_assert(U.drop_from_inventory(B, W, FALSE) && B.loc == W, "implicit third FALSE and explicit target reach production parent")
		flax_entry_clean(U, B)
		qdel(B)
	for (var/method in list("drop_l_hand", "drop_r_hand", "drop_active_hand", "drop_inactive_hand", "drop_item"))
		U.hand = method == "drop_l_hand"
		var/obj/item/flax_bundle/B = new(site)
		if (method == "drop_inactive_hand")
			flax_entry_assert(U.put_in_inactive_hand(B), "production inactive-hand pickup")
		else
			flax_entry_held(U, B)
		flax_entry_assert(call(U, method)(W) && B.loc == W, "production wrapper forwards result and target: [method]")
		flax_entry_clean(U, B)
		qdel(B)
	var/obj/item/flax_bundle/default_target = new(site)
	flax_entry_held(U, default_target)
	flax_entry_assert(U.drop_from_inventory(default_target) && default_target.loc == site, "omitted target forwards to actor location")
	qdel(default_target)
	var/obj/item/organ/internal_item = new /obj/item/organ/flax_entry(U)
	U.internal_organs += internal_item
	flax_entry_assert(!U.drop_from_inventory(internal_item, W) && internal_item.loc == U, "production internal-organ guard refuses before removal")
	U.internal_organs -= internal_item
	qdel(internal_item)
	var/obj/item/organ/external/external_item = new /obj/item/organ/external/flax_entry(U)
	U.organs += external_item
	flax_entry_assert(!U.drop_from_inventory(external_item, W) && external_item.loc == U, "production external-organ guard refuses before removal")
	U.organs -= external_item
	qdel(external_item)

/proc/flax_entry_caller_regressions(mob/living/human/flax_entry_actor/U, turf/site)
	var/turf/table_site = locate(3,4,1)
	var/obj/structure/table/flax_entry/T = new(table_site)
	for (var/refused in list(FALSE, TRUE))
		var/obj/item/weapon/I = new(site)
		flax_entry_held(U, I)
		I.nodrop = refused
		T.MouseDrop_T(I, U)
		if (refused)
			flax_entry_assert(I.loc == U && U.get_active_hand() == I, "table caller retains refused held item")
			I.nodrop = FALSE
			U.drop_from_inventory(I)
		else
			flax_entry_assert(I.loc == table_site, "table caller steps successfully dropped weapon")
			flax_entry_clean(U, I)
		qdel(I)
	qdel(T)
	var/obj/item/weapon/defibrillator/D = new(site)
	var/obj/item/weapon/shockpaddles/linked/P = D.paddles
	flax_entry_assert(P && P.base_unit == D, "real defibrillator constructs linked paddles")
	flax_entry_held(U, P)
	D.reattach_paddles(U)
	flax_entry_assert(P.loc == D && P.base_unit == D, "production paddle caller returns actual paddles to base")
	flax_entry_clean(U, P)
	qdel(D)

/world/New()
	OpenPort("none")
	sleep(1)
	try
		flax_entry_assert(!world.port && !OpenPort(12345), "entry fixture refuses listening ports")
		text2file("closed", "port-closed.txt")
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		makeDatumRefLists()
		var/turf/site = locate(3,3,1)
		var/turf/floor/beach/water/W = new(locate(4,3,1))
		W.salty = FALSE
		W.radiation = 0
		var/mob/living/human/flax_entry_actor/U = new(site)
		flax_entry_assert(!U.client && !U.lying && !U.sleeping && U.stat == CONSCIOUS, "headless production inventory actor is awake and live")
		flax_entry_afterattack_regressions(U, site, W)
		U.forceMove(site)
		flax_entry_drop_contracts(U, site, W)
		flax_entry_caller_regressions(U, site)
		text2file(json_encode(list("commit" = world.params["tested_commit"], "byond_version" = world.byond_version, "byond_build" = world.byond_build, "dimensions" = "8x8x1", "client_screen_acceptance" = "not covered: no connected client", "paddle_notice_acceptance" = "not covered: no connected client")), "fixture.json")
		text2file("PASS: production human flax afterattack entry and caller contracts", "result.txt")
	catch (var/exception/E)
		world.log << "ENTRY exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
