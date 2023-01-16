/obj/item/weapon/material/sword
	name = "claymore"
	desc = "What are you standing around staring at this for? Get to killing!"
	icon_state = "claymore"
	item_state = "claymore"
	slot_flags = SLOT_BELT
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	sharp = TRUE
	edge = TRUE
	var/atk_mode = SLASH
	block_chance = 35
	attack_verb = list("slashed", "diced")
	hitsound = "slash_sound"
	drawsound = 'sound/items/unholster_sword01.ogg'
	sharpness = 25
	var/stat = "swords"
	cooldownw = DEFAULT_ATTACK_COOLDOWN //how long till you can attack again


/obj/item/weapon/material/sword/handle_shield(mob/living/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	//Ok this if looks like a bit of a mess, and it is. Basically you need to have the sword in your active hand, and pass the default parry check
	//and also pass the prob which is your melee skill * the swords block chance. Complicated, I know, but hopefully it'll balance out.
	var/mob/living/human/H_user = user
	var/isdefend = 1 //the defend tactic modifier
	var/modif = 1
	if (H_user.religion_check() == "Combat")
		modif = 1.1
	if (user.tactic == "defend")
		isdefend = 1.2
	if(default_parry_check(user, attacker, damage_source) && prob(isdefend*(min(block_chance * (H_user.getStatCoeff("swords")*modif),92))) && (user.get_active_hand() == src))//You gotta be holding onto that sheesh bro.
		user.visible_message("<font color='#E55300'><big>\The [user] parries [attack_text] with \the [src]!</big></font>")
		var/mob/living/human/H = user
		H.adaptStat("swords", 1*modif)
		playsound(user.loc, pick('sound/weapons/blade_parry1.ogg', 'sound/weapons/blade_parry2.ogg', 'sound/weapons/blade_parry3.ogg'), 50, 1)
		if (istype(damage_source, /obj/item/weapon/sledgehammer))
			health -= 10
			if(prob(35))
				user.visible_message("<font color='#E55300'><big>\The [src] flies out of \the [user]'s hand!</big></font>")
				user.drop_from_inventory(src)
				throw_at(get_edge_target_turf(src, pick(alldirs)), rand(1,3), throw_speed)//Throw that sheesh away

		else if (istype(damage_source, /obj/item/weapon/melee) || istype(damage_source, /obj/item/weapon/material/hatchet))
			health -= 5
			if(prob(15))
				user.visible_message("<font color='#E55300'><big>\The [src] flies out of \the [user]'s hand!</big></font>")
				user.drop_from_inventory(src)
				throw_at(get_edge_target_turf(src, pick(alldirs)), rand(1,3), throw_speed)//Throw that sheesh away
		else
			health-= 0.5
			if(prob(10))
				user.visible_message("<font color='#E55300'><big>\The [src] flies out of \the [user]'s hand!</big></font>")
				user.drop_from_inventory(src)
				throw_at(get_edge_target_turf(src, pick(alldirs)), rand(1,3), throw_speed)//Throw that sheesh away
		return 1
	return 0

/obj/item/weapon/material/sword/attack_self(mob/user)
	..()
	if(atk_mode == SLASH)
		atk_mode = STAB
		user << "<span class='notice'>You will now stab.</span>"
		edge = FALSE
		sharp = TRUE
		attack_verb = list("stabbed")
		hitsound = "stab_sound"

	else if(atk_mode == STAB)
		atk_mode = BASH
		user << "<span class='notice'>You will now bash.</span>"
		edge = FALSE
		sharp = FALSE
		attack_verb = list("bashed", "smacked")
		hitsound = "swing_hit"

	else if(atk_mode == BASH)
		atk_mode = SLASH
		user << "<span class='notice'>You will now slash.</span>"
		edge = TRUE
		sharp = TRUE
		attack_verb = list("slashed", "diced")
		hitsound = "slash_sound"

/obj/item/weapon/material/sword/training
	name = "training sword"
	desc = "A wood sword used for nonlethal practice."
	icon_state = "wood_sword"
	item_state = "wood_sword"
	block_chance = 60
	force_divisor = 5
	thrown_force_divisor = 3
	force = 1
	slot_flags = SLOT_BELT | SLOT_BACK
	value = 0
	cooldownw = 8
	sharpness = 0
	flammable = TRUE
	attack_verb = list("thwacked", "hit", "clonked", "batted", "tapped", "smacked", "poked", "slapped")
	hitsound = 'sound/weapons/kick.ogg'
	drawsound = 'sound/items/unholster_sword01.ogg'
	sharp = FALSE
	edge = FALSE
	default_material = "wood"

/obj/item/weapon/material/sword/training/bamboo
	name = "bokken"
	desc = "A bamboo sword used for nonlethal practice."
	icon_state = "bokken_sword"
	item_state = "bokken_sword"
	block_chance = 50
	force_divisor = 5
	thrown_force_divisor = 3
	force = 1
	slot_flags = SLOT_BELT | SLOT_BACK
	value = 0
	cooldownw = 8
	sharpness = 0
	flammable = TRUE
	attack_verb = list("thwacked", "hit", "clonked", "batted", "tapped", "smacked", "poked", "slapped")
	hitsound = 'sound/weapons/kick.ogg'
	drawsound = 'sound/items/unholster_sword01.ogg'
	sharp = FALSE
	edge = FALSE
	default_material = "bamboo"

/obj/item/weapon/material/sword/training/attack_self(mob/user)
	..()
	edge = FALSE
	sharp = FALSE

/obj/item/weapon/material/sword/katana
	name = "katana"
	desc = "A sword used by the japanese for centuries. Made to slice and slash, not chop or saw."
	icon_state = "katana"
	item_state = "katana"
	block_chance = 27
	force_divisor = 0.8 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	value = 60
	cooldownw = 7

obj/item/weapon/material/sword/wakazashi
	name = "wakazashi"
	desc = "A sword used by the japanese for centuries. Made to slice and slash, not chop or saw. Often paired with a katana."
	icon_state = "wakazashi"
	item_state = "wakazashi"
	block_chance = 19
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT
	value = 60
	cooldownw = 6

obj/item/weapon/material/sword/wakazashi/yakuza
	slot_flags = SLOT_BELT | SLOT_BACK

/obj/item/weapon/material/sword/katana/iron
	default_material = "iron"

/obj/item/weapon/material/sword/smallsword
	name = "small sword"
	desc = "A common european sword, with about one meter in length."
	icon_state = "smallsword"
	item_state = "smallsword"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.6 // 36 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.8 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 25
	cooldownw = 6
	value = 35

obj/item/weapon/material/sword/smallsword/iron
	default_material = "iron"

obj/item/weapon/material/sword/smallsword/copper
	default_material = "copper"

obj/item/weapon/material/sword/smallsword/bronze
	default_material = "bronze"

/obj/item/weapon/material/sword/spadroon
	name = "spadroon"
	desc = "A medium sword with a straight blade. Common among the military."
	icon_state = "spadroon"
	item_state = "longsword2"
	throw_speed = 3
	throw_range = 3
	force_divisor = 0.8 // 48 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 40
	cooldownw = 9
	value = 50

obj/item/weapon/material/sword/spadroon/iron
	default_material = "iron"

obj/item/weapon/material/sword/spadroon/copper
	default_material = "copper"

obj/item/weapon/material/sword/spadroon/bronze
	default_material = "bronze"

/obj/item/weapon/material/sword/armingsword
	name = "arming sword"
	desc = "A very common medieval medium-sized sword."
	icon_state = "armingsword"
	item_state = "longsword2"
	throw_speed = 3
	throw_range = 3
	force_divisor = 0.9 // 48 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.45 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 37
	cooldownw = 11
	value = 50

obj/item/weapon/material/sword/armingsword/iron
	default_material = "iron"

obj/item/weapon/material/sword/armingsword/copper
	default_material = "copper"

obj/item/weapon/material/sword/armingsword/bronze
	default_material = "bronze"

/obj/item/weapon/material/sword/vikingsword
	name = "carolingian sword"
	desc = "A medium-size sword with a rounded tip used by the vikings."
	icon_state = "viking_sword"
	item_state = "longsword2"
	throw_speed = 3
	throw_range = 2
	force_divisor = 0.10 // 48 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.45 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 38
	cooldownw = 11
	value = 60

obj/item/weapon/material/sword/vikingsword/iron
	default_material = "iron"

obj/item/weapon/material/sword/vikingsword/copper
	default_material = "copper"

obj/item/weapon/material/sword/vikingsword/bronze
	default_material = "bronze"


/obj/item/weapon/material/sword/mersksword
	name = "mersks sword"
	desc = "A very common medieval medium-sized sword."
	icon_state = "mersksword"
	item_state = "longsword2"
	throw_speed = 3
	throw_range = 3
	force_divisor = 0.11 // 48 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.45 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 40
	cooldownw = 13
	value = 50

/obj/item/weapon/material/sword/vangar
	name = "Vangar's sword"
	desc = "A special, customized sword with 'Vangar' engraved on the hilt."
	icon_state = "vangar"
	item_state = "longsword2"
	throw_speed = 4
	throw_range = 4
	force_divisor = 0.75 // 45 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 35
	cooldownw = 7

/obj/item/weapon/material/sword/bolo
	name = "bolo"
	desc = "A very common filipino machete like sword."
	icon_state = "bolo"
	item_state = "bolo"
	throw_speed = 3
	throw_range = 6
	force_divisor = 0.9 // 48 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.45 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 37
	cooldownw = 9
	value = 30
	chopping_speed = 1.9

/obj/item/weapon/material/sword/bolo/iron
	default_material = "iron"
	value = 25

/obj/item/weapon/material/sword/kukri
	name = "kukri"
	desc = "A very distinctly shaped machete originating in the outback for hacking through thick brush."
	icon_state = "kukri"
	item_state = "kukri"
	throw_speed = 3
	throw_range = 6
	force_divisor = 0.9 // 48 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.45 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 37
	cooldownw = 9
	value = 30
	chopping_speed = 1.9

/obj/item/weapon/material/sword/kukri/iron
	default_material = "iron"
	value = 25

/obj/item/weapon/material/sword/cutlass
	name = "cutlass"
	desc = "A medium-sized, curved sword, preferred by pirates."
	icon_state = "cutlass"
	item_state = "cutlass"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.6 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 28
	cooldownw = 8
	value = 40

obj/item/weapon/material/sword/cutlass/iron
	default_material = "iron"

/obj/item/weapon/material/sword/scimitar
	name = "scimitar"
	desc = "A medium-sized, curved sword, preferred by arabs."
	icon_state = "scimitar"
	item_state = "sabre"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.7 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 30
	cooldownw = 8
	value = 45

obj/item/weapon/material/sword/scimitar/iron
	default_material = "iron"

/obj/item/weapon/material/sword/longquan
	name = "longquan"
	desc = "A medium-sized oriental sword; preferred by chinese warriors & soldiers."
	icon_state = "longquan"
	item_state = "longquan"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.7 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 30
	cooldownw = 8
	value = 45

/obj/item/weapon/material/sword/longquan/iron
	default_material = "iron"
	value = 40

/obj/item/weapon/material/sword/plasmaquan
	name = "Plasmaquan"
	desc = "A sword based on the longquan."
	icon_state = "plasmaquan"
	item_state = "plasmaquan"
	throw_speed = 2
	throw_range = 4
	force_divisor = 1.2 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BACK
	block_chance = 40
	cooldownw = 7
	value = 100

/obj/item/weapon/material/sword/longquan/iron
	default_material = "iron"
	value = 40

/obj/item/weapon/material/sword/saif
	name = "saif"
	desc = "A medium sword, original from the arab peninsula."
	icon_state = "umar_sword"
	item_state = "umar_sword"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.8 // 45 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.6 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 34
	cooldownw = 9
	value = 60

obj/item/weapon/material/sword/saif/iron
	default_material = "iron"

/obj/item/weapon/material/sword/sabre
	name = "sabre"
	desc = "A small, slightly curved sword, favored by cavalry and light infantry units."
	icon_state = "sabre"
	item_state = "sabre"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.75 // 45 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.6 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 32
	cooldownw = 9
	value = 50

obj/item/weapon/material/sword/sabre/iron
	default_material = "iron"

/obj/item/weapon/material/sword/longsword
	name = "longsword"
	desc = "A sword with a long blade. Commonly used in the medieval era."
	icon_state = "longsword"
	item_state = "longsword"
	throw_speed = 2
	throw_range = 2
	force_divisor = 1 // 60 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 47
	cooldownw = 15
	value = 60

obj/item/weapon/material/sword/longsword/iron
	default_material = "iron"

obj/item/weapon/material/sword/longsword/bronze
	default_material = "bronze"

obj/item/weapon/material/sword/longsword/diamond
	default_material = "diamond"

/obj/item/weapon/material/sword/zweihander
	name = "Zweihander"
	desc = "A German sword used by knights."
	icon_state = "zweihander"
	item_state = "longsword"
	throw_speed = 1
	throw_range = 2
	force_divisor = 1.90 // 60 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 60
	cooldownw = 30
	value = 60

/obj/item/weapon/material/sword/claymore
	name = "claymore"
	desc = "A Scottish longsword."
	icon_state = "claymore"
	item_state = "longsword"
	throw_speed = 1
	throw_range = 2
	force_divisor = 1.80 // 60 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 65
	cooldownw = 20
	value = 60

obj/item/weapon/material/sword/claymore/iron
	default_material = "iron"


/obj/item/weapon/material/sword/rapier
	name = "rapier"
	desc = "A light sword with a thin, stright blade. Commonly used by officers and nobility."
	icon_state = "rapier"
	item_state = "rapier"
	throw_speed = 4
	throw_range = 4
	force_divisor = 0.65 // 40 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.8 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 30
	cooldownw = 5
	value = 60

obj/item/weapon/material/sword/rapier/iron
	default_material = "iron"

/obj/item/weapon/material/sword/broadsword
	name = "broadsword"
	desc = "A sword with a long thick blade. Commonly used in the medieval era."
	icon_state = "broadsword"
	item_state = "longsword"
	throw_speed = 2
	throw_range = 2
	force_divisor = 2.2 // 60 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 20
	cooldownw = 15
	value = 60

/* Ancient Multi Material Swords */
// Created as per template then subtypes for spawning into TDM & admin debug access.

/obj/item/weapon/material/sword/gladius
	name = "gladius"
	desc = "A relatively small sword, used by Roman soldiers."
	icon_state = "gladius"
	item_state = "gladius"
	throw_speed = 2
	throw_range = 6
	force_divisor = 0.6 // 36 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.8 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 25
	cooldownw = 6
	value = 35

/obj/item/weapon/material/sword/gladius/bronze
	default_material = "bronze"

/obj/item/weapon/material/sword/gladius/iron
	default_material = "iron"

/obj/item/weapon/material/sword/gaelic
	name = "gaelic shortsword"
	desc = "A relatively small sword with a dramatic hilt, used by Gaelic warriors."
	icon_state = "gaelic_short"
	item_state = "gaelic_short"
	throw_speed = 2
	throw_range = 6
	force_divisor = 0.6 // 36 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.8 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 25
	cooldownw = 6
	value = 35

/obj/item/weapon/material/sword/gaelic/bronze
	default_material = "bronze"

/obj/item/weapon/material/sword/gaelic/iron
	default_material = "iron"

/obj/item/weapon/material/sword/khopesh //template for multi-material crafting
	name = "khopesh"
	desc = "A curved sword, used by soldiers of egyptian dynasties & desert warriors."
	icon_state = "khopesh"
	item_state = "khopesh"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.75 // 36 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.7 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 28
	cooldownw = 7
	value = 40

/obj/item/weapon/material/sword/khopesh/bronze
	default_material = "bronze"

/obj/item/weapon/material/sword/khopesh/iron
	default_material = "iron"

/obj/item/weapon/material/sword/xiphos //template for multi-material crafting
	name = "xiphos"
	desc = "A small sword, used by hellenic soldiers."
	icon_state = "xiphos"
	item_state = "gladius"
	throw_speed = 2
	throw_range = 4
	force_divisor = 0.75 // 36 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.7 // 10 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 28
	cooldownw = 7
	value = 40

/obj/item/weapon/material/sword/xiphos/bronze
	default_material = "bronze"

/obj/item/weapon/material/sword/xiphos/iron
	default_material = "iron"

//////////////////////////////////SKYRIM////////////////////////////////////////
/obj/item/weapon/material/sword/tes13/twohanded
	name = "twohanded steel sword"
	desc = "A sword with a long blade and handle meant to be used with 2 hands."
	icon_state = "twohanded"
	item_state = "twohanded"
	throw_speed = 2
	throw_range = 2
	force_divisor = 1.1 // 60 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 50
	cooldownw = 15
	value = 60

/obj/item/weapon/material/sword/tes13/steel
	name = "imperial steel sword"
	desc = "A sword with a steel blade commonly used by the empire."
	icon_state = "imperial"
	item_state = "longsword"
	throw_speed = 2
	throw_range = 2
	force_divisor = 0.80 //
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 20
	cooldownw = 8
	value = 60

/obj/item/weapon/material/sword/tes13/steel/balgruuf
	name = "balgruuf's imperial steel sword"
	desc = "A sword with a steel blade commonly used by the empire. This one was especially forged for balgruuf."
	icon_state = "imperial"
	item_state = "longsword"
	throw_speed = 2
	throw_range = 2
	force_divisor = 1 //
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	force = 100
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 20
	cooldownw = 8
	value = 500

//////////////////////////////////GAME OF THRONES////////////////////////////////////////
/obj/item/weapon/material/sword/longclaw
	name = "longclaw"
	desc = "The Longclaw is a ancestral Valyrian steel bastard sword from the house of mormont."
	icon_state = "longclaw"
	item_state = "longsword"
	throw_speed = 2
	throw_range = 2
	force_divisor = 1 // 60 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 50
	cooldownw = 11
	value = 400
