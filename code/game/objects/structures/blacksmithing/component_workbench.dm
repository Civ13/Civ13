// Optional staged assembly. Components keep their native acquisition gates.
/obj/structure/component_workbench
	name = "tool assembly workbench"
	desc = "Select a tool, insert its head and a handle, then assemble it. Inputs and finished tools can be retrieved."
	icon = 'icons/obj/structures.dmi'
	icon_state = "workbench"
	density = TRUE
	anchored = TRUE
	not_disassemblable = TRUE
	var/selected_tool = "Pickaxe"
	var/tmp/busy = FALSE
	var/tmp/cancelled = FALSE
	var/tmp/mob/living/human/assembler
	var/tmp/assembly_time = 100

/obj/structure/component_workbench/persistence_runtime_var(key)
	return (key in list("busy", "cancelled", "assembler", "assembly_time")) || ..(key)

/obj/structure/component_workbench/after_load()
	..()
	busy = FALSE
	cancelled = FALSE
	assembler = null
	if (!(selected_tool in tool_recipes())) selected_tool = "Pickaxe"

/obj/structure/component_workbench/proc/tool_recipes()
	return list("Pickaxe" = /obj/item/weapon/material/pickaxe, "Shovel" = /obj/item/weapon/material/shovel, "Hatchet" = /obj/item/weapon/material/hatchet)

/obj/structure/component_workbench/proc/can_use(mob/living/human/H)
	return istype(H) && isturf(loc) && H.Adjacent(src) && !H.incapacitated()

/obj/structure/component_workbench/proc/valid_component(obj/item/weapon/material/I)
	return I && I.loc && I.material && I.health > 0 && I.maxhealth > 0

/obj/structure/component_workbench/proc/find_head()
	for (var/obj/item/weapon/material/part/P in contents)
		if (P.result == tool_recipes()[selected_tool] && P.is_work_tool_head() && valid_component(P)) return P

/obj/structure/component_workbench/proc/find_handle()
	for (var/obj/item/weapon/material/handle/H in contents)
		if (valid_component(H)) return H

/obj/structure/component_workbench/proc/insert(obj/item/weapon/material/I, mob/living/human/H)
	if (busy || !can_use(H) || !valid_component(I) || I.loc != H || (H.l_hand != I && H.r_hand != I) || contents.len >= 2) return FALSE
	if (istype(I, /obj/item/weapon/material/handle))
		if (find_handle()) return FALSE
	else if (istype(I, /obj/item/weapon/material/part))
		var/obj/item/weapon/material/part/P = I
		if (!P.is_work_tool_head() || P.result != tool_recipes()[selected_tool] || find_head()) return FALSE
	else
		return FALSE
	H.drop_from_inventory(I)
	if (I.loc != get_turf(H)) return FALSE
	I.forceMove(src)
	return I.loc == src

/obj/structure/component_workbench/attackby(obj/item/I, mob/living/human/H)
	if (insert(I, H))
		to_chat(H, "You place [I] on [src].")
	else
		to_chat(H, "Select a matching tool and hold one usable head or handle. Retrieve the current items before changing recipes.")

/obj/structure/component_workbench/proc/retrieve(mob/living/human/H)
	if (!can_use(H)) return FALSE
	cancelled = TRUE
	for (var/obj/item/I in contents.Copy()) I.forceMove(get_turf(src))
	return TRUE

// No sleeping operations in this commit. Exact references must still be staged.
/obj/structure/component_workbench/proc/finish_assembly(mob/living/human/H, obj/item/weapon/material/part/P, obj/item/weapon/material/handle/B, choice)
	if (!busy || cancelled || assembler != H || !can_use(H) || selected_tool != choice || !valid_component(P) || !valid_component(B) || P.loc != src || B.loc != src || P.result != tool_recipes()[choice] || !P.is_work_tool_head()) return
	var/obj/item/weapon/material/M = new P.result(get_turf(src), P.material.name)
	M.record_tool_components(P, B)
	qdel(P)
	qdel(B)
	M.forceMove(src)
	return M

/obj/structure/component_workbench/proc/assemble(mob/living/human/H)
	if (busy || !can_use(H)) return
	var/obj/item/weapon/material/part/P = find_head()
	var/obj/item/weapon/material/handle/B = find_handle()
	if (!P || !B || contents.len != 2) return
	var/choice = selected_tool
	busy = TRUE
	cancelled = FALSE
	assembler = H
	var/obj/item/weapon/material/M
	if (do_after(H, assembly_time, src)) M = finish_assembly(H, P, B, choice)
	busy = FALSE
	assembler = null
	if (M) to_chat(H, "You finish [M]. Retrieve it from [src].")
	return M

/obj/structure/component_workbench/attack_hand(mob/living/human/H)
	if (!can_use(H)) return
	var/list/options = list("Status", "Retrieve / cancel")
	if (!busy && !contents.len) options += "Select recipe"
	if (!busy && find_head() && find_handle()) options += "Assemble"
	var/action = input(H, "[selected_tool]: one matching usable head and one usable handle. [busy ? "Assembly in progress" : "Idle"].", name) as null|anything in options
	if (!can_use(H)) return
	switch (action)
		if ("Retrieve / cancel") retrieve(H)
		if ("Assemble") assemble(H)
		if ("Select recipe")
			var/choice = input(H, "Tool recipe", name) as null|anything in tool_recipes()
			if (can_use(H) && !busy && !contents.len && (choice in tool_recipes())) selected_tool = choice
		if ("Status")
			to_chat(H, "[selected_tool] requires one matching head and one handle. Head: [find_head() ? "ready" : "missing"]. Handle: [find_handle() ? "ready" : "missing"]. [contents.len] item(s) stored; retrieve to collect or cancel.")

/obj/structure/component_workbench/Destroy()
	cancelled = TRUE
	assembler = null
	for (var/obj/item/I in contents.Copy()) I.forceMove(get_turf(src))
	return ..()
