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
	var/craft_skill = 105
	getStat(stat_name)
		return craft_skill
	getStatCoeff(stat_name)
		return 1
/obj/item/stack/ore/uranium/energy_ci
	var/mode = "complete"
	uranium_extraction_wait(mob/living/human/H, obj/item/weapon/reagent_containers/glass/extraction_kit/ET, delay)
		if (mode == "cancel")
			return FALSE
		if (mode == "kit")
			qdel(ET)
		if (mode == "actor")
			qdel(H)
		if (mode == "ore")
			qdel(src)
		return TRUE
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
		if (mode == "destroy_input")
			qdel(input)
		if (mode == "destroy_actor")
			qdel(H)
		return TRUE
/proc/energy_cartridges(turf/T)
	var/total = 0
	for (var/obj/item/stack/reactor_fuel/F in T)
		total += F.amount
	return total
/proc/energy_ore_units(turf/T)
	var/total = 0
	for (var/obj/item/stack/ore/uranium/U in T)
		total += U.amount
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
	energy_ci_check("real underground terrain is mineable", mine.is_mineable, TRUE)
	energy_mining_rolls = list(FALSE,FALSE,FALSE,TRUE)
	mine.mining_proc(null)
	mine = locate(1,4,1)
	var/obj/item/stack/ore/uranium/U = locate() in mine
	energy_ci_check("finite production uranium mining", !!U, TRUE)
	energy_ci_check("uranium terrain depleted", mine.is_mineable, FALSE)
	if (!U)
		qdel(P)
		return
	energy_mining_rolls = list(FALSE,FALSE,FALSE,TRUE)
	mine.mining_proc(null)
	energy_ci_check("depleted terrain cannot mint more uranium", energy_ore_units(locate(1,4,1)), 1)
	var/turf/early = new /turf/floor/dirt/underground(locate(4,4,1))
	map.ordinal_age = 7
	energy_mining_rolls = list(FALSE,FALSE,FALSE,TRUE)
	early.mining_proc(null)
	energy_ci_check("preModern mining cannot yield uranium", energy_ore_units(locate(4,4,1)), 0)
	map.ordinal_age = 8
	U.forceMove(H)
	U.amount = 3
	P.input = U
	P.mode = "complete"
	node[RNODE_ENTRY_STATUS] = RNODE_AVAILABLE
	P.attackby(U,H)
	energy_ci_check("locked processing cannot debit", U.amount, 3)
	energy_ci_check("locked processing cannot issue cartridge", energy_cartridges(P.loc), 0)
	node[RNODE_ENTRY_STATUS] = RNODE_DONE
	H.craft_skill = 104
	P.attackby(U,H)
	energy_ci_check("under skilled processing cannot debit", U.amount, 3)
	H.craft_skill = 105
	H.forceMove(locate(4,1,2))
	P.attackby(U,H)
	energy_ci_check("other z actor cannot process", U.amount, 3)
	H.forceMove(locate(4,1,1))
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
	var/obj/item/stack/reactor_fuel/paid = locate() in P.loc
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	ref = map_storage.BuildVarDirectory(save,paid,1)
	map_storage.clear_bookkeeping()
	var/obj/item/stack/reactor_fuel/paid_restored = map_storage.Load_Entry(save,ref,null,locate(2,4,1))
	energy_ci_check("paid cartridge native save amount", paid_restored ? paid_restored.amount : -1, 1)
	qdel(paid_restored)
	P.mode = "destroy"
	P.attackby(U,H)
	energy_ci_check("destroyed processor cannot consume", U.amount, 2)
	energy_ci_check("destroyed processor cannot issue output", energy_cartridges(locate(4,1,1)), 1)
	qdel(restored)
	var/obj/structure/reactor_fuel_processor/energy_ci/retirement = new(locate(4,1,1))
	var/obj/item/stack/ore/uranium/retired_input = new(H)
	retired_input.amount = 2
	retirement.input = retired_input
	retirement.mode = "destroy_input"
	retirement.attackby(retired_input,H)
	energy_ci_check("retired input produces nothing", energy_cartridges(locate(4,1,1)), 1)
	var/mob/living/human/energy_ci/fuel_actor/retired_actor = new(locate(4,1,1))
	retired_actor.civilization = H.civilization
	var/obj/item/stack/ore/uranium/actor_input = new(locate(4,1,1))
	actor_input.amount = 2
	retirement.input = actor_input
	retirement.mode = "destroy_actor"
	retirement.attackby(actor_input,retired_actor)
	energy_ci_check("retired actor cannot debit", actor_input.amount, 2)
	energy_ci_check("retired actor produces nothing", energy_cartridges(locate(4,1,1)), 1)
	qdel(actor_input)
	qdel(retirement)
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
	for (var/action in list("complete","cancel","kit","actor","ore","other_z"))
		var/mob/living/human/energy_ci/fuel_actor/extractor = new(locate(4,4,1))
		var/obj/item/stack/ore/uranium/energy_ci/raw = new(locate(4,4,1))
		raw.amount = 2
		raw.mode = action
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/kit = new(locate(4,4,1))
		if (action == "other_z")
			extractor.forceMove(locate(4,4,2))
		raw.attackby(kit,extractor)
		if (action == "complete")
			energy_ci_check("chemical extraction pays one ore unit", raw.amount, 1)
			energy_ci_check("chemical extraction preserves five unit yield", kit.reagents.get_reagent_amount("uranium"), 5)
		else if (action != "ore")
			energy_ci_check("chemical extraction rejects [action]", raw.amount, 2)
		if (raw)
			energy_ci_check("chemical extraction releases [action] lock", raw.uranium_extracting, FALSE)
		qdel(raw)
		qdel(kit)
		qdel(extractor)
	// Explicit local-only recursive propagation and unchanged default caller.
	var/radiation_before = global_radiation
	var/obj/item/energy_rad_receiver/nearby = new(locate(1,1,1))
	var/obj/item/energy_rad_receiver/other_z = new(locate(1,1,2))
	var/obj/item/energy_rad_receiver/boundary = new(locate(4,1,1))
	radiation_pulse(locate(1,1,1),3,7,2,FALSE,TRUE)
	sleep(11)
	energy_ci_check("local recursion never changes global", global_radiation, radiation_before)
	energy_ci_check("local recursion exact two pulses", nearby.pulses, 2)
	energy_ci_check("local pulse excludes other z", other_z.pulses, 0)
	energy_ci_check("radius boundary receives zero dose", boundary.dose, 0)
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
	var/obj/item/stack/ore/uranium/queued = new(shield)
	queued.gc_destroyed = GC_QUEUED_FOR_QUEUING
	sleep(11)
	energy_ci_check("pre garbage queue marker stops chain", queued.uranium_emitting, FALSE)
	sleep(11)
	energy_ci_check("pre garbage queue cannot emit", nearby.pulses, hits)
	queued.gc_destroyed = 0
	qdel(queued)
	radiation_pulse(locate(1,1,1),3,7,1,FALSE)
	energy_ci_check("default pulse retains global behavior", global_radiation > radiation_before, TRUE)
	qdel(shield)
	qdel(H)
