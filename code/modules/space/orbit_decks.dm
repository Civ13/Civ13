// ============================================================
// Station decks (orbital stations, stage C)
// ------------------------------------------------------------
// A station grows up and down through node modules. A node is a habitat
// module with a deck hatch on the floor tile south-east of its core. Two
// nodes at the same x and y on decks linked in the plane registry (up and
// down, orbit_world.dm) form a shaft: people climb through it, and while
// both deck hatches are open the two modules share their air like modules
// behind an open side hatch. An open deck hatch with no node beyond it is a
// breach.
//
// A new deck: use a node module kit on an open deck hatch. That claims a
// free plane for the station's party (the station quota of 6 planes holds),
// links it above or below and unfolds a node on it at the same spot. Power
// crosses decks with cable risers (cable_risers.dm), which follow the same
// links.
//
// Nothing here stores world.time or a cross-level reference: partners are
// found from positions and the registry each time.
// ============================================================

#define ORBIT_DECK_CLIMB_DELAY 10

/obj/item/habitat_kit/node
	name = "node module kit"
	desc = "A folded node module with a deck hatch in its floor. In orbit, use it on a node's open deck hatch to build a new deck above or below the station."
	kind = "node"
	core_type = /obj/structure/habitat_core/node

/obj/structure/habitat_core/node
	name = "node core"
	desc = "The air hub of a node module, with a deck hatch in the floor beside it."
	kind = "node"

// ---------------------------------------------------------------- hatch

/obj/structure/deck_hatch
	name = "deck hatch"
	desc = "A round pressure hatch in the floor and ceiling of a node module, with rungs through it to the next deck."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "ladderdown"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	layer = 2.4
	var/open = FALSE

/obj/structure/deck_hatch/ex_act(severity)
	return

/obj/structure/deck_hatch/proc/core()
	var/turf/T = locate(x - 1, y + 1, z)
	var/obj/structure/habitat_core/node/N = T ? locate() in T : null
	return (N && !QDELETED(N)) ? N : null

// The deck hatch of the node at the same spot on the deck in direction
// ("up" or "down"), or null.
/obj/structure/deck_hatch/proc/partner(direction)
	var/level = orbit_plane_link(z, direction)
	var/turf/T = level ? locate(x, y, level) : null
	var/obj/structure/deck_hatch/H = T ? locate() in T : null
	return (H && !QDELETED(H) && H.core()) ? H : null

/obj/structure/deck_hatch/proc/partners()
	var/list/found = list()
	for (var/direction in list("up", "down"))
		var/obj/structure/deck_hatch/H = partner(direction)
		if (H)
			found[direction] = H
	return found

/obj/structure/deck_hatch/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("It is [open ? "open" : "shut"]."))
	var/list/found = partners()
	if (!found.len)
		to_chat(user, SPAN_WARNING("No deck lies beyond it. Use a node module kit on it, open, to build one."))
	else
		to_chat(user, SPAN_NOTICE("It leads [jointext(found, " and ")]."))

/obj/structure/deck_hatch/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client || user.restrained())
		return
	var/list/options = list(open ? "Shut" : "Open")
	var/list/found = partners()
	if (open)
		for (var/direction in found)
			var/obj/structure/deck_hatch/H = found[direction]
			if (H.open)
				options += "Climb [direction]"
	options += "Cancel"
	var/choice = WWinput(user, "The deck hatch is [open ? "open" : "shut"].", "Deck hatch", "Cancel", options)
	if (!choice || choice == "Cancel" || !in_range(src, user))
		return
	if (choice == "Open" || choice == "Shut")
		open = (choice == "Open")
		icon_state = open ? "ladderup" : "ladderdown"
		user.visible_message(SPAN_NOTICE("[user] [open ? "opens" : "shuts"] \the [src]."))
		return
	climb(user, choice == "Climb up" ? "up" : "down")

// Moves user through the shaft. Returns null or a reason.
/obj/structure/deck_hatch/proc/climb(mob/living/human/user, direction)
	var/obj/structure/deck_hatch/H = partner(direction)
	if (!open || !H || !H.open)
		return "The hatches must be open on both decks."
	user.visible_message(SPAN_NOTICE("[user] starts to climb [direction] through \the [src]."))
	if (!do_after(user, ORBIT_DECK_CLIMB_DELAY, src))
		return null
	H = partner(direction)
	if (!open || !H || !H.open)
		return "The hatches must be open on both decks."
	var/turf/T = get_turf(H)
	if (!persistence_movement_allowed(user, T) || (user.pulling && !persistence_movement_allowed(user.pulling, T)))
		return "You cannot get through."
	var/atom/movable/pulled = user.pulling
	user.forceMove(T)
	if (pulled)
		pulled.forceMove(T)
	playsound(T, 'sound/effects/ladder.ogg', 50, TRUE, -1)
	return null

/obj/structure/deck_hatch/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/habitat_kit/node))
		orbit_build_deck(src, W, user)
		return
	return ..()

// ---------------------------------------------------------------- node air

/obj/structure/habitat_core/node/proc/deck_hatch()
	var/turf/T = locate(x + 1, y - 1, z)
	var/obj/structure/deck_hatch/H = T ? locate() in T : null
	return (H && !QDELETED(H)) ? H : null

// Nodes on other decks behind open deck hatches on both sides.
/obj/structure/habitat_core/node/proc/deck_neighbours()
	var/list/found = list()
	var/obj/structure/deck_hatch/H = deck_hatch()
	if (!H || !H.open)
		return found
	for (var/direction in list("up", "down"))
		var/obj/structure/deck_hatch/P = H.partner(direction)
		if (P && P.open)
			found += P.core()
	return found

/obj/structure/habitat_core/node/open_neighbours()
	return ..() + deck_neighbours()

// An open deck hatch with no node beyond it opens the module to space.
/obj/structure/habitat_core/node/breaches()
	. = ..()
	var/obj/structure/deck_hatch/H = deck_hatch()
	if (H && H.open && !length(H.partners()))
		.++

/obj/structure/habitat_core/node/fold_refusal(mob/user)
	. = ..()
	if (.)
		return
	var/obj/structure/deck_hatch/H = deck_hatch()
	if (H && H.open)
		return "Shut the deck hatch first."
	if (H && length(H.partners()))
		return "A deck is joined through this node. Fold the node on that deck first."

/obj/structure/habitat_core/node/fold(mob/user)
	var/obj/structure/deck_hatch/H = deck_hatch()
	if (H)
		qdel(H)
	return ..()

/proc/orbit_place_deck_hatch(obj/structure/habitat_core/node/N)
	var/turf/T = locate(N.x + 1, N.y - 1, N.z)
	if (T && !(locate(/obj/structure/deck_hatch) in T))
		new /obj/structure/deck_hatch(T)

// ---------------------------------------------------------------- new decks

// Null when a deck may be built from hatch H in direction, otherwise why not.
/proc/orbit_deck_refusal(obj/structure/deck_hatch/H, direction, mob/user)
	if (!orbit_world())
		return "Decks are only built in orbit."
	var/party = orbit_station_party(H.z)
	if (!party)
		return "Only a station's plane can grow new decks."
	if (user && !party_train_may_board(user, party))
		return "This station belongs to [party_train_party_name(party)]."
	if (!H.open)
		return "Open the deck hatch first."
	if (orbit_plane_link(H.z, direction))
		return "A deck already lies [direction] from here."
	if (length(orbit_station_planes(party)) >= ORBIT_STATION_PLANE_QUOTA)
		return "The station already has [ORBIT_STATION_PLANE_QUOTA] decks and sectors, the most one party may hold."
	if (!length(orbit_free_planes()))
		return "Every plane in orbit is taken."
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	return null

// Claims a plane for the station, links it in direction and unfolds a node
// on it at the same spot. Returns the new node, or null.
/proc/orbit_add_deck(obj/structure/deck_hatch/H, direction)
	var/party = orbit_station_party(H.z)
	var/obj/structure/habitat_core/node/N = H.core()
	if (!party || !N)
		return null
	var/level = orbit_claim_plane(orbit_station_owner(party))
	if (!level)
		return null
	if (!orbit_link_planes(H.z, direction, level))
		orbit_release_plane(level)
		return null
	var/turf/centre = locate(N.x, N.y, level)
	if (habitat_module_refusal(centre, null))
		orbit_unlink_plane(H.z, direction)
		orbit_release_plane(level)
		return null
	var/obj/structure/habitat_core/node/made = habitat_unfold(centre, "node", /obj/structure/habitat_core/node)
	log_game("Orbit station: [party] added a deck [direction] (plane [level]) from plane [H.z].")
	return made

/proc/orbit_build_deck(obj/structure/deck_hatch/H, obj/item/habitat_kit/node/K, mob/user)
	var/list/choices = list()
	for (var/direction in list("up", "down"))
		if (!orbit_plane_link(H.z, direction))
			choices += "Build a deck [direction]"
	if (!choices.len)
		to_chat(user, SPAN_WARNING("Decks already lie both above and below this one."))
		return
	var/choice = WWinput(user, "Build a new deck through this hatch with \the [K]?", "New deck", "Cancel", choices + "Cancel")
	if (!choice || choice == "Cancel")
		return
	var/direction = choice == "Build a deck up" ? "up" : "down"
	var/reason = orbit_deck_refusal(H, direction, user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	to_chat(user, SPAN_NOTICE("You pass the folded node through the hatch and start bolting it in place..."))
	if (!do_after(user, 100, H) || QDELETED(K) || K.loc != user)
		return
	reason = orbit_deck_refusal(H, direction, user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	if (!orbit_add_deck(H, direction))
		to_chat(user, SPAN_WARNING("There is no room for a node on the new deck."))
		return
	user.visible_message(SPAN_NOTICE("[user] builds a new deck [direction] through \the [H]."))
	qdel(K)
