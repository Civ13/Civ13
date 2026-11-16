// Buried alive (docs/burial.md). Anyone still alive when a grave is filled
// over them is buried alive: they see only the grave and breathe what air they
// have. A closed coffin holds a few minutes of air, bare earth only a held
// breath. After that they suffocate every life tick until they die, someone
// digs the grave up, or they claw their way out with Resist. Clawing out of a
// coffin first means forcing its lid, which a nailed (locked or welded) coffin
// will not allow; a burial mound heaped on top doubles the earth to dig
// through. The state is ordinary saved mob vars, and every life tick re-checks
// it, so a buried mob restored from a save is still buried and sees the grave.

// Life ticks of air: a closed coffin, and a held breath in bare earth.
#define BURIAL_COFFIN_AIR 90
#define BURIAL_BARE_AIR 10
// Suffocation each life tick once the air is gone.
#define BURIAL_SUFFOCATION 5
// Resist presses to force a coffin lid, and to claw up through the earth.
#define BURIAL_LID_WORK 4
#define BURIAL_EARTH_WORK 15
// Air each Resist press costs: digging is hard breathing.
#define BURIAL_EFFORT_AIR 2

/mob/living/human/var/burial_air = -1
/mob/living/human/var/burial_work = 0
/mob/living/human/var/burial_lid_forced = FALSE

// The closed grave that holds H, directly or in a coffin, or null.
/proc/burial_grave(mob/living/human/H)
	if (!H)
		return null
	var/atom/A = H.loc
	if (istype(A, /obj/structure/closet/coffin))
		A = A.loc
	var/obj/structure/religious/grave/G = A
	if (istype(G) && !G.open)
		return G
	return null

/mob/living/human/proc/burial_coffin()
	var/obj/structure/closet/coffin/C = loc
	return istype(C) ? C : null

/mob/living/human/proc/burial_start(obj/structure/religious/grave/G)
	if (stat == DEAD)
		return
	buriedalive = TRUE
	burial_air = burial_coffin() ? BURIAL_COFFIN_AIR : BURIAL_BARE_AIR
	burial_work = 0
	burial_lid_forced = FALSE
	if (!burial_coffin())
		anchored = TRUE
	burial_view(G)
	to_chat(src, SPAN_DANGER("Earth thuds down over you. You are buried alive! Use Resist to claw your way out."))

/mob/living/human/proc/burial_view(obj/structure/religious/grave/G)
	if (client && G && client.eye != G)
		client.perspective = EYE_PERSPECTIVE
		client.eye = G

/mob/living/human/proc/burial_release()
	if (!buriedalive)
		return
	buriedalive = FALSE
	burial_air = -1
	burial_work = 0
	burial_lid_forced = FALSE
	anchored = FALSE
	if (client)
		client.eye = client.mob
		client.perspective = MOB_PERSPECTIVE

/mob/living/human/proc/burial_life_tick()
	var/obj/structure/religious/grave/G = burial_grave(src)
	if (!G)
		burial_release()
		return
	burial_view(G)
	if (stat == DEAD)
		return
	if (burial_air < 0)
		burial_air = burial_coffin() ? BURIAL_COFFIN_AIR : BURIAL_BARE_AIR
	if (burial_air > 0)
		burial_air--
		if (burial_air == round(BURIAL_COFFIN_AIR / 3) && burial_coffin())
			to_chat(src, SPAN_WARNING("The air in the coffin is growing thick and stale."))
		else if (burial_air == 0)
			to_chat(src, SPAN_DANGER("There is no air left!"))
		return
	adjustOxyLoss(BURIAL_SUFFOCATION)
	if (prob(50))
		to_chat(src, SPAN_DANGER("You can't breathe!"))

// Resist while buried: force the coffin lid, then claw up through the earth.
// Returns TRUE when it handled the press.
/mob/living/human/proc/burial_resist()
	var/obj/structure/religious/grave/G = burial_grave(src)
	if (!G)
		return FALSE
	if (stat || persistence_save_in_progress)
		return TRUE
	setClickCooldown(20)
	var/obj/structure/closet/coffin/C = burial_coffin()
	if (C && !burial_lid_forced)
		if (C.locked || C.welded)
			to_chat(src, SPAN_DANGER("You claw at the lid, but it is nailed shut."))
			return TRUE
		burial_air = max(0, burial_air - BURIAL_EFFORT_AIR)
		burial_work++
		if (burial_work < BURIAL_LID_WORK)
			to_chat(src, SPAN_WARNING("You push against the coffin lid. The earth on it shifts a little."))
			return TRUE
		burial_lid_forced = TRUE
		burial_work = 0
		to_chat(src, SPAN_WARNING("The lid cracks open and cold earth pours in. Keep digging up!"))
		return TRUE
	burial_air = max(0, burial_air - BURIAL_EFFORT_AIR)
	if (!prob(70 * getStatCoeff("strength")))
		to_chat(src, SPAN_WARNING("The loose earth caves back in around your hands."))
		return TRUE
	burial_work++
	var/needed = BURIAL_EARTH_WORK * (G.mound_raised ? 2 : 1)
	if (burial_work < needed)
		to_chat(src, SPAN_WARNING("You claw upward through the earth."))
		return TRUE
	to_chat(src, SPAN_NOTICE("Your hand breaks through into the open air!"))
	G.visible_message(SPAN_DANGER("A hand bursts out of \the [G]!"))
	log_game("[key_name(src)] clawed out of [G] at ([G.x],[G.y],[G.z]).")
	G.uncover_grave()
	if (C && !QDELETED(C))
		C.open()
	adaptStat("strength", 1)
	return TRUE

/mob/living/human/process_resist()
	if (buriedalive && burial_resist())
		return TRUE
	return ..()

#undef BURIAL_COFFIN_AIR
#undef BURIAL_BARE_AIR
#undef BURIAL_SUFFOCATION
#undef BURIAL_LID_WORK
#undef BURIAL_EARTH_WORK
#undef BURIAL_EFFORT_AIR
