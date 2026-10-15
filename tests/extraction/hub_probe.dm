/proc/extraction_hub_probe(obj/map_metadata/extraction_survival/M)
	var/mob/living/human/H = new(locate(3,3,1))
	var/mob/living/human/visitor = new(locate(3,3,1))
	H.m_intent = "stealth"
	visitor.m_intent = "stealth"
	M.test_owners[H] = "hubcrafter"
	M.test_owners[visitor] = "hubvisitor"
	equipment_assert(M.admit(H) && M.admit(visitor), "hub crafting admits separate room owners")
	var/datum/extraction_session/S = H.extraction_session
	var/obj/structure/component_workbench/extraction_private/B = M.house_workbench(S)
	equipment_assert(B && !B.should_save, "private workbench has one account persistence authority")
	H.forceMove(locate(B.x - 1, B.y, B.z))
	visitor.forceMove(get_turf(H))
	H.sleeping = 0
	visitor.sleeping = 0
	equipment_assert(B.can_use(H) && !B.can_use(visitor), "workbench rejects another account even beside its staged contents")
	var/obj/item/weapon/material/part/pickaxe/head = new(get_turf(H), "iron")
	var/obj/item/weapon/material/handle/handle = new(get_turf(H), "wood")
	equipment_assert(H.put_in_hands(head) && B.insert(head, H), "real held production head stages on private workbench")
	equipment_assert(H.put_in_hands(handle) && B.insert(handle, H), "real held production handle stages on private workbench")
	equipment_assert(M.save_home(S) && S.profile["stash"].len == 6, "staged workbench inputs are included in durable private inventory")
	B.busy = TRUE
	B.cancelled = FALSE
	B.assembler = H
	var/obj/item/weapon/material/tool = B.finish_assembly(H, head, handle, "Pickaxe")
	B.busy = FALSE
	B.assembler = null
	equipment_assert(istype(tool, /obj/item/weapon/material/pickaxe) && tool.loc == B && !head.loc && !handle.loc, "production assembly consumes exact staged inputs and retains its finished tool")
	tool.health = min(31, tool.maxhealth)
	var/saved_health = tool.health
	var/saved_head_material = tool.tool_head_material
	var/saved_handle_material = tool.tool_handle_material
	var/id = tool.extraction_item_id
	equipment_assert(M.save_home(S), "assembled staged tool commits before room release")
	id = tool.extraction_item_id
	equipment_assert(S.profile["stash"].len == 5 && M.release(S) && !B.contents.len && !tool.loc, "room release retires staged physical graph without losing its durable tool")
	equipment_assert(M.admit(H), "released account restores assembled tool once")
	S = H.extraction_session
	var/found = 0
	for (var/obj/item/weapon/material/pickaxe/I in M.home_roots(S))
		if (I.extraction_item_id == id && I.health == saved_health && I.tool_head_material == saved_head_material && I.tool_handle_material == saved_handle_material) found++
	equipment_assert(found == 1, "native private reload preserves assembled tool identity, condition and component materials")
	equipment_assert(M.release(S) && M.release(visitor.extraction_session), "hub probe releases only its own accounts")
	// These two disposable actors must not consume the later finite-round
	// fixture's sixteen-participant admission budget.
	M.round_participants -= "hubcrafter"
	M.round_participants -= "hubvisitor"
	qdel(H)
	qdel(visitor)
