// Heavy earthwork before the bulldozer (Val, 2026-11-19).
//
// Slip scraper (Wagons & Ships): a steel scoop on two handles that a horse or
// an ox draws. With the blade down, each step cuts a three-tile swath one
// level, so three steps grade a 3x3 patch, and the earth rides in the scoop
// (nine loads). With the blade up, an empty hand tips the load to build the
// ground up again under and beside it.
//
// Blasting charge (Gunpowder): a black-powder charge that breaks the rock
// around it, the way miners opened cuttings and tunnels before dynamite.

#define SCRAPER_LOADS 9
#define SCRAPER_TIP_TIME 30
#define BLASTING_POWDER 15

// ---- slip scraper ---------------------------------------------------------

/obj/structure/closet/crate/cart/slip_scraper
	name = "slip scraper"
	desc = "A steel scoop on two long handles, drawn by a horse or an ox. Hitch it up and lower the blade to scrape the ground down as the team walks; raise it and tip it to build ground up."
	icon = 'icons/obj/earthworking_tools.dmi'
	icon_state = "slip_scraper"
	icon_opened = "slip_scraper"
	icon_closed = "slip_scraper"
	storagecap = 0
	var/loads = 0
	var/blade_down = FALSE

/obj/structure/closet/crate/cart/slip_scraper/update_icon()
	icon_state = loads ? "slip_scraper_loaded" : "slip_scraper"

/obj/structure/closet/crate/cart/slip_scraper/after_load()
	..()
	update_icon()

/obj/structure/closet/crate/cart/slip_scraper/examine(mob/user)
	. = ..()
	to_chat(user, "The blade is [blade_down ? "down, biting the ground" : "up"]. It holds [loads] of [SCRAPER_LOADS] loads of earth.")

// Nothing goes in a scraper's scoop by hand: an empty hand tips its earth.
/obj/structure/closet/crate/cart/slip_scraper/attack_hand(mob/user)
	if (!ishuman(user) || !Adjacent(user))
		return
	if (!loads)
		to_chat(user, SPAN_NOTICE("\The [src] is empty. Lower the blade and have a horse or an ox draw it to scrape up earth."))
		return
	if (blade_down)
		to_chat(user, SPAN_WARNING("Raise the blade before tipping \the [src]."))
		return
	scraper_tip(user)

/obj/structure/closet/crate/cart/slip_scraper/attackby(obj/item/W, mob/user)
	return FALSE

/obj/structure/closet/crate/cart/slip_scraper/verb/toggle_blade()
	set name = "Raise or Lower Scraper Blade"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || !Adjacent(H))
		return
	blade_down = !blade_down
	H.visible_message(SPAN_NOTICE("[H] [blade_down ? "lowers" : "raises"] the blade of \the [src]."), SPAN_NOTICE("You [blade_down ? "lower" : "raise"] the blade of \the [src]."))

/obj/structure/closet/crate/cart/slip_scraper/AltClick(mob/user)
	if (Adjacent(user))
		usr = user
		toggle_blade()
		return
	return ..()

// The scraper's tile and the tiles either side of it across direction d.
/obj/structure/closet/crate/cart/slip_scraper/proc/swath(d)
	. = list()
	var/turf/T = get_turf(src)
	if (!T)
		return
	if (!(d in cardinal))
		d = dir
	. += T
	for (var/side in list(turn(d, 90), turn(d, -90)))
		var/turf/S = get_step(T, side)
		if (S)
			. += S

// Why T cannot be graded one level in direction by the scraper, or null.
// The scraper itself standing on T does not count as something in the way.
/obj/structure/closet/crate/cart/slip_scraper/proc/grade_problem(turf/T, direction)
	var/was_dense = density
	density = FALSE
	. = terrain_grade_problem(T, direction)
	density = was_dense

/obj/structure/closet/crate/cart/slip_scraper/follow_leader(turf/left = null, swing = FALSE)
	var/turf/before = loc
	. = ..()
	if (. && blade_down && isturf(loc) && loc != before)
		scrape(isturf(before) ? get_dir(before, loc) : dir)

// Cuts the swath one level as the team draws the blade through it. Only a
// draft animal can draw it through the ground.
/obj/structure/closet/crate/cart/slip_scraper/proc/scrape(d)
	var/mob/living/simple_animal/A = hitched_to
	if (!istype(A) || !is_draft_animal(A) || A.stat == DEAD)
		return 0
	var/cut = 0
	for (var/turf/T in swath(d))
		if (loads >= SCRAPER_LOADS)
			break
		if (grade_problem(T, -1))
			continue
		var/grade = T.terrain_grade - 1
		if (!istype(T, /turf/floor/dirt) || istype(T, /turf/floor/dirt/winter))
			T = T.ChangeTurf(/turf/floor/dirt)
		T.terrain_grade = grade
		T.terrain_grade_apply()
		loads++
		cut++
	if (cut)
		playsound(loc, 'sound/effects/shovelling.ogg', 50, TRUE)
		update_icon()
		if (loads >= SCRAPER_LOADS)
			visible_message(SPAN_NOTICE("\The [src]'s scoop is full of earth."))
	return cut

// Tips the load to build up the swath across the scraper's facing, one load
// a tile; earth with nowhere to go is left in piles on its tile.
/obj/structure/closet/crate/cart/slip_scraper/proc/scraper_tip(mob/living/human/H)
	H.visible_message(SPAN_NOTICE("[H] starts tipping \the [src]."), SPAN_NOTICE("You start tipping \the [src]."))
	if (!do_after(H, work_delay(H, SCRAPER_TIP_TIME, WORK_SHIFT), src) || QDELETED(src) || blade_down || !loads)
		return 0
	var/built = tip_load()
	if (!built)
		H.visible_message(SPAN_NOTICE("[H] tips \the [src] out into piles of dirt."), SPAN_NOTICE("The ground here can't be built up, so you tip the earth out in piles."))
	else
		H.visible_message(SPAN_NOTICE("[H] tips \the [src], building the ground up."), SPAN_NOTICE("You tip \the [src] and build the ground up under it."))
	return built

// Builds up the swath with the load; returns the tiles built up, or 0 when
// none could be and the load was left in piles.
/obj/structure/closet/crate/cart/slip_scraper/proc/tip_load()
	var/built = 0
	for (var/turf/T in swath(dir))
		if (!loads)
			break
		if (grade_problem(T, 1))
			continue
		var/grade = T.terrain_grade + 1
		if (!istype(T, /turf/floor/tamped_earth))
			T = T.ChangeTurf(/turf/floor/tamped_earth)
		T.terrain_grade = grade
		T.terrain_grade_apply()
		loads--
		built++
	if (!built)
		var/turf/here = get_turf(src)
		while (loads > 0)
			loads--
			earth_pile_drop(here, "dirt")
	update_icon()
	return built

// ---- blasting charge ------------------------------------------------------

/obj/item/weapon/grenade/blasting_charge
	name = "empty blasting charge"
	desc = "A small wooden powder case for blasting rock. Fill it with gunpowder, fit a cord fuse and light it with a flame, then stand well back."
	icon = 'icons/obj/earthworking_tools.dmi'
	icon_state = "blasting_charge"
	item_state = "blasting_charge"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_earthworking.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_earthworking.dmi',
		)
	det_time = 60
	nothrow = TRUE
	throw_range = 2
	explosion_size = 1
	explosion_sound = 'sound/weapons/Explosives/Dynamite.ogg'
	var/state = 0 // 0 empty, 1 filled, 2 fused

/obj/item/weapon/grenade/blasting_charge/ready
	name = "blasting charge"
	state = 2

/obj/item/weapon/grenade/blasting_charge/examine(mob/user)
	..(user)
	switch (state)
		if (0)
			to_chat(user, "It is empty. Pour in [BLASTING_POWDER] units of gunpowder.")
		if (1)
			to_chat(user, "It is filled. Fit a rope fuse.")
		if (2)
			to_chat(user, active ? SPAN_DANGER("Its fuse is burning!") : "It is ready. Light the fuse with a flame.")

// The fuse needs a flame; it is not lit in the hand.
/obj/item/weapon/grenade/blasting_charge/attack_self(mob/user)
	if (!active)
		to_chat(user, SPAN_NOTICE(state == 2 ? "Light the fuse with a flame." : "\The [src] isn't ready to light."))
	return

/obj/item/weapon/grenade/blasting_charge/attackby(obj/item/W, mob/user)
	if (state == 0 && istype(W, /obj/item/weapon/reagent_containers))
		if (!W.reagents || !W.reagents.has_reagent("gunpowder", BLASTING_POWDER))
			to_chat(user, SPAN_WARNING("It takes [BLASTING_POWDER] units of gunpowder to fill \the [src]."))
			return TRUE
		W.reagents.remove_reagent("gunpowder", BLASTING_POWDER)
		state = 1
		name = "filled blasting charge"
		to_chat(user, SPAN_NOTICE("You fill \the [src] with gunpowder."))
		return TRUE
	if (state == 1 && istype(W, /obj/item/stack/material/rope))
		var/obj/item/stack/material/rope/R = W
		R.use(1)
		state = 2
		name = "blasting charge"
		to_chat(user, SPAN_NOTICE("You fit a cord fuse to \the [src]."))
		return TRUE
	if (state == 2 && !active && is_hot(W))
		user.visible_message(SPAN_DANGER("[user] lights the fuse of \the [src]!"), SPAN_DANGER("You light the fuse! [det_time / 10] seconds!"))
		activate(user)
		icon_state = "blasting_charge_lit"
		add_fingerprint(user)
		return TRUE
	return ..()

// A light blast that breaks the rock around it but brings down little else.
/obj/item/weapon/grenade/blasting_charge/prime()
	set waitfor = 0
	var/turf/O = get_turf(src)
	if (!O)
		return
	explosion(O, -1, 0, 2, 1, sound = explosion_sound)
	blasting_charge_break_rock(O)
	qdel(src)

// Breaks the mineable rock on and around T as if it had been mined.
/proc/blasting_charge_break_rock(turf/T)
	var/broken = 0
	for (var/turf/floor/dirt/underground/U in range(1, T))
		if (!U.density || !U.is_mineable)
			continue
		U.mining_proc()
		broken++
	return broken

#undef SCRAPER_LOADS
#undef SCRAPER_TIP_TIME
#undef BLASTING_POWDER
