// Production crafting, rolling and storage; existing inert human adapters.
/proc/bedroll_ci_expect(condition, label)
	if (!condition)
		recipe_ci_fail("portable bedding", label)

/proc/recipe_ci_cloth_bedroll()
	map.ordinal_age = 0
	var/mob/living/human/handle_ci/H = new(locate(2,1,1))
	H.civilization = "recipe_ci"
	for (var/rolled_path in list(/obj/item/weapon/bedroll, /obj/item/weapon/bedroll/cloth))
		var/cloth = rolled_path == /obj/item/weapon/bedroll/cloth
		var/material_path = cloth ? /material/cloth : /material/leather
		var/stock_path = cloth ? /obj/item/stack/material/cloth : /obj/item/stack/material/leather
		var/unrolled_path = cloth ? /obj/structure/bed/bedroll/cloth : /obj/structure/bed/bedroll
		var/datum/stack_recipe/R = recipe_ci_food_recipe(material_path, rolled_path, H.civilization)
		bedroll_ci_expect(R && R.req_amount == 4, "four-unit route exists: [rolled_path]")
		if (!R)
			continue
		R.time = 0 // Bound delay only; keep constructor and debit production paths.
		var/obj/item/stack/stock = new stock_path(H, 12, FALSE)
		H.r_hand = stock
		var/obj/item/weapon/flint/held = new(H)
		H.l_hand = held // Leave the crafted item on the clear fixture floor.
		stock.produce_recipe(R, 1, H)
		var/obj/item/weapon/bedroll/rolled = locate(rolled_path) in locate(2,1,1)
		bedroll_ci_expect(rolled && stock.amount == 8, "construction pays four units: [rolled_path]")
		if (!rolled)
			qdel(stock)
			qdel(held)
			continue
		for (var/i = 1, i <= 3, i++)
			rolled.attack_self(H)
			var/obj/structure/bed/bedroll/B = locate() in locate(2,1,1)
			bedroll_ci_expect(QDELETED(rolled) && B && B.type == unrolled_path, "unrolling preserves bedding type: [rolled_path]")
			if (!B)
				break
			B.used = TRUE
			bedroll_ci_expect(!B.fold_up(H) && !QDELETED(B) && !shelf_ci_count(rolled_path), "used bedding cannot fold: [rolled_path]")
			B.used = FALSE
			var/obj/item/weapon/hammer/hammer = new /obj/item/weapon/hammer/tribalhammer(H)
			B.attackby(hammer, H)
			bedroll_ci_expect(!QDELETED(B) && !shelf_ci_count(/obj/item/stack/material/wood), "textile bedding cannot produce a wood refund: [rolled_path]")
			qdel(hammer)
			rolled = B.fold_up(H)
			bedroll_ci_expect(QDELETED(B) && rolled && rolled.type == rolled_path && shelf_ci_count(rolled_path) == 1, "folding preserves exactly one original type: [rolled_path]")
		var/obj/item/weapon/storage/backpack/bag = new(locate(2,1,1))
		bedroll_ci_expect(bag.can_be_inserted(rolled, TRUE) && bag.handle_item_insertion(rolled, TRUE) && rolled.loc == bag, "normal backpack admits original instance: [rolled_path]")
		bedroll_ci_expect(bag.remove_from_storage(rolled, locate(2,1,1)) && rolled.type == rolled_path && shelf_ci_count(rolled_path) == 1, "backpack removal preserves type without conversion: [rolled_path]")
		qdel(bag)
		qdel(stock)
		qdel(held)
		shelf_ci_clear()
	qdel(H)
