#define SLASH 1
#define STAB 2
#define BASH 3

/obj/item/weapon/material/sword
	name = "claymore"
	desc = "What are you standing around staring at this for? Get to killing!"
	icon_state = "claymore"
	item_state = "claymore"
	slot_flags = SLOT_BELT
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	sharp = 1
	edge = 1
	var/atk_mode = SLASH
	var/block_chance = 35
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	hitsound = 'sound/weapons/bladeslice.ogg'
	drawsound = 'sound/items/unholster_sword01.ogg'
	sharpness = 25
	var/stat = "swords"


/obj/item/weapon/material/sword/handle_shield(mob/living/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	//Ok this if looks like a bit of a mess, and it is. Basically you need to have the sword in your active hand, and pass the default parry check
	//and also pass the prob which is your melee skill devided by two + the swords block chance. Complicated, I know, but hopefully it'll balance out.
	var/mob/living/carbon/human/H_user = user
	if(default_parry_check(user, attacker, damage_source) && prob(min(block_chance * (H_user.getStatCoeff("swords")),92)) && (user.get_active_hand() == src))//You gotta be holding onto that sheesh bro.
		user.visible_message("<span class='danger'>\The [user] parries [attack_text] with \the [src]!</span>")
		var/mob/living/carbon/human/H = user
		H.adaptStat("swords", 1)
		playsound(user.loc, pick('sound/weapons/blade_parry1.ogg', 'sound/weapons/blade_parry2.ogg', 'sound/weapons/blade_parry3.ogg'), 50, 1)
		health -= 0.5
		if(prob(15))
			user.visible_message("<span class='danger'>\The [src] flies out of \the [user]'s hand!</span>")
			user.drop_from_inventory(src)
			throw_at(get_edge_target_turf(src, pick(alldirs)), rand(1,3), throw_speed)//Throw that sheesh away

		return 1
	return 0

/obj/item/weapon/material/sword/attack_self(mob/user)
	..()
	if(atk_mode == SLASH)
		atk_mode = STAB
		user << "<span class='notice'>You will now stab.</span>"
		edge = 0
		sharp = 1
		attack_verb = list("stabbed")
		hitsound = "stab_sound"
		return

	else if(atk_mode == STAB)
		atk_mode = BASH
		user << "<span class='notice'>You will now bash.</span>"
		edge = 0
		sharp = 0
		attack_verb = list("bashed", "smacked")
		hitsound = "swing_hit"
		return


	else if(atk_mode == BASH)
		atk_mode = SLASH
		user << "<span class='notice'>You will now slash.</span>"
		attack_verb = list("slashed", "diced")
		hitsound = "slash_sound"
		edge = 1
		sharp = 1
		return
/obj/item/weapon/material/sword/katana
	name = "katana"
	desc = "Woefully underpowered in D20. This one looks pretty sharp."
	icon_state = "katana"
	item_state = "katana"
	block_chance = 30
	slot_flags = SLOT_BELT | SLOT_BACK

/obj/item/weapon/material/sword/smallsword
	name = "small sword"
	desc = "A common european sword, with about one meter in lenght."
	icon_state = "smallsword"
	item_state = "smallsword"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.6 // 36 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.8 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 25

/obj/item/weapon/material/sword/spadroon
	name = "spadroon"
	desc = "A light sword with a straight blade. Common among the military."
	icon_state = "spadroon"
	item_state = "spadroon"
	throw_speed = 3
	throw_range = 3
	force_divisor = 0.8 // 48 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 40

/obj/item/weapon/material/sword/cutlass
	name = "cutlass"
	desc = "A small, slightly curved sword, preferred by pirates."
	icon_state = "cutlass"
	item_state = "cutlass"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.6 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 28