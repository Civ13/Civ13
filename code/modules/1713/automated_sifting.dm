// Slow renewable traces, using the drill's bounded output and power lifecycle.
/obj/structure/drill/sifter
	name = "powered soil sifter"
	desc = "Separates trace resources from uncovered non-mineable dirt or sand. Requires 150 cable power and anchoring. Produces two random trace units every two minutes; clear its output before twelve stacks accumulate."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "grinder"
	var/machine_icon = "grinder"
	var/requires_river = FALSE
	var/tmp/datum/trace_soil_identity
	var/tmp/datum/trace_water_identity
	var/tmp/turf/trace_water
	ore_types = list(/obj/item/stack/material/stone, /obj/item/stack/ore/glass, /obj/item/stack/ore/copper, /obj/item/stack/ore/tin, /obj/item/stack/ore/iron, /obj/item/stack/ore/coal, /obj/item/stack/ore/saltpeter, /obj/item/stack/ore/sulphur, /obj/item/stack/ore/lead)

/obj/structure/drill/sifter/panner
	name = "powered river concentrator"
	desc = "Concentrates trace river sediment on uncovered non-mineable dirt or sand beside shallow freshwater. Requires 150 cable power and anchoring. Produces two random copper, tin, silver or gold ore units every two minutes; clear its output before twelve stacks accumulate."
	icon_state = "centrifuge"
	machine_icon = "centrifuge"
	requires_river = TRUE
	ore_types = list(/obj/item/stack/ore/copper, /obj/item/stack/ore/tin, /obj/item/stack/ore/silver, /obj/item/stack/ore/gold)

/obj/structure/drill/sifter/update_icon()
	icon_state = active ? "[machine_icon]_active" : (powered ? "[machine_icon]_powered" : machine_icon)

/obj/structure/drill/sifter/proc/valid_trace_site()
	if (!anchored || !isturf(loc))
		return FALSE
	var/turf/T = loc
	if (!T.can_sift_resources() || (active && T.sifting_identity != trace_soil_identity))
		return FALSE
	var/turf/water = requires_river ? T.panning_water() : null
	return !requires_river || (water && (!active || (water == trace_water && water.sifting_identity == trace_water_identity)))

/obj/structure/drill/sifter/attack_hand(mob/living/human/H)
	if (!active)
		if (!valid_trace_site())
			to_chat(H, SPAN_WARNING("Anchor the machine on uncovered non-mineable soil[requires_river ? " beside shallow freshwater" : ""]."))
			return
		var/turf/T = loc
		if (!T.sifting_identity)
			T.sifting_identity = new /datum
		trace_soil_identity = T.sifting_identity
		trace_water = requires_river ? T.panning_water() : null
		if (trace_water)
			if (!trace_water.sifting_identity)
				trace_water.sifting_identity = new /datum
			trace_water_identity = trace_water.sifting_identity
	return ..()

/obj/structure/drill/sifter/stop_drilling()
	. = ..()
	trace_soil_identity = null
	trace_water_identity = null
	trace_water = null

/obj/structure/drill/sifter/get_saved_vars()
	var/list/saved = ..()
	saved -= list("trace_soil_identity", "trace_water_identity", "trace_water")
	return saved

/obj/structure/drill/sifter/process_machine()
	if (!active || process_pending)
		return
	if (!valid_trace_site())
		stop_drilling()
		visible_message(SPAN_WARNING("\The [src] stops: anchor it on uncovered non-mineable soil[requires_river ? " beside shallow freshwater" : ""]."))
		return
	if (!check_power())
		stop_drilling()
		visible_message(SPAN_WARNING("\The [src] stops: insufficient cable power."))
		return
	if (next_spawn <= 0 && world.time >= production_due)
		if (!produce_minerals(pick(ore_types), 2))
			stop_drilling()
			visible_message(SPAN_WARNING("\The [src] stops: clear its output tile and restart it."))
			return
		next_spawn = 60
		production_due = world.time + 1200
	update_icon()
	process_pending = TRUE
	spawn(20)
		process_pending = FALSE
		if (active)
			next_spawn--
			process_machine()
