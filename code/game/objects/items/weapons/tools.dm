//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

/* Tools!
 * Note: Multitools are /obj/item
 *
 * Contains:
 * 		Wrench
 * 		Screwdriver
 * 		Wirecutters
 * 		Welding Tool
 * 		Crowbar
 */

/*
 * Wrench
 */
/obj/item/weapon/wrench
	name = "wrench"
	desc = "A wrench with many common uses. Can be usually found in your hand."
	icon = 'icons/obj/items.dmi'
	icon_state = "wrench"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = ITEM_SIZE_SMALL

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")

/obj/item/weapon/metalfile
	name = "metalfile"
	desc = "A metal file, maybe you could file through metal with this."
	icon = 'icons/obj/items.dmi'
	icon_state = "metalfile"
	flags = CONDUCT
	slot_flags = SLOT_POCKET
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_SMALL

	attack_verb = list("bapped", "bonked", "slapped", "whacked")

/*
 * Fire Extinguisher
 */
/obj/item/weapon/reagent_containers/glass/fire_extinguisher
	name = "fire extinguisher"
	desc = "A fire extinguisher used to put out fires. You can fill it with water."
	icon = 'icons/obj/items.dmi'
	icon_state = "fire_extinguisher"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL+5
	throwforce = WEAPON_FORCE_NORMAL+5
	w_class = ITEM_SIZE_NORMAL

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")
	volume = 30
	var/lastfire = 0
	var/max_range = 1
	New()
		..()
		reagents.add_reagent("water",30)

/obj/item/weapon/reagent_containers/glass/fire_extinguisher/empty/New()
	..()
	return

/obj/item/weapon/reagent_containers/glass/fire_extinguisher/proc/fire(var/mob/living/human/H,var/cdir=null,atom/target)
	if (!H)
		return
	if (world.time<=lastfire)
		return
	if (!H.has_empty_hand(both = FALSE))
		H << "<span class='warning'>You need both hands to use \the [src]!</span>"
		return
	if (!cdir)
		cdir = H.dir
	else
		process_foam(H,cdir,target)
		return

/obj/item/weapon/reagent_containers/glass/fire_extinguisher/proc/process_foam(var/mob/living/human/user, var/cdir = null, atom/target)
	if (!cdir || !(cdir in list(NORTH,SOUTH,EAST,WEST)))
		cdir = user.dir
	if (src.reagents && src.reagents.get_reagent_amount("water") >= 5)
		src.reagents.remove_reagent("water",5)
		lastfire = world.time+12
		var/turf/source_turf = get_turf(user)

		var/list/turfs = getline2(source_turf, target)

		var/distance = 0
		var/stop_at_turf = FALSE

		playsound(source_turf, 'sound/effects/extinguish.ogg', 100, FALSE)

		for(var/turf/T in turfs)
			if(distance > max_range)
				break

			if(T.density)
				if(!istype(T, /obj/structure/barricade) || !istype(T, /obj/structure/window/barrier))
					stop_at_turf = TRUE
			else
				if (distance > 0)
					new/obj/effect/decal/cleanable/foam(T)
					for (var/obj/effect/fire/F in T)
						qdel(F)
					for (var/mob/living/human/H in T)
						if (H.on_fire)
							H.fire_stacks = 0
							H.ExtinguishMob()

			if(T == target.loc)
				if(stop_at_turf)
					break
				continue

			if(stop_at_turf)
				break

			distance++
	else
		user << "<span class='warning'>\The [src] is empty.</span>"
		return

/obj/item/weapon/reagent_containers/glass/fire_extinguisher/ww2
	name = "fire extinguisher"
	desc = "A fire extinguisher used to put out fires. You can fill it with water."
	icon_state = "german_fire_extinguisher"
	New()
		..()
		reagents.add_reagent("water",30)

/*
 * Screwdriver
 */
/obj/item/weapon/screwdriver
	name = "screwdriver"
	desc = "Your archetypal flathead screwdriver, with a nice, heavy polymer handle."
	icon = 'icons/obj/items.dmi'
	icon_state = "screwdriver"
	item_state = "screwdriver"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_POCKET | SLOT_EARS
	force = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_TINY
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 3
	throw_range = 5
	attack_verb = list("stabbed")
	flammable = FALSE

/*
 * Hammers
 */
/obj/item/weapon/hammer
	name = "hammer"
	desc = "Hit stuff apart with this."
	icon = 'icons/obj/items.dmi'
	icon_state = "hammer"
	item_state = "hammer"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = WEAPON_FORCE_NORMAL + 4
	w_class = ITEM_SIZE_SMALL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 5

	attack_verb = list("bludgeoned", "hit")
	flammable = TRUE

/obj/item/weapon/hammer/tribalhammer
	name = "simple wooden mallet"
	desc = "Hit stuff apart with this."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "tribalhammer"
	item_state = "tribalhammer"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = WEAPON_FORCE_NORMAL + 4
	w_class = ITEM_SIZE_SMALL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 5

	attack_verb = list("bludgeoned", "hit")
	flammable = TRUE

/obj/item/weapon/hammer/modern
	name = "clawhammer"
	desc = "For hitting things or pulling them apart."
	icon = 'icons/obj/items.dmi'
	icon_state = "hammer_modern"
	item_state = "hammer_modern"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = WEAPON_FORCE_NORMAL + 6
	w_class = ITEM_SIZE_SMALL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 6
	throw_range = 5

	attack_verb = list("bludgeoned", "hit")
	flammable = FALSE

/obj/item/weapon/globe
	name = "globe"
	desc = "flat earthers hate this thing."
	icon = 'icons/obj/items.dmi'
	icon_state = "globe"
	item_state = "globe"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL + 1
	w_class = ITEM_SIZE_SMALL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 5

	attack_verb = list("bludgeoned", "hit")
	flammable = TRUE


/*
 * Wirecutters
 */

/obj/item/weapon/wirecutters
	name = "wirecutters"
	desc = "This cuts wires."
	icon = 'icons/obj/items.dmi'
	icon_state = "cutters-y"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK
	throw_speed = 2
	throw_range = 9
	w_class = ITEM_SIZE_SMALL
	attack_verb = list("pinched", "nipped")
	sharp = TRUE
	edge = TRUE

/obj/item/weapon/wirecutters/New()
	if (!istype(src, /obj/item/weapon/wirecutters/boltcutters))
		if (prob(50))
			icon_state = "cutters-y"
			item_state = "cutters_yellow"
	..()

/obj/item/weapon/wirecutters/attack(mob/living/human/C as mob, mob/user as mob)
	..()

/*
 * Crowbar
 */

/obj/item/weapon/crowbar
	name = "crowbar"
	desc = "Used to remove floors and to pry open doors."
	icon = 'icons/obj/items.dmi'
	icon_state = "crowbar"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_PAINFUL
	throwforce = WEAPON_FORCE_NORMAL
	item_state = "crowbar"
	w_class = ITEM_SIZE_SMALL

	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")

/obj/item/weapon/horn
	name = "blowing horn"
	desc = "Good for long range communication."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "tribalhorn"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	item_state = "zippo"
	w_class = ITEM_SIZE_SMALL
	flags = FALSE

	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")
	var/cooldown = FALSE
	var/whistle_sound = 'sound/effects/blowing_horn.ogg'

/obj/item/weapon/horn/attack_self(mob/user as mob)
	if (!cooldown)
		playsound(loc, 'sound/effects/blowing_horn.ogg', 100, FALSE, 25)
		user.visible_message(SPAN_WARNING("[user] sounds the [name]!"))
		cooldown = TRUE
		spawn(6 SECONDS)
			cooldown = FALSE
		return

/obj/item/weapon/whistle
	name = "whistle"
	desc = "Good for ordering the troops to go over the top."
	icon = 'icons/obj/items.dmi'
	icon_state = "whistle"
	attack_verb = list("attacked", "whacked")
	slot_flags = SLOT_BELT
	w_class = ITEM_SIZE_SMALL | SLOT_POCKET
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	item_state = "zippo"

	var/cooldown = FALSE
	var/whistle_sound = 'sound/effects/whistle.ogg'

/obj/item/weapon/whistle/attack_self(mob/user as mob)
	if (!cooldown)
		playsound(loc, whistle_sound, 100, FALSE, 5)
		user.visible_message(SPAN_WARNING("[user] sounds the [name]!"))
		cooldown = TRUE
		spawn(6 SECONDS)
			cooldown = FALSE
		return

/obj/item/weapon/whistle/death
	name = "death whistle"
	desc = "Good for terrifying enemy soldiers."
	icon_state = "death_whistle"
	whistle_sound = 'sound/effects/death-whistle.ogg'

/obj/item/weapon/whistle/tin
	name = "whistle"
	desc = "A cheap whistle made from tin."
	icon = 'icons/obj/clothing/masks.dmi'
	icon_state = "whistle"
	w_class = ITEM_SIZE_TINY

/obj/item/weapon/siegeladder
	name = "siege ladder"
	desc = "A wood ladder, used to climb over walls."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "siege_ladder"
	var/depicon = "siege_ladder_dep"
	flags = FALSE
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_LARGE
	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")
	nothrow = TRUE
	flammable = TRUE
	var/deployed = FALSE

/obj/item/weapon/siegeladder/attack_hand(mob/user as mob)
	if (deployed)
		user.visible_message(
			SPAN_DANGER("[user] starts removing \the [src]!"),
			SPAN_DANGER("You start removing \the [src]!"))
		if (do_after(user, 8 SECONDS, src))
			user.visible_message(
				SPAN_DANGER("[user] has removed \the [src]!"),
				SPAN_DANGER("You have removed \the [src]!"))
			anchored = FALSE
			deployed = FALSE
			icon_state = initial(icon_state)
			for (var/obj/structure/ST in get_turf(src))
				ST.climbable = FALSE
			user.put_in_any_hand_if_possible(src, prioritize_active_hand = TRUE)
	else
		..()

/obj/item/weapon/siegeladder/metal
	name = "ladder"
	desc = "A metal ladder, good for climbing things."
	icon_state = "metal_ladder"
	depicon = "metal_ladder_dep"
	flags = CONDUCT
	flammable = FALSE

/obj/item/weapon/siegeladder/grapplinghook
	name = "grappling hook"
	desc = "A grappling hook attached to a rope, good for climbing things."
	icon_state = "grapplehook"
	depicon = "grapplehook_dep"
	w_class = ITEM_SIZE_NORMAL
	flammable = FALSE
	slot_flags = SLOT_SHOULDER | SLOT_ID

/obj/item/weapon/fishing
	name = "fishing pole"
	desc = "A classic fishing pole."
	icon = 'icons/obj/items.dmi'
	icon_state = "fishing"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = ITEM_SIZE_NORMAL
	flags = FALSE

	attack_verb = list("bashed", "whacked")
	flammable = TRUE

/obj/item/weapon/fishing/net
	name = "fishing net"
	desc = "A classic fishing net, made of fiberous rope."
	w_class = ITEM_SIZE_SMALL
	icon_state = "fishing_net"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	slot_flags = null
	attack_verb = list("slapped")
	flammable = TRUE

/obj/item/weapon/fishing/modern
	name = "fishing rod"
	desc = "A modern fishing pole."
	icon = 'icons/obj/items.dmi'
	icon_state = "fishing_modern"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = ITEM_SIZE_NORMAL

	attack_verb = list("bashed", "whacked")
	flammable = TRUE

/obj/item/weapon/goldsceptre
	name = "gold sceptre"
	desc = "A sceptre made of gold."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "goldsceptre"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL+4
	throwforce = WEAPON_FORCE_NORMAL-1
	w_class = ITEM_SIZE_SMALL
	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")

/*
 * Wrench
 */
/obj/item/weapon/shears
	name = "shears"
	desc = "A tool used to collect wool from sheep."
	icon = 'icons/obj/items.dmi'
	icon_state = "shears"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	flags = CONDUCT
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = ITEM_SIZE_SMALL

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")

//////////////////////////////////////////////////////WELDER///////////////////////////////////////////////////////////
/obj/item/weapon/weldingtool
	name = "welding tool"
	desc = "used to weld metals together"
	icon = 'icons/obj/items.dmi'
	icon_state = "ww2_welder_off"
	var/on_state = "ww2_welder_on"
	var/off_state = "ww2_welder_off"
	flags = CONDUCT
	slot_flags = SLOT_BELT

	//Amount of OUCH when it's thrown
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = TRUE
	throw_range = 5
	w_class = ITEM_SIZE_NORMAL
	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")
/*	var/welding = FALSE

/obj/item/weapon/weldingtool/process(var/mob/living/human/L, var/obj/item/weapon/reagent_containers/glass/welding_tank/FM = null)
	if (welding)
		if (!L.back || !istype(L.back,/obj/item/weapon/reagent_containers/glass/welding_tank))
			L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a welder!</span>"
			setWelding(0)
			return

		if (istype(L.back,/obj/item/weapon/reagent_containers/glass/welding_tank))
			FM = L.back

		if (!FM)
			L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a welder!</span>"
			setWelding(0)
			return

		if (prob(5))
			remove_fuel(1)

		if (get_fuel(FM) < 1)
			setWelding(0)

/obj/item/weapon/weldingtool/attack_self(mob/user as mob)
	setWelding(!welding, usr)
	return

//Returns the amount of fuel in the welder
/obj/item/weapon/weldingtool/proc/get_fuel(var/obj/item/weapon/reagent_containers/glass/welding_tank/FM)
	return FM.reagents.get_reagent_amount("gasoline")


//Removes fuel from the welding tool. If a mob is passed, it will perform an eyecheck on the mob. This should probably be renamed to use()
/obj/item/weapon/weldingtool/proc/remove_fuel(var/amount = TRUE, var/mob/M = null, var/obj/item/weapon/reagent_containers/glass/welding_tank/FM)
	if (!welding)
		return FALSE
	if (get_fuel() >= amount)
		FM.reagents.remove_reagent("gasoline", amount)
		if (M)
			eyecheck(M)
		return TRUE
	else
		if (M)
			M << "<span class='notice'>You need more welding fuel to complete this task.</span>"
		return FALSE

//Returns whether or not the welding tool is currently on.
/obj/item/weapon/weldingtool/proc/isOn()
	return welding

/obj/item/weapon/weldingtool/update_icon()
	..()
	icon_state = welding ? on_state : off_state
	var/mob/M = loc
	if (istype(M))
		M.update_inv_l_hand()
		M.update_inv_r_hand()

//Sets the welding state of the welding tool. If you see W.welding = TRUE anywhere, please change it to W.setWelding(1)
//so that the welding tool updates accordingly
/obj/item/weapon/weldingtool/proc/setWelding(var/set_welding, var/mob/M, var/obj/item/weapon/reagent_containers/glass/welding_tank/FM)
	var/turf/T = get_turf(src)
	//If we're turning it on
	if (set_welding && !welding)
		if (get_fuel() > 0)
			if (M)
				M << "<span class='notice'>You switch the [src] on.</span>"
			else if (T)
				T.visible_message("<span class='danger'>\The [src] turns on.</span>")
			force = WEAPON_FORCE_PAINFUL
			damtype = "fire"
			w_class = ITEM_SIZE_LARGE
			welding = TRUE
			update_icon()
			set_light(l_range = 1.4, l_power = TRUE, l_color = COLOR_ORANGE)
			processing_objects |= src
		else
			if (M)
				M << "<span class='notice'>You need more welding fuel to complete this task.</span>"
			return
	//Otherwise
	else if (!set_welding && welding)
		processing_objects -= src
		if (M)
			M << "<span class='notice'>You switch \the [src] off.</span>"
		else if (T)
			T.visible_message("<span class='warning'>\The [src] turns off.</span>")
		force = WEAPON_FORCE_WEAK
		damtype = "brute"
		w_class = initial(w_class)
		welding = FALSE
		update_icon()
		set_light(l_range = FALSE, l_power = FALSE, l_color = COLOR_ORANGE)

//Decides whether or not to damage a player's eyes based on what they're wearing as protection
//Note: This should probably be moved to mob
/obj/item/weapon/weldingtool/proc/eyecheck(mob/user as mob)
	if (!ishuman(user))	return TRUE
	if (istype(user, /mob/living/human))
		var/mob/living/human/H = user
		var/obj/item/organ/eyes/E = H.internal_organs_by_name["eyes"]
		if (!E)
			return
		var/safety = H.eyecheck()
		switch(safety)
			if (FLASH_PROTECTION_MODERATE)
				H << "<span class='warning'>Your eyes sting a little.</span>"
				E.damage += rand(1, 2)/2
				if (E.damage > 12)
					H.eye_blurry += rand(3,6)/2
			if (FLASH_PROTECTION_NONE)
				H << "<span class='warning'>Your eyes burn.</span>"
				E.damage += rand(2, 4)/2
				if (E.damage > 10)
					E.damage += rand(4,10)/2
			if (FLASH_PROTECTION_REDUCED)
				H << "<span class='danger'>Your equipment intensify the welder's glow. Your eyes itch and burn severely.</span>"
				H.eye_blurry += rand(12,20)/2
				E.damage += rand(12, 16)/2
		if (safety<FLASH_PROTECTION_MAJOR)
			if (E.damage > 10)
				user << "<span class='warning'>Your eyes are really starting to hurt. This can't be good for you!</span>"

			if (E.damage >= E.min_broken_damage)
				H << "<span class='danger'>You go blind!</span>"
				H.sdisabilities |= BLIND
			else if (E.damage >= E.min_bruised_damage)
				H << "<span class='danger'>You go blind!</span>"
				H.eye_blind = 5
				H.eye_blurry = 5
				H.disabilities |= NEARSIGHTED
				spawn(100)
					H.disabilities &= ~NEARSIGHTED




/obj/item/weapon/reagent_containers/glass/welding_tank
	name = "portable welding tank"
	desc = "A portable welding tank using gasoline as a fuel source."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "welding_tank"
	item_state = "welding_tank"
	flags = CONDUCT
	sharp = FALSE
	edge = FALSE
	flags = CONDUCT
	nothrow = TRUE
	attack_verb = list("bashed", "hit")
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	flammable = TRUE
	w_class = 10
	slot_flags = SLOT_BACK
	throw_speed = 1
	throw_range = 1
	amount_per_transfer_from_this = 5
	volume = 100
	density = FALSE

/obj/item/weapon/reagent_containers/glass/welding_tank/filled/New()
	..()
	reagents.add_reagent("gasoline",100)
///////////////////////////////////////END OF WELDER/////////////////////////////////////////////////////////////////////////
Shinobi's unfinished welder stuff - siro*/


/obj/item/weapon/gongmallet
	name = "gong mallet"
	desc = "A wooden mallet used to hit a gong."
	icon_state = "gongmallet"
	item_state = "gongmallet"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL + 2
	w_class = ITEM_SIZE_SMALL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 5

	attack_verb = list("jabbed", "hit", "bashed")
	flammable = TRUE

/obj/item/weapon/compass
	name = "compass"
	desc = "An instrument containing a magnetized pointer which shows the direction of magnetic north and bearings from it."
	icon = 'icons/obj/items.dmi'
	icon_state = "compass"
	slot_flags = SLOT_BELT | SLOT_POCKET | SLOT_ID
	w_class = ITEM_SIZE_TINY
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	var/time = 10 SECONDS
	var/max_offset = 6

/obj/item/weapon/compass/attack_self(mob/user as mob)
	var/offset = rand(-max_offset,max_offset)
	var/pos_x = user.x + offset
	var/pos_y = user.y + offset
	var/lat_x = round((world.maxx)/3)
	var/lat_y = round((world.maxy)/3)

	var/pos_dir_x = "-UNKNOWN"
	var/pos_dir_y = "UNKNOWN"

	var/pos_message = "You're in the [pos_dir_y][pos_dir_x] of the area."
	if (do_after(user,time,src))
		if (pos_x <= lat_x)
			pos_dir_x = "WEST"
		else if (pos_x >= 2*lat_x)
			pos_dir_x = "EAST"
		else
			pos_dir_x = ""

		if (pos_y <= lat_y)
			pos_dir_y = "SOUTH"
		else if (pos_y >= 2*lat_y)
			pos_dir_y = "NORTH"
		else
			pos_dir_y = ""

		if (pos_dir_x != "" || pos_dir_y != "")
			pos_message = "You're in the <b>[pos_dir_y][pos_dir_x]</b> of the area."
		else
			pos_message = "You're in the <b>CENTER</b> of the area."
		usr << "You estimate your position to be <b>[pos_x];[pos_y]</b>. [pos_message]"

/obj/item/weapon/compass/modern
	name = "navigation tablet"
	desc = "A tablet programmed specifically to navigate people through rough terrain and to let them know where they are."
	icon_state = "compass_modern"
	slot_flags = SLOT_BELT
	time = 3
	max_offset = 2
	secondary_action = TRUE
	var/on = FALSE

/obj/item/weapon/compass/modern/attack_self(mob/user as mob)
	if (!on)
		usr << SPAN_WARNING("You need to turn the tablet on.")
		return
	else
		. = ..()

/obj/item/weapon/compass/modern/AltClick()
	..()
	turn_on()

/obj/item/weapon/compass/modern/verb/turn_on()
	set name = "Toggle Power"
	set category = null
	if (!on)
		on = TRUE
		icon_state = "compass_modern_on"
		update_icon()
		return
	else
		on = FALSE
		icon_state = "compass_modern"
		update_icon()
		return

/obj/item/weapon/compass/modern/tacmap
	name = "tactical map"
	desc = "A tablet programmed specifically to navigate combatants through rough terrain and to let them know where they are."
	var/image/img

/obj/item/weapon/compass/modern/tacmap/New()
	..()
	switch (map.ID)
		if (MAP_OPERATION_FALCON)
			img = image(icon = 'icons/minimaps.dmi', icon_state = "operation_falcon_map")

/obj/item/weapon/compass/modern/tacmap/examine(mob/user)
	user << browse(getFlatIcon(img),"window=popup;size=630x630")

//////////////////////////////////////////LOCKPICK/////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/lockpick
	name = "lockpick"
	desc = "A lockpick. Used to unlock chests and doors. It does require some skill though."
	icon = 'icons/obj/items.dmi'
	icon_state = "lockpick"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = 5
	throwforce = WEAPON_FORCE_NORMAL
	w_class = ITEM_SIZE_TINY

	attack_verb = list("shanked", "jabbed", "stabbed","shiv'd")
