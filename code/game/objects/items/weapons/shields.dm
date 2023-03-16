//** Shield Helpers
//These are shared by various items that have shield-like behaviour

//bad_arc is the ABSOLUTE arc of directions from which we cannot block. If you want to fix it to e.g. the user's facing you will need to rotate the dirs yourself.
/proc/check_shield_arc(mob/user, var/bad_arc, atom/damage_source = null, mob/attacker = null)
	//check attack direction
	var/attack_dir = FALSE //direction from the user to the source of the attack
	if (istype(damage_source, /obj/item/projectile))
		var/obj/item/projectile/P = damage_source
		attack_dir = get_dir(get_turf(user), P.starting)
	else if (attacker)
		attack_dir = get_dir(get_turf(user), get_turf(attacker))
	else if (damage_source)
		attack_dir = get_dir(get_turf(user), get_turf(damage_source))

	if (!(attack_dir && (attack_dir & bad_arc)))
		return TRUE
	return FALSE

/proc/default_parry_check(mob/user, mob/attacker, atom/damage_source)
	//parry only melee attacks
	if (istype(damage_source, /obj/item/projectile) || (attacker && get_dist(user, attacker) > 1) || user.incapacitated())
		return FALSE

	if(user.defense_intent != I_PARRY)//If you're not on parry intent, you won't parry.
		return 0

	//block as long as they are not directly behind us
	var/bad_arc = reverse_direction(user.dir) //arc of directions from which we cannot block
	if (!check_shield_arc(user, bad_arc, damage_source, attacker))
		return FALSE

	return TRUE

/obj/item/weapon/shield
	name = "wood shield"
	icon_state = "buckler"
	item_state = "buckler"
	var/base_block_chance = 25
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BACK | SLOT_ACCESSORY
	var/material = "wood"
	health = 20 // hardness of wood
	var/cooldown = 0
	slowdown = 0.1

/obj/item/weapon/shield/New()
	..()
	if (get_material_name() == "wood")
		flammable = TRUE

/obj/item/weapon/shield/nguni_shield
	name = "nguni shield"
	icon_state = "nguni_shield"
	item_state = "nguni_shield"
	base_block_chance = 25
	health = 25

/obj/item/weapon/shield/steel
	name = "steel shield"
	icon_state = "steel_shield"
	item_state = "steel_shield"
	material = "steel"
	health = 30
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 38 //minor change to make the upgrade worthwhile
	slowdown = 0.3

/obj/item/weapon/shield/iron
	name = "iron shield"
	icon_state = "iron_shield"
	item_state = "iron_shield"
	material = "iron"
	health = 25
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 33
	slowdown = 0.25

/obj/item/weapon/shield/bronze
	name = "bronze shield"
	icon_state = "bronze_shield"
	item_state = "bronze_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 30
	slowdown = 0.2

/obj/item/weapon/shield/aspis
	name = "aspis"
	desc = "a round, slightly curved greek shield, with the colors and symbol of it's city-state."
	icon_state = "athenian_shield"
	item_state = "athenian_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 45
	slowdown = 0.4

/obj/item/weapon/shield/aspis/New()
	..()
	icon_state = pick("athenian_shield", "spartan_shield", "pegasus_shield", "owl_shield")
	item_state = icon_state
	update_icon()

/* Nomads Aspis Shields*/

/obj/item/weapon/shield/nomads/aspis //to avoid the new() , this variant is nerfed to be evenly matched with roman but slightly stronger than iron shields
	name = "athenian aspis"
	desc = "a round, slightly curved greek shield, with the colors and symbol of it's city-state."
	icon_state = "athenian_shield"
	item_state = "athenian_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 35
	slowdown = 0.4

/obj/item/weapon/shield/nomads/spartan
	name = "spartan aspis"
	desc = "a round, slightly curved greek shield, with the colors and symbol of it's city-state."
	icon_state = "spartan_shield"
	item_state = "spartan_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 35
	slowdown = 0.4

/obj/item/weapon/shield/nomads/aspis/pegasus
	name = "aspis with image of a pegasus"
	desc = "a round, slightly curved greek shield, with the colors and symbol of it's city-state."
	icon_state = "pegasus_shield"
	item_state = "pegasus_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 35
	slowdown = 0.4

/obj/item/weapon/shield/nomads/aspis/owl
	name = "aspis with image of a owl"
	desc = "a round, slightly curved greek shield, with the colors and symbol of it's city-state."
	icon_state = "owl_shield"
	item_state = "owl_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 35
	slowdown = 0.4

/* Nomads Aspis Shields -End*/

/obj/item/weapon/shield/egyptian
	name = "egyptian shield"
	desc = "a semi oval, rectangular bronze shield of egyptian design and motifs"
	icon_state = "egyptian_shield"
	item_state = "egyptian_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 35
	slowdown = 0.4

/obj/item/weapon/shield/scutum
	name = "scutum shield"
	desc = "a rounded rectangular shield, with celtic motifs."
	icon_state = "scutum"
	item_state = "scutum"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 37
	slowdown = 0.3

/obj/item/weapon/shield/roman
	name = "roman shield"
	desc = "a rectangular shield, with roman motifs."
	icon_state = "roman_shield"
	item_state = "roman_shield"
	material = "bronze"
	health = 23
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 37
	slowdown = 0.3

/obj/item/weapon/shield/roman/blue
	name = "blue roman shield"
	desc = "a blue rectangular shield, with roman motifs. Often used by imitation legions and client states."
	icon_state = "blue_roman_shield"
	item_state = "blue_roman_shield"

/obj/item/weapon/shield/roman/praetorian
	name = "praetorian roman shield"
	desc = "a purple rectangular shield, with roman motifs. Often used by the praetorian guard, it looks more robust than the standard roman shield."
	icon_state = "prae_roman_shield"
	item_state = "prae_roman_shield"
	health = 30
	base_block_chance = 37
	slowdown = 0.40

/obj/item/weapon/shield/roman_buckler
	name = "roman parma shield"
	desc = "a circular buckler, with roman motifs."
	icon_state = "roman_buckler"
	item_state = "roman_buckler"
	base_block_chance = 25 //nerfed from 257
	w_class = ITEM_SIZE_SMALL
	material = "wood"
	health = 20 // hardness of wood
	slowdown = 0.1
	slot_flags = SLOT_BACK | SLOT_BELT | SLOT_ACCESSORY

/obj/item/weapon/shield/chimalli
	name = "chimalli"
	desc = "an oval Mesoamerican shield, furnished with feathers."
	icon_state = "chimalli"
	item_state = "chimalli"
	material = "wood"
	slot_flags = SLOT_BACK
	health = 20
	w_class = ITEM_SIZE_SMALL
	base_block_chance = 30
	slowdown = 0.1
/obj/item/weapon/shield/handle_shield(mob/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	if (user.incapacitated())
		return FALSE

	//block as long as they are not directly behind us
	var/bad_arc = reverse_direction(user.dir) //arc of directions from which we cannot block
	if (check_shield_arc(user, bad_arc, damage_source, attacker))
		if (prob(get_block_chance(user, damage, damage_source, attacker)))
			user.visible_message("<font color='#E55300'><big>\The [user] blocks [attack_text] with \the [src]!</big></font>")
			if (istype(damage_source, /obj/item/weapon/melee) || istype(damage_source, /obj/item/weapon/material/hatchet))
				health -= 10
			else
				health--
			check_health()
			return TRUE
	return FALSE

/obj/item/weapon/shield/proc/get_block_chance(mob/user, var/damage, atom/damage_source = null, mob/attacker = null)
	return base_block_chance

/obj/item/weapon/shield/proc/check_health(var/consumed)
	if (health<=0)
		shatter(consumed)

/obj/item/weapon/shield/proc/shatter(var/consumed)
	var/turf/T = get_turf(src)
	T.visible_message("<span class='danger'>\The [src] is broken apart!</span>")
	if (istype(loc, /mob/living))
		var/mob/living/M = loc
		M.drop_from_inventory(src)
	playsound(src, "shatter", 70, TRUE)
	qdel(src)

/obj/item/weapon/shield/iron/semioval
	name = "semioval iron shield"
	icon_state = "semioval_shield"
	item_state = "semioval_shield"
	material = "iron"
	health = 25
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 40
	slowdown = 0.3

/obj/item/weapon/shield/iron/semioval/templar
	name = "semioval iron templar shield"
	icon_state = "semioval_shield_templar"
	item_state = "semioval_shield_templar"

/obj/item/weapon/shield/iron/semioval/templar2
	name = "semioval iron templar shield"
	icon_state = "semioval_shield_templar2"
	item_state = "semioval_shield_templar2"

/* Nomads Semi Oval & Medieval Shields*/

/obj/item/weapon/shield/iron/nomads/semioval
	name = "semioval iron shield"
	icon_state = "semioval_shield"
	item_state = "semioval_shield"
	material = "iron"
	health = 25
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 37
	slowdown = 0.3

/obj/item/weapon/shield/iron/nomads/semioval/templar
	name = "semioval iron templar shield"
	icon_state = "semioval_shield_templar"
	item_state = "semioval_shield_templar"

/obj/item/weapon/shield/iron/nomads/semioval/templar2
	name = "semioval iron templar shield"
	icon_state = "semioval_shield_templar2"
	item_state = "semioval_shield_templar2"

/* Nomads Semi Oval & Medieval Shields -End*/

/obj/item/weapon/shield/red_buckler
	name = "red buckler shield"
	icon_state = "red_buckler"
	item_state = "red_buckler"
	base_block_chance = 25
	w_class = ITEM_SIZE_SMALL
	material = "wood"
	health = 20 // hardness of wood
	slowdown = 0.1
	slot_flags = SLOT_BACK | SLOT_BELT | SLOT_ACCESSORY

obj/item/weapon/shield/blue_buckler
	name = "blue buckler shield"
	icon_state = "blue_buckler"
	item_state = "blue_buckler"
	base_block_chance = 25
	slot_flags = SLOT_BACK | SLOT_BELT | SLOT_ACCESSORY
	w_class = ITEM_SIZE_SMALL
	material = "wood"
	health = 20 // hardness of wood
	slowdown = 0.1

obj/item/weapon/shield/attack_self(mob/user as mob)
	if (cooldown < world.time - 10)
		user.visible_message("<span class='warning'>[user] bashes the shield!</span>")
		playsound(user.loc, 'sound/effects/shieldbash2.ogg', 100, TRUE)
		cooldown = world.time

/obj/item/weapon/shield/arab_buckler
	name = "arabic round shield"
	icon_state = "arabic_shield"
	item_state = "arabic_shield"
	base_block_chance = 30
	slot_flags = SLOT_BACK | SLOT_BELT | SLOT_ACCESSORY | SLOT_ACCESSORY
	w_class = ITEM_SIZE_SMALL
	material = "wood"
	health = 20 // hardness of wood
	slowdown = 0.22

/* Tribes Shields */

/obj/item/weapon/shield/iron/orc
	name = "uruk-hai shield"
	icon_state = "orc_shield"
	item_state = "orc_shield"
	material = "iron"
	health = 25
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 40
	slowdown = 0.3

/obj/item/weapon/shield/chitin
	name = "chitin buckler"
	desc = "a rounded shield made out of fused chitinous plates."
	icon_state = "chitin_buckler"
	item_state = "chitin_buckler"
	material = "chitin"
	health = 20
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 25
	slowdown = 0.2

/obj/item/weapon/shield/chitin/large
	name = "chitin shield"
	desc = "a large shield made out of fused chitinous plates."
	icon_state = "chitin_shield"
	item_state = "chitin_shield"
	material = "chitin"
	health = 25
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 37
	slowdown = 0.35

/* Tribes Shields -End*/


/obj/item/weapon/shield/metal_riot
	name = "riot shield"
	desc = "A riot sheild designed to be excellent in blocking during prisoner uprisings"
	icon_state = "metal_riot"
	item_state = "metal_riot"
	material = "iron"
	health = 90
	w_class = ITEM_SIZE_SMALL
	base_block_chance = 65
	slowdown = 0.35

/obj/item/weapon/shield/balistic
	name = "ballistic shield"
	desc = "A shield designed to be excellent in blocking projectiles."
	icon_state = "metal_riot"
	item_state = "metal_riot"
	material = "steel"
	health = 90
	w_class = ITEM_SIZE_LARGE
	base_block_chance = 85
	slowdown = 2.85
//////////////////////////////////////SKYRIM////////////////////////////////////////
/obj/item/weapon/shield/tes13
	name = "iron shield"
	icon_state = "iron_shield_tes13"
	item_state = "iron_shield_tes13"
	material = "iron"
	health = 60
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 40
	slowdown = 0.05
/obj/item/weapon/shield/tes13/handle_shield(mob/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	if (user.incapacitated())
		return FALSE

	//block as long as they are not directly behind us
	var/bad_arc = reverse_direction(user.dir) //arc of directions from which we cannot block
	if (check_shield_arc(user, bad_arc, damage_source, attacker))
		if (prob(get_block_chance(user, damage, damage_source, attacker)))
			user.visible_message("<font color='#E55300'><big>\The [user] blocks [attack_text] with \the [src]!</big></font>")
			if (istype(damage_source, /obj/item/weapon/melee) || istype(damage_source, /obj/item/weapon/material/hatchet))
				health -= 2
			else
				health--
			if (istype(damage_source, /obj/item/weapon/material/tes13/mace))
				src.health -= 10
			check_health()
			return TRUE
	return FALSE
/obj/item/weapon/shield/tes13/stormcloak
	name = "stormcloak shield"
	icon_state = "stormcloak"
	item_state = "stormcloak"
	material = "wood"
	health = 60
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 40
	slowdown = 0.05

/obj/item/weapon/shield/tes13/whiterun
	name = "whiterun guard shield"
	icon_state = "whiterun"
	item_state = "whiterun"
	material = "wood"
	health = 60
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 40
	slowdown = 0.05

/obj/item/weapon/shield/tes13/imperial
	name = "imperial kite shield"
	icon_state = "imperial_kite"
	item_state = "imperial_kite"
	material = "wood"
	health = 60
	w_class = ITEM_SIZE_NORMAL
	base_block_chance = 40
	slowdown = 0.05