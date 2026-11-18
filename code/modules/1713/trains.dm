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

// Sets the switches this lever works. TRUE when it moved.
/obj/structure/train_lever/proc/throw_switch(state)
	if (switched == state)
		return FALSE
	switched = state
	for (var/obj/structure/rails/split/switcher/S in range(2,src))
		S.switched = state
		S.update_icon()
	update_icon()
	playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
	return TRUE

/obj/structure/train_lever/attack_hand(mob/living/user as mob)
	if (istype(user, /mob/living))
		// Worked by rodding from a signal box (train_signals.dm).
		if (worked_by && train_frame_by_id(worked_by, src))
			to_chat(user, "\The [src] is worked by rodding from a signal box; it does not move by hand.")
			return
		if (switched == "forward")
			throw_switch("split")
			visible_message("<span class = 'notice'>[user] moves the lever into the splitting position!</span>", "<span class = 'notice'>You move the lever into the splitting position!</span>")
		else
			throw_switch("forward")
			visible_message("<span class = 'notice'>[user] moves the lever into the forward position!</span>", "<span class = 'notice'>You move the lever into the forward position!</span>")

/obj/structure/train_lever/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/train_signal_wire))
		var/obj/item/train_signal_wire/wire = W
		wire.use_on(src, user)
		return
	return ..()

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
	var/reversed = FALSE // coupled in back to front: runs tail first (train_heading())
	var/tmp/moving_train = FALSE
	var/train_weight = 1 // empty weight of this car, in loaded-wagon units

/obj/structure/trains/verb/hitch()
	set category = null
	set name = "Hitch"
	set desc = "Hitch or unhitch to the wagon ahead or behind."

	set src in view(1)

	if (!istype(usr, /mob/living/human))
		return
	if (train_under_power())
		to_chat(usr, SPAN_WARNING("The couplings are pulled tight. Shut the throttle first."))
		return FALSE
	if (hitch_front(usr) || hitch_rear(usr))
		return TRUE
	to_chat(usr, "There is no wagon to hitch \the [src] to.")
	return FALSE

// Couples or uncouples this car and the one ahead of it in its train.
/obj/structure/trains/proc/hitch_front(mob/user)
	return couple_end(TRUE, user)

// The same from the rear end, for the car behind.
/obj/structure/trains/proc/hitch_rear(mob/user)
	return couple_end(FALSE, user)

// The way this car travels when its train runs forward. A car stands facing
// its own front (dir); one coupled in back to front is reversed and runs
// tail first.
/obj/structure/trains/proc/train_heading()
	return reversed ? OPPOSITE_DIR(dir) : dir

/obj/structure/trains/proc/train_is_driving()
	for (var/obj/structure/trains/locomotive/L in train_consist_list(train_head()))
		if (L.driving)
			return TRUE
	return FALSE

// Turns the train's order round without moving anything: its last car becomes
// its front, and every car now runs the other way. Cars keep facing as they do.
/obj/structure/trains/proc/reverse_train()
	var/list/cars = train_consist_list(train_head())
	for (var/i in 1 to cars.len)
		var/obj/structure/trains/car = cars[i]
		car.connected = (i > 1) ? cars[i - 1] : null
		car.reversed = !car.reversed

// Keeps the train's order the way most of its engines face, or most of its
// cars when the engines do not settle it: a train whose cars mostly run tail
// first is the same train counted from its other end.
/obj/structure/trains/proc/settle_train_order()
	var/list/cars = train_consist_list(train_head())
	var/turned = 0
	var/engines = 0
	var/engines_turned = 0
	for (var/obj/structure/trains/car in cars)
		if (car.reversed)
			turned++
		if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			if (L.driving)
				L.refresh_consist()
				return
			engines++
			if (L.reversed)
				engines_turned++
	if (engines_turned * 2 != engines ? engines_turned * 2 > engines : turned * 2 > cars.len)
		reverse_train()

// Couples or uncouples at one end of this car: ahead is the end towards the
// front of its train. Any two ends couple, whichever way the cars face; when
// two fronts or two rears meet, one train is counted from its other end. The
// sections of one car or engine stay hitched to each other.
/obj/structure/trains/proc/couple_end(ahead, mob/user)
	var/obj/structure/trains/other = ahead ? lead_car() : connected
	if (other)
		if (car_id && other.car_id == car_id)
			return FALSE
		// Uncoupled as the train coasts, the part without the engine rolls on
		// by itself (train_rolling.dm).
		var/list/motion = train_motion()
		var/way = motion ? travel_way(motion) : null
		var/other_way = motion ? other.travel_way(motion) : null
		if (ahead)
			other.connected = null
		else
			connected = null
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		to_chat(user, "You unhitch \the [src] from \the [other].")
		settle_train_order()
		other.settle_train_order()
		update_couplers()
		other.update_couplers()
		parted_rolls(other, motion, way, other_way)
		return TRUE
	var/way = ahead ? train_heading() : OPPOSITE_DIR(train_heading())
	for (var/obj/structure/trains/TR in get_step(src, way))
		if (TR == src || (TR.dir != dir && TR.dir != OPPOSITE_DIR(dir)))
			continue
		// The end of TR that faces this car, and whether it is free.
		var/their_front = (TR.train_heading() == OPPOSITE_DIR(way))
		if (their_front ? TR.lead_car() : TR.connected)
			continue
		if (TR.train_head() == train_head())
			continue
		// Both couplings must be there and whole (train_couplings.dm).
		if (coupling_at(coupling_end_ahead(ahead)) <= 0)
			to_chat(user, SPAN_WARNING("\The [src] has no working coupling at that end."))
			return FALSE
		if (TR.coupling_at(TR.coupling_end_ahead(their_front)) <= 0)
			to_chat(user, SPAN_WARNING("\The [TR] has no working coupling at that end."))
			return FALSE
		if (!join_trains(ahead, TR, their_front))
			to_chat(user, SPAN_WARNING("Stop the trains before you couple them."))
			return TRUE
		playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
		to_chat(user, "You hitch \the [src] to \the [TR].")
		return TRUE
	return FALSE

// Makes the link between this car's end (ahead: the one towards the front of
// its train) and the free end of TR that meets it (their_front likewise).
// When two fronts or two rears meet, the train that is not being driven is
// counted from its other end. FALSE when both are being driven.
/obj/structure/trains/proc/join_trains(ahead, obj/structure/trains/TR, their_front)
	var/mine_front = ahead
	if (their_front == mine_front)
		var/obj/structure/trains/turned = train_is_driving() ? TR : src
		if (turned.train_is_driving())
			return FALSE
		turned.reverse_train()
		if (turned == src)
			mine_front = !mine_front
	if (mine_front)
		TR.connected = src
	else
		connected = TR
	settle_train_order()
	update_couplers()
	TR.update_couplers()
	return TRUE

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
	// A handbrake anywhere in the train holds it against a push.
	if (train_handbrakes())
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
// fdir: the way the car heads after the step (train_heading()).
/obj/structure/trains/Move(var/turf/newloc, var/fdir = null)
	if (moving_train || !isturf(loc) || !newloc)
		return FALSE
	if (!fdir)
		fdir = train_heading()
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
	dir = reversed ? OPPOSITE_DIR(fdir) : fdir
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
		connected.Move(oldloc, fdir)

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
		// A car that stopped on the curve while its train backed already heads
		// out along one of the curve's legs: it runs straight on.
		if (fdir != mdir && !rail_canmove(fdir) && rail_canmove(mdir))
			fdir = mdir
			tgtt = get_step(RT, mdir)
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
		automovement = FALSE
		// Cars that nothing holds roll away from the blow (train_rolling.dm).
		var/list/strike = (TF.train_head() != train_head()) ? train_motion() : null
		// At speed this is a wreck (train_crashes.dm).
		if (train_crash(TF, impact, fdir))
			TF.shoved(strike, fdir)
			return TRUE
		// A slow approach buffers up, and automatic couplers lock
		// (train_shunting.dm).
		if (buffer_up(TF, strike))
			return TRUE
		visible_message("<span class = 'warning'>\The [src] hits \the [TF]!</span>")
		health -= round(5 * impact)
		if (impact > 1)
			TF.health -= round(5 * (impact - 1))
		TF.shoved(strike, fdir)
		return TRUE
	for (var/obj/O in tgtt)
		// Deck and body tiles are the clearance check's business (train_consist_obstacle):
		// on a curve the leading car's own side tile lies on the track ahead.
		if (O.density && !istype(O, /obj/structure/trains) && !istype(O, /obj/structure/rails) && !istype(O, /obj/structure/train_part))
			// A buffer stop takes a train up to a hard blow and stands
			// (train_trackworks.dm); a harder one wrecks both.
			if (istype(O, /obj/structure/train_buffer_stop))
				var/obj/structure/train_buffer_stop/stop = O
				automovement = FALSE
				if (stop.hold(impact))
					visible_message("<span class = 'warning'>\The [src] [impact < 0.5 ? "comes to rest against" : "runs hard into"] \the [stop], which holds.</span>")
					return TRUE
				if (!train_crash(stop, impact, fdir))
					visible_message("<span class = 'warning'>\The [src] hits \the [stop]!</span>")
				stop.smash()
				return TRUE
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
				if (!train_crash(O, impact, fdir))
					visible_message("<span class = 'warning'>\The [src] crashes into \the [O]!</span>")
				return TRUE
			automovement = FALSE
			if (impact < 0.5)
				visible_message("<span class = 'warning'>\The [src] bumps into \the [O] and stops.</span>")
				return TRUE
			// A wreck does its own damage to the train (train_crashes.dm).
			var/wreck = train_crash(O, impact, fdir)
			if (!wreck)
				visible_message("<span class = 'warning'>\The [src] hits \the [O]!</span>")
			O.ex_act(impact >= 1.5 ? 1.0 : 2.0)
			if (!wreck)
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
	var/list/route = rail_target(train_heading())
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
		if (!train_crash(clearance, isnull(impact) ? collision_impact() : impact, fdir))
			visible_message("<span class = 'warning'>\The [src] grinds to a halt against \the [clearance]!</span>")
		automovement = FALSE
		set_light(0)
		return FALSE
	// ... and move this train
	if (!src.Move(tgtt, fdir))
		automovement = FALSE
		set_light(0)
		return FALSE
	set_light(lamp_range)
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
	if (service_use(W, user))
		return
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
	if (service_use(W, user))
		return
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
#define BOILER_WORKING_PRESSURE 60 // full power from here up
#define BOILER_MIN_PRESSURE 15 // no power below this
#define BOILER_INJECTOR_PRESSURE 20 // the injector needs steam to work
#define BOILER_COOL_TIME 1200 // seconds for a full boiler to go cold
#define BOILER_IDLE_FUEL 0.02 // fuel a standing fire burns each second

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
	var/start_text = "Start the engine"
	var/stop_text = "Stop the engine"
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
	var/atom/spot = control_spot(user)
	if (!istype(user, /mob/living) || !spot || !(user in range(1, spot)))
		if (body_kind && istype(user, /mob/living))
			to_chat(user, "The controls are in the cab.")
		return
	// A steam cab has three stations; each works its own controls.
	var/station = cab_station(user)
	if (!station)
		to_chat(user, "Step into the cab: the driver's stand is on its right, the firebox door in the middle and the fireman's side on the left.")
		return
	// Linked diesel units are driven as one (train_diesel.dm): any of their
	// cabs works the unit that sets the pace.
	var/obj/structure/trains/locomotive/E = linked_driver()
	E.boiler_tick()
	var/list/choices = E.station_controls(station)
	var/choice = player_input(user, "[station_text(station)][E.control_summary()]", "[E.name]", null, "anything", choices, TRUE)
	if (!choice || QDELETED(src) || QDELETED(E) || !(user in range(1, spot)) || cab_station(user) != station)
		return
	E.work_control(choice, user)

// The controls worked from a station: "all" on an engine with one place.
/obj/structure/trains/locomotive/proc/station_controls(station)
	var/list/choices = list()
	if (station == "all" || station == "fire")
		choices += on ? stop_text : start_text
	if (station == "all" || station == "driver")
		choices += list("Throttle up", "Throttle down", "Brake", "Sand the rails")
		choices += (reverser > 0) ? "Reverser to backward" : "Reverser to forward"
		// Warnings and the headlamp (train_stations.dm).
		choices += list("Sound the [whistle_name()]", "Ring the bell", headlamp ? "Put out the headlamp" : "Light the headlamp")
	if (station == "all" || station == "fireman")
		choices += extra_controls()
	return choices

// Works one control for user, who stands at a station that has it.
/obj/structure/trains/locomotive/proc/work_control(choice, mob/user)
	if (!(choice in station_controls(cab_station(user))))
		return
	boiler_tick()
	if (choice == start_text)
		choice = "Start the engine"
	else if (choice == stop_text)
		choice = "Stop the engine"
	switch (choice)
		if ("Start the engine")
			if (engine_disabled())
				to_chat(user, "<span class = 'warning'>The engine is too badly damaged to run. Weld it first.</span>")
				return
			if (fuel <= 0 && max_fuel)
				to_chat(user, "<span class = 'warning'>The [fuel_store] is empty.</span>")
				return
			var/problem = start_problem()
			if (problem)
				to_chat(user, "<span class = 'warning'>[problem]</span>")
				return
			on = TRUE
			started(user)
			switch_linked(TRUE, user)
		if ("Stop the engine")
			on = FALSE
			stopped(user)
			switch_linked(FALSE, user)
		if ("Throttle up")
			if (!on)
				to_chat(user, "[start_text] first.")
				return
			if (steam_factor() <= 0)
				to_chat(user, "<span class = 'warning'>There is not enough steam yet. Wait for the pressure to rise.</span>")
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
			visible_message("[user] applies \the [src]'s brake.", "You apply the engine's brake. It holds the engine alone: a long train needs its handbrakes as well.")
		if ("Sand the rails")
			if (!sand_rails(user))
				return
		if ("Sound the whistle", "Sound the horn")
			sound_whistle(user)
			return
		if ("Ring the bell")
			sound_bell(user)
			return
		if ("Light the headlamp", "Put out the headlamp")
			set_headlamp(!headlamp, user)
			return
		if ("Reverser to backward", "Reverser to forward")
			if (rail_speed > 0)
				to_chat(user, "<span class = 'warning'>Stop the train before you move the reverser.</span>")
				return
			reverser = -reverser
			to_chat(user, "You set the reverser to [reverser > 0 ? "forward" : "backward"].")
		else
			if (!handle_control(choice, user))
				return
	playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)
	update_icon()
	locomotive()

/obj/structure/trains/locomotive/proc/control_summary()
	var/where = reverser > 0 ? "forward" : "backward"
	var/pinned = train_handbrakes()
	return "[state_text()] Throttle notch [throttle] of [LOCO_NOTCHES], reverser [where][braking ? ", engine brake on" : ""][pinned ? ", [pinned] handbrake\s on in the train" : ""]. [speed_text()].[night_text()] [sand_text()]"

/obj/structure/trains/locomotive/proc/state_text()
	return "Engine [on ? "running" : "stopped"]."

/obj/structure/trains/locomotive/proc/started(mob/user)
	visible_message("[user] starts \the [src].", "You start \the [src].")

/obj/structure/trains/locomotive/proc/stopped(mob/user)
	visible_message("[user] stops \the [src]'s engine.", "You stop the engine. The train will roll on until it slows or you brake.")

// Why the engine cannot be started just now, or null.
/obj/structure/trains/locomotive/proc/start_problem()
	return null

// More choices for the controls menu, and what they do. handle_control()
// returns TRUE when a control was worked.
/obj/structure/trains/locomotive/proc/extra_controls()
	return list()

/obj/structure/trains/locomotive/proc/handle_control(choice, mob/user)
	return FALSE

// Steam engines (below): the share of its power the boiler can give, the
// boiler's slow changes by the clock, and what each tile of work takes.
/obj/structure/trains/locomotive/proc/steam_factor()
	return 1

/obj/structure/trains/locomotive/proc/boiler_tick()
	return

/obj/structure/trains/locomotive/proc/steam_use(notch, weight, tiles = 1)
	return

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

// The reverser is the engine's own: forward is the way the engine faces. This
// is the way the train then runs: 1 towards its front car, -1 towards its last.
/obj/structure/trains/locomotive/proc/train_way()
	return reversed ? -reverser : reverser

// What leads the train decides how fast it may go: an engine running
// forward, an engine running bunker first, or cars pushed with nobody at the
// front to see the line. A running helper engine at the front counts.
/obj/structure/trains/locomotive/proc/leading_factor(list/cars)
	if (!cars || !cars.len)
		return 1
	var/way = train_way()
	var/obj/structure/trains/lead = (way > 0) ? cars[1] : cars[cars.len]
	var/obj/structure/trains/locomotive/E = istype(lead, /obj/structure/trains/locomotive) ? lead : lead.unit_engine()
	if (E && (E == src || (E.on && !E.engine_disabled())))
		var/ahead = ((way > 0) != !!E.reversed) // it runs the way it faces
		// With a cab at each end (train_diesel.dm) it is the cab that leads
		// that has to be manned.
		if (E.rear_cab())
			return E.cab_manned(ahead ? 1 : 2) ? 1 : 0.75
		return ahead ? 1 : 0.75
	return 0.5

/obj/structure/trains/locomotive/proc/refresh_consist(steps_since = 0)
	drive_head = train_head()
	var/list/cars = train_consist_list(drive_head)
	drive_tail = cars.len ? cars[cars.len] : src
	// In the dark with no light ahead it runs blind (train_stations.dm).
	lead_factor = leading_factor(cars) * night_factor()
	linked = linked_units(cars)
	consist_weight = 0
	consist_power = 0
	consist_engines = 0
	consist_braked = 0
	consist_own = 0
	consist_hot = 0
	for (var/obj/structure/trains/car in cars)
		var/car_weight = car.car_load_weight()
		consist_weight += car_weight
		// Axle boxes (train_servicing.dm): a seized axle holds like a brake,
		// a hot box drags.
		car.wear_axles(steps_since)
		// Brakes (train_brakes.dm): handbrakes on, and what the driver's brake
		// holds. A brake that is on wears its shoes, and worn shoes hold less.
		// The driver's brake holds the engine and the units linked to it.
		var/own = (car == src || (car_id && car.car_id == car_id) || (linked && car.car_id && linked[car.car_id]))
		if (car.handbrake || (own && braking))
			car.wear_shoes(steps_since)
		if (car.handbrake || car.axle_seized)
			consist_braked += car_weight * car.brake_hold()
		else if (car.axle_oil <= 0)
			consist_hot += car_weight
		if (own)
			consist_own += car_weight * car.brake_hold()
		if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			if (L.on && (L.fuel > 0 || !L.max_fuel) && !L.engine_disabled())
				// A worn engine pulls less until it is overhauled.
				L.wear_engine(steps_since)
				consist_power += L.haul * L.wear_factor() * ((L == src) ? 1 : L.steam_factor())
				consist_engines++
				// Helper engines burn their own fuel on the lead's beat.
				if (L != src && steps_since > 0)
					L.fuel = max(0, L.fuel - L.fuel_per_tile(throttle, consist_weight) * steps_since)
					L.steam_use(throttle, consist_weight, steps_since)
					if (L.fuel <= 0)
						L.stall()
				L.tender_top_up()

// The notch as a share of full throttle.
/obj/structure/trains/locomotive/proc/throttle_share()
	return throttle / LOCO_NOTCHES

/obj/structure/trains/locomotive/proc/engine_disabled()
	return broken_down || derailed

// 0 when the engine pulls its rated load or more; below 1 it is overloaded.
/obj/structure/trains/locomotive/proc/pull_ratio()
	return consist_power / max(1, drag_weight())

/obj/structure/trains/locomotive/proc/cruise_speed()
	if (!on || throttle <= 0 || engine_disabled())
		return 0
	var/top = 10 / max(0.5, max_train_speed)
	return top * lead_factor * snow_factor * min(1, pull_ratio()) * steam_factor() * throttle / LOCO_NOTCHES

/obj/structure/trains/locomotive/collision_impact()
	if (rail_speed <= 0)
		return 1
	return (rail_speed / 4) * clamp(sqrt(max(1, consist_weight) / 4), 1, 2)

/obj/structure/trains/locomotive/proc/drive()
	if (driving)
		return
	driving = TRUE
	automovement = TRUE
	deadman_missed = 0
	refresh_consist()
	// Signals and section boards right ahead (train_signals.dm).
	lineside_seen = null
	lineside_watch()
	playsound(loc, 'sound/machines/train/moving.ogg', 100, TRUE)
	spawn(0)
		var/steps = 0
		var/since = 0
		while (!QDELETED(src) && isturf(loc))
			if (since >= 6)
				refresh_consist(since)
				since = 0
				// Nobody in the cab (train_diesel.dm).
				deadman_watch()
				// Signals and section boards (train_signals.dm).
				lineside_watch()
			boiler_tick()
			var/target = cruise_speed()
			var/heft = max(1, consist_weight / 6)
			if (rail_speed < target)
				// Too much throttle for the grip (train_adhesion.dm): the wheels
				// spin and the train gains nothing.
				if (wheels_slip())
					wheel_slip()
					if (rail_speed <= 0)
						sleep(10)
						continue
				else
					slipping = 0
					if (rail_speed <= 0 && pull_ratio() < 0.25)
						visible_message("<span class = 'warning'>\The [src]'s wheels spin; [consist_braked > 0 ? "the handbrakes are holding the train" : "the train is too heavy to start"].</span>")
						throttle = 0
						break
					rail_speed = min(target, max(rail_speed, 0.5) + 0.35 * min(2, pull_ratio()))
					braking = FALSE
			else if (rail_speed > target)
				// Rolling resistance by the train's heft, and the brakes by the
				// share of its weight they hold (train_brakes.dm).
				var/drag = (target > 0 ? 0.6 : 0.2) / heft + brake_decel()
				rail_speed = max(target, rail_speed - drag)
			if (rail_speed <= 0.25 && target <= 0)
				break
			automovement = TRUE
			var/obj/structure/trains/lead = (train_way() > 0) ? drive_head : drive_tail
			if (!lead || QDELETED(lead))
				lead = src
			var/lead_dir = lead.dir
			var/turf/lead_from = lead.loc
			var/moved = (train_way() > 0) ? process_rail_forward() : process_rail_reverse()
			if (QDELETED(src))
				return
			if (!moved)
				// Off the end of the rails at speed (train_derail.dm).
				overrun_check()
				throttle = 0
				break
			// Too fast round a curve or through a switch (train_derail.dm).
			if (curve_check(lead, lead_dir, lead_from))
				break
			steps++
			since++
			// Snow on the line (train_snow.dm).
			meet_snow()
			if (sanding > 0)
				sanding--
			if (steps % 8 == 0)
				playsound(loc, 'sound/machines/train/moving.ogg', 100, TRUE)
			sleep(clamp(10 / max(0.5, rail_speed), max_train_speed, 20))
		if (QDELETED(src))
			return
		if (rail_speed > 0 || steps)
			playsound(loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
		// The last few tiles count for wear as well.
		if (since > 0 && isturf(loc))
			refresh_consist(since)
		rail_speed = 0
		snow_factor = 1
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
	var/list/route = tail.rail_target(OPPOSITE_DIR(tail.train_heading()))
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
		if (!tail.train_crash(clearance, impact, fdir))
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
			face = car.train_heading()
		if (!car.Move(dest, face))
			. = FALSE
			break
	train_solo_move = FALSE
	if (!.)
		automovement = FALSE
	else
		set_light(lamp_range)

// Fuel used for one tile: idling costs little, a full throttle on a heavy
// train costs most. About a hundred tiles a firebox at full load.
/obj/structure/trains/locomotive/proc/fuel_per_tile(notch, weight)
	return 0.25 + 0.75 * (notch / LOCO_NOTCHES) * min(1.5, weight / max(1, haul))

/obj/structure/trains/locomotive/proc/burn_fuel()
	if (!max_fuel)
		return
	fuel = max(0, fuel - fuel_per_tile(throttle, consist_weight))
	steam_use(throttle, consist_weight)

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

/obj/structure/trains/locomotive/proc/set_speed()
	train_speed = rail_speed > 0 ? round(10 / rail_speed, 0.1) : max_train_speed
	return train_speed

/obj/structure/trains/locomotive/coal
	name = "steam locomotive"
	desc = "A steam-powered locomotive. It burns coal or wood and boils water from its tank. Use it to light the fire, set the throttle, brake, move the reverser or work the injector."
	icon_state = "locomotive"
	train_speed = 2
	max_fuel = 100
	max_train_speed = 2
	haul = 14
	start_text = "Light the fire"
	stop_text = "Drop the fire"
	// The boiler (docs/trains.md). Engines are built filled and in steam.
	var/water = 240 // in the tank
	var/max_water = 240
	var/boiler_water = 60 // in the boiler itself: a tile of hard work boils off one
	var/max_boiler = 60
	var/pressure = 100 // percent of working pressure
	var/steam_time = 120 // seconds from cold to full pressure on a good fire
	var/injector = TRUE // feeds the boiler from the tank as the engine works
	var/plug_dropped = FALSE // the fusible plug melted: no fire until a new one is fitted
	var/tmp/boiler_time = 0
	var/tmp/water_warned = FALSE

/obj/structure/trains/locomotive/examine(mob/user)
	..()
	boiler_tick()
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
	var/worn = overhaul_text()
	if (worn)
		to_chat(user, SPAN_WARNING(worn))
	if (driving && consist_weight)
		var/ratio = pull_ratio()
		if (ratio < 1)
			to_chat(user, "<span class = 'warning'>The train is heavier than its engines can pull at full speed.</span>")
		if (consist_engines > 1)
			to_chat(user, "[consist_engines] engines are working this train.")
		if (lead_factor <= 0.5)
			to_chat(user, "It is pushing cars ahead of it and keeps to half speed.")
		else if (lead_factor < 1)
			to_chat(user, "The engine in front runs backward, so the train keeps to three quarters of its speed.")
	return TRUE

/obj/structure/trains/locomotive/coal/fuel_value(obj/item/I)
	return steam_fuel_value(I)

// How well the fire steams: a firebox under half full makes less.
/obj/structure/trains/locomotive/coal/proc/fire_factor()
	return (max_fuel ? min(1, fuel / (0.5 * max_fuel)) : 1) * clinker_factor() * scale_factor()

/obj/structure/trains/locomotive/coal/steam_factor()
	if (plug_dropped || pressure < BOILER_MIN_PRESSURE)
		return 0
	return min(1, pressure / BOILER_WORKING_PRESSURE)

// The boiler by the clock, caught up whenever someone looks at the engine
// or it drives: a lit fire raises steam and burns a little standing; a dead
// one lets the boiler cool.
/obj/structure/trains/locomotive/coal/boiler_tick()
	var/now = world.time
	if (!boiler_time || boiler_time > now)
		boiler_time = now
		return
	var/dt = min(3600, (now - boiler_time) / 10)
	if (dt < 1)
		return
	boiler_time = now
	if (on && fuel > 0)
		if (boiler_water <= 0)
			drop_plug()
			return
		pressure = min(100, pressure + dt * (100 / steam_time) * fire_factor())
		fuel = max(0, fuel - BOILER_IDLE_FUEL * dt)
		if (fuel <= 0)
			stall()
	else
		pressure = max(0, pressure - dt * 100 / BOILER_COOL_TIME)

// A tile of work: steam used against steam made, water boiled off, and the
// injector putting tank water back at a small cost in steam.
/obj/structure/trains/locomotive/coal/steam_use(notch, weight, tiles = 1)
	if (!on || plug_dropped || tiles <= 0)
		return
	var/work = (notch / LOCO_NOTCHES) * min(1.5, weight / max(1, haul))
	make_clinker(notch, weight, tiles)
	pressure = clamp(pressure + (1.1 * fire_factor() - work) * tiles, 0, 100)
	var/boiled = min(boiler_water, (0.2 + 0.8 * work) * tiles)
	make_scale(boiled)
	boiler_water -= boiled
	if (injector && water > 0 && boiler_water < max_boiler && pressure >= BOILER_INJECTOR_PRESSURE)
		var/fed = min(water, max_boiler - boiler_water, 3 * tiles)
		water -= fed
		boiler_water += fed
		pressure = max(0, pressure - 0.2 * tiles)
	if (boiler_water <= 0)
		drop_plug()
	else if (boiler_water < max_boiler / 4)
		if (!water_warned)
			water_warned = TRUE
			visible_message("<span class = 'danger'>The water is low in \the [src]'s gauge glass!</span>")
	else
		water_warned = FALSE

// The boiler ran dry over a lit fire: the fusible plug melts and the steam
// puts the fire out. Nothing worse happens, but the engine is dead until a
// new plug is fitted.
/obj/structure/trains/locomotive/coal/proc/drop_plug()
	if (plug_dropped)
		return
	plug_dropped = TRUE
	on = FALSE
	throttle = 0
	pressure = 0
	boiler_water = 0
	visible_message("<span class = 'danger'>With a roar of steam \the [src]'s fusible plug lets go and puts the fire out!</span>")
	playsound(loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
	update_icon()

/obj/structure/trains/locomotive/coal/start_problem()
	if (plug_dropped)
		return "The fusible plug has melted. Fit a new one first."
	if (boiler_water <= 0)
		return "There is no water in the boiler. Fill it before you light the fire."
	return null

/obj/structure/trains/locomotive/coal/started(mob/user)
	visible_message("[user] lights the fire in \the [src].", "You light the fire. [pressure < BOILER_WORKING_PRESSURE ? "It will take a while to raise steam." : "The boiler is in steam."]")

/obj/structure/trains/locomotive/coal/stopped(mob/user)
	visible_message("[user] drops \the [src]'s fire.", "You drop the fire. The boiler will slowly cool.")

/obj/structure/trains/locomotive/coal/state_text()
	var/glass = round(100 * boiler_water / max_boiler)
	var/tank = round(100 * water / max_water)
	if (plug_dropped)
		return "The fusible plug has melted. Tank [tank]%."
	return "Fire [on ? "lit" : "out"]. Pressure [round(pressure)]%. Water in the glass [glass]%, tank [tank]%, injector [injector ? "on" : "off"].[clinker_text()][scale_text()]"

/obj/structure/trains/locomotive/coal/extra_controls()
	var/list/choices = list(injector ? "Injector off" : "Injector on")
	if (washout_due())
		choices += "Wash out the boiler"
	return choices

/obj/structure/trains/locomotive/coal/handle_control(choice, mob/user)
	if (choice == "Wash out the boiler")
		return wash_out_by(user)
	if (choice != "Injector on" && choice != "Injector off")
		return FALSE
	injector = (choice == "Injector on")
	to_chat(user, injector ? "You turn the injector on. It feeds the boiler from the tank while the engine works." : "You turn the injector off. Watch the gauge glass.")
	return TRUE

// Water goes in from a bucket or any open vessel: a cold boiler is filled
// first, then the tank.
/obj/structure/trains/locomotive/coal/proc/takes_water(obj/item/W)
	return istype(W, /obj/item/weapon/reagent_containers) && W.reagents && W.is_open_container() && W.reagents.has_reagent("water")

/obj/structure/trains/locomotive/coal/proc/add_water(amount)
	var/used = 0
	if (pressure < BOILER_INJECTOR_PRESSURE && !plug_dropped)
		used = min(amount, max_boiler - boiler_water)
		boiler_water += used
	var/tanked = min(amount - used, max_water - water)
	water += tanked
	return used + tanked

/obj/structure/trains/locomotive/coal/takes_fuel(obj/item/W)
	return ..() || takes_water(W) || istype(W, /obj/item/fusible_plug) || is_tool(W, TOOL_SHOVEL)

/obj/structure/trains/locomotive/coal/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/fusible_plug))
		boiler_tick()
		if (!plug_dropped)
			to_chat(user, "\The [src]'s fusible plug is sound.")
			return
		user.visible_message("[user] starts fitting a new fusible plug to \the [src]...", "You crawl into the cold firebox and start screwing in the new plug...")
		if (!do_after(user, 100, src) || !plug_dropped || user.get_active_hand() != W)
			return
		user.drop_from_inventory(W)
		qdel(W)
		plug_dropped = FALSE
		user.visible_message("[user] fits a new fusible plug to \the [src].", "You fit the new plug. Fill the boiler before you light the fire.")
		return
	// Firing is done at the firebox door (train_locomotives.dm).
	if ((is_tool(W, TOOL_SHOVEL) || fuel_value(W)) && !at_firebox(user))
		to_chat(user, "Stand at the firebox door in the middle of the cab to fire \the [src].")
		return
	if (is_tool(W, TOOL_SHOVEL))
		boiler_tick()
		shovel_coal(user)
		return
	if (takes_water(W))
		boiler_tick()
		var/have = W.reagents.get_reagent_amount("water")
		var/poured = add_water(have)
		if (poured <= 0)
			to_chat(user, "<span class = 'notice'>\The [src]'s tank is full.</span>")
			return
		W.reagents.remove_reagent("water", poured)
		playsound(loc, 'sound/effects/watersplash.ogg', 60, TRUE)
		to_chat(user, "You pour water into \the [src]. [state_text()]")
		return
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

// A spare for the boiler's safety plug.
/obj/item/fusible_plug
	name = "fusible plug"
	desc = "A bronze plug with a lead core, screwed into the crown of a locomotive's firebox. If the boiler runs dry the lead melts and steam puts the fire out."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "fusible_plug"
	w_class = 1

#undef LOCO_NOTCHES
#undef BOILER_WORKING_PRESSURE
#undef BOILER_MIN_PRESSURE
#undef BOILER_INJECTOR_PRESSURE
#undef BOILER_COOL_TIME
#undef BOILER_IDLE_FUEL

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
