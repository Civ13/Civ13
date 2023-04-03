/obj/item/weapon/gun/launcher/grenade
	name = "grenade launcher"
	desc = "A bulky pump-action grenade launcher. Holds up to 6 grenades in a revolving magazine."
	icon_state = "grenade_launcher"
	item_state = "grenade_launcher"
	w_class = ITEM_SIZE_HUGE
	force = 10
	
	fire_sound = 'sound/weapons/guns/fire/m79.ogg'
	fire_sound_text = "a metallic thunk"
	recoil = 0
	throw_distance = 40
	release_force = 5
	gun_safety = FALSE

	var/obj/item/weapon/grenade/chambered
	var/list/grenades = new/list()
	var/max_grenades = 5 //holds this + one in the chamber
	var/whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/shell)

	var/blacklisted_grenades = list(
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag)

	matter = list(DEFAULT_WALL_MATERIAL = 2000)

/obj/item/weapon/gun/launcher/grenade/process_projectile(obj/item/projectile, mob/user, atom/target, var/target_zone, var/params=null, var/pointblank=0, var/reflex=0)
	update_release_force(projectile)
	projectile.loc = get_turf(user)
	projectile.throw_at(target, throw_distance, release_force, user)
	projectile.dir = get_dir(src.loc, target.loc)
	projectile.icon_state = "[initial(projectile.icon_state)]_active"
	return TRUE

/obj/item/weapon/gun/launcher/grenade/examine(mob/user)
	if (..(user, 2))
		var/grenade_count = grenades.len + (chambered? 1 : 0)
		to_chat(user, "Has [grenade_count] grenade\s remaining.")
		if (chambered)
			to_chat(user, "\A [chambered] is chambered.")

/obj/item/weapon/gun/launcher/grenade/proc/load(obj/item/weapon/grenade/G, mob/user)
	if (!can_load_grenade_type(G, user))
		return
	if (grenades.len >= max_grenades)
		to_chat(user, "<span class='warning'>\The [src] is full.</span>")
		return

	user.drop_from_inventory(G, src)
	G.loc = src
	grenades.Insert(1, G) //add to the head of the list, so that it is loaded on the next pump

/obj/item/weapon/gun/launcher/grenade/proc/unload(mob/user)
	if (grenades.len)
		var/obj/item/weapon/grenade/G = grenades[grenades.len]
		grenades.len--
		user.put_in_hands(G)
	else
		to_chat(user, "<span class='warning'>\The [src] is empty.</span>")

/obj/item/weapon/gun/launcher/grenade/attackby(obj/item/I, mob/user)
	if ((istype(I, /obj/item/weapon/grenade)))
		if (do_after(user, 10, src, can_move = TRUE))
			load(I, user)
	else
		..()

/obj/item/weapon/gun/launcher/grenade/attack_hand(mob/user)
	if (user.get_inactive_hand() == src)
		unload(user)
	else
		..()

/obj/item/weapon/gun/launcher/grenade/consume_next_projectile()
	if (chambered)
		chambered.dir = src.loc.dir
		chambered.det_time = 15
		chambered.activate(null)
	return chambered

/obj/item/weapon/gun/launcher/grenade/handle_post_fire(mob/user)
	message_admins("[key_name_admin(user)] fired a grenade ([chambered.name]) from a grenade launcher ([src.name]).")
	log_game("[key_name_admin(user)] used a grenade ([chambered.name]) from a grenade launcher ([src.name]).")
	chambered = null
	..()

/obj/item/weapon/gun/launcher/grenade/proc/can_load_grenade_type(obj/item/weapon/grenade/G, mob/user)
	if (is_type_in_list(G, blacklisted_grenades) && ! is_type_in_list(G, whitelisted_grenades))
		to_chat(user, "<span class='warning'>\The [G] doesn't seem to fit in \the [src]!</span>")
		return FALSE
	return TRUE

// For uplink purchase, comes loaded with a random assortment of grenades
/obj/item/weapon/gun/launcher/grenade/loaded/New()
	..()

	var/list/grenade_types = list(
		/obj/item/weapon/grenade/smokebomb = 2,
		/obj/item/weapon/grenade/frag/shell = 1 //dont do this ever again
		)

	var/grenade_type = pickweight(grenade_types)
	chambered = new grenade_type(src)
	for(var/i in 1 to max_grenades)
		grenade_type = pickweight(grenade_types)
		grenades += new grenade_type(src)

//Underslung grenade launcher to be used with the Z8
/obj/item/weapon/gun/launcher/grenade/underslung
	name = "underslung grenade launcher"
	desc = "Not much more than a tube and a firing mechanism, this grenade launcher is designed to be fitted to a rifle."
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "grenade_launcher"
	w_class = ITEM_SIZE_NORMAL
	force = 5
	throw_distance = 40
	max_grenades = 0
	var/A_attached = FALSE
	var/image/ongun
	New()
		..()
		ongun = image("icon" = 'icons/obj/gun_att.dmi', "icon_state" = "[icon_state]_ongun")

/obj/item/weapon/gun/launcher/grenade/underslung/attack_self()
	return

//load and unload directly into chambered
/obj/item/weapon/gun/launcher/grenade/underslung/load(obj/item/weapon/grenade/G, mob/user)
	if (!can_load_grenade_type(G, user))
		return
	if (chambered)
		to_chat(user, "<span class='warning'>\The [src] is already loaded.</span>")
		return

	user.drop_from_inventory(G, src)
	G.loc = src
	chambered = G

/obj/item/weapon/gun/launcher/grenade/underslung/unload(mob/user)
	if (chambered)
		user.put_in_hands(chambered)
		chambered = null
	else
		to_chat(user, "<span class='warning'>\The [src] is empty.</span>")

///////////////////////////////////////
/////LAUNCHERS/////////////////////////
///////////////////////////////////////

//////////////////////////// underslug and launcher ////////////////////////////

/obj/item/weapon/gun/launcher/grenade/underslung/m203
	name = "M203 grenade launcher"
	release_force = 2
	throw_distance = 40
	desc = "Not much more than a tube and a firing mechanism, this grenade launcher is designed to be fitted to a rifle."
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		)

	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/underslung/gp25
	name = "GP-25 'Koster' grenade launcher"
	release_force = 2
	throw_distance = 40
	desc = "Not much more than a tube and a firing mechanism, this grenade launcher is designed to be fitted to a rifle."
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

//Grenade Launcher
/obj/item/weapon/gun/launcher/grenade/standalone
	name = "Standalone Grenade Launcher"
	desc = "A generic standalone grenade launcher"
	icon_state = "hk69"
	item_state = "hk69"
	w_class = ITEM_SIZE_LARGE
	max_grenades = 0
	recoil = 1
	gun_safety = TRUE
	release_force = 2
	throw_distance = 40
	equiptimer = 25
	slot_flags =  SLOT_SHOULDER | SLOT_BACK
	var/cover_opened = FALSE
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/standalone/consume_next_projectile()
	if (!cover_opened)
		return ..()
	else if (chambered | cover_opened)
		chambered.dir = src.loc.dir
		chambered.det_time = 15
		chambered.activate(null)
	return chambered | cover_opened

//load and unload directly into chambered
/obj/item/weapon/gun/launcher/grenade/standalone/load(obj/item/weapon/grenade/G, mob/user)
	if (!can_load_grenade_type(G, user))
		return
	if (!cover_opened)
		return
	if (chambered)
		return

	user.drop_from_inventory(G, src)
	G.loc = src
	chambered = G
	playsound(src, 'sound/weapons/guns/interact/launcher_insertgrenade.ogg', 50, 1)
	update_icon()

/obj/item/weapon/gun/launcher/grenade/standalone/unload(mob/user)
	if (cover_opened)
		if (chambered)
			user.put_in_hands(chambered)
			playsound(src, 'sound/weapons/guns/interact/launcher_empty.ogg', 50, 1)
			chambered = null
			update_icon()
		else
			to_chat(user, "<span class='warning'>\The [src] is empty.</span>")
	else
		to_chat(user, "<span class='warning'>\The [src] is closed.</span>")

/obj/item/weapon/gun/launcher/grenade/standalone/proc/toggle_cover(mob/user)
	cover_opened = !cover_opened
	playsound(src, 'sound/weapons/guns/interact/launcher_openbarrel.ogg', 50, 1)
	update_icon()

/obj/item/weapon/gun/launcher/grenade/standalone/attack_self(mob/user as mob)
	toggle_cover(user)

/obj/item/weapon/gun/launcher/grenade/standalone/update_icon()
	..()
	if (cover_opened)
		if (chambered)
			icon_state = "[initial(icon_state)]_open"
		else
			icon_state = "[initial(icon_state)]_open_empty"
	else
		icon_state = "[initial(icon_state)]"



/obj/item/weapon/gun/launcher/grenade/standalone/hk69
	name = "HK69A1 grenade launcher"
	desc = "A German made multi-use 40mm grenade launcher."
	icon_state = "hk69"
	item_state = "hk69"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/standalone/m79
	name = "M79 Grenade Launcher"
	desc = "An American multi-use 40mm grenade launcher."
	icon_state = "m79"
	item_state = "m79"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/standalone/admin
	name = "Grenade Launcher"
	desc = "By the power of gods you can launch any grenade!"
	icon_state = "m79"
	item_state = "m79"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade
		)
	blacklisted_grenades = null