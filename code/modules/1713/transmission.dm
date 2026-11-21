// Transmission: line shafts, gear boxes, clutches and rope drives carry a
// prime mover's drive (mechanical_power.dm) beyond the tiles beside it.
//
// Nothing here ticks and there is no network object. mechanical_drive_load()
// walks from the machine that asks, through the fastened parts that touch one
// another (within one tile, diagonals included), to the movers at the far end.
// A gear box carries drive to a gear box directly above or below it, and a rope
// drive to the rope drive its rope is tied to.

#define TRANSMISSION_ROPE_RANGE 7
#define TRANSMISSION_WOOD_RUN 8
#define TRANSMISSION_IRON_RUN 16

// How much of a drive a structure uses while it works: 0 for anything that is
// not driven. Movers and transmission parts draw nothing.
/obj/structure
	var/drive_draw = 0

/obj/structure/workshop_machine/potters_wheel
	drive_draw = 1
/obj/structure/workshop_machine/masons_saw
	drive_draw = 1
/obj/structure/workshop_machine/cement_mixer
	drive_draw = 1
/obj/structure/workshop_machine/shear_legs
	drive_draw = 1
/obj/structure/workshop_machine/wire_bench
	drive_draw = 1
/obj/structure/workshop_machine/fitting/drill_press
	drive_draw = 1
/obj/structure/workshop_machine/trip_hammer
	drive_draw = 2
/obj/structure/workshop_machine/trip_hammer/steam
	drive_draw = 0
/obj/structure/workshop_machine/rolling_mill
	drive_draw = 2
/obj/structure/fluid_pump/hand
	drive_draw = 1
/obj/structure/hydraulic_monitor
	drive_draw = 1
/obj/structure/stone_crusher
	drive_draw = 2
/obj/structure/drill/stamp_mill/water
	drive_draw = 2
/obj/structure/furnace/blast_furnace
	drive_draw = 2

// TRUE when this set of joined parts holds more line shaft than it can turn:
// a run with any wooden length turns at most 8 lengths, an all-iron run 16.
/proc/transmission_run_too_long(list/parts, search_cut_short)
	if (search_cut_short)
		return TRUE
	var/lengths = 0
	var/limit = TRANSMISSION_IRON_RUN
	for (var/obj/structure/workshop_machine/transmission/line_shaft/S in parts)
		lengths++
		limit = min(limit, S.max_run)
	return lengths > limit

//////////////////////////////////////////////////////////////////////////////
// Shared base

/obj/structure/workshop_machine/transmission
	name = "transmission"
	icon = 'icons/obj/transmission.dmi'
	density = FALSE
	flammable = TRUE

// TRUE while this part passes drive on.
/obj/structure/workshop_machine/transmission/proc/carries()
	return anchored && isturf(loc)

// Parts this one passes drive to beyond the tiles touching it.
/obj/structure/workshop_machine/transmission/proc/linked_parts()
	return list()

/obj/structure/workshop_machine/transmission/examine(mob/user, distance)
	..(user, distance)
	if (!anchored)
		to_chat(user, SPAN_WARNING("It is not fastened down."))
		return
	if (!carries())
		return
	var/list/load = mechanical_drive_load(src)
	if (load[4])
		to_chat(user, SPAN_WARNING("The run of line shaft is too long to turn: a run with any wooden length turns at most [TRANSMISSION_WOOD_RUN] lengths, an iron run [TRANSMISSION_IRON_RUN]."))
	else if (load[1] < 1)
		to_chat(user, SPAN_NOTICE("It is turning, with a strength of [load[2]] against a draw of [load[3]]. The machines on it work in [round(mechanical_load_factor(load) * 100)]% of the usual time."))
	else
		to_chat(user, SPAN_NOTICE("It is still: no turning treadwheel, horse gin, mill wheel or windmill is joined to it."))

/obj/structure/workshop_machine/transmission/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		update_icon()
		return
	return ..()

//////////////////////////////////////////////////////////////////////////////
// Line shafts

/obj/structure/workshop_machine/transmission/line_shaft
	name = "wooden line shaft"
	desc = "A squared timber axle on a trestle. Lay a line of them from a treadwheel, horse gin, mill wheel or windmill, and the fastened machines beside any length are driven too. A run with any wooden length turns at most eight lengths."
	icon_state = "line_shaft"
	var/max_run = TRANSMISSION_WOOD_RUN

/obj/structure/workshop_machine/transmission/line_shaft/attack_hand(mob/living/human/H)
	if (!istype(H) || anchored)
		return ..()
	set_dir(turn(dir, 90))
	to_chat(H, SPAN_NOTICE("You turn \the [src] round."))

/obj/structure/workshop_machine/transmission/line_shaft/iron
	name = "iron line shaft"
	desc = "A wrought-iron shaft in a greased bearing block. Lay a line of them from a prime mover, and the fastened machines beside any length are driven too. An all-iron run turns up to sixteen lengths."
	icon_state = "line_shaft_iron"
	flammable = FALSE
	max_run = TRANSMISSION_IRON_RUN

//////////////////////////////////////////////////////////////////////////////
// Clutch: a length of shaft that can be thrown out of gear.

/obj/structure/workshop_machine/transmission/line_shaft/clutch
	name = "shaft clutch"
	desc = "A length of shaft broken by a sliding dog clutch. Thrown in, it passes the drive on like any other length; thrown out, everything past it stands still. Work it by hand or tie a lever's cord to it."
	icon_state = "clutch_engaged"
	var/engaged = TRUE

/obj/structure/workshop_machine/transmission/line_shaft/clutch/after_load()
	..()
	update_icon()

/obj/structure/workshop_machine/transmission/line_shaft/clutch/update_icon()
	icon_state = engaged ? "clutch_engaged" : "clutch"

/obj/structure/workshop_machine/transmission/line_shaft/clutch/carries()
	return ..() && engaged

/obj/structure/workshop_machine/transmission/line_shaft/clutch/examine(mob/user, distance)
	..(user, distance)
	if (!engaged)
		to_chat(user, SPAN_NOTICE("It is thrown out: nothing past it turns."))

/obj/structure/workshop_machine/transmission/line_shaft/clutch/proc/set_engaged(want)
	if (want == engaged)
		return FALSE
	engaged = want
	update_icon()
	playsound(src, 'sound/items/Ratchet.ogg', 40, TRUE)
	return TRUE

/obj/structure/workshop_machine/transmission/line_shaft/clutch/attack_hand(mob/living/human/H)
	if (!istype(H) || !anchored)
		return ..()
	set_engaged(!engaged)
	H.visible_message(SPAN_NOTICE("[H] throws \the [src] [engaged ? "in" : "out"]."), SPAN_NOTICE("You throw \the [src] [engaged ? "in" : "out"]."))

//////////////////////////////////////////////////////////////////////////////
// Gear box: carries drive one level up or down.

/obj/structure/workshop_machine/transmission/gear_box
	name = "gear box"
	desc = "A pit wheel meshing with a lantern pinion on an upright shaft. It joins the line shafts around it to a gear box set directly above or below it, so a mill wheel on the ground floor can drive the floor above."
	icon_state = "gear_box"
	density = TRUE

/obj/structure/workshop_machine/transmission/gear_box/linked_parts()
	. = list()
	var/turf/here = get_turf(src)
	if (!here)
		return
	for (var/z in list(multiz_level_above(here.z), multiz_level_below(here.z)))
		if (!z)
			continue
		var/turf/T = locate(here.x, here.y, z)
		for (var/obj/structure/workshop_machine/transmission/gear_box/G in T)
			. += G

//////////////////////////////////////////////////////////////////////////////
// Rope drive: carries drive across a gap to its partner wheel.

/obj/structure/workshop_machine/transmission/rope_drive
	name = "rope drive wheel"
	desc = "A grooved wheel for an endless rope. Tie a rope from it to another rope drive wheel up to seven tiles away on the same level, and drive passes between them over walls, roads and water."
	icon_state = "rope_drive"
	density = TRUE
	flammable = FALSE
	var/link = "" // "dx,dy" to the wheel its rope runs to

/obj/structure/workshop_machine/transmission/rope_drive/proc/partner()
	var/list/xy = splittext(link, ",")
	if (xy.len != 2)
		return null
	var/turf/T = locate(x + text2num(xy[1]), y + text2num(xy[2]), z)
	if (!T)
		return null
	for (var/obj/structure/workshop_machine/transmission/rope_drive/R in T)
		if (R != src)
			return R
	return null

/obj/structure/workshop_machine/transmission/rope_drive/linked_parts()
	var/obj/structure/workshop_machine/transmission/rope_drive/R = partner()
	return R ? list(R) : list()

/obj/structure/workshop_machine/transmission/rope_drive/proc/tie_to(obj/structure/workshop_machine/transmission/rope_drive/R)
	link = R ? "[R.x - x],[R.y - y]" : ""
	if (R)
		R.link = "[x - R.x],[y - R.y]"

/obj/structure/workshop_machine/transmission/rope_drive/examine(mob/user, distance)
	..(user, distance)
	var/obj/structure/workshop_machine/transmission/rope_drive/R = partner()
	if (R)
		to_chat(user, SPAN_NOTICE("Its rope runs to the wheel [mechanism_offset_words(src, get_turf(R))]."))
	else
		to_chat(user, SPAN_NOTICE("No rope runs from it. Use rope on it to tie it to another rope drive wheel within [TRANSMISSION_ROPE_RANGE] tiles."))

/obj/structure/workshop_machine/transmission/rope_drive/attackby(obj/item/I, mob/living/human/H)
	if (istype(I, /obj/item/stack/material/rope) && istype(H))
		rope_on_wheel(I, H)
		return
	return ..()

/obj/structure/workshop_machine/transmission/rope_drive/proc/rope_on_wheel(obj/item/stack/material/rope/R, mob/living/human/H)
	var/obj/structure/workshop_machine/transmission/rope_drive/old = partner()
	if (old)
		if (old.partner() == src)
			old.link = ""
		link = ""
		new /obj/item/stack/material/rope(get_turf(H), 1)
		H.visible_message(SPAN_NOTICE("[H] takes the rope off \the [src]."), SPAN_NOTICE("You take the rope off \the [src] and coil it up."))
		return
	var/list/choices = list()
	for (var/obj/structure/workshop_machine/transmission/rope_drive/W in range(TRANSMISSION_ROPE_RANGE, src))
		if (W != src && W.z == z && W.anchored && !W.partner())
			choices["Rope drive wheel ([mechanism_offset_words(src, get_turf(W))])"] = W
	if (!choices.len)
		to_chat(H, SPAN_WARNING("There is no free, fastened rope drive wheel within [TRANSMISSION_ROPE_RANGE] tiles of \the [src]."))
		return
	var/choice = player_input(H, "Run the rope from \the [src] to which wheel?", "Rope drive", null, "anything", choices, TRUE)
	var/obj/structure/workshop_machine/transmission/rope_drive/target = choice ? choices[choice] : null
	if (!target || QDELETED(target) || QDELETED(src) || QDELETED(R) || H.get_active_hand() != R || get_dist(H, src) > 1)
		return
	H.visible_message(SPAN_NOTICE("[H] starts running a rope from \the [src]."), SPAN_NOTICE("You start running a rope from \the [src]."))
	if (!do_after(H, 30, src) || QDELETED(target) || QDELETED(src) || partner() || target.partner() || !R.use(1))
		return
	tie_to(target)
	to_chat(H, SPAN_NOTICE("You run the rope from \the [src] to the wheel [mechanism_offset_words(src, get_turf(target))]."))

#undef TRANSMISSION_ROPE_RANGE
#undef TRANSMISSION_WOOD_RUN
#undef TRANSMISSION_IRON_RUN
