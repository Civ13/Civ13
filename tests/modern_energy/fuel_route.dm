// Production procedures; only action waits, injury receivers and RNG are adapted.
var/list/energy_mining_rolls = list()
/proc/energy_mining_prob(chance)
	if (!energy_mining_rolls.len)
		return FALSE
	var/result = energy_mining_rolls[1]
	energy_mining_rolls.Cut(1,2)
	return result
/obj/item/energy_rad_receiver
	var/pulses = 0
	var/dose = 0
	rad_act(severity)
		pulses++
		dose += severity
/mob/living/human/energy_ci/fuel_actor
	getStat(stat_name)
		return 105
/obj/structure/reactor_fuel_processor/energy_ci
	var/mode = "complete"
	var/obj/item/stack/ore/uranium/input
	processing_wait(mob/living/human/H)
		if (mode == "cancel")
			return FALSE
		if (mode == "move")
			input.forceMove(locate(1,4,2))
		if (mode == "reenter")
			attackby(input,H)
		if (mode == "destroy")
			qdel(src)
		return TRUE
/proc/energy_cartridges(turf/T)
	var/total = 0
	for (var/obj/item/stack/reactor_fuel/F in T)
		total += F.amount
	return total
/proc/run_nuclear_fuel_route_checks()
	build_research_tree()
	map.ordinal_age = 8
	map.ID = MAP_NOMADS_PANGEA
	var/mob/living/human/energy_ci/fuel_actor/H = new(locate(4,1,1))
	H.civilization = "fuel_route_ci"
	map.faction_baseline_era[H.civilization] = 0
	var/list/node = map.ensure_node_entry(H.civilization,"nuclear_power")
	node[RNODE_ENTRY_STATUS] = RNODE_DONE
	var/obj/structure/reactor_fuel_processor/energy_ci/P = new(H.loc)
	var/turf/mine = new /turf/floor/dirt/underground(locate(1,4,1))
	mine.is_mineable = TRUE
	energy_mining_rolls = list(FALSE,FALSE,FALSE,TRUE)
	mine.mining_proc(null)
	mine = locate(1,4,1)
	var/obj/item/stack/ore/uranium/U = locate() in mine
	energy_ci_check("finite production uranium mining", !!U, TRUE)
	energy_ci_check("uranium terrain depleted", mine.is_mineable, FALSE)
	if (!U)
		qdel(P)
		return
	U.forceMove(H)
	U.amount = 3
	P.input = U
	P.mode = "cancel"
	P.attackby(U,H)
	energy_ci_check("interrupted processing preserves input", U.amount, 3)
	energy_ci_check("interrupted processing produces nothing", energy_cartridges(P.loc), 0)
	P.mode = "move"
	P.attackby(U,H)
	energy_ci_check("moved input not consumed", U.amount, 3)
	energy_ci_check("moved input no output", energy_cartridges(P.loc), 0)
	U.forceMove(H)
	P.mode = "reenter"
	P.attackby(U,H)
	energy_ci_check("processing pays one ore unit", U.amount, 2)
	energy_ci_check("concurrent reentry produces once", energy_cartridges(P.loc), 1)
	energy_ci_check("processing releases input lock", U.uranium_extracting, FALSE)
	var/savefile/save = new("fuel-route.sav")
	save["/format_version"] << 2
	P.fuel_processing = TRUE
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(save,P,1)
	map_storage.clear_bookkeeping()
	var/obj/structure/reactor_fuel_processor/restored = map_storage.Load_Entry(save,ref,null,locate(3,1,1))
	energy_ci_check("processor native save restores no work", restored && !restored.fuel_processing, TRUE)
	P.fuel_processing = FALSE
	P.mode = "destroy"
	P.attackby(U,H)
	energy_ci_check("destroyed processor cannot consume", U.amount, 2)
	energy_ci_check("destroyed processor cannot issue output", energy_cartridges(locate(4,1,1)), 1)
	qdel(restored)
	// Native nested storage retains paid input and excludes the processing lock.
	var/obj/structure/closet/crate/lead/lead = new(locate(1,1,1))
	U.forceMove(lead)
	U.uranium_extracting = TRUE
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	ref = map_storage.BuildVarDirectory(save,lead,1)
	map_storage.clear_bookkeeping()
	var/obj/structure/closet/crate/lead/loaded = map_storage.Load_Entry(save,ref,null,locate(3,3,1))
	var/obj/item/stack/ore/uranium/saved_ore = locate() in loaded
	energy_ci_check("nested native ore retains paid remainder", saved_ore ? saved_ore.amount : -1, 2)
	energy_ci_check("nested native ore excludes work lock", saved_ore ? saved_ore.uranium_extracting : TRUE, FALSE)
	qdel(U)
	qdel(saved_ore)
	qdel(lead)
	qdel(loaded)
	// Explicit local-only recursive propagation and unchanged default caller.
	var/radiation_before = global_radiation
	var/obj/item/energy_rad_receiver/nearby = new(locate(1,1,1))
	var/obj/item/energy_rad_receiver/other_z = new(locate(1,1,2))
	radiation_pulse(locate(1,1,1),3,7,2,FALSE,TRUE)
	sleep(11)
	energy_ci_check("local recursion never changes global", global_radiation, radiation_before)
	energy_ci_check("local recursion exact two pulses", nearby.pulses, 2)
	energy_ci_check("local pulse excludes other z", other_z.pulses, 0)
	nearby.pulses = 0
	var/obj/item/stack/ore/uranium/emitter = new(locate(1,1,1))
	emitter.process_radioactivity()
	sleep(21)
	energy_ci_check("one uranium chain three timed pulses", nearby.pulses, 3)
	energy_ci_check("uranium never changes global", global_radiation, radiation_before)
	var/obj/structure/closet/crate/lead/shield = new(locate(1,1,1))
	emitter.forceMove(shield)
	sleep(11)
	energy_ci_check("lead shields pending emission", nearby.pulses, 3)
	qdel(emitter)
	sleep(11)
	energy_ci_check("retired ore stops pending chain", emitter ? emitter.uranium_emitting : FALSE, FALSE)
	var/hits = nearby.pulses
	sleep(11)
	energy_ci_check("retired ore does not rearm", nearby.pulses, hits)
	radiation_pulse(locate(1,1,1),3,7,1,FALSE)
	energy_ci_check("default pulse retains global behavior", global_radiation > radiation_before, TRUE)
	qdel(shield)
	qdel(H)
