/obj/structure/closet
	name = "closet"
	desc = "It's a basic storage unit."
	icon = 'icons/obj/closet.dmi'
	icon_state = "closed"
	density = TRUE
	w_class = ITEM_SIZE_HUGE
	var/icon_closed = "closed"
	var/icon_opened = "open"
	var/opened = FALSE
	var/welded = FALSE
	var/wall_mounted = FALSE //never solid (You can always pass over it)
	var/health = 1000
	var/breakout = FALSE //if someone is currently breaking out. mutex
	var/storage_capacity = 2 * MOB_MEDIUM //This is so that someone can't pack hundreds of items in a locker/crate
							  //then open it in a populated area to crash clients.
	var/open_sound = 'sound/machines/Custom_closetopen.ogg'
	var/close_sound = 'sound/machines/Custom_closetclose.ogg'

	var/store_misc = TRUE
	var/store_items = TRUE
	var/store_mobs = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

	var/custom_code = 0
	var/locked = 0
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;opened;locked;custom_code"
/obj/structure/closet/initialize()
	..()
	if (!opened)		// if closed, any item at the crate's loc is put in the contents
		var/obj/item/I
		for (I in loc)
			if (I.density || I.anchored || I == src) continue
			I.forceMove(src)
		// adjust locker size to hold all items with 5 units of free store room
		var/content_size = FALSE
		for (I in contents)
			content_size += ceil(I.w_class/2)
		if (content_size > 0 && content_size > storage_capacity-5)
			storage_capacity = content_size + 5

// max w_class/2 * items = enough to fit items amount of items no matter the size
/obj/structure/closet/proc/update_capacity(items)
	storage_capacity = max((2 * items) + 5,storage_capacity)

/obj/structure/closet/examine(mob/user)
	if (..(user, TRUE) && !opened)
		if(istype(src, /obj/structure/closet/crate/wall_mailbox))
			var/obj/structure/closet/crate/wall_mailbox/WM = src
			if (WM.contents_stored == 0)
				user << "It is empty."
			else if  (WM.contents_stored <= 4 && WM.contents_stored != 0)
				user << "There is something inside."
			else if  (WM.contents_stored == 5)
				user << "It is full."
		else
			var/content_size = FALSE
			for (var/obj/item/I in contents)
				if (!I.anchored)
					content_size += ceil(I.w_class/2)
			if (!content_size)
				user << "It is empty."
			else if (storage_capacity > content_size*4)
				user << "It is barely filled."
			else if (storage_capacity > content_size*2)
				user << "It is less than half full."
			else if (storage_capacity > content_size)
				user << "There is still some free space."
			else
				user << "It is full."

/obj/structure/closet/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (!istype(mover, /obj/item/projectile))
		if (air_group || (height==0 || wall_mounted)) return TRUE
		return !density
	if (prob(60))
		return !density
	else
		return TRUE

/obj/structure/closet/proc/can_open()
	if (welded)
		return FALSE
	return TRUE

/obj/structure/closet/proc/can_close()
	for (var/obj/structure/closet/closet in get_turf(src))
		if (closet != src)
			return FALSE
	return TRUE

/obj/structure/closet/proc/dump_contents()
	//Cham Projector Exception
	for (var/obj/I in src)
		I.forceMove(loc)

	for (var/mob/M in src)
		M.forceMove(loc)
		if (M.client)
			M.client.eye = M.client.mob
			M.client.perspective = MOB_PERSPECTIVE

/obj/structure/closet/proc/open()
	if (opened)
		return FALSE

	if (!can_open())
		return FALSE

	dump_contents()

	icon_state = icon_opened
	opened = TRUE
	playsound(loc, open_sound, 100, TRUE, -3)
	density = FALSE
	return TRUE

/obj/structure/closet/proc/close()
	if (!opened)
		return FALSE

	if (!can_close())
		return FALSE

	var/stored_units = FALSE

	if (store_misc)
		stored_units += store_misc(stored_units)
	if (store_items)
		stored_units += store_items(stored_units)
	if (store_mobs)
		stored_units += store_mobs(stored_units)

	icon_state = icon_closed
	opened = FALSE

	playsound(loc, close_sound, 100, TRUE, -3)
	density = TRUE
	return TRUE

//Cham Projector Exception
/obj/structure/closet/proc/store_misc(var/stored_units)
	var/added_units = 0
	return added_units

/obj/structure/closet/proc/store_items(var/stored_units)
	var/added_units = FALSE
	for (var/obj/item/I in loc)
		var/item_size = ceil(I.w_class / 2)
		if (stored_units + added_units + item_size > storage_capacity)
			continue
		if (!I.anchored)
			I.forceMove(src)
			added_units += item_size
	return added_units

/obj/structure/closet/proc/store_mobs(var/stored_units)
	var/added_units = FALSE
	for (var/mob/living/M in loc)
		if (M.buckled || M.pinned.len)
			continue
		if (stored_units + added_units + M.mob_size > storage_capacity)
			break
		if (M.client)
			M.client.perspective = EYE_PERSPECTIVE
			M.client.eye = src
		M.forceMove(src)
		added_units += M.mob_size
	return added_units

/obj/structure/closet/proc/toggle(mob/user as mob)
	if (!(opened ? close() : open()))
		user << "<span class='notice'>It won't budge!</span>"
		return
	update_icon()

// this should probably use dump_contents()
/obj/structure/closet/ex_act(severity)
	switch(severity)
		if (1)
			for (var/atom/movable/A as mob|obj in src)//pulls everything out of the locker and hits it with an explosion
				A.forceMove(loc)
				A.ex_act(severity + 1)
			qdel(src)
		if (2)
			if (prob(50))
				for (var/atom/movable/A as mob|obj in src)
					A.forceMove(loc)
					A.ex_act(severity + 1)
				qdel(src)
		if (3)
			if (prob(5))
				for (var/atom/movable/A as mob|obj in src)
					A.forceMove(loc)
				qdel(src)

/obj/structure/closet/proc/damage(var/damage)
	health -= damage
	if (health <= 0)
		for (var/atom/movable/A in src)
			A.forceMove(loc)
		qdel(src)

/obj/structure/closet/bullet_act(var/obj/item/projectile/Proj)
	var/proj_damage = Proj.get_structure_damage()
	if (!proj_damage)
		return

	..()
	damage(proj_damage)

	return

/obj/structure/closet/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!opened && !istype(src, /obj/structure/closet/hideout) && !istype(src, /obj/structure/closet/coffin) && !istype(src, /obj/structure/closet/old_coffin))
		if (istype(W, /obj/item/weapon/key))
			var/obj/item/weapon/key/K = W
			if (custom_code == 0 && K.code != 0)
				var/choice = WWinput(user, "Are you sure you want to assign this key to \the [src]?", "Lock", "No", list("Yes","No"))
				if (choice == "No")
					return
				else
					locked = TRUE
					opened = FALSE
					custom_code = K.code
					visible_message("<span class = 'notice'>[user] locks \the [src].</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
			if (K.code == custom_code)
				locked = !locked
				if (locked == 1)
					visible_message("<span class = 'notice'>[user] locks \the [src].</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
				else if (locked == 0)
					visible_message("<span class = 'notice'>[user] unlocks \the [src].</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
		else if (istype(W, /obj/item/weapon/storage/belt/keychain) && custom_code != 0)
			for (var/obj/item/weapon/key/KK in W.contents)
				if (KK.code == custom_code)
					locked = !locked
					if (locked == 1)
						visible_message("<span class = 'notice'>[user] locks the [src].</span>")
						playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
						return
					else if (locked == 0)
						visible_message("<span class = 'notice'>[user] unlocks the [src].</span>")
						playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
						return
			user << "No key in this keychain matches the lock!"
			return
		if (istype(W, /obj/item/weapon/key) && W.code != custom_code)
			user << "This key does not match this lock!"
			return
	if (istype(W, /obj/item/weapon/hammer) && user.a_intent == I_HARM)
		if (!opened)
			user << "You need to open the crate first."
		else
			visible_message("<span class='danger'>[user] begins to deconstruct the [src]!</span>")
			playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
			user.do_attack_animation(src)
			if (do_after(user, 50, user.loc))
				qdel(src)
				return
	if (opened)
		if (istype(W, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = W
			MouseDrop_T(G.affecting, user)	  //act like they were dragged onto the closet
			return FALSE
		if (W.loc != user) // This should stop mounted modules ending up outside the module.
			return
		usr.drop_item()
		if (W)
			if (istype(src, /obj/structure/closet/crate/dumpster))
				var/content_size = FALSE
				for (var/obj/item/I in contents)
					content_size += ceil(I.w_class/2)
				if (content_size < storage_capacity)
					W.forceMove(src)
					user << "You throw \the [W] into \the [src]."
					update_icon()
					return
				else
					user << "<span class='warning'>\The [src] is too full!</span>"
					return
			else
				W.forceMove(loc)
	else
		attack_hand(user)
	return

/obj/structure/closet/MouseDrop_T(atom/movable/O as mob|obj, mob/user as mob)
	if (istype(O, /obj/screen))	//fix for HUD elements making their way into the world	-Pete
		return
	if (O.loc == user)
		return
	if (user.restrained() || user.stat || user.weakened || user.stunned || user.paralysis)
		return
	if ((!( istype(O, /atom/movable) ) || O.anchored || !Adjacent(user) || !Adjacent(O) || !user.Adjacent(O) || user.contents.Find(src)))
		return
	if (!isturf(user.loc)) // are you in a container/closet/pod/etc?
		return
	if (!opened)
		return
	if (istype(O, /obj/structure/closet))
		return
	var/area/A = get_area(src)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall) && map && (!map.faction1_can_cross_blocks() || map.faction2_can_cross_blocks()))
		return
	step_towards(O, loc)
	if (user != O)
		user.show_viewers("<span class='danger'>[user] stuffs [O] into [src]!</span>")
	add_fingerprint(user)
	return

/obj/structure/closet/relaymove(mob/user as mob)
	if (..(user))
		if (user.stat || !isturf(loc))
			return

		if (!open())
			user << "<span class='notice'>It won't budge!</span>"

/obj/structure/closet/attack_hand(mob/user as mob)
	add_fingerprint(user)
	if (locked && !opened)
		user << "<span class='notice'>\The [src] is locked.</span>"
		return
	else
		toggle(user)

/obj/structure/closet/verb/verb_toggleopen()
	var/obj/structure/closet/CO
	if (!istype(CO,/obj/structure/closet/old_coffin))
		set src in oview(1)
		set category = null
		set name = "Toggle Open"

		if (!usr.canmove || usr.stat || usr.restrained())
			return

		if (locked)
			usr << "<span class='warning'>\The [src]is locked!</span>"
			return

		if (ishuman(usr))
			add_fingerprint(usr)
			toggle(usr)
		else
			usr << "<span class='warning'>This mob type can't use this verb.</span>"
	else
		set src in oview(1)
		set category = null
		set name = "Toggle Open"

		if (!usr.canmove || usr.stat || usr.restrained())
			return

		if (locked)
			usr << "<span class='warning'>\The [src]is locked!</span>"
			return

		if (ishuman(usr))
			add_fingerprint(usr)
			usr << "<span class='warning'>you're gonna need to use something to open this</span>"
		else
			usr << "<span class='warning'>This mob type can't use this verb.</span>"

/obj/structure/closet/update_icon()//Putting the welded stuff in updateicon() so it's easy to overwrite for special cases (Fridges, cabinets, and whatnot)
	overlays.Cut()
	if (!opened)
		icon_state = icon_closed
		if (welded)
			overlays += "welded"
	else
		icon_state = icon_opened

/obj/structure/closet/attack_generic(var/mob/user, var/damage, var/attack_message = "destroys", var/wallbreaker)
	if (!damage || !wallbreaker)
		return
	attack_animation(user)
	visible_message("<span class='danger'>[user] [attack_message] the [src]!</span>")
	dump_contents()
	spawn(1) qdel(src)
	return TRUE

/obj/structure/closet/proc/req_breakout()
	if (opened)
		return FALSE //Door's open... wait, why are you in it's contents then?
	if (!welded)
		return FALSE //closed but not welded...
	return TRUE

/obj/structure/closet/proc/mob_breakout(var/mob/living/escapee)
	var/breakout_time = 2 //2 minutes by default

	if (breakout || !req_breakout())
		return

	escapee.setClickCooldown(100)

	//okay, so the closet is either welded or locked... resist!!!
	escapee << "<span class='warning'>You lean on the back of \the [src] and start pushing the door open. (this will take about [breakout_time] minutes)</span>"

	visible_message("<span class='danger'>\The [src] begins to shake violently!</span>")

	breakout = TRUE //can't think of a better way to do this right now.
	for (var/i in TRUE to (6*breakout_time * 2)) //minutes * 6 * 5seconds * 2
		if (!do_after(escapee, 50, src)) //5 seconds
			breakout = FALSE
			return
		if (!escapee || escapee.incapacitated() || escapee.loc != src)
			breakout = FALSE
			return //closet/user destroyed OR user dead/unconcious OR user no longer in closet OR closet opened
		//Perform the same set of checks as above for weld and lock status to determine if there is even still a point in 'resisting'...
		if (!req_breakout())
			breakout = FALSE
			return

		playsound(loc, 'sound/effects/grillehit.ogg', 100, TRUE)
		animate_shake()
		add_fingerprint(escapee)

	//Well then break it!
	breakout = FALSE
	escapee << "<span class='warning'>You successfully break out!</span>"
	visible_message("<span class='danger'>\The [escapee] successfully broke out of \the [src]!</span>")
	playsound(loc, 'sound/effects/grillehit.ogg', 100, TRUE)
	break_open()
	animate_shake()

/obj/structure/closet/proc/break_open()
	welded = FALSE
	update_icon()
	//Do this to prevent contents from being opened into nullspace (read: bluespace)
	open()

/obj/structure/closet/proc/animate_shake()
	var/init_px = pixel_x
	var/shake_dir = pick(-1, TRUE)
	animate(src, transform=turn(matrix(), 8*shake_dir), pixel_x=init_px + 2*shake_dir, time=1)
	animate(transform=null, pixel_x=init_px, time=6, easing=ELASTIC_EASING)

/obj/structure/closet/anchored
	anchored = TRUE

/obj/structure/closet/safe
	name = "safe"
	desc = "A sturdy safe, with a keyslot."
	icon = 'icons/obj/structures.dmi'
	icon_state = "safe"
	icon_closed = "safe"
	icon_opened = "safe-open"
	not_disassemblable = TRUE
	not_movable = TRUE
	anchored = TRUE
	var/faction = null

/obj/structure/closet/safe/red
	New()
		..()
		custom_code = REDCODE
		locked = TRUE
		faction = "Rednikov Industries"
		new /obj/item/stack/money/dollar/twenty(src)
/*
		new /obj/item/weapon/disk/red(src)
		new /obj/item/weapon/disk/red(src)
		new /obj/item/weapon/disk/red(src)
		new /obj/item/weapon/disk/red(src)
		new /obj/item/weapon/disk/red/fake(src)
		new /obj/item/weapon/disk/red/fake(src)
*/
/obj/structure/closet/safe/blue
	New()
		..()
		custom_code = BLUECODE
		locked = TRUE
		faction = "Giovanni Blu Stocks"
		new /obj/item/stack/money/dollar/twenty(src)
/*
		new /obj/item/weapon/disk/blue(src)
		new /obj/item/weapon/disk/blue(src)
		new /obj/item/weapon/disk/blue(src)
		new /obj/item/weapon/disk/blue(src)
		new /obj/item/weapon/disk/blue/fake(src)
		new /obj/item/weapon/disk/blue/fake(src)
*/
/obj/structure/closet/safe/yellow
	New()
		..()
		custom_code = YELLOWCODE
		locked = TRUE
		faction = "Goldstein Solutions"
		new /obj/item/stack/money/dollar/twenty(src)
/*
		new /obj/item/weapon/disk/yellow(src)
		new /obj/item/weapon/disk/yellow(src)
		new /obj/item/weapon/disk/yellow(src)
		new /obj/item/weapon/disk/yellow(src)
		new /obj/item/weapon/disk/yellow/fake(src)
		new /obj/item/weapon/disk/yellow/fake(src)
*/
/obj/structure/closet/safe/green
	New()
		..()
		custom_code = GREENCODE
		locked = TRUE
		faction = "Kogama Kraftsmen"
		new /obj/item/stack/money/dollar/twenty(src)
/*
		new /obj/item/weapon/disk/green(src)
		new /obj/item/weapon/disk/green(src)
		new /obj/item/weapon/disk/green(src)
		new /obj/item/weapon/disk/green(src)
		new /obj/item/weapon/disk/green/fake(src)
		new /obj/item/weapon/disk/green/fake(src)
*/