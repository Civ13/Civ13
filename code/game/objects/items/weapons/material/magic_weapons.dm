//Staves and Special Weapons
/obj/item/weapon/material/sword/magic
	name = "Hypothetical Magic Sword"
	desc = "This is a place holder for code don't use it as an item."
	icon = 'icons/obj/magicweapons.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_magic.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_magic.dmi',
		)
	icon_state = "energy_blade"
	item_state = "energy_blade"
	var/base_icon = "energy_blade"
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
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
			//M.adjustFireLoss(rand(2,10))
			if (prob(flamepower))
				M.fire_stacks += 1
			M.IgniteMob()
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 75, TRUE)
			cooloff = world.time+flamepower
	if(prob(ices))
		M.adjustFireLoss(icepower)
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
	force_divisor = 1.5 // 42 when wielded with hardnes 60 (steel)
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
	force_divisor = 1.5 // 42 when wielded with hardnes 60 (steel)
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
	force_divisor = 1.5 // 42 when wielded with hardnes 60 (steel)
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
	force_divisor = 1.5 // 42 when wielded with hardnes 60 (steel)
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
	force_divisor = 1.6 // 42 when wielded with hardnes 60 (steel)
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

// Odis' Beamblade collection

/obj/item/weapon/material/sword/magic/onoff
	name = "White Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of pure light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	var/overlay = 'icons/obj/magicoverlay.dmi'
	var/overlay_icon = 'icons/obj/magicoverlay.dmi'
	var/set_light()
	var/old_force_divisor = 0.10
	var/old_thrown_force_divisor = 0.10
	var/old_force = 0
	var/old_sharpness = 0
	var/old_block_chance = 25
	var/old_damage = DAMAGE_MEDIUM

	var/new_damage = DAMAGE_OH_GOD
	var/new_force_divisor = 15
	var/new_thrown_force_divisor = 0.55 // 10 when thrown with weight 20 (steel)
	var/new_block_chance = 96
	var/new_force = 200
	var/new_sharpness = 500

	var/hitsound_off = 'sound/weapons/punch1.ogg' //default
	var/drawsound_off = 'sound/weapons/punch1.ogg' //temp

	var/hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	var/drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	var/onsound = 'sound/weapons/magic/LS_On.ogg'
	var/offsound = 'sound/weapons/magic/LS_Off.ogg'
	var/suicide = FALSE

	var/state = "OFF"
	var/on_state = "beamblade"
	var/on_state_item = "beamblade"
	var/off_state = "beamblade_off"
	var/off_state_item = ""

/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		new_force = 200
		new_damage = DAMAGE_OH_GOD
		state = "ON"
		sharp = TRUE
		edge = TRUE
		atk_mode = SLASH
		set_light(2, 0.25, "#FFFFFF")
		update_icon()
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		old_force = 0
		old_damage = DAMAGE_MEDIUM
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
		update_icon()
	..()

obj/item/weapon/material/sword/magic/onoff/blue
	name = "Blue Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of blue light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "bluebeamblade"
	on_state_item = "bluebeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#0000FF")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/red
	name = "Red Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of red light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "redbeamblade"
	on_state_item = "redbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#FF0000")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/green
	name = "Green Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of green light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "greenbeamblade"
	on_state_item = "greenbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#00FF00")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/lightgreen
	name = "Light Green Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of light green light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "lightgreenbeamblade"
	on_state_item = "lightgreenbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#90EE90")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/darkgreen
	name = "Dark Green Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of dark green light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "darkgreenbeamblade"
	on_state_item = "darkgreenbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#013220")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/purple
	name = "Purple Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of purple light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "purplebeamblade"
	on_state_item = "purplebeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#800080")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/teal
	name = "Teal Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of teal light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "tealbeamblade"
	on_state_item = "tealbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#008080")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/cyan
	name = "Cyan Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of cyan light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "cyanbeamblade"
	on_state_item = "cyanbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#00FFFF")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/magenta
	name = "Magenta Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of magenta light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "magentabeamblade"
	on_state_item = "magentabeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#FF00FF")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/redpink
	name = "Reddish Pink Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of reddish pink light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "redpinkbeamblade"
	on_state_item = "redpinkbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#ffc0cb")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/yellow
	name = "Yellow Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of yellow light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "yellowbeamblade"
	on_state_item = "yellowbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#FFFF00")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/gold
	name = "Gold Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of gold light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "goldbeamblade"
	on_state_item = "goldbeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#FFD700")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/orange
	name = "Orange Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of orange light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "orangebeamblade"
	on_state_item = "orangebeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "OFF")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#FFA500")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/darkorange
	name = "Dark Orange Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of dark orange light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "darkorangebeamblade"
	on_state_item = "darkorangebeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#ff8c00")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

obj/item/weapon/material/sword/magic/onoff/bronze
	name = "Bronze Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	base_icon = "beamblade_off"
	cooldownw = DEFAULT_QUICK_COOLDOWN
	desc = "A blade made of bronze light contained by a strange force."
	atk_mode = BASH
	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	overlay = 'icons/obj/magicoverlay.dmi'
	overlay_icon = 'icons/obj/magicoverlay.dmi'

	old_force_divisor = 0.10
	old_thrown_force_divisor = 0.10
	old_sharpness = 0
	old_block_chance = 25

	new_force_divisor = 10
	new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	new_block_chance = 95
	new_sharpness = 100

	hitsound_off = 'sound/weapons/punch1.ogg' //default
	drawsound_off = 'sound/weapons/punch1.ogg' //temp

	hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	onsound = 'sound/weapons/magic/LS_On.ogg'
	offsound = 'sound/weapons/magic/LS_Off.ogg'

	state = "OFF"
	on_state = "bronzebeamblade"
	on_state_item = "bronzebeamblade"
	off_state = "beamblade_off"
	off_state_item = ""
/obj/item/weapon/material/sword/magic/onoff/attack_self()
	if(state == "ON")
		icon_state = on_state
		item_state = on_state_item
		force_divisor = new_force_divisor
		thrown_force_divisor = new_thrown_force_divisor
		sharpness = new_sharpness
		block_chance = new_block_chance
		playsound(loc, onsound, 100, TRUE)
		hitsound = hitsound_on
		drawsound = drawsound_on
		state = "ON"
		sharp = TRUE
		edge = TRUE
		set_light(2, 0.25, "#CD7F32")
		atk_mode = SLASH
	else
		icon_state = off_state
		item_state = off_state_item
		force_divisor = old_force_divisor
		thrown_force_divisor = old_thrown_force_divisor
		sharpness = old_sharpness
		block_chance = old_block_chance
		playsound(loc, offsound, 100, TRUE)
		hitsound = hitsound_off
		drawsound = drawsound_off
		state = "OFF"
		sharp = FALSE
		edge = FALSE
		atk_mode = BASH
	..()

//WANDS
/obj/item/weapon/material/magic/wand
	name = "Magic Wand"
	desc = "Sparkly."
	icon = 'icons/obj/magicweapons.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_magic.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_magic.dmi',
		)
	icon_state = "wand_shaman"
	item_state = "wand_shaman"
	slot_flags = SLOT_BACK
	force_divisor = 0.7 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	block_chance = 35
	attack_verb = list("bonked", "batted", "hit", "whacked")
	hitsound = 'sound/effects/woodhit.ogg'
	drawsound = null
	default_material = null
	var/magic_state = "Spark" //this switches according to spell.
	var/magic_state_stage //stage of state.
	var/magic_spell_amount = 4 //How many spells are in the wand.
	var/low_spell_list = list("Spark", "Flare", "Root", "Ice Shard") //Magic stat 0-75
	var/med_spell_list = list("Shock Bolt", "Fire Bolt", "Vine Shot", "Ice Blast") //Magic stat 75 - 125
	var/hig_spell_list = list("Lightning Strike", "Fire Ball", "Ensnare", "Frozen Rain") //Magic stat 125 - 200
	var/active_spell_list = list()
	var/maxcharges = 10 //How many times you can cast spells without waiting.
	var/chargetime = 60 //How long in seconds it takes to recharge a charge
	var/castdelay = 8 //antispam measure.
	var/casting = FALSE //check if we are casting.
	var/minimum_level = 0 //Minimum required magic level.
	var/charges
	var/gem //this will hold the gem, which will directly influence spell lists and description along with icon.
	New()
		active_spell_list = low_spell_list
		charges = maxcharges //fill 'er up.
		default_material = null

//Utility
/obj/item/weapon/material/magic/wand/examine(mob/user as mob)
	var/mob/living/human/H = user
	user << "<span class='notice'>[desc]</span>"
	user << "<span class='notice'>The currently active spell is [magic_state]</span>"
	if(H.getStat("magic") <= 100)
		user << "<span class='notice'>You cannot detect anything about the wands spells.</span>"
	else
		user << "<span class='notice'>The wand has the spells [active_spell_list] active spells.</span>"
	//How many uses are left.
	if(H.getStat("magic") <= 100)
		if(charges >= maxcharges / 1.5)
			user << "<span class='notice'>The wand feels <font color=#9fe6f5>full</font>!</span>"
		else if(charges >= maxcharges / 1.75)
			user << "<span class='notice'>The wand feels <font color=#9fe6f5>somewhat full</font>!</span>"
		else if(charges >= maxcharges / 3)
			user << "<span class='notice'>The wand feels <font color=#9fe6f5>faint</font>!</span>"
		else
			user << "<span class='notice'>The wand feels <font color=#9fe6f5>dead</font>!</span>"
	else if(H.getStat("magic") <= 150)
		if(charges >= maxcharges / 1.25)
			user << "<span class='notice'>The wand looks <font color=#9fe6f5>very full</font>!</span>"
		else if(charges >= maxcharges / 1.5)
			user << "<span class='notice'>The wand looks <font color=#9fe6f5>full</font>!</span>"
		else if(charges >= maxcharges / 1.75)
			user << "<span class='notice'>The wand looks <font color=#9fe6f5>mostly full</font>!</span>"
		else if(charges >= maxcharges / 2)
			user << "<span class='notice'>The wand looks <font color=#9fe6f5>partially full</font>!</span>"
		else if(charges >= maxcharges / 2.5)
			user << "<span class='notice'>The wand looks <font color=#9fe6f5>half-empty</font>!</span>"
		else if(charges >= maxcharges / 3)
			user << "<span class='notice'>The wand looks <font color=#9fe6f5>somewhat empty</font>!</span>"
		else if(charges >= maxcharges / 4)
			user << "<span class='notice'>The wand feels <font color=#9fe6f5>halfway empty</font>!</span>"
		else if(charges >= maxcharges / 5)
			user << "<span class='notice'>The wand feels <font color=#9fe6f5>almost empty</font>!</span>"
		else
			user << "<span class='notice'>The wand feels <font color=#9fe6f5>empty</font>!</span>"
	else if(H.getStat("magic") <= 200)
		user << "<span class='notice'>The wand has <font color=#9fe6f5>[charges] charges left!</font>!</span>"
	else
		user << "<span class='notice'>The wand has <font color=#9fe6f5>[charges]</font> out of <font color=#9fe6f5>[maxcharges] charges left!</font>!</span>"

/obj/item/weapon/material/magic/wand/attackby(obj/item/W as obj, mob/user as mob)
	//Switch spell
	magic_state_stage++
	if(magic_state_stage > magic_spell_amount)
		magic_state_stage = 1
	user << "<span class='notice'>Spell set to [active_spell_list[magic_state_stage]]!</span>"
	magic_state = active_spell_list[magic_state_stage]

/obj/item/weapon/material/magic/wand/attack(obj/item/W as obj, mob/user as mob)
	//if charges > 0, casting = true spawn(castdelay), CASTING = false, shoot projectile.

/obj/item/weapon/material/magic/wand/proc/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params=null)

	var/obj/item/projectile/P = projectile

	if (!istype(P))
		return FALSE //default behaviour only applies to true projectiles

	if (params)
		P.set_clickpoint(params)

	//shooting while in shock
	var/x_offset = 0
	var/y_offset = 0
	if (istype(user, /mob/living/human))
		var/mob/living/human/mob = user
		if (mob.shock_stage > 120)
			y_offset = rand(-2,2)
			x_offset = rand(-2,2)
		else if (mob.shock_stage > 70)
			y_offset = rand(-1,1)
			x_offset = rand(-1,1)

	return !P.launch(target, user, src, target_zone, x_offset, y_offset)