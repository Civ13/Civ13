// Piranha swarms (code/game/mob/living/simple_animal/friendly/piranha.dm) on a
// real human: a warning nip first, bites that build, no limb loss until
// sustained exposure in open water, and nobody bitten mid-jump.

/proc/piranha_limbs_left(mob/living/human/H)
	var/left = 0
	for (var/zone in list("l_foot", "r_foot", "l_leg", "r_leg"))
		var/obj/item/organ/external/E = H.get_organ(zone)
		if (E && !E.is_stump())
			left++
	return left

/proc/piranha_next_bite(obj/structure/piranha/P, mob/living/human/H)
	H.piranha_last_bite = world.time - 30
	P.bite(H)

/proc/combat_piranha_checks()
	if (!movementMachine) // footsteps on the river read it
		movementMachine = new
	for (var/mob/living/M in world)
		M.loc = null
	for (var/turf/T in block(locate(1, 1, 1), locate(8, 8, 1)))
		new /turf/floor/beach/water/jungle(T)
	var/turf/bank = locate(8, 8, 1)
	new /turf/floor/plating(bank)
	combat_assert(piranha_open_water(locate(4, 4, 1)), "Mid-river tile is not open water")
	combat_assert(!piranha_open_water(locate(7, 7, 1)), "Tile beside the bank counts as open water")
	combat_assert(!piranha_open_water(locate(1, 4, 1)), "Map-edge tile counts as open water")
	var/list/river = list()
	for (var/turf/T in block(locate(1, 1, 1), locate(8, 8, 1)))
		if (T != bank)
			river += T
	seed_piranhas(river, 6)
	for (var/obj/structure/piranha/S in world)
		combat_assert(piranha_open_water(S.loc), "A swarm was seeded beside the bank")
		qdel(S)

	var/obj/structure/piranha/P = new(locate(4, 4, 1))
	var/mob/living/human/H = new(locate(4, 4, 1))
	H.s_tone = 0
	combat_assert(P.can_bite(H), "Swarm cannot bite a person wading in the river")
	H.throwing = TRUE
	combat_assert(!P.can_bite(H), "Swarm bit a person in mid-jump")
	H.throwing = FALSE
	H.forceMove(bank)
	combat_assert(!P.can_bite(H), "Swarm bit a person on the bank")
	H.forceMove(locate(4, 4, 1))

	var/before = H.getBruteLoss()
	P.bite(H)
	combat_assert(H.piranha_bites == 1 && H.getBruteLoss() - before == 2, "First bite is not a 2 damage warning nip: [H.getBruteLoss() - before]")
	P.bite(H)
	combat_assert(H.piranha_bites == 1, "Two bites inside the three second cooldown")
	before = H.getBruteLoss()
	piranha_next_bite(P, H)
	combat_assert(H.piranha_bites == 2 && H.getBruteLoss() - before == 6, "Second bite is not 6 damage: [H.getBruteLoss() - before]")
	for (var/i = 3, i <= 5, i++)
		piranha_next_bite(P, H)
	combat_assert(piranha_limbs_left(H) == 4, "A limb went within five bites")
	combat_assert(H.persistence_runtime_var("piranha_bites") && P.persistence_runtime_var("feeding"), "Piranha bite state would be saved")

	// A minute out of reach and the next bite is a warning again.
	H.piranha_last_bite = world.time - 600
	before = H.getBruteLoss()
	P.bite(H)
	combat_assert(H.piranha_bites == 1 && H.getBruteLoss() - before == 2, "Exposure did not calm after a minute")

	// Near the bank bites build but never take a limb.
	H.forceMove(locate(7, 7, 1))
	for (var/i = 2, i <= 40, i++)
		H.revive()
		H.piranha_bites = 10
		piranha_next_bite(P, H)
	combat_assert(piranha_limbs_left(H) == 4, "A limb went beside the bank")

	// Sustained exposure in open water can take one.
	H.forceMove(locate(4, 4, 1))
	for (var/i = 1, i <= 60 && piranha_limbs_left(H) == 4, i++)
		piranha_next_bite(P, H)
	combat_assert(piranha_limbs_left(H) < 4, "Sustained exposure in open water never took a limb")
	qdel(P)
	qdel(H)
