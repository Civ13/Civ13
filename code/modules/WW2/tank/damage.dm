/obj/tank/var/did_critical_damage = FALSE
/obj/tank/var/next_ex_act = -1

/obj/tank/bullet_act(var/obj/item/projectile/P, var/def_zone)

	// we can't be hit by our own bullets
	if (P.firer == back_seat())
		return
	if (!truck)

		if (istype(P, /obj/item/projectile/bullet/pellet))
			tank_message("<span class = 'danger'>[P] bounces off the tank!</span>")
			return

		if (istype(P, /obj/item/weapon/material/shard/shrapnel))
			tank_message("<span class = 'danger'>[P] bounces off the tank!</span>")
			return
	else
		if (istype(P, /obj/item/projectile/bullet/pellet))
			tank_message("<span class = 'danger'>[P] bounces off the truck!</span>")
			return

		if (istype(P, /obj/item/weapon/material/shard/shrapnel))
			tank_message("<span class = 'danger'>[P] bounces off the truck!</span>")
			return
	def_zone = check_zone(def_zone)

	// MGs will no longer destroy tanks in a few shots - Kachnov

	var/dam = 0
	if (!truck)
		if (P.firedfrom && istype(P.firedfrom, /obj/item/weapon/gun/projectile/heavy))
			dam = (P.damage/3 + (P.armor_penetration*20))/50
		else
			dam = (P.damage/3)/50

		if (P.armor_penetration < 50)
			dam /= 8

		dam += 0.25 // minimum damage
		damage += dam
		update_damage_status()
		if (prob(critical_damage_chance()))
			critical_damage()
		tank_message("<span class = 'danger'>The tank is hit by [P]!</span>")


	else
		if (P.firedfrom && istype(P.firedfrom, /obj/item/weapon/gun/projectile/heavy))
			dam = (P.damage + (P.armor_penetration))
			for (var/mob/living/m in src)
				m.apply_damage(rand(2,3), BRUTE)
		else if (istype(P, /obj/item/weapon/gun/launcher/rocket))
			dam = 4000
			for (var/mob/living/m in src)
				m.apply_damage(rand(2,3), BRUTE)
		else
			dam = (P.damage/3)/5
			for (var/mob/living/m in src)
				m.apply_damage(1, BRUTE)

		if (P.armor_penetration < 50)
			dam /= 2
		dam += 1 // minimum damage
		damage += dam
		update_damage_status()
		if (prob(critical_damage_chance()))
			critical_damage()
		tank_message("<span class = 'danger'>The truck is hit by [P]!</span>")


/obj/tank/ex_act(severity, var/forced = FALSE)

	if (world.time < next_ex_act && !forced)
		return

	next_ex_act = world.time + 5

	// reproportion severity - most dangerous to biggest number
	switch (severity)
		if (3.0)
			severity = 1.0
		if (2.0)
			severity = 2.0
		if (1.0)
			severity = 3.0

	// very high damage
	var/addamage = (rand(90,110) * severity)
	addamage = min(addamage, max_damage/10)

	damage += addamage

	if (prob(critical_damage_chance()))
		critical_damage()

	return TRUE


/obj/tank/proc/health_percentage() // text!
	return "[100 - ((damage/max_damage) * 100)]%"

/obj/tank/proc/health_percentage_num()
	return 100 - ((damage/max_damage) * 100)

/obj/tank/proc/health_coeff_num()
	return health_percentage_num()/100

/obj/tank/proc/critical_damage_chance()
	var/damage_coeff = damage/max_damage
	if (!truck)
		if (damage_coeff < 0.7)
			return FALSE
		else
			if (damage_coeff >= 0.7 && damage_coeff <= 0.9)
				return 5
			else
				return 25
	else
		if (damage_coeff >= 0.8)
			return 25


/obj/tank/proc/critical_damage()

	if (did_critical_damage)
		return

	did_critical_damage = TRUE
	tank_message("<span class = 'danger'><big>[src] starts to shake and fall apart!</big></span>")
	spawn (rand(100,200))
		tank_message("<span class = 'danger'>You can smell burning from inside [src].</danger>")
		for (var/mob/living/m in src)
			m.on_fire = TRUE
			m.fire_stacks += rand(5,15)
			m << "<span class = 'danger'><big>You're on fire.</big></danger>"
			if (prob(30))
				spawn (25) // smell needs to travel or something
					tank_message("<span class = 'danger'>You can smell burning flesh from inside [src].</danger>")

	spawn (rand(250, 350))
		tank_message("<span class = 'danger'>[src] is falling apart[pick("!", "!!")]</span>")
		for (var/v in TRUE to 10)
			spawn (v * 5)
				for (var/mob/living/m in src)
					m.apply_damage(rand(1,2), BRUTE)
	spawn (rand(420, 600))
		tank_message("<span class = 'danger'><big>[src] explodes.</big></span>")
		for (var/mob/m in src)
			m.crush()
		explosion(get_turf(src), TRUE, 3, 5, 6)
		spawn (20)
			qdel(src)
			loc = null

