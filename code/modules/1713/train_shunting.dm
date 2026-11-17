// Shunting (docs/trains.md#shunting). Making up a train is slow work with
// screw couplings: every one is done up and undone by hand from between the
// cars. Two things make a yard quicker.
//
// - A train that comes up to standing cars slowly buffers up to them: it
//   stops against them and nothing is marked (buffer_up()).
// - An automatic coupler locks by itself when two of them are pushed
//   together, and its lever lets go at once from beside the car, also while
//   the train coasts: the cars that are let go roll on (train_rolling.dm).
//   It is a part like any coupling (train_couplings.dm): `front_auto` and
//   `rear_auto` say which ends carry one.

#define TRAIN_BUFFER_SPEED 1 // tiles per second: up to this a train buffers up without a mark
#define TRAIN_AUTO_COUPLE_SPEED 1.5 // faster than this the cars are knocked away instead

/obj/structure/trains
	var/front_auto = FALSE // the coupling at that end is an automatic coupler
	var/rear_auto = FALSE

/obj/item/train_coupling
	var/automatic = FALSE

/obj/item/train_coupling/automatic
	name = "automatic coupler"
	desc = "A steel knuckle coupler. Two of them lock by themselves when the cars are pushed together, and a lever at the side lets them go."
	icon_state = "knuckle_item"
	automatic = TRUE

/obj/structure/trains/proc/coupling_auto(front)
	return front ? front_auto : rear_auto

/obj/structure/trains/proc/set_coupling_auto(front, state)
	if (front)
		front_auto = !!state
	else
		rear_auto = !!state
	update_couplers()

/obj/structure/trains/proc/coupling_noun(front)
	return coupling_auto(front) ? "automatic coupler" : "coupling"

// The end of this car that faces something standing next to it in line with
// it: TRUE for its front, FALSE for its rear, null when it is not in line.
/obj/structure/trains/proc/end_facing(atom/other)
	var/d = get_dir(src, other)
	if (d == dir)
		return TRUE
	if (d == OPPOSITE_DIR(dir))
		return FALSE
	return null

// Two automatic couplers meet between this car and other, whole and free.
/obj/structure/trains/proc/auto_couplers_meet(obj/structure/trains/other)
	var/mine = end_facing(other)
	var/theirs = other.end_facing(src)
	if (isnull(mine) || isnull(theirs))
		return FALSE
	if (!has_coupling_end(mine) || !other.has_coupling_end(theirs))
		return FALSE
	if (!coupling_auto(mine) || !other.coupling_auto(theirs))
		return FALSE
	if (coupling_at(mine) <= 0 || other.coupling_at(theirs) <= 0)
		return FALSE
	if (end_neighbour(mine) || other.end_neighbour(theirs))
		return FALSE
	return TRUE

// The coupling at that end and its neighbour's are both automatic: the lever
// works them.
/obj/structure/trains/proc/lever_uncouples(front)
	var/obj/structure/trains/other = end_neighbour(front)
	return other && coupling_auto(front) && other.coupling_auto(other.end_towards(src))

// This car, leading a train that moves as strike (its train_motion()), comes
// up against the standing car TF. TRUE when it buffers up: the train stops
// there unmarked, and automatic couplers lock.
/obj/structure/trains/proc/buffer_up(obj/structure/trains/TF, list/strike)
	if (!strike || !istype(TF) || TF.train_head() == train_head() || TF.train_motion())
		return FALSE
	if (strike[1] <= TRAIN_AUTO_COUPLE_SPEED && auto_couplers_meet(TF))
		var/mine = end_facing(TF)
		var/obj/structure/trains/head = train_head()
		if (head.roll_speed > 0)
			head.stop_rolling()
		if (join_trains(coupling_end_ahead(mine), TF, TF.coupling_end_ahead(TF.end_facing(src))))
			visible_message(SPAN_NOTICE("\The [src] buffers up to \the [TF] and the couplers lock."))
			playsound(loc, 'sound/effects/clang.ogg', 60, TRUE)
			return TRUE
	if (strike[1] <= TRAIN_BUFFER_SPEED)
		visible_message("\The [src] buffers up to \the [TF].")
		return TRUE
	return FALSE

#undef TRAIN_BUFFER_SPEED
#undef TRAIN_AUTO_COUPLE_SPEED
