// Full-source probe for bare-knuckle hand injuries: glove protection values,
// the injury chance by zone, force and armour, and what a hurt hand looks
// like. Real humans and gloves; the dice are replaced so the test decides.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/punch_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/punch_probe/New()
	map = src

/turf/floor/plating/punch_probe

/mob/living/human/punch_probe
var/punch_probe_checks = 0
var/list/punch_probe_rolls = list()

/mob/living/human/punch_probe/punch_injury_roll(chance)
	if (!punch_probe_rolls.len)
		return FALSE
	var/result = punch_probe_rolls[1]
	punch_probe_rolls.Cut(1, 2)
	return result

/obj/item/stack/material/hand_wrap_wait(mob/living/human/H)
	return TRUE

/proc/punch_probe_assert(ok, label)
	punch_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/punch_probe_wear(mob/living/human/H, path)
	if (H.gloves)
		var/obj/item/old = H.gloves
		H.drop_from_inventory(old)
		qdel(old)
	if (path)
		H.equip_to_slot_or_del(new path(H), slot_gloves)

/proc/punch_probe_chance(mob/living/human/H, path, zone = "chest", force = 5, armor = 0)
	punch_probe_wear(H, path)
	return H.punch_injury_chance(zone, force, armor)

/proc/punch_probe_run()
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
	map = new /obj/map_metadata/punch_probe
	map.ordinal_age = 0

	var/mob/living/human/punch_probe/H = new(locate(3, 3, 1))
	H.stat = CONSCIOUS
	var/mob/living/human/punch_probe/T = new(locate(4, 3, 1))
	T.stat = CONSCIOUS

	// --- protection values --------------------------------------------------
	var/bare = punch_probe_chance(H, null)
	punch_probe_assert(bare > 0 && H.punch_protection() == 0, "bare_hands_are_at_risk")
	punch_probe_assert(punch_probe_chance(H, /obj/item/clothing/gloves/watch/watch) == bare, "watch_protects_nothing")
	punch_probe_assert(punch_probe_chance(H, /obj/item/clothing/gloves/rings/silver) == bare, "ring_protects_nothing")
	var/latex = punch_probe_chance(H, /obj/item/clothing/gloves/sterile)
	var/cloth_gloves = punch_probe_chance(H, /obj/item/clothing/gloves/color/white)
	var/cloth_wraps = punch_probe_chance(H, /obj/item/clothing/gloves/hand_wraps)
	var/leather_gloves = punch_probe_chance(H, /obj/item/clothing/gloves/thick/leather)
	var/leather_wraps = punch_probe_chance(H, /obj/item/clothing/gloves/hand_wraps/leather)
	var/gauntlets = punch_probe_chance(H, /obj/item/clothing/gloves/gauntlets)
	var/boxing = punch_probe_chance(H, /obj/item/clothing/gloves/boxing)
	punch_probe_assert(bare > latex && latex > cloth_gloves && cloth_gloves > cloth_wraps, "thin_gloves_worse_than_wraps")
	punch_probe_assert(cloth_wraps == leather_gloves && leather_wraps < cloth_wraps, "leather_wraps_beat_cloth")
	punch_probe_assert(gauntlets < leather_wraps && gauntlets > 0, "gauntlets_best_short_of_boxing")
	punch_probe_assert(boxing == 0, "boxing_gloves_stop_it")
	punch_probe_assert(new /obj/item/clothing/gloves/gauntlets().get_punch_protection() == 77.5, "armour_derived_protection")

	// --- chance by target -------------------------------------------------
	punch_probe_wear(H, null)
	punch_probe_assert(H.punch_injury_chance("head", 5, 0) == bare * 2.5, "skull_is_harder")
	punch_probe_assert(H.punch_injury_chance("chest", 5, 60) > bare, "armour_is_harder")
	punch_probe_assert(H.punch_injury_chance("chest", 1, 0) < bare, "light_blow_risks_less")

	// --- the injury -------------------------------------------------------
	H.hand = 0
	var/obj/item/organ/external/R = H.organs_by_name["r_hand"]
	var/obj/item/organ/external/L = H.organs_by_name["l_hand"]
	punch_probe_rolls = list(FALSE)
	punch_probe_assert(!H.punch_hurts_hand(T, "chest", 5) && !R.brute_dam, "lucky_punch_is_harmless")
	punch_probe_rolls = list(TRUE, FALSE)
	punch_probe_assert(H.punch_hurts_hand(T, "chest", 5) && R.brute_dam >= 2 && !L.brute_dam && !(R.status & ORGAN_BROKEN), "bruised_punching_hand")
	H.hand = 1
	punch_probe_rolls = list(TRUE, TRUE)
	punch_probe_assert(H.punch_hurts_hand(T, "head", 5) && L.brute_dam >= 2 && (L.status & ORGAN_BROKEN), "broken_knuckles")

	// --- the punch path: a pulled punch never injures -----------------------
	var/datum/unarmed_attack/light_strike/LS = new
	punch_probe_assert(!istype(LS, /datum/unarmed_attack/punch) && LS.deal_halloss, "sparring_strike_is_not_a_punch")

	// --- wrapping: grab intent on your own hand -----------------------------
	punch_probe_wear(H, null)
	H.hand = 0
	var/obj/item/stack/material/cloth/C = new(H.loc, 3)
	H.put_in_active_hand(C)
	H.a_intent = I_GRAB
	punch_probe_assert(!C.attack(H, H, "chest") && !H.gloves, "wrap_needs_hand_target")
	H.a_intent = I_HELP
	C.attack(H, H, "r_hand")
	punch_probe_assert(!H.gloves && C.amount == 3, "wrap_needs_grab_intent")
	H.a_intent = I_GRAB
	punch_probe_assert(C.attack(H, H, "r_hand") && istype(H.gloves, /obj/item/clothing/gloves/hand_wraps) && C.amount == 2, "cloth_wraps_hands")
	var/obj/item/clothing/gloves/hand_wraps/W = H.gloves
	punch_probe_assert(W.name == "cloth hand wraps" && W.unwraps_to == /obj/item/stack/material/cloth && H.punch_protection() == 60, "cloth_wrap_identity")
	punch_probe_assert(!W.settle_wrap() && H.gloves == W, "worn_wrap_stays")
	punch_probe_assert(C.attack(H, H, "l_hand") && H.gloves == W && C.amount == 2, "one_wrap_at_a_time")
	// Dropped on the floor: the same cloth again.
	H.drop_from_inventory(C)
	qdel(C)
	H.drop_from_inventory(W)
	var/obj/item/stack/material/cloth/back = W.settle_wrap()
	punch_probe_assert(istype(back) && back.amount == 1 && back.loc == H.loc && QDELETED(W), "dropped_wrap_is_cloth")
	qdel(back)
	// Leather, taken off into the hand: leather in that hand.
	var/obj/item/stack/material/leather/LE = new(H.loc, 1)
	H.put_in_active_hand(LE)
	punch_probe_assert(LE.attack(H, H, "l_hand") && istype(H.gloves, /obj/item/clothing/gloves/hand_wraps/leather) && QDELETED(LE), "last_leather_wraps_hands")
	W = H.gloves
	punch_probe_assert(W.name == "leather hand wraps" && H.punch_protection() == 75, "leather_wrap_identity")
	H.drop_from_inventory(W)
	H.put_in_active_hand(W)
	var/obj/item/stack/material/leather/LB = W.settle_wrap()
	punch_probe_assert(istype(LB) && LB.amount == 1 && H.get_active_hand() == LB && QDELETED(W), "taken_off_wrap_is_leather_in_hand")
	H.a_intent = I_HELP

	// --- art stand-ins exist -------------------------------------------------
	for (var/state in list("ncr_handwraps", "legion_handwraps"))
		punch_probe_assert((state in icon_states('icons/obj/clothing/gloves.dmi')) && (state in icon_states('icons/mob/hands.dmi')), "icon_state_[state]")

/world/New()
	OpenPort("none")
	var/error = null
	try
		punch_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = punch_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
