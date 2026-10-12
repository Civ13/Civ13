/mob/living/human/component_ci/incapacitated(incapacitation_flags)
	return FALSE

/proc/run_workbench_checks(mob/living/human/component_ci/H, turf/T)
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	H.may_do_after = TRUE
	H.l_hand = null
	H.r_hand = null
	var/obj/structure/component_workbench/W = new(T)
	W.assembly_time = 3
	var/obj/item/weapon/material/part/pickaxe/P = new(H, "steel")
	var/obj/item/weapon/material/handle/B = component_handle(H, "hardwood")
	H.r_hand = P
	P.health = P.maxhealth * 0.6
	component_check(W.insert(P,H) && W.insert(B,H), "bench insertion")
	var/obj/item/weapon/material/M = W.assemble(H)
	component_check(M && M.loc == W && !P.loc && !B.loc, "bench exact assembly")
	component_check(M && M.tool_head_material == "steel" && abs(M.health / M.maxhealth - 0.6) < 0.001, "bench preserves native stats")
	component_check(!W.assemble(H), "bench duplicate output")
	component_check(W.retrieve(H) && M.loc == T, "bench output retrieval")
	for (var/scenario in list("cancel", "move", "ingredient", "delete"))
		P = new(H, "iron")
		B = component_handle(H)
		H.r_hand = P
		component_check(W.insert(P,H) && W.insert(B,H), "bench restaging [scenario]")
		W.assembly_time = 5
		var/list/state = list("concurrent" = FALSE)
		spawn(1)
			state["concurrent"] = !W.assemble(H)
			switch (scenario)
				if ("cancel") W.retrieve(H)
				if ("move") H.loc = locate(3,1,1)
				if ("ingredient") P.forceMove(T)
				if ("delete") qdel(W)
		component_check(!W.assemble(H), "bench failed action produced output [scenario]")
		component_check(state["concurrent"], "bench concurrent assembly accepted")
		component_check(P.loc && B.loc, "bench failed action consumed inputs [scenario]")
		H.loc = T
		if (scenario == "delete")
			component_check(P.loc == T && B.loc == T, "bench deletion lost ingredients")
			W = new(T)
		else
			W.retrieve(H)
		qdel(P)
		qdel(B)
	P = new(H, "iron")
	B = component_handle(H)
	H.r_hand = P
	component_check(W.insert(P,H) && W.insert(B,H), "bench save staging")
	W.busy = TRUE
	W.assembler = H
	var/savefile/S = new("workbench-roundtrip.sav")
	S["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(S, W, 1)
	map_storage.clear_bookkeeping()
	var/obj/structure/component_workbench/loaded = map_storage.Load_Entry(S, ref, starting_loc = T)
	component_check(loaded && loaded.contents.len == 2 && !loaded.busy && !loaded.assembler, "bench nested save/runtime reset")
	if (loaded)
		component_check(loaded.find_head() && loaded.find_handle(), "bench restored components")
		loaded.assembly_time = 1
		component_check(loaded.assemble(H), "bench restored assembly")
	qdel(loaded)
	qdel(W)
