// Chemistry automation phase 4: the pipe meter. Set on a pipe, it reports
// that pipe's network: pumps, what moved last step and each machine's state.
// Its dial lights while the network moves liquid. See
// docs/chemistry-automation-design.md.

var/global/list/fluid_meters = list()

/obj/structure/fluid_meter
	name = "pipe meter"
	desc = "A gauge clamped onto a pipe. Examine it or use it to read its pipe network: pumps, flow and every machine on the line. It lights while liquid moves."
	icon = 'icons/obj/machines/pipes.dmi'
	icon_state = "meter"
	anchored = TRUE
	density = FALSE
	layer = 2.9
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/fluid_meter/New()
	..()
	fluid_meters |= src
	update_icon()

/obj/structure/fluid_meter/Destroy()
	fluid_meters -= src
	return ..()

/obj/structure/fluid_meter/after_load()
	. = ..()
	fluid_meters |= src
	update_icon()

/obj/structure/fluid_meter/proc/network()
	for (var/obj/structure/fluid_pipe/P in loc)
		if (P.network)
			return P.network
	return null

/obj/structure/fluid_meter/update_icon()
	var/datum/fluid_network/N = network()
	icon_state = N && N.last_moved > 0 && !N.idle_steps ? "meter_on" : "meter"

// One line per machine on the network, in a stable order.
/proc/fluid_member_state(obj/O)
	if (istype(O, /obj/structure/fluid_pump))
		var/obj/structure/fluid_pump/P = O
		return P.on ? (P.powered ? "running" : "on, without power") : "off"
	if (istype(O, /obj/structure/fluid_tank))
		var/obj/structure/fluid_tank/T = O
		var/state = "[round(T.reagents.total_volume)]/[T.reagents.maximum_volume]"
		if (T.reagents.total_volume)
			state += " [T.reagents.get_master_reagent_name()]"
		if (T.filter_reagent)
			var/datum/reagent/R = chemical_reagents_list[T.filter_reagent]
			state += ", only [R ? R.name : T.filter_reagent]"
		return state
	if (istype(O, /obj/structure/fluid_vessel))
		var/obj/structure/fluid_vessel/V = O
		var/datum/chemical_reaction/R = V.recipe()
		if (!R)
			return "no recipe"
		var/list/stages = list("filling", V.powered ? "reacting" : "waiting for power", "emptying")
		return "[R.name], [stages[V.stage + 1]], [round(V.reagents.total_volume)]/[V.volume]"
	if (istype(O, /obj/structure/fluid_bottler))
		var/obj/structure/fluid_bottler/B = O
		var/obj/item/weapon/reagent_containers/C = B.held_container()
		if (!B.filter_reagent)
			return "no reagent set"
		return C ? "filling \a [C], [round(C.reagents.total_volume)]/[C.reagents.maximum_volume]" : "waiting for a container"
	if (istype(O, /obj/structure/fluid_tablet_press))
		var/obj/structure/fluid_tablet_press/press = O
		return "[round(press.reagents.total_volume)] units buffered[press.powered ? ", pressing" : ""]"
	if (istype(O, /obj/structure/fluid_intake))
		var/obj/structure/fluid_intake/I = O
		return I.water_turf() ? "beside water" : "no water"
	var/list/roles = list()
	if (O.fluid_supply_tier())
		roles += "supplying"
	if (O.fluid_demand_tier())
		roles += "taking"
	return roles.len ? jointext(roles, " and ") : "idle"

/obj/structure/fluid_meter/proc/report()
	var/datum/fluid_network/N = network()
	if (!N)
		return list("It is not on a pipe network.")
	var/pumps = 0
	var/running = 0
	for (var/obj/structure/fluid_pump/P in N.members)
		pumps++
		if (P.on && P.powered)
			running++
	var/list/lines = list()
	var/flow = N.idle_steps ? "idle" : "moved [round(N.last_moved)] units last step"
	lines += "Network: [N.pipes.len] pipes, [running] of [pumps] pumps running, [flow]."
	for (var/obj/O in N.members)
		if (istype(O, /obj/structure/fluid_meter) || QDELETED(O))
			continue
		lines += "[O.name]: [fluid_member_state(O)]"
	return lines

/obj/structure/fluid_meter/examine(mob/user, distance)
	..(user, distance)
	for (var/line in report())
		to_chat(user, SPAN_NOTICE(line))

/obj/structure/fluid_meter/attack_hand(mob/user)
	update_icon()
	for (var/line in report())
		to_chat(user, SPAN_NOTICE(line))

/proc/factory_meters_update()
	for (var/obj/structure/fluid_meter/M in fluid_meters.Copy())
		if (QDELETED(M))
			fluid_meters -= M
			continue
		M.update_icon()
