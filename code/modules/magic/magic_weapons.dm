//Staves and Special Weapons
/obj/item/weapon/material/sword/magic
	name = "Hypothetical Magic Sword"
	desc = "This is a place holder for code don't use it as an item."
	icon = 'icons/obj/magic_weapons.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_magic.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_magic.dmi',
		)
	icon_state = "energy_blade"
	item_state = "energy_blade"
	var/base_icon = "energy_blade"
	force_divisor = 0.7 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	hitsound = 'sound/weapons/bladeslice.ogg'
	drawsound = 'sound/items/unholster_sword01.ogg'
	sharpness = 50
	default_material = "diamond"
	applies_material_colour = FALSE
	cooldownw = DEFAULT_ATTACK_COOLDOWN //how long till you can attack again
	//ability vars
	var/weakens = 0
	var/flames = 0
	var/ices = 0
	var/toxics = 0
	var/leechs = 0
	var/shocks = 0
	//other
	var/reagent1 = ""
	var/reagent2 = ""
	//potentialdamagevars
	var/weakenpower = 0
	var/flamepower = 0
	var/icepower = 0
	var/toxicpower = 0
	var/leechpower = 0
	var/shockpower = 0
	//cooloff
	var/reagent1amount = 0
	var/reagent2amount = 0
	var/cooloff = 0
	unbreakable = TRUE


/obj/item/weapon/material/sword/magic/attack(mob/living/human/M as mob, mob/living/user as mob)
	..()
	if(prob(weakens))
		M.Weaken(weakenpower)
	if(prob(flames))
		if (world.time > cooloff)
			//M.adjustBurnLoss(rand(2,10))
			if (prob(flamepower))
				M.fire_stacks += 1
			M.IgniteMob()
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 75, TRUE)
			cooloff = world.time+flamepower
	if(prob(ices))
		M.adjustBurnLoss(icepower)
		playsound(loc, 'sound/effects/bubbles.ogg', 75, TRUE)
		M.bodytemperature -= (icepower)
	if(prob(toxics))
		M.reagents.add_reagent(reagent1, (prob(toxicpower) + reagent1amount))
		M.reagents.add_reagent(reagent2, (prob(toxicpower) + reagent2amount))
		playsound(loc, 'sound/effects/Splash_Small_01_mono.ogg', 75, TRUE)
	if(prob(leechs))
		user.health += prob(leechpower)
		user.updatehealth()
		M.health -= prob(leechpower)
		M.updatehealth()
		playsound(loc, 'sound/effects/refill.ogg', 75, TRUE)
	if(prob(shocks))
		M.electrocute_act(shockpower, src, 1.0)
		if(prob(25))
			playsound(loc, 'sound/effects/sparks1.ogg', 75, TRUE)
		else if(prob(25))
			playsound(loc, 'sound/effects/sparks2.ogg', 75, TRUE)
		else if(prob(25))
			playsound(loc, 'sound/effects/sparks3.ogg', 75, TRUE)
		else
			playsound(loc, 'sound/effects/sparks4.ogg', 75, TRUE)
//Swords

/obj/item/weapon/material/sword/magic/New(var/newloc, var/material_key)
	material = null
	..()
	material = null

/obj/item/weapon/material/sword/magic/arkofdisease
	name = "Ark of Disease"
	icon_state = "ark_of_disease"
	item_state = "ark_of_disease"
	base_icon = "ark_of_disease"
	desc = "It pulses ominously, you feel sick just by looking at it."
	force_divisor = 1.5 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.45 // 10 when thrown with weight 20 (steel)
	sharpness = 25
	block_chance = 35
	toxics = 100
	toxicpower = 100
	reagent1 = "lexorin"
	reagent2 = "plague"
	reagent1amount = 25
	reagent2amount = 5

/obj/item/weapon/material/sword/magic/arkofdisease/lesser
	name = "Curve of Infection"
	toxics = 40
	toxicpower = 15
	reagent1 = "cryptobiolin"
	reagent2 = "typhus"
	reagent1amount = 15
	reagent2amount = 5
	default_material = "iron"
	material = "iron"
	applies_material_colour = TRUE



/obj/item/weapon/material/sword/magic/crimsonedge
	name = "Crimson Edge"
	icon_state = "crimson_edge"
	item_state = "crimson_edge"
	base_icon = "crimson_edge"
	desc = "It looks like it is bleeding.."
	force_divisor = 1.5
	thrown_force_divisor = 0.60 // 10 when thrown with weight 20 (steel)
	sharpness = 35
	block_chance = 38
	leechs = 100
	leechpower = 100

/obj/item/weapon/material/sword/magic/crimsonedge/lesser
	name = "Red Razer"
	leechs = 40
	leechpower = 15
	default_material = "iron"
	applies_material_colour = TRUE

/obj/item/weapon/material/sword/magic/swordsmansflame
	name = "Swordsman's Flame"
	icon_state = "swordsmans_flame"
	item_state = "cultblade"
	base_icon = "cultblade"
	desc = "The blade feels cool but looks like it's red hot."
	force_divisor = 1.5 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.60 // 10 when thrown with weight 20 (steel)
	sharpness = 40
	block_chance = 40
	flames = 100
	flamepower = 100
	light_color = "#da0205"
	light_range = 2


/obj/item/weapon/material/sword/magic/swordsmansflame/lesser
	name = "Soldier's Ember"
	default_material = "iron"
	flames = 40
	flamepower = 15
	applies_material_colour = TRUE

/obj/item/weapon/material/sword/magic/ice
	name = "Greater Icicle"
	icon_state = "sord"
	item_state = "sord"
	base_icon = "sord"
	desc = "Your breath mists as it nears the blade."
	force_divisor = 1.5 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.60 // 10 when thrown with weight 20 (steel)
	sharpness = 40
	block_chance = 40
	ices = 100
	icepower = 60

/obj/item/weapon/material/sword/magic/ice/lesser
	name = "Lesser Icicle"
	default_material = "iron"
	ices = 40
	icepower = 15
	applies_material_colour = TRUE

/obj/item/weapon/material/sword/magic/elec
	name = "Sheet Lightning"
	icon_state = "elec"
	item_state = "elec"
	base_icon = "elec"
	desc = "Holding this blade makes your small hairs stand on end."
	force_divisor = 1.5 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.60 // 10 when thrown with weight 20 (steel)
	sharpness = 40
	block_chance = 40
	shocks = 100
	shockpower = 150

/obj/item/weapon/material/sword/magic/elec/lesser
	name = "Sparking Blade"
	default_material = "iron"
	shocks = 45
	shockpower = 15
	applies_material_colour = TRUE

//blunt//
/obj/item/weapon/material/sword/magic/mjolnir
	name = "Mjolnir"
	default_material = "steel"
	icon_state = "mjolnir"
	item_state = "hammer"
	base_icon = "mjolnir"
	desc = "Only for the worthy."
	slot_flags = SLOT_BELT
	force_divisor = 1.6 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 1.2 // 10 when thrown with weight 20 (steel)
	attack_verb = list("bashed","struck","beaten")
	hitsound = 'sound/items/trayhit2.ogg'
	drawsound = 'sound/items/trayhit1.ogg'
	sharpness = 0
	block_chance = 10
	shocks = 100
	shockpower = 150
	cooldownw = 12
	unbreakable = TRUE

/obj/item/weapon/material/sword/magic/mjolnir/lesser
	name = "Mjolnir"
	shocks = 45
	shockpower = 15
