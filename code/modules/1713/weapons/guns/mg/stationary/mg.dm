/obj/item/weapon/gun/projectile/automatic/stationary/maxim
	name = "Maxim 1895"
	desc = "Russian version of the original Maxim machinegun, on cart mount. Uses Russian 7.62x54mm rounds."
	icon_state = "maxim"
	base_icon = "maxim"
	caliber = "a762x54_weak"
	fire_sound = 'sound/weapons/guns/fire/Maxim.ogg'
	magazine_type = /obj/item/ammo_magazine/maxim
	good_mags = list(/obj/item/ammo_magazine/maxim)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=2, fire_delay=2, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	recoil = 10
	accuracy = 4

/obj/item/weapon/gun/projectile/automatic/stationary/maxim/ww2
	name = "Maxim"
	desc = "Russian version of the original Maxim machinegun, on cart mount. Uses Russian 7.62x54mm rounds."
	icon_state = "maxim_ww2"
	base_icon = "maxim_ww2"
	hardness = 90
	caliber = "a762x54_weak"
	fire_sound = 'sound/weapons/guns/fire/Maxim.ogg'
	magazine_type = /obj/item/ammo_magazine/maxim
	good_mags = list(/obj/item/ammo_magazine/maxim)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=2, fire_delay=2, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	recoil = 10
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/mg08
	name = "Maschinengewehr 08"
	desc = "German Heavy Maxim machinegun, based on the original Maxim. Uses 7.92x57mm Mauser rounds."
	icon_state = "mg08"
	base_icon = "mg08"
	caliber = "a792x57_weak"
	fire_sound = 'sound/weapons/guns/fire/Maxim.ogg'
	magazine_type = /obj/item/ammo_magazine/mg08
	good_mags = list(/obj/item/ammo_magazine/mg08)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=2, fire_delay=2, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	recoil = 10
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/pkm
	name = "PKM machine gun"
	desc = "Soviet Heavy PKM machinegun. Uses 7.62x54mm rounds."
	icon_state = "pkm"
	base_icon = "pkm"
	caliber = "a762x54_weak"
	magazine_type = /obj/item/ammo_magazine/pkm
	good_mags = list(/obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm/c100, /obj/item/ammo_magazine/maxim)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3, fire_delay=1.3, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	recoil = 10
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/dshk
	name = "DShK machine gun"
	desc = "Soviet Heavy DShK machinegun, can also be as anti vehicle gun against some lightly armored vehicles. Uses 12.7x108mm rounds."
	icon_state = "dshk"
	base_icon = "dshk"
	caliber = "a127"
	magazine_type = /obj/item/ammo_magazine/ammo127
	good_mags = list(/obj/item/ammo_magazine/ammo127)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.2, fire_delay=1.2, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a127
	recoil = 25
	accuracy = 1

/obj/item/weapon/gun/projectile/automatic/stationary/nsvt
	name = "NSVT machine gun"
	desc = "Modern Soviet Heavy NSVT machinegun, can also be as anti vehicle gun against some lightly armored vehicles. Uses 12.7x108mm rounds."
	icon_state = "nsvt"
	base_icon = "nsvt"
	caliber = "a127"
	magazine_type = /obj/item/ammo_magazine/ammo127
	good_mags = list(/obj/item/ammo_magazine/ammo127)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.1, fire_delay=1.1, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a127
	recoil = 30
	accuracy = 1

/obj/item/weapon/gun/projectile/automatic/stationary/foldable
	anchored = TRUE
	var/path

/obj/item/weapon/gun/projectile/automatic/stationary/foldable/verb/retrieve()
	set category = null
	set name = "Retrieve"
	set src in range(1, usr)
	if (usr.l_hand && usr.r_hand)
		to_chat(usr, SPAN_WARNING("You need to have a hand free to do this."))
		return
	usr.face_atom(src)

	visible_message(SPAN_WARNING("[usr] starts to get the [src] from the ground."))
	if (do_after(usr, 40, get_turf(usr)))
		unload_ammo(usr)
		qdel(src)
		usr.put_in_any_hand_if_possible(new path, prioritize_active_hand = TRUE)
		visible_message(SPAN_WARNING("[usr] retrieves the [src] from the ground."))

/obj/item/weapon/gun/projectile/automatic/stationary/foldable/pkm
	name = "Foldable PKM machine gun"
	desc = "Soviet Heavy foldable PKM machinegun. Chambered in 7.62x54mm rounds."
	icon_state = "pkm_foldable"
	base_icon = "pkm_foldable"
	caliber = "a762x54_weak"
	fire_sound = 'sound/weapons/guns/fire/Maxim.ogg'
	magazine_type = /obj/item/ammo_magazine/pkm
	good_mags = list(/obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm/c100, /obj/item/ammo_magazine/maxim)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3, fire_delay=1.3, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x54/weak
	recoil = 10
	accuracy = 3

	path = /obj/item/weapon/foldable/pkm

/obj/item/weapon/gun/projectile/automatic/stationary/vickers
	name = "Vickers machine gun"
	desc = "A water-cooled heavy machinegun. Chambered in .303 british rounds."
	icon_state = "vickers"
	base_icon = "vickers"
	caliber = "a303_weak"
	fire_sound = 'sound/weapons/guns/fire/Vickers.ogg'
	magazine_type = /obj/item/ammo_magazine/vickers
	good_mags = list(/obj/item/ammo_magazine/vickers)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=2, fire_delay=2, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a303/weak
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/vickers/type24
	name = "Type 24 machine gun"
	desc = "A water-cooled heavy machinegun. Chambered in 7.92x57mm mauser rounds."
	icon_state = "vickers"
	base_icon = "vickers"
	caliber = "a792x57_weak"
	fire_sound = 'sound/weapons/guns/fire/Vickers.ogg'
	magazine_type = /obj/item/ammo_magazine/mg08
	good_mags = list(/obj/item/ammo_magazine/mg08)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=2, fire_delay=2, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a792x57/weak

/obj/item/weapon/gun/projectile/automatic/stationary/hotchkiss1914
	name = "Hotchkiss M1914 machine gun"
	desc = "A french heavy machinegun. Chambered in 8x50mm Lebel."
	icon_state = "hotchkiss1914"
	base_icon = "hotchkiss1914"
	caliber = "a8x50_weak"
	magazine_type = /obj/item/ammo_magazine/hotchkiss
	good_mags = list(/obj/item/ammo_magazine/hotchkiss)
	ammo_type = /obj/item/ammo_casing/a8x50/weak
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/type3
	name = "Type 3 machine gun"
	desc = "A japanese heavy machinegun based on the French Hotchkiss. Chambered in 6.5x50mm Arisaka."
	icon_state = "type3"
	base_icon = "type3"
	caliber = "a65x50_weak"
	magazine_type = /obj/item/ammo_magazine/type3
	good_mags = list(/obj/item/ammo_magazine/type3)
	ammo_type = /obj/item/ammo_casing/a65x50/weak
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/type98
	name = "Type 92 machine gun"
	desc = "A japanese heavy machinegun. Chambered in 7.7x58mm Arisaka."
	icon_state = "type92hmg"
	base_icon = "type92hmg"
	caliber = "a77x58"
	fire_sound = 'sound/weapons/guns/fire/Type92.ogg'
	magazine_type = /obj/item/ammo_magazine/type92
	good_mags = list(/obj/item/ammo_magazine/type92)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.8, fire_delay=1.8, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a77x58
	attachment_slots = ATTACH_SCOPE
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/type98/update_icon()
	icon_state = "type92hmg[ammo_magazine ? round(ammo_magazine.stored_ammo.len, 5) : "_empty"]"

/obj/structure/type92tripod
	name = "Type 92 Tripod"
	desc = "A tripod for the Type 92 HMG. Slap the gun on it to make use of it."
	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "type92hmg_stand"
	anchored = FALSE
	not_disassemblable = TRUE
	density = TRUE

/obj/structure/type92tripod/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/type92hmg))
		if (do_after(H, 20, H.loc) && src)
			new /obj/item/weapon/gun/projectile/automatic/stationary/type98(src.loc)
			qdel(src)
			qdel(W)
			visible_message("<span class='danger'>[H] starts assembling the Type 92 HMG.</span>", "<span class='danger'>You start assembling the Type 92 HMG.</span>")
			return
	else
		to_chat(usr, SPAN_WARNING("You cant put that on the tripod!"))
		return

/obj/structure/type92tripod/attack_hand(var/mob/living/human/H as mob)
	if (H.l_hand && H.r_hand)
		to_chat(H, SPAN_WARNING("You need to have a hand free to do this."))
		return
	H.face_atom(src)
	visible_message(SPAN_WARNING("[H] starts to retrieve the [src]."))
	if (do_after(H, 20, H.loc) && src)
		H.put_in_any_hand_if_possible(new /obj/item/weapon/type92tripod, prioritize_active_hand = TRUE)
		qdel(src)
		visible_message(SPAN_WARNING("[H] grabs the [src]."))
		return

	visible_message(SPAN_WARNING("[usr] starts to disassemble the [src]."))

/obj/item/weapon/type92tripod
	name = "Type 92 HMG tripod"
	desc = "Used to make gun emplacements"
	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "tripod"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	throwforce = WEAPON_FORCE_NORMAL
	item_state = "tripod"
	w_class = ITEM_SIZE_HUGE
	slowdown = 0.3

	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")

/obj/item/weapon/type92tripod/attack_self(mob/user)
	if (ishuman(user))
		var/turf/targetfloor = get_turf(get_step(user, user.dir))
		if (istype(targetfloor, /turf/wall) || istype(targetfloor, /turf/floor/beach/water/deep/saltwater))
			to_chat(usr, SPAN_WARNING("You cant place this here!."))
			return
		else
			var/mob/living/human/H = user
			visible_message("<span class='danger'>[H] starts placing the Type 92 Tripod.</span>", "<span class='danger'>You start placing the Type 92 Tripod.</span>")
			if (do_after(H, 20, H.loc) && src)
				qdel(src)
				new/obj/structure/type92tripod(get_step(H, H.dir), H)
				visible_message("<span class='danger'>[user] finishes placing the Type 92 Tripod.</span>")
				return

/obj/item/weapon/type92hmg
	name = "Dismounted Type 92 HMG"
	desc = "Slap this on a Type 92 Tripod to assemble the weapon. It's useless otherwise."
	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "type92hmg_item"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	throwforce = WEAPON_FORCE_NORMAL
	item_state = "type92hmg_item"
	w_class = ITEM_SIZE_HUGE
	slowdown = 0.6

	attack_verb = list("attacked", "bashed", "battered", "bludgeoned", "whacked")

/obj/item/weapon/gun/projectile/automatic/stationary/type98/verb/disassemble()
	set category = null
	set name = "Disassemble"
	set src in range(1, usr)
	if (usr.l_hand && usr.r_hand)
		to_chat(usr, SPAN_WARNING("You need to have a hand free to do this."))
		return
	usr.face_atom(src)

	visible_message(SPAN_WARNING("[usr] starts to disassemble the [src]."))
	if (do_after(usr, 40, get_turf(usr)))
		if (src.ammo_magazine)
			unload_ammo(usr)
			new /obj/item/weapon/type92tripod(src.loc)
			new /obj/item/weapon/type92hmg(src.loc)
			qdel(src)
			return
		else
			usr.put_in_any_hand_if_possible(new /obj/item/weapon/type92hmg, prioritize_active_hand = TRUE)
			new /obj/item/weapon/type92tripod(src.loc)
			qdel(src)
			visible_message(SPAN_WARNING("[usr] disassembles the [src]."))
			return


/obj/item/weapon/gun/projectile/automatic/stationary/breda30
	name = "Breda 30 machine gun"
	desc = "The Fucile Mitragliatore Breda modello 30 is a Italian light machinegun that entered service in 1930. The design of the gun is rather impractical and often makes for long reload times. Chambered in 6.5x52mm Carcano."
	icon_state = "type92hmg"
	base_icon = "type92hmg"
	caliber = "a65x52"
	fire_sound = 'sound/weapons/guns/fire/Type92.ogg'
	reload_sound = 'sound/weapons/guns/interact/breda30_clip.ogg'
	magazine_type = /obj/item/ammo_magazine/breda30
	good_mags = list(/obj/item/ammo_magazine/breda30)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=3.0, fire_delay=1.0, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a65x52
	load_method = SINGLE_CASING | SPEEDLOADER
	max_shells = 20
	load_delay = 12
	recoil = 20
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/breda30/update_icon()
	icon_state = "type92hmg[ammo_magazine ? round(ammo_magazine.stored_ammo.len, 5) : "_empty"]"

/obj/item/weapon/gun/projectile/automatic/stationary/breda30/hull
	name = "vehicle mounted Breda 30 machine gun"
	anchored = TRUE
	density = FALSE
	can_turn = FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/solothurn
	name = "Solothurn S-18/1000"
	desc = "The Solothurn S18/1000 20mm is a Swiss anti-tank rifle. It is a later variant of the S-18/100 with modifications for a higher muzzle velocity, as well as a larger cartridge size. The more powerful ammunition resulted in significant recoil, which was problematic for the gunner, and its size made portability difficult."
	icon_state = "type92hmg"
	base_icon = "type92hmg"
	caliber = "a20"
	handle_casings = EJECT_CASINGS
	fire_sound = 'sound/weapons/guns/fire/30mm.ogg'
	reload_sound = 'sound/weapons/guns/interact/breda30_clip.ogg'
	magazine_type = /obj/item/ammo_magazine/a20mm_aphe
	good_mags = list(/obj/item/ammo_magazine/a20mm_aphe)
	firemodes = list(
		list(name = "semiauto", burst=1, burst_delay=1, fire_delay=6.0, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a20mm_aphe
	load_method = SINGLE_CASING | SPEEDLOADER
	max_shells = 10
	load_delay = 60
	recoil = 30
	accuracy = 2

/obj/item/weapon/gun/projectile/automatic/stationary/solothurn/update_icon()
	icon_state = "type92hmg[ammo_magazine ? round(ammo_magazine.stored_ammo.len, 5) : "_empty"]"

/obj/item/weapon/gun/projectile/automatic/stationary/solothurn/italian
	name = "Fucile Controcarri S Mod.39"
	desc = "An Italian variant of the Swiss Solothurn S18/1000 20mm anti-tank rifle. It is a later variant of the S-18/100 with modifications for a higher muzzle velocity, as well as a larger cartridge size. The more powerful ammunition resulted in significant recoil, which was problematic for the gunner, and its size made portability difficult."

/obj/item/weapon/gun/projectile/automatic/stationary/solothurn/italian/stationary
	name = "vehicle mounted Fucile Controcarri S Mod.39"
	anchored = TRUE
	density = FALSE
	can_turn = FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/browning
	name = "M1919A1 browning machine gun"
	desc = "An american heavy machinegun. Chambered in 30-06. rounds."
	icon_state = "browning"
	base_icon = "browning"
	caliber = "a3006"
	fire_sound = 'sound/weapons/guns/fire/M1919.ogg'
	magazine_type = /obj/item/ammo_magazine/browning
	good_mags = list(/obj/item/ammo_magazine/browning)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.8, fire_delay=1.1, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a3006
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/browning/update_icon()
	icon_state = "browning[ammo_magazine ? round(ammo_magazine.stored_ammo.len, 50) : "_empty"]"

/obj/item/weapon/gun/projectile/automatic/stationary/m2browning
	name = "M2HB browning machine gun"
	desc = "An american heavy machinegun. Chambered in .50 cal rounds."
	icon_state = "m2"
	base_icon = "m2"
	caliber = "a50cal"
	fire_sound = 'sound/weapons/guns/fire/M1919.ogg'
	magazine_type = /obj/item/ammo_magazine/a50cal_can
	good_mags = list(/obj/item/ammo_magazine/a50cal_can)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.8, fire_delay=1.1, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a50cal/weak
	recoil = 30
	accuracy = 1

/obj/item/weapon/gun/projectile/automatic/stationary/mg34
	name = "MG 34 machine gun"
	desc = "A german heavy machinegun. Chambered in 7.92x57 Mauser."
	icon_state = "mg34hmg"
	base_icon = "mg34hmg"
	caliber = "a792x57_weak"
	magazine_type = /obj/item/ammo_magazine/mg34belt
	good_mags = list(/obj/item/ammo_magazine/mg34belt, /obj/item/ammo_magazine/mg34)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1, fire_delay=1, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a792x57/weak
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/mg3
	name = "MG 3 machine gun"
	desc = "A german heavy machinegun. Chambered in 7.62x51mm rounds."
	icon_state = "mg3"
	base_icon = "mg3"
	caliber = "a792x57_weak"
	magazine_type = /obj/item/ammo_magazine/mg3belt
	good_mags = list(/obj/item/ammo_magazine/mg3belt)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1, fire_delay=1, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x51/weak
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/fnmag
	name = "FN MAG machine gun"
	desc = "A Belgian general-purpose machine gun, designed in the early 1950s by Ernest Vervier. It has been used by more than 80 countries and it has been made under licence in several countries."
	icon_state = "mg3"
	base_icon = "mg3"
	caliber = "a792x57_weak"
	magazine_type = /obj/item/ammo_magazine/mg3belt
	good_mags = list(/obj/item/ammo_magazine/mg3belt)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1, fire_delay=1, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x51/weak
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/blugoslavia
	name = "BHMG-21 machine gun"
	desc = "A Blugoslavian heavy machinegun. Uses 7.62x54mm rounds."
	icon_state = "pkm"
	base_icon = "pkm"
	caliber = "a762x54"
	magazine_type = /obj/item/ammo_magazine/emptybelt/filled_762x54
	good_mags = list(/obj/item/ammo_magazine/emptybelt,/obj/item/ammo_magazine/emptybelt/filled_762x54)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=1.3, fire_delay=2.5, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x54
	recoil = 25
	accuracy = 3

/obj/item/weapon/gun/projectile/automatic/stationary/redmenia
	name = "RK-42 stationary machine gun"
	desc = "A Redmenian heavy machinegun. Uses 5.56x45mm rounds."
	icon_state = "nsvt"
	base_icon = "nsvt"
	caliber = "a556x45"
	magazine_type = /obj/item/ammo_magazine/emptybelt/filled_556x45
	good_mags = list(/obj/item/ammo_magazine/emptybelt,/obj/item/ammo_magazine/emptybelt/filled_556x45)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=3, fire_delay=2.3, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a762x54
	recoil = 25
	accuracy = 3

// Autocannons

/obj/item/weapon/gun/projectile/automatic/stationary/autocannon
	name = "30mm autocannon"
	desc = "An autocannon capable of putting pretty big holes in people."
	icon_state = "autocannon"
	base_icon = "autocannon"
	caliber = "a30"
	fire_sound = 'sound/weapons/guns/fire/30mm.ogg'
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	magazine_type = /obj/item/ammo_magazine/a30mm_ap
	good_mags = list(/obj/item/ammo_magazine/a30mm_ap, /obj/item/ammo_magazine/a30mm_he)
	firemodes = list(
		list(name = "autocannon", burst=1, burst_delay=3, accuracy=list(2)),
		)
	ammo_type = /obj/item/ammo_casing/a30mm_ap
	is_hmg = TRUE
	anchored = TRUE
	full_auto = FALSE
	recoil = 1
	accuracy = 1

/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params=null)
	var/obj/item/projectile/P = projectile
	P.loc = get_turf(user)
	P.dispersion = clamp(rand(-accuracy, accuracy), -30, 30)
	if(!P.launch(target, user, src))
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/shipunov2a42 // BMD-2
	name = "Shipunov 2A42 30mm autocannon"
	desc = "The 30mm 2A42 autocannon was developed as a replacement for the 2A28 Grom. It fires 30mm rounds."
	icon_state = "autocannon"
	base_icon = "autocannon"
	caliber = "a30"
	fire_sound = 'sound/weapons/guns/fire/30mm.ogg'
	handle_casings = EJECT_CASINGS
	magazine_type = /obj/item/ammo_magazine/a30mm_ap
	good_mags = list(/obj/item/ammo_magazine/a30mm_ap, /obj/item/ammo_magazine/a30mm_he)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=3, accuracy=list(2)),
		)
	ammo_type = /obj/item/ammo_casing/a30mm_ap
	full_auto = TRUE

/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/shipunov2a72 // BTR-80
	name = "Shipunov 2A72 30mm autocannon"
	desc = "A lighter simplified variant of the 2A42 with a lower number of parts, a longer barrel, and higher muzzle velocity, but also a lower rate of fire. It fires 30mm rounds."
	icon_state = "autocannon"
	base_icon = "autocannon"
	caliber = "a30"
	fire_sound = 'sound/weapons/guns/fire/2a72.ogg'
	handle_casings = EJECT_CASINGS
	magazine_type = /obj/item/ammo_magazine/a30mm_ap/btr80
	good_mags = list(/obj/item/ammo_magazine/a30mm_ap/btr80, /obj/item/ammo_magazine/a30mm_he/btr80)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=3, accuracy=list(2)),
		)
	ammo_type = /obj/item/ammo_casing/a30mm_ap
	full_auto = TRUE

/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/bushmaster // CV-90
	name = "Bushmaster III 35mm autocannon"
	desc = "The Bushmaster III is a chain gun, like the other members of the Bushmaster family, which grants it great dependability and safety from ammunition cook-off even though it does result in lower rates of fire."
	icon_state = "autocannon"
	base_icon = "autocannon"
	caliber = "a35"
	fire_sound = 'sound/weapons/guns/fire/2a72.ogg'
	handle_casings = EJECT_CASINGS
	magazine_type = /obj/item/ammo_magazine/a35mm_fap
	good_mags = list(/obj/item/ammo_magazine/a35mm_fap, /obj/item/ammo_magazine/a35mm_hei)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=5, accuracy=list(2)),
		)
	ammo_type = /obj/item/ammo_casing/a30mm_ap
	full_auto = TRUE

/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/bushmaster/bradley
	name = "M242 'Bushmaster' 25mm autocannon"
	desc = "An electrically driven, chain-fed gun used for engaging various targets."
	icon_state = "autocannon"
	base_icon = "autocannon"
	caliber = "a25"
	fire_sound = 'sound/weapons/guns/fire/30mm.ogg'
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	magazine_type = /obj/item/ammo_magazine/a25mm_ap/bradley
	good_mags = list(/obj/item/ammo_magazine/a25mm_ap/bradley, /obj/item/ammo_magazine/a25mm_he/bradley)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=5, accuracy=list(2))
		)
	ammo_type = /obj/item/ammo_casing/a25mm_ap

/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/red
	name = "30mm autocannon"
	desc = "An autocannon capable of firing 20 rounds per minute."
	icon_state = "autocannon"
	base_icon = "autocannon"
	caliber = "a30"
	fire_sound = 'sound/weapons/guns/fire/30mm.ogg'
	load_method = MAGAZINE
	handle_casings = EJECT_CASINGS
	magazine_type = /obj/item/ammo_magazine/a30mm_ap
	good_mags = list(/obj/item/ammo_magazine/a30mm_ap, /obj/item/ammo_magazine/a30mm_ap/small, /obj/item/ammo_magazine/a30mm_he, /obj/item/ammo_magazine/a30mm_he/small)
	firemodes = list(
		list(name = "automatic", burst=1, burst_delay=3, accuracy=list(2)),
		)
	ammo_type = /obj/item/ammo_casing/a30mm_ap
	full_auto = FALSE

// ATGMs

/obj/item/weapon/gun/projectile/automatic/stationary/atgm
	name = "Stationary ATGM"
	desc = "An ATGM system capable of taking out armored targets. This one is firmly bolted to the ground."
	icon_state = "atgm"
	base_icon = "atgm"
	caliber = "rocket"
	fire_sound = 'sound/weapons/guns/fire/rpg7.ogg'
	zoom_amount = ZOOM_CONSTANT*2+4
	load_method = SINGLE_CASING
	handle_casings = REMOVE_CASINGS
	magazine_type = /obj/item/ammo_magazine/mosin
	firemodes = list(
		list(name = "single shot", burst=1, accuracy=list(2)),
		)
	ammo_type = /obj/item/ammo_casing/rocket/atgm
	is_hmg = TRUE
	full_auto = FALSE
	anchored = TRUE

	var/atgm_ammo = /obj/item/ammo_casing/rocket/atgm
	var/max_rockets = 1
	var/list/rockets = new/list()
	var/release_force = 5
	var/firing_range = 30

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, atgm_ammo))
		playsound(src.loc, 'sound/effects/rpgreload.ogg', 80, 0)
		if (rockets.len < max_rockets && do_after(user, load_delay, src, can_move = TRUE))
			user.remove_from_mob(I)
			I.loc = src
			rockets += I
			user.visible_message("[user] loads a [I] into \the [src].", "You load a [I] into \the [src].")
			update_icon()
			return
		else
			to_chat(usr, SPAN_WARNING("\The [src] cannot hold any more rockets."))

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/unload_ammo(mob/user, var/allow_dump=1)
	if (rockets.len)
		for (var/obj/item/ammo_casing/rocket/I in rockets)
			I.loc = get_turf(src)
			rockets -= I
		update_icon()
	else
		to_chat(user, SPAN_WARNING("The ATGM is empty!"))


/obj/item/weapon/gun/projectile/automatic/stationary/atgm/handle_click_empty(mob/user)
	if (rockets.len <= 0)
		if (user)
			user.visible_message("*click click*", SPAN_DANGER("*click*"))
		else
			visible_message("*click click*")
		playsound(loc, 'sound/weapons/empty.ogg', 100, TRUE)

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/consume_next_projectile()
	if (rockets.len)
		var/obj/item/ammo_casing/rocket/I = rockets[1]
		var/obj/item/projectile/shell/missile/M = new I.projectile_type(src)
		playsound(get_turf(src), 'sound/weapons/guns/fire/rpg7.ogg', 100, TRUE)
		rockets -= I
		return M
	return null

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/handle_post_fire(mob/user, atom/target)
	message_admins("[key_name_admin(user)] fired an ATGM at [target].", key_name_admin(user))
	log_game("[key_name_admin(user)] used an ATGM at [target].")
	update_icon()

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/process_projectile(obj/item/projectile, mob/user, atom/target, var/target_zone, var/params=null)
	projectile.loc = get_turf(user)
	if(istype(projectile, /obj/item/projectile/shell))
		var/obj/item/projectile/shell/P = projectile
		P.dir = SOUTH
		P.launch(target, user, src)
		return TRUE

	return FALSE

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/update_icon()
	if (rockets.len > 0)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_empty"

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/kornet
	name = "9K135 Kornet"
	desc = "A highly accurate, Russian laser-guided anti-tank missile system with long-range capabilities and advanced armor penetration, designed for modern battlefield engagements."
	icon_state = "kornet_atgm"
	base_icon = "kornet_atgm"

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/bgm_tow
	name = "BGM-71 TOW"
	desc = "A wire-guided anti-tank missile, known for its effectiveness against armored vehicles at long distances."
	icon_state = "bgm71_tow_atgm"
	base_icon = "bgm71_tow_atgm"

// Foldable ATGMs

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable
	name = "Foldable ATGM"
	desc = "An ATGM system capable of taking out armored targets. You can move this one around by right-clicking it and pressing 'Retrieve'"
	icon_state = "foldable_atgm"
	base_icon = "foldable_atgm"
	var/path = /obj/item/weapon/foldable/atgm

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable/AltClick(mob/living/human/user)
	if(!ishuman(user))
		return
	retrieve()

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable/verb/retrieve()
	set category = null
	set name = "Retrieve"
	set src in range(1, usr)
	if (usr.l_hand && usr.r_hand)
		to_chat(usr, SPAN_WARNING("You need to have a hand free to do this."))
		return
	usr.face_atom(src)
	visible_message(SPAN_WARNING("[usr] starts to get the [src] from the ground."))
	if (do_after(usr, 30, get_turf(usr)))
		for (var/obj/item/ammo_casing/rocket/I in rockets)
			I.loc = get_turf(src)
			rockets -= I
		qdel(src)
		usr.put_in_any_hand_if_possible(new path, prioritize_active_hand = TRUE)
		visible_message(SPAN_WARNING("[usr] retrieves the [src] from the ground."))

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable/kornet
	name = "9K135 Kornet"
	desc = "A highly accurate, Russian laser-guided anti-tank missile system with long-range capabilities and advanced armor penetration, designed for modern battlefield engagements."
	icon_state = "kornet_atgm"
	base_icon = "kornet_atgm"
	path = /obj/item/weapon/foldable/atgm/kornet

/obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable/bgm_tow
	name = "BGM-71 TOW"
	desc = "A wire-guided anti-tank missile, known for its effectiveness against armored vehicles at long distances."
	icon_state = "bgm71_tow_atgm"
	base_icon = "bgm71_tow_atgm"
	path = /obj/item/weapon/foldable/atgm/bgm_tow