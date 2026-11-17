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
	crushable = FALSE
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

/obj/structure/rails/turn
	icon_state = "rails_turn_left"
	sw_direction = "left"

/obj/structure/rails/turn/New()
	..()
	update_turn_dir()

// A crafted turn is created facing south and then rotated to the builder's
// facing, so the exit direction must follow every later dir change.
/obj/structure/rails/turn/set_dir(new_dir)
	. = ..()
	update_turn_dir()

/obj/structure/rails/turn/proc/update_turn_dir()
	if (!(dir in cardinal))
		turn_dir = null
		return
	turn_dir = turn(dir, sw_direction == "right" ? -90 : 90)

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
	to_chat(usr, "You rotate the platform to the left.")
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
	to_chat(usr, "You rotate the platform to the right.")
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
	to_chat(user, "You rotate the platform to the [dir2text(dir)].")
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
			update_icon()
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
	health = 1000
	var/train_speed = 6 //deciseconds of delay, so lower is better
	var/max_train_speed = 6
	var/locomotive = FALSE
	var/list/transporting = list()
	var/on = FALSE
	var/obj/structure/trains/connected = null
	var/tmp/moving_train = FALSE
	var/train_weight = 1 // empty weight of this car, in loaded-wagon units

/obj/structure/trains/verb/hitch()
	set category = null
	set name = "Hitch"
	set desc = "Hitch or unhitch to the wagon ahead or behind."

	set src in view(1)

	if (!istype(usr, /mob/living/human))
		return
	if (hitch_front(usr) || hitch_rear(usr))
		return TRUE
	to_chat(usr, "There is no wagon to hitch \the [src] to.")
	return FALSE

// Couples or uncouples this car and the one ahead of it.
/obj/structure/trains/proc/hitch_front(mob/user)
	for (var/obj/structure/trains/TR in get_step(src, dir))
		if (TR.connected && TR.connected == src)
			playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
			to_chat(user, "You unhitch \the [src] from \the [TR].")
			TR.connected = null
			return TRUE
		else if (!TR.connected)
			if ((dir == TR.dir || dir == OPPOSITE_DIR(TR.dir)) && can_connect_to(TR))
				playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
				to_chat(user, "You hitch \the [src] to \the [TR].")
				TR.connected = src
				return TRUE
	return FALSE

// The same from the rear end, for the car behind. The sections of one car or
// engine stay hitched to each other.
/obj/structure/trains/proc/hitch_rear(mob/user)
	if (connected)
		if (car_id && connected.car_id == car_id)
			return FALSE
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		to_chat(user, "You unhitch \the [connected] from \the [src].")
		connected = null
		return TRUE
	for (var/obj/structure/trains/TR in get_step(src, OPPOSITE_DIR(dir)))
		if (TR == src || TR.lead_car())
			continue
		if (dir == TR.dir && TR.can_connect_to(src))
			playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
			to_chat(user, "You hitch \the [TR] to \the [src].")
			connected = TR
			return TRUE
	return FALSE

// Connections point to the following wagon. Reject both a new cycle and an
// already malformed chain before attaching it to another car.
/obj/structure/trains/proc/can_connect_to(obj/structure/trains/leader)
	var/list/seen = list(leader)
	var/obj/structure/trains/car = src
	while (car)
		if (car in seen)
			return FALSE
		seen += car
		car = car.connected
	return TRUE

/obj/structure/trains/proc/check_connections()
	if (!connected)
		return FALSE
	// Same test as "connected in range(2, src)" without listing the tiles.
	if (isturf(loc) ? (isturf(connected.loc) && connected.z == z && get_dist(src, connected) <= 2) : (connected in range(2,src)))
		return TRUE
	else
		connected = null
		return FALSE
/obj/structure/trains/Bumped(atom/AM)
	// Train contact is handled by process_rail_movement, not a push cascade.
	if (istype(AM, /obj/structure/trains) || moving_train || !AM || !AM.loc)
		return FALSE
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
		return src.Move(tgt)
/obj/structure/trains/Move(var/turf/newloc, var/fdir = dir)
	if (moving_train || !isturf(loc) || !newloc)
		return FALSE
	check_connections()
	if (buckled_mob && map.check_caribbean_block(buckled_mob, newloc))
		return FALSE

	var/turf/oldloc = loc

	moving_train = TRUE
	var/moved = ..(newloc)
	if (!src)
		return FALSE
	if (!moved || loc == oldloc || !isturf(loc))
		moving_train = FALSE
		return FALSE
	dir = fdir
	if (buckled_mob)
		if (buckled_mob.buckled == src)
			buckled_mob.persistence_set_loc(loc)
		else
			buckled_mob = null
	for (var/mob/living/L in oldloc)
		L.persistence_set_loc(loc)
	for (var/obj/O in oldloc)
		if (O.anchored && (O in transporting))
			O.persistence_set_loc(loc)
	if (connected && !train_solo_move)
		connected.Move(oldloc, dir)

	for (var/obj/O in transporting)
		if (get_dist(O, src) >= 2)
			transporting -= O
	for (var/obj/item/I in transporting)
		I.update_light()
	moving_train = FALSE
	return TRUE

// Set while a reversing train moves its cars one by one from the rear, so a
// car's Move() does not drag its follower as well.
var/global/train_solo_move = FALSE

// Where a car standing here goes next when it rolls towards mdir:
// list(target turf, facing after the step), or null at the end of the track.
/obj/structure/trains/proc/rail_target(mdir)
	var/turf/tgtt = get_step(src, mdir)
	if (!get_turf(src) || !tgtt)
		return null
	var/fdir = mdir
	var/obj/structure/rails/RT = null
	for (var/obj/structure/rails/RTT in loc)
		RT = RTT
	if (RT && istype(RT, /obj/structure/rails/split/switcher) && RT.switched == "split" && RT.dir == mdir && rail_canmove(mdir))
		if (RT.sw_direction == "left")
			tgtt = get_step(RT, turn(RT.dir, 90))
		else if (RT.sw_direction == "right")
			tgtt = get_step(RT, turn(RT.dir, -90))
	else if (RT && istype(RT, /obj/structure/rails/turn) && RT.turn_dir)
		if (RT.turn_dir == mdir)
			fdir = RT.dir
		else if (RT.turn_dir == OPPOSITE_DIR(mdir))
			fdir = OPPOSITE_DIR(RT.dir)
		else if (RT.dir == mdir)
			fdir = RT.turn_dir
		else if (RT.dir == OPPOSITE_DIR(mdir))
			fdir = OPPOSITE_DIR(RT.turn_dir)
		tgtt = get_step(RT, fdir)
	if (!rail_canmove(fdir))
		return null
	return list(tgtt, fdir)

// How hard this car hits what is in front of it: 1 is the old fixed blow.
// A locomotive scales it with its speed and the weight behind it.
/obj/structure/trains/proc/collision_impact()
	return 1

// Ram force of a train at impact 1, in wood-part hit points, and how much
// absorbed force costs the car one point of health.
#define TRAIN_RAM_FORCE 600
#define TRAIN_RAM_HULL_PER_FORCE 20

// Hits whatever stands on tgtt. TRUE when the train must stop there.
/obj/structure/trains/proc/rail_hit(turf/tgtt, fdir, impact = null)
	if (isnull(impact))
		impact = collision_impact()
	for (var/obj/structure/trains/TF in tgtt)
		visible_message("<span class = 'warning'>\The [src] hits \the [TF]!</span>")
		automovement = FALSE
		health -= round(5 * impact)
		if (impact > 1)
			TF.health -= round(5 * (impact - 1))
		return TRUE
	for (var/obj/O in tgtt)
		// Deck and body tiles are the clearance check's business (train_consist_obstacle):
		// on a curve the leading car's own side tile lies on the track ahead.
		if (O.density && !istype(O, /obj/structure/trains) && !istype(O, /obj/structure/rails) && !istype(O, /obj/structure/train_part))
			// A wall, door or pillar on the line takes the train's weight
			// (structure_impact.dm); one that gives way does not stop it.
			if (impact >= 0.5 && is_structure_impact_part(O))
				var/force = TRAIN_RAM_FORCE * impact
				var/left = O.structure_impact(force, IMPACT_CRUSH, src, fdir)
				health -= round((force - left) / TRAIN_RAM_HULL_PER_FORCE)
				if (left > 0 && QDELETED(O))
					visible_message("<span class = 'danger'>\The [src] smashes through \the [O]!</span>")
					continue
				automovement = FALSE
				visible_message("<span class = 'warning'>\The [src] crashes into \the [O]!</span>")
				return TRUE
			automovement = FALSE
			if (impact < 0.5)
				visible_message("<span class = 'warning'>\The [src] bumps into \the [O] and stops.</span>")
				return TRUE
			visible_message("<span class = 'warning'>\The [src] hits \the [O]!</span>")
			O.ex_act(impact >= 1.5 ? 1.0 : 2.0)
			health -= round(15 * O.w_class * impact)
			return TRUE
	for (var/mob/living/L in tgtt)
		// A crawl shoves a person off the line; speed hurts in proportion.
		if (impact < 0.5)
			visible_message("<span class = 'warning'>\The [src] shoves \the [L] off the track!</span>")
			L.adjustBruteLoss(5)
		else
			visible_message("<span class = 'warning'>\The [src] hits \the [L]!</span>")
			L.adjustBruteLoss(min(250, round(100 * impact)))
			health -= 8
		var/moved = FALSE
		for (var/side in list(turn(fdir, 90), turn(fdir, -90)))
			var/turf/T = get_step(tgtt, side)
			if (T && !T.density && L.persistence_set_loc(T))
				moved = TRUE
				break
		train_knock_down(L, impact)
		// One body does not stop a heavy train at speed, but a train that
		// cannot clear the person off the rails stops on them.
		if (!moved || impact < 1)
			automovement = FALSE
			return TRUE
	return FALSE

// impact, driven: set by an engine further back that pushes this car at the
// head of its train; the engine burns its own fuel and lends its weight.
/obj/structure/trains/proc/process_rail_movement(impact = null, driven = FALSE)
	if (!automovement)
		return FALSE
	var/list/route = rail_target(dir)
	if (!route)
		automovement = FALSE
		set_light(0)
		return FALSE
	var/turf/tgtt = route[1]
	var/fdir = route[2]
	if (!driven && istype(src, /obj/structure/trains/locomotive))
		var/obj/structure/trains/locomotive/L = src
		if (L.fuel <= 0 && L.on)
			L.stall()
		else if (L.on)
			L.burn_fuel()
	//push (or hit) wtv is in front...
	if (rail_hit(tgtt, fdir, impact))
		return FALSE
	// Platform cars need room for their decks (train_platforms.dm).
	var/atom/clearance = train_consist_obstacle(src, tgtt, fdir)
	if (clearance)
		visible_message("<span class = 'warning'>\The [src] grinds to a halt against \the [clearance]!</span>")
		automovement = FALSE
		set_light(0)
		return FALSE
	// ... and move this train
	if (!src.Move(tgtt, fdir))
		automovement = FALSE
		set_light(0)
		return FALSE
	set_light(2)
	return TRUE

// What this car weighs with its load, for the locomotive's pull.
/obj/structure/trains/proc/car_load_weight()
	var/w = train_weight + transporting.len * 0.4
	for (var/mob/living/L in loc)
		w += 0.1
	return w

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
	if (istype(user, /mob/living/human) && (user in range(1,src)))
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

/obj/structure/trains/storage/car_load_weight()
	return ..() + storage.contents.len * 0.05

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
		storage.can_hold = list(/obj/item/stack/ore/coal, /obj/item/stack/material/wood, /obj/item/weapon/branch)

/obj/structure/trains/storage/tender/examine(mob/user)
	..()
	to_chat(user, "Hitched behind a steam locomotive, its fireman tops up the firebox from here while the train runs.")

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
			to_chat(user, "You buckle yourself to \the [src].")
		else
			visible_message("[user] buckles [M] to \the [src].","You buckle [M] to \the [src].")
		return
	else
		if (user == M)
			to_chat(user, "You start climbing into \the [src]...")
		else
			visible_message("[user] starts dragging [M] into \the [src]...", "You start dragging [M] into \the [src]...")
		if (do_after(user, 50, src))
			if (user == M)
				to_chat(user, "You climb into \the [src].")
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
			if (!affecting.persistence_set_loc(loc))
				return FALSE
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
			if (F == loc || F.density)
				continue
			var/blocked = FALSE
			for(var/atom/movable/O in F)
				if (O.density)
					blocked = TRUE
					break
			if (!blocked)
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
// Locomotives (docs/trains.md). The lead engine of a train runs drive(): the
// throttle notch sets a cruising speed, the train gathers speed and slows by
// the weight it hauls, and the reverser pushes the train backwards. Other
// running engines hitched into the same train add their pull (double heading).
// Speeds are tiles per second; max_train_speed is the step delay in
// deciseconds at full throttle with a light train.

#define LOCO_NOTCHES 3

/obj/structure/trains/locomotive
	name = "locomotive"
	icon_state = "tractor"
	train_speed = 1.2 //deciseconds of delay, so lower is better
	max_train_speed = 1.2 // docs/vehicle-speeds.md
	locomotive = TRUE
	on = FALSE
	train_weight = 3
	var/fuel = 0
	var/max_fuel = 100
	var/haul = 16 // train weight, itself included, pulled at full speed
	var/fuel_store = "firebox"
	var/tmp/throttle = 0 // notch, 0 to LOCO_NOTCHES
	var/tmp/reverser = 1 // 1 forward, -1 backward
	var/tmp/braking = FALSE
	var/tmp/rail_speed = 0 // tiles per second
	var/tmp/driving = FALSE
	var/tmp/consist_weight = 0
	var/tmp/consist_power = 0
	var/tmp/consist_engines = 0
	var/tmp/obj/structure/trains/drive_head = null // front car of the train while this engine drives it
	var/tmp/lead_factor = 1 // share of top speed allowed by what leads the train

/obj/structure/trains/locomotive/Destroy()
	clear_body()
	on = FALSE
	rail_speed = 0
	return ..()

/obj/structure/trains/locomotive/attack_hand(mob/living/user as mob)
	// A heavy locomotive is driven from its cab (train_locomotives.dm).
	var/atom/spot = control_spot()
	if (!istype(user, /mob/living) || !spot || !(user in range(1, spot)))
		if (body_kind && istype(user, /mob/living))
			to_chat(user, "The controls are in the cab.")
		return
	var/list/choices = list(on ? "Stop the engine" : "Start the engine")
	choices += list("Throttle up", "Throttle down", "Brake")
	choices += (reverser > 0) ? "Reverser to backward" : "Reverser to forward"
	var/choice = player_input(user, "[control_summary()]", "[name]", null, "anything", choices, TRUE)
	if (!choice || QDELETED(src) || !(user in range(1, spot)))
		return
	switch (choice)
		if ("Start the engine")
			if (engine_disabled())
				to_chat(user, "<span class = 'warning'>The engine is too badly damaged to run. Weld it first.</span>")
				return
			if (fuel <= 0 && max_fuel)
				to_chat(user, "<span class = 'warning'>The [fuel_store] is empty.</span>")
				return
			on = TRUE
			visible_message("[user] starts \the [src].", "You start \the [src].")
		if ("Stop the engine")
			on = FALSE
			visible_message("[user] stops \the [src]'s engine.", "You stop the engine. The train will roll on until it slows or you brake.")
		if ("Throttle up")
			if (!on)
				to_chat(user, "Start the engine first.")
				return
			throttle = min(LOCO_NOTCHES, throttle + 1)
			braking = FALSE
			to_chat(user, "You open the throttle to notch [throttle].")
		if ("Throttle down")
			throttle = max(0, throttle - 1)
			to_chat(user, throttle ? "You ease the throttle to notch [throttle]." : "You close the throttle. The train coasts.")
		if ("Brake")
			throttle = 0
			braking = TRUE
			visible_message("[user] applies \the [src]'s brakes.", "You apply the brakes.")
		if ("Reverser to backward", "Reverser to forward")
			if (rail_speed > 0)
				to_chat(user, "<span class = 'warning'>Stop the train before you move the reverser.</span>")
				return
			reverser = -reverser
			to_chat(user, "You set the reverser to [reverser > 0 ? "forward" : "backward"].")
	playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)
	update_icon()
	locomotive()

/obj/structure/trains/locomotive/proc/control_summary()
	var/where = reverser > 0 ? "forward" : "backward"
	var/state = on ? "running" : "stopped"
	return "Engine [state]. Throttle notch [throttle] of [LOCO_NOTCHES], reverser [where][braking ? ", brakes on" : ""]. [speed_text()]."

/obj/structure/trains/locomotive/proc/speed_text()
	if (rail_speed <= 0)
		return "Standing"
	return "Rolling at about [round(rail_speed * 3.6 * 10)] km/h"

// Starts the drive loop if anything asks the train to move.
/obj/structure/trains/locomotive/proc/locomotive()
	if (driving || (!on || throttle <= 0) && rail_speed <= 0)
		return
	// One engine drives a train, from wherever it is hitched in: the first to
	// open its throttle. Any other running engine helps it.
	for (var/obj/structure/trains/locomotive/L in train_consist_list(train_head()))
		if (L != src && L.driving)
			if (on)
				visible_message("\The [src] works as a helper engine; \the [L] sets the pace.")
			return
	drive()

// The car hitched in front of this one, if any. It is nearly always on the
// next tile; a link may stretch to two tiles.
/obj/structure/trains/proc/lead_car()
	for (var/d in cardinal)
		for (var/obj/structure/trains/TR in get_step(src, d))
			if (TR.connected == src)
				return TR
	for (var/obj/structure/trains/TR in range(2, src))
		if (TR.connected == src)
			return TR
	return null

// The front car of the train this car is hitched into.
/obj/structure/trains/proc/train_head()
	var/obj/structure/trains/car = src
	var/list/seen = list(src)
	while (seen.len < 200)
		var/obj/structure/trains/ahead = car.lead_car()
		if (!ahead || (ahead in seen))
			break
		seen += ahead
		car = ahead
	return car

// The engine this car is a section of, if any (train_locomotives.dm).
/obj/structure/trains/proc/unit_engine()
	return null

// What leads the train decides how fast it may go: an engine running
// forward, an engine running bunker first, or cars pushed with nobody at the
// front to see the line. A running helper engine at the front counts.
/obj/structure/trains/locomotive/proc/leading_factor(list/cars)
	if (!cars || !cars.len)
		return 1
	var/obj/structure/trains/lead = (reverser > 0) ? cars[1] : cars[cars.len]
	var/obj/structure/trains/locomotive/E = istype(lead, /obj/structure/trains/locomotive) ? lead : lead.unit_engine()
	if (E && (E == src || (E.on && !E.engine_disabled())))
		return (reverser > 0) ? 1 : 0.75
	return 0.5

/obj/structure/trains/locomotive/proc/refresh_consist(steps_since = 0)
	drive_head = train_head()
	var/list/cars = train_consist_list(drive_head)
	lead_factor = leading_factor(cars)
	consist_weight = 0
	consist_power = 0
	consist_engines = 0
	var/obj/structure/trains/storage/tender/tender = null
	for (var/obj/structure/trains/car in cars)
		consist_weight += car.car_load_weight()
		if (!tender && istype(car, /obj/structure/trains/storage/tender))
			tender = car
		if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			if (L.on && (L.fuel > 0 || !L.max_fuel) && !L.engine_disabled())
				consist_power += L.haul
				consist_engines++
				// Helper engines burn their own fuel on the lead's beat.
				if (L != src && steps_since > 0)
					L.fuel = max(0, L.fuel - L.fuel_per_tile(throttle, consist_weight) * steps_since)
					if (L.fuel <= 0)
						L.stall()
	if (tender)
		feed_from(tender)

/obj/structure/trains/locomotive/proc/engine_disabled()
	return broken_down

// 0 when the engine pulls its rated load or more; below 1 it is overloaded.
/obj/structure/trains/locomotive/proc/pull_ratio()
	return consist_power / max(1, consist_weight)

/obj/structure/trains/locomotive/proc/cruise_speed()
	if (!on || throttle <= 0 || engine_disabled())
		return 0
	var/top = 10 / max(0.5, max_train_speed)
	return top * lead_factor * min(1, pull_ratio()) * throttle / LOCO_NOTCHES

/obj/structure/trains/locomotive/collision_impact()
	if (rail_speed <= 0)
		return 1
	return (rail_speed / 4) * clamp(sqrt(max(1, consist_weight) / 4), 1, 2)

/obj/structure/trains/locomotive/proc/drive()
	if (driving)
		return
	driving = TRUE
	automovement = TRUE
	refresh_consist()
	playsound(loc, 'sound/machines/train/moving.ogg', 100, TRUE)
	spawn(0)
		var/steps = 0
		var/since = 0
		while (!QDELETED(src) && isturf(loc))
			if (since >= 6)
				refresh_consist(since)
				since = 0
			var/target = cruise_speed()
			var/heft = max(1, consist_weight / 6)
			if (rail_speed < target)
				if (rail_speed <= 0 && pull_ratio() < 0.25)
					visible_message("<span class = 'warning'>\The [src]'s wheels spin; the train is too heavy to start.</span>")
					throttle = 0
					break
				rail_speed = min(target, max(rail_speed, 0.5) + 0.35 * min(2, pull_ratio()))
				braking = FALSE
			else if (rail_speed > target)
				var/drag = braking ? 1.2 : (target > 0 ? 0.6 : 0.2)
				rail_speed = max(target, rail_speed - drag / heft)
			if (rail_speed <= 0.25 && target <= 0)
				break
			automovement = TRUE
			var/moved = (reverser > 0) ? process_rail_forward() : process_rail_reverse()
			if (QDELETED(src))
				return
			if (!moved)
				throttle = 0
				break
			steps++
			since++
			if (steps % 8 == 0)
				playsound(loc, 'sound/machines/train/moving.ogg', 100, TRUE)
			sleep(clamp(10 / max(0.5, rail_speed), max_train_speed, 20))
		if (QDELETED(src))
			return
		if (rail_speed > 0 || steps)
			playsound(loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
		rail_speed = 0
		braking = FALSE
		driving = FALSE
		automovement = FALSE
		set_light(0)

// Forward: the front car of the train leads. When that is not this engine,
// the engine pushes it, burning its own fuel.
/obj/structure/trains/locomotive/proc/process_rail_forward()
	var/obj/structure/trains/head = drive_head
	if (!head || head == src || QDELETED(head) || !isturf(head.loc))
		return process_rail_movement()
	if (!automovement)
		return FALSE
	if (fuel <= 0 && on)
		stall()
	else if (on)
		burn_fuel()
	head.automovement = TRUE
	. = head.process_rail_movement(collision_impact(), TRUE)
	head.automovement = FALSE
	if (!.)
		automovement = FALSE

// Backing up: the rearmost car leads and each car takes the place of the one
// behind it, the same way a forward step works from the front.
/obj/structure/trains/locomotive/proc/process_rail_reverse()
	if (!automovement)
		return FALSE
	var/list/cars = train_consist_list((drive_head && !QDELETED(drive_head)) ? drive_head : src)
	var/obj/structure/trains/tail = cars[cars.len]
	var/list/route = tail.rail_target(OPPOSITE_DIR(tail.dir))
	if (!route)
		automovement = FALSE
		return FALSE
	var/turf/tgtt = route[1]
	var/fdir = route[2]
	if (fuel <= 0 && on)
		stall()
	else if (on)
		burn_fuel()
	// The rear car takes the blow, with the weight of the train behind it.
	var/impact = collision_impact()
	if (tail.rail_hit(tgtt, fdir, impact))
		automovement = FALSE
		return FALSE
	var/list/rear_first = list()
	for (var/i = cars.len, i >= 1, i--)
		rear_first += cars[i]
	var/atom/clearance = train_consist_obstacle(tail, tgtt, fdir, rear_first)
	if (clearance)
		visible_message("<span class = 'warning'>\The [tail] grinds to a halt against \the [clearance]!</span>")
		automovement = FALSE
		return FALSE
	var/list/old = list()
	for (var/obj/structure/trains/car in cars)
		old += car.loc
	train_platform_reset_plan()
	for (var/obj/structure/trains/platform/P in cars)
		if (!(P in train_platform_plan))
			train_platform_plan_from(P)
	train_solo_move = TRUE
	. = TRUE
	for (var/i = cars.len, i >= 1, i--)
		var/obj/structure/trains/car = cars[i]
		var/turf/dest = (i == cars.len) ? tgtt : old[i + 1]
		var/face = get_dir(dest, old[i])
		if (!(face in cardinal))
			face = car.dir
		if (!car.Move(dest, face))
			. = FALSE
			break
	train_solo_move = FALSE
	if (!.)
		automovement = FALSE
	else
		set_light(2)

// Fuel used for one tile: idling costs little, a full throttle on a heavy
// train costs most. About a hundred tiles a firebox at full load.
/obj/structure/trains/locomotive/proc/fuel_per_tile(notch, weight)
	return 0.25 + 0.75 * (notch / LOCO_NOTCHES) * min(1.5, weight / max(1, haul))

/obj/structure/trains/locomotive/proc/burn_fuel()
	if (!max_fuel)
		return
	fuel = max(0, fuel - fuel_per_tile(throttle, consist_weight))

/obj/structure/trains/locomotive/proc/stall()
	if (!on)
		return
	on = FALSE
	throttle = 0
	visible_message("\The [src]'s engine stalls.")
	update_icon()

// Fuel worth of one unit of this item in the firebox; 0 when it does not burn here.
/obj/structure/trains/locomotive/proc/fuel_value(obj/item/I)
	return 0

// The fireman shovels from a tender hitched into the train.
/obj/structure/trains/locomotive/proc/feed_from(obj/structure/trains/storage/tender/T)
	if (!T || !T.storage || !max_fuel || fuel > max_fuel / 2)
		return FALSE
	for (var/obj/item/I in T.storage.contents)
		var/value = fuel_value(I)
		if (!value)
			continue
		var/room = round((max_fuel - fuel) / value)
		if (room < 1)
			return FALSE
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			var/units = min(S.amount, room)
			fuel += units * value
			S.use(units)
		else
			fuel += value
			T.storage.remove_from_storage(I, null)
			qdel(I)
		T.update_icon()
		return TRUE
	return FALSE

/obj/structure/trains/locomotive/proc/set_speed()
	train_speed = rail_speed > 0 ? round(10 / rail_speed, 0.1) : max_train_speed
	return train_speed

/obj/structure/trains/locomotive/coal
	name = "steam locomotive"
	desc = "A steam-powered locomotive. Works with coal, wood, and so on. Use it to start the engine, set the throttle, brake or move the reverser."
	icon_state = "locomotive"
	train_speed = 2
	max_fuel = 100
	max_train_speed = 2
	haul = 14

/obj/structure/trains/locomotive/examine(mob/user)
	..()
	if (max_fuel)
		var/aprfuel = fuel/max_fuel
		if (aprfuel >= 0.8)
			to_chat(user, "The combustion chamber seems full!")
		else if (aprfuel < 0.8 && aprfuel >= 0.6)
			to_chat(user, "The combustion chamber seems to be sufficiently fueled.")
		else if (aprfuel < 0.6 && aprfuel >= 0.4)
			to_chat(user, "The combustion chamber seems to be stable.")
		else if (aprfuel < 0.4 && aprfuel >= 0.2)
			to_chat(user, "The combustion chamber seems to be emptying.")
		else
			to_chat(user, "The combustion chamber seems to be almost empty!")
	to_chat(user, control_summary())
	if (driving && consist_weight)
		var/ratio = pull_ratio()
		if (ratio < 1)
			to_chat(user, "<span class = 'warning'>The train is heavier than its engines can pull at full speed.</span>")
		if (consist_engines > 1)
			to_chat(user, "[consist_engines] engines are working this train.")
		if (lead_factor <= 0.5)
			to_chat(user, "It is pushing cars ahead of it and keeps to half speed.")
		else if (lead_factor < 1)
			to_chat(user, "It is running backward and keeps to three quarters of its speed.")
	return TRUE

/obj/structure/trains/locomotive/coal/fuel_value(obj/item/I)
	if (istype(I, /obj/item/stack/ore/coal))
		return 15
	if (istype(I, /obj/item/stack/material/wood) || istype(I, /obj/item/weapon/branch))
		return 3
	return 0

/obj/structure/trains/locomotive/coal/attackby(obj/item/W as obj, mob/user as mob)
	var/value = fuel_value(W)
	if (!value)
		return ..()
	var/units = 1
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		units = S.amount
	if (fuel >= max_fuel)
		to_chat(user, "<span class = 'notice'>The combustion chamber is full!</span>")
		return
	if ((units * value) + fuel > max_fuel)
		to_chat(user, "<span class = 'notice'>The combustion chamber can't fit that much fuel! Try with a smaller amount.</span>")
		return
	fuel += units * value
	qdel(W)
	to_chat(user, "You refuel \the [src].")

#undef LOCO_NOTCHES

// A train at speed throws a person it hits; a crawl only shoves them aside.
/proc/train_knock_down(mob/living/L, impact)
	if (impact >= 0.5 && !QDELETED(L))
		L.Weaken(round(2 + 3 * min(impact, 3)))

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
