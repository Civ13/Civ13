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
	var/block_chance = 15

	var/crafting_quality = 1
	// Scalars persist through the native world serializer without retaining parts.
	var/tool_head_material
	var/tool_handle_material
	var/tool_head_quality
	var/tool_handle_quality
	var/tool_head_condition
	var/tool_handle_condition

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
		apply_tool_material_speed()

/obj/item/weapon/material/Destroy()
	processing_objects -= src
	..()

/obj/item/weapon/material/apply_hit_effect()
	..()
	if (!unbreakable)
		if (material.is_brittle())
			health = FALSE
			check_health()
		else if (!prob(material.hardness))
			apply_wear(1, WEAR_BLOW)
		else
			check_health()

/obj/item/weapon/material/check_health(consumed)
	if (health<=0 || maxhealth <=0)
		shatter(consumed)
		return TRUE
	return FALSE

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

/obj/item/weapon/material/handle_shield(mob/living/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	//Ok this if looks like a bit of a mess, and it is. Basically you need to have the sword in your active hand, and pass the default parry check
	//and also pass the prob which is your melee skill * the swords block chance. Complicated, I know, but hopefully it'll balance out.
	var/mob/living/human/H_user = user
	var/isdefend = 1 //the defend tactic modifier
	var/modif = 1
	if (H_user.religion_check() == "Combat")
		modif = 1.1
	if (user.tactic == "defend")
		isdefend = 1.2
	if(default_parry_check(user, attacker, damage_source) && prob(isdefend*(min(block_chance * modif*(0.66*H_user.getStatCoeff("strength")+0.34*H_user.getStatCoeff("dexterity")),87))) && (user.get_active_hand() == src))//You gotta be holding onto that sheesh bro.
		user.visible_message("<font color='#E55300'><big>\The [user] parries [attack_text] with \the [src]!</big></font>")
		var/mob/living/human/H = user
		H.body_motion_parry(attacker)
		if (prob(50))
			H.adaptStat("dexterity", 1)
		else
			H.adaptStat("strength", 1)
		playsound(user.loc, pick('sound/weapons/blade_parry1.ogg', 'sound/weapons/blade_parry2.ogg', 'sound/weapons/blade_parry3.ogg'), 50, 1)
		if (istype(damage_source, /obj/item/weapon/melee) || is_tool(damage_source, TOOL_HATCHET))
			apply_wear(5, WEAR_BLOW)
		else
			apply_wear(0.5, WEAR_BLOW)
		if(QDELETED(src))
			return 1
		if(prob(15))
			user.visible_message("<font color='#E55300'><big>\The [src] flies out of \the [user]'s hand!</big></font>")
			user.drop_from_inventory(src)
			throw_at(get_edge_target_turf(src, pick(alldirs)), rand(1,3), throw_speed)//Throw that sheesh away

		return 1
	return 0

/obj/item/weapon/material/examine(mob/user)
	..()
	if (material)
		to_chat(user, "<b>Material:</b> [material.display_name] - [material.property_summary()].")
	if (tool_head_material && tool_handle_material)
		to_chat(user, "<b>Components:</b> [tool_head_material] head (quality [tool_head_quality]), [tool_handle_material] handle (quality [tool_handle_quality]).")
	switch(crafting_quality)
		if (-100 to 0.85)
			to_chat(user, "<b>Quality:</b> Very Crude")
		if (0.850001 to 0.95)
			to_chat(user, "<b>Quality:</b> Below Average")
		if (0.950001 to 1.15)
			to_chat(user, "<b>Quality:</b> Decent")
		if (1.150001 to 100)
			to_chat(user, "<b>Quality:</b> Excellent")
	if (health > 0 && maxhealth > 0)
		var/health_percentage = (health/maxhealth)*100
		switch (health_percentage)
			if (-100 to 21)
				to_chat(user, "<font color='#7f0000'>Is practically falling apart!</font>")
			if (22 to 49)
				to_chat(user, "<font color='#a74510'>Seems to be in very bad condition.</font>")
			if (50 to 69)
				to_chat(user, "<font color='#cccc00'>Seems to be in a rough condition.</font>")
			if (70 to 84)
				to_chat(user, "<font color='#4d5319'>Seems to be in a somewhat decent condition.</font>")
			if (85 to 200)
				to_chat(user, "<font color='#245319'>Seems to be in very good condition.</font>")

/obj/item/weapon/material/proc/record_tool_components(obj/item/weapon/material/part/head_part, obj/item/weapon/material/handle/HANDLE)
	tool_head_material = head_part.material.name
	tool_head_quality = max(0.5, min(2, head_part.crafting_quality))
	tool_head_condition = max(0, min(1, head_part.health / head_part.maxhealth))
	apply_tool_handle(src, HANDLE.material.name, HANDLE.crafting_quality, HANDLE.health / HANDLE.maxhealth)

// How a handle of this material changes a tool against a plain wood handle:
// list(durability multiplier, work speed multiplier). Tougher wood lasts
// longer; lighter wood swings faster.
/proc/tool_handle_effects(handle_material_name)
	var/material/wood = get_material_by_name("wood")
	var/material/M = get_material_by_name(handle_material_name)
	if (!wood || !M)
		return list(1, 1)
	return list(max(0.5, min(1.5, M.integrity / wood.integrity)), max(0.75, min(1.25, wood.weight / max(1, M.weight))))

// "lasts 50% longer and works 25% faster than with a wood handle", for examine
// text and the Crafting window.
/proc/tool_handle_effect_text(handle_material_name)
	var/list/effects = tool_handle_effects(handle_material_name)
	var/list/parts = list()
	var/durability = round((effects[1] - 1) * 100, 1)
	var/speed = round((effects[2] - 1) * 100, 1)
	if (durability)
		parts += durability > 0 ? "lasts [durability]% longer" : "has [-durability]% less durability"
	if (speed)
		parts += "works [abs(speed)]% [speed > 0 ? "faster" : "slower"]"
	return parts.len ? "[jointext(parts, " and ")] than with a wood handle" : "works the same as with a wood handle"

// Fit a handle to a finished tool, whether a head was put on it by hand or the
// tool was crafted from a stack recipe that used the handle up. The handle
// scales durability, and the work speed of pickaxes, shovels and hoes.
/proc/apply_tool_handle(obj/item/I, handle_material_name, handle_quality = 1, handle_condition = 1)
	if (!istype(I) || !handle_material_name)
		return
	var/list/effects = tool_handle_effects(handle_material_name)
	handle_quality = max(0.5, min(2, handle_quality))
	handle_condition = max(0, min(1, handle_condition))
	var/head_condition = 1
	var/head_name = null
	if (istype(I, /obj/item/weapon/material))
		var/obj/item/weapon/material/T = I
		if (!T.tool_head_material && T.material)
			T.tool_head_material = T.material.name
			T.tool_head_quality = max(0.5, min(2, T.crafting_quality))
			T.tool_head_condition = 1
		T.tool_handle_material = handle_material_name
		T.tool_handle_quality = handle_quality
		T.tool_handle_condition = handle_condition
		T.crafting_quality = min(T.tool_head_quality, handle_quality)
		T.update_force()
		head_condition = T.tool_head_condition
		head_name = T.tool_head_material
	if (I.maxhealth > 0)
		I.maxhealth = max(1, round(I.maxhealth * effects[1]))
		I.health = I.maxhealth * min(head_condition, handle_condition)
	I.apply_handle_speed(effects[2], head_name)

// The head sets the family speed (tool_speeds.dm); the handle scales it. Only
// tools with a work speed take part.
/obj/item/proc/apply_handle_speed(multiplier, head_name)
	return

/obj/item/weapon/material/pickaxe/apply_handle_speed(multiplier, head_name)
	var/head_speed = tool_material_speed(/obj/item/weapon/material/pickaxe, head_name) || initial(usespeed)
	usespeed = max(1, min(3, head_speed * multiplier))

/obj/item/weapon/material/shovel/apply_handle_speed(multiplier, head_name)
	var/head_speed = tool_material_speed(/obj/item/weapon/material/shovel, head_name) || initial(usespeed)
	usespeed = head_speed * multiplier

/obj/item/weapon/plough/hoe/apply_handle_speed(multiplier, head_name)
	usespeed *= multiplier

// Says what this handle does for a tool built on it.
/obj/item/weapon/material/handle/examine(mob/user)
	..()
	if (material)
		to_chat(user, "<b>As a tool handle:</b> a tool built on it [tool_handle_effect_text(material.name)].")
