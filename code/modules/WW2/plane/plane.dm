/* a plane controller (heavy WIP):
  nodes, fuelslots, and controls are all in lists so as to support more
  modular planes with multiple controls, etc. Right now none of the planes
  are like that, and the length of fuelslots/controls will always be 1.

  - Kachnov
*/


/datum/plane
	var/list/plane_nodes = list()
	var/list/plane_fuelslots = list()
	var/list/plane_controls = list()
	var/name = "A freakin' plane"
	var/named = FALSE
	var/damage = FALSE
	var/max_damage = 500
	var/took_critical_damage = FALSE

/datum/plane/proc/visible_message(x)
	var/obj/plane_part/plane_node/middle_node = get_middle_node()
	return middle_node.visible_message(x)

/datum/plane/proc/get_middle_node()
	return plane_nodes[min(max(round(plane_nodes.len/2), TRUE), plane_nodes.len)]

/* subtypes */

/datum/plane/german
	name = "German Plane"

/datum/plane/german/my_name()
	return "the German Plane"

/datum/plane/soviet
	name = "Soviet T-23 Plane"

/datum/plane/soviet/my_name()
	return "the Soviet T-23 Plane"

/* list helper member functions for CONCISE coding!!! - Kachnov */

/datum/plane/proc/node(i)
	if (!i)
		i = TRUE
	if (i > plane_nodes.len)
		if (plane_nodes.len)
			return plane_nodes[plane_nodes.len]
		return null
	else
		return plane_nodes[i]

/datum/plane/proc/fuelslot(i)
	if (!i)
		i = TRUE
	if (i > plane_fuelslots.len)
		if (plane_fuelslots.len)
			return plane_fuelslots[plane_fuelslots.len]
		return null
	else
		return plane_fuelslots[i]

/datum/plane/proc/controls(i)
	if (!i)
		i = TRUE
	if (i > plane_controls.len)
		if (plane_controls.len)
			return plane_controls[plane_controls.len]
		return null
	else
		return plane_controls[i]

/* various plane helper member functions */

/datum/plane/proc/my_name()
	return "the [name]"

/datum/plane/proc/set_name(x)
	name = x
	named = TRUE

/datum/plane/var/displayed_damage_message[10]

/datum/plane/proc/x_percent_of_max_damage(x)
	return (max_damage/100) * x

/datum/plane/proc/update_damage_status()
	var/damage_percentage = (damage/max_damage) * 100
	switch (damage_percentage)
		if (0 to 5) // who cares
			if (!displayed_damage_message["0-5"])
				displayed_damage_message["6-15"] = FALSE
		//		plane_message("<span class = 'danger'>[src] looks a bit damaged.</span>")
				displayed_damage_message["0-5"] = TRUE
		if (6 to 15)
			if (!displayed_damage_message["6-15"])
				displayed_damage_message["16-25"] = FALSE
				plane_message("<span class = 'danger'>[src] looks a bit damaged.</span>")
				displayed_damage_message["6-15"] = TRUE
		if (16 to 25)
			if (!displayed_damage_message["16-25"])
				displayed_damage_message["25-49"] = FALSE
				plane_message("<span class = 'danger'>[src] looks damaged.</span>")
				displayed_damage_message["16-25"] = TRUE
		if (25 to 49)
			if (!displayed_damage_message["25-49"])
				displayed_damage_message["50-79"] = FALSE
				plane_message("<span class = 'danger'>[src] looks quite damaged.</span>")
				displayed_damage_message["25-49"] = TRUE
		if (50 to 79)
			if (!displayed_damage_message["50-79"])
				displayed_damage_message["80-97"] = FALSE
				plane_message("<span class = 'danger'>[src] looks really damaged!</span>")
				displayed_damage_message["50-79"] = TRUE
		if (80 to 97)
			if (!displayed_damage_message["80-97"])
				displayed_damage_message["97-INFINITY"] = FALSE
				plane_message("<span class = 'danger'>[src] looks extremely damaged!</span>")
				displayed_damage_message["80-97"] = TRUE
		if (97 to INFINITY)
			if (!displayed_damage_message["97-INFINITY"])
				plane_message("<span class = 'danger'><big>[src] looks like its going to explode!!</big></span>")
				displayed_damage_message["97-INFINITY"] = TRUE

/datum/plane/proc/plane_message(x)
	x = replacetext(x, "The plane", istype(src, /datum/plane/german) ? "German Panzer" : "Soviet plane")
	visible_message(x)
	internal_plane_message(x)
	for (var/datum/plane/other in world)
		if (other != src)
			for (var/mob/m in range(10, other.get_middle_node()))
				m << x // they aren't in the same plane so they get normal messages

/datum/plane/proc/internal_plane_message(x)
	for (var/mob/m in src)
		m << "<span class = 'notice'>(YOUR plane)</span> <big>[x]</big>"

/* plane damage helpers */
/*
/datum/plane/var/did_critical_damage = FALSE
/datum/plane/var/next_ex_act = -1

/datum/plane/bullet_act(var/obj/item/projectile/P, var/def_zone)

	if (istype(P, /obj/item/projectile/bullet/pellet))
		plane_message("<span class = 'danger'>[P] bounces off the plane!</span>")
		return

	if (istype(P, /obj/item/weapon/material/shard/shrapnel))
		plane_message("<span class = 'danger'>[P] bounces off the plane!</span>")
		return

	def_zone = check_zone(def_zone)

	var/dam = (P.damage/3 + (P.armor_penetration*20))/25
	if (P.armor_penetration < 50)
		dam /= 8

	dam += 1 // minimum damage

	damage += dam

	update_damage_status()
	if (prob(critical_damage_chance()))
		critical_damage()
	plane_message("<span class = 'danger'>The plane is hit by [P]!</span>")*/
/*
/datum/plane/ex_act(severity, var/forced = FALSE)

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
*/

/datum/plane/proc/health_percentage() // text!
	return "[100 - ((damage/max_damage) * 100)]%"

/datum/plane/proc/health_percentage_num()
	return 100 - ((damage/max_damage) * 100)

/datum/plane/proc/health_coeff_num()
	return health_percentage_num()/100

/datum/plane/proc/critical_damage_chance()
	var/damage_coeff = damage/max_damage
	if (damage_coeff < 0.7)
		return FALSE
	else
		if (damage_coeff >= 0.7 && damage_coeff <= 0.9)
			return 5
		else
			return 25

/datum/plane/proc/critical_damage()

	if (took_critical_damage)
		return

	took_critical_damage = TRUE
	plane_message("<span class = 'danger'><big>[src] starts to shake and fall apart!</big></span>")
	spawn (rand(100,200))
		plane_message("<span class = 'danger'>You can smell burning from inside [src].</danger>")
		for (var/mob/living/m in src)
			m.on_fire = TRUE
			m.fire_stacks += rand(5,15)
			m << "<span class = 'danger'><big>You're on fire.</big></danger>"
			if (prob(30))
				spawn (25) // smell needs to travel or something
					plane_message("<span class = 'danger'>You can smell burning flesh from inside [src].</danger>")

	spawn (rand(250, 350))
		plane_message("<span class = 'danger'>[src] is falling apart[pick("!", "!!")]</span>")
		for (var/v in TRUE to 10)
			spawn (v * 5)
				for (var/mob/living/m in src)
					m.apply_damage(rand(1,2), BRUTE)
	spawn (rand(420, 600))
		plane_message("<span class = 'danger'><big>[src] explodes.</big></span>")
		for (var/mob/m in src)
			m.crush()
		explosion(get_turf(src), TRUE, 3, 5, 6)
		spawn (20)
			qdel(src)