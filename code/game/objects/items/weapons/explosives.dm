/obj/item/weapon/plastique
	name = "plastic explosives"
	desc = "Used to put holes in specific areas without too much extra hole."
	gender = PLURAL
	icon = 'icons/obj/grenade.dmi'
	icon_state = "plastic-explosive0"
	item_state = "zippo"
	flags = NOBLUDGEON | CONDUCT
	w_class = ITEM_SIZE_SMALL
	var/timer = 10
	var/atom/target = null
	var/open_panel = FALSE
	var/image_overlay = null

/obj/item/weapon/plastique/c4
	name = "C4 explosive"


/obj/item/weapon/plastique/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/wrench))
		open_panel = !open_panel
		user << "<span class='notice'>You [open_panel ? "open" : "close"] the wire panel.</span>"
		..()

/obj/item/weapon/plastique/attack_self(mob/user as mob)
	var/newtime = WWinput(usr, "Please set the timer.", "Timer", 5, "num")
	if (user.get_active_hand() == src)
		newtime = Clamp(newtime, 3, 60000)
		timer = newtime
		user << "Timer set for [timer] seconds."

/obj/item/weapon/plastique/afterattack(atom/movable/target, mob/user, flag)
	if (!flag)
		return

	if (istype(target, /obj/item/weapon/storage) || istype(target, /obj/item/clothing/accessory/storage) || istype(target, /obj/item/clothing/under))
		return

	user << "Planting explosives..."
	user.do_attack_animation(target)

	if (do_after(user, 50, target) && in_range(user, target))
		user.drop_item()
		target = target
		loc = null

		if (ismob(target))
			add_logs(user, target, "planted [name] on")
			user.visible_message("<span class='danger'>[user.name] finished planting an explosive on [target.name]!</span>")
			message_admins("[key_name(user, user.client)](<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A>) planted [name] on [key_name(target)](<A HREF='?_src_=holder;adminmoreinfo=\ref[target]'>?</A>) with [timer] second fuse",0,1)
			log_game("[key_name(user)] planted [name] on [key_name(target)] with [timer] second fuse")

		else
			message_admins("[key_name(user, user.client)](<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A>) planted [name] on [target.name] at ([target.x],[target.y],[target.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[target.x];Y=[target.y];Z=[target.z]'>JMP</a>) with [timer] second fuse",0,1)
			log_game("[key_name(user)] planted [name] on [target.name] at ([target.x],[target.y],[target.z]) with [timer] second fuse")

		target.overlays += image_overlay
		user << "Bomb has been planted. Timer counting down from [timer]."
		spawn(timer*10)
			explode(get_turf(target))

/obj/item/weapon/plastique/proc/explode(var/turf/location)
	var/original_mobs = list()
	var/original_objs = list()

	if (location)
		explosion(location, 1, 1, 3, 3)
		for (var/mob/living/L in location.contents)
			original_mobs += L
			if (L.client)
				L.canmove = FALSE
		for (var/obj/O in location.contents)
			original_objs += O
		playsound(location, "explosion", 100, TRUE)
		spawn (1)
			for (var/mob/living/L in original_mobs)
				if (L)
					L.maim()
					if (L)
						L.overlays -= image_overlay
						L.canmove = TRUE
			for (var/obj/O in original_objs)
				if (O)
					O.overlays -= image_overlay
					O.ex_act(1.0)
			location.overlays -= image_overlay
			location.ex_act(1.0)
	qdel(src)

/obj/item/weapon/plastique/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		return explode(get_turf(src))

/obj/item/weapon/plastique/attack(mob/M as mob, mob/user as mob, def_zone)
	return


/obj/item/weapon/plastique/New()
	image_overlay = image(icon, "plastic-explosive2")
	..()

/obj/item/weapon/plastique/russian
	name = "explosive charge"
	icon_state = "russian_charge"

/obj/item/weapon/plastique/russian/New()
	image_overlay = image(icon, "russian_charge_placed")
	..()