
/*
	run_armor_check(a,b)
	args
	a:def_zone - What part is getting hit, if null will check entire body
	b:attack_flag - What type of attack, bullet, laser, energy, melee

	Returns
	0 - no block
	1 - halfblock
	2 - fullblock
*/
/mob/living/proc/run_armor_check(var/def_zone = null, var/attack_flag = "melee", var/armor_pen = FALSE, var/absorb_text = null, var/soften_text = null, var/obj/item/damage_source = null)
	if (armor_pen >= 100)
		return FALSE //might as well just skip the processing

	var/armor = getarmor(def_zone, attack_flag)
	var/absorb = FALSE

	//Roll armor
	if (prob(armor))
		absorb += 1
	if (prob(armor))
		absorb += 1

	//Roll penetration
	if (prob(armor_pen))
		absorb -= 1
	if (prob(armor_pen))
		absorb -= 1
	var/dmg = 0
	if (damage_source)
		if (istype(damage_source, /obj/item/weapon/melee) || istype(damage_source, /obj/item/weapon/material/hatchet))
			dmg = 8
		else
			dmg = 0.8
	if (absorb >= 2)
		if (istype(src, /mob/living/human))
			var/mob/living/human/H = src
			if(!(istype(damage_source,/obj/item/weapon/melee)))
				H.damage_armor(def_zone, dmg)
		if (absorb_text)
			show_message("[absorb_text]")
		else
			show_message("<span class='warning'>Your armor absorbs the blow!</span>")
		return 2
	if (absorb == TRUE)
		if (istype(src, /mob/living/human))
			var/mob/living/human/H = src
			if(!(istype(damage_source,/obj/item/weapon/melee)))
				H.damage_armor(def_zone, dmg)
		if (absorb_text)
			show_message("[soften_text]",4)
		else
			show_message("<span class='warning'>Your armor softens the blow!</span>")
		return TRUE
	return FALSE

//if null is passed for def_zone, then this should return something appropriate for all zones (e.g. area effect damage)
/mob/living/proc/getarmor(var/def_zone, var/type)
	return FALSE

/mob/living/bullet_act(var/obj/item/projectile/P, var/def_zone)

	var/mob/living/human/H = src
	if (istype(H.l_hand, /obj/item/weapon/material/sword/magic/onoff))
		var/obj/item/weapon/material/sword/magic/onoff/LS = H.l_hand
		if (LS.state == "ON")
			qdel(P)
	if (istype(H.r_hand, /obj/item/weapon/material/sword/magic/onoff))
		var/obj/item/weapon/material/sword/magic/onoff/LS = H.r_hand
		if (LS.state == "ON")
			qdel(P)
		return

	//"Stun-like" beams (used in tasers)
	if(P.taser_effect)
		stun_effect_act(P.stun, P.agony, def_zone, P)

	//Armor
	var/absorb = run_armor_check(def_zone, P.check_armor, P.armor_penetration, damage_source = P)
	var/proj_sharp = is_sharp(P)
	var/proj_edge = P.edge
	if ((proj_sharp || proj_edge) && prob(getarmor(def_zone, P.check_armor)))
		proj_sharp = FALSE
		proj_edge = FALSE

	var/damage = P.damage

	if (ishuman(src))
		if (H.takes_less_damage)
			damage /= H.getStatCoeff("strength")
		var/instadeath = 0
		if (def_zone == "eyes")
			instadeath = 10
		else if (def_zone == "mouth")
			instadeath = 10
		else if (def_zone == "head")
			instadeath = 5
		if (instadeath > 0)
			if (prob(instadeath))
				adjustBrainLoss(rand(30,60))
				H.instadeath_check()
	if (!P.nodamage)
		apply_damage(damage, P.damage_type, def_zone, absorb, P, sharp=proj_sharp, edge=proj_edge)

	P.on_hit(src, absorb, def_zone)

	return absorb

//Handles the effects of "stun" weapons
/mob/living/proc/stun_effect_act(var/stun_amount, var/agony_amount, var/def_zone, var/used_weapon=null)
	flash_pain()

	if (stun_amount)
		Stun(stun_amount)
		Weaken(stun_amount)
		apply_effect(STUTTER, stun_amount)
		apply_effect(EYE_BLUR, stun_amount)

	if (agony_amount)
		apply_damage(agony_amount, HALLOSS, def_zone, FALSE, used_weapon)
		apply_effect(STUTTER, agony_amount/10)
		apply_effect(EYE_BLUR, agony_amount/10)

/mob/living/proc/electrocute_act(var/shock_damage, var/obj/source, var/siemens_coeff = 1.0)
	  return FALSE //only carbon liveforms have this proc

/mob/living/emp_act(severity)
	var/list/L = get_contents()
	for (var/obj/O in L)
		O.emp_act(severity)
	..()

/mob/living/proc/resolve_item_attack(obj/item/I, mob/living/user, var/target_zone)
	return target_zone

//Called when the mob is hit with an item in combat. Returns the blocked result
/mob/living/proc/hit_with_weapon(obj/item/I, mob/living/user, var/effective_force, var/hit_zone)
	visible_message("<span class='danger'>[src] has been [I.attack_verb.len? pick(I.attack_verb) : "attacked"] with the [I.name] by [user]!</span>")

	var/blocked = run_armor_check(hit_zone, "melee", damage_source = I)
	standard_weapon_hit_effects(I, user, effective_force, blocked, hit_zone)


	return blocked

//returns FALSE if the effects failed to apply for some reason, TRUE otherwise.
/mob/living/proc/standard_weapon_hit_effects(obj/item/I, mob/living/user, var/effective_force, var/blocked, var/hit_zone)
	if (!effective_force || blocked >= 2)
		return FALSE

	//Apply weapon damage
	var/weapon_sharp = is_sharp(I)
	var/weapon_edge = I.edge
	if (prob(max(getarmor(hit_zone, "melee") - I.armor_penetration, FALSE))) //melee armor provides a chance to turn sharp/edge weapon attacks into blunt ones
		weapon_sharp = FALSE
		weapon_edge = FALSE

	apply_damage(effective_force, I.damtype, hit_zone, blocked, sharp=weapon_sharp, edge=weapon_edge, used_weapon=I)

	return TRUE

//this proc handles being hit by a thrown atom
/mob/living/hitby(atom/movable/AM as mob|obj,var/speed = THROWFORCE_SPEED_DIVISOR)//Standardization and logging -Sieve
	if (istype(AM,/obj/))
		var/obj/O = AM
		var/dtype = O.damtype
		var/throw_damage = O.throwforce*(speed/THROWFORCE_SPEED_DIVISOR)
		var/mob/living/human/M = null
		if (ishuman(O.thrower))
			M = O.thrower
		var/miss_chance = 15
		if (M)
			miss_chance = 15 - M.getStat("throwing")/100
		if (O.throw_source)
			var/distance = get_dist(O.throw_source, loc)
			miss_chance = max(15*(distance-2), FALSE)

		if (prob(miss_chance))
			visible_message("<span class = 'notice'>\The [O] misses [src] narrowly!</span>")
			playsound(src, "miss_sound", 50, TRUE, -6)
			return

		visible_message("<span class = 'red'>[src] has been hit by [O].</span>")
		var/armor = run_armor_check(null, "melee", damage_source = AM)

		if (armor < 2)
			apply_damage(throw_damage, dtype, null, armor, is_sharp(O), O.edge, O)

		O.throwing = FALSE		//it hit, so stop moving

		if (ismob(O.thrower) && M && M.client)
			var/client/assailant = M.client
			if (assailant)
				attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been hit with a [O], thrown by [M.name] ([assailant.ckey])</font>")
				M.attack_log += text("\[[time_stamp()]\] <font color='red'>Hit [name] ([ckey])([stat]) with a thrown [O]</font>")
				if (!istype(src,/mob/living/simple_animal/mouse))
					msg_admin_attack("[name] ([ckey]) was hit by a [O], thrown by [M.name] ([assailant.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>)", assailant.ckey, ckey)
		if (istype(O, /obj/item/weapon/snowball))
			O.icon_state = "snowball_hit"
			O.update_icon()
			spawn(6)
				qdel(O)
			return

		// Begin BS12 momentum-transfer code.
		var/mass = 1.5
		if (istype(O, /obj/item))
			var/obj/item/I = O
			mass = I.w_class/THROWNOBJ_KNOCKBACK_DIVISOR
		var/momentum = speed*mass

		if (O.throw_source && momentum >= THROWNOBJ_KNOCKBACK_SPEED)
			var/dir = get_dir(O.throw_source, src)

			visible_message("<span class = 'red'>[src] staggers under the impact!</span>","<span class = 'red'>You stagger under the impact!</span>")
			throw_at(get_edge_target_turf(src,dir),1,momentum)

			if (!O || !src) return

			if (O.sharp && O.w_class <= 2.0) //Projectile is suitable for pinning.
				//Handles embedding for non-humans and simple_animals.
				embed(O)

				var/turf/T = near_wall(dir,2)

				if (T)
					loc = T
					visible_message("<span class='warning'>[src] is pinned to the wall by [O]!</span>","<span class='warning'>You are pinned to the wall by [O]!</span>")
					anchored = TRUE
					pinned += O

/mob/living/proc/embed(var/obj/O, var/def_zone=null)
	O.loc = src
	embedded += O
	verbs += /mob/proc/yank_out_object

//This is called when the mob is thrown into a dense turf
/mob/living/proc/turf_collision(var/turf/T, var/speed)
	visible_message(SPAN_DANGER("[src] slams into \the [T]!"))
	take_organ_damage(speed*5)
	T.add_blood(src)

/mob/living/proc/near_wall(var/direction,var/distance=1)
	var/turf/T = get_step(get_turf(src),direction)
	var/turf/last_turf = loc
	var/i = TRUE

	while (i>0 && i<=distance)
		if (T.density) //Turf is a wall!
			return last_turf
		i++
		last_turf = T
		T = get_step(T,direction)

	return FALSE

// End BS12 momentum-transfer code.

/mob/living/attack_generic(var/mob/user, var/damage, var/attack_message)

	if (!damage || !istype(user))
		return

	adjustBruteLoss(damage)
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>attacked [name] ([ckey])</font>")
	attack_log += text("\[[time_stamp()]\] <font color='orange'>was attacked by [user.name] ([user.ckey])</font>")
	visible_message("<span class='danger'>[user] has [attack_message] [src]!</span>")
	user.do_attack_animation(src)
	spawn(1) updatehealth()
	return TRUE

/mob/living/proc/IgniteMob()
	if (fire_stacks > 0 && !on_fire)
		on_fire = TRUE
		set_light(light_range + 3)
		light_color = "#FF9900"
		if (stat == CONSCIOUS)
			emote("scream")
		update_fire()

/mob/living/proc/ExtinguishMob()
	if (on_fire)
		on_fire = FALSE
		fire_stacks = 0
		set_light(max(0, light_range - 3))
		light_color = null
		playsound(src, 'sound/items/cig_snuff.ogg', 50, TRUE) //A little sizzle as you're put out.
		update_fire()

/mob/living/proc/update_fire()
	return

/mob/living/proc/adjust_fire_stacks(add_fire_stacks) //Adjusting the amount of fire_stacks we have on person
	fire_stacks = Clamp(fire_stacks + add_fire_stacks, FIRE_MIN_STACKS, FIRE_MAX_STACKS)

var/obj/generic_living_fire_overlay = null
var/obj/human_fire_overlay = null
var/obj/human_fire_overlay_lying = null

/mob/living/proc/handle_fire()

	if (human_fire_overlay)
		overlays -= generic_living_fire_overlay
		overlays -= human_fire_overlay

	if (fire_stacks < 0)
		fire_stacks = min(0, ++fire_stacks) //If we've doused ourselves in water to avoid fire, dry off slowly

	if (!on_fire)
		return TRUE

	else if (fire_stacks <= 0 || (stat == DEAD && prob(1)))
		ExtinguishMob() //Fire's been put out.
		return TRUE
/*
	var/datum/gas_mixture/G = loc.return_air() // Check if we're standing in an oxygenless environment
	if (G.gas["oxygen"] < 1)
		ExtinguishMob() //If there's no oxygen in the tile we're on, put out the fire
		return TRUE

	var/turf/location = get_turf(src)
	location.hotspot_expose(fire_burn_temperature(), 50, TRUE)
*/
	if (!human_fire_overlay)
		human_fire_overlay = new
		human_fire_overlay.icon = 'icons/mob/OnFire.dmi'
		human_fire_overlay.icon_state = "Standing"
		human_fire_overlay.layer = MOB_LAYER + 1

		human_fire_overlay_lying = new
		human_fire_overlay_lying.icon = 'icons/mob/OnFire.dmi'
		human_fire_overlay_lying.icon_state = "Lying"
		human_fire_overlay_lying.layer = MOB_LAYER + 1

		generic_living_fire_overlay = new
		generic_living_fire_overlay.icon = 'icons/mob/OnFire.dmi'
		generic_living_fire_overlay.icon_state = "Generic_mob_burning"
		generic_living_fire_overlay.layer = MOB_LAYER + 1

	apply_damage(ceil(fire_stacks/3)+1, BURN, "chest", FALSE) // because fire does 0.2 damage per tick
	if (prob((fire_stacks * 10) + 5))
		if (!lying)
			visible_message("<span class = 'danger'>[src] falls over in pain.</span>")
		Weaken(fire_stacks+1)

	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.lying)
			overlays += human_fire_overlay_lying
		else
			overlays += human_fire_overlay
	else
		overlays += generic_living_fire_overlay

/mob/living/fire_act()
	adjust_fire_stacks(1)
	IgniteMob()

/mob/living/proc/get_cold_protection()
	return FALSE

/mob/living/proc/get_heat_protection()
	return FALSE

//Finds the effective temperature that the mob is burning at.
/mob/living/proc/fire_burn_temperature()
	if (fire_stacks <= 0)
		return FALSE

	//Scale quadratically so that single digit numbers of fire stacks don't burn ridiculously hot.
	//lower limit of 700 K, same as matches and roughly the temperature of a cool flame.
	return max(2.25*round(FIRESUIT_MAX_HEAT_PROTECTION_TEMPERATURE*(fire_stacks/FIRE_MAX_FIRESUIT_STACKS)**2), 700)

/mob/living/proc/reagent_permeability()
	return TRUE
	return round(FIRESUIT_MAX_HEAT_PROTECTION_TEMPERATURE*(fire_stacks/FIRE_MAX_FIRESUIT_STACKS)**2)

/mob/living/proc/handle_actions()
	//Pretty bad, i'd use picked/dropped instead but the parent calls in these are nonexistent
	for (var/datum/action/A in actions)
		if (A.CheckRemoval(src))
			A.Remove(src)
	for (var/obj/item/I in src)
		if (I.action_button_name)
			if (!I.action)
				if (I.action_button_is_hands_free)
					I.action = new/datum/action/item_action/hands_free
				else
					I.action = new/datum/action/item_action
				I.action.name = I.action_button_name
				I.action.target = I
			I.action.Grant(src)
	return

/mob/living/update_action_buttons()
	if (!hud_used) return
	if (!client) return

	//if (hud_used.hud_shown != TRUE)	//Hud toggled to minimal
	//	return

	//client.screen -= hud_used.hide_actions_toggle
	for (var/datum/action/A in actions)
		if (A.button)
			client.screen -= A.button

	/*if (hud_used.action_buttons_hidden)
		if (!hud_used.hide_actions_toggle)
			hud_used.hide_actions_toggle = new(hud_used)
			hud_used.hide_actions_toggle.UpdateIcon()

		if (!hud_used.hide_actions_toggle.moved)
			hud_used.hide_actions_toggle.screen_loc = hud_used.ButtonNumberToScreenCoords(1)
			//hud_used.SetButtonCoords(hud_used.hide_actions_toggle,1)

		client.screen += hud_used.hide_actions_toggle
		return
*/
	var/button_number = 0
	for (var/datum/action/A in actions)
		button_number++
		if (A.button == null)
			var/obj/screen/movable/action_button/N = new(hud_used)
			N.owner = A
			A.button = N

		var/obj/screen/movable/action_button/B = A.button

		B.UpdateIcon()

		B.name = A.UpdateName()

		client.screen += B

		if (!B.moved)
			B.screen_loc = hud_used.ButtonNumberToScreenCoords(button_number)
			//hud_used.SetButtonCoords(B,button_number)

//	if (button_number > 0)
		/*if (!hud_used.hide_actions_toggle)
			hud_used.hide_actions_toggle = new(hud_used)
			hud_used.hide_actions_toggle.InitialiseIcon(src)
		if (!hud_used.hide_actions_toggle.moved)
			hud_used.hide_actions_toggle.screen_loc = hud_used.ButtonNumberToScreenCoords(button_number+1)
			//hud_used.SetButtonCoords(hud_used.hide_actions_toggle,button_number+1)
		client.screen += hud_used.hide_actions_toggle*/

