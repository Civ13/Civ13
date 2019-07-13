// SEE code/modules/materials/materials.dm FOR DETAILS ON INHERITED DATUM.
// This class of weapons takes force and appearance data from a material datum.
// They are also fragile based on material data and many can break/smash apart.
/obj/item/weapon/material
	health = 10
	hitsound = 'sound/weapons/bladeslice.ogg'
	gender = NEUTER
	throw_speed = 3
	throw_range = 7
	w_class = 3
	sharp = FALSE
	edge = FALSE

	var/applies_material_colour = TRUE
	var/unbreakable
	var/force_divisor = 0.5
	var/thrown_force_divisor = 0.5
	var/default_material = DEFAULT_WALL_MATERIAL
	var/material/material
	var/drops_debris = TRUE
	var/block_chance = 15

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
/obj/item/weapon/material/get_material()
	return material

/obj/item/weapon/material/proc/update_force()
	if (edge || sharp)
		force = material.get_edge_damage()
	else
		force = material.get_blunt_damage()
	force = round(force*force_divisor)
	throwforce = round(material.get_blunt_damage()*thrown_force_divisor)
	//spawn(1)
	//	world << "[src] has force [force] and throwforce [throwforce] when made from default material [material.name]"

/obj/item/weapon/material/proc/set_material(var/new_material)
	material = get_material_by_name(new_material)
	if (!material)
		qdel(src)
	else
		name = "[material.display_name] [initial(name)]"
		health = round(material.integrity/10)
		if (applies_material_colour)
			color = material.icon_colour
		if (material.products_need_process())
			processing_objects |= src
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
	if (health<=0)
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

/obj/item/weapon/material/handle_shield(mob/living/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	//Ok this if looks like a bit of a mess, and it is. Basically you need to have the sword in your active hand, and pass the default parry check
	//and also pass the prob which is your melee skill * the swords block chance. Complicated, I know, but hopefully it'll balance out.
	var/mob/living/carbon/human/H_user = user
	var/isdefend = 1 //the defend tactic modifier
	var/modif = 1
	if (H_user.religion_check() == "Combat")
		modif = 1.1
	if (user.tactic == "defend")
		isdefend = 1.2
	if(default_parry_check(user, attacker, damage_source) && prob(isdefend*(min(block_chance * modif*(0.66*H_user.getStatCoeff("strength")+0.34*H_user.getStatCoeff("dexterity")),87))) && (user.get_active_hand() == src))//You gotta be holding onto that sheesh bro.
		user.visible_message("<font color='#E55300'><big>\The [user] parries [attack_text] with \the [src]!</big></font>")
		var/mob/living/carbon/human/H = user
		if (prob(50))
			H.adaptStat("dexterity", 1)
		else
			H.adaptStat("strength", 1)
		playsound(user.loc, pick('sound/weapons/blade_parry1.ogg', 'sound/weapons/blade_parry2.ogg', 'sound/weapons/blade_parry3.ogg'), 50, 1)
		if (istype(damage_source, /obj/item/weapon/melee) || istype(damage_source, /obj/item/weapon/material/hatchet))
			health -= 5
		else
			health-= 0.5
		check_health()
		if(prob(15))
			user.visible_message("<font color='#E55300'><big>\The [src] flies out of \the [user]'s hand!</big></font>")
			user.drop_from_inventory(src)
			throw_at(get_edge_target_turf(src, pick(alldirs)), rand(1,3), throw_speed)//Throw that sheesh away

		return 1
	return 0