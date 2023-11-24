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
	var/breachable = TRUE
	material = "iron"
	icon = 'icons/obj/doors/material_doors_leonister.dmi'

/obj/structure/simple_door/key_door/faction_door
	var/faction = null
	locked = 1

/obj/structure/simple_door/key_door/faction_door/attack_hand(mob/user as mob)
	if(istype(user, /mob/living/human))
		var/mob/living/human/H = user

		if(H.civilization == faction)
			if(!state && !isSwitchingStates)
				Open()
			else if(state && !isSwitchingStates)
				Close()
		else
			user.visible_message(SPAN_NOTICE("[H] knocks at the door."))
			playsound(get_turf(src), "doorknock", 75, TRUE)

/obj/structure/simple_door/key_door/faction_door/Bumped(atom/user)
	if(istype(user, /mob/living/human))
		var/mob/living/human/H = user

		if(H.civilization == faction)
			if(!state && !isSwitchingStates)
				Open()
		else
			user.visible_message(SPAN_NOTICE("[H] knocks at the door."))
			playsound(get_turf(src), "doorknock", 75, TRUE)

/obj/structure/simple_door/key_door/faction_door/Crossed(atom/user)
	if(istype(user, /mob/living/human))
		var/mob/living/human/H = user
		if(H.civilization == faction)
			if(state && !isSwitchingStates)
				spawn(10)
					if (!isSwitchingStates)
						Close()

/obj/structure/simple_door/key_door/New(_loc, _material = null)

	var/map_door_name = name

	..(_loc, _material ? _material : material)

	if (keyslot_type)
		keyslot = new keyslot_type
	else
		keyslot = new()

	health = 300 //same as iron double doors and vice versa
	initial_health = health

	if (istype(src, /obj/structure/simple_door/key_door/anyone/shoji))
		health = 50
		initial_health = health


	spawn (2)
		if (unique_door_name && map_door_name == "door")
			name = "[unique_door_name] door"
		else if (map_door_name != "door")
			name = "[map_door_name] door"

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
				visible_message(SPAN_NOTICE("[user] locks the door."))
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
			else if (locked == 0)
				visible_message(SPAN_NOTICE("[user] unlocks the door."))
				playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
				return
		if (W.code != custom_code)
			user << "This key does not match this lock!"
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		for (var/obj/item/weapon/key/KK in W.contents)
			if (KK.code == custom_code)
				locked = !locked
				if (locked == 1)
					visible_message(SPAN_NOTICE("[user] locks the door."))
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
				else if (locked == 0)
					visible_message(SPAN_NOTICE("[user] unlocks the door."))
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
		if (W.code != custom_code)
			user << "None of the keys match this lock!"
	else if (istype(W, /obj/item/weapon/lockpick))
		if (src.locked == 1)
			var/mob/living/human/H = user
			if (H.getStatCoeff("dexterity") < 1.7)
				user << "You don't have the skills to use this."
				return
			else
				visible_message(SPAN_DANGER("[user] starts picking the [src.name]'s lock with the [W]!"))
				if (do_after(user, 35*H.getStatCoeff("dexterity"), src))
					if(prob(H.getStatCoeff("dexterity")*35))
						user << SPAN_NOTICE("You pick the lock.")
						src.locked = 0
						return
					else if (prob(60))
						qdel(W)
						user << SPAN_NOTICE("Your lockpick broke!")
						return
					else
						return
				return
	else
		if ((W.force > WEAPON_FORCE_WEAK || user.a_intent == I_HARM) && check_can_break_doors(W))
			if (!user.hitting_key_door)
				user.hitting_key_door = TRUE
				visible_message(SPAN_DANGER("[user] hits the door with [W]!"))
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
	else if (istype(W, /obj/item/weapon/lockpick))
		if (keyslot.locked)
			var/mob/living/human/H = user
			if (H.getStatCoeff("dexterity") < 1.7)
				user << "You don't have the skills to use this."
				return
			else
				visible_message(SPAN_DANGER("[user] starts picking the [src.name]'s lock with the [W]!"))
				if (do_after(user, 35*H.getStatCoeff("dexterity"), src))
					if(prob(H.getStatCoeff("dexterity")*35))
						user << SPAN_NOTICE("You pick the lock.")
						keyslot.locked = FALSE
						return
					else if (prob(60))
						qdel(W)
						user << SPAN_WARNING("Your lockpick broke!")
						return
					else
						user << SPAN_WARNING("You failed to pick the lock!")
						return
				return
	else if (istype(W, /obj/item/weapon/gun/projectile/shotgun/pump))
		var/obj/item/weapon/gun/projectile/shotgun/pump/pump = W
		if (breachable && !state && (istype(pump.chambered, /obj/item/ammo_casing/shotgun/buckshot) || istype(pump.chambered, /obj/item/ammo_casing/shotgun/slug) || istype(pump.chambered, /obj/item/projectile/bullet/shotgun/breaching)) && pump.consume_next_projectile())
			locked = FALSE
			update_icon()
			visible_message(SPAN_WARNING("[user] breaks the lock on the [src]!"))
			pump.Fire(src, user)
			playsound(src.loc, 'sound/weapons/heavysmash.ogg', 50, 1)
			density = FALSE
			opacity = FALSE
			state = TRUE
			update_icon()
			isSwitchingStates = FALSE
			for (var/atom/movable/lighting_overlay/L in view(7*3, src))
				L.update_overlay()
			for(var/obj/roof/R in range(1,src))
				R.update_transparency(1)
			new/obj/effect/sparks(src.loc)
			return
	else
		if ((W.force > WEAPON_FORCE_WEAK || user.a_intent == I_HARM) && check_can_break_doors(W))
			if (!user.hitting_key_door)
				user.hitting_key_door = TRUE
				visible_message(SPAN_DANGER("[user] hits the door with [W]!"))
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
			visible_message(SPAN_WARNING("[user] locks the door."))
		else
			visible_message(SPAN_NOTICE("[user] unlocks the door."))
		playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
/obj/structure/simple_door/key_door/custom/attack_hand(mob/user as mob)

	if (!locked)
		return TryToSwitchState(user)
		return
	else
		if (world.time < next_attack_hand)
			return

		if (user.a_intent == I_HELP)
			user.visible_message(SPAN_NOTICE("[user] knocks at the door."))
			for (var/mob/living/L in view(7, src))
				if (!viewers(7, L).Find(user))
					L << SPAN_NOTICE("You hear a knock at the door.")
			playsound(get_turf(src), "doorknock", 75, TRUE)
		else if (user.a_intent == I_DISARM || user.a_intent == I_GRAB)
			user.visible_message(SPAN_WARNING("[user] bangs on the door."))
			for (var/mob/living/L in view(7, src))
				if (!viewers(7, L).Find(user))
					L << SPAN_NOTICE("You hear a knock at the door.")
			playsound(get_turf(src), "doorknock", 100, TRUE)
		else
			user.visible_message(SPAN_DANGER("[user] kicks the door!"))
			if (istype(material, /material/wood))
				playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 100)
			else
				playsound(get_turf(src), 'sound/effects/grillehit.ogg', 100)

		next_attack_hand = world.time + 10

/obj/structure/simple_door/key_door/attack_hand(mob/user as mob)
	if (!istype(src, /obj/structure/simple_door/key_door/custom))
		if (!keyslot.locked || istype(src, /obj/structure/simple_door/key_door/anyone))
			return ..(user)
		else
			if (world.time < next_attack_hand)
				return

			if (user.a_intent == I_HELP)
				user.visible_message(SPAN_NOTICE("[user] knocks at the door."))
				for (var/mob/living/L in view(7, src))
					if (!viewers(7, L).Find(user))
						L << SPAN_NOTICE("You hear a knock at the door.")
				playsound(get_turf(src), "doorknock", 75, TRUE)
			else if (user.a_intent == I_DISARM || user.a_intent == I_GRAB)
				user.visible_message(SPAN_WARNING("[user] bangs on the door."))
				for (var/mob/living/L in view(7, src))
					if (!viewers(7, L).Find(user))
						L << SPAN_NOTICE("You hear a knock at the door.")
				playsound(get_turf(src), "doorknock", 100, TRUE)
			else
				user.visible_message(SPAN_DANGER("[user] kicks the door!"))
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
			visible_message(SPAN_DANGER("The shoji door is torn apart!"))
		else if (istype(src, /obj/structure/simple_door/key_door/anyone/doubledoor/wood || /obj/structure/simple_door/key_door/anyone/nordic || /obj/structure/simple_door/key_door/anyone/wood || /obj/structure/simple_door/key_door/anyone/rustic || /obj/structure/simple_door/key_door/anyone/aztec|| /obj/structure/simple_door/key_door/anyone/singledoor/privacy || /obj/structure/simple_door/key_door/anyone/singledoor/housedoor))
			visible_message(SPAN_DANGER("[src] collapses into a pile of wood splinters!"))
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			qdel(src)
		else if (istype(src, /obj/structure/simple_door/key_door/anyone/doubledoor/bamboo))
			visible_message(SPAN_DANGER("[src] collapses into a pile of bamboo splinters!"))
			new /obj/item/stack/material/bamboo(loc)
			new /obj/item/stack/material/bamboo(loc)
			qdel(src)
		else if (istype(src, /obj/structure/simple_door/key_door/anyone/doubledoor/stone || /obj/structure/simple_door/key_door/anyone/doubledoor/marble || /obj/structure/simple_door/key_door/anyone/roman))
			visible_message(SPAN_DANGER("[src] collapses into a pile of stone rubble!"))
			new /obj/item/stack/material/stone(loc)
			new /obj/item/stack/material/stone(loc)
			qdel(src)
		else if (istype(src, /obj/structure/simple_door/key_door/anyone/doubledoor/sandstone))
			visible_message(SPAN_DANGER("[src] collapses into a pile of sandstone rubble!"))
			new /obj/item/stack/material/sandstone(loc)
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)
		else if (istype(src, /obj/structure/simple_door/key_door/anyone/doubledoor/marble))
			visible_message(SPAN_DANGER("[src] collapses into a pile of marble rubble!"))
			new /obj/item/stack/material/marble(loc)
			new /obj/item/stack/material/marble(loc)
			qdel(src)
		else if (istype(src, /obj/structure/simple_door/key_door/anyone/doubledoor/bone))
			visible_message(SPAN_DANGER("[src] collapses into a pile of bones!"))
			new /obj/item/stack/material/bone(loc)
			new /obj/item/stack/material/bone(loc)
			qdel(src)
		else
			visible_message(SPAN_DANGER("[src] collapses into a pile of scrap metal!"))
		qdel(src)

/obj/structure/simple_door/key_door/proc/damage_display()

	if (health < 20 && !showed_damage_messages[1])
		showed_damage_messages[1] = TRUE
		visible_message(SPAN_DANGER("[src] looks like it's about to break!"))
	else if (health < (initial_health/4) && !showed_damage_messages[2])
		showed_damage_messages[2] = TRUE
		visible_message(SPAN_DANGER("[src] looks extremely damaged!"))
	else if (health < (initial_health/2) && !showed_damage_messages[3])
		showed_damage_messages[3] = TRUE
		visible_message(SPAN_DANGER("[src] looks very damaged."))
	else if (health < (initial_health/1.2) && !showed_damage_messages[4])
		showed_damage_messages[4] = TRUE
		visible_message(SPAN_DANGER("[src] starts to show signs of damage."))
