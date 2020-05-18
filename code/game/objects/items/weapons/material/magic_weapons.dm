//Staves and Special Weapons
/obj/item/weapon/material/sword/magic
	name = "Magic Sword"
	desc = "Shiny"
	icon = 'icons/obj/magicweapons.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_magic.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_magic.dmi',
		)
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
	default_material = null
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

/obj/item/weapon/material/sword/magic/New()
	..()
	default_material = null

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
	desc = "It pulses ominously, you feel sick just by looking at it."
	force_divisor = 0.50 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.45 // 10 when thrown with weight 20 (steel)
	sharpness = 25
	block_chance = 35
	toxics = 25
	toxicpower = 15
	reagent1 = "food_poisoning"
	reagent2 = "cholera"
	reagent1amount = 10
	reagent2amount = 5


/obj/item/weapon/material/sword/magic/crimsonedge
	name = "Crimson Edge"
	icon_state = "crimson_edge"
	item_state = "crimson_edge"
	desc = "It looks like it is bleeding.."
	force_divisor = 0.60 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.60 // 10 when thrown with weight 20 (steel)
	sharpness = 35
	block_chance = 38
	leechs = 20
	leechpower = 20

/obj/item/weapon/material/sword/magic/swordsmansflame
	name = "Swordsman's Flame"
	icon_state = "swordsmans_flame"
	item_state = "swordsmans_flame"
	desc = "The blade feels cool but looks like it's red hot."
	force_divisor = 0.65 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.60 // 10 when thrown with weight 20 (steel)
	sharpness = 40
	block_chance = 40
	flames = 35
	flamepower = 50

/obj/item/weapon/material/sword/magic/onoff
	name = "Beam Blade"
	icon_state = "beamblade_off"
	item_state = "beamblade_off"
	desc = "A blade made of pure energy"

	force_divisor = 0.10
	thrown_force_divisor = 0.10
	sharpness = 0
	block_chance = 25

	var/overlay = 'icons/obj/magicoverlay.dmi'
	var/overlay_icon = 'icons/obj/magicoverlay.dmi'

	var/old_force_divisor = 0.10
	var/old_thrown_force_divisor = 0.10
	var/old_sharpness = 0
	var/old_block_chance = 25

	var/new_force_divisor = 0.25 // 42 when wielded with hardnes 60 (steel)
	var/new_thrown_force_divisor = 0.25 // 10 when thrown with weight 20 (steel)
	var/new_block_chance = 95
	var/new_sharpness = 100

	var/hitsound_off = 'sound/weapons/punch1.ogg' //default
	var/drawsound_off = 'sound/weapons/punch1.ogg' //temp

	var/hitsound_on = 'sound/weapons/magic/LS_Hit_1.ogg'
	var/drawsound_on = 'sound/weapons/magic/LS_On.ogg'

	var/onsound = 'sound/weapons/magic/LS_On.ogg'
	var/offsound = 'sound/weapons/magic/LS_Off.ogg'

	var/state = "OFF"
	var/on_state = "beamblade"
	var/on_state_item = "beamblade"
	var/off_state = "beamblade_off"
	var/off_state_item = ""

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