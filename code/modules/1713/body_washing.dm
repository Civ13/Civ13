// Washing one part of the body (docs/hygiene.md).
//
// The targeted body part says what you mean. Drinking from a container, or
// feeding someone, needs the mouth targeted (standard_feed_mob). On help
// intent, any other part washes:
// - Click yourself or someone beside you with an open container holding clean
//   water (a bucket, pot, mug, cup or glass): it uses 5 units.
// - Click a sink, tap or fountain, or fresh water, to wash that part of
//   yourself. Targeting a hand there gives the usual hand wash.
// Washing a hand clears dirty hands and the blood on it (or on the glove).
// Washing any other part cleans the blood off what is worn over it, or, on
// bare skin, raises cleanliness a little (10 a wash, up to a sponge bath's
// 175; 20 up to 250 with soap).
// After each part, washing moves on by itself to the next bare part that
// still needs washing (head down to feet), until none is left, the water runs
// out, or the washer moves.
// Self-examine marks each part that needs washing: hands with work dirt or
// blood, and, while cleanliness is below clean, the skin of every part not
// washed since. A part washed stays marked clean until cleanliness falls 25
// below what it was after that wash. Skin under clothes shows as covered,
// since washing there cleans the clothes; undress to wash it.
// Once no part is left needing a wash, the whole body counts as washed: plain
// water lifts cleanliness to a sponge bath's 175 at least, so a full wash is
// never still filthy (too filthy to sleep, or the filthy mood).
// Wounds: water halves the germs in the part's open wounds and in the part
// itself while it is not yet infected. Soap in the washer's other hand
// disinfects the wounds and clears those germs. An infection already set in
// still needs medicine.

#define WASH_PART_WATER 5
#define WASH_PART_HYGIENE 10
#define WASH_PART_TIME 20
#define WASH_PART_SOAP_HYGIENE 20
#define WASHED_PART_MARGIN 25

// limb_name -> cleanliness right after that part was last washed bare.
/mob/living/human/var/tmp/list/washed_parts

// Zones a container washes on help intent: all but the mouth.
/proc/container_washes_zone(zone)
	return zone && zone != "mouth" && zone != "random"

// Zones a water source washes as one part rather than as a hand wash.
/proc/source_washes_zone(zone)
	return zone && zone != "random" && zone != "l_hand" && zone != "r_hand"

/proc/wash_zone_name(zone)
	switch (zone)
		if ("eyes", "mouth")
			return "face"
		if ("l_arm")
			return "left arm"
		if ("r_arm")
			return "right arm"
		if ("l_hand")
			return "left hand"
		if ("r_hand")
			return "right hand"
		if ("l_leg")
			return "left leg"
		if ("r_leg")
			return "right leg"
		if ("l_foot")
			return "left foot"
		if ("r_foot")
			return "right foot"
	return zone

// Washes one part, with soap if `soap` is set. Returns FALSE when that part
// is missing.
/mob/living/human/proc/wash_body_part(zone, soap = FALSE)
	var/obj/item/organ/external/E = get_organ(zone)
	if (!E || E.is_stump())
		return FALSE
	rinse_wounds(E, soap)
	if (zone == "l_hand" || zone == "r_hand")
		if (gloves)
			gloves.clean_blood()
			gloves.germ_level = 0
		else
			bloody_hands = 0
			germ_level = 0
			wash_hands()
		update_inv_gloves()
		return TRUE
	var/covered = FALSE
	for (var/obj/item/clothing/C in get_equipped_items())
		if (C.body_parts_covered & E.body_part)
			covered = TRUE
			C.clean_blood()
	if ((zone == "l_foot" || zone == "r_foot") && !shoes)
		feet_blood_color = null
		feet_blood_DNA = null
		update_inv_shoes(1)
	if (!covered)
		if (istype(blood_DNA, /list))
			blood_DNA = null
		if (soap)
			raise_hygiene(min(hygiene + WASH_PART_SOAP_HYGIENE, HYGIENE_LEVEL_CLEAN))
		else if (hygiene < SPONGE_BATH_MAX)
			raise_hygiene(min(hygiene + WASH_PART_HYGIENE, SPONGE_BATH_MAX))
		LAZYSET(washed_parts, E.limb_name, hygiene)
		check_whole_body_washed()
	update_icons()
	return TRUE

// Marks one bare part washed at the current cleanliness. Every hand wash
// (sinks, taps, open water, baths) does this through wash_hands().
/mob/living/human/proc/mark_part_washed(zone)
	var/obj/item/organ/external/E = get_organ(zone)
	if (E && !E.is_stump())
		LAZYSET(washed_parts, E.limb_name, hygiene)
		check_whole_body_washed()

// With every part washed, cleanliness reaches a sponge bath's level at least,
// and every part is marked washed at that level.
/mob/living/human/proc/check_whole_body_washed()
	if (hygiene >= SPONGE_BATH_MAX || !length(organs))
		return
	for (var/obj/item/organ/external/E in organs)
		if (part_dirt_status(E) != "")
			return
	raise_hygiene(SPONGE_BATH_MAX)
	for (var/obj/item/organ/external/E in organs)
		if (!E.is_stump())
			LAZYSET(washed_parts, E.limb_name, hygiene)

// A whole-body wash (Bathe, a sponge bath) cleans every bare part, even when
// it leaves cleanliness short of clean.
/mob/living/human/proc/mark_bare_parts_washed()
	for (var/obj/item/organ/external/E in organs)
		if (!E.is_stump() && !part_is_covered(E))
			LAZYSET(washed_parts, E.limb_name, hygiene)

// Is this part's clothing covering it?
/mob/living/human/proc/part_is_covered(obj/item/organ/external/E)
	for (var/obj/item/clothing/C in get_equipped_items())
		if (C.body_parts_covered & E.body_part)
			return TRUE
	return FALSE

// What self-examine says about a part's dirt: "" when it needs no washing.
/mob/living/human/proc/part_dirt_status(obj/item/organ/external/E)
	if (!E || E.is_stump())
		return ""
	if (E.limb_name == "l_hand" || E.limb_name == "r_hand")
		if (gloves)
			return gloves.blood_DNA ? "bloody gloves" : ""
		if (bloody_hands)
			return "bloody"
		if (dirty_hands)
			return "dirty"
	if (hygiene >= HYGIENE_LEVEL_NORMAL)
		return ""
	var/washed_at = LAZYACCESS(washed_parts, E.limb_name)
	if (!isnull(washed_at) && hygiene >= washed_at - WASHED_PART_MARGIN)
		return ""
	var/dirt = hygiene < HYGIENE_LEVEL_DIRTY ? "filthy" : "dirty"
	return part_is_covered(E) ? "[dirt] (covered)" : dirt

// Water halves the germs in a part's open wounds; soap disinfects them.
/mob/living/human/proc/rinse_wounds(obj/item/organ/external/E, soap = FALSE)
	if (soap)
		E.disinfect()
	else
		for (var/datum/wound/W in E.wounds)
			if (!W.internal)
				W.germ_level *= 0.5
	if (E.germ_level < INFECTION_LEVEL_ONE)
		E.germ_level = soap ? 0 : E.germ_level * 0.5

// The soap held in the washer's hands, if any.
/mob/living/human/proc/held_soap()
	if (istype(l_hand, /obj/item/weapon/soap))
		return l_hand
	if (istype(r_hand, /obj/item/weapon/soap))
		return r_hand
	return null

// The order washing moves through the body.
var/global/list/wash_zone_order = list("head", "chest", "groin", "l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg", "l_foot", "r_foot")

// The next bare part that still needs washing, skipping the zones in `done`.
/mob/living/human/proc/next_dirty_zone(list/done)
	for (var/zone in wash_zone_order)
		if (done && (zone in done))
			continue
		var/obj/item/organ/external/E = get_organ(zone)
		if (!E || E.is_stump() || part_is_covered(E))
			continue
		if (part_dirt_status(E) != "")
			return zone
	return null

// Pays for one part's wash from `source`. TRUE if this part was paid for.
// Open water never runs out.
/atom/proc/wash_spend(mob/living/human/user)
	return TRUE

// TRUE while `source` has water for another part's wash.
/atom/proc/wash_ready()
	return TRUE

// After a plain hand wash, carries on with the next bare part that still
// needs washing.
/mob/living/human/proc/wash_on_after_hands(atom/source)
	if (!source || !source.wash_ready() || !Adjacent(source))
		return
	wash_part_of(src, next_dirty_zone(list("l_hand", "r_hand")), "\the [source]", source)

// Who washes whom, after the wait. Returns TRUE when at least one part was
// washed. After each part it moves on by itself to the next bare part that
// still needs washing, until none is left, the water runs out, or the washer
// moves or does something else.
/mob/living/human/proc/wash_part_of(mob/living/human/target, zone, source_name, atom/source)
	. = FALSE
	var/list/done = list()
	var/uses_source = !!source
	while (zone)
		if (uses_source && (QDELETED(source) || !source.wash_ready()))
			return
		if (!wash_one_part_of(target, zone, source_name, source))
			return
		. = TRUE
		done += zone
		zone = target.next_dirty_zone(done)

/mob/living/human/proc/wash_one_part_of(mob/living/human/target, zone, source_name, atom/source)
	var/uses_source = !!source
	var/part = wash_zone_name(zone)
	var/obj/item/organ/external/E = target.get_organ(zone)
	if (!E || E.is_stump())
		to_chat(src, SPAN_WARNING("[target == src ? "You have" : "[target] has"] no [part] to wash."))
		return FALSE
	if (target == src)
		visible_message(SPAN_NOTICE("[src] starts washing their [part] with [source_name]."), SPAN_NOTICE("You start washing your [part] with [source_name]."))
	else
		visible_message(SPAN_NOTICE("[src] starts washing [target]'s [part] with [source_name]."), SPAN_NOTICE("You start washing [target]'s [part] with [source_name]."))
	if (!do_after(src, WASH_PART_TIME, target, check_for_repeats = FALSE))
		return FALSE
	if (target != src && !Adjacent(target))
		return FALSE
	// The wash wait does not reserve water; pay before hygiene or soap changes.
	if (uses_source && (QDELETED(source) || !source.wash_spend(src)))
		return FALSE
	var/obj/item/weapon/soap/S = held_soap()
	target.wash_body_part(zone, !!S)
	if (S)
		S.used++
		if (S.used >= 30)
			qdel(S)
		else
			S.update_icon()
	playsound(target.loc, 'sound/effects/slosh.ogg', 25, TRUE)
	if (target == src)
		to_chat(src, SPAN_NOTICE("You wash your [part]. [hygiene_feeling()]"))
	else
		to_chat(src, SPAN_NOTICE("You wash [target]'s [part]."))
		to_chat(target, SPAN_NOTICE("[src] washes your [part]."))
	return TRUE

// ---- with a container -------------------------------------------------------
// Buckets, pots and other glass containers, and drinks (mugs, cups, glasses).

// TRUE when this click should wash rather than drink: help intent, a part
// other than the mouth, and an open container with water in it.
/obj/item/weapon/reagent_containers/proc/washes_on_click(mob/living/M, mob/living/user)
	if (!ishuman(user) || !ishuman(M) || user.a_intent != I_HELP || !is_open_container() || !reagents)
		return FALSE
	if (!container_washes_zone(user.targeted_organ))
		return FALSE
	return reagents.get_reagent_amount("water") > 0

// Washes the targeted part of M with this container's water.
/obj/item/weapon/reagent_containers/proc/wash_with(mob/living/human/M, mob/living/human/user)
	if (reagents.get_reagent_amount("water") < WASH_PART_WATER)
		to_chat(user, SPAN_WARNING("There is not enough water in \the [src] to wash with."))
		return TRUE
	if (reagents.has_reagent("food_poisoning"))
		to_chat(user, SPAN_WARNING("The water in \the [src] smells foul. It would only make you dirtier."))
		return TRUE
	user.wash_part_of(M, user.targeted_organ, "\the [src]", src)
	return TRUE

/obj/item/weapon/reagent_containers/wash_ready()
	return is_open_container() && reagents && reagents.get_reagent_amount("water") >= WASH_PART_WATER && !reagents.has_reagent("food_poisoning")

/obj/item/weapon/reagent_containers/wash_spend(mob/living/human/user)
	if (!wash_ready() || !reagents.remove_reagent("water", WASH_PART_WATER))
		return FALSE
	update_icon()
	return TRUE

/obj/item/weapon/reagent_containers/glass/attack(mob/living/M, mob/living/user, target_zone)
	if (!washes_on_click(M, user))
		return ..()
	return wash_with(M, user)

// ---- at a water source ------------------------------------------------------

/obj/structure/sink/attack_hand(mob/user)
	var/mob/living/human/H = user
	if (!ishuman(H) || H.a_intent != I_HELP || !source_washes_zone(H.targeted_organ) || !Adjacent(H))
		return ..()
	if (heat_dried() || volume <= 0)
		to_chat(H, SPAN_WARNING("\The [src] is dry!"))
		return
	if (busy && busy != H)
		to_chat(H, SPAN_WARNING("Someone's already washing here."))
		return
	busy = H
	H.wash_part_of(H, H.targeted_organ, "\the [src]", src)
	busy = FALSE

/obj/structure/sink/wash_spend(mob/living/human/user)
	return volume > 0 && !heat_dried()

/obj/structure/sink/wash_ready()
	return volume > 0 && !heat_dried()

/obj/structure/water_tap/attack_hand(mob/living/user)
	var/mob/living/human/H = user
	if (!ishuman(H) || H.a_intent != I_HELP || !source_washes_zone(H.targeted_organ) || !Adjacent(H) || busy)
		return ..()
	if (!wash_ready())
		to_chat(H, SPAN_WARNING("\The [src] has no clean water to wash with."))
		return
	busy = TRUE
	H.wash_part_of(H, H.targeted_organ, "\the [src]", src)
	busy = FALSE

/obj/structure/water_tap/wash_ready()
	return reagents && reagents.get_reagent_amount("water") >= WASH_PART_WATER

/obj/structure/water_tap/wash_spend(mob/living/human/user)
	return wash_ready() && reagents.remove_reagent("water", WASH_PART_WATER)

/turf/floor/beach/water/attack_hand(mob/living/human/H)
	if (!ishuman(H) || H.a_intent != I_HELP || salty || !Adjacent(H) || istype(src, /turf/floor/beach/water/ice) || !source_washes_zone(H.targeted_organ))
		return ..()
	H.wash_part_of(H, H.targeted_organ, "\the [src]")

#undef WASH_PART_WATER
#undef WASH_PART_HYGIENE
#undef WASH_PART_TIME
#undef WASH_PART_SOAP_HYGIENE
#undef WASHED_PART_MARGIN
