// Paid joinery and existing document admission, without a connected client.
/proc/recipe_ci_document_drawers()
	map.ordinal_age = 2
	var/path = /obj/structure/filingcabinet/chestdrawer/wood
	var/datum/stack_recipe/R = recipe_ci_food_recipe(/material/wood/soft, path, "recipe_ci")
	joinery_ci_expect(R && R.req_amount == 6, "document drawer global plank route")
	var/datum/joinery_ci_case/C = new("joinery: wooden document drawers", 4)
	C.craft()
	var/obj/structure/filingcabinet/chestdrawer/wood/D = locate() in locate(2,1,1)
	joinery_ci_expect(D && C.stock.amount == 14 && C.dowels.amount == 9, "drawers pay six planks and one peg set")
	if (D)
		world.log << "Document drawer appearance: color=[D.color]; icon_state=[D.icon_state]"
		joinery_ci_expect(lowertext(D.color) == "#a07449", "wood drawers retain the intended RGB tint: [D.color]")
		joinery_ci_expect(D.icon_state == "chestdrawer", "wood drawers retain the drawer state: [D.icon_state]")
		var/mob/living/human/handle_ci/H = new(locate(2,1,1))
		for (var/item_path in list(/obj/item/weapon/paper, /obj/item/weapon/paper_bundle, /obj/item/weapon/folder))
			var/obj/item/I = new item_path(H)
			joinery_ci_expect(H.put_in_active_hand(I), "document fixture legal hand")
			D.attackby(I, H)
			joinery_ci_expect(I.loc == D && !H.get_active_hand(), "document drawer admission: [item_path]")
		var/obj/item/stack/material/cloth/cloth = new(H, 1, FALSE)
		H.put_in_active_hand(cloth)
		D.attackby(cloth, H)
		joinery_ci_expect(cloth.loc == H && D.contents.len == 3, "drawers remain document-only storage")
		H.drop_item()
		var/obj/item/weapon/hammer/hammer = new /obj/item/weapon/hammer/tribalhammer(H)
		H.put_in_active_hand(hammer)
		D.attackby(hammer, H)
		joinery_ci_expect(!QDELETED(D) && !shelf_ci_count(/obj/item/stack/material/wood), "drawers do not gain a wood refund")
		qdel(H)
	C.clean()
	for (var/change in list("occupied", "tool moved", "research revoked"))
		C = new("joinery: wooden document drawers", 4)
		var/datum/research_node/N
		var/original_tier
		if (change == "research revoked")
			N = get_research_node("fine_furniture")
			original_tier = joinery_ci_research_control(C.actor, N.id, TRUE)
		spawn(1)
			if (change == "occupied") new /obj/structure/filingcabinet/chestdrawer/wood(locate(2,1,1))
			if (change == "tool moved") C.chisel.loc = C.hammer
			if (change == "research revoked")
				var/list/entry = map.get_node_entry(C.actor.civilization, N.id)
				entry[RNODE_ENTRY_STATUS] = RNODE_AVAILABLE
		C.craft()
		if (N) N.era_tier = original_tier
		joinery_ci_expect(C.stock.amount == 20 && C.dowels.amount == 10 && C.actor.joinery_xp == 0 && joinery_ci_outputs(path) == (change == "occupied" ? 1 : 0), "document drawer late rejection: [change]")
		C.clean()
	map.ordinal_age = 0
