// Pipes by material (docs/material-roles.md, "Pipes").
//
// One pipe type in any material, the way a gear set is. A pipe knows its
// material name and nothing else; what the material means is asked of the
// material:
//   pipe_pressure(name)       -> share of a pump's flow the pipe can carry
//   pipe_material_toxic(name) -> it poisons what it carries (lead)
// A network moves at the pressure of its weakest pipe, surveyed once each
// time the networks are rebuilt, so a step costs nothing extra.
//
// The pipe and network bodies in code/modules/1713/factory_pipes.dm are
// untouched; this file wraps them.

#define PIPE_PRESSURE_MIN 0.25
// Chance, each step a network with a toxic pipe moves liquid, that one unit
// of lead ends up in a tank on it.
#define PIPE_TOXIN_CHANCE 2
#define HAND_PUMP_STROKE 50 // one pull of the handle, in deciseconds
#define HAND_PUMP_RUN 80    // how long one pull keeps the pump working

var/global/list/pipe_pressure_cache = list()

// Steel is 1. Tougher material holds more pressure: bamboo 0.55, bored log
// 0.65, lead 0.45, copper 0.75, iron 0.9.
/proc/pipe_pressure(material_name)
	var/cached = pipe_pressure_cache[material_name]
	if (isnull(cached))
		var/material/M = get_material_by_name(material_name)
		cached = M ? max(PIPE_PRESSURE_MIN, min(1, round(sqrt(M.toughness / 100), 0.05))) : 1
		pipe_pressure_cache[material_name] = cached
	return cached

/proc/pipe_material_toxic(material_name)
	var/material/M = get_material_by_name(material_name)
	return M ? M.toxic : FALSE

/obj/structure/fluid_pipe
	// Material name, as get_material_by_name() takes it.
	var/pipe_material = "steel"

/obj/structure/fluid_pipe/New(newloc, material_name)
	if (istext(material_name) && get_material_by_name(material_name))
		pipe_material = material_name
	..(newloc)
	apply_pipe_material()

/obj/structure/fluid_pipe/after_load()
	. = ..()
	apply_pipe_material()

/obj/structure/fluid_pipe/proc/pipe_name(material/M)
	return "[M.name == "wood" ? "bored log" : M.display_name] pipe"

// A steel pipe keeps the name and look it always had.
/obj/structure/fluid_pipe/proc/apply_pipe_material()
	var/material/M = get_material_by_name(pipe_material)
	if (!M || pipe_material == "steel")
		return
	name = pipe_name(M)
	desc = "A pipe of [M.display_name]. It joins with pipes and machines on every side. Liquids and gases only flow through a network while a working pump is connected to it."
	color = M.icon_colour
	flammable = M.flammable

// The valve shows open or closed by its colour, and is always steel.
/obj/structure/fluid_pipe/valve/apply_pipe_material()
	return

/obj/structure/fluid_pipe/examine(mob/user, distance)
	..(user, distance)
	if (pipe_material != "steel")
		to_chat(user, "A pipe of this material carries [round(pipe_pressure(pipe_material) * 100)]% of a pump's flow.")
	if (pipe_material_toxic(pipe_material))
		to_chat(user, SPAN_WARNING("Lead slowly poisons whatever stands in a tank on its network. Do not drink from it."))
	if (network && network.pressure && network.pressure < 1)
		var/material/weak = get_material_by_name(network.weakest)
		to_chat(user, "The weakest pipe on this network is [weak ? weak.display_name : network.weakest], so the whole network moves [round(network.pressure * 100)]% of what its pumps could.")
	if (network && network.toxic_pipes)
		to_chat(user, SPAN_WARNING("There is lead pipe on this network."))

// The same pipe behind an earlier research gate: recipes are gated by result
// type, and hand-made pipe comes long before the factory.
/obj/structure/fluid_pipe/plain
	name = "pipe"
	desc = "A hand-made pipe."
	pipe_material = "wood"

/datum/fluid_network
	var/pressure = 0     // 0 until surveyed
	var/weakest = null   // material name of the weakest pipe
	var/toxic_pipes = 0

/datum/fluid_network/proc/survey_pipes()
	pressure = 1
	weakest = null
	toxic_pipes = 0
	for (var/obj/structure/fluid_pipe/P in pipes)
		if (P.pipe_material == "steel")
			continue
		var/rating = pipe_pressure(P.pipe_material)
		if (rating < pressure)
			pressure = rating
			weakest = P.pipe_material
		if (pipe_material_toxic(P.pipe_material))
			toxic_pipes++

/datum/fluid_network/pumped_rate()
	. = ..()
	if (. > 0)
		if (!pressure)
			survey_pipes()
		. = max(1, round(. * pressure))

/datum/fluid_network/network_step()
	. = ..()
	if (. > 0 && toxic_pipes && prob(PIPE_TOXIN_CHANCE))
		taint_from_pipes()

// One unit of lead into a tank that will take it. Machines that only accept
// their own feed refuse it, so fuel and reagent lines stay clean.
/datum/fluid_network/proc/taint_from_pipes()
	var/list/takers = list()
	for (var/obj/O in members)
		if (member_ok(O) && O.fluid_demand_tier() && O.fluid_demand("lead") > 0)
			takers += O
	if (!takers.len)
		return
	var/obj/taker = pick(takers)
	if (taker.fluid_receive("lead", 1, null) > 0)
		taker.note_food_toxin("lead from the pipes")

// Lead did nothing when swallowed. Now it is a slow poison: a little toxin
// damage, and now and then a little harm to the brain.
/datum/reagent/lead/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(removed * 2)
	if (prob(2))
		M.adjustBrainLoss(0.5)

//////////////////////////////////////////////////////////////////////////////
// Plumbing before electricity: a pump someone works, a wooden intake, a
// cistern and a trough, so hand-made pipe has something to do.

/obj/structure/fluid_pump/hand
	name = "hand pump"
	desc = "A lift pump on a timber base. Work the handle and it moves liquids and gases through the pipe network beside it for as long as you keep pumping. A turning treadwheel, horse gin, mill wheel or windmill next to it works it for you."
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "pump_s"
	powerneeded = 0
	var/tmp/pumped_until = 0
	var/tmp/mob/pumper = null

// Who is pumping is not saved; pumped_until is a world.time stamp (world_time_stamps.dm).
/obj/structure/fluid_pump/hand/persistence_runtime_var(key)
	if (key == "pumper" || key == "on")
		return TRUE
	return ..()

/obj/structure/fluid_pump/hand/proc/driven()
	return world.time < pumped_until || mechanical_drive_factor(src) < 1

/obj/structure/fluid_pump/hand/pump_step()
	var/was = powered
	on = (anchored && isturf(loc) && driven()) ? TRUE : FALSE
	powered = on
	if (powered && !was)
		var/datum/fluid_network/N = fluid_network_of(src)
		if (N)
			N.idle_steps = 0

/obj/structure/fluid_pump/hand/pump_stop()
	powered = FALSE

/obj/structure/fluid_pump/hand/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	if (pumper == H)
		return
	if (pumper && world.time < pumped_until)
		to_chat(H, SPAN_WARNING("[pumper] is already working the handle."))
		return
	pumper = H
	H.visible_message(SPAN_NOTICE("[H] starts working the handle of \the [src]."), SPAN_NOTICE("You start working the handle of \the [src]. Stay beside it to keep pumping."))
	while (!QDELETED(src) && anchored && !QDELETED(H) && !H.stat)
		pumped_until = world.time + HAND_PUMP_RUN
		if (!do_after(H, HAND_PUMP_STROKE, src))
			break
	if (!QDELETED(src) && pumper == H)
		pumper = null

/obj/structure/fluid_pump/hand/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		to_chat(user, SPAN_WARNING("\The [src] takes no cable. Work its handle."))
		return
	return ..()

/obj/structure/fluid_pump/hand/examine(mob/user, distance)
	..(user, distance)
	if (mechanical_drive_factor(src) < 1)
		to_chat(user, SPAN_NOTICE("The machine beside it is working the handle."))
	else if (world.time >= pumped_until)
		to_chat(user, "Nobody is working the handle. Click it to pump.")

/obj/structure/fluid_intake/wooden
	name = "wooden water intake"
	desc = "A screened wooden box inlet. Set beside open water, it supplies that water to its pipe network."
	color = "#824B28"
	flammable = TRUE

/obj/structure/fluid_tank/cistern
	name = "wooden cistern"
	desc = "A great staved cask for a pipe network. It fills from sources and feeds the troughs, taps and machines that want what it holds. Hold a container and use Set Tank Filter to keep it to one liquid or gas."
	icon_state = "beer_barrel"
	flammable = TRUE

/obj/structure/water_tap/trough
	name = "water trough"
	desc = "A wooden trough on a pipe network. It gives whatever the pipes bring it: fill a container, drink from it with a grab, or wash your hands."
	icon = 'icons/obj/structures.dmi'
	icon_state = "water_trough"
	flammable = TRUE

#undef PIPE_PRESSURE_MIN
#undef PIPE_TOXIN_CHANCE
#undef HAND_PUMP_STROKE
#undef HAND_PUMP_RUN
