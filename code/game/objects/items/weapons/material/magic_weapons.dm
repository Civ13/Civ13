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


//WANDS
/obj/item/weapon/material/magic/wand
	name = "magic wand"
	desc = "Sparkly."
	icon = 'icons/obj/magic_weapons.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_magic.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_magic.dmi',
		)
	icon_state = "wand"
	item_state = "wand"
	slot_flags = SLOT_BELT
	force_divisor = 0.7 // 42 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.5 // 10 when thrown with weight 20 (steel)
	block_chance = 35
	attack_verb = list("bonked", "batted", "hit", "whacked")
	hitsound = 'sound/effects/woodhit.ogg'
	drawsound = null
	default_material = null
	secondary_action = TRUE
	var/magic_state = "Spark" // this switches according to spell.
	var/magic_state_stage // stage of state.
	var/list/low_spell_list = list("Spark", "Flare", "Root", "Ice Shard") // Magic stat 0-75
	var/list/med_spell_list = list("Shock Bolt", "Fire Bolt", "Vine Shot", "Ice Blast") // Magic stat 75 - 125
	var/list/hig_spell_list = list("Lightning Strike", "Fire Ball", "Ensnare", "Frozen Rain") // Magic stat 125 - 200
	var/list/active_spell_list = list()
	var/maxcharges = 10 // How many times you can cast spells without waiting.
	var/chargetime = 60 // How long in seconds it takes to recharge a charge
	var/castdelay = 8 // antispam measure.
	var/casting = FALSE // check if we are casting.
	var/minimum_level = 0 // Minimum required magic level.
	var/charges
	var/gem // this will hold the gem, which will directly influence spell lists and description along with icon.
	var/silencer = null
	var/chargetimer = 0

/obj/item/weapon/material/magic/wand/New()
	active_spell_list = low_spell_list
	charges = maxcharges //fill 'er up.
	default_material = null
	processing_objects |= src

/obj/item/weapon/material/magic/wand/Destroy()
	processing_objects -= src
	return ..()

/obj/item/weapon/material/magic/wand/process()
	if (charges >= maxcharges)
		chargetimer = 0
		return
	
	chargetimer += 2
	if (chargetimer >= chargetime)
		charges++
		chargetimer = 0
		if (istype(loc, /mob))
			to_chat(loc, SPAN_NOTICE("\The [src] crackles with magical energy, regaining a charge!"))

//Utility
/obj/item/weapon/material/magic/wand/examine(mob/user as mob)
	to_chat(user, SPAN_NOTICE("[desc]"))
	if (ishuman(user))
		var/mob/living/human/H = user
		to_chat(user, SPAN_NOTICE("The currently active spell is [magic_state]"))
		if (H.getStat("magic") <= 100)
			to_chat(user, SPAN_NOTICE("You cannot detect anything about the wands spells."))
		else
			to_chat(user, SPAN_NOTICE("The wand has the spells [active_spell_list] active spells."))

		
		//How many uses are left.
		var/fullness
		if(H.getStat("magic") < 100)
			if (charges >= maxcharges)
				fullness = "full"
			else if (charges >= maxcharges*0.75)
				fullness = "almost full"
			else if (charges >= maxcharges*0.50)
				fullness = "mostly full"
			else if (charges >= maxcharges*0.25)
				fullness = "partially empty"
			else if (charges > 0)
				fullness = "almost empty"
			else
				fullness = "empty"
			to_chat(user, SPAN_NOTICE("The wand looks <font color=#9fe6f5>[fullness]!</font>"))
		else
			to_chat(user, SPAN_NOTICE("The wand has <font color=#9fe6f5>[charges]</font> out of <font color=#9fe6f5>[maxcharges] charges left!</font>!"))
	else
		to_chat(user, SPAN_NOTICE("Eugh, magic disgusts you. Leave it to humans."))

/obj/item/weapon/material/magic/wand/secondary_attack_self(mob/living/human/user)
	//Switch spell
	magic_state_stage++
	if(magic_state_stage > active_spell_list.len)
		magic_state_stage = 1
	to_chat(user, SPAN_NOTICE("Spell set to [active_spell_list[magic_state_stage]]!"))
	magic_state = active_spell_list[magic_state_stage]

/obj/item/weapon/material/magic/wand/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!user || !target)
		return
	if (casting)
		return
	if (charges <= 0)
		to_chat(user, SPAN_WARNING("The wand is empty! It needs to recharge."))
		return
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.getStat("magic") < minimum_level)
			to_chat(user, SPAN_WARNING("You do not have the magical knowledge required to use this wand!"))
			return

	// Update active spell list based on magic level of the user if they are human
	if (ishuman(user))
		var/mob/living/human/H = user
		var/magic_lvl = H.getStat("magic")
		if (magic_lvl >= 125)
			active_spell_list = hig_spell_list
		else if (magic_lvl >= 75)
			active_spell_list = med_spell_list
		else
			active_spell_list = low_spell_list
		
		// Ensure current magic_state is valid for the current active list
		if (!active_spell_list.Find(magic_state))
			magic_state_stage = 1
			magic_state = active_spell_list[1]

	casting = TRUE
	user.visible_message(SPAN_WARNING("[user] begins chanting a spell with \the [src]!"), SPAN_NOTICE("You begin chanting [magic_state]..."))
	if(do_after(user, castdelay, target))
		if (charges > 0 && user.get_active_hand() == src)
			charges--
			user.visible_message(SPAN_WARNING("[user] casts [magic_state] from \the [src]!"), SPAN_NOTICE("You cast [magic_state]!"))
			
			// Play cast sound
			playsound(user.loc, 'sound/weapons/magic/LS_On.ogg', 50, TRUE)

			// Create and launch the projectile!
			var/obj/item/projectile/magic/P
			switch(magic_state)
				if("Spark")
					P = new /obj/item/projectile/magic/spark(user.loc)
				if("Flare")
					P = new /obj/item/projectile/magic/flare(user.loc)
				if("Root")
					P = new /obj/item/projectile/magic/root(user.loc)
				if("Ice Shard")
					P = new /obj/item/projectile/magic/ice_shard(user.loc)
				if("Shock Bolt")
					P = new /obj/item/projectile/magic/shock_bolt(user.loc)
				if("Fire Bolt")
					P = new /obj/item/projectile/magic/fire_bolt(user.loc)
				if("Vine Shot")
					P = new /obj/item/projectile/magic/vine_shot(user.loc)
				if("Ice Blast")
					P = new /obj/item/projectile/magic/ice_blast(user.loc)
				if("Lightning Strike")
					P = new /obj/item/projectile/magic/lightning_strike(user.loc)
				if("Fire Ball")
					P = new /obj/item/projectile/magic/fire_ball(user.loc)
				if("Ensnare")
					P = new /obj/item/projectile/magic/ensnare(user.loc)
				if("Frozen Rain")
					P = new /obj/item/projectile/magic/frozen_rain(user.loc)
			
			if (P)
				var/tgt_zone = "chest"
				if (ishuman(user))
					var/mob/living/human/H = user
					tgt_zone = H.targeted_organ
				process_projectile(P, user, target, tgt_zone, params)
	casting = FALSE

/obj/item/weapon/material/magic/wand/attack(mob/living/M, mob/living/user, var/target_zone)
	afterattack(M, user, TRUE)
	return TRUE

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

// Magic Projectile Definitions
/obj/item/projectile/magic
	name = "magic bolt"
	icon = 'icons/obj/magic_projectiles.dmi'
	icon_state = "spell"
	damage = 10
	damage_type = BURN
	nodamage = FALSE
	check_armor = "energy"
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/magic/spark
	name = "spark"
	icon_state = "spark"
	damage = 5
	damage_type = BURN

/obj/item/projectile/magic/spark/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(agony = 10, blocked = blocked)

/obj/item/projectile/magic/flare
	name = "flare"
	icon_state = "flare"
	damage = 12
	damage_type = BURN

/obj/item/projectile/magic/flare/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (ishuman(target))
			var/mob/living/human/H = target
			H.fire_stacks += 1
			H.IgniteMob()

/obj/item/projectile/magic/root
	name = "root spell"
	icon_state = "root"
	damage = 0
	nodamage = TRUE

/obj/item/projectile/magic/root/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(paralyze = 2, blocked = blocked)
			to_chat(L, SPAN_DANGER("Vines rise from the ground, rooting you in place!"))

/obj/item/projectile/magic/ice_shard
	name = "ice shard"
	icon_state = "ice_shard"
	damage = 10
	damage_type = BRUTE
	sharp = TRUE

/obj/item/projectile/magic/ice_shard/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.bodytemperature -= 60
			to_chat(L, SPAN_DANGER("You feel a sudden chilling cold!"))

/obj/item/projectile/magic/shock_bolt
	name = "shock bolt"
	icon_state = "shock"
	damage = 15
	damage_type = BURN

/obj/item/projectile/magic/shock_bolt/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(agony = 20, stun = 1, blocked = blocked)

/obj/item/projectile/magic/fire_bolt
	name = "fire bolt"
	icon_state = "fire"
	damage = 22
	damage_type = BURN

/obj/item/projectile/magic/fire_bolt/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (ishuman(target))
			var/mob/living/human/H = target
			H.fire_stacks += 2
			H.IgniteMob()

/obj/item/projectile/magic/vine_shot
	name = "vine shot"
	icon_state = "vines"
	damage = 5
	damage_type = BRUTE

/obj/item/projectile/magic/vine_shot/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(paralyze = 4, blocked = blocked)
			to_chat(L, SPAN_DANGER("Vines wrap tightly around you!"))

/obj/item/projectile/magic/ice_blast
	name = "ice blast"
	icon_state = "ice"
	damage = 18
	damage_type = BURN

/obj/item/projectile/magic/ice_blast/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.bodytemperature -= 120
			L.apply_effects(agony = 15, blocked = blocked)

/obj/item/projectile/magic/lightning_strike
	name = "lightning strike"
	icon_state = "lightning"
	damage = 35
	damage_type = BURN

/obj/item/projectile/magic/lightning_strike/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.electrocute_act(25, src, 1.0)

/obj/item/projectile/magic/fire_ball
	name = "fireball"
	icon_state = "fireball"
	damage = 30
	damage_type = BURN

/obj/item/projectile/magic/fire_ball/on_impact(var/atom/A)
	var/turf/T = get_turf(A)
	if (T)
		explosion(T, 0, 1, 2, 3)
	return ..()

/obj/item/projectile/magic/ensnare
	name = "ensnare spell"
	icon_state = "ensnare"
	damage = 10
	damage_type = BRUTE

/obj/item/projectile/magic/ensnare/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(paralyze = 6, weaken = 2, blocked = blocked)
			to_chat(L, SPAN_DANGER("You are completely ensnared in thick magical roots!"))

/obj/item/projectile/magic/frozen_rain
	name = "frozen rain"
	icon_state = "frozen_rain"
	damage = 30
	damage_type = BURN

/obj/item/projectile/magic/frozen_rain/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.bodytemperature -= 200
			L.apply_effects(paralyze = 2, agony = 30, blocked = blocked)