/obj/item/weapon/bomb
	name = "plastic explosives"
	desc = "Used to put holes in specific areas without too much extra hole."
	gender = PLURAL
	icon = 'icons/obj/grenade.dmi'
	icon_state = "bomb"
	item_state = "plasticx"
	flags = NOBLUDGEON
	w_class = 2.0
//	origin_tech = list(TECH_ILLEGAL = 2)
	var/datum/wires/explosive/c4/wires = null
	var/timer = 10
	var/atom/target = null
	var/open_panel = FALSE
	var/image_overlay = null

//obj/item/weapon/bomb/New()
//	wires = new(src)
	//image_overlay = image('icons/obj/assemblies.dmi', "plastic-explosive2")
	//..()

/obj/item/weapon/bomb/Destroy()
//	qdel(wires)
//	wires = null
	return ..()

/obj/item/weapon/bomb/attack_self(mob/user as mob)
	var/newtime = WWinput(usr, "Please set the fuse length.", "Timer", 5, "num")
	if (user.get_active_hand() == src)
		newtime = Clamp(newtime, 3, 60000)
		timer = newtime
		user << "Fuse set for [timer] seconds."

/obj/item/weapon/bomb/afterattack(atom/movable/target, mob/user, flag)
	if (!flag)
		return

	if (istype(target, /obj/item/weapon/storage) || istype(target, /obj/item/clothing/accessory/storage) || istype(target, /obj/item/clothing/under) || istype(target, /mob))
		return

	user << "Placing explosives..."
	user.do_attack_animation(target)

	if (do_after(user, 50, target) && in_range(user, target))
		user.drop_item()
		target = target
		loc = null
		icon_state = "bomb_active"

		if (ismob(target))
			add_logs(user, target, "planted [name] on")
			user.visible_message("<span class='danger'>[user.name] finished placing an explosive on [target.name]!</span>")
			message_admins("[key_name(user, user.client)](<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A>) placed [name] on [key_name(target)](<A HREF='?_src_=holder;adminmoreinfo=\ref[target]'>?</A>) with [timer] second fuse",0,1)
			log_game("[key_name(user)] placed [name] on [key_name(target)] with [timer] second fuse")

		else
			message_admins("[key_name(user, user.client)](<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A>) placed [name] on [target.name] at ([target.x],[target.y],[target.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[target.x];Y=[target.y];Z=[target.z]'>JMP</a>) with [timer] second fuse",0,1)
			log_game("[key_name(user)] placed [name] on [target.name] at ([target.x],[target.y],[target.z]) with [timer] second fuse")

		target.overlays += image_overlay
		user << "The explosive has been placed. Timer counting down from [timer]."
		icon = "bomb_active"
		spawn(timer*10)
			explode(get_turf(target))

/obj/item/weapon/bomb/proc/explode(var/turf/location)
	var/original_mobs = list()
	var/original_objs = list()

	if (location)
		explosion(location, 0, 0, 2, 3)
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

/obj/item/weapon/bomb/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		return explode(get_turf(src))

/obj/item/weapon/bomb/attack(mob/M as mob, mob/user as mob, def_zone)
	return