// Production tanning methods in the existing isolated harvest fixture.
// Connection/wait adapters are explicit; this is not connected-client evidence.
/mob/living/harvest_tester/tanning
	var/tanning_action = "complete"
	var/obj/item/tanning_tool
	var/tanning_duplicate_result = null

/mob/living/harvest_tester/tanning/hide_worker_connected()
	return tanning_action != "disconnected"

/mob/living/harvest_tester/tanning/drop_from_inventory(obj/item/W, atom/Target = null, ignore_nodrop = FALSE)
	. = ..()
	if (istype(Target, /obj/structure/converter/tanning))
		world.log << "TANNING production drop: result=[.] inside=[W.loc == Target] nodrop=[W.nodrop] special=[W.nodrop_special_check()]"
	return .

/mob/living/harvest_tester/tanning/hide_preparation_wait(atom/target)
	var/obj/item/stack/material/hide = target
	if (tanning_action == "cancel")
		return FALSE
	if (tanning_action == "drop")
		tanning_tool.forceMove(get_turf(src))
		r_hand = null
	if (tanning_action == "deplete")
		hide.amount = 0
	if (tanning_action == "relocate")
		hide.forceMove(locate(7,7,1))
	if (tanning_action == "disconnect")
		tanning_action = "disconnected"
	if (tanning_action == "concurrent")
		tanning_duplicate_result = hide.prepare_hide(src, tanning_tool)
	if (tanning_action == "realwait_move")
		spawn(1)
			forceMove(locate(8,8,1))
		return do_after(src, 3, target, progress = FALSE)
	if (tanning_action == "realwait_complete")
		return do_after(src, 2, target, progress = FALSE)
	return TRUE

/proc/tanning_amount(atom/container, path)
	var/total = 0
	for (var/obj/item/stack/S in container)
		if (istype(S, path) && !QDELETED(S))
			total += S.amount
	return total

/proc/tanning_stack_count(atom/container, path)
	var/count = 0
	for (var/obj/item/stack/S in container)
		if (istype(S, path) && !QDELETED(S))
			count++
	return count

/proc/tanning_pipeline_regression(turf/site)
	var/mob/living/harvest_tester/tanning/worker = new(site)
	var/obj/item/weapon/material/kitchen/utensil/knife/tool = new(worker)
	worker.r_hand = tool
	worker.tanning_tool = tool
	var/obj/item/stack/material/rawhide/raw = new(site, 1, FALSE)
	harvest_assert(raw.prepare_hide(worker, tool), "Pipeline raw hide was not prepared")
	var/obj/item/stack/material/hairlesshide/prepared = locate() in site
	harvest_assert(QDELETED(raw) && prepared && prepared.amount == 1, "Pipeline preparation lost a piece")
	var/obj/item/weapon/reagent_containers/glass/vessel = new(worker)
	worker.r_hand = vessel
	vessel.reagents.add_reagent("water", 15)
	prepared.attackby(vessel, worker)
	var/obj/item/stack/material/wethide/wet = locate() in site
	harvest_assert(QDELETED(prepared) && wet && wet.amount == 1 && vessel.reagents.get_reagent_amount("water") == 10, "Pipeline washing failed")
	var/obj/item/stack/bark/bark = new(site, 1, FALSE)
	bark.attackby(vessel, worker)
	harvest_assert(QDELETED(bark) && vessel.reagents.get_reagent_amount("water") == 0 && vessel.reagents.get_reagent_amount("tannin") == 10, "Pipeline bark extraction failed")
	var/obj/structure/converter/tanning/rack = new(site)
	wet.forceMove(worker)
	worker.l_hand = wet
	world.log << "TANNING rack admission: valid=[hide_worker_can_reach(worker, wet)] held=[worker.item_is_in_hands(wet)] inventory=[wet.loc == worker] turf=[isturf(rack.loc)] adjacent=[worker.Adjacent(rack)] contents=[rack.contents.len] amount=[wet.amount] max=[wet.max_amount] type=[wet.type] rack_deleted=[QDELETED(rack)]"
	rack.attackby(wet, worker)
	world.log << "TANNING rack loaded: inside=[wet.loc == rack] filled=[rack.filled] epoch=[rack.drying_epoch] same_site=[rack.loc == site] deleted=[QDELETED(wet)] amount=[wet.amount]"
	harvest_assert(wet.loc == rack, "Pipeline wet hide was not admitted to rack")
	harvest_assert(rack.finish_hide_drying(wet, 1, rack.drying_epoch, site), "Pipeline admitted hide did not dry")
	rack.attack_hand(worker)
	var/obj/item/stack/material/dryhide/dry = locate() in site
	harvest_assert(dry && dry.amount == 1, "Pipeline dried hide could not be removed")
	dry.attackby(vessel, worker)
	harvest_assert(QDELETED(dry) && tanning_amount(site, /obj/item/stack/material/leather) == 1 && vessel.reagents.get_reagent_amount("tannin") == 5, "Pipeline failed exact one-leather yield")
	harvest_assert(!rack.contents.len && !tanning_amount(site, /obj/item/stack/material/rawhide) && !tanning_amount(site, /obj/item/stack/material/hairlesshide) && !tanning_amount(site, /obj/item/stack/material/wethide) && !tanning_amount(site, /obj/item/stack/material/dryhide), "Pipeline left duplicated intermediate skins")
	qdel(rack)
	qdel(vessel)
	qdel(tool)
	qdel(worker)
	harvest_clear(site)

/proc/tanning_prepare_case(turf/site, action)
	var/mob/living/harvest_tester/tanning/worker = new(site)
	var/obj/item/weapon/material/kitchen/utensil/knife/tool = new(worker)
	worker.r_hand = tool
	worker.tanning_tool = tool
	worker.tanning_action = action
	var/obj/item/stack/material/source
	if (action == "pelt")
		source = new /obj/item/stack/material/pelt/cowpelt(site, 2, FALSE)
	else
		source = new /obj/item/stack/material/rawhide(site, 2, FALSE)
	var/initial_prepared = action == "full" ? 50 : 49
	var/obj/item/stack/material/hairlesshide/existing = new(site, initial_prepared, FALSE)
	var/result = source.prepare_hide(worker, tool)
	var/completed = (action in list("complete", "concurrent", "full", "pelt", "realwait_complete"))
	if (completed)
		harvest_assert(result && source.amount == 1 && !source.preparing_hide, "Preparation did not pay exactly one hide: [action]")
		harvest_assert(tanning_amount(site, /obj/item/stack/material/hairlesshide) == initial_prepared + 1, "Preparation duplicated/lost output on stocked turf: [action]")
		harvest_assert(existing.amount == 50, "Preparation did not respect existing stack capacity: [action]")
		harvest_assert(tanning_stack_count(site, /obj/item/stack/material/hairlesshide) == (action == "full" ? 2 : 1), "Preparation produced wrong number of stacks: [action]")
		if (action == "concurrent")
			harvest_assert(worker.tanning_duplicate_result == FALSE, "Concurrent hide preparation accepted")
	else
		harvest_assert(!result && !source.preparing_hide && tanning_amount(site, /obj/item/stack/material/hairlesshide) == initial_prepared, "Cancelled/invalid preparation produced output: [action]")
		harvest_assert(source.amount == (action == "deplete" ? 0 : 2), "Cancelled preparation consumed a hide: [action]")
	harvest_assert(!tanning_amount(site, /obj/item/stack/material/leather), "Preparation bypassed tanning")
	qdel(source)
	qdel(tool)
	qdel(worker)
	harvest_clear(site)

/proc/tanning_stack_regressions(turf/site)
	for (var/path in list(/obj/item/stack/material/rawhide, /obj/item/stack/material/hairlesshide, /obj/item/stack/material/wethide, /obj/item/stack/material/dryhide))
		var/obj/item/stack/material/source = new path(site, 5, FALSE)
		var/obj/item/stack/material/target = new path(site, 49, FALSE)
		harvest_assert(source.stacktype == path && target.stacktype == path, "Tanning stage has wrong stack identity: [path]")
		source.merge(target)
		harvest_assert(source.amount == 4 && target.amount == 50, "Stage merge exceeded capacity or lost pieces: [path]")
		source.merge(target)
		harvest_assert(source.amount == 4 && target.amount == 50, "Full stage stack accepted extra pieces: [path]")
		var/obj/item/stack/material/part = source.split(2)
		harvest_assert(part && part.type == path && part.amount == 2 && source.amount == 2, "Stage split lost type or pieces: [path]")
		part.transfer_to(source, 1)
		harvest_assert(part.amount == 1 && source.amount == 3 && target.amount == 50, "Stage transfer lost pieces: [path]")
		qdel(part)
		harvest_clear(site)
	var/obj/item/stack/material/rawhide/raw = new(site, 3, FALSE)
	var/obj/item/stack/material/wethide/wet = new(site, 2, FALSE)
	harvest_assert(!raw.transfer_to(wet, 1) && raw.amount == 3 && wet.amount == 2, "Distinct tanning stages merged")
	harvest_clear(site)

/proc/tanning_liquid_regressions(turf/site)
	var/mob/living/harvest_tester/tanning/worker = new(site)
	var/obj/item/weapon/reagent_containers/glass/vessel = new(worker)
	worker.r_hand = vessel
	var/obj/item/stack/material/hairlesshide/prepared = new(site, 2, FALSE)
	vessel.reagents.add_reagent("water", 4)
	prepared.attackby(vessel, worker)
	harvest_assert(prepared.amount == 2 && vessel.reagents.get_reagent_amount("water") == 4 && !tanning_amount(site, /obj/item/stack/material/wethide), "Insufficient wash water consumed or produced hides")
	vessel.reagents.add_reagent("water", 6)
	worker.r_hand = null
	prepared.attackby(vessel, worker)
	harvest_assert(prepared.amount == 2 && vessel.reagents.get_reagent_amount("water") == 10, "Unheld washing vessel consumed resources")
	worker.r_hand = vessel
	vessel.flags &= ~OPENCONTAINER
	prepared.attackby(vessel, worker)
	harvest_assert(prepared.amount == 2 && vessel.reagents.get_reagent_amount("water") == 10, "Closed washing vessel consumed resources")
	vessel.flags |= OPENCONTAINER
	var/obj/item/stack/material/wethide/existing_wet = new(site, 49, FALSE)
	prepared.attackby(vessel, worker)
	harvest_assert(prepared.amount == 1 && existing_wet.amount == 50 && vessel.reagents.get_reagent_amount("water") == 5, "Washing failed one-piece/five-water accounting")
	prepared.attackby(vessel, worker)
	harvest_assert(QDELETED(prepared) && tanning_amount(site, /obj/item/stack/material/wethide) == 51 && vessel.reagents.get_reagent_amount("water") == 0, "Washing a final piece/full output stack lost or duplicated resources")
	harvest_clear(site)
	var/obj/item/stack/bark/bark = new(site, 2, FALSE)
	vessel.reagents.add_reagent("water", 60)
	harvest_assert(vessel.reagents.total_volume == vessel.volume, "Bark full-vessel fixture is not full")
	vessel.flags &= ~OPENCONTAINER
	bark.attackby(vessel, worker)
	harvest_assert(bark.amount == 2 && vessel.reagents.get_reagent_amount("water") == 60 && !vessel.reagents.has_reagent("tannin"), "Closed bark vessel consumed resources")
	vessel.flags |= OPENCONTAINER
	bark.attackby(vessel, worker)
	harvest_assert(bark.amount == 1 && vessel.reagents.get_reagent_amount("water") == 50 && vessel.reagents.get_reagent_amount("tannin") == 10 && vessel.reagents.total_volume == 60, "Bark extraction failed at full vessel capacity")
	vessel.reagents.clear_reagents()
	vessel.reagents.add_reagent("water", 9)
	bark.attackby(vessel, worker)
	harvest_assert(bark.amount == 1 && vessel.reagents.get_reagent_amount("water") == 9 && !vessel.reagents.has_reagent("tannin"), "Insufficient bark water consumed resources")
	vessel.reagents.clear_reagents()
	vessel.reagents.add_reagent("tannin", 15)
	var/obj/item/stack/material/dryhide/dry = new(site, 2, FALSE)
	var/obj/item/stack/material/leather/existing_leather = new(site, 49, FALSE)
	vessel.flags &= ~OPENCONTAINER
	dry.attackby(vessel, worker)
	harvest_assert(dry.amount == 2 && existing_leather.amount == 49 && vessel.reagents.get_reagent_amount("tannin") == 15, "Closed tannin vessel consumed resources")
	vessel.flags |= OPENCONTAINER
	dry.attackby(vessel, worker)
	harvest_assert(dry.amount == 1 && existing_leather.amount == 50 && vessel.reagents.get_reagent_amount("tannin") == 10, "Tanning failed one-piece/five-tannin accounting")
	dry.attackby(vessel, worker)
	harvest_assert(QDELETED(dry) && tanning_amount(site, /obj/item/stack/material/leather) == 51 && tanning_stack_count(site, /obj/item/stack/material/leather) == 2 && vessel.reagents.get_reagent_amount("tannin") == 5, "Final tanning duplicated leather or overfilled an existing stack")
	var/obj/item/stack/material/dryhide/unpaid = new(site, 1, FALSE)
	vessel.reagents.remove_reagent("tannin", 1)
	unpaid.attackby(vessel, worker)
	harvest_assert(unpaid.amount == 1 && vessel.reagents.get_reagent_amount("tannin") == 4 && tanning_amount(site, /obj/item/stack/material/leather) == 51, "Insufficient tannin produced leather")
	qdel(vessel)
	qdel(worker)
	harvest_clear(site)

/proc/tanning_rack_regressions(turf/site)
	var/mob/living/harvest_tester/tanning/worker = new(site)
	var/obj/structure/converter/tanning/rack = new(site)
	var/obj/item/stack/material/lead/lead = new(worker, 2, FALSE)
	worker.l_hand = lead
	rack.attackby(lead, worker)
	harvest_assert(lead.amount == 2 && !rack.contents.len && !rack.filled, "Tanning rack accepted inherited lead input")
	var/obj/item/stack/material/rawhide/raw = new(worker, 2, FALSE)
	worker.l_hand = raw
	rack.attackby(raw, worker)
	harvest_assert(raw.amount == 2 && !rack.contents.len, "Tanning rack accepted unwashed skin")
	qdel(raw)
	qdel(lead)
	var/obj/item/stack/material/wethide/wet = new(worker, 3, FALSE)
	worker.l_hand = wet
	wet.nodrop = TRUE
	rack.attackby(wet, worker)
	harvest_assert(wet.loc == worker && wet.amount == 3 && !rack.contents.len, "Rack bypassed nodrop input")
	wet.nodrop = FALSE
	// Causal control: an ordinary drop into an atom is redirected to its turf.
	harvest_assert(worker.drop_from_inventory(wet, rack) && wet.loc == site && wet.amount == 3 && !rack.contents.len, "MOVED_DROP control no longer reproduces redirected rack entry")
	wet.forceMove(worker)
	worker.l_hand = wet
	rack.attackby(wet, worker)
	harvest_assert(wet.loc == rack && wet.amount == 3 && rack.filled && !worker.item_is_in_hands(wet), "Rack failed to preserve the actual paid stack")
	var/old_epoch = rack.drying_epoch
	rack.attack_hand(worker)
	harvest_assert(wet.loc == site && wet.amount == 3 && !rack.filled && !rack.contents.len, "Cancelling drying consumed a wet hide")
	harvest_assert(!rack.finish_hide_drying(wet, 3, old_epoch, site) && !tanning_amount(site, /obj/item/stack/material/dryhide), "Cancelled drying callback produced hides")
	wet.forceMove(worker)
	worker.l_hand = wet
	rack.attackby(wet, worker)
	harvest_assert(!rack.finish_hide_drying(wet, 3, old_epoch, site), "Stale drying epoch accepted a replacement batch")
	harvest_assert(!rack.finish_hide_drying(wet, 4, rack.drying_epoch, site), "Changed drying count accepted")
	harvest_assert(rack.finish_hide_drying(wet, 3, rack.drying_epoch, site), "Current paid batch failed to dry")
	harvest_assert(QDELETED(wet) && tanning_amount(rack, /obj/item/stack/material/dryhide) == 3 && !rack.filled && !tanning_amount(rack, /obj/item/stack/material/leather), "Rack multiplied output or bypassed tannin")
	harvest_assert(!rack.finish_hide_drying(wet, 3, rack.drying_epoch, site) && tanning_amount(rack, /obj/item/stack/material/dryhide) == 3, "Repeated drying completion duplicated output")
	rack.attack_hand(worker)
	harvest_assert(tanning_amount(site, /obj/item/stack/material/dryhide) == 3 && !rack.contents.len, "Dried batch could not be removed")
	qdel(rack)
	harvest_clear(site)
	var/obj/structure/converter/tanning/destroyed_rack = new(site)
	var/obj/item/stack/material/wethide/released = new(worker, 4, FALSE)
	worker.l_hand = released
	destroyed_rack.attackby(released, worker)
	harvest_assert(released.loc == destroyed_rack, "Destruction fixture did not load input")
	qdel(destroyed_rack)
	harvest_assert(!QDELETED(released) && released.loc == site && released.amount == 4, "Rack destruction lost paid wet contents")
	qdel(worker)
	harvest_clear(site)

/proc/tanning_timer_regressions(turf/site)
	var/mob/living/harvest_tester/tanning/worker = new(site)
	var/obj/structure/converter/tanning/rack = new(site)
	rack.delay = 2
	var/obj/item/stack/material/wethide/wet = new(worker, 2, FALSE)
	worker.l_hand = wet
	rack.attackby(wet, worker)
	sleep(3)
	harvest_assert(QDELETED(wet) && tanning_amount(rack, /obj/item/stack/material/dryhide) == 2, "Production drying callback did not finish paid batch")
	qdel(rack)
	harvest_clear(site)
	var/obj/structure/converter/tanning/cancelled_rack = new(site)
	cancelled_rack.delay = 2
	var/obj/item/stack/material/wethide/cancelled = new(worker, 2, FALSE)
	worker.l_hand = cancelled
	cancelled_rack.attackby(cancelled, worker)
	cancelled_rack.attack_hand(worker)
	sleep(3)
	harvest_assert(cancelled.loc == site && cancelled.amount == 2 && !tanning_amount(site, /obj/item/stack/material/dryhide) && !cancelled_rack.contents.len, "Actual cancelled callback created dried hides")
	qdel(cancelled_rack)
	qdel(worker)
	harvest_clear(site)

/proc/tanning_save_regressions(turf/site)
	for (var/path in list(/obj/item/stack/material/rawhide, /obj/item/stack/material/hairlesshide, /obj/item/stack/material/wethide, /obj/item/stack/material/dryhide, /obj/item/stack/material/leather))
		var/obj/item/stack/material/input = new path(site, 7, FALSE)
		input.preparing_hide = TRUE
		var/list/keys = input.get_saved_vars()
		harvest_assert(!("preparing_hide" in keys), "Stage save retained a preparation lock: [path]")
		var/stage_name = input.default_type
		var/savefile/stage_file = new("tanning-stage-[stage_name].sav")
		stage_file["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/stage_id = map_storage.BuildVarDirectory(stage_file, input)
		harvest_assert(stage_id, "Tanning stage excluded from save: [path]")
		qdel(input)
		map_storage.clear_bookkeeping()
		var/obj/item/stack/material/restored = map_storage.Load_Entry(stage_file, stage_id, starting_loc = site)
		harvest_assert(restored && restored.type == path && restored.amount == 7 && !restored.preparing_hide && restored.material && restored.material.name == stage_name, "Tanning stage round trip lost type/material/count or retained lock: [path]")
		map_storage.clear_bookkeeping()
		harvest_clear(site)
	var/obj/structure/converter/tanning/rack = new(site)
	var/obj/item/stack/material/wethide/wet = new(rack, 4, FALSE)
	rack.start_hide_drying(wet)
	var/list/rack_keys = rack.get_saved_vars()
	harvest_assert(!("filled" in rack_keys) && !("drying_epoch" in rack_keys), "Rack persisted runtime callback ownership")
	var/savefile/rack_file = new("tanning-paid-rack.sav")
	rack_file["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/rack_id = map_storage.BuildVarDirectory(rack_file, rack, 1)
	harvest_assert(rack_id, "Paid tanning rack excluded from save")
	// Simulate historical runtime fields. Import must ignore both.
	var/rack_path = map_storage.entry_path(rack_file, rack_id)
	rack_file["[rack_path]/filled"] << list("kind" = "value", "value" = TRUE)
	rack_file["[rack_path]/drying_epoch"] << list("kind" = "value", "value" = 9876)
	qdel(rack)
	qdel(wet)
	map_storage.clear_bookkeeping()
	var/obj/structure/converter/tanning/restored_rack = map_storage.Load_Entry(rack_file, rack_id, starting_loc = site)
	harvest_assert(restored_rack && !restored_rack.filled && restored_rack.drying_epoch == 0 && tanning_amount(restored_rack, /obj/item/stack/material/wethide) == 4, "Rack round trip lost paid contents or restored stale callback ownership")
	restored_rack.after_load()
	var/obj/item/stack/material/wethide/restored_wet = locate() in restored_rack
	harvest_assert(restored_rack.filled && restored_rack.drying_epoch == 1 && restored_wet.amount == 4, "Restored wet contents failed to restart drying")
	harvest_assert(restored_rack.finish_hide_drying(restored_wet, 4, restored_rack.drying_epoch, site) && tanning_amount(restored_rack, /obj/item/stack/material/dryhide) == 4, "Restored paid rack did not preserve one-to-one yield")
	map_storage.clear_bookkeeping()
	qdel(restored_rack)
	harvest_clear(site)

/proc/tanning_turkey_regressions(turf/site)
	for (var/path in list(/mob/living/simple_animal/turkey_f, /mob/living/simple_animal/turkey_m, /mob/living/simple_animal/turkeychick))
		for (var/skin in list(FALSE, TRUE))
			var/mob/living/simple_animal/bird = new path(site)
			var/expected = path == /mob/living/simple_animal/turkeychick ? 0 : 1
			harvest_assert(!bird.harvest_mammal() && bird.harvest_skin_yield() == expected, "Turkey skin eligibility changed anatomy or chick policy: [path]")
			bird.harvest_products(site, skin)
			harvest_assert(tanning_amount(site, /obj/item/stack/material/rawhide) == expected && !tanning_amount(site, /obj/item/stack/material/leather), "Turkey harvest skin yield/bypass: [path], skin=[skin]")
			harvest_assert(!harvest_count(site, /obj/item/stack/sinew) && !harvest_count(site, /obj/item/stack/material/bone) && !harvest_count(site, /obj/item/weapon/reagent_containers/food/snacks/meat/offal) && !harvest_count(site, /obj/item/weapon/reagent_containers/food/snacks/animalfat), "Turkey gained mammalian byproducts: [path]")
			var/meat_count = 0
			for (var/obj/item/weapon/reagent_containers/food/snacks/meat/meat in site)
				if (!istype(meat, /obj/item/weapon/reagent_containers/food/snacks/meat/offal))
					meat_count++
			harvest_assert(meat_count == bird.butcher_yield(), "Turkey skin change altered meat yield: [path]")
			qdel(bird)
			harvest_clear(site)

/proc/harvest_tanning_regressions(turf/site)
	initialize_chemical_reagents()
	tanning_pipeline_regression(site)
	for (var/action in list("cancel", "drop", "deplete", "relocate", "disconnect", "concurrent", "complete", "full", "pelt", "realwait_move", "realwait_complete"))
		tanning_prepare_case(site, action)
	tanning_stack_regressions(site)
	tanning_liquid_regressions(site)
	tanning_vessel_regressions(site)
	tanning_rack_regressions(site)
	tanning_rack_transfer_regressions(site)
	tanning_recipe_regressions()
	tanning_timer_regressions(site)
	tanning_save_regressions(site)
	tanning_turkey_regressions(site)
	world.log << "PASS: tanning preparation/washing/tannin, bounded stack accounting, rack cancellation/epochs/destruction/save recovery, turkey anatomy and yields"

#include "vessel_probe.dm"
#include "rack_transfer_probe.dm"
#include "hide_recipe_probe.dm"
