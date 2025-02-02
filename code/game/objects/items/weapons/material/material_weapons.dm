// SEE code/modules/materials/materials.dm FOR DETAILS ON INHERITED DATUM.
// This class of weapons takes force and appearance data from a material datum.
// They are also fragile based on material data and many can break/smash apart.
/obj/item/weapon/material
	health = 10
	hitsound = 'sound/weapons/bladeslice.ogg'
	gender = NEUTER
	throw_speed = 3
	throw_range = 7
	w_class = ITEM_SIZE_NORMAL
	sharp = FALSE
	edge = FALSE

	var/applies_material_colour = TRUE
	var/unbreakable
	var/force_divisor = 0.5
	var/thrown_force_divisor = 0.5
	var/default_material = "steel"
	var/material/material
	var/drops_debris = TRUE

	var/crafting_quality = 1

	dropsound = 'sound/effects/drop_knife.ogg'

/obj/item/weapon/material/New(var/newloc, var/material_key)
	..(newloc)
	if (!material_key)
		if (!material)
			material_key = default_material
		else
			material_key = material
	set_material(material_key)
	if (!material)
		qdel(src)
		return

	matter = material.get_matter()
	if (matter.len)
		for (var/material_type in matter)
			if (!isnull(matter[material_type]))
				matter[material_type] *= force_divisor // May require a new var instead.
	spawn(20)
		if (material)
			if (get_material_name() == "wood")
				flammable = TRUE
				flags = FALSE
/obj/item/weapon/material/get_material()
	return material

/obj/item/weapon/material/proc/update_force()
	if (edge || sharp)
		force = material.get_edge_damage()
	else
		force = material.get_blunt_damage()
	force = round(force*force_divisor)*min(crafting_quality,2)
	throwforce = round(material.get_blunt_damage()*thrown_force_divisor)*min(crafting_quality,2)
	//spawn(1)
	//	to_chat(world, "[src] has force [force] and throwforce [throwforce] when made from default material [material.name]")

/obj/item/weapon/material/proc/set_material(var/new_material)
	material = get_material_by_name(new_material)
	if (!material)
		qdel(src)
	else
		name = "[material.display_name] [initial(name)]"
		health = round(material.integrity/10)
		maxhealth = health
		if (applies_material_colour)
			color = material.icon_colour
		update_force()

/obj/item/weapon/material/Destroy()
	processing_objects -= src
	..()

/obj/item/weapon/material/apply_hit_effect()
	..()
	if (!unbreakable)
		if (material.is_brittle())
			health = FALSE
		else if (!prob(material.hardness))
			health--
		check_health()

/obj/item/weapon/material/proc/check_health(var/consumed)
	if (health<=0 || maxhealth <=0)
		shatter(consumed)

/obj/item/weapon/material/proc/shatter(var/consumed)
	var/turf/T = get_turf(src)
	if (T)
		T.visible_message("<span class='danger'>\The [src] [material.destruction_desc]!</span>")
	if (istype(loc, /mob/living))
		var/mob/living/M = loc
		M.drop_from_inventory(src)
	playsound(src, "shatter", 70, TRUE)
	if (!consumed && drops_debris) material.place_shard(T)
	qdel(src)

/obj/item/weapon/material/examine(mob/user)
	..()
	switch(crafting_quality)
		if (-100 to 0.85)
			user << "<b>Quality:</b> Very Crude"
		if (0.850001 to 0.95)
			user << "<b>Quality:</b> Below Average"
		if (0.950001 to 1.15)
			user << "<b>Quality:</b> Decent"
		if (1.150001 to 100)
			user << "<b>Quality:</b> Excellent"
	if (health > 0 && maxhealth > 0)
		var/health_percentage = (health/maxhealth)*100
		switch (health_percentage)
			if (-100 to 21)
				user << "<font color='#7f0000'>Is practically falling apart!</font>"
			if (22 to 49)
				user << "<font color='#a74510'>Seems to be in very bad condition.</font>"
			if (50 to 69)
				user << "<font color='#cccc00'>Seems to be in a rough condition.</font>"
			if (70 to 84)
				user << "<font color='#4d5319'>Seems to be in a somewhat decent condition.</font>"
			if (85 to 200)
				user << "<font color='#245319'>Seems to be in very good condition.</font>"

