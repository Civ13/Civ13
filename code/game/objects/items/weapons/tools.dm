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
	w_class = 2.0

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")

/*
 * Fire Extinguisher
 */
/obj/item/weapon/fire_extinguisher
	name = "fire extinguisher"
	desc = "A fire extinguisher filled with foam."
	icon = 'icons/obj/items.dmi'
	icon_state = "fire_extinguisher"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL+5
	throwforce = WEAPON_FORCE_NORMAL+5
	w_class = 3.0

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")
	var/cap = 25
	New()
		..()
		desc = "A fire extinguisher filled with foam. Has [cap] units left."

/obj/item/weapon/fire_extinguisher/attack_self(mob/living/human/user as mob)
	if (!ishuman(user))
		return
	if (cap >= 1)
		visible_message("<span class='notice'>[user] sprays the fire extinguisher!</span>", "<span class='notice'>You spray the fire extinguisher!</span>")
		cap--
		desc = "A fire extinguisher filled with foam. Has [cap] units left."
		var/turf/dest = get_turf(get_step(user, user.dir))
		if (dest)
			for (var/obj/effect/fire/BO in dest)
				qdel(BO)
			for (var/mob/living/human/H in dest)
				if (H.fire_stacks > 0)
					H.fire_stacks = 0
			new/obj/effect/decal/cleanable/foam(dest)
			playsound(dest, 'sound/effects/extinguish.ogg', 100, FALSE)
			return
	else
		user << "<span class='warning'>The fire extinguisher is empty.</span>"
		return

/obj/item/weapon/fire_extinguisher/ww2
	name = "fire extinguisher"
	desc = "A fire extinguisher filled with foam."
	icon = 'icons/obj/items.dmi'
	icon_state = "german_fire_extinguisher"

/*
 * Screwdriver
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
	w_class = 2.0
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
	w_class = 2.0
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
	w_class = 2.0
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
	w_class = 2.0
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
	w_class = 2.0
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
	w_class = 2.0

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
	w_class = 2.0
	flags = FALSE

	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")
	var/cooldown_horn = FALSE

/obj/item/weapon/horn/attack_self(mob/user as mob)
	if (cooldown_horn == FALSE)
		playsound(loc, 'sound/effects/blowing_horn.ogg', 100, FALSE, 25)
		user.visible_message("<span class='warning'>[user] sounds the [name]!</span>")
		cooldown_horn = TRUE
		spawn(100)
			cooldown_horn = FALSE
		return

/obj/item/weapon/whistle
	name = "whistle"
	desc = "Good for ordering the troops to go over the top."
	icon = 'icons/obj/items.dmi'
	icon_state = "whistle"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	item_state = "zippo"
	w_class = 2.0

	attack_verb = list("attacked", "whacked")
	var/cooldown_whistle = FALSE

/obj/item/weapon/whistle/attack_self(mob/user as mob)
	if (cooldown_whistle == FALSE)
		playsound(loc, 'sound/effects/whistle.ogg', 100, FALSE, 5)
		user.visible_message("<span class='warning'>[user] sounds the [name]!</span>")
		cooldown_whistle = TRUE
		spawn(100)
			cooldown_whistle = FALSE
		return

/obj/item/weapon/siegeladder
	name = "siege ladder"
	desc = "A wood ladder, used to climb over walls."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "siege_ladder"
	flags = CONDUCT
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = 4.0
	flags = FALSE

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")
	var/deployed = FALSE
	nothrow = TRUE
	flammable = TRUE
	var/depicon = "siege_ladder_dep"
	var/handicon = "siege_ladder"

/obj/item/weapon/siegeladder/metal
	name = "ladder"
	desc = "A metal ladder, good for climbing things."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "metal_ladder"
	flags = CONDUCT
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = 4.0

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")
	deployed = FALSE
	nothrow = TRUE
	flammable = TRUE
	depicon = "metal_ladder_dep"
	handicon = "metal_ladder"

/obj/item/weapon/siegeladder/attackby(obj/item/weapon/O as obj, mob/user as mob)
	if (deployed)
		user.visible_message(
			"<span class='danger'>\The [user] starts removing \the [src]!</span>",
			"<span class='danger'>You start removing \the [src]!</span>")
		if (do_after(user, 80, src))
			user.visible_message(
				"<span class='danger'>\The [user] has removed \the [src]!</span>",
				"<span class='danger'>You have removed \the [src]!</span>")
			anchored = FALSE
			deployed = FALSE
			icon_state = handicon
			for (var/obj/structure/barricade/ST in src.loc)
				ST.climbable = FALSE
	else
		..()

/obj/structure/barricade/attackby(obj/item/weapon/siegeladder/O as obj, mob/living/user as mob)
	if (istype(O, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [O.name].</span>",
			"<span class='danger'>You start deploying \the [O.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [O.name]!</span>",
				"<span class='danger'>You have deployed \the [O.name]!</span>")
			qdel(O)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	else
		..()

/obj/item/weapon/fishing
	name = "fishing pole"
	desc = "A classic fishing pole."
	icon = 'icons/obj/items.dmi'
	icon_state = "fishing"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = 3.0
	flags = FALSE

	attack_verb = list("bashed", "whacked")
	flammable = TRUE

/obj/item/weapon/fishing/net
	name = "fishing net"
	desc = "A classic fishing net, made of fiberous rope."
	w_class = 2.0
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
	w_class = 3.0

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
	w_class = 2.0
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
	w_class = 2.0

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
	w_class = 3.0
	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")
/*	var/welding = FALSE

/obj/item/weapon/weldingtool/process(var/mob/living/human/L, var/obj/item/weapon/reagent_containers/glass/flamethrower/FM = null)
	if (welding)
		if (!L.back || !istype(L.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
			L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
			setWelding(0)
			return

		if (istype(L.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
			FM = L.back

		if (!FM)
			L << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
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
/obj/item/weapon/weldingtool/proc/get_fuel(var/obj/item/weapon/reagent_containers/glass/flamethrower/FM)
	return FM.reagents.get_reagent_amount("gasoline")


//Removes fuel from the welding tool. If a mob is passed, it will perform an eyecheck on the mob. This should probably be renamed to use()
/obj/item/weapon/weldingtool/proc/remove_fuel(var/amount = TRUE, var/mob/M = null, var/obj/item/weapon/reagent_containers/glass/flamethrower/FM)
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
/obj/item/weapon/weldingtool/proc/setWelding(var/set_welding, var/mob/M, var/obj/item/weapon/reagent_containers/glass/flamethrower/FM)
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
			w_class = 4
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
	w_class = 2.0
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 5

	attack_verb = list("jabbed", "hit", "bashed")
	flammable = TRUE

/obj/item/weapon/whistle/tin
	name = "whistle"
	desc = "A cheap whistle made from tin."
	icon = 'icons/obj/clothing/masks.dmi'
	icon_state = "whistle"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_POCKET
	w_class = 1.0

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
	w_class = 1.0

	attack_verb = list("shanked", "jabbed", "stabbed","shiv'd")
