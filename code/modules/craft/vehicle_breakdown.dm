// ============================================================
// Breaking a vehicle down for parts at its press (docs/vehicle-sheets.md)
// ------------------------------------------------------------
// Every vehicle press (car workshop, hangar, shipyard press, submarine pen,
// rover bay, airship yard) can take back what it builds. Park the vehicle,
// stopped with its engine off and nobody aboard, wholly in the bay northeast
// of the press, and choose "Break down the <name> for parts". A dialog says
// what goes back into the press's stock and how long it takes; nothing
// starts until the player says yes. Ships at a slipway, drydock or boathouse
// are broken up there instead (naval/berth_breakup.dm).
//
// - What it is worth: a press model is costed as the press costs it; any
//   other vehicle is drawn on a sheet (vehicle_draught_survey) and costed as
//   the press would build that sheet. An airship at the airship yard is
//   costed from her sheet (air_draught_survey). A vehicle the press cannot
//   cost is refused: take it apart by hand.
// - What comes back: all of that cost, less for wear: the cost times the
//   average condition of its parts (breakup_part_condition, berth_breakup.dm),
//   rounded down, into the press's stock ("Unload inputs" hands it out). Loose cargo, a boot's or
//   hold's contents and bodies are set down whole by the press.
// - Who may: a keyed vehicle needs its key in hand; an airship registered to
//   a party needs a member of it or her captain. Otherwise only a player
//   with a Discord-verified account.
// - How long: half the press's assembly time, by the same mechanic's speed.
// ============================================================

// The side of the bay a vehicle to break down must lie wholly in.
/obj/structure/car_workshop/proc/breakdown_bay_side()
	return max(4, largest_model_size(), VEHICLE_DRAUGHT_MAX)

/obj/structure/car_workshop/proc/in_breakdown_bay(turf/T, side)
	return T && T.z == z && T.x > x && T.x <= x + side && T.y > y && T.y <= y + side

// The frame tiles of axis A.
/proc/vehicle_breakdown_tiles(obj/structure/vehicleparts/axis/A)
	. = list()
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		if (F.axis == A && isturf(F.loc))
			. |= F.loc

// Vehicles lying wholly in the bay: axes and, at the airship yard, airship helms.
/obj/structure/car_workshop/proc/breakdown_targets()
	. = list()
	if (!isturf(loc))
		return
	var/side = breakdown_bay_side()
	var/list/seen = list()
	for (var/turf/T in block(locate(x + 1, y + 1, z), locate(min(world.maxx, x + side), min(world.maxy, y + side), z)))
		for (var/obj/structure/vehicleparts/frame/F in T)
			var/obj/structure/vehicleparts/axis/A = F.axis
			if (!A || QDELETED(A) || seen[A])
				continue
			seen[A] = TRUE
			var/whole = TRUE
			for (var/turf/U in vehicle_breakdown_tiles(A))
				if (!in_breakdown_bay(U, side))
					whole = FALSE
			if (whole)
				. += A

/obj/structure/car_workshop/airship_yard/breakdown_bay_side()
	return AIR_DRAUGHT_MAX

/obj/structure/car_workshop/airship_yard/breakdown_targets()
	. = ..()
	var/side = breakdown_bay_side()
	for (var/turf/T in block(locate(x + 1, y + 1, z), locate(min(world.maxx, x + side), min(world.maxy, y + side), z)))
		for (var/obj/structure/airship_helm/W in T)
			if (!W.craft || !W.craft.body)
				continue
			var/whole = TRUE
			for (var/turf/U in W.craft.body.cells())
				if (!in_breakdown_bay(U, side))
					whole = FALSE
			if (whole)
				. += W

/proc/vehicle_breakdown_name(atom/V)
	if (istype(V, /obj/structure/airship_helm))
		var/obj/structure/airship_helm/W = V
		return W.craft ? W.craft.name : "airship"
	return V.name

// What building V took at this press: material = amount, or the reason it
// cannot be costed.
/obj/structure/car_workshop/proc/breakdown_cost(atom/V)
	if (istype(V, /obj/structure/airship_helm))
		var/survey = air_draught_survey(V)
		if (istext(survey))
			return survey
		var/datum/air_draught/AD = survey
		. = AD.costs()
		qdel(AD)
		return
	var/obj/structure/vehicleparts/axis/A = V
	if (A.name in models())
		var/list/C = costs(A.name)
		if (C)
			return C.Copy()
	var/survey = vehicle_draught_survey(A)
	if (istext(survey))
		return "The press cannot work out how \the [A] is built: [survey] Take it apart by hand."
	var/datum/vehicle_draught/D = survey
	. = sheet_costs(D)
	qdel(D)

// How sound a vehicle's parts are on average, from 0 to 1.
/proc/vehicle_breakdown_condition(list/parts)
	var/total = 0
	var/n = 0
	for (var/atom/movable/M in parts)
		if (istype(M, /obj/effect))
			continue
		total += breakup_part_condition(M)
		n++
	return n ? total / n : 1

// What comes back for a vehicle that cost cost, its parts in condition.
/proc/vehicle_breakdown_reclaim(list/cost, condition = 1)
	. = list()
	for (var/key in cost)
		var/n = round(cost[key] * clamp(condition, 0, 1))
		if (n > 0)
			.[key] = n

// The tiles V stands on.
/proc/vehicle_breakdown_cells(atom/V)
	if (istype(V, /obj/structure/airship_helm))
		var/obj/structure/airship_helm/W = V
		return W.craft && W.craft.body ? W.craft.body.cells() : list()
	return vehicle_breakdown_tiles(V)

// TRUE for an airship part (air_draught.dm's tables and their kin).
/proc/vehicle_breakdown_air_part(atom/movable/M)
	return istype(M, /obj/covers/airship_deck) || istype(M, /obj/structure/airship_gas_cell) || istype(M, /obj/structure/airship_helm) || istype(M, /obj/structure/engine/internal) || istype(M, /obj/structure/airship_bomb_hatch) || istype(M, /obj/item/weapon/reagent_containers/glass/barrel/fueltank)

// TRUE for what a press fits to a land vehicle or plane, anchored on its frames.
/proc/vehicle_breakdown_axis_part(atom/movable/M)
	if (!isobj(M) || !M:anchored)
		return FALSE
	for (var/path in list(/obj/structure/vehicleparts, /obj/structure/engine, /obj/structure/bed/chair, /obj/structure/turret, /obj/item/weapon/reagent_containers/glass/barrel, /obj/structure/cargo_hold, /obj/structure/table/carboot, /obj/structure/lamp))
		if (istype(M, path))
			return TRUE
	return FALSE

// list("parts", "loose", "refusal") for breaking V down. Anchored things on
// its tiles that are not its parts (cables, signs) are left where they are.
/obj/structure/car_workshop/proc/breakdown_inventory(atom/V)
	. = list("parts" = list(), "loose" = list(), "refusal" = null)
	var/air = istype(V, /obj/structure/airship_helm)
	var/obj/structure/vehicleparts/axis/A = air ? null : V
	if (A)
		for (var/atom/movable/M in A.components)
			.["parts"] |= M
		.["parts"] |= A
	for (var/turf/T in vehicle_breakdown_cells(V))
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || !M.simulated || (M in .["parts"]))
				continue
			if (isliving(M))
				var/mob/living/L = M
				if (L.stat != DEAD)
					.["refusal"] = "[L] is aboard: everyone must get off before it can be broken down."
					return
				.["loose"] += M
				continue
			if (istype(M, /atom/movable/lighting_overlay) || istype(M, /obj/effect))
				continue
			var/part = air ? vehicle_breakdown_air_part(M) : vehicle_breakdown_axis_part(M)
			if (part)
				.["parts"] += M
			else if (isobj(M) && !M:anchored)
				.["loose"] += M

// Why H may not break V down here now, or null.
/obj/structure/car_workshop/proc/breakdown_refusal(mob/living/human/H, atom/V)
	if (!V || QDELETED(V) || !(V in breakdown_targets()))
		return "Park it wholly in the bay northeast of \the [src] first."
	if (istype(V, /obj/structure/airship_helm))
		var/obj/structure/airship_helm/W = V
		var/datum/craft/C = W.craft
		if (!C || C.speed > 0)
			return "Bring her to a stop on the ground first."
		if (H)
			var/datum/craft_register/R = C.register
			if (R && R.party)
				if (!R.is_owner(H) && R.role_of(H) != CRAFT_ROLE_CAPTAIN)
					return "The [C.name] is registered to [party_train_party_name(R.party)]: only they or her captain may break her down."
			else if (!H.client || !verified_discord_id(H.client.ckey))
				return "The [C.name] is registered to nobody: only a Discord-verified player may break her down. Use OOC > Verify Discord first."
		return null
	var/obj/structure/vehicleparts/axis/A = V
	if (A.driver || A.moving || A.currentspeed || (A.engine && A.engine.on))
		return "Stop \the [A] and turn its engine off first."
	if (H)
		if (A.keyed_vehicle_id)
			if (!A.key_access(H))
				return "You need the key for \the [A] to break it down."
		else if (!H.client || !verified_discord_id(H.client.ckey))
			return "\The [A] has no key: only a Discord-verified player may break it down. Use OOC > Verify Discord first."
	return null

// Takes V apart: its cost's reclaim goes into stock, loose things are set
// down by the press. Returns what came back, or the reason it stayed.
/obj/structure/car_workshop/proc/break_down(atom/V)
	var/why = breakdown_refusal(null, V)
	if (why)
		return why
	var/cost = breakdown_cost(V)
	if (istext(cost))
		return cost
	var/list/I = breakdown_inventory(V)
	if (I["refusal"])
		return I["refusal"]
	var/turf/drop = get_turf(src)
	var/label = vehicle_breakdown_name(V)
	var/condition = vehicle_breakdown_condition(I["parts"])
	if (istype(V, /obj/structure/airship_helm))
		var/obj/structure/airship_helm/W = V
		W.decommission()
	for (var/atom/movable/M in I["loose"])
		if (!QDELETED(M))
			M.forceMove(drop)
	// Parts first, floors last; what a part holds is cargo, not parts.
	for (var/pass = 1, pass <= 2, pass++)
		for (var/atom/movable/M in I["parts"])
			if (QDELETED(M) || (pass == 2) != istype(M, /obj/covers))
				continue
			if (istype(M, /obj/structure/closet) || istype(M, /obj/structure/cargo_hold) || istype(M, /obj/structure/table/carboot))
				for (var/obj/item/inside in M)
					inside.forceMove(drop)
			for (var/mob/living/L in M)
				L.forceMove(drop)
			qdel(M)
	. = vehicle_breakdown_reclaim(cost, condition)
	for (var/key in .)
		stock[key] = (stock[key] || 0) + .[key]
	log_game("Vehicle breakdown: the [label] at [src] at [x],[y],[z] was broken down ([length(I["parts"])] parts, [length(I["loose"])] things set down); back into stock: [vehicle_sheet_costs_text(.)].")

// The press's menu entries for breaking vehicles down: label = vehicle.
/obj/structure/car_workshop/proc/breakdown_options()
	. = list()
	for (var/atom/V in breakdown_targets())
		var/label = "Break down the [vehicle_breakdown_name(V)] for parts"
		while (.[label])
			label += " "
		.[label] = V

// Asks H to confirm, then works the press to break V down.
/obj/structure/car_workshop/proc/breakdown_action(mob/living/human/H, atom/V)
	var/why = breakdown_refusal(H, V)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	var/cost = breakdown_cost(V)
	if (istext(cost))
		to_chat(H, SPAN_WARNING(cost))
		return
	var/list/I = breakdown_inventory(V)
	if (I["refusal"])
		to_chat(H, SPAN_WARNING(I["refusal"]))
		return
	var/label = vehicle_breakdown_name(V)
	var/list/back = vehicle_breakdown_reclaim(cost, vehicle_breakdown_condition(I["parts"]))
	var/time = max(1, round(trade_time(H, assembly_time, "mechanic") / 2))
	var/air = istype(V, /obj/structure/airship_helm)
	var/secs = max(1, round(time / 10))
	var/list/lines = list("Break down the [label] for parts? [air ? "She" : "It"] is taken apart for good and cannot be put back together.")
	lines += back.len ? "The press takes [vehicle_sheet_costs_text(back)] back into its stock: everything [air ? "she" : "it"] cost to build, less for any damaged parts." : "Nothing goes back into the press's stock."
	lines += "[air ? "Her" : "Its"] cargo and everything else aboard that is not part of [air ? "her" : "it"] is set down whole by \the [src]; none of it is lost."
	lines += "It takes about [secs] second[secs == 1 ? "" : "s"]."
	if (WWinput(H, jointext(lines, " "), name, "No", list("Yes", "No")) != "Yes")
		return
	if (busy || QDELETED(src) || !Adjacent(H))
		return
	why = breakdown_refusal(H, V)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	busy = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts breaking down the [label] at \the [src]."), SPAN_NOTICE("You start breaking down the [label]. Stay by \the [src] to keep working."))
	var/ok = do_after(H, time, src)
	busy = FALSE
	if (!ok || QDELETED(src) || !Adjacent(H))
		to_chat(H, SPAN_NOTICE("You stop. The [label] is still whole."))
		return
	why = breakdown_refusal(H, V)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return
	var/result = break_down(V)
	if (istext(result))
		to_chat(H, SPAN_WARNING(result))
		return
	var/list/got = result
	H.visible_message(SPAN_NOTICE("The [label] is broken down for parts."), SPAN_NOTICE("The [label] is broken down.[got.len ? " The press takes [vehicle_sheet_costs_text(got)] back into its stock." : " Nothing goes back into the press's stock."]"))
	log_game("[key_name(H)] broke down the [label] at [src] at [x],[y],[z].")

