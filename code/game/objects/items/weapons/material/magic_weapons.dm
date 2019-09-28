//Staves and Special Weapons
/obj/item/weapon/material/sword/magic
	name = "Magic Sword"
	desc = "Shiny"
	icon = 'icons/obj/magicweapons.dmi'
	icon_state = "ark_of_disease"
	item_state = "ark_of_disease"
	slot_flags = SLOT_BELT
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	sharp = 1
	edge = 1
	atk_mode = SLASH
	block_chance = 35
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	hitsound = 'sound/weapons/bladeslice.ogg'
	drawsound = 'sound/items/unholster_sword01.ogg'
	sharpness = 50
	stat = "swords"
	cooldownw = DEFAULT_ATTACK_COOLDOWN //how long till you can attack again
	//ability vars
	var/weakens = 0
	var/flames = 0
	var/ices = 0
	var/toxics = 0
	var/leechs = 0
	//other
	var/reagent1 = ""
	var/reagent2 = ""
	//potentialdamagevars
	var/weakenpower = 0
	var/flamepower = 0
	var/icepower = 0
	var/toxicpower = 0
	var/leechpower = 0
	//cooloff
	var/reagent1amount = 0
	var/reagent2amount = 0
	var/cooloff = 0

/obj/item/weapon/material/sword/magic/attack(mob/living/carbon/human/M as mob, mob/living/user as mob)
	..()
	if(prob(weakens))
		M.Weaken(weakenpower)
	if(prob(flames))
		if (world.time > cooloff)
			//M.adjustFireLoss(rand(2,10))
			if (prob(flamepower))
				M.fire_stacks += 1
			M.IgniteMob()
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 75, TRUE)
			cooloff = world.time+flamepower
	if(prob(ices))
		M.adjustFireLoss(icepower)
	if(prob(toxics))
		M.reagents.add_reagent(reagent1, (prob(toxicpower) + reagent1amount))
		M.reagents.add_reagent(reagent2, (prob(toxicpower) + reagent2amount))
	if(prob(leechs))
		user.health += prob(leechpower)
		user.updatehealth()
		M.health -= prob(leechpower)
		M.updatehealth()

//Swords

/obj/item/weapon/material/sword/magic/arkofdisease
	name = "Ark of Disease"
	desc = "It pulses ominously, you feel sick just by looking at it."
	force_divisor = 0.85 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.65 // 10 when thrown with weight 20 (steel)
	sharpness = 35
	block_chance = 35
	toxics = 25
	toxicpower = 15
	reagent1 = "food_poisoning"
	reagent2 = "cholera"
	reagent1amount = 2
	reagent2amount = 1