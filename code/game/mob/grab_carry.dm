// Fireman carry: sling a downed person over your shoulder.
// The idea comes from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0, GRAB_CARRY in
// code/_onclick/human.dm); this is a fresh implementation for Civ13's grabs.
//
// How it works: hold an aggressive grab on a downed (lying, unconscious or
// dead) human and click yourself with the grab. After a short wait you carry
// them on your own tile, like a neck grab, and walk much faster than when
// dragging. Click yourself with the grab again to put them down. The carry
// ends on its own if they stand up or you fall.

#define FIREMAN_CARRY_TIME 30
#define FIREMAN_CARRY_GRAB_DELAY 0.25
#define FIREMAN_CARRY_RUN_STAMINA 1
#define DEFAULT_GRAB_MOVE_DELAY 1.0

/obj/item/weapon/grab
	var/carrying = FALSE

/obj/item/weapon/grab/proc/carry_target_downed()
	if (!ishuman(affecting))
		return FALSE
	return affecting.lying || affecting.stat != CONSCIOUS

// Returns TRUE when the click was handled as a carry action.
/obj/item/weapon/grab/proc/fireman_carry_click()
	if (carrying)
		stop_fireman_carry(TRUE)
		return TRUE
	if (state != GRAB_AGGRESSIVE || !carry_target_downed())
		return FALSE
	if (affecting.buckled)
		to_chat(assailant, SPAN_WARNING("[affecting] is buckled to something."))
		return TRUE
	if (assailant.lying || !assailant.canmove)
		return TRUE
	assailant.visible_message(SPAN_NOTICE("[assailant] starts lifting [affecting] onto \his shoulders..."), SPAN_NOTICE("You start lifting [affecting] onto your shoulders..."))
	if (!do_mob(assailant, affecting, FIREMAN_CARRY_TIME))
		return TRUE
	if (gcDestroyed || !affecting || !assailant || state != GRAB_AGGRESSIVE || carrying || !carry_target_downed() || affecting.buckled)
		return TRUE
	if (!isturf(assailant.loc) || !affecting.persistence_set_loc(assailant.loc))
		return TRUE
	carrying = TRUE
	force_down = FALSE
	assailant.stop_pulling()
	assailant.visible_message(SPAN_NOTICE("[assailant] slings [affecting] over \his shoulders."), SPAN_NOTICE("You sling [affecting] over your shoulders. Click yourself with the grab to put them down."))
	adjust_position()
	return TRUE

/obj/item/weapon/grab/proc/stop_fireman_carry(announce = FALSE)
	if (!carrying)
		return
	carrying = FALSE
	if (affecting)
		affecting.layer = 4
		animate(affecting, pixel_x = FALSE, pixel_y = FALSE, 3, TRUE, LINEAR_EASING)
		if (announce && assailant)
			assailant.visible_message(SPAN_NOTICE("[assailant] puts [affecting] down."), SPAN_NOTICE("You put [affecting] down."))

// Called from process(): a carry needs a downed passenger and a carrier on their feet.
/obj/item/weapon/grab/proc/check_fireman_carry()
	if (!carrying)
		return
	if (!affecting || !assailant)
		return
	if (!carry_target_downed() || affecting.buckled || assailant.lying || assailant.stat != CONSCIOUS)
		stop_fireman_carry(TRUE)

// Keeps the passenger on the carrier's tile, drawn over the shoulders.
/obj/item/weapon/grab/proc/fireman_carry_position()
	if (!assailant || !isturf(assailant.loc))
		return FALSE
	if (affecting.loc != assailant.loc && !affecting.persistence_set_loc(assailant.loc))
		stop_fireman_carry()
		return FALSE
	affecting.set_dir(assailant.dir)
	affecting.layer = 4.1
	animate(affecting, pixel_x = FALSE, pixel_y = 14, 3, TRUE, LINEAR_EASING)
	return TRUE

// Extra step delay while holding grabs; carrying is cheaper than dragging.
/mob/proc/grab_move_delay()
	for (var/obj/item/weapon/grab/G in grab_list)
		if (G.carrying)
			if (m_intent == "run" && ishuman(src))
				var/mob/living/human/H = src
				if (H.stats["stamina"][1] > 0)
					H.stats["stamina"][1] -= FIREMAN_CARRY_RUN_STAMINA
			return FIREMAN_CARRY_GRAB_DELAY
	return DEFAULT_GRAB_MOVE_DELAY

#undef FIREMAN_CARRY_TIME
#undef FIREMAN_CARRY_GRAB_DELAY
#undef FIREMAN_CARRY_RUN_STAMINA
#undef DEFAULT_GRAB_MOVE_DELAY
