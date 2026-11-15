// Predator temperament, bite pacing and bite fractures, using the production
// AI procs on a real human. No normal world startup or client.

/proc/predator_reset(mob/living/simple_animal/hostile/sabertooth/lion/L, mob/living/human/H, lx, hx)
	L.LoseTarget()
	L.simplehunger = 1000
	L.provoked_by = null
	L.end_food_distraction()
	L.next_melee_attack = 0
	L.stance = HOSTILE_STANCE_IDLE
	L.forceMove(locate(lx, 4, 1))
	H.forceMove(locate(hx, 4, 1))

/proc/predator_bitten_total(mob/living/human/H)
	return H.getBruteLoss() + H.getBurnLoss()

/proc/predator_broken_limbs(mob/living/human/H)
	var/broken = 0
	for (var/obj/item/organ/external/E in H.organs)
		if (E.status & ORGAN_BROKEN)
			broken++
	return broken

/proc/combat_predator_checks()
	// Earlier fixtures leave animals and testers on this small map.
	for (var/mob/living/M in world)
		M.loc = null
	var/mob/living/human/H = new(locate(1, 4, 1))
	H.faction_text = "predator_fixture"
	var/mob/living/simple_animal/hostile/sabertooth/lion/L = new(locate(6, 4, 1))
	L.see_in_dark = 8
	L.idle_vision_range = 7
	L.aggro_vision_range = 7

	// Fed and not crowded: the person is ignored.
	predator_reset(L, H, 6, 1)
	combat_assert(!L.predator_will_hunt(H) && !L.FindTarget(), "Fed predator hunted a distant person")
	// Encroached upon: three tiles or closer.
	predator_reset(L, H, 4, 1)
	combat_assert(L.predator_will_hunt(H) && L.FindTarget() == H, "Predator ignored a person three tiles away")
	// Starving: hunts at any distance it can see.
	predator_reset(L, H, 6, 1)
	L.simplehunger = L.predator_starving_hunger - 1
	combat_assert(L.FindTarget() == H, "Starving predator ignored a person")
	// Other animals are still prey whatever the hunger.
	var/mob/living/simple_animal/deer/D = new(locate(8, 8, 1))
	predator_reset(L, H, 6, 1)
	combat_assert(L.predator_will_hunt(D), "Temperament rule touched animal prey")
	qdel(D)

	// An unprovoked, fed predator gives up a person who backs away...
	predator_reset(L, H, 8, 1)
	L.npc_set_combat_target(H)
	L.stance = HOSTILE_STANCE_ATTACK
	L.AttackTarget()
	combat_assert(!L.target_mob && L.stance == HOSTILE_STANCE_IDLE, "Fed predator kept chasing a retreating person")
	// ...but never the person who hurt it.
	predator_reset(L, H, 8, 1)
	combat_assert(L.animal_provoked(H) && L.target_mob == H && L.provoked_by == H && L.stance == HOSTILE_STANCE_ATTACK, "Hurt predator did not turn on its attacker")
	L.AttackTarget()
	combat_assert(L.target_mob == H, "Predator forgave its attacker")

	// One bite per cooldown, however many callers reach it in one tick.
	predator_reset(L, H, 2, 1)
	L.npc_set_combat_target(H)
	L.stance = HOSTILE_STANCE_ATTACK
	var/before = predator_bitten_total(H)
	L.AttackTarget()
	var/after_first = predator_bitten_total(H)
	L.AttackTarget()
	L.do_behaviour()
	combat_assert(after_first > before && predator_bitten_total(H) == after_first, "Bite pacing allowed more than one bite per cooldown")
	combat_assert(L.next_melee_attack == world.time + 30, "Lion bite cooldown is not three seconds: [L.next_melee_attack - world.time]")
	var/mob/living/simple_animal/hostile/alligator/A = new(locate(8, 1, 1))
	combat_assert(A.melee_attack_cooldown() == 40, "Slow walker cooldown not capped at four seconds")
	qdel(A)

	// A hungry predator in a fight keeps fighting instead of foraging.
	predator_reset(L, H, 2, 1)
	L.npc_set_combat_target(H)
	L.stance = HOSTILE_STANCE_ATTACK
	L.simplehunger = 100
	clients += "predator_fixture"
	before = predator_bitten_total(H)
	L.handle_ai()
	clients -= "predator_fixture"
	combat_assert(predator_bitten_total(H) > before, "Hungry predator foraged instead of biting")

	// Provoked within reach: bites back at once, then waits out its cooldown.
	predator_reset(L, H, 2, 1)
	before = predator_bitten_total(H)
	L.animal_provoked(H)
	combat_assert(predator_bitten_total(H) > before, "Provoked predator did not bite back")
	before = predator_bitten_total(H)
	L.animal_provoked(H)
	combat_assert(predator_bitten_total(H) == before, "Repeated provocation bypassed the bite cooldown")

	// Damage spans the whole range, not only the two ends.
	var/list/seen = list()
	for (var/i = 1, i <= 200, i++)
		seen["[rand(L.melee_damage_lower, L.melee_damage_upper)]"] = TRUE
	combat_assert(seen.len > 2, "Bite damage only picks the extremes")

	// Guarded bites wound without breaking bone; unguarded heavy hits still break.
	// A fresh body, so earlier random bites cannot cap the damage a limb takes.
	H = new(locate(1, 2, 1))
	var/obj/item/organ/external/leg = H.get_organ("l_leg")
	H.bite_fracture_guard = world.time + 1
	H.apply_damage(leg.min_broken_damage + 5, BRUTE, leg, 0, sharp=1, edge=1)
	H.bite_fracture_guard = 0
	combat_assert(!(leg.status & ORGAN_BROKEN), "Fracture guard did not hold")
	var/obj/item/organ/external/arm = H.get_organ("r_arm")
	H.apply_damage(arm.min_broken_damage + 5, BRUTE, arm, 0, sharp=1, edge=1)
	combat_assert(arm.status & ORGAN_BROKEN, "Unguarded heavy hit no longer breaks bone")

	// Four heavy bites with no fracture roll leave every bone whole.
	var/mob/living/human/V = new(locate(1, 6, 1))
	V.faction_text = "predator_fixture"
	var/mob/living/simple_animal/hostile/sabertooth/S = new(locate(2, 6, 1))
	S.bite_fracture_chance = 0
	S.melee_damage_lower = 44
	S.npc_set_combat_target(V)
	for (var/i = 1, i <= 4, i++)
		S.AttackingTarget()
	combat_assert(!predator_broken_limbs(V), "Bites broke bones with a zero fracture chance")
	var/list/zones = list()
	for (var/i = 1, i <= 400, i++)
		var/z = S.animal_bite_zone()
		zones[z] = (zones[z] || 0) + 1
	combat_assert(zones["chest"] > zones["l_foot"] * 3 && zones.len == 11, "Bite zones are not torso-weighted across the body")

	// Thrown meat draws a starving, unhurt predator off the person it is after.
	H = new(locate(1, 4, 1))
	H.faction_text = "predator_fixture"
	predator_reset(L, H, 6, 1)
	L.simplehunger = L.predator_starving_hunger - 1
	L.npc_set_combat_target(H)
	L.stance = HOSTILE_STANCE_ATTACK
	var/obj/item/weapon/reagent_containers/food/snacks/meat/bait = new(locate(8, 4, 1))
	combat_assert(bait.lure_starving_predators(H) == 1 && L.distracted_by == bait && !L.target_mob && L.stance == HOSTILE_STANCE_IDLE, "Thrown meat did not distract a starving predator")
	combat_assert(!L.predator_will_hunt(H) && !L.FindTarget(), "Distracted predator still hunted the thrower")
	L.forceMove(locate(7, 4, 1))
	L.food_distraction_tick()
	combat_assert(QDELETED(bait) && !L.distracted_by && L.simplehunger >= L.predator_starving_hunger, "Distracted predator did not eat the meat")
	combat_assert(!L.predator_will_hunt(H), "Fed predator still hunted a distant person after eating")

	// Hurting it while it goes for the meat ends the distraction.
	predator_reset(L, H, 6, 1)
	L.simplehunger = L.predator_starving_hunger - 1
	L.npc_set_combat_target(H)
	bait = new(locate(8, 4, 1))
	bait.lure_starving_predators(H)
	L.animal_provoked(H)
	combat_assert(!L.distracted_by && L.target_mob == H, "Hurt predator kept going for the meat")
	qdel(bait)

	// An animal you have hurt is not fooled.
	predator_reset(L, H, 6, 1)
	L.simplehunger = L.predator_starving_hunger - 1
	L.animal_provoked(H)
	bait = new(locate(8, 4, 1))
	combat_assert(!bait.lure_starving_predators(H) && L.target_mob == H && !L.distracted_by, "Thrown meat distracted a predator the thrower hurt")
	qdel(bait)

	// A fed predator closing in has no interest, and plant food is no bait.
	predator_reset(L, H, 4, 1)
	L.npc_set_combat_target(H)
	bait = new(locate(8, 4, 1))
	combat_assert(!bait.lure_starving_predators(H) && L.target_mob == H, "Thrown meat distracted a fed predator")
	qdel(bait)
	predator_reset(L, H, 6, 1)
	L.simplehunger = L.predator_starving_hunger - 1
	L.npc_set_combat_target(H)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/W = new(locate(8, 4, 1))
	combat_assert(!W.is_predator_bait() && !W.lure_starving_predators(H) && L.target_mob == H, "Plant food distracted a predator")
	qdel(W)
