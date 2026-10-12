// Real material constructors, assembly, force calculation and persistence.
// Only player initialization/inventory effects are isolated from game startup.
/world
	hub = ""
	hub_password = ""
	maxx = 3
	maxy = 1
	maxz = 1
	turf = /turf
	area = /area

/mob/living/human/component_ci
	New()
		return
	update_icons()
		return
	drop_from_inventory(obj/item/I, atom/target = null)
		if (l_hand == I)
			l_hand = null
		if (r_hand == I)
			r_hand = null
		I.loc = loc
		return TRUE

var/list/component_errors = list()
/proc/component_check(condition, message)
	if (!condition)
		component_errors += message

/proc/component_handle(mob/living/human/H, material_name = "wood")
	var/obj/item/weapon/material/handle/B = new(H, material_name)
	H.l_hand = B
	return B

/proc/run_component_checks()
	populate_material_list()
	var/turf/T = locate(1,1,1)
	var/mob/living/human/component_ci/H = new(T)
	for (var/head_type in list(/obj/item/weapon/material/part/pickaxe, /obj/item/weapon/material/part/shovel, /obj/item/weapon/material/part/axehead/hatchet))
		var/obj/item/weapon/material/part/A = new head_type(T, "iron")
		var/obj/item/weapon/material/handle/B = component_handle(H)
		var/obj/item/weapon/material/M = A.assemble_work_tool(B, H)
		component_check(M && M.type == A.result, "wrong family output [head_type]")
		component_check(!A.loc && !B.loc && !H.l_hand, "ingredients not consumed [head_type]")
		component_check(!A.assemble_work_tool(B, H), "duplicate output [head_type]")
		component_check(M.tool_head_material == "iron" && M.tool_handle_material == "wood", "missing provenance")
		component_check(M.health == M.maxhealth && M.crafting_quality == 1, "normal condition/quality changed")
		qdel(M)
	var/obj/item/weapon/material/part/pickaxe/A = new(T, "steel")
	var/obj/item/weapon/material/handle/B = component_handle(H, "hardwood")
	A.crafting_quality = 1.8
	B.crafting_quality = 0.8
	A.health = A.maxhealth * 0.6
	B.health = B.maxhealth * 0.4
	var/obj/item/weapon/material/pickaxe/M = A.assemble_work_tool(B, H)
	component_check(M.crafting_quality == 0.8 && M.tool_head_quality == 1.8, "quality was erased/upgraded")
	component_check(abs(M.health / M.maxhealth - 0.4) < 0.001, "worn inputs restored")
	component_check(M.usespeed > 2 && M.usespeed <= 3, "steel/light handle speed")
	component_check(M.maxhealth == round(35 * 1.5), "handle capacity clamp")
	component_check(M.force == round(M.material.get_edge_damage() * M.force_divisor) * 0.8, "native force rule changed")
	var/savefile/S = new("component-roundtrip.sav")
	S["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(S, M, 0)
	component_check(ref > 0, "serializer rejected tool")
	map_storage.clear_bookkeeping()
	var/obj/item/weapon/material/pickaxe/loaded = map_storage.Load_Entry(S, ref, starting_loc = T)
	component_check(loaded && loaded != M, "load failed")
	if (loaded)
		component_check(loaded.tool_head_material == "steel" && loaded.tool_handle_material == "hardwood", "provenance lost on load")
		component_check(loaded.health == M.health && loaded.maxhealth == M.maxhealth && loaded.usespeed == M.usespeed && loaded.force == M.force, "stats/wear lost on load")
		component_check(loaded.tool_head_quality == 1.8 && loaded.tool_handle_quality == 0.8, "quality lost on load")
	qdel(loaded)
	qdel(M)
	for (var/rejection in list("remote", "container", "unheld", "broken", "deleted"))
		A = new(T, "iron")
		B = component_handle(H)
		switch (rejection)
			if ("remote")
				A.loc = locate(3,1,1)
			if ("container")
				A.loc = new /obj(T)
			if ("unheld")
				H.l_hand = null
			if ("broken")
				B.health = 0
			if ("deleted")
				qdel(A)
		component_check(!A.assemble_work_tool(B, H), "accepted [rejection]")
		component_check(B.loc == H, "failed assembly consumed handle [rejection]")
		if (rejection != "deleted")
			component_check(A.loc, "failed assembly consumed head [rejection]")
		qdel(A)
		qdel(B)
	A = new(T, "indestructable")
	B = component_handle(H, "lead")
	A.crafting_quality = 1000
	B.crafting_quality = -1
	M = A.assemble_work_tool(B, H)
	component_check(M.usespeed >= 1 && M.usespeed <= 3 && M.crafting_quality == 0.5, "extreme stat bounds")
	var/obj/item/weapon/material/pickaxe/legacy = new(T, "iron")
	component_check(!legacy.tool_head_material && legacy.usespeed == 2 && legacy.maxhealth == 25, "legacy behavior changed")
	component_check(get_material_by_name("wood").integrity == 39 && get_material_by_name("steel").hardness == 60, "shared material mutation")
	// Exercise the actual item interaction entry point, not only its helper.
	A = new(T, "iron")
	B = component_handle(H, "woodplank")
	A.attackby(B, H)
	var/obj/item/weapon/material/pickaxe/interaction
	for (var/obj/item/weapon/material/pickaxe/P in T)
		if (P.tool_handle_material == "woodplank")
			interaction = P
	component_check(interaction && interaction.usespeed == 2.5 && !B.loc && !A.loc, "attackby did not assemble plank-handled tool")
	A = new(T, "iron")
	B = component_handle(H, "iron")
	var/obj/item/weapon/material/pickaxe/heavy = A.assemble_work_tool(B, H)
	component_check(heavy.usespeed < 2 && heavy.maxhealth == round(25 * 1.5), "reinforced handle tradeoff missing")
	run_workbench_checks(H, T)
	var/report = "Production assembly, rejection, bounds, condition, provenance and native save/load checks\n"
	for (var/error in component_errors)
		report += "FAIL: [error]\n"
	report += component_errors.len ? "FAIL\n" : "PASS\n"
	text2file(report, "component-checks.txt")
	del(world)

#include "workbench.dm"
