// ============================================================
// Taking trains apart with a crowbar
// ------------------------------------------------------------
// A one-tile wagon or engine comes apart into part of the material it was
// built from, never more than it cost (dismantle_refund.dm). A heavy
// locomotive or a tender folds back into its kit, like a platform car
// (dismantle_car() in train_platforms.dm). Either way the car must stand
// still, uncoupled, cold and empty. Called from service_use()
// (train_servicing.dm), which every train's attackby reaches first.
// ============================================================

#define TRAIN_DISMANTLE_TIME 80

// TRUE when W was a crowbar used to take this car apart (or try to).
/obj/structure/trains/proc/dismantle_use(obj/item/W, mob/living/user)
	if (!is_tool(W, TOOL_CROWBAR))
		return FALSE
	var/obj/structure/trains/locomotive/E = src
	if (istype(E) && E.body_kind)
		E.pack_engine(user)
	else if (!wide_body())
		dismantle_wagon(user)
	else
		return FALSE
	return TRUE

// Why a one-tile car cannot be taken apart now, or null.
/obj/structure/trains/proc/wagon_dismantle_problem()
	if (!isturf(loc) || QDELETED(src))
		return "It cannot be taken apart here."
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return "Wait a moment and try again."
	if (automovement || train_rolling())
		return "\The [src] is moving."
	if (on)
		return "Shut \the [src] down first."
	if (connected || lead_car())
		return "Uncouple \the [src] first."
	if (draft_animal)
		return "Take the harness off \the [src] first."
	if (buckled_mob)
		return "Somebody is buckled to \the [src]."
	if (transporting.len)
		return "Unload \the [src] first."
	return null

/obj/structure/trains/storage/wagon_dismantle_problem()
	. = ..()
	if (!. && storage && storage.contents.len)
		return "Empty \the [src] first."

// What taking it apart gives back: half of what it cost, never more than
// that (dismantle_refund.dm).
/obj/structure/trains/proc/wagon_refund()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/units = round(crafted_refund_units(type) / 2)
	var/refund = crafted_refund_stack(type, null)
	if (!ispath(refund, /obj/item/stack) || units <= 0)
		return null
	return new refund(T, units)

/obj/structure/trains/proc/dismantle_wagon(mob/living/user)
	var/problem = wagon_dismantle_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	user.visible_message("[user] starts taking \the [src] apart...", "You start taking \the [src] apart...[locomotive ? " Its fuel and water are lost." : ""]")
	if (!do_after(user, TRAIN_DISMANTLE_TIME, src))
		return FALSE
	problem = wagon_dismantle_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	log_game("[key_name(user)] dismantled [name] at [x],[y],[z].")
	user.visible_message("[user] takes \the [src] apart.", "You take \the [src] apart.")
	take_apart()
	return TRUE

// Leaves the refund where the car stood and removes the car: the refund.
/obj/structure/trains/proc/take_apart()
	var/obj/item/stack/S = wagon_refund()
	qdel(src)
	return S

// Every section of this heavy locomotive, the engine first.
/obj/structure/trains/locomotive/proc/unit_sections()
	. = list(src)
	for (var/obj/structure/trains/platform/P in range(body_length() + 1, src))
		if (P.car_id == car_id)
			. += P

// Why this heavy locomotive cannot be packed into its kit now, or null.
/obj/structure/trains/locomotive/proc/pack_problem()
	if (!isturf(loc) || QDELETED(src) || !body_kind)
		return "It cannot be taken apart here."
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return "Wait a moment and try again."
	if (!train_car_layout("loco_[body_kind]"))
		return "\The [src] cannot be packed into a kit."
	if (automovement || train_rolling())
		return "\The [src] is moving."
	if (on)
		return "Shut \the [src] down first."
	var/list/sections = unit_sections()
	if (sections.len != body_length())
		return "\The [src] is not whole."
	for (var/obj/structure/trains/S in sections)
		var/obj/structure/trains/ahead = S.lead_car()
		if ((S.connected && S.connected.car_id != car_id) || (ahead && ahead.car_id != car_id))
			return "Uncouple \the [src] first."
		for (var/turf/T in train_platform_tiles(S.loc, S.dir))
			for (var/atom/movable/AM in T)
				if (AM.loc == T && train_platform_carries(AM))
					return "Clear everything off \the [src] first, including \the [AM]."
	return null

/obj/structure/trains/locomotive/proc/pack_engine(mob/living/user)
	var/problem = pack_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return null
	user.visible_message("[user] starts taking \the [src] apart...", "You start taking \the [src] apart. Its fuel and water are lost.")
	if (!do_after(user, TRAIN_DISMANTLE_TIME * 2, src))
		return null
	problem = pack_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return null
	log_game("[key_name(user)] packed [name] into a kit at [x],[y],[z].")
	var/obj/structure/train_car_kit/K = pack_into_kit()
	user.visible_message("[user] takes the engine apart into \a [K].", "You take the engine apart into \a [K].")
	return K

// Packs the whole engine into an unfurnished kit at its front tile.
/obj/structure/trains/locomotive/proc/pack_into_kit()
	var/obj/structure/train_car_kit/K = new(loc)
	K.set_kind("loco_[body_kind]")
	K.furnished = FALSE
	for (var/obj/structure/trains/S in unit_sections())
		qdel(S)
	return K

#undef TRAIN_DISMANTLE_TIME
