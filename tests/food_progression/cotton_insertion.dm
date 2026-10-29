// New executable coverage selects the existing food suite under ordinary PRs.
/obj/item/stack/material/cotton/cotton_fixture
	amount = 25
	var/fail_payment = FALSE
/obj/item/stack/material/cotton/cotton_fixture/use(used)
	if (fail_payment)
		return FALSE
	return ..()

/proc/barrel_cotton_insertion(turf/site, mob/living/human/H)
	for (var/vessel_type in list(/obj/item/weapon/reagent_containers/glass/beaker, /obj/item/weapon/reagent_containers/glass/barrel))
		for (var/change in list("one", "preset", "headroom", "short", "trace short", "full", "closed", "small holder", "zero", "fraction", "negative", "material", "payment"))
			var/obj/item/weapon/reagent_containers/glass/B = new vessel_type(site)
			var/obj/item/stack/material/cotton/cotton_fixture/CT = new(H)
			if (change == "one") CT.amount = 1
			if (change == "zero") CT.amount = 0
			if (change == "fraction") CT.amount = 1.5
			if (change == "negative") CT.amount = -1
			if (change == "material") CT.material = get_material_by_name("steel")
			if (change == "payment") CT.fail_payment = TRUE
			var/free = max(1, CT.amount)
			if (change == "headroom" || change == "closed") free = B.reagents.maximum_volume
			if (change == "short") free = 24
			if (change == "trace short") free = 24.99
			if (change == "full") free = 0
			if (change == "small holder")
				B.reagents.maximum_volume = 10
				free = 10
			B.reagents.add_reagent("water", B.reagents.maximum_volume - free)
			if (change == "closed") B.flags &= ~OPENCONTAINER
			barrel_check(H.put_in_active_hand(CT), "cotton occupies a legal hand")
			var/paid = CT.amount
			var/before = B.reagents.total_volume
			B.attackby(CT, H)
			if (change == "one" || change == "preset" || change == "headroom")
				barrel_check(QDELETED(CT) && !H.get_active_hand() && B.reagents.get_reagent_amount("cotton") == paid && B.reagents.total_volume == before + paid, "whole actual cotton pile paid once with final-hand cleanup: [change]")
			else
				barrel_check(!QDELETED(CT) && CT.amount == paid && H.get_active_hand() == CT && B.reagents.total_volume == before && !B.reagents.has_reagent("cotton"), "cotton refusal retains stock and recipient: [change]")
				H.remove_from_mob(CT); qdel(CT)
			qdel(B)
