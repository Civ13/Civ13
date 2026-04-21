/datum/firemode
	var/name = "default"
	var/burst = 1
	var/burst_delay = 0
	var/fire_delay = -1
	var/move_delay = 1
	var/shake_strength = -1

//using a list makes defining fire modes for new guns much nicer,
//however we convert the lists to datums in part so that firemodes can be VVed if necessary.
/datum/firemode/New(list/properties = null)
	..()
	if (!properties) return

	for (var/propname in vars)
		if (!isnull(properties[propname]))
			vars[propname] = properties[propname]

//Parent gun type. Guns are weapons that can be aimed at mobs and act over a distance
/obj/item/weapon/gun
	name = "gun"
	desc = "Its a gun. It's pretty terrible, though."
	icon = 'icons/obj/guns/gun.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_guns.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_guns.dmi',
		)
	icon_state = "detective"
	item_state = "pistol"
	flags =  CONDUCT
	slot_flags = SLOT_BELT|SLOT_HOLSTER
	w_class = ITEM_SIZE_NORMAL
	throwforce = 5
	throw_speed = 4
	throw_range = 5
	force = 5
	attack_verb = list("struck", "hit", "bashed")

	var/full_auto = FALSE
	var/fire_delay = 0.1 	//delay after shooting before the gun can be used again
	var/fire_sound = 'sound/weapons/guns/fire/rifle.ogg'
	var/silencer_fire_sound = 'sound/weapons/guns/fire/AKM-SD.ogg'
	var/fire_sound_text = "gunshot"
	var/shake_strength = 0		//screen shake
	var/muzzle_flash = 3

	var/recoil = 15 // movement of the barrel by recoil to the sides when shooting
	var/next_shot_recoil = 0
	var/last_shot_time = 0 // last shot time
	var/accuracy = 1 // basic trunk defect
	var/ergonomics = 1
	var/stat = "rifle"

	var/next_fire_time = 0

	var/sel_mode = 1 //index of the currently selected mode
	var/list/firemodes = list()
	var/firemode_type = /datum/firemode //for subtypes that need custom firemode data

	//aiming system stuff
	var/keep_aim = TRUE 	//1 for keep shooting until aim is lowered
						//0 for one bullet after tarrget moves and aim is lowered
	var/multi_aim = FALSE //Used to determine if you can target multiple people.
	var/tmp/list/mob/living/aim_targets //List of who yer targeting.
	var/tmp/mob/living/last_moved_mob //Used to fire faster at more than one person.
	var/tmp/told_cant_shoot = FALSE //So that it doesn't spam them with the fact they cannot hit them.
	var/tmp/lock_time = -100

	var/list/under_mounts = list() //List of extra compatible unders
	var/list/scope_mounts = list() //List of extra compatible scopes

	var/damage_modifier = 0

//	var/wielded = FALSE
//	var/must_wield = FALSE
//	var/can_wield = FALSE
//	var/can_scope = FALSE

	var/burst = 1
	var/move_delay = 1
	var/list/burst_accuracy = list(0)

	var/obj/item/weapon/attachment/bayonet = null
	var/obj/item/weapon/gun/launcher/grenade/underslung/launcher = null
	var/use_launcher = FALSE

	var/gun_type = GUN_TYPE_GENERIC

	var/gibs = FALSE
	var/crushes = FALSE

	health = 200 //guns are stronk, rarely exploded.

/obj/item/weapon/gun/New()
	..()
	maxhealth = health
	if (!istype(src, /obj/item/weapon/gun/projectile/custom))
		if (!firemodes.len)
			firemodes += new firemode_type
		else
			for (var/i in 1 to firemodes.len)
				firemodes[i] = new firemode_type(firemodes[i])

		for (var/datum/firemode/FM in firemodes)
			if (FM.fire_delay == -1)
				FM.fire_delay = fire_delay

	if (!aim_targets)
		aim_targets = list()

//Checks whether a given mob can use the gun
//Any checks that shouldn't result in handle_click_empty() being called if they fail should go here.
//Otherwise, if you want handle_click_empty() to be called, check in consume_next_projectile() and return null there.
/obj/item/weapon/gun/proc/special_check(var/mob/user)

	if (!istype(user, /mob/living))
		return FALSE

	if (!user.IsAdvancedToolUser())
		return FALSE

	return TRUE

/obj/item/weapon/gun/emp_act(severity)
	for (var/obj/O in contents)
		O.emp_act(severity)

/obj/item/weapon/gun/handle_shield(mob/user, var/damage, atom/damage_source = null, mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	if (default_parry_check(user, attacker, damage_source) && w_class >= 4) // Only big guns can stop attacks.
		if (bayonet && prob(40)) // If they have a bayonet they get a higher chance to stop the attack.
			user.visible_message("<span class='danger'>\The [user] blocks [attack_text] with \the [src]!</span>")
			playsound(user.loc, 'sound/weapons/punchmiss.ogg', 50, TRUE)
			return TRUE
		else
			if (prob(10))// Much smaller chance to block it due to no bayonet.
				user.visible_message("<span class='danger'>\The [user] blocks [attack_text] with \the [src]!</span>")
				playsound(user.loc, 'sound/weapons/punchmiss.ogg', 50, TRUE)
				return TRUE
	return FALSE

/obj/item/weapon/gun/afterattack(atom/A, mob/living/user, adjacent, params)
	if (adjacent) return //A is adjacent, is the user, or is on the user's person

	if (!user.aiming)
		user.aiming = new(user)

	if (user && user.client && user.aiming && user.aiming.active && user.aiming.aiming_at != A)
		PreFire(A,user,params) //They're using the new gun system, locate what they're aiming at.
		return

	//DUAL WIELDING: only works with pistols edition
	var/obj/item/weapon/gun/off_hand = null
	var/off_hand_fire = FALSE
	if (ishuman(user))
		var/mob/living/human/H = user
		if (istype(H.l_hand, /obj/item/weapon/gun) && istype(H.r_hand, /obj/item/weapon/gun))
			var/obj/item/weapon/gun/LH = H.l_hand
			var/obj/item/weapon/gun/RH = H.r_hand
			if (RH.gtype == "pistol" || RH.gtype == "revolver")
				if (LH.gtype == "pistol" || LH.gtype == "revolver")
					if (H.r_hand == src)
						off_hand = H.l_hand
					else if (H.l_hand == src)
						off_hand = H.r_hand
					if (off_hand)
						off_hand_fire = TRUE
						spawn(3)
							off_hand.Fire(A,user,params, accuracy_mod = 0.66)
	if (!off_hand_fire)
		Fire(A,user,params) //Otherwise, fire normally.
	else
		Fire(A,user,params, accuracy_mod = 0.66)

/obj/item/weapon/gun/attack(atom/A, mob/living/user, def_zone)
	var/mob/living/human/H = user
	if (istype(H) && (H.faction_text == INDIANS) && (map && (!map.ID == MAP_AFRICAN_WARLORDS || !map.ID == MAP_TADOJSVILLE)))
		user << SPAN_DANGER("You have no idea how this thing works.")
		return
	if (A == user)
		var/tgt = user.targeted_organ
		if (user.targeted_organ == "random")
			tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
		if (tgt == "mouth" && !mouthshoot)
			handle_suicide(user)
		else if (user.a_intent == I_HARM && do_after(user, 2, get_turf(user)))
			handle_shoot_self(user)
		return

	var/fire = TRUE
	if (istype(src, /obj/item/weapon/gun/projectile))
		var/obj/item/weapon/gun/projectile/proj = src
		if (!proj.has_next_projectile())
			fire = FALSE

	if (user.a_intent != I_HELP && !bayonet && fire) // point blank shooting
		Fire(A, user, pointblank=1)
	else
		if (bayonet && isliving(A) && !istype(bayonet, /obj/item/weapon/attachment/bayonet/flag))
			var/mob/living/L = A

			var/obj/item/weapon/attachment/bayonet/a = bayonet
			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			///////////////////////////////////////////////////////////I have made true spaghetti code, this would probably be better if we made the bayoneting action a proc that gets called instead of relisting the same code, but I am lazy today. Someone else can optimize it on their civilian time.- Kenobi/////////
			if (L)
				if (ishuman(L))
					if (user != L)
						if(L.attempt_dodge()) //Trying to dodge it before they even have the chance to miss us.
							return

						else
							H = L
							//chest armor? no? get fucked
							if (user.targeted_organ == "chest")
								if (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/armor))
									visible_message("<span class = 'danger'>[user]'s bayonet bounces off [H]'s [H.wear_suit]!</span>")
									return
								else
									visible_message("<span class = 'danger'>[user] impales [H] with their gun's bayonet!</span>")
									playsound(get_turf(src), a.attack_sound, rand(90,100))
									H.apply_damage(a.mounted_dmg, BRUTE, def_zone)
									if (L.stat == CONSCIOUS && prob(50))
										H.emote("painscream")
							//Helmet? no? kinda hard to hit
							else if (user.targeted_organ == "head")
								if (H.head && istype(H.head, /obj/item/clothing/head/helmet))
									visible_message("<span class = 'danger'>[user]'s bayonet bounces off [H]'s [H.head]!</span>")
									return
								else
									if(prob(90))
										visible_message("<span class = 'danger'>[user]'s bayonet narrowly misses [H]!</span>")
									else
										visible_message("<span class = 'danger'>[user] impales [H] with their gun's bayonet!</span>")
										playsound(get_turf(src), a.attack_sound, rand(90,100))
										H.apply_damage(a.mounted_dmg, BRUTE, def_zone)
										if (L.stat == CONSCIOUS && prob(50))
											H.emote("painscream")
							//mouth armor? no? you're honestly safe
							if (user.targeted_organ == "mouth")
								if (H.wear_mask)
									if (istype(H.wear_mask, /obj/item/clothing/mask/samurai) || istype(H.wear_mask, /obj/item/clothing/mask/stone) || istype(H.wear_mask, /obj/item/clothing/mask/wooden))
										visible_message("<span class = 'danger'>[user]'s bayonet bounces off [H]'s [H.wear_suit]!</span>")
										return
								else
									if (prob(95))
										visible_message("<span class = 'danger'>[user]'s bayonet narrowly misses [H]!</span>")
									else
										visible_message("<span class = 'danger'>[user] impales [H] with their gun's bayonet!</span>")
										playsound(get_turf(src), a.attack_sound, rand(90,100))
										H.apply_damage(a.mounted_dmg, BRUTE, def_zone)
										if (L.stat == CONSCIOUS && prob(50))
											H.emote("painscream")
							//your limbs are still only a 25% chance to hit, which makes the chest the best option. if they're armored then you're simply better off shooting them.
							else
								if (user.targeted_organ != "chest" && user.targeted_organ != "groin" && user.targeted_organ != "head")
									if(prob(75))
										visible_message("<span class = 'danger'>[user]'s bayonet narrowly misses [H]!</span>")
									else
										visible_message("<span class = 'danger'>[user] impales [H] with their gun's bayonet!</span>")
										playsound(get_turf(src), a.attack_sound, rand(90,100))
										H.apply_damage(a.mounted_dmg, BRUTE, def_zone)
										if (L.stat == CONSCIOUS && prob(50))
											H.emote("painscream")
				else //if its a mob like a bear or turkey
					visible_message("<span class = 'danger'>[user] impales [L] with their gun's bayonet!</span>")
					playsound(get_turf(src), a.attack_sound, rand(90,100))
					L.apply_damage(a.mounted_dmg, BRUTE, def_zone)
		else
			..() //Pistolwhipping - now help intent only (or when the gun is empty)

// only update our in-hands icon if we aren't using a scope (invisible)
/obj/item/weapon/gun/update_held_icon()
	if (loc && ismob(loc))
		if (ishuman(loc))
			var/mob/living/human/H = loc
			if (H.using_look())
				return FALSE
	..()

/obj/item/weapon/gun/proc/Fire(atom/target, mob/living/user, clickparams = null, pointblank = FALSE, reflex = FALSE, forceburst = -1, force = FALSE, accuracy_mod = 1)

	if (!user || !target) return

	add_fingerprint(user)

	if (!force)
		if (!special_check(user))
			return

		if (world.time < next_fire_time)
			if (world.time % 3) //to prevent spam
				user << SPAN_WARNING("[src] is not ready to fire again!")
			return

	//unpack firemode data
	var/datum/firemode/firemode = firemodes[sel_mode]
	var/_burst = firemode.burst
	var/_burst_delay = isnull(firemode.burst_delay)? 2 : firemode.burst_delay
	var/_fire_delay = isnull(firemode.fire_delay) ? fire_delay : firemode.fire_delay
	var/_move_delay = firemode.move_delay

	if (forceburst != -1)
		_burst = forceburst

	var/shoot_time = (_burst - 1)*_burst_delay
	user.next_move = world.time + shoot_time  //no clicking on things while shooting
	if (user.client) user.client.move_delay = world.time + shoot_time //no moving while shooting either
	next_fire_time = world.time + shoot_time

	//actually attempt to shoot
	var/turf/targloc = get_turf(target) //cache this in case target gets deleted during shooting, e.g. if it was a securitron that got destroyed.

	for (var/i in 1 to _burst)
		var/obj/projectile = consume_next_projectile(user)

		if (!projectile)
			handle_click_empty(user)
			break
		if (istype(src, /obj/item/weapon/gun/projectile/semiautomatic/m1garand))
			var/obj/item/weapon/gun/projectile/semiautomatic/m1garand/G = src
			if (!G.loaded.len)
				playsound(loc, 'sound/weapons/guns/interact/GarandUnload.ogg', 100, TRUE)
		health_check(user)
		health -= 0.2

		if (istype(projectile, /obj/item/projectile))
			var/obj/item/projectile/P = projectile
			if (istype(P.firedfrom, /obj/item/weapon/gun/projectile))
				var/obj/item/weapon/gun/projectile/proj = P.firedfrom
				P.KD_chance = proj.KD_chance

		if (pointblank)
			if (istype(projectile, /obj/item/projectile))
				var/obj/item/projectile/P = projectile
				P.KD_chance = 100
			process_point_blank(projectile, user, target)
		var/tgt = "chest"
		if (user)
			tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			if (!process_projectile(projectile, user, target, tgt, clickparams))
				handle_post_fire(user, target, pointblank, reflex)
				update_icon()

		if (i < _burst)
			sleep(_burst_delay)

		if (!(target && target.loc))
			target = targloc
			pointblank = FALSE

	update_held_icon()

	//update timing

	if (_move_delay)
		user.setMoveCooldown(_move_delay + 1.5)

	next_fire_time = world.time + _fire_delay

	if (muzzle_flash)
		spawn(5)
			set_light(0)

//obtains the next projectile to fire
/obj/item/weapon/gun/proc/consume_next_projectile()
	return null

//used by aiming code
/obj/item/weapon/gun/proc/can_hit(atom/target as mob, var/mob/living/user as mob)
	if (!special_check(user))
		return 2
	//just assume we can shoot through glass and stuff. No big deal, the player can just choose to not target someone
	//on the other side of a window if it makes a difference. Or if they run behind a window, too bad.
	return check_trajectory(target, user)

//called if there was no projectile to shoot
/obj/item/weapon/gun/proc/handle_click_empty(mob/user)
	if (user)
		user.visible_message("*click click*", "<span class='danger'>*click*</span>")
	else
		visible_message("*click click*")

	playsound(loc, 'sound/weapons/empty.ogg', 100, TRUE)

//called after successfully firing
/obj/item/weapon/gun/proc/handle_post_fire(mob/user, atom/target, var/pointblank=0, var/reflex=0)
	if (silencer)
		playsound(user, silencer_fire_sound, 100-silencer.reduction, TRUE,100-silencer.reduction)
	else
		playsound(user, fire_sound, 100, TRUE,100)
	if (muzzle_flash)
		set_light(muzzle_flash)

	var/datum/firemode/F = firemodes[sel_mode]

	if (F.shake_strength != -1)
		shake_strength = F.shake_strength

	if (shake_strength)
		spawn(0)
			if (shake_strength > 0)
				shake_camera(user, max(shake_strength, 0), min(shake_strength, 50))

	update_icon()

/obj/item/weapon/gun/proc/process_point_blank(obj/projectile, mob/user, atom/target)
	var/obj/item/projectile/P = projectile
	if (!istype(P))
		return //default behaviour only applies to true projectiles
	//default point blank multiplier
	var/damage_mult = 1.33

	//determine multiplier due to the target being grabbed
	if (ismob(target))
		var/mob/M = target
		if (M.grabbed_by.len)
			var/grabstate = FALSE
			for (var/obj/item/weapon/grab/G in M.grabbed_by)
				grabstate = max(grabstate, G.state)
			if (grabstate >= GRAB_NECK)
				damage_mult = 4
			else if (grabstate >= GRAB_AGGRESSIVE)
				damage_mult = 3
	P.damage *= damage_mult

/obj/item/weapon/gun/proc/get_dispersion_range(mob/user)
	var/dt = world.time - last_shot_time
	var/dt_movement = world.time - user.last_movement
	var/recoil_range = recoil / ergonomics
	var/accuracy_range = accuracy

	if(dt > firemodes[sel_mode].burst_delay)
		recoil_range /= sqrt(dt) * 2
		if((recoil_range - sqrt(dt) * 1.5) < 0)
			recoil_range = 0
		else
			recoil_range -= sqrt(dt) * 1.5

	if(user.lying || user.prone)
		recoil_range /= 2

	if(dt_movement <= 6)
		accuracy_range = 30
	else if (dt_movement < 10)
		accuracy_range = 40 / (dt_movement - 6)

	return recoil_range + accuracy_range

//does the actual launching of the projectile
/obj/item/weapon/gun/proc/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params=null)

	var/obj/item/projectile/P = projectile

	if (!istype(P))
		return FALSE //default behaviour only applies to true projectiles

	if (params)
		P.set_clickpoint(params)

	if (damage_modifier != 0)
		P.damage += damage_modifier

	var/dt = world.time - last_shot_time

	var/shot_recoil = next_shot_recoil / ergonomics

	if(dt >= firemodes[sel_mode].burst_delay)
		shot_recoil /= sqrt(dt) * 2
		if(dt * 0.5 < abs(shot_recoil) )
			shot_recoil -= ((shot_recoil) ? ((shot_recoil) < 0 ? -1 : 1) : 0) * dt * 0.5
		else
			shot_recoil = 0

	if(user.lying || user.prone)
		shot_recoil /= 2

	var/shot_accuracy = rand(-accuracy, accuracy)

	var/dt_movement = world.time - user.last_movement

	if (dt_movement <= 6)
		shot_accuracy = rand(-20, 20)
	else if (dt_movement < 10)
		var/accuracy_range = 20 / sqrt(dt_movement - 6)
		shot_accuracy = rand(-accuracy_range, accuracy_range)
		if (abs(shot_accuracy) < 5) // even RNjesus won’t help you get there right away
			shot_accuracy += 5
		if (istype(user, /mob/living/human))
			if(user.m_intent != "run")
				shot_accuracy *= 0.75

	var/shot_dispersion = clamp(shot_recoil + shot_accuracy, -40, 40)

	P.dispersion = shot_dispersion

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

	if(!P.launch(target, user, src, target_zone, x_offset, y_offset))
		next_shot_recoil = clamp(shot_recoil + (rand(recoil * 0.5, recoil) * rand(-1, 1)), -40, 40)
		next_shot_recoil /= rand(1, sqrt(abs(next_shot_recoil)) / 3)
		last_shot_time = world.time
		return FALSE
	return TRUE

//Suicide handling.
/obj/item/weapon/gun/var/mouthshoot = FALSE //To stop people from suiciding twice... >.>
/obj/item/weapon/gun/proc/handle_suicide(mob/living/user)
	if (!ishuman(user))
		return
	var/mob/living/human/M = user

	// realistic WW2 suicide, no hesitation - Kachnov
	mouthshoot = TRUE
	M.visible_message("<span class = 'red'>[user] sticks [M.gender == FEMALE ? "her" : "his"] [src] in [M.gender == FEMALE ? "her" : "his"] mouth.</span>")
	if (!do_after(user, 3))
		visible_message("<span class = 'notice'>[user] failed to commit suicide.</span>")
		mouthshoot = FALSE
		return
	var/obj/item/projectile/in_chamber = consume_next_projectile()
	if (in_chamber && istype(in_chamber))
		user.visible_message("<span class = 'warning'>[user] pulls the trigger.</span>")
		if (silencer)
			playsound(user, silencer_fire_sound, 50-(silencer.reduction/2), TRUE,50-(silencer.reduction/2))
		else
			playsound(user, fire_sound, 50, TRUE,50)

		M.attack_log += "\[[time_stamp()]\] [M]/[M.ckey]</b> shot themselves in the mouth (tried to commit suicide)"

		in_chamber.on_hit(M)
		if (in_chamber.damage_type != HALLOSS)

			if (M.wear_mask && istype(M.wear_mask, /obj/item/weapon/grenade))
				visible_message("<span class = 'danger'>The grenade in [M]'s mouth goes off!</span>")
				var/obj/item/weapon/grenade/G = M.wear_mask
				G.active = TRUE
				G.prime()

			user.apply_damage(in_chamber.damage*2.5, in_chamber.damage_type, "head", used_weapon = "Point blank shot in the mouth with \a [in_chamber]", sharp=1)
			user.death()
			M.attack_log += "\[[time_stamp()]\] [M]/[M.ckey]</b> shot themselves in the mouth (committed suicide)"
		else
			user << "<span class = 'notice'>Ow...</span>"
			user.apply_effect(110,AGONY,0)

		if (istype(src, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/proj = src
			if (proj.chambered)
				proj.chambered.expend()
				proj.process_chambered()
		else
			qdel(in_chamber)

		mouthshoot = FALSE
		return
	else
		handle_click_empty(user)
		mouthshoot = FALSE
		return

/obj/item/weapon/gun/proc/handle_shoot_self(var/mob/living/human/user)
	if (!istype(user))
		return
	if (!special_check(user))
		return

	var/_burst = 1
	var/datum/firemode/firemode = firemodes[sel_mode]
	if (firemode)
		_burst = firemode.burst

	for (var/v in 1 to _burst)

		var/obj/item/projectile/in_chamber = consume_next_projectile()

		if (in_chamber && istype(in_chamber))

			var/damage_multiplier = 1.33 // so legs and arms don't explode - Kachnov
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			var/organ_name = replacetext(replacetext(tgt, "l_", "left "), "r_", "right ")

			switch (tgt)
				if ("l_hand", "r_hand", "l_foot", "r_foot")
					damage_multiplier = 1.0
				if ("chest")
					damage_multiplier = 3.0

			user.visible_message("<span class = 'red'>[user] shoots \himself in \the [organ_name]!</span>")
			if (silencer)
				playsound(user, silencer_fire_sound, 100-silencer.reduction, TRUE,100-silencer.reduction)
			else
				playsound(user, fire_sound, 100, TRUE,100)

			user.attack_log += "\[[time_stamp()]\] [user]/[user.ckey]</b> shot themselves in the [organ_name]"

			in_chamber.on_hit(user)
			if (in_chamber.damage_type != HALLOSS)
				user.apply_damage(in_chamber.damage*damage_multiplier, in_chamber.damage_type, tgt, used_weapon = "Point blank shot in the [user.targeted_organ] with \a [in_chamber]", sharp=1)
			else
				user << "<span class = 'notice'>Ow...</span>"
				user.apply_effect(110,AGONY,0)


			if (istype(src, /obj/item/weapon/gun/projectile))
				var/obj/item/weapon/gun/projectile/proj = src
				if (proj.chambered)
					proj.chambered.expend()
					proj.process_chambered()
			else
				qdel(in_chamber)

		else
			handle_click_empty(user)
			break

/obj/item/weapon/gun/examine(mob/user)
	..()
	if (health > 0 && maxhealth > 0)
		var/health_percentage = (health/maxhealth)*100
		switch (health_percentage)
			if (-100 to 21)
				user << "<font color='#7f0000'>Is pratically falling apart!</font>"
			if (22 to 49)
				user << "<font color='#a74510'>Seems to be in very bad condition.</font>"
			if (50 to 69)
				user << "<font color='#cccc00'>Seems to be in a rough condition.</font>"
			if (70 to 84)
				user << "<font color='#4d5319'>Seems to be in a somewhat decent condition.</font>"
			if (85 to 200)
				user << "<font color='#326327'>Seems to be in very good condition.</font>"

	if (firemodes.len > 1)
		var/datum/firemode/current_mode = firemodes[sel_mode]
		user.visible_message("The fire selector is set to [current_mode.name].")
	if (safetyon)
		to_chat(user, SPAN_NOTICE("<b>The safety is on.</b>"))

/obj/item/weapon/gun/proc/switch_firemodes(mob/user=null)
	sel_mode++
	if (sel_mode > firemodes.len)
		sel_mode = 1
	var/datum/firemode/new_mode = firemodes[sel_mode]
	to_chat(user, SPAN_NOTICE("\The [src] is now set to [new_mode.name]."))
	if (new_mode.name == "automatic")
		full_auto = TRUE
	else
		full_auto = FALSE

/obj/item/weapon/gun/attack_self(mob/user)
	if (firemodes.len > 1)
		switch_firemodes(user)
/*
/obj/item/weapon/gun/proc/wield(mob/user as mob)
	if (wielded)
		return

	wielded = TRUE
	update_icon()

	var/obj/item/weapon/offhand/O = new(src)
	if (user.get_inactive_hand() == src)
		user:swap_hand()
	user.drop_inactive_hand()
	user.put_in_inactive_hand(O)

/obj/item/weapon/gun/proc/unwield(mob/user as mob)
	if (!wielded)
		return

	wielded = FALSE
	update_icon()

	var/obj/item/weapon/offhand/O = user.get_inactive_hand()
	if (istype(O))
		user.drop_inactive_hand()
		qdel(O)
	else
		O = user.get_active_hand()
		if (istype(O))
			user.drop_active_hand()
			qdel(O)

/obj/item/weapon/gun/dropped(mob/user)
	..()
	if (wielded)
		unwield(user)
*/

/obj/item/weapon/gun/mob_can_equip(M as mob, slot) //Dirty hack
	. = ..()
/*	if (.)
		unwield(M)*/
	return
/*
/obj/item/weapon/offhand
	w_class = ITEM_SIZE_HUGE
	icon_state = "offhand"
	name = "offhand"

/obj/item/weapon/offhand/update_icon()
	return

/obj/item/weapon/offhand/dropped(mob/user as mob)
	qdel(src)

/obj/item/weapon/offhand/attackby(obj/I as obj, mob/user as mob)
	if (user.get_inactive_hand() == src)
		user:swap_hand()*/

/mob/living/human/verb/eject_magazine()
	set name = "Eject magazine"
	set category = null

	var/obj/item/weapon/gun/projectile/G = get_active_hand()
	if (!G || !istype(G))
		G = get_inactive_hand()
		if (!G || !istype(G))
			src << "<span class = 'red'>You can't unload magazine from anything in your hands.</span>"
			return

	if (G.load_method == MAGAZINE && G.ammo_magazine == null)
		src << "<span class = 'red'>The [G.name] is already unloaded.</span>"
		return
	if (G && G.ammo_magazine)
		G.ammo_magazine.loc = get_turf(loc)
	visible_message(
		"[G.ammo_magazine] falls out and clatters on the floor!",
		"<span class='notice'>[G.ammo_magazine] falls out and clatters on the floor!</span>"
		)
	G.ammo_magazine.update_icon()
	G.ammo_magazine = null
	G.update_icon() //make sure to do this after unsetting ammo_magazine


//weight check stuff

/obj/item/weapon/gun/projectile/get_weight()
	. = ..()
	if (ammo_magazine)
		.+= ammo_magazine.get_weight()
	return .

//health stuff; if the gun quality is too low, it might blow up in your hands!
/obj/item/weapon/gun/proc/health_check(mob/living/human/H)
	if(health <= 0 || maxhealth <= 0)
		playsound(src, "shatter", 70, TRUE)
		visible_message("<span class='danger'>\The [src.name] shatters!</span>")
		var/hurthand = "r_hand"
		if (src.loc == H.l_hand)
			hurthand = "l_hand"
		var/obj/item/organ/external/affecting = H.get_organ(hurthand)
		H.apply_damage(25, BRUTE, affecting)
		H.bloody_hands(H,0)
		H.emote("painscream")
		H.drop_from_inventory(src)
		new /obj/item/weapon/material/shard(H.loc, "steel")
		qdel(src)
