// Track wear (train scale-up, step 15).
//
// Every train an engine drives wears the rails under its leading car, by its
// weight: more on curves and switches, more at speed, and more once the
// track is already rough. Nothing runs on a timer: an idle line does not
// decay, and wear is a number on the rail (`wear`, 0 to 100).
//
// - Getting rough (25): the cab is told, and nothing else happens.
// - Worn (50): the line speed is down to TRACK_WORN_SPEED. Faster than that
//   the rails spread and the leading car leaves them.
// - Bad (80): TRACK_BAD_SPEED, a crawl.
//
// A platelayer keeps it up: a hammer packs and spikes one tile of rough or
// worn track, and bad track wants a new set of sleepers first. A long line
// is work for a gang.

#define TRACK_WEAR_RATE 0.01 // wear a unit of train weight puts on a tile
#define TRACK_ROUGH 25
#define TRACK_WORN 50
#define TRACK_BAD 80
#define TRACK_WORN_SPEED 5 // tiles a second
#define TRACK_BAD_SPEED 2
#define TRACK_PACK 30 // wear one round of packing takes off
#define TRACK_PACK_TIME 30
#define TRACK_RESLEEPER_TIME 50

/obj/structure/rails
	var/wear = 0
	var/tmp/image/wear_image = null

/obj/structure/rails/after_load()
	..()
	show_wear()

// 0 sound, 1 getting rough, 2 worn, 3 bad.
/obj/structure/rails/proc/wear_state()
	if (wear >= TRACK_BAD)
		return 3
	if (wear >= TRACK_WORN)
		return 2
	if (wear >= TRACK_ROUGH)
		return 1
	return 0

// The fastest a train may pass, in tiles a second, or 0 for no limit.
/obj/structure/rails/proc/line_speed()
	switch (wear_state())
		if (3)
			return TRACK_BAD_SPEED
		if (2)
			return TRACK_WORN_SPEED
	return 0

// Worn and bad track shows it.
/obj/structure/rails/proc/show_wear()
	if (wear_image)
		overlays -= wear_image
		wear_image = null
	var/state = wear_state()
	if (state < 2)
		return
	wear_image = image('icons/obj/vehicles/train_platforms.dmi', state >= 3 ? "track_bad" : "track_worn")
	wear_image.dir = (dir in cardinal) ? dir : NORTH
	overlays += wear_image

// A train of this weight passes at this speed.
/obj/structure/rails/proc/take_traffic(weight, speed)
	var/amount = TRACK_WEAR_RATE * max(1, weight)
	if (turn_dir || istype(src, /obj/structure/rails/split))
		amount *= 2
	if (speed > TRACK_WORN_SPEED)
		amount *= 1.5
	var/before = wear_state()
	if (before >= 1)
		amount *= 1.5
	wear = min(100, wear + amount)
	if (wear_state() != before)
		show_wear()

/obj/structure/rails/proc/wear_text()
	switch (wear_state())
		if (3)
			return "The track here is in a bad way: the sleepers are split and the rails are out of line. Anything faster than a crawl will leave it. It wants new sleepers."
		if (2)
			return "The track here is worn: the rails have worked loose on their sleepers. Fast trains will leave it. A hammer packs and spikes it."
		if (1)
			return "The track here is getting rough. A hammer packs and spikes it."
	return "The track here is in good order."

/obj/structure/rails/examine(mob/user)
	..()
	to_chat(user, wear_text())

// Platelaying, asked first by attackby() (track_laying.dm). TRUE when W was
// used on the track.
/obj/structure/rails/proc/track_maintain(obj/item/W, mob/user)
	var/hammer = is_tool(W, TOOL_HAMMER)
	var/obj/item/stack/rail_sleepers/sleepers = W
	if (!hammer && !istype(sleepers))
		return FALSE
	var/state = wear_state()
	if (hammer)
		if (!state)
			return FALSE
		if (state >= 3)
			to_chat(user, SPAN_WARNING("The sleepers here are done for: no packing will hold these rails. Put in a new set of railway sleepers."))
			return TRUE
	else if (state < 2)
		to_chat(user, SPAN_NOTICE("The sleepers under \the [src] are sound[state ? ": a hammer will pack them" : ""]."))
		return TRUE
	if (locate(/obj/structure/trains) in get_turf(src))
		to_chat(user, SPAN_WARNING("Move the train off this track first."))
		return TRUE
	user.visible_message("[user] starts [hammer ? "packing and spiking" : "putting new sleepers under"] the track.", "You start [hammer ? "packing the sleepers and driving the spikes home" : "drawing the old sleepers and putting in new ones"].")
	if (!do_after(user, hammer ? TRACK_PACK_TIME : TRACK_RESLEEPER_TIME, src) || QDELETED(src))
		return TRUE
	if (locate(/obj/structure/trains) in get_turf(src))
		return TRUE
	if (hammer)
		if (wear_state() >= 3)
			return TRUE
		wear = max(0, wear - TRACK_PACK)
	else
		if (QDELETED(sleepers) || wear_state() < 2 || !sleepers.use(1))
			return TRUE
		wear = 0
	show_wear()
	playsound(loc, 'sound/effects/woodhit.ogg', 50, TRUE)
	to_chat(user, SPAN_NOTICE(wear_text()))
	return TRUE

/obj/structure/trains/locomotive
	var/tmp/track_told = 0 // the worst track the cab has been told of on this stretch

// The leading car has entered a tile (the drive loop, trains.dm): the track
// takes the wear, and worn track taken too fast puts the train off. TRUE
// when it left the rails.
/obj/structure/trains/locomotive/proc/meet_track()
	var/list/end = leading_end()
	var/obj/structure/trains/lead = end[1]
	var/obj/structure/rails/R = isturf(lead.loc) ? rail_routing_at(lead.loc) : null
	if (!R)
		return FALSE
	R.take_traffic(consist_weight, rail_speed)
	var/state = R.wear_state()
	if (!state)
		track_told = 0
		return FALSE
	var/limit = R.line_speed()
	if (limit && rail_speed > limit)
		return leave_rails(1, 0.5 * rail_speed / limit, "The worn rails spread under \the [lead] and it leaves them!") > 0
	if (state > track_told)
		track_told = state
		switch (state)
			if (1)
				visible_message("\The [src] rides rough: the track here wants packing.")
			if (2)
				visible_message(SPAN_WARNING("\The [src] rocks and bangs over worn track. Any faster than a steady run and it will leave the rails."))
			if (3)
				visible_message(SPAN_DANGER("\The [src] lurches over track in a bad way. Any faster than a crawl and it will leave the rails."))
	return FALSE

#undef TRACK_WEAR_RATE
#undef TRACK_ROUGH
#undef TRACK_WORN
#undef TRACK_BAD
#undef TRACK_WORN_SPEED
#undef TRACK_BAD_SPEED
#undef TRACK_PACK
#undef TRACK_PACK_TIME
#undef TRACK_RESLEEPER_TIME
