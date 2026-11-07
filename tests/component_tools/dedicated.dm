// Dedicated benches: one-step retargeting, weapon assembly and batch fletching.
/proc/run_dedicated_checks(mob/living/human/component_ci/H, turf/T)
	H.may_do_after = TRUE
	H.l_hand = null
	H.r_hand = null
	// Retargeting a loaded tool bench returns the stored items and switches.
	var/obj/structure/component_workbench/W = new(T)
	var/obj/item/weapon/material/part/pickaxe/P = new(H, "iron")
	H.r_hand = P
	component_check(W.insert(P, H), "retarget staging")
	component_check(W.select_recipe(H, "Shovel") && W.selected_tool == "Shovel" && P.loc == T && !W.contents.len, "retarget returns stored items")
	component_check(!W.select_recipe(H, "Sword") && W.selected_tool == "Shovel", "retarget unknown recipe")
	W.busy = TRUE
	component_check(!W.select_recipe(H, "Hatchet") && W.selected_tool == "Shovel", "retarget while busy")
	W.busy = FALSE
	qdel(P)
	qdel(W)

	// Weapon bench: anvil weapon heads only, material and condition kept.
	var/obj/structure/component_workbench/weapon/WB = new(T)
	WB.assembly_time = 1
	var/obj/item/weapon/material/part/axehead/hatchet/hatchet_head = new(H, "iron")
	H.r_hand = hatchet_head
	component_check(!WB.insert(hatchet_head, H), "weapon bench accepted a tool head")
	H.r_hand = null
	qdel(hatchet_head)
	var/obj/item/weapon/material/part/spearhead/S = new(H, "bronze")
	S.health = S.maxhealth * 0.5
	H.r_hand = S
	var/obj/item/weapon/material/handle/B = component_handle(H)
	component_check(WB.insert(S, H) && WB.insert(B, H), "weapon bench staging")
	var/obj/item/weapon/material/spear/spear = WB.assemble(H)
	component_check(istype(spear) && spear.loc == WB && !S.loc && !B.loc, "weapon bench exact assembly")
	component_check(spear && spear.tool_head_material == "bronze" && abs(spear.health / spear.maxhealth - 0.5) < 0.001, "weapon bench keeps head stats")
	component_check(WB.select_recipe(H, "Battle axe") && spear && spear.loc == T, "weapon bench retarget returns output")
	var/obj/item/weapon/material/part/axehead/battleaxe/BA = new(H, "iron")
	H.r_hand = BA
	B = component_handle(H)
	component_check(WB.insert(BA, H) && WB.insert(B, H) && istype(WB.assemble(H), /obj/item/weapon/material/hatchet/battleaxe), "weapon bench battle axe")
	qdel(spear)
	qdel(WB)

	// Fletcher's bench: every shaft with a head is fitted in one action.
	var/obj/structure/component_workbench/fletching/F = new(T)
	F.assembly_time = 1
	var/list/shafts = list()
	for (var/i in 1 to 3)
		shafts += new /obj/item/ammo_casing/arrow(T)
	var/obj/item/ammo_casing/bolt/stray_bolt = new(T)
	component_check(F.load_from_floor(H) == 3 && stray_bolt.loc == T, "fletching floor load")
	var/obj/item/stack/arrowhead/iron/heads = new(H, 5, FALSE)
	H.r_hand = heads
	component_check(F.insert(heads, H), "fletching head staging")
	var/obj/item/stack/arrowhead/stone/other = new(H, 2, FALSE)
	H.r_hand = other
	component_check(!F.insert(other, H), "fletching mixed head kinds")
	H.r_hand = null
	component_check(F.ready_count() == 3, "fletching ready count")
	component_check(F.assemble(H) == 3, "fletching batch")
	var/made = 0
	for (var/obj/item/ammo_casing/arrow/iron/A in T)
		made++
	component_check(made == 3 && heads.amount == 2 && !F.stored_shafts().len, "fletching exact costs")
	for (var/obj/item/ammo_casing/arrow/shaft in shafts)
		component_check(QDELETED(shaft) || !shaft.loc, "fletching shaft not consumed")
	component_check(!F.assemble(H), "fletching without shafts")
	// Cancellation keeps inputs.
	new /obj/item/ammo_casing/arrow(T)
	F.load_from_floor(H)
	F.assembly_time = 5
	spawn(1)
		F.retrieve(H)
	component_check(!F.assemble(H) && heads.loc == T, "fletching cancellation consumed inputs")
	// Bolts and sharpened flint.
	F.assembly_time = 1
	component_check(F.select_recipe(H, "Crossbow bolts"), "fletching retarget")
	component_check(F.load_from_floor(H) == 1, "fletching bolt load")
	var/obj/item/weapon/flint/sharpened/flint = new(H)
	H.r_hand = flint
	component_check(F.insert(flint, H) && F.assemble(H) == 1 && QDELETED(flint), "fletching flint bolt")
	var/found = FALSE
	for (var/obj/item/ammo_casing/bolt/flint/FB in T)
		found = TRUE
	component_check(found, "fletching flint bolt output")
	H.r_hand = null
	qdel(other)
	qdel(F)
