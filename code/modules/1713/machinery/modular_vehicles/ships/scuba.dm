// Scuba diving (docs/river-flow.md, "Scuba"): the aqualung era.
//
// A dive mask and a scuba set (a steel cylinder with a regulator) on the back
// let a swimmer breathe under the water. They Dive from the open sea like a
// free diver (free_diving.dm), but breathe from the cylinder instead of
// holding their breath, and reach open water at any swimming skill; the deep
// still needs a hard suit. A calmer, better swimmer uses less air: about ten
// minutes from a full set at skill 100, fourteen at 200. Swim fins speed the
// swim and slow the walk.
//
// Breathing compressed air in open water loads the body with nitrogen. The
// shelf near the coast lets it go again, so a stop there on the way back is
// a safety stop. Surfacing straight from open water with a heavy load gives
// the bends: pain, failing strength, harm to the body and, at the worst, a
// collapse that can kill. Ascend Slowly makes the stop on the way up (20 to 60
// seconds by the load, shorter for a skilled swimmer) and always avoids it.
// Lying down helps the bends pass.

#define SCUBA_AIR_PER_SECOND 3 // a full set (1800 air seconds) lasts ten minutes at skill 100
#define SCUBA_NITROGEN_OPEN 1.5 // load a second breathing in open water
#define SCUBA_NITROGEN_SHELF_RELEASE 1 // load released a second on the shelf
#define SCUBA_NITROGEN_MAX 300
#define SCUBA_BENDS_SAFE 60 // load a diver can surface with unharmed
#define SCUBA_BENDS_DECAY 0.5 // severity gone a second
#define SCUBA_BENDS_REST_DECAY 1.5 // ...lying down
#define SCUBA_BENDS_COLLAPSE 60
#define SCUBA_SLOW_ASCENT_MIN 20
#define SCUBA_SLOW_ASCENT_MAX 60

/mob/living/human
	var/tmp/nitrogen_load = 0
	var/tmp/bends = 0 // severity of decompression sickness

/mob/living/human/persistence_runtime_var(key)
	return key == "nitrogen_load" || ..()

// ---- Gear ----

/obj/item/clothing/mask/dive_mask
	name = "dive mask"
	desc = "A glass faceplate in a rubber skirt. With a scuba set on your back it lets you breathe and see under the water."
	icon = 'icons/obj/clothing/diving.dmi'
	icon_state = "dive_mask"
	item_state = "dive_mask"
	icon_override = 'icons/mob/diving.dmi'
	body_parts_covered = FACE|EYES
	w_class = ITEM_SIZE_SMALL

/obj/item/clothing/shoes/swim_fins
	name = "swim fins"
	desc = "Long rubber blades for the feet. They make swimming much faster and walking on land clumsy."
	icon = 'icons/obj/clothing/diving.dmi'
	icon_state = "swim_fins"
	item_state = "swim_fins"
	icon_override = 'icons/mob/diving.dmi'
	wade_mult = 0.6
	land_slowdown = 1.5
	w_class = ITEM_SIZE_NORMAL

/obj/item/pressure_tank/scuba
	name = "scuba set"
	desc = "A steel air cylinder on a harness, with a regulator and mouthpiece. Wear it on your back with a dive mask to breathe under the water. Refill it at a submarine's ballast station, a habitat module's core or a landed lander."
	icon = 'icons/obj/clothing/diving.dmi'
	icon_state = "scuba_set"
	item_icons = list(slot_back_str = 'icons/mob/diving.dmi')

// TRUE while mask and set with air let this person breathe under the water.
/mob/living/human/proc/scuba_ready()
	if (pressure_suit_sealed())
		return FALSE
	var/obj/item/pressure_tank/scuba/A = back
	return istype(wear_mask, /obj/item/clothing/mask/dive_mask) && istype(A) && A.air_seconds > 0

// Air used a second: a better swimmer breathes calmer.
/mob/living/human/proc/scuba_air_rate()
	return SCUBA_AIR_PER_SECOND * sqrt(100 / swimming_skill())

// One breath from the set on the seabed at T, and the nitrogen it brings.
/mob/living/human/proc/scuba_breathe(turf/T)
	var/obj/item/pressure_tank/scuba/A = back
	if (!istype(A))
		return FALSE
	var/before = A.air_seconds
	A.air_seconds = max(0, A.air_seconds - scuba_air_rate())
	if (A.air_seconds <= 0)
		to_chat(src, SPAN_DANGER("The regulator wheezes dry: your set is empty! Hold your breath and get up!"))
	else if (pressure_crossed(before, A.air_seconds, 120))
		to_chat(src, SPAN_DANGER("Your set is almost empty. Head for the surface now."))
	else if (pressure_crossed(before, A.air_seconds, 450))
		to_chat(src, SPAN_WARNING("Your set is running low."))
	scuba_nitrogen_step(T)
	return TRUE

// Nitrogen builds in open water and leaves again on the shelf.
// Only breathing compressed air in open water adds nitrogen; a held breath
// adds none, while the shelf still releases the load.
/mob/living/human/proc/scuba_nitrogen_step(turf/T, breathing = TRUE)
	var/before = nitrogen_load
	if (sea_zone_of(T) >= SEA_ZONE_OPEN)
		if (!breathing)
			return
		nitrogen_load = min(SCUBA_NITROGEN_MAX, nitrogen_load + SCUBA_NITROGEN_OPEN)
		if (before < SCUBA_BENDS_SAFE && nitrogen_load >= SCUBA_BENDS_SAFE)
			to_chat(src, SPAN_WARNING("You have been down long enough to need a safety stop: come up slowly, or rest on the shelf first."))
	else if (nitrogen_load > 0)
		nitrogen_load = max(0, nitrogen_load - SCUBA_NITROGEN_SHELF_RELEASE)
		if (before >= SCUBA_BENDS_SAFE && nitrogen_load < SCUBA_BENDS_SAFE)
			to_chat(src, SPAN_NOTICE("You have waited out your safety stop on the shelf."))

// Breaking the surface with what is left of the nitrogen.
/mob/living/human/proc/scuba_surfaced()
	if (nitrogen_load > SCUBA_BENDS_SAFE)
		bends = min(SCUBA_NITROGEN_MAX, bends + nitrogen_load - SCUBA_BENDS_SAFE)
		to_chat(src, SPAN_DANGER("A deep ache spreads through your joints. You came up too fast: you have the bends!"))
	nitrogen_load = 0

// Ascend Slowly: a safety stop on the way up, then the surface.
/mob/living/human/proc/scuba_slow_ascent()
	if (!free_diving)
		to_chat(src, SPAN_WARNING("You are not diving."))
		return FALSE
	var/seconds = clamp(round(nitrogen_load / 5 * 100 / swimming_skill()), SCUBA_SLOW_ASCENT_MIN, SCUBA_SLOW_ASCENT_MAX)
	var/turf/T = get_turf(src)
	var/turf/up = locate(T.x, T.y, multiz_level_above(T.z))
	if (!sea_layer_open_surface(up) || up.iscovered())
		to_chat(src, SPAN_WARNING("Something floats on the water above you. Swim clear of it first."))
		return FALSE
	visible_message(SPAN_NOTICE("[src] starts a slow ascent, breathing steadily."))
	to_chat(src, SPAN_NOTICE("You rise slowly, stopping to let your body clear: about [seconds] seconds."))
	if (!do_after(src, seconds SECONDS, src))
		return FALSE
	if (!free_diving)
		return FALSE
	nitrogen_load = 0
	return free_dive_surface()

/mob/living/human/verb/ascend_slowly_verb()
	set name = "Ascend Slowly"
	set desc = "Swim up from the seabed with a safety stop, so you do not get the bends."
	set category = "IC"
	scuba_slow_ascent()

// ---- The bends ----

/mob/living/human/proc/bends_tick()
	if (bends <= 0 || stat == DEAD)
		bends = 0
		return
	var/resting = lying || istype(buckled, /obj/structure/bed)
	if (prob(8))
		to_chat(src, SPAN_WARNING(pick("Your joints ache deep inside.", "Your knees and elbows throb.", "Your skin itches and prickles.", "A wave of dizziness passes over you.")))
	if (islist(stats) && islist(stats["stamina"]))
		stats["stamina"][1] = max(0, stats["stamina"][1] - bends / 30)
	adjustBruteLoss(bends / 100)
	if (bends >= SCUBA_BENDS_COLLAPSE && !resting && prob(10))
		to_chat(src, SPAN_DANGER("Your legs give way!"))
		Weaken(3)
	bends = max(0, bends - (resting ? SCUBA_BENDS_REST_DECAY : SCUBA_BENDS_DECAY))
	if (!bends)
		to_chat(src, SPAN_NOTICE("The ache in your joints is gone."))

#undef SCUBA_AIR_PER_SECOND
#undef SCUBA_NITROGEN_OPEN
#undef SCUBA_NITROGEN_SHELF_RELEASE
#undef SCUBA_NITROGEN_MAX
#undef SCUBA_BENDS_SAFE
#undef SCUBA_BENDS_DECAY
#undef SCUBA_BENDS_REST_DECAY
#undef SCUBA_BENDS_COLLAPSE
#undef SCUBA_SLOW_ASCENT_MIN
#undef SCUBA_SLOW_ASCENT_MAX
