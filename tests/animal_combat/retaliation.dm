// Uses production animal handlers, Weaken and inventory drop. Only the actor's
// strength coefficient and animation are adapted; no normal world startup.
/mob/living/combat_tester/proc/getStatCoeff(statname)
	return 1

/proc/retaliation_reset(mob/living/combat_tester/U, mob/living/simple_animal/A)
	U.stat = CONSCIOUS
	U.status_flags |= CANWEAKEN
	U.mob_size = MOB_MEDIUM
	U.SetWeakened(0)
	U.stunned = 0
	U.prone = FALSE
	U.resting = FALSE
	U.next_animal_retaliation = 0
	A.next_animal_retaliation = 0
	U.forceMove(locate(3,3,1))
	A.forceMove(locate(4,3,1))

/proc/combat_retaliation_checks()
	var/mob/living/combat_tester/U = new(locate(3,3,1))
	var/mob/living/simple_animal/sheep/R = new(locate(4,3,1))
	var/health_before = U.health
	U.a_intent = I_HELP
	R.attack_hand(U)
	combat_assert(!U.weakened && !R.target_mob && !R.next_animal_retaliation, "Peaceful interaction provoked retaliation")
	for (var/intent in list(I_HARM, I_DISARM, I_GRAB))
		retaliation_reset(U, R)
		U.a_intent = intent
		R.attack_hand(U)
		combat_assert(U.weakened == 2 && U.lying && U.health == health_before, "Provocation did not cause bounded zero-damage knockdown: [intent]")
		combat_assert(!R.target_mob && R.stance == HOSTILE_STANCE_IDLE && R.behaviour == "wander", "Retaliation queued pursuit")
		combat_assert(R.next_animal_retaliation == world.time + 100 && U.next_animal_retaliation == world.time + 100, "Wrong retaliation cooldown")
		var/deadline = R.next_animal_retaliation
		U.SetWeakened(0)
		combat_assert(!R.try_defensive_retaliation(U) && !U.weakened && R.next_animal_retaliation == deadline, "Cooldown refreshed or stun-locked attacker")
		if (U.get_active_hand())
			U.drop_from_inventory(U.get_active_hand())

	retaliation_reset(U, R)
	var/obj/item/weapon/material/combat_probe/I = new(U)
	I.material = new /material/combat_wear
	I.force = 1
	I.health = 100
	I.maxhealth = 100
	U.hand = FALSE
	U.r_hand = I
	U.a_intent = I_HARM
	var/ram_health = R.health
	R.attackby(I, U)
	combat_assert(I.attacks == 1 && I.hits == 1 && R.health == ram_health - 1 && I.health == 99, "Retaliation changed incoming damage or wear")
	combat_assert(U.weakened == 2 && !U.get_active_hand() && I.loc == U.loc && U.health == health_before, "Retaliation did not safely disarm with zero damage")

	retaliation_reset(U, R)
	I.nodrop = TRUE
	I.forceMove(U)
	U.r_hand = I
	combat_assert(R.try_defensive_retaliation(U) && U.r_hand == I && I.loc == U, "Retaliation bypassed nodrop")
	I.nodrop = FALSE
	U.drop_from_inventory(I)

	retaliation_reset(U, R)
	var/mob/living/simple_animal/sheep/second_ram = new(locate(4,4,1))
	combat_assert(R.try_defensive_retaliation(U), "First herd shove failed")
	U.SetWeakened(0)
	combat_assert(!second_ram.try_defensive_retaliation(U) && !second_ram.next_animal_retaliation, "Another animal bypassed target cooldown")
	R.next_animal_retaliation = world.time
	combat_assert(!R.try_defensive_retaliation(U), "Animal deadline alone bypassed target cooldown")
	U.next_animal_retaliation = world.time
	combat_assert(R.try_defensive_retaliation(U), "Expired cooldown blocked retaliation")

	retaliation_reset(U, R)
	U.SetWeakened(1)
	combat_assert(!R.try_defensive_retaliation(U) && U.weakened == 1, "Retaliation extended existing knockdown")
	retaliation_reset(U, R)
	U.stunned = 1
	combat_assert(!R.try_defensive_retaliation(U), "Retaliation extended existing stun")
	retaliation_reset(U, R)
	U.stat = DEAD
	combat_assert(!R.try_defensive_retaliation(U), "Retaliation hit a corpse")
	U.stat = UNCONSCIOUS
	combat_assert(!R.try_defensive_retaliation(U), "Retaliation hit unconscious actor")
	retaliation_reset(U, R)
	U.gc_destroyed = TRUE
	combat_assert(!R.try_defensive_retaliation(U), "Retaliation hit retiring actor")
	U.gc_destroyed = FALSE
	retaliation_reset(U, R)
	U.status_flags &= ~CANWEAKEN
	combat_assert(!R.try_defensive_retaliation(U), "Retaliation ignored weaken immunity")
	retaliation_reset(U, R)
	U.forceMove(locate(8,8,1))
	combat_assert(!R.try_defensive_retaliation(U), "Retaliation hit distant actor")
	var/obj/item/container = new(locate(4,3,1))
	U.forceMove(container)
	combat_assert(!R.try_defensive_retaliation(U), "Retaliation hit contained actor")
	retaliation_reset(U, R)
	combat_assert(!R.try_defensive_retaliation(null) && !R.try_defensive_retaliation(R), "Retaliation accepted null or self")
	R.stat = DEAD
	combat_assert(!R.try_defensive_retaliation(U), "Dead animal retaliated")
	R.stat = CONSCIOUS
	R.SetWeakened(1)
	combat_assert(!R.try_defensive_retaliation(U), "Incapacitated animal retaliated")
	R.SetWeakened(0)
	R.lamb = TRUE
	combat_assert(!R.try_defensive_retaliation(U), "Lamb inherited adult retaliation")
	R.lamb = FALSE
	for (var/mode in list("scared", "hunt", "hostile"))
		R.behaviour = mode
		combat_assert(!R.try_defensive_retaliation(U), "Retaliation replaced escape or predator behavior: [mode]")
	R.behaviour = "wander"
	U.mob_size = MOB_LARGE
	combat_assert(!R.try_defensive_retaliation(U), "Larger attacker lost existing retreat priority")
	U.mob_size = MOB_MEDIUM

	for (var/path in list(/mob/living/simple_animal/cattle/cow, /mob/living/simple_animal/cattle/bull, /mob/living/simple_animal/pig_boar, /mob/living/simple_animal/pig_gilt, /mob/living/simple_animal/goat, /mob/living/simple_animal/goat/female, /mob/living/simple_animal/sheep/female, /mob/living/simple_animal/horse, /mob/living/simple_animal/horse/black, /mob/living/simple_animal/camel))
		var/mob/living/simple_animal/A = new path(locate(4,3,1))
		retaliation_reset(U, A)
		combat_assert(A.try_defensive_retaliation(U) && U.weakened == 2 && U.health == health_before && !A.target_mob, "Adult opt-in missing: [path]")
		for (var/juvenile_key in list("calf", "piglet", "lamb"))
			if (juvenile_key in A.vars)
				A.vars[juvenile_key] = TRUE
				retaliation_reset(U, A)
				combat_assert(!A.try_defensive_retaliation(U), "Juvenile opt-out missing: [path]")
				A.vars[juvenile_key] = FALSE

	// Benign item dispatch does not set either cooldown, target, or stance.
	retaliation_reset(U, R)
	I.force = 0
	R.attackby(I, U)
	combat_assert(!U.weakened && !R.next_animal_retaliation && !R.target_mob, "Harmless tap provoked retaliation")
	var/obj/item/stack/medical/combat_medical/M = new(U)
	M.amount = 2
	R.adjustBruteLoss(10)
	R.attackby(M, U)
	combat_assert(!U.weakened && !R.next_animal_retaliation && !R.target_mob, "Healing provoked retaliation")
	var/obj/item/weapon/leash/combat_leash/L = new(U)
	R.attackby(L, U)
	combat_assert(L.S1 == R && !U.weakened && !R.next_animal_retaliation, "Leashing provoked retaliation")
	R.granivore = TRUE
	var/obj/item/stack/farming/seeds/combat_food/F = new(U)
	F.amount = 2
	R.attackby(F, U)
	combat_assert(F.amount == 1 && !U.weakened && !R.next_animal_retaliation && !R.target_mob, "Feeding provoked retaliation")
	R.adjustBruteLoss(-1000)
	I.force = R.maxHealth + 1
	R.attackby(I, U)
	combat_assert(R.stat == DEAD && !U.weakened && !R.next_animal_retaliation, "Fatal item attack provoked retaliation")

	for (var/path in list(/mob/living/simple_animal, /mob/living/simple_animal/deer, /mob/living/simple_animal/rabbit, /mob/living/simple_animal/chicken, /mob/living/simple_animal/boar_boar, /mob/living/simple_animal/boar_gilt, /mob/living/simple_animal/bison, /mob/living/simple_animal/hostile/fox, /mob/living/simple_animal/hostile/wolf, /mob/living/simple_animal/hostile/groundsloth, /mob/living/simple_animal/hostile/human/kenobi))
		var/mob/living/simple_animal/A = new path(locate(4,3,1))
		retaliation_reset(U, A)
		combat_assert(!A.uses_defensive_retaliation() && !A.try_defensive_retaliation(U), "Unrelated species opted in: [path]")
	combat_assert(R.persistence_runtime_var("next_animal_retaliation") && U.persistence_runtime_var("next_animal_retaliation"), "Cooldown could persist across world restart")
	text2file("PASS: adult retaliation provocation, disarm, zero damage, cooldown/herd, target validity, juveniles and unaffected animals", "audit.txt")
