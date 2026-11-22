// ============================================================
// Her bow: the bowsprit and its jib, and figureheads (docs/ship-edges.md)
// ------------------------------------------------------------
// A bowsprit is a spar standing out over her stem. A sail rigged on it is a
// jib: it is set, reefed and furled like any sail (hull_rigging.dm) and
// pushes half as hard as a sail on a mast, and only while the bowsprit stands
// at her bow, with no deck of hers ahead of it.
//
// A figurehead is a carved figure on her bow. It does nothing but look fine:
// the first person to work on it chooses what it is carved as.
// ============================================================

#define JIB_THRUST_SHARE 0.5

/obj/structure/vehicleparts/movement/sail/bowsprit
	name = "bowsprit"
	desc = "A stout spar run out over a ship's bow, to carry a jib forward of her masts. Rig a sail on it to set the jib."
	icon = 'icons/obj/vehicles/ship_bowsprit.dmi' // the mast's sail0, sail1 and sail2, as a spar and its jib
	// A 96x96 cell with her own tile in the middle, so the spar stands out
	// over the next tile whichever way it points. The offset centres the
	// cell and is the same for every facing: a turning hull turns her dir
	// (craft_turned) and leaves a structure's pixel offsets alone.
	pixel_x = -32
	pixel_y = -32
	ntype = "bowsprit"

// Masts are climbed and carry crow's nests; a bowsprit does neither
// (hull_masts.dm).
/obj/structure/vehicleparts/movement/sail/bowsprit/mast_grab_climb(mob/living/human/H)
	return FALSE

/obj/structure/vehicleparts/movement/sail/bowsprit/fit_crows_nest(obj/item/I, mob/living/human/H)
	return FALSE

/obj/structure/vehicleparts/movement/sail/bowsprit/aloft_examine(mob/user)
	if (isturf(loc) && !axis)
		to_chat(user, SPAN_NOTICE("A jib on a bowsprit pushes half as hard as a sail on a mast, and only from her bow."))

/obj/structure/vehicleparts/movement/sail/bowsprit/craft_drive()
	return (isturf(loc) && !axis) ? new /datum/craft_drive/fitted/sail/jib(src) : null

/datum/craft_drive/fitted/sail/jib
	kind = "sail"

// Half a mast's thrust (hull_drives.dm sets a sail's).
/datum/craft_drive/fitted/sail/jib/New(atom/movable/new_source)
	..()
	thrust *= JIB_THRUST_SHARE

// A jib draws only from her bow: no deck of hers ahead of the bowsprit.
/datum/craft_drive/fitted/sail/jib/ready()
	if (!..())
		return FALSE
	var/heading = craft.body.heading()
	var/turf/ahead = heading ? get_step(get_turf(source), heading) : null
	return ahead && !craft.body.carries(ahead)

// ---- Figureheads ----

// The figures a figurehead may be carved as: name = list(icon, state).
var/global/list/figurehead_carvings = list(
	"bear" = list('icons/obj/ship_edges.dmi', "figurehead_bear"),
	"wolf" = list('icons/obj/ship_edges.dmi', "figurehead_wolf"),
	"goose" = list('icons/obj/ship_edges.dmi', "figurehead_goose"),
	"monkey" = list('icons/obj/ship_edges.dmi', "figurehead_monkey"),
	"serpent" = list('icons/obj/ship_edges.dmi', "figurehead_serpent"),
	"ram" = list('icons/obj/ship_edges.dmi', "figurehead_ram"),
	"carved face" = list('icons/obj/ship_edges.dmi', "figurehead_face"),
)

/obj/structure/figurehead
	name = "figurehead"
	desc = "A block of timber fixed to a ship's bow, waiting to be carved."
	icon = 'icons/obj/ship_edges.dmi'
	icon_state = "figurehead"
	anchored = TRUE
	density = FALSE
	layer = 3.2
	flammable = TRUE
	var/carving = ""

/obj/structure/figurehead/New()
	..()
	if (carving)
		carve(carving)

// A figurehead saved with an older picture takes the current one.
/obj/structure/figurehead/after_load()
	..()
	if (carving)
		carve(carving)
	else
		icon = initial(icon)
		icon_state = initial(icon_state)

/obj/structure/figurehead/hull_load()
	return 0.1

/obj/structure/figurehead/proc/carve(figure)
	var/list/look = figurehead_carvings[figure]
	if (!look)
		return FALSE
	carving = figure
	icon = look[1]
	icon_state = look[2]
	name = "[figure] figurehead"
	desc = "A [figure] carved in timber on a ship's bow."
	return TRUE

/obj/structure/figurehead/attack_hand(mob/living/human/H)
	if (carving || !istype(H) || !Adjacent(H))
		return ..()
	var/figure = WWinput(H, "Carve the figurehead as:", "Figurehead", "Cancel", figurehead_carvings + "Cancel")
	if (!figure || figure == "Cancel" || carving || !Adjacent(H))
		return
	if (!do_after(H, 30, src) || carving)
		return
	carve(figure)
	H.visible_message(SPAN_NOTICE("[H] carves \the [src]."), SPAN_NOTICE("You carve a [figure] on her bow."))

/obj/structure/figurehead/examine(mob/user)
	. = ..()
	if (!carving)
		to_chat(user, SPAN_NOTICE("Click it with an empty hand to carve it."))

#undef JIB_THRUST_SHARE
