// Objects say how to use them (chat feedback, 2026-11-17): examining a
// tree, a palm, a dug hole or a ladder adds one line with its basic actions,
// the questions new players kept asking in chat. Only ordinary, public
// actions are named.

// The line shown under this thing's description, or null.
/atom/proc/use_hint(mob/user)
	return null

/obj/structure/wild/use_hint(mob/user)
	var/list/parts = list()
	if (max_branches > 0)
		parts += branches >= 1 ? "Click it with an empty hand on Harm intent to break off a branch ([branches] left; they grow back)." : "Its branches have all been taken; they grow back in time."
	if (density && holds_climber)
		parts += "Click it with an empty hand on Grab intent to climb it."
	return parts.len ? jointext(parts, " ") : null

/obj/structure/wild/tree/use_hint(mob/user)
	. = ..()
	return "[. ? "[.] " : ""]An axe or hatchet chops it down for wood."

/obj/structure/wild/palm/use_hint(mob/user)
	. = ..()
	return "[. ? "[.] " : ""]An axe or hatchet chops it down for wood and palm leaves. A knife, with a clay pot in your other hand, taps its sap."

/obj/structure/multiz/ladder/use_hint(mob/user)
	return "Click it with an empty hand to climb [istop ? "down" : "up"]. Keep a hand free."

/obj/structure/multiz/ladder/ww2/tunneltop/pit/use_hint(mob/user)
	if (leaf_covered)
		return null
	return "From the bottom, face one of its walls and use Climb Up in the IC tab, or click the wall with an empty hand on Grab intent."

/obj/structure/wild/examine(mob/user, distance = -1)
	. = ..()
	show_use_hint(user)

/obj/structure/multiz/ladder/examine(mob/user, distance = -1)
	. = ..()
	show_use_hint(user)

/atom/proc/show_use_hint(mob/user)
	var/hint = use_hint(user)
	if (hint && user)
		to_chat(user, SPAN_NOTICE(hint))
