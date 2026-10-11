// A finite terrain-consuming batch. Inputs live in native contents for saves.
/obj/structure/drill/fracking
	name = "hydraulic fracturing rig"
	desc = "A Modern rig. Anchor beside mineable underground rock, connect 300 cable power, and load a freshwater barrel, an empty petroleum barrel and raw sand. A two-minute batch consumes one rock tile, 20 water and 5 sand for 50 petroleum. Each batch stops the rig."
	powerneeded = 300
	var/tmp/turf/fracture_target
	var/tmp/datum/fracture_identity

/obj/structure/drill/fracking/proc/valid_fracture_target(turf/T)
	return anchored && isturf(loc) && T && get_dist(src, T) == 1 && T.z == z && istype(T, /turf/floor/dirt/underground) && !istype(T, /turf/floor/dirt/underground/empty) && T.is_mineable

/obj/structure/drill/fracking/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel) || istype(W, /obj/item/stack/ore/glass))
		if (active || W.loc != H || get_dist(src, H) > 1)
			return
		if (contents.len >= 3)
			to_chat(H, SPAN_WARNING("Unload the rig before adding another input."))
			return
		H.drop_from_inventory(W)
		W.loc = src
		return
	return ..()

/obj/structure/drill/fracking/attack_hand(mob/living/human/H)
	if (active)
		return ..()
	fracture_target = null
	for (var/turf/T in orange(1, src))
		if (valid_fracture_target(T))
			fracture_target = T
			break
	if (!fracture_target)
		to_chat(H, SPAN_WARNING("Anchor beside undepleted underground rock."))
		return
	if (!fracture_target.sifting_identity)
		fracture_target.sifting_identity = new /datum
	fracture_identity = fracture_target.sifting_identity
	if (!fracture_batch() || !check_power())
		stop_drilling()
		to_chat(H, SPAN_WARNING("Load pure freshwater, an empty or petroleum-only barrel, five sand, and sufficient cable power."))
		return
	return ..()

/obj/structure/drill/fracking/verb/unload_inputs()
	set name = "Unload Fracking Rig"
	set src in oview(1)
	stop_drilling()
	for (var/obj/item/I in contents)
		I.loc = loc

/obj/structure/drill/fracking/proc/fracture_batch(commit_batch = FALSE)
	if (!valid_fracture_target(fracture_target) || fracture_target.sifting_identity != fracture_identity)
		return FALSE
	var/obj/item/weapon/reagent_containers/glass/barrel/water
	var/obj/item/weapon/reagent_containers/glass/barrel/output
	var/obj/item/stack/ore/glass/sand
	for (var/obj/item/weapon/reagent_containers/glass/barrel/B in contents)
		if (!water && B.reagents.get_reagent_amount("water") >= 20 && B.reagents.total_volume == B.reagents.get_reagent_amount("water"))
			water = B
		else if (!output && B.reagents.get_free_space() >= 50 && B.reagents.total_volume == B.reagents.get_reagent_amount("petroleum"))
			output = B
	for (var/obj/item/stack/ore/glass/S in contents)
		if (S.amount >= 5)
			sand = S
			break
	if (!water || !output || !sand)
		return FALSE
	if (commit_batch)
		// All validation precedes this non-yielding payment and terrain replacement.
		water.reagents.remove_reagent("water", 20)
		sand.use(5)
		fracture_target.change_the_turf()
		output.reagents.add_reagent("petroleum", 50)
	return TRUE

/obj/structure/drill/fracking/process_machine()
	if (!active || process_pending)
		return
	if (!fracture_batch() || !check_power())
		stop_drilling()
		return
	if (next_spawn <= 0 && world.time >= production_due)
		fracture_batch(TRUE)
		stop_drilling()
		return
	update_icon()
	process_pending = TRUE
	spawn(20)
		process_pending = FALSE
		if (active)
			next_spawn--
			process_machine()

/obj/structure/drill/fracking/stop_drilling()
	. = ..()
	fracture_target = null
	fracture_identity = null

/obj/structure/drill/fracking/get_saved_vars()
	var/list/saved = ..()
	saved -= list("fracture_target", "fracture_identity")
	return saved

/obj/structure/drill/fracking/Destroy()
	for (var/obj/item/I in contents)
		I.loc = loc
	return ..()
