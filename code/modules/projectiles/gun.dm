/datum/firemode
	var/name = "default"
	var/burst = 1
	var/burst_delay = 0
	var/fire_delay = -1
	var/move_delay = 0
	var/recoil = -1
	var/list/dispersion = list(0)

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
	icon = 'icons/obj/gun.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_guns.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_guns.dmi',
		)
	icon_state = "detective"
	item_state = "gun"
	flags =  CONDUCT
	slot_flags = SLOT_BELT|SLOT_HOLSTER
	matter = list(DEFAULT_WALL_MATERIAL = 2000)
	w_class = 3
	throwforce = 5
	throw_speed = 4
	throw_range = 5
	force = 5
	attack_verb = list("struck", "hit", "bashed")

	var/full_auto = FALSE
	var/fire_delay = 5 	//delay after shooting before the gun can be used again
	var/burst_delay = 2	//delay between shots, if firing in bursts
	var/fire_sound = 'sound/weapons/kar_shot.ogg'
	var/fire_sound_text = "gunshot"
	var/recoil = 0		//screen shake
	var/silenced = FALSE
	var/muzzle_flash = 3
	var/accuracy = 0   //accuracy is measured in tiles. +1 accuracy means that everything is effectively one tile closer for the purpose of miss chance, -1 means the opposite. launchers are not supported, at the moment.
//	var/scoped_accuracy = null

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

//	var/wielded = FALSE
//	var/must_wield = FALSE
//	var/can_wield = FALSE
//	var/can_scope = FALSE

	var/burst = 1
	var/move_delay = 0
	var/list/burst_accuracy = list(0)
	var/list/dispersion = list(0)

	var/obj/item/weapon/attachment/bayonet = null

	var/gun_type = GUN_TYPE_GENERIC

	var/autofiring = FALSE

	var/gibs = FALSE
	var/crushes = FALSE

/obj/item/weapon/gun/New()
	..()
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
	if (ishuman(user) && user.a_intent == "harm")
		var/mob/living/carbon/human/H = user
		if (istype(H.l_hand, /obj/item/weapon/gun) && istype(H.r_hand, /obj/item/weapon/gun))
			var/obj/item/weapon/gun/LH = H.l_hand
			var/obj/item/weapon/gun/RH = H.r_hand
			if (RH == "pistol")
				if (LH == "pistol")
					if (H.r_hand == src)
						off_hand = H.l_hand

					else if (H.l_hand == src)
						off_hand = H.r_hand

					if (off_hand && off_hand.can_hit(user))
						spawn(1)
							off_hand.Fire(A,user,params)

	Fire(A,user,params) //Otherwise, fire normally.

/obj/item/weapon/gun/attack(atom/A, mob/living/user, def_zone)
	var/mob/living/carbon/human/H = user
	if (istype(H) && (H.faction_text == "INDIANS" || H.crab))
		user << "<span class = 'danger'>You have no idea how this thing works.</span>"
		return
	if (A == user)
		var/tgt = user.targeted_organ
		if (user.targeted_organ == "random")
			tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
		if (tgt == "mouth" && !mouthshoot)
			handle_suicide(user)
		else if (user.a_intent == I_HURT && do_after(user, 2, get_turf(user)))
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
		if (bayonet && isliving(A))
			var/mob/living/L = A
			var/mob/living/carbon/C = A
			if (!istype(C) || !C.check_attack_throat(src, user))
				// bayonets no longer have a miss chance, but have been balanced otherwise - Kachnov
				var/obj/item/weapon/attachment/bayonet/a = bayonet
				user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN) // No more rapid stabbing for you.
				visible_message("<span class = 'danger'>[user] impales [L] with their gun's bayonet!</span>")
				if (L)
					L.apply_damage(a.force, BRUTE, def_zone)
					L.Weaken(a.weakens)
					if (L.stat == CONSCIOUS && prob(50))
						L.emote("painscream")
				playsound(get_turf(src), a.attack_sound, rand(90,100))
			else
				var/obj/item/weapon/attachment/bayonet/a = bayonet
				playsound(get_turf(src), a.attack_sound, rand(90,100))
		else
			..() //Pistolwhipping - now help intent only (or when the gun is empty)

// only update our in-hands icon if we aren't using a scope (invisible)
/obj/item/weapon/gun/update_held_icon()
	if (loc && ismob(loc))
		if (ishuman(loc))
			var/mob/living/carbon/human/H = loc
			if (H.using_zoom())
				return FALSE
	..()

/obj/item/weapon/gun/proc/Fire(atom/target, mob/living/user, clickparams, pointblank=0, reflex=0, forceburst = -1, force = FALSE)

	if (!user || !target) return

	if (user.pixel_y > 16) return // can't fire while we're this high up - used for paradropping in particular

	// stops admemes from sending immortal dummies into combat
	if (user && istype(user, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = user
		if ((H.client && istype(H, /mob/living/carbon/human/dummy)) || !H.original_job || !H.original_job_title)
			if (clients.len > 1)
				user << "<span class = 'danger'>Hey you fucking dumbass, don't send immortal dummies into combat.</span>"
				return

	add_fingerprint(user)

	if (!force)
		if (!special_check(user))
			return

		if (world.time < next_fire_time)
			if (world.time % 3) //to prevent spam
				user << "<span class='warning'>[src] is not ready to fire again!</span>"
			return

	//unpack firemode data
	var/datum/firemode/firemode = firemodes[sel_mode]
	var/_burst = firemode.burst
	var/_burst_delay = isnull(firemode.burst_delay)? burst_delay : firemode.burst_delay
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

		var/acc = 0 // calculated in projectile code
		var/disp = firemode.dispersion[min(i, firemode.dispersion.len)]

		if (istype(projectile, /obj/item/projectile))
			var/obj/item/projectile/P = projectile

			if (istype(P.firedfrom, /obj/item/weapon/gun/projectile))
				var/obj/item/weapon/gun/projectile/proj = P.firedfrom
				P.KD_chance = proj.KD_chance

		process_accuracy(projectile, user, target, acc, disp)

		if (pointblank)
			if (istype(projectile, /obj/item/projectile))
				var/obj/item/projectile/P = projectile
				P.KD_chance = 100
			process_point_blank(projectile, user, target)
		var/tgt = user.targeted_organ
		if (user.targeted_organ == "random")
			tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
		if (process_projectile(projectile, user, target, tgt, clickparams))
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
	if (silenced)
		playsound(get_turf(user), fire_sound, 10, TRUE, 100)
	else
		playsound(get_turf(user), fire_sound, 100, TRUE, 100)

		if (muzzle_flash)
			set_light(muzzle_flash)

	var/datum/firemode/F = firemodes[sel_mode]

	var/i_recoil = recoil
	if (F.recoil != -1)
		recoil = F.recoil

	if (recoil)
		spawn(0)
			var/shake_strength = recoil
			if (shake_strength > 0)
				shake_camera(user, max(shake_strength, 0), min(shake_strength, 50))
			recoil = i_recoil
	else
		recoil = i_recoil

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

/obj/item/weapon/gun/proc/process_accuracy(obj/projectile, mob/user, atom/target, acc_mod, dispersion)
	var/obj/item/projectile/P = projectile

	if (!istype(P))
		return //default behaviour only applies to true projectiles

	//Accuracy modifiers
	P.accuracy = accuracy + acc_mod
	P.dispersion = dispersion
/*
	//accuracy bonus from aiming
	if (aim_targets && (target in aim_targets))
		//If you aim at someone beforehead, it'll hit more often.
		//Kinda balanced by fact you need like 2 seconds to aim
		//As opposed to no-delay pew pew
		P.accuracy += 2*/

//does the actual launching of the projectile
/obj/item/weapon/gun/proc/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params=null)

	var/obj/item/projectile/P = projectile

	if (!istype(P))
		return FALSE //default behaviour only applies to true projectiles

	if (params)
		P.set_clickpoint(params)

	//shooting while in shock
	var/x_offset = 0
	var/y_offset = 0
	if (istype(user, /mob/living/carbon))
		var/mob/living/carbon/mob = user
		if (mob.shock_stage > 120)
			y_offset = rand(-2,2)
			x_offset = rand(-2,2)
		else if (mob.shock_stage > 70)
			y_offset = rand(-1,1)
			x_offset = rand(-1,1)

	return !P.launch(target, user, src, target_zone, x_offset, y_offset)

//Suicide handling.
/obj/item/weapon/gun/var/mouthshoot = FALSE //To stop people from suiciding twice... >.>
/obj/item/weapon/gun/proc/handle_suicide(mob/living/user)
	if (!ishuman(user))
		return
	var/mob/living/carbon/human/M = user

	// realistic WW2 suicide, no hesitation - Kachnov
	mouthshoot = TRUE
	M.visible_message("<span class = 'red'>[user] sticks [M.gender == FEMALE ? "her" : "his"] [src] in [M.gender == FEMALE ? "her" : "his"] mouth.</span>")
	if (!do_after(user, 3))
		M.visible_message("<span class = 'notice'>[user] failed to commit suicide.</span>")
		mouthshoot = FALSE
		return
	var/obj/item/projectile/in_chamber = consume_next_projectile()
	if (in_chamber && istype(in_chamber))
		user.visible_message("<span class = 'warning'>[user] pulls the trigger.</span>")
		if (silenced)
			playsound(user, fire_sound, 10, TRUE)
		else
			playsound(user, fire_sound, 50, TRUE)

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

/obj/item/weapon/gun/proc/handle_shoot_self(var/mob/living/carbon/human/user)
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
			if (silenced)
				playsound(user, fire_sound, 20, TRUE)
			else
				playsound(user, fire_sound, 100, TRUE)

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
	if (firemodes.len > 1)
		var/datum/firemode/current_mode = firemodes[sel_mode]
		user.visible_message("The fire selector is set to [current_mode.name].")
	if (safetyon)
		user << "<span class='notice'><b>The safety is on.</b></span>"
/obj/item/weapon/gun/proc/switch_firemodes(mob/user=null)
	sel_mode++
	if (sel_mode > firemodes.len)
		sel_mode = TRUE
	var/datum/firemode/new_mode = firemodes[sel_mode]
	user << "<span class='notice'>\The [src] is now set to [new_mode.name].</span>"
	if (new_mode.name == "full auto")
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
	w_class = 5
	icon_state = "offhand"
	name = "offhand"

/obj/item/weapon/offhand/update_icon()
	return

/obj/item/weapon/offhand/dropped(mob/user as mob)
	qdel(src)

/obj/item/weapon/offhand/attackby(obj/I as obj, mob/user as mob)
	if (user.get_inactive_hand() == src)
		user:swap_hand()*/

/mob/living/carbon/human/verb/eject_magazine()
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