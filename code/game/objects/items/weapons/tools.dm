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
	desc = "A red fire extinguisher filled with foam."
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
		desc = "A red fire extinguisher filled with foam. Has [cap] units left."

/obj/item/weapon/fire_extinguisher/attack_self(mob/living/human/user as mob)
	if (!ishuman(user))
		return
	if (cap >= 1)
		visible_message("<span class='notice'>[user] sprays the fire extinguisher!</span>", "<span class='notice'>You spray the fire extinguisher!</span>")
		cap--
		desc = "A red fire extinguisher filled with foam. Has [cap] units left."
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

/*
 * Screwdriver
 */
/obj/item/weapon/hammer
	name = "hammer"
	desc = "Tear stuff apart with this."
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

/obj/item/weapon/globe
	name = "globe"
	desc = "flat earthers hate this thing."
	icon = 'icons/obj/items.dmi'
	icon_state = "globe"
	item_state = "globe"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = WEAPON_FORCE_NORMAL + 1
	w_class = 2.0
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 5

	attack_verb = list("bludgeoned", "hit")
	flammable = TRUE

/obj/item/weapon/hammer/modern
	name = "clawhammer"
	desc = "Tear stuff apart with this."
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

	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")
	var/cooldown_horn = FALSE

/obj/item/weapon/horn/attack_self(mob/user as mob)
	if (cooldown_horn == FALSE)
		playsound(loc, 'sound/effects/blowing_horn.ogg', 100, FALSE, 25)
		user.visible_message("<span class='warning'>[user] sounds the [name]!</span>")
		cooldown_horn = TRUE
		spawn(600)
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
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = 2.0

	attack_verb = list("bashed", "battered", "bludgeoned", "whacked")

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
