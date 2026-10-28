// Real material debit, occupancy admission and inherited bed/structure dispatch.
/proc/recipe_ci_rope_hammock()
	map.ordinal_age = 0
	var/mob/living/human/handle_ci/H = new(locate(2,1,1))
	H.civilization = "recipe_ci"
	var/datum/stack_recipe/R = recipe_ci_food_recipe(/material/rope, /obj/structure/bed/hammock, H.civilization)
	joinery_ci_expect(R && R.req_amount == 6, "six-rope hammock route exists")
	if (!R)
		qdel(H)
		return
	R.time = 0 // Bound wait only; retain production payment/constructor paths.
	var/obj/item/stack/material/rope/stock = new(H, 5, FALSE)
	H.r_hand = stock
	stock.produce_recipe(R, 1, H)
	joinery_ci_expect(stock.amount == 5 && !shelf_ci_count(/obj/structure/bed/hammock), "short rope stock produces no hammock")
	qdel(stock)
	stock = new(H, 12, FALSE)
	H.r_hand = stock
	stock.produce_recipe(R, 1, H)
	var/obj/structure/bed/hammock/B = locate() in locate(2,1,1)
	joinery_ci_expect(B && stock.amount == 6 && B.material && B.material.name == "rope", "hammock construction pays six actual rope units")
	if (B)
		stock.produce_recipe(R, 1, H)
		joinery_ci_expect(stock.amount == 6 && shelf_ci_count(/obj/structure/bed/hammock) == 1, "occupied hammock tile rejects second debit/output")
		B.fire()
		joinery_ci_expect(B.icon_state == "hammockf", "existing unoccupied hammock processing remains usable")
		var/obj/item/weapon/hammer/hammer = new /obj/item/weapon/hammer/tribalhammer(H)
		H.l_hand = hammer
		B.attackby(hammer, H)
		joinery_ci_expect(!QDELETED(B) && !shelf_ci_count(/obj/item/stack/material/wood), "rope hammock cannot produce generic wood refund")
		qdel(hammer)
	qdel(stock)
	shelf_ci_clear()
	qdel(H)
