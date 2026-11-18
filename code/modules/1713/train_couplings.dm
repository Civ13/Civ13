// Couplings (docs/trains.md). Every car carries a coupling at each end: a
// part that is worked by hand, takes damage, breaks, and is taken off and
// replaced. Two cars stay hitched only while the couplings that join them
// hold; when one breaks the train parts there.
//
// The link itself is still `connected` (trains.dm). The couplings are per
// car end, so they keep their state however the train's order is counted:
// the front end is the one the car faces (dir), the rear end the other.
//
// Each end shows as a small part that rides on the car through vis_contents:
// it costs nothing when the train steps, and it is what players click.

#define TRAIN_COUPLING_HEALTH 100
#define TRAIN_COUPLING_NONE -1 // taken off: an empty drawbar pocket
#define TRAIN_COUPLING_UNCOUPLE_TIME 20
#define TRAIN_COUPLING_FIT_TIME 40
#define TRAIN_COUPLING_WELD_TIME 50

/obj/structure/trains
	var/front_coupling = TRAIN_COUPLING_HEALTH
	var/rear_coupling = TRAIN_COUPLING_HEALTH
	var/tmp/obj/effect/train_coupler/coupler_f = null
	var/tmp/obj/effect/train_coupler/coupler_r = null

/obj/structure/trains/on_runtime_spawn()
	..()
	update_couplers()

/obj/structure/trains/after_load()
	..()
	update_couplers()

/obj/structure/trains/Destroy()
	clear_couplers()
	unharness()
	return ..()

// Whether this section has a car end there. A car of several sections has
// one at its first and last section only; an engine's body carries the rear.
/obj/structure/trains/proc/has_coupling_end(front)
	return TRUE

/obj/structure/trains/platform/has_coupling_end(front)
	return front ? (seg_index == 1) : (seg_index == car_length())

/obj/structure/trains/locomotive/has_coupling_end(front)
	return front || !body_kind

/obj/structure/trains/proc/coupling_at(front)
	return front ? front_coupling : rear_coupling

/obj/structure/trains/proc/set_coupling(front, value)
	if (front)
		front_coupling = value
	else
		rear_coupling = value
	update_couplers()

// TRUE when that end points towards the front of the train's order.
/obj/structure/trains/proc/coupling_end_ahead(front)
	return front ? !reversed : reversed

// The other car hitched at that end, if any.
/obj/structure/trains/proc/end_neighbour(front)
	var/obj/structure/trains/other = coupling_end_ahead(front) ? lead_car() : connected
	if (other && car_id && other.car_id == car_id)
		return null
	return other

// Which of this car's ends is hitched to that neighbour: TRUE for its front.
/obj/structure/trains/proc/end_towards(obj/structure/trains/other)
	return (connected == other) ? reversed : !reversed

/obj/structure/trains/proc/coupling_state(front)
	var/v = coupling_at(front)
	if (v == TRAIN_COUPLING_NONE)
		return "none"
	if (v <= 0)
		return "broken"
	return end_neighbour(front) ? "linked" : "free"

/obj/structure/trains/proc/clear_couplers()
	for (var/obj/effect/train_coupler/C in list(coupler_f, coupler_r))
		vis_contents -= C
		C.car = null
		qdel(C)
	coupler_f = null
	coupler_r = null

// Rebuilds the visible parts from the saved state. Cheap, and safe to call
// at any time: after a spawn or a load, and whenever a link or a coupling
// changes.
/obj/structure/trains/proc/update_couplers()
	if (!isturf(loc) || QDELETED(src))
		clear_couplers()
		return
	for (var/front in list(TRUE, FALSE))
		var/obj/effect/train_coupler/C = front ? coupler_f : coupler_r
		if (!has_coupling_end(front))
			if (C)
				vis_contents -= C
				C.car = null
				qdel(C)
				if (front)
					coupler_f = null
				else
					coupler_r = null
			continue
		if (!C)
			C = new(null)
			C.car = src
			C.front = front
			vis_contents += C
			if (front)
				coupler_f = C
			else
				coupler_r = C
		var/state = coupling_state(front)
		C.name = coupling_noun(front)
		C.icon_state = "[(coupling_auto(front) && state != "none") ? "knuckle" : "coupler"]_[front ? "f" : "b"]_[state]"
		C.overlays.Cut()
		if (plough_at(front))
			var/image/blade = image('icons/obj/vehicles/train_plough.dmi', front ? "plough_f" : "plough_b")
			blade.pixel_x = -32
			blade.pixel_y = -32
			C.overlays += blade

// Unhitches at that end without a word. Returns the car that was there.
/obj/structure/trains/proc/part_at(front)
	var/obj/structure/trains/other = end_neighbour(front)
	if (!other)
		return null
	// A moving train that parts leaves cars rolling (train_rolling.dm).
	var/list/motion = train_motion()
	var/way = motion ? travel_way(motion) : null
	var/other_way = motion ? other.travel_way(motion) : null
	if (coupling_end_ahead(front))
		other.connected = null
	else
		connected = null
	settle_train_order()
	other.settle_train_order()
	update_couplers()
	other.update_couplers()
	parted_rolls(other, motion, way, other_way)
	return other

// Wears a coupling down. At nothing it breaks, and the train parts there.
/obj/structure/trains/proc/damage_coupling(front, amount)
	var/v = coupling_at(front)
	if (!has_coupling_end(front) || v <= 0 || amount <= 0)
		return FALSE
	v = max(0, v - amount)
	if (v > 0)
		set_coupling(front, v)
		return TRUE
	var/obj/structure/trains/other = end_neighbour(front)
	if (other)
		part_at(front)
		visible_message(SPAN_DANGER("The coupling between \the [src] and \the [other] breaks!"))
	else
		visible_message(SPAN_WARNING("The coupling on \the [src] breaks."))
	playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
	set_coupling(front, 0)
	return TRUE

// Takes the coupling off a free end. Returns it as an item.
/obj/structure/trains/proc/remove_coupling(front, turf/where)
	var/v = coupling_at(front)
	if (!has_coupling_end(front) || v == TRAIN_COUPLING_NONE || end_neighbour(front))
		return null
	var/kind = coupling_auto(front) ? /obj/item/train_coupling/automatic : /obj/item/train_coupling
	var/obj/item/train_coupling/I = new kind(where || get_turf(src))
	I.set_condition(v)
	if (front)
		front_auto = FALSE
	else
		rear_auto = FALSE
	set_coupling(front, TRAIN_COUPLING_NONE)
	return I

/obj/structure/trains/proc/fit_coupling(front, obj/item/train_coupling/I)
	if (!has_coupling_end(front) || coupling_at(front) != TRAIN_COUPLING_NONE || !istype(I))
		return FALSE
	if (front)
		front_auto = I.automatic
	else
		rear_auto = I.automatic
	set_coupling(front, I.condition)
	qdel(I)
	return TRUE

// An engine in this train is pulling: the couplings are drawn tight.
/obj/structure/trains/proc/train_under_power()
	for (var/obj/structure/trains/locomotive/L in train_consist_list(train_head()))
		if (L.driving && L.on && L.throttle > 0)
			return TRUE
	return FALSE

/obj/structure/trains/proc/coupling_text(front)
	var/v = coupling_at(front)
	var/end = front ? "front" : "rear"
	if (v == TRAIN_COUPLING_NONE)
		return "The [end] coupling is missing. Fit a spare one."
	var/noun = coupling_noun(front)
	if (v <= 0)
		return "The [end] [noun] is broken. Weld it, or take it off with a wrench and fit a spare."
	var/obj/structure/trains/other = end_neighbour(front)
	var/wear = (v >= TRAIN_COUPLING_HEALTH) ? "sound" : "damaged ([round(100 * v / TRAIN_COUPLING_HEALTH)]%)"
	return "The [end] [noun] is [wear][other ? " and hitched to \the [other]" : " and hangs free"]."

/obj/structure/trains/examine(mob/user)
	..()
	for (var/front in list(TRUE, FALSE))
		if (has_coupling_end(front) && coupling_at(front) < TRAIN_COUPLING_HEALTH)
			to_chat(user, coupling_text(front))
	var/plough = plough_text()
	if (plough)
		to_chat(user, plough)
	// The destination card (train_goods.dm).
	to_chat(user, card_line())
	// A horse or an ox in the traces (train_early.dm).
	var/draft = draft_line()
	if (draft)
		to_chat(user, draft)

// Explosions strain the couplings of the cars they catch.
/obj/structure/trains/ex_act(severity)
	blast_couplings(severity)
	return ..()

/obj/structure/trains/proc/blast_couplings(severity)
	var/blow = (severity <= 1) ? 100 : ((severity <= 2) ? 60 : 25)
	for (var/front in list(TRUE, FALSE))
		damage_coupling(front, blow)

// A player works the coupling at one end: by hand to couple or uncouple, a
// spare to fit, a wrench to take it off, a welder to mend it, and a weapon
// on harm intent to break it.
/obj/structure/trains/proc/coupler_use(mob/living/user, front)
	if (!istype(user) || user.incapacitated() || !isturf(loc) || get_dist(user, src) > 1 || !has_coupling_end(front))
		return FALSE
	var/obj/item/W = user.get_active_hand()
	// A snowplough is bolted on over the coupling (train_snow.dm).
	if (plough_use(user, front, W))
		return TRUE
	var/v = coupling_at(front)
	var/obj/structure/trains/other = end_neighbour(front)
	if (istype(W, /obj/item/train_coupling))
		var/obj/item/train_coupling/spare = W
		if (v != TRAIN_COUPLING_NONE)
			// The other kind of coupling changes places with the one fitted.
			if (spare.automatic == coupling_auto(front))
				to_chat(user, "\The [src] has \a [coupling_noun(front)] here already. A wrench takes it off.")
				return TRUE
			if (other)
				to_chat(user, SPAN_WARNING("Uncouple \the [src] from \the [other] first."))
				return TRUE
		user.visible_message("[user] starts fitting \a [W] to \the [src]...", "You start fitting \the [W] to \the [src]...")
		if (!do_after(user, TRAIN_COUPLING_FIT_TIME, src) || user.get_active_hand() != W || coupling_at(front) != v || end_neighbour(front))
			return TRUE
		if (v != TRAIN_COUPLING_NONE && !remove_coupling(front, get_turf(user)))
			return TRUE
		user.drop_from_inventory(W)
		fit_coupling(front, W)
		playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
		user.visible_message("[user] fits \a [coupling_noun(front)] to \the [src].", "You fit the [coupling_noun(front)] to \the [src].")
		return TRUE
	if (v == TRAIN_COUPLING_NONE)
		to_chat(user, coupling_text(front))
		return TRUE
	if (is_tool(W, TOOL_WELDER))
		if (v >= TRAIN_COUPLING_HEALTH)
			to_chat(user, "The coupling is sound.")
			return TRUE
		user.visible_message("[user] starts welding a coupling on \the [src]...", "You start welding the coupling...")
		if (!do_after(user, TRAIN_COUPLING_WELD_TIME, src) || coupling_at(front) == TRAIN_COUPLING_NONE)
			return TRUE
		set_coupling(front, TRAIN_COUPLING_HEALTH)
		user.visible_message("[user] mends the coupling on \the [src].", "You mend the coupling.")
		return TRUE
	if (is_tool(W, TOOL_WRENCH))
		if (other)
			to_chat(user, SPAN_WARNING("Uncouple \the [src] from \the [other] first."))
			return TRUE
		user.visible_message("[user] starts taking a coupling off \the [src]...", "You start taking the coupling off \the [src]...")
		if (!do_after(user, TRAIN_COUPLING_FIT_TIME, src))
			return TRUE
		if (remove_coupling(front, get_turf(user)))
			playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
			user.visible_message("[user] takes a coupling off \the [src].", "You take the coupling off \the [src].")
		return TRUE
	if (W && W.force >= 5 && user.a_intent == I_HARM)
		if (v <= 0)
			to_chat(user, "The coupling is broken already.")
			return TRUE
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		user.do_attack_animation(src)
		playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
		user.visible_message(SPAN_DANGER("[user] hits the coupling on \the [src] with \the [W]!"), SPAN_DANGER("You hit the coupling with \the [W]!"))
		damage_coupling(front, W.force)
		return TRUE
	if (v <= 0)
		to_chat(user, coupling_text(front))
		return TRUE
	if (other)
		if (train_under_power())
			to_chat(user, SPAN_WARNING("The coupling is pulled tight. Shut the throttle first."))
			return TRUE
		// Two automatic couplers let go at once by the lever (train_shunting.dm).
		if (lever_uncouples(front))
			user.visible_message("[user] lifts the uncoupling lever of \the [src].", "You lift the uncoupling lever.")
		else
			user.visible_message("[user] starts uncoupling \the [src] from \the [other]...", "You start uncoupling \the [src] from \the [other]...")
			if (!do_after(user, TRAIN_COUPLING_UNCOUPLE_TIME, src) || end_neighbour(front) != other || train_under_power())
				return TRUE
		couple_end(coupling_end_ahead(front), user)
		return TRUE
	if (!couple_end(coupling_end_ahead(front), user))
		to_chat(user, "There is nothing to couple \the [src] to at this end.")
	return TRUE

/////////////////////////////////////////////////////////////////////////////
// The part players see and click

/obj/effect/train_coupler
	name = "coupling"
	desc = "A hook and screw link that joins two railway cars."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "coupler_f_free"
	layer = 3.3
	anchored = TRUE
	should_save = FALSE
	vis_flags = VIS_INHERIT_DIR
	var/obj/structure/trains/car = null
	var/front = TRUE

/obj/effect/train_coupler/Destroy()
	car = null
	return ..()

/obj/effect/train_coupler/Click(location, control, params)
	if (!car || !usr)
		return
	var/list/mods = params2list(params)
	if (mods["shift"])
		examine(usr)
		return
	car.coupler_use(usr, front)

/obj/effect/train_coupler/examine(mob/user)
	if (!car)
		return
	to_chat(user, car.coupling_text(front))
	if (car.plough_at(front))
		to_chat(user, "A snowplough is bolted on here. It clears snow from the line when this end leads the train. A wrench takes it off.")
	if (car.coupling_auto(front) && car.coupling_at(front) > 0)
		to_chat(user, "It locks by itself onto another automatic coupler when the cars are pushed together slowly, and its lever lets go at once.")
	to_chat(user, "Click it to couple or uncouple. Harm intent with a weapon strikes it.")

/obj/effect/train_coupler/ex_act(severity)
	return

/////////////////////////////////////////////////////////////////////////////
// A spare

/obj/item/train_coupling
	name = "train coupling"
	desc = "A draw hook with its screw link, ready to fit to the end of a railway car."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "coupling_item"
	w_class = 4
	force = 12
	throwforce = 10
	var/condition = TRAIN_COUPLING_HEALTH

/obj/item/train_coupling/proc/set_condition(value)
	condition = clamp(value, 0, TRAIN_COUPLING_HEALTH)
	name = condition > 0 ? initial(name) : "broken train coupling"

/obj/item/train_coupling/after_load()
	..()
	set_condition(condition)

/obj/item/train_coupling/examine(mob/user)
	..()
	if (condition <= 0)
		to_chat(user, SPAN_WARNING("It is broken. A welding tool mends it."))
	else if (condition < TRAIN_COUPLING_HEALTH)
		to_chat(user, "It is damaged ([round(100 * condition / TRAIN_COUPLING_HEALTH)]%). A welding tool mends it.")
	to_chat(user, "Use it on the empty coupling pocket at the end of a car.")

/obj/item/train_coupling/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WELDER))
		if (condition >= TRAIN_COUPLING_HEALTH)
			to_chat(user, "\The [src] is sound.")
			return
		user.visible_message("[user] starts welding \the [src]...", "You start welding \the [src]...")
		if (do_after(user, TRAIN_COUPLING_WELD_TIME, src))
			set_condition(TRAIN_COUPLING_HEALTH)
			to_chat(user, "You mend \the [src].")
		return
	return ..()
