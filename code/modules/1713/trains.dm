/obj/structure/rails
	name = "rails"
	desc = "Rails used by trains."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "rails"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = FALSE
	layer = 2.5
	var/switched = "forward"
	var/turn_dir = null
	var/sw_direction = "forward"
	New()
		..()
		spawn(5)
			update_icon()
/obj/structure/rails/regular/update_icon()
	..()
	if (dir == NORTH || dir == SOUTH)
		for (var/obj/structure/rails/R in get_step(src, WEST))
			if (R.icon_state == "rails_split_f_left" || R.icon_state == "rails_split_s_left")
				if (R.dir == SOUTH)
					icon_state = "rails_split1"
					dir = R.dir
			if (R.icon_state == "rails_split_f_right" || R.icon_state == "rails_split_s_right")
				if (R.dir == NORTH)
					icon_state = "rails_split1"
					dir = R.dir
		for (var/obj/structure/rails/R in get_step(src, EAST))
			if (R.icon_state == "rails_split_f_left" || R.icon_state == "rails_split_s_left")
				if (R.dir == NORTH)
					icon_state = "rails_split2"
					dir = R.dir
			if (R.icon_state == "rails_split_f_right" || R.icon_state == "rails_split_s_right")
				if (R.dir == SOUTH)
					icon_state = "rails_split2"
					dir = R.dir
	else if (dir == EAST || dir == WEST)
		for (var/obj/structure/rails/R in get_step(src, SOUTH))
			if (R.icon_state == "rails_split_f_left" || R.icon_state == "rails_split_s_left")
				if (R.dir == EAST)
					icon_state = "rails_split2"
					dir = OPPOSITE_DIR(R.dir)
			if (R.icon_state == "rails_split_f_right" || R.icon_state == "rails_split_s_right")
				if (R.dir == WEST)
					icon_state = "rails_split2"
					dir = OPPOSITE_DIR(R.dir)
		for (var/obj/structure/rails/R in get_step(src, NORTH))
			if (R.icon_state == "rails_split_f_left" || R.icon_state == "rails_split_s_left")
				if (R.dir == WEST)
					icon_state = "rails_split1"
					dir = OPPOSITE_DIR(R.dir)
			if (R.icon_state == "rails_split_f_right" || R.icon_state == "rails_split_s_right")
				if (R.dir == EAST)
					icon_state = "rails_split1"
					dir = OPPOSITE_DIR(R.dir)
	spawn(10) 
		update_icon()

/obj/structure/rails/regular/horizontal/New()
	..()
	dir = 4
/obj/structure/rails/end
	icon_state = "rails_end"

/obj/structure/rails/split
	icon_state = "rails_split"

/obj/structure/rails/turn/right
	icon_state = "rails_turn_right"
	sw_direction = "right"
	New()
		..()
		switch(dir)
			if (1)
				turn_dir = 4
			if (2)
				turn_dir = 8
			if (4)
				turn_dir = 2
			if (8)
				turn_dir = 1

/obj/structure/rails/turn
	icon_state = "rails_turn_left"
	sw_direction = "left"
	New()
		..()
		switch(dir)
			if (1)
				turn_dir = 8
			if (2)
				turn_dir = 4
			if (4)
				turn_dir = 1
			if (8)
				turn_dir = 2

/obj/structure/rails/split/switcher
	icon_state = "rails_split_f_left"
	name = "rail switcher"
	desc = "used to switch between two train tracks. It is set to go forward."
	switched = "forward"
	sw_direction = "left"

/obj/structure/rails/split/switcher/right
	icon_state = "rails_split_f_right"
	name = "rail switcher"
	desc = "used to switch between two train tracks. It is set to go forward."
	switched = "forward"
	sw_direction = "right"

/obj/structure/rails/split/switcher/update_icon()
	if (switched == "forward")
		icon_state = "rails_split_f_[sw_direction]"
	else
		icon_state = "rails_split_s_[sw_direction]"

/obj/structure/rails/rotate
	name = "rotating rail"
	desc = "A rotating platform that allows wagons to switch direction."
	icon_state = "rails_rotate"

/obj/structure/rails/rotate/verb/rotate_left()
	set name = "Rotate Left"
	set category = null
	set desc = "Rotate the platform"
	set src in oview(1)

	if (!istype(usr, /mob/living/human))
		return

	set_dir(turn(dir, -90))
	for (var/obj/structure/trains/TR in loc)
		TR.dir = dir
	playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
	usr << "You rotate the platform to the left."
	return

/obj/structure/rails/rotate/verb/rotate_right()
	set name = "Rotate Right"
	set category = null
	set desc = "Rotate the platform"
	set src in oview(1)

	if (!istype(usr, /mob/living/human))
		return

	set_dir(turn(dir, 90))
	for (var/obj/structure/trains/TR in loc)
		TR.dir = dir
	playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
	usr << "You rotate the platform to the right."
	return

/obj/structure/rails/rotate/attack_hand(mob/living/user as mob)
	switch(dir)
		if (1)
			dir = 8
		if (2)
			dir = 4
		if (4)
			dir = 1
		if (8)
			dir = 2
	for (var/obj/structure/trains/TR in loc)
		TR.dir = dir
	playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
	user << "You rotate the platform to the [dir2text(dir)]."
	return
/////////////////////////////////////////////////////////////////////////////////
/obj/structure/train_lever
	name = "rail switch lever"
	desc = "A lever used to switch between tracks."
	icon = 'icons/obj/vehicles/train_lever.dmi'
	icon_state = "lever_none"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/switched = "forward"

/obj/structure/train_lever/update_icon()
	if (switched == "forward")
		icon_state = "lever_none"
	else
		icon_state = "lever_pulled"

/obj/structure/train_lever/attack_hand(mob/living/user as mob)
	if (istype(user, /mob/living))
		if (switched == "forward")
			switched = "split"
			for (var/obj/structure/rails/split/switcher/S in range(2,src))
				S.switched = "split"
				S.update_icon()
			visible_message("<span class = 'notice'>[user] moves the lever into the splitting position!</span>", "<span class = 'notice'>You move the lever into the splitting position!</span>")
			playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
			return
		else
			switched = "forward"
			for (var/obj/structure/rails/split/switcher/S in range(2,src))
				S.switched = "forward"
				S.update_icon()
			visible_message("<span class = 'notice'>[user] moves the lever into the forward position!</span>", "<span class = 'notice'>You move the lever into the forward position!</span>")
			update_icon()
			playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
			return

/////////////////////////////////////////////////////////////////////////////////

/obj/structure/trains
	name = "wagon"
	desc = "A wagon meant to be used on rails."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "miningcar"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/automovement = FALSE
	var/health = 1000
	var/train_speed = 6 //deciseconds of delay, so lower is better
	var/max_train_speed = 6
	var/locomotive = FALSE
	var/list/transporting = list()
	var/on = FALSE
	var/obj/structure/trains/connected = null

/obj/structure/trains/verb/hitch()
	set category = null
	set name = "Hitch"
	set desc = "Hitch or unhitch to the wagon ahead."

	set src in view(1)

	if (!istype(usr, /mob/living/human))
		return


	for (var/obj/structure/trains/TR in get_step(src, dir))
		if (TR.connected && TR.connected == src)
			playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
			usr << "You unhitch \the [src] from \the [connected]."
			connected = null
			return TRUE
		else if (!TR.connected)
			if (dir == TR.dir || dir == OPPOSITE_DIR(TR.dir))
				playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
				usr << "You hitch \the [src] to \the [TR]."
				TR.connected = src
				return TRUE
	usr << "There is no wagon to hitch \the [src] to."
	return FALSE

/obj/structure/trains/proc/check_connections()
	if (!connected)
		return FALSE
	if (connected in range(2,src))
		return TRUE
	else
		connected = null
		return FALSE
/obj/structure/trains/Bumped(atom/AM)
	check_connections()
	var/turf/tgt = get_step(src,AM.dir)
	if (!tgt)
		return FALSE
	if (isliving(AM))
		var/mob/living/ML = AM
		for (var/obj/structure/trains/TR in AM.loc)
			if (istype(src, /obj/structure/trains/transport))
				ML.forceMove(loc)
				return FALSE
			return FALSE
		if (ML.mob_size < MOB_MEDIUM || (ML.dir != dir && ML.dir != OPPOSITE_DIR(dir)))
			return FALSE
		for (var/obj/structure/trains/TR in tgt)
			return FALSE
	if (rail_canmove(AM.dir))
		src.Move(tgt)
		return TRUE
/obj/structure/trains/Move(var/turf/newloc, var/fdir = dir)
	check_connections()
	if (buckled_mob && map.check_caribbean_block(buckled_mob, newloc))
		return FALSE
/*
	var/turf/behind = get_step(src,OPPOSITE_DIR(dir))
	var/turf/oldloc = loc
	dir = fdir

	for (var/obj/structure/rails/turn/TR in oldloc)
		if (dir != TR.turn_dir && dir == TR.dir)
			behind = get_step(src,OPPOSITE_DIR(TR.turn_dir))

		else if (dir != TR.dir && dir == TR.turn_dir)
			behind = get_step(src,OPPOSITE_DIR(TR.dir))

	for (var/obj/structure/trains/T in behind)
		T.Move(oldloc, dir)
*/

	var/turf/oldloc = loc

	..(newloc)
	dir = fdir
	if (buckled_mob)
		if (buckled_mob.buckled == src)
			buckled_mob.loc = loc
		else
			buckled_mob = null
	for (var/mob/living/L in oldloc)
		L.loc = loc
	for (var/obj/O in oldloc)
		if (O.anchored && O in transporting)
			O.loc = loc
	if (connected)
		connected.Move(oldloc, dir)

	for (var/obj/O in transporting)
		if (get_dist(O, src) >= 2)
			transporting -= O
	for (var/obj/item/I in transporting)
		I.update_light()
	return TRUE

/obj/structure/trains/proc/rail_movement()
	if (!automovement)
		playsound(src.loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
		on = FALSE
		return FALSE
	spawn(train_speed)
		if (!automovement)
			playsound(src.loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
			on = FALSE
			return FALSE
		process_rail_movement()
		rail_movement()
		rail_sound()

/obj/structure/trains/proc/rail_sound()
	if (automovement)
		spawn(10)
			playsound(src.loc, 'sound/machines/train/moving.ogg', 100, TRUE)

/obj/structure/trains/proc/process_rail_movement()
	var/fdir = dir
	if (automovement)
		var/turf/tgtt = get_step(src,dir)
		var/turf/curr = get_turf(src)
		if (!curr || !tgtt)
			automovement = FALSE
			set_light(0)
			return FALSE
		if (istype(src, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = src
			if (L.fuel <= 0 && L.on)
				automovement = FALSE
				visible_message("\The [src]'s engine stalls.")
				set_light(0)
				return FALSE
			else if (L.on)
				L.fuel--
				L.set_speed()
//				world.log << "[L.train_speed]"
		var/obj/structure/rails/RT = null
		for (var/obj/structure/rails/RTT in loc)
			RT = RTT
		if (RT && istype(RT, /obj/structure/rails/split/switcher) && RT.switched == "split" && RT.dir == dir && rail_canmove(dir))
			if (RT.sw_direction == "left")
				switch(RT.dir)
					if (1)
						tgtt = get_step(RT, 8)
					if (2)
						tgtt = get_step(RT, 4)
					if (4)
						tgtt = get_step(RT, 1)
					if (8)
						tgtt = get_step(RT, 2)
			else if (RT.sw_direction == "right")
				switch(RT.dir)
					if (1)
						tgtt = get_step(RT, 4)
					if (2)
						tgtt = get_step(RT, 8)
					if (4)
						tgtt = get_step(RT, 2)
					if (8)
						tgtt = get_step(RT, 1)
		else if (RT && istype(RT, /obj/structure/rails/turn) && RT.turn_dir)
//			world.log << "d: [dir]"
//			world.log << "od: [OPPOSITE_DIR(dir)]"
//			world.log << "rd: [RT.dir]"
//			world.log << "td: [RT.turn_dir]"
			if (RT.turn_dir == dir)
//				world.log << "a"
				fdir = RT.dir
				tgtt = get_step(RT, RT.dir)
			else if (RT.turn_dir == OPPOSITE_DIR(dir))
//				world.log << "b"
				fdir = OPPOSITE_DIR(RT.dir)
				tgtt = get_step(RT, OPPOSITE_DIR(RT.dir))
			else if (RT.dir == dir)
//				world.log << "c"
				fdir = RT.turn_dir
				tgtt = get_step(RT, RT.turn_dir)
			else if (RT.dir == OPPOSITE_DIR(dir))
//				world.log << "d"
				fdir = OPPOSITE_DIR(RT.turn_dir)
				tgtt = get_step(RT, OPPOSITE_DIR(RT.turn_dir))
		if (!rail_canmove(fdir))
			automovement = FALSE
			set_light(0)
			return FALSE
		//push (or hit) wtv is in front...
		for (var/obj/structure/trains/TF in tgtt)
			visible_message("<span class = 'warning'>\The [src] hits \the [TF]!</span>")
			automovement = FALSE
			health -= 5
			return FALSE
		for (var/obj/O in tgtt)
			if (O.density && !istype(O, /obj/structure/trains) && !istype(O, /obj/structure/rails))
				visible_message("<span class = 'warning'>\The [src] hits \the [O]!</span>")
				O.ex_act(1.0)
				health -= 15*O.w_class
				automovement = FALSE
				return FALSE
		for (var/mob/living/L in tgtt)
			var/found = FALSE
			for (var/obj/structure/trains/TT in tgtt)
				found = TRUE
			if (!found)
				visible_message("<span class = 'warning'>\The [src] hits \the [L]!</span>")
				health -= 8
				automovement = FALSE
				L.adjustBruteLoss(100)
				return FALSE
		// ... and move this train
		src.Move(tgtt, fdir)
		set_light(2)
		return TRUE
	return FALSE
/obj/structure/trains/proc/rail_canmove(mdir=dir)
	var/turf/tgtt = get_step(src,mdir)
	if (!tgtt)
		return FALSE
	for (var/obj/structure/rails/R in tgtt)
		if (mdir == 1 || mdir == 2)
			if (R.dir == 1 || R.dir == 2)
				return TRUE
			if (R.turn_dir == 1 || R.turn_dir == 2)
				return TRUE
		else if (mdir == 4 || mdir == 8)
			if (R.dir == 4 || R.dir == 4)
				return TRUE
			if (R.turn_dir == 4 || R.turn_dir == 8)
				return TRUE
			return TRUE
	return FALSE
//////////////////////////////////////////////////////////////////////////
/obj/structure/trains/storage
	var/max_storage = 7
	var/obj/item/weapon/storage/internal/storage


/obj/structure/trains/storage/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = max_storage
	storage.max_w_class = 5
	storage.max_storage_space = max_storage*5
	update_icon()

/obj/structure/trains/storage/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/trains/storage/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/human) && user in range(1,src))
		storage.open(user)
		update_icon()
	else
		return
/obj/structure/trains/storage/MouseDrop(obj/over_object as obj)
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/trains/storage/attackby(obj/item/W as obj, mob/user as mob)
	..()
	storage.attackby(W, user)
	update_icon()

/obj/structure/trains/storage/miningcart
	name = "mining cart"
	desc = "A wooden mining cart, for underground rails."
	icon_state = "miningcar"

/obj/structure/trains/storage/tender
	name = "tender wagon"
	desc = "A wagon made to carry fuel for the engine."
	icon_state = "coal_wagon"
	max_storage = 15
	New()
		..()
		storage.can_hold = list(/obj/item/stack/ore/coal, /obj/item/clothing/accessory/storage/sheath/katana/full, /obj/item/weapon/branch)

/obj/structure/trains/storage/closed
	name = "transport wagon"
	desc = "A covered wagon with lots of internal space."
	icon_state = "closed_wagon"
	max_storage = 8
//////////////////////////////////////////////////////////////////////////////////
/obj/structure/trains/transport
	name = "flatbed cart"
	icon_state = "flatbed"
	can_buckle = TRUE
	buckle_lying = FALSE

/obj/structure/trains/transport/MouseDrop_T(atom/movable/M, mob/living/user)
	if (!istype(user, /mob/living))
		return
	if (!istype(M, /obj) && !istype(M, /mob/living))
		return
	if  (!istype(M, /mob/living))
		var/obj/AM = M
		if (istype(AM, /obj/item) || istype(AM, /obj/structure))
			if (!AM.anchored)
				visible_message("[user] starts dragging \the [AM] into \the [src]...", "You start dragging \the [AM] into \the [src]...")
				if (do_after(user, 50, src))
					visible_message("[user] drags \the [AM] into \the [src].", "You drag \the [AM] into \the [src].")
					AM.forceMove(src.loc)
					AM.anchored = TRUE
					transporting += AM
					return
	if (M.loc == src.loc)
		buckle_mob(M)
		if (user == M)
			user << "You buckle yourself to \the [src]."
		else
			visible_message("[user] buckles [M] to \the [src].","You buckle [M] to \the [src].")
		return
	else
		if (user == M)
			user << "You start climbing into \the [src]..."
		else
			visible_message("[user] starts dragging [M] into \the [src]...", "You start dragging [M] into \the [src]...")
		if (do_after(user, 50, src))
			if (user == M)
				user << "You climb into \the [src]."
			else
				visible_message("[user] drags [M] into \the [src].", "You drag [M] into \the [src].")
			M.forceMove(src.loc)
		return
/obj/structure/trains/transport/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		var/mob/living/affecting = G.affecting
		user.visible_message("<span class='notice'>[user] attempts to buckle [affecting] into \the [src]!</span>")
		if (do_after(user, 20, src))
			affecting.loc = loc
			spawn(0)
				if (buckle_mob(affecting))
					affecting.visible_message(\
						"<span class='danger'>[affecting.name] is buckled to [src] by [user.name]!</span>",\
						"<span class='danger'>You are buckled to [src] by [user.name]!</span>",\
						"<span class='notice'>You hear metal clanking.</span>")
			qdel(W)
	else
		if (istype(W, /obj/item/weapon))
			switch(W.damtype)
				if ("fire")
					health -= W.force * TRUE
				if ("brute")
					health -= W.force * 0.75
		else
			..()


/obj/structure/trains/transport/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		for(var/turf/floor/F in range(1,src))
			for(var/obj/O in F)
				if (!O.density && !F.density)
					M.forceMove(F)
					return M
	return M

/obj/structure/trains/transport/verb/unsecure()
	set category = null
	set name = "Unsecure"
	set desc = "Unsecure whatever is on top of the wagon."

	set src in view(1)

	if (!istype(usr, /mob/living))
		return
	for (var/obj/AM in transporting)
		visible_message("[usr] unsecures \the [AM] from \the [src].")
		AM.anchored = FALSE
		transporting -= AM
	return
/obj/structure/trains/transport/flatbed
	name = "flatbed wagon"
	desc = "A wooden floor flatbed wagon, used to transport a variety of things."
	icon_state = "flatbed_wagon"

/obj/structure/trains/transport/cabin
	name = "train cabin"
	desc = "A windowed train cabin, made for the conductor."
	icon_state = "cabinfloor"
	var/image/ovl
	New()
		..()
		ovl = image(icon, "cabinroof", layer = 4.5)
		overlays += ovl

/////////////////////////////////////////////////////////////////////////////////////////////
/obj/structure/trains/locomotive
	name = "locomotive"
	icon_state = "tractor"
	train_speed = 4 //deciseconds of delay, so lower is better
	locomotive = TRUE
	on = FALSE
	var/fuel = FALSE
	var/max_fuel = FALSE
	max_fuel = 100
	max_train_speed = 4

/obj/structure/trains/locomotive/attack_hand(mob/living/user as mob)
	if (!istype(user, /mob/living))
		return
	if (on)
		on = FALSE
		visible_message("[user] turns off \the [src].", "You turn off \the [src].")
		automovement = FALSE
		update_icon()
		return
	else
		on = TRUE
		visible_message("[user] turns on \the [src].", "You turn on \the [src].")
		locomotive()
		update_icon()
		return
	..()

/obj/structure/trains/locomotive/proc/locomotive()
	if (!on)
		return
	if (!automovement)
		automovement = TRUE
		playsound(src.loc, 'sound/machines/train/moving.ogg', 100, TRUE)
		rail_movement()
		return

/obj/structure/trains/locomotive/proc/set_speed()
	var/aprfuel = fuel/max_fuel
	if (aprfuel >= 0.8)
		train_speed = max_train_speed
		return train_speed
	else if (aprfuel < 0.8 && aprfuel >= 0.6)
		train_speed = round(max_train_speed/0.9)
		return train_speed
	else if (aprfuel < 0.6 && aprfuel >= 0.4)
		train_speed = round(max_train_speed/0.8)
		return train_speed
	else if (aprfuel < 0.4 && aprfuel >= 0.2)
		train_speed = round(max_train_speed/0.7)
		return train_speed
	else
		train_speed = round(max_train_speed/0.6)
		return train_speed

/obj/structure/trains/locomotive/coal
	name = "steam locomotive"
	desc = "A steam-powered locomotive. Works with coal, wood, and so on."
	icon_state = "locomotive"
	train_speed = 5
	max_fuel = 100
	max_train_speed = 5

/obj/structure/trains/locomotive/examine(mob/user)
	..()
	var/aprfuel = fuel/max_fuel
	if (aprfuel >= 0.8)
		user << "The combustion chamber seems full!"
	else if (aprfuel < 0.8 && aprfuel >= 0.6)
		user << "The combustion chamber seems to be suficiently fueled."
	else if (aprfuel < 0.6 && aprfuel >= 0.4)
		user << "The combustion chamber seems to be stable."
	else if (aprfuel < 0.4 && aprfuel >= 0.2)
		user << "The combustion chamber seems to be emptying."
	else
		user << "The combustion chamber seems to be almost empty!"
	return TRUE

/obj/structure/trains/locomotive/coal/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		if (istype(S, /obj/item/stack/ore/coal))
			if (fuel>=max_fuel)
				user << "<span class = 'notice'>The combustion chamber is full!</span>"
				return
			else if ((S.amount*15)+fuel>max_fuel)
				user << "<span class = 'notice'>The combustion chamber can't fit that much fuel! Try with a smaller amount.</span>"
				return
			fuel+= S.amount*15
			qdel(W)
			user << "You refuel \the [src]."
			return
		else if (istype(S, /obj/item/stack/material/wood))
			if (fuel>=max_fuel)
				user << "<span class = 'notice'>The combustion chamber is full!</span>"
				return
			else if ((S.amount*3)+fuel>max_fuel)
				user << "<span class = 'notice'>The combustion chamber can't fit that much fuel! Try with a smaller amount.</span>"
				return
			fuel+= S.amount*3
			qdel(W)
			user << "You refuel \the [src]."
			return
		else if (istype(S, /obj/item/weapon/branch))
			if (fuel>=max_fuel)
				user << "<span class = 'notice'>The combustion chamber is full!</span>"
				return
			else if ((S.amount*3)+fuel>max_fuel)
				user << "<span class = 'notice'>The combustion chamber can't fit that much fuel! Try with a smaller amount.</span>"
				return
			fuel+= S.amount*3
			qdel(W)
			user << "You refuel \the [src]."
			return
	else
		..()

/obj/structure/rails/wide
	name = "rails"
	desc = "Rails used by trains."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "middle" //Thanks жендос#0897 for the icons!
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	layer = 2.5

/obj/structure/rails/corner
	name = "rails"
	desc = "Rails used by trains."
	icon = 'icons/obj/vehicles/trains.dmi'
	icon_state = "corner" //Thanks жендос#0897 for the icons!
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	layer = 2.5
