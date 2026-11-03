// Production armor bench, inventory transfer, waits, debits and serializer.
/obj/map_metadata/armor_ci
	New()
		return

/mob/living/human/component_ci/u_equip(obj/item/I)
	if (l_hand == I) l_hand = null
	if (r_hand == I) r_hand = null
	return TRUE

/proc/armor_stage(obj/structure/component_workbench/armor/W, mob/living/human/H, path, count = 1)
	var/obj/item/I
	if (ispath(path, /obj/item/stack)) I = new path(H, count, FALSE)
	else I = new path(H)
	H.l_hand = I
	component_check(W.insert(I, H), "armor insertion [path]")
	return I

/proc/run_armor_checks(mob/living/human/component_ci/H, turf/T)
	map = new /obj/map_metadata/armor_ci
	map.ordinal_age = 7
	build_research_tree()
	H.civilization = "armor_ci"
	map.complete_node(H.civilization, "weaving")
	var/obj/structure/component_workbench/armor/W = new(T)
	W.assembly_time = 1
	component_check(!W.recipe_available(H, "Aramid panels"), "armor specialist research bypass")
	map.complete_node(H.civilization, "modern_armor")
	map.ordinal_age = 6
	component_check(!W.recipe_available(H, "Aramid panels"), "armor early era bypass")
	map.ordinal_age = 9
	component_check(!W.recipe_available(H, "Aramid panels"), "armor late era bypass")
	map.ordinal_age = 7
	component_check(W.recipe_available(H, "Aramid panels"), "armor unlocked recipe unavailable")
	var/obj/item/stack/material/cloth/C = armor_stage(W, H, /obj/item/stack/material/cloth, 5)
	var/obj/item/stack/material/leather/L = armor_stage(W, H, /obj/item/stack/material/leather, 3)
	var/obj/item/armor_component/carrier/carrier = W.assemble(H)
	component_check(istype(carrier) && carrier.loc == W && C.amount == 1 && L.amount == 1, "armor carrier exact costs/excess")
	component_check(!W.assemble(H), "armor duplicate carrier")
	W.retrieve(H)
	W.selected_tool = "Aramid panels"
	var/obj/item/stack/material/kevlar/K = armor_stage(W, H, /obj/item/stack/material/kevlar, 14)
	var/obj/item/armor_component/aramid_panels/panels = W.assemble(H)
	component_check(istype(panels) && !K.loc, "armor panels paid fourteen sheets")
	W.retrieve(H)
	W.selected_tool = "Standard aramid vest"
	H.l_hand = carrier
	carrier.forceMove(H)
	component_check(W.insert(carrier, H), "armor existing carrier insertion")
	H.l_hand = panels
	panels.forceMove(H)
	component_check(W.insert(panels, H), "armor existing panels insertion")
	var/obj/item/clothing/accessory/armor/nomads/kevlarblack/vest = W.assemble(H)
	component_check(istype(vest) && vest.loc == W && !carrier.loc && !panels.loc, "armor exact final components consumed")
	component_check(vest && vest.armor["gun"] == 65 && vest.slowdown == 0.4, "armor legacy vest stats")
	W.retrieve(H)
	qdel(vest)
	for (var/scenario in list("cancel", "remove", "amount", "move", "bench_move", "unlock", "era", "epoch", "delete"))
		W.selected_tool = "Armor carrier"
		C = armor_stage(W, H, /obj/item/stack/material/cloth, 4)
		L = armor_stage(W, H, /obj/item/stack/material/leather, 2)
		W.assembly_time = 5
		var/list/state = list()
		spawn(1)
			state["concurrent"] = !W.assemble(H)
			switch (scenario)
				if ("cancel") W.retrieve(H)
				if ("remove") C.forceMove(T)
				if ("amount") C.amount = 5
				if ("move") H.loc = locate(3,1,1)
				if ("bench_move") W.forceMove(locate(2,1,1))
				if ("unlock") H.civilization = "locked_armor_ci"
				if ("era") map.ordinal_age = 9
				if ("epoch") persistence_admission_identity = new /datum
				if ("delete") qdel(W)
		component_check(!W.assemble(H), "armor failed action produced output [scenario]")
		component_check(state["concurrent"], "armor concurrent assembly [scenario]")
		component_check(C.loc && L.loc && C.amount >= 4 && L.amount == 2, "armor failure consumed inputs [scenario]")
		H.loc = T
		H.civilization = "armor_ci"
		map.ordinal_age = 7
		if (scenario == "delete")
			component_check(C.loc == T && L.loc == T, "armor destruction lost stock")
			W = new(T)
		else
			W.forceMove(T)
			W.retrieve(H)
		qdel(C)
		qdel(L)
	W.selected_tool = "Armor carrier"
	var/obj/item/stack/material/cloth/wrong = new(H, 4, FALSE)
	H.l_hand = wrong
	wrong.material = get_material_by_name("kevlar")
	component_check(!W.insert(wrong,H) && wrong.loc == H, "armor material identity bypass")
	qdel(wrong)
	C = armor_stage(W, H, /obj/item/stack/material/cloth, 4)
	L = armor_stage(W, H, /obj/item/stack/material/leather, 2)
	W.busy = TRUE
	W.assembler = H
	var/savefile/S = new("armor-roundtrip.sav")
	S["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(S, W, 1)
	map_storage.clear_bookkeeping()
	var/obj/structure/component_workbench/armor/loaded = map_storage.Load_Entry(S, ref, starting_loc = T)
	if (loaded) loaded.after_load()
	component_check(loaded && loaded.contents.len == 2 && !loaded.busy && !loaded.assembler && loaded.staged_inputs("Armor carrier"), "armor save paid inputs/runtime reset")
	if (loaded)
		loaded.assembly_time = 1
		component_check(loaded.assemble(H), "armor restored inputs assemble")
	qdel(loaded)
	qdel(W)
