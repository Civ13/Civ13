/world
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating

/mob/living/combat_tester/New()
	return
/mob/living/combat_tester/do_attack_animation(atom/A)
	return

/obj/map_metadata/combat_fixture/New()
	map = src

/obj/item/weapon/material/combat_probe
	force = 10
	no_attack_log = TRUE
	var/attacks = 0
	var/hits = 0
/material/combat_wear
	hardness = 0
/material/combat_wear/is_brittle()
	return FALSE

/obj/item/weapon/material/combat_probe/attack(mob/living/M, mob/living/user, target_zone)
	attacks++
	return ..()
/obj/item/weapon/material/combat_probe/apply_hit_effect(mob/living/target, mob/living/user, hit_zone)
	hits++
	return ..()

/obj/item/stack/farming/seeds/combat_food
	force = 10
/obj/item/stack/farming/seeds/combat_food/attack()
	throw EXCEPTION("Feeding dispatched combat")
/obj/item/stack/medical/combat_medical
	heal_brute = 5
	force = 10
/obj/item/stack/medical/combat_medical/attack()
	throw EXCEPTION("Healing dispatched combat")
/obj/item/weapon/leash/combat_leash
	force = 10
/obj/item/weapon/leash/combat_leash/attack()
	throw EXCEPTION("Leashing dispatched combat")

/proc/combat_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/world/OpenPort(port)
	if (port == "none")
		return ..(port)
	return FALSE

/world/New()
	OpenPort("none")
	sleep(1)
	try
		new /obj/map_metadata/combat_fixture
		var/mismatches = 0
		for (var/path in typesof(/mob/living/simple_animal))
			var/mob/living/simple_animal/A = path
			if (initial(A.health) != initial(A.maxHealth))
				text2file("[path]: [initial(A.health)]/[initial(A.maxHealth)]", "audit.txt")
				mismatches++
				combat_assert(path == /mob/living/simple_animal/hostile/human/voyage/pirate/friendly/blindman, "Unexpected compiled health mismatch: [path]")
		var/turf/site = locate(3,3,1)
		var/mob/living/combat_tester/U = new(site)
		U.a_intent = I_HARM
		var/obj/item/weapon/material/combat_probe/I = new(U)
		I.material = new /material/combat_wear
		I.force = 10
		I.health = 100
		I.maxhealth = 100
		for (var/path in list(/mob/living/simple_animal/pig_gilt, /mob/living/simple_animal/camel, /mob/living/simple_animal/hostile/human/kenobi))
			var/mob/living/simple_animal/A = new path(site)
			var/start_health = A.health
			combat_assert(A.maxHealth == start_health, "Health cap mismatch: [path]")
			A.stop_automated_movement = TRUE
			A.Life()
			combat_assert(A.health == start_health, "Life lowered health: [path]")
			for (var/mode in list("wander", "defends", "hunt", "hostile", "scared"))
				for (var/sharpness in list(FALSE, TRUE))
					A.behaviour = mode
					I.sharp = sharpness
					I.attacks = 0
					I.hits = 0
					A.adjustBruteLoss(-10000)
					var/wear_before = I.health
					A.attackby(I, U)
					combat_assert(I.attacks == 1 && I.hits == 1, "Duplicate click: [path] [mode] [sharpness], [I.attacks]/[I.hits]")
					combat_assert(I.health == wear_before - 1, "Duplicate tool wear: [path]")
					combat_assert(A.health == start_health - I.force, "Wrong damage: [path] [A.health]")
			A.adjustBruteLoss(-10000)
			combat_assert(A.health == start_health, "Healing exceeds cap: [path]")
			A.adjustBruteLoss(start_health)
			combat_assert(A.health <= 0 && A.stat == DEAD, "Death missing: [path]")
		var/mob/living/simple_animal/A = new(site)
		A.granivore = TRUE
		A.simplehunger = 100
		A.adjustBruteLoss(10)
		var/obj/item/stack/farming/seeds/combat_food/F = new(U)
		F.amount = 2
		A.attackby(F, U)
		combat_assert(F.amount == 1 && A.health == 14, "Feeding lost healing or consumed wrong amount")
		var/obj/item/stack/medical/combat_medical/M = new(U)
		M.amount = 2
		combat_assert(A.attackby(M, U) && M.amount == 1 && A.health == 19, "Medical action lost healing/return/consumption")
		A.adjustBruteLoss(-100)
		A.attackby(M, U)
		combat_assert(M.amount == 1 && A.health == 20, "Full health consumed medical stack")
		var/obj/item/weapon/leash/combat_leash/L = new(U)
		A.behaviour = "wander"
		A.attackby(L, U)
		combat_assert(L.S1 == A && L.onedefined && A.health == 20, "Leash attachment changed")
		I.force = 0
		I.sharp = FALSE
		I.attacks = 0
		I.hits = 0
		A.attackby(I, U)
		combat_assert(!I.attacks && !I.hits && A.health == 20, "Harmless tap dispatched attack")
		var/mob/living/simple_animal/hostage/H = new(site)
		I.force = 10
		I.sharp = TRUE
		I.attacks = 0
		I.hits = 0
		H.attackby(I, U)
		combat_assert(I.attacks == 1 && I.hits == 1 && H.health == 140, "Sharp hostage fallback changed")
		text2file("PASS: production health/Life, sharp/blunt clicks, damage, material wear, healing and death; [mismatches] audited default mismatches", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E]", "result.txt")
	del(world)
