// Snow on the line (docs/trains.md#snow). Snow that falls and lies
// (snowfall_ground.dm: `weather_snow`, one or two units on a tile) drifts
// over the track. The car that leads a train pushes into it and the train
// keeps to a share of its speed for as long as it runs in snow. A snowplough
// fitted to the leading end throws the snow clear: the train keeps its speed
// and the line behind it is open.
//
// The plough is a part of a car end, like a coupling (train_couplings.dm):
// `front_plough` and `rear_plough` say which ends carry one. The engine that
// drives looks at the one tile its leading car has just entered, once a
// tile (meet_snow()); nothing else is searched.

#define TRAIN_SNOW_SLOW 0.25 // share of its speed a train loses to each unit of snow
#define TRAIN_PLOUGH_TIME 60

/obj/structure/trains
	var/front_plough = FALSE
	var/rear_plough = FALSE

/obj/structure/trains/locomotive
	var/tmp/snow_factor = 1 // share of its speed the snow on the line allows
	var/tmp/obj/structure/trains/drive_tail = null // last car of the train while this engine drives it

/obj/item/train_snowplough
	name = "snowplough"
	desc = "A steel wedge plough for the end of a locomotive or railway car. Fit it to the coupling of the end that will lead the train."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "plough_item"
	w_class = 5
	force = 12
	throwforce = 8

/obj/structure/trains/proc/plough_at(front)
	return front ? front_plough : rear_plough

/obj/structure/trains/proc/set_plough(front, state)
	if (front)
		front_plough = !!state
	else
		rear_plough = !!state
	update_couplers()

// The snow drifted over the track on this tile, in units.
/turf/proc/rail_snow()
	return weather_snow

// A plough throws the drift clear. TRUE when there was one.
/turf/proc/plough_snow()
	if (weather_snow <= 0 || persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	weather_snow = 0
	snowfall_ground_generation = ++next_snowfall_ground_generation
	snowfall_ground_icon()
	return TRUE

// The car that leads the train this engine drives, and which of its ends
// goes first, as list(car, front).
/obj/structure/trains/locomotive/proc/leading_end()
	var/forward = train_way() > 0
	var/obj/structure/trains/lead = forward ? drive_head : drive_tail
	if (!lead || QDELETED(lead))
		lead = src
	return list(lead, forward ? !lead.reversed : !!lead.reversed)

// The leading car has entered a tile: snow on it slows the train, unless a
// plough leads.
/obj/structure/trains/locomotive/proc/meet_snow()
	var/list/end = leading_end()
	var/obj/structure/trains/lead = end[1]
	var/turf/T = lead.loc
	var/depth = isturf(T) ? T.rail_snow() : 0
	if (depth <= 0)
		snow_factor = 1
		return
	if (lead.plough_at(end[2]))
		T.plough_snow()
		snow_factor = 1
		return
	var/was = snow_factor
	snow_factor = max(0.25, 1 - TRAIN_SNOW_SLOW * depth)
	if (was >= 1)
		visible_message(SPAN_WARNING("\The [lead] pushes into the snow on the line and the train slows. A snowplough at the front would clear it."))

// Fitting and taking off, at the coupling of that end (coupler_use()). TRUE
// when W was used for the plough.
/obj/structure/trains/proc/plough_use(mob/living/user, front, obj/item/W)
	if (istype(W, /obj/item/train_snowplough))
		if (plough_at(front))
			to_chat(user, "\The [src] has a snowplough at this end already. A wrench takes it off.")
			return TRUE
		if (end_neighbour(front))
			to_chat(user, SPAN_WARNING("A snowplough goes on a free end. Uncouple \the [src] here first."))
			return TRUE
		if (train_rolling())
			to_chat(user, SPAN_WARNING("The train is moving."))
			return TRUE
		user.visible_message("[user] starts bolting a snowplough to \the [src]...", "You start bolting the snowplough to the headstock of \the [src]...")
		if (!do_after(user, TRAIN_PLOUGH_TIME, src) || user.get_active_hand() != W || plough_at(front) || end_neighbour(front) || train_rolling())
			return TRUE
		user.drop_from_inventory(W)
		qdel(W)
		set_plough(front, TRUE)
		playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
		user.visible_message("[user] fits a snowplough to \the [src].", "You fit the snowplough. It clears the line when this end leads the train.")
		return TRUE
	if (plough_at(front) && is_tool(W, TOOL_WRENCH))
		if (train_rolling())
			to_chat(user, SPAN_WARNING("The train is moving."))
			return TRUE
		user.visible_message("[user] starts unbolting the snowplough of \the [src]...", "You start unbolting the snowplough...")
		if (!do_after(user, TRAIN_PLOUGH_TIME, src) || !plough_at(front) || train_rolling())
			return TRUE
		remove_plough(front, get_turf(user))
		playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
		user.visible_message("[user] takes the snowplough off \the [src].", "You take the snowplough off \the [src].")
		return TRUE
	return FALSE

// Takes the plough off that end. Returns it as an item.
/obj/structure/trains/proc/remove_plough(front, turf/where)
	if (!plough_at(front))
		return null
	set_plough(front, FALSE)
	return new /obj/item/train_snowplough(where || get_turf(src))

/obj/structure/trains/proc/plough_text()
	if (front_plough && rear_plough)
		return "It carries a snowplough at each end."
	if (front_plough || rear_plough)
		return "It carries a snowplough at its [front_plough ? "front" : "rear"] end."
	return null

#undef TRAIN_SNOW_SLOW
#undef TRAIN_PLOUGH_TIME
