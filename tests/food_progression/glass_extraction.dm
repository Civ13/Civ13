// Exercise inherited fixed-dose food branches through both ordinary glass and
// the barrel dispatch. Rejected attempts must retain the actual paid item.
/proc/barrel_food_extraction(turf/site, mob/living/human/H)
	var/list/routes = json_decode(file2text("glass-extraction-routes.json"))
	for (var/list/route in routes)
		var/path = text2path(route["input"])
		for (var/vessel_type in list(/obj/item/weapon/reagent_containers/glass/beaker, /obj/item/weapon/reagent_containers/glass/barrel))
			for (var/change in list("exact", "headroom", "short", "trace short", "full", "closed", "small holder"))
				var/obj/item/weapon/reagent_containers/glass/B = new vessel_type(site)
				var/dose = route["dose"]
				var/free = dose
				if (change == "headroom" || change == "closed") free = B.reagents.maximum_volume
				if (change == "short") free = dose - 1
				if (change == "trace short") free = dose - 0.01
				if (change == "full") free = 0
				if (change == "small holder")
					B.reagents.maximum_volume = dose - 1
					free = dose - 1
				B.reagents.add_reagent("water", B.reagents.maximum_volume - free)
				if (change == "closed") B.flags &= ~OPENCONTAINER
				var/obj/item/weapon/reagent_containers/food/snacks/food = new path(H)
				barrel_check(H.put_in_active_hand(food), "extraction food occupies legal hand")
				var/old_volume = B.reagents.total_volume
				var/old_food_volume = food.reagents.total_volume
				B.attackby(food, H)
				if (change == "exact" || change == "headroom")
					barrel_check(QDELETED(food) && !H.get_active_hand() && B.reagents.get_reagent_amount(route["reagent"]) == dose && B.reagents.total_volume == old_volume + dose, "whole fixed food yield and hand cleanup: [route["reagent"]]/[change]")
				else
					barrel_check(!QDELETED(food) && food.loc == H && H.get_active_hand() == food && food.reagents.total_volume == old_food_volume && B.reagents.total_volume == old_volume && !B.reagents.has_reagent(route["reagent"]), "rejected extraction retains food and recipient: [route["reagent"]]/[change]")
					H.remove_from_mob(food); qdel(food)
				qdel(B)

