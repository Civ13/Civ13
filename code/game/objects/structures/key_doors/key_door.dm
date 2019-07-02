// types that can't break down doors - Kachnov
var/list/nonbreaking_types = list(
	/obj/item/clothing,
	/obj/item/weapon/handcuffs)

/proc/check_can_break_doors(var/atom/a)
	for (var/type in nonbreaking_types)
		if (istype(a, type))
			return FALSE
	return TRUE

/mob/var/hitting_key_door = FALSE

/obj/structure/simple_door/key_door
	var/datum/keyslot/keyslot = null
	var/keyslot_type = null
	var/showed_damage_messages[4]
	var/unique_door_name = null
	var/starts_open = FALSE
	var/next_attack_hand = -1
	material = "iron"
	icon = 'icons/obj/doors/material_doors_leonister.dmi'

/obj/structure/simple_door/key_door/New(_loc, _material = null)

	var/map_door_name = name

	..(_loc, _material ? _material : material)

	if (keyslot_type)
		keyslot = new keyslot_type
	else
		keyslot = new()

	health = 300
	initial_health = health

	if (istype(src, /obj/structure/simple_door/key_door/anyone/shoji))
		health = 50
		initial_health = health


	spawn (2)
		if (unique_door_name && map_door_name == "door")
			name = "[unique_door_name] door"
		else if (map_door_name != "door")
			name = "[map_door_name] Door"

	// should fix doors always being the wrong type
	spawn (5)
		var/initial_material = _material ? _material : initial(material)
		if (material.name != initial_material)
			update_material(initial_material)

	spawn (7)
		if (starts_open)
			Open()

/obj/structure/simple_door/key_door/custom/New(_loc, _material = null)
	health = 600
	initial_health = health
	material = "iron"


/obj/structure/simple_door/key_door/Open()
	..()
	if (!istype(src, /obj/structure/simple_door/key_door/custom))
		keyslot.locked = FALSE
	else
		locked = FALSE

/obj/structure/simple_door/key_door/custom/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/key))
		if (W.code == custom_code)
			locked = !locked
			if (locked == 1)
				visible_message("<span class = 'notice'>[user] locks the door.</span>")
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
			else if (locked == 0)
				visible_message("<span class = 'notice'>[user] unlocks the door.</span>")
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
		if (W.code != custom_code)
			user << "This key does not match this lock!"
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		for (var/obj/item/weapon/key/KK in W.contents)
			if (KK.code == custom_code)
				locked = !locked
				if (locked == 1)
					visible_message("<span class = 'notice'>[user] locks the door.</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
				else if (locked == 0)
					visible_message("<span class = 'notice'>[user] unlocks the door.</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
		if (W.code != custom_code)
			user << "None of the keys match this lock!"
	else
		if ((W.force > WEAPON_FORCE_WEAK || user.a_intent == I_HURT) && check_can_break_doors(W))
			if (!user.hitting_key_door)
				user.hitting_key_door = TRUE
				visible_message("<span class = 'danger'>[user] hits the door with [W]!</span>")
				if (istype(material, /material/wood))
					playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 100)
				else
					playsound(get_turf(src), 'sound/effects/grillehit.ogg', 100)
				update_damage(-W.force)
				spawn (7)
					user.hitting_key_door = FALSE
				return

/obj/structure/simple_door/key_door/attackby(obj/item/W as obj, mob/user as mob)

	var/keyslot_original_locked = keyslot.locked

	if (istype(W, /obj/item/weapon/key))
		if (istype(src, /obj/structure/simple_door/key_door/anyone))
			return
		if (keyslot.check_weapon(W, user, TRUE))
			keyslot.locked = !keyslot.locked
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		if (istype(src, /obj/structure/simple_door/key_door/anyone))
			return
		if (keyslot.check_weapon(W, user, TRUE))
			keyslot.locked = !keyslot.locked
	else
		if ((W.force > WEAPON_FORCE_WEAK || user.a_intent == I_HURT) && check_can_break_doors(W))
			if (!user.hitting_key_door)
				user.hitting_key_door = TRUE
				visible_message("<span class = 'danger'>[user] hits the door with [W]!</span>")
				if (istype(material, /material/wood))
					playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 100)
				if (istype(material, /material/paper))
					playsound(get_turf(src), 'sound/effects/cardboardpunch.ogg', 100)
				else
					playsound(get_turf(src), 'sound/effects/grillehit.ogg', 100)
				update_damage(-W.force)
				spawn (7)
					user.hitting_key_door = FALSE
				return

	var/keyslot_locked = keyslot.locked

	if (keyslot_original_locked != keyslot_locked)
		if (keyslot_locked)
			visible_message("<span class = 'warning'>[user] locks the door.</span>")
		else
			visible_message("<span class = 'notice'>[user] unlocks the door.</span>")
		playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
/obj/structure/simple_door/key_door/custom/attack_hand(mob/user as mob)

	if (!locked)
		return TryToSwitchState(user)
		return
	else
		if (world.time < next_attack_hand)
			return

		if (user.a_intent == I_HELP)
			user.visible_message("<span class = 'notice'>[user] knocks at the door.</span>")
			for (var/mob/living/L in view(7, src))
				if (!viewers(7, L).Find(user))
					L << "<span class = 'notice'>You hear a knock at the door.</span>"
			playsound(get_turf(src), "doorknock", 75, TRUE)
		else if (user.a_intent == I_DISARM || user.a_intent == I_GRAB)
			user.visible_message("<span class = 'warning'>[user] bangs on the door.</span>")
			for (var/mob/living/L in view(7, src))
				if (!viewers(7, L).Find(user))
					L << "<span class = 'notice'>You hear a knock at the door.</span>"
			playsound(get_turf(src), "doorknock", 100, TRUE)
		else
			user.visible_message("<span class = 'danger'>[user] kicks the door!</span>")
			if (istype(material, /material/wood))
				playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 100)
			else
				playsound(get_turf(src), 'sound/effects/grillehit.ogg', 100)
			update_damage(-10)

		next_attack_hand = world.time + 10

/obj/structure/simple_door/key_door/attack_hand(mob/user as mob)
	if (!istype(src, /obj/structure/simple_door/key_door/custom))
		if (!keyslot.locked || istype(src, /obj/structure/simple_door/key_door/anyone))
			return ..(user)
		else
			if (world.time < next_attack_hand)
				return

			if (user.a_intent == I_HELP)
				user.visible_message("<span class = 'notice'>[user] knocks at the door.</span>")
				for (var/mob/living/L in view(7, src))
					if (!viewers(7, L).Find(user))
						L << "<span class = 'notice'>You hear a knock at the door.</span>"
				playsound(get_turf(src), "doorknock", 75, TRUE)
			else if (user.a_intent == I_DISARM || user.a_intent == I_GRAB)
				user.visible_message("<span class = 'warning'>[user] bangs on the door.</span>")
				for (var/mob/living/L in view(7, src))
					if (!viewers(7, L).Find(user))
						L << "<span class = 'notice'>You hear a knock at the door.</span>"
				playsound(get_turf(src), "doorknock", 100, TRUE)
			else
				user.visible_message("<span class = 'danger'>[user] kicks the door!</span>")
				if (istype(material, /material/wood))
					playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 100)
				if (istype(material, /material/paper))
					playsound(get_turf(src), 'sound/effects/cardboardpunch.ogg', 100)
				else
					playsound(get_turf(src), 'sound/effects/grillehit.ogg', 100)
				update_damage(-10)

			next_attack_hand = world.time + 10

/obj/structure/simple_door/key_door/Bumped(atom/user)
	if (istype(src, /obj/structure/simple_door/key_door/custom))
		if (!locked)
			return ..(user)
		else
			return FALSE
	else
		if (!keyslot.locked || istype(src, /obj/structure/simple_door/key_door/anyone))
			return ..(user)
		else
			return FALSE


/obj/structure/simple_door/key_door/proc/update_damage(amt)
	health += amt
	damage_display()
	if (health <= 0)
		if (istype(src, /obj/structure/simple_door/key_door/anyone/shoji))
			visible_message("<span class = 'danger'>The shoji door is torn apart!</span>")
		else
			visible_message("<span class = 'danger'>[src] collapses into a pile of scrap metal!</span>")
		qdel(src)

/obj/structure/simple_door/key_door/proc/damage_display()

	if (health < 20 && !showed_damage_messages[1])
		showed_damage_messages[1] = TRUE
		visible_message("<span class = 'danger'>[src] looks like it's about to break!</span>")
	else if (health < (initial_health/4) && !showed_damage_messages[2])
		showed_damage_messages[2] = TRUE
		visible_message("<span class = 'danger'>[src] looks extremely damaged!</span>")
	else if (health < (initial_health/2) && !showed_damage_messages[3])
		showed_damage_messages[3] = TRUE
		visible_message("<span class = 'danger'>[src] looks very damaged.</span>")
	else if (health < (initial_health/1.2) && !showed_damage_messages[4])
		showed_damage_messages[4] = TRUE
		visible_message("<span class = 'danger'>[src] starts to show signs of damage.</span>")
