// ============================================================
// Grapnels: grappling hooks thrown by hand (docs/ship-edges.md)
// ------------------------------------------------------------
// A grapnel is an iron hook on a line. Standing on her deck, click another
// ship's deck or rail within GRAPNEL_RANGE tiles with it in hand to throw it.
// It catches GRAPNEL_CATCH_CHANCE times in a hundred; a miss is hauled back.
// A hook that catches throws her lines as from the helm (craft_grapple.dm),
// without waiting for the helm's lines to be coiled, or adds to the lines
// already holding the two ships. Every hook on the lines makes them take
// longer to cut. The hooks come back to her deck when the lines part.
// ============================================================

#define GRAPNEL_RANGE 5
#define GRAPNEL_THROW_TIME 15
#define GRAPNEL_CATCH_CHANCE 60

/obj/item/weapon/grapnel
	name = "grapnel"
	desc = "A four-fluked iron hook on a stout line, thrown to catch another ship's rail and hold her alongside."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "grapplehook"
	w_class = ITEM_SIZE_NORMAL
	slot_flags = SLOT_SHOULDER
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	flags = CONDUCT
	flammable = FALSE
	attack_verb = list("bashed", "hooked")

// Why a grapnel cannot be thrown from turf from at turf at now, or null.
/proc/grapnel_refusal(turf/from, turf/at)
	var/datum/craft/mine = from ? craft_at(from) : null
	if (!mine)
		return "Throw it from a ship's deck."
	var/datum/craft/other = at ? craft_at(at) : null
	if (!other || other == mine)
		return "Throw it at another ship's deck or rail."
	if (at.z != from.z || get_dist(from, at) > GRAPNEL_RANGE)
		return "She lies too far off to reach with a grapnel."
	if (mine.grapple && mine.grapple.other(mine) != other)
		return "The [mine.name] is already grappled to another ship."
	if (other.grapple && other.grapple.other(other) != mine)
		return "Another ship already has lines on her."
	return null

// Grapnel hook has caught: it throws mine's lines on other, or holds on the
// lines already out between them. Null when it holds, otherwise why not.
/proc/grapnel_catch(obj/item/weapon/grapnel/hook, datum/craft/mine, datum/craft/other)
	var/datum/craft_grapple/G = mine.grapple
	if (!G)
		if (!mine.order_grapple(other, TRUE))
			return "The hook catches, but the lines do not hold: [mine.last_refusal]."
		G = mine.grapple
	else if (G.other(mine) != other)
		return "The [mine.name] is already grappled to another ship."
	if (ismob(hook.loc))
		var/mob/M = hook.loc
		M.drop_from_inventory(hook)
	hook.loc = null
	G.hooks += hook
	return null

/obj/item/weapon/grapnel/afterattack(atom/target, mob/user, proximity, params)
	if (!ishuman(user))
		return ..()
	var/turf/at = get_turf(target)
	var/turf/from = get_turf(user)
	var/datum/craft/other = at ? craft_at(at) : null
	if (!other || other == craft_at(from))
		if (proximity)
			return ..()
		to_chat(user, SPAN_WARNING("Throw it at another ship's deck or rail."))
		return
	var/why = grapnel_refusal(from, at)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return
	user.visible_message(SPAN_WARNING("[user] swings \a [src] to throw at the [other.name]!"), SPAN_NOTICE("You swing the grapnel..."))
	if (!do_after(user, GRAPNEL_THROW_TIME, src) || QDELETED(src) || loc != user)
		return
	from = get_turf(user)
	why = grapnel_refusal(from, at)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return
	if (!prob(GRAPNEL_CATCH_CHANCE))
		user.visible_message(SPAN_NOTICE("[user]'s grapnel falls short and splashes into the water."), SPAN_NOTICE("The grapnel falls short. You haul it back in."))
		return
	var/datum/craft/mine = craft_at(from)
	var/fresh = !mine.grapple
	why = grapnel_catch(src, mine, other)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return
	var/datum/craft_grapple/G = mine.grapple
	log_game("[key_name(user)] threw a grapnel from the [mine.name] onto the [other.name] ([G.hooks.len] hook\s on the lines).")
	user.visible_message(SPAN_WARNING("[user]'s grapnel bites into the [other.name]'s rail!"), SPAN_NOTICE("Your grapnel bites. [G.hooks.len] hook\s now hold the lines."))
	if (fresh)
		mine.crew_message(SPAN_NOTICE("[user]'s grapnel holds the [mine.name_of(other)] fast alongside. Neither ship sails until the lines are let go."))
		other.crew_message(SPAN_DANGER("<b>A grapnel from [other.knows(mine) ? "the [mine.name]" : "an unknown ship"] bites into the rail!</b> The [other.name] is held fast. Cut the lines at the helm or at the lines themselves."))

/obj/item/weapon/grapnel/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("Standing on a ship's deck, click another ship within [GRAPNEL_RANGE] tiles with it to throw it. More hooks on the lines make them slower to cut."))

/obj/covers/repairedfloor/rope/boarding/examine(mob/user)
	. = ..()
	if (grapple && grapple.hooks.len)
		to_chat(user, SPAN_NOTICE("[grapple.hooks.len] grapnel\s hold these lines: cutting them takes [round(grapple.cut_time() / 10)] seconds."))

#undef GRAPNEL_RANGE
#undef GRAPNEL_THROW_TIME
#undef GRAPNEL_CATCH_CHANCE
