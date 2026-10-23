// Exercise the actual click-resolution chain, not just the shared predicate.
/proc/tanning_vessel_regressions(turf/site)
	var/mob/living/harvest_tester/tanning/worker = new(site)
	for (var/path in list(/obj/item/weapon/reagent_containers/glass, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2))
		var/obj/item/weapon/reagent_containers/vessel = new path(worker)
		worker.r_hand = vessel
		vessel.flags |= OPENCONTAINER
		vessel.reagents.clear_reagents()
		var/obj/item/stack/material/hairlesshide/hide = new(site, 2, FALSE)
		vessel.reagents.add_reagent("water", 4)
		harvest_assert(vessel.resolve_attackby(hide, worker), "Insufficient wash did not resolve: [path]")
		harvest_assert(hide.amount == 2 && vessel.reagents.get_reagent_amount("water") == 4, "Insufficient wash spent resources: [path]")
		vessel.reagents.add_reagent("water", 16)
		vessel.reagents.add_reagent("nutriment", vessel.volume - 20)
		vessel.flags &= ~OPENCONTAINER
		harvest_assert(vessel.resolve_attackby(hide, worker), "Closed wash did not resolve: [path]")
		harvest_assert(hide.amount == 2 && vessel.reagents.get_reagent_amount("water") == 20, "Closed vessel spent resources: [path]")
		vessel.flags |= OPENCONTAINER
		harvest_assert(vessel.resolve_attackby(hide, worker), "Open vessel wash did not resolve: [path]")
		harvest_assert(hide.amount == 1 && vessel.reagents.get_reagent_amount("water") == 15 && tanning_amount(site, /obj/item/stack/material/wethide) == 1, "Wash lost exact five-water/one-hide accounting: [path]")
		var/obj/item/stack/bark/bark = new(site, 2, FALSE)
		harvest_assert(vessel.resolve_attackby(bark, worker), "Bark extraction did not resolve: [path]")
		harvest_assert(bark.amount == 1 && vessel.reagents.get_reagent_amount("water") == 5 && vessel.reagents.get_reagent_amount("tannin") == 10, "Bark extraction lost exact accounting: [path]")
		harvest_assert(vessel.reagents.total_volume == vessel.volume - 5 && vessel.reagents.get_reagent_amount("nutriment") == vessel.volume - 20, "Extraction lost unrelated liquid/full-vessel volume: [path]")
		var/obj/item/stack/material/dryhide/dry = new(site, 2, FALSE)
		harvest_assert(vessel.resolve_attackby(dry, worker), "Tanning did not resolve: [path]")
		harvest_assert(dry.amount == 1 && vessel.reagents.get_reagent_amount("tannin") == 5 && vessel.reagents.get_reagent_amount("water") == 5 && tanning_amount(site, /obj/item/stack/material/leather) == 1, "Tanning debited wrong liquid or duplicate pieces: [path]")
		worker.r_hand = null
		qdel(vessel)
		harvest_clear(site)
	// A barrel is not held and does not advertise OPENCONTAINER: its lock controls access.
	var/obj/structure/reagent_dispensers/barrel = new(site)
	var/obj/item/stack/bark/bark = new(worker, 2, FALSE)
	worker.r_hand = bark
	barrel.reagents.add_reagent("water", 20)
	barrel.custom_code = 123
	barrel.locked = TRUE
	harvest_assert(bark.resolve_attackby(barrel, worker), "Locked barrel interaction fell through")
	harvest_assert(bark.amount == 2 && barrel.reagents.get_reagent_amount("water") == 20 && !barrel.reagents.get_reagent_amount("tannin"), "Locked barrel allowed extraction")
	barrel.locked = FALSE
	barrel.forceMove(locate(8,8,1))
	harvest_assert(bark.resolve_attackby(barrel, worker), "Remote barrel interaction fell through")
	harvest_assert(bark.amount == 2 && barrel.reagents.get_reagent_amount("water") == 20, "Remote barrel spent resources")
	barrel.forceMove(site)
	worker.r_hand = null
	bark.resolve_attackby(barrel, worker)
	harvest_assert(bark.amount == 2 && barrel.reagents.get_reagent_amount("water") == 20, "Unheld bark spent barrel liquid")
	worker.r_hand = bark
	harvest_assert(bark.resolve_attackby(barrel, worker), "Accessible barrel interaction failed")
	harvest_assert(bark.amount == 1 && barrel.reagents.get_reagent_amount("water") == 10 && barrel.reagents.get_reagent_amount("tannin") == 10, "Barrel extraction lost accounting")
	var/obj/item/stack/material/hairlesshide/prepared = new(worker, 2, FALSE)
	worker.r_hand = prepared
	harvest_assert(prepared.resolve_attackby(barrel, worker), "Held-hide barrel wash failed")
	harvest_assert(prepared.amount == 1 && barrel.reagents.get_reagent_amount("water") == 5 && tanning_amount(site, /obj/item/stack/material/wethide) == 1, "Barrel wash lost accounting")
	var/obj/item/stack/material/dryhide/dry = new(worker, 2, FALSE)
	worker.r_hand = dry
	harvest_assert(dry.resolve_attackby(barrel, worker), "Held-hide barrel tanning failed")
	harvest_assert(dry.amount == 1 && barrel.reagents.get_reagent_amount("tannin") == 5 && tanning_amount(site, /obj/item/stack/material/leather) == 1, "Barrel tanning lost accounting")
	// Having reagents alone is not an open-container capability.
	var/obj/item/impostor = new(site)
	impostor.create_reagents(40)
	impostor.reagents.add_reagent("tannin", 20)
	dry.resolve_attackby(impostor, worker)
	harvest_assert(dry.amount == 1 && impostor.reagents.get_reagent_amount("tannin") == 20, "Non-container reagent holder accepted")
	// Ordinary open vessels also work in the reverse direction while on the ground.
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/mug = new(site)
	mug.reagents.add_reagent("tannin", 10)
	dry.resolve_attackby(mug, worker)
	harvest_assert(QDELETED(dry) && mug.reagents.get_reagent_amount("tannin") == 5 && tanning_amount(site, /obj/item/stack/material/leather) == 2, "Ground wood mug reverse interaction failed")
	worker.r_hand = prepared
	mug.forceMove(barrel)
	mug.reagents.add_reagent("water", 10)
	prepared.resolve_attackby(mug, worker)
	harvest_assert(prepared.amount == 1 && mug.reagents.get_reagent_amount("water") == 10, "Nested vessel bypassed accessibility")
	qdel(mug)
	qdel(impostor)
	qdel(barrel)
	qdel(bark)
	qdel(prepared)
	qdel(worker)
	harvest_clear(site)
	world.log << "PASS: wood/glass/canteen and stationary vessel click chains, locks, reachability and exact tanning liquid costs"
