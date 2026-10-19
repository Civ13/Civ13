// Completed stages and paid material survive saves; action locks never do.
/proc/flax_worker_can_reach(mob/user, atom/target)
	if (!user || !target || !user.loc || !target.loc || user.stat != CONSCIOUS)
		return FALSE
	var/turf/U = get_turf(user)
	var/turf/T = get_turf(target)
	return U && T && U.z == T.z && get_dist(U, T) <= 1

/mob/proc/flax_processing_wait(delay, atom/target)
	return do_after(src, delay, target)

/obj/item/stack/material/flax/verb/tie_flax_bundle()
	set name = "Tie Flax Bundle"
	set category = "Object"
	set src in usr
	tie_bundle(usr)

/obj/item/stack/material/flax/proc/tie_bundle(mob/user)
	if (!flax_worker_can_reach(user, src) || loc != user || amount < 2)
		return FALSE
	var/turf/T = get_turf(user)
	if (!use(2))
		return FALSE
	var/obj/item/flax_bundle/B = new(T)
	user.put_in_any_hand_if_possible(B)
	to_chat(user, SPAN_NOTICE("You tie two portions of flax with their own fibres. Place the bundle in fresh water to ret it."))
	return TRUE

/obj/item/flax_bundle
	name = "tied flax bundle"
	desc = "Two portions of flax tied with their own fibres. Use on fresh water to soak it; completed soaking stages survive interruption."
	icon = 'icons/obj/materials.dmi'
	icon_state = "flax"
	color = "#A3946E"
	w_class = ITEM_SIZE_NORMAL
	var/soak_stage = 0
	var/tmp/soaking = FALSE

/obj/item/flax_bundle/persistence_runtime_var(key)
	return key == "soaking" || ..()

/obj/item/flax_bundle/proc/valid_water(turf/floor/beach/water/W)
	return istype(W) && !W.salty && W.radiation <= 0 && loc == W

/obj/item/flax_bundle/afterattack(atom/target, mob/user, proximity)
	if (!proximity || loc != user || !flax_worker_can_reach(user, target) || !istype(target, /turf/floor/beach/water))
		return
	var/turf/floor/beach/water/W = target
	if (W.salty || W.radiation > 0)
		to_chat(user, SPAN_WARNING("Use non-irradiated fresh water to ret flax."))
		return
	if (!user.drop_from_inventory(src, W) || loc != W)
		return
	soak(user, W)

/obj/item/flax_bundle/attack_hand(mob/user)
	if (istype(loc, /turf/floor/beach/water))
		soak(user, loc)
		return
	return ..()

/obj/item/flax_bundle/proc/soak(mob/user, turf/floor/beach/water/W)
	if (soaking || !valid_water(W) || !flax_worker_can_reach(user, src) || soak_stage < 0 || soak_stage >= 3)
		return FALSE
	soaking = TRUE
	while (soak_stage < 3)
		if (!user.flax_processing_wait(100, src) || !valid_water(W) || !flax_worker_can_reach(user, src))
			soaking = FALSE
			return FALSE
		soak_stage++
	soaking = FALSE
	new /obj/item/stack/rotten_flax(W, 2, FALSE)
	qdel(src)
	return TRUE

/obj/item/flax_bundle/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("Completed soaking stages: [soak_stage]/3."))

/obj/item/stack/rotten_flax
	name = "rotted flax"
	desc = "Water-retted flax. Load up to ten portions into a flax comb to separate straw, tow and textile lint."
	icon = 'icons/obj/materials.dmi'
	icon_state = "flax"
	color = "#756F46"
	singular_name = "portion of rotted flax"
	max_amount = 20
	w_class = ITEM_SIZE_SMALL

/obj/item/flax_work
	name = "partly combed flax batch"
	desc = "Paid flax awaiting further combing. Load into an empty flax comb to continue."
	icon = 'icons/obj/materials.dmi'
	icon_state = "flax"
	color = "#B4A16C"
	var/units = 0
	var/stage = 0

/obj/item/flax_work/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("[units] portions; completed combing stages: [stage]/3."))

/obj/structure/flax_comb
	name = "flax comb"
	desc = "A wooden comb for separating rotted flax. Load up to ten portions, then use by hand to separate straw, tow and textile lint. Drag it onto yourself to recover an unfinished batch."
	icon = 'icons/obj/structures.dmi'
	icon_state = "drying_rack_empty"
	anchored = TRUE
	density = TRUE
	var/tmp/combing = FALSE

/obj/structure/flax_comb/persistence_runtime_var(key)
	return key == "combing" || ..()

/obj/structure/flax_comb/attackby(obj/item/W, mob/user)
	if (combing || !W || !flax_worker_can_reach(user, src) || W.loc != user || contents.len)
		return
	if (istype(W, /obj/item/flax_work))
		var/obj/item/flax_work/B = W
		if (B.units < 1 || B.units > 10 || B.stage < 0 || B.stage >= 3)
			return
		user.drop_from_inventory(B, src)
		return
	if (istype(W, /obj/item/stack/rotten_flax))
		var/obj/item/stack/rotten_flax/F = W
		var/count = min(10, F.amount)
		if (count < 1 || !F.use(count))
			return
		var/obj/item/flax_work/B = new(src)
		B.units = count
		return
	return ..()

/obj/structure/flax_comb/attack_hand(mob/user)
	return comb(user)

/obj/structure/flax_comb/proc/comb(mob/user)
	var/obj/item/flax_work/B = locate() in contents
	if (combing || !B || !flax_worker_can_reach(user, src))
		return FALSE
	combing = TRUE
	if (!user.flax_processing_wait(100, src) || !flax_worker_can_reach(user, src) || !B || B.loc != src)
		combing = FALSE
		return FALSE
	var/completed = finish_stage(B)
	combing = FALSE
	return completed

/obj/structure/flax_comb/proc/finish_stage(obj/item/flax_work/B)
	if (!istype(loc, /turf) || !B || B.loc != src || B.units < 1 || B.units > 10 || B.stage < 0 || B.stage >= 3)
		return FALSE
	var/count = B.units
	var/output_stage = B.stage
	B.stage++
	switch (output_stage)
		if (0)
			new /obj/item/stack/material/straw(loc, count, FALSE)
		if (1)
			new /obj/item/stack/flax_tow(loc, count, FALSE)
		if (2)
			new /obj/item/stack/textile_lint(loc, count, FALSE)
	if (B.stage == 3)
		qdel(B)
	return TRUE

/obj/structure/flax_comb/MouseDrop(atom/over_object)
	var/mob/user = usr
	if (over_object != user || combing || !flax_worker_can_reach(user, src))
		return
	for (var/obj/item/flax_work/B in contents)
		B.forceMove(get_turf(src))

/obj/structure/flax_comb/proc/release_flax()
	var/turf/T = get_turf(src)
	if (T)
		for (var/obj/item/flax_work/B in contents)
			B.forceMove(T)

/obj/structure/flax_comb/Destroy()
	release_flax()
	return ..()

/obj/structure/flax_comb/Del()
	release_flax()
	return ..()

/obj/item/stack/flax_tow
	name = "flax tow"
	desc = "Coarse flax fibres. Use in hand to spin two portions into one coil of twine, usable as ordinary rope."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	color = "#C0AA74"
	singular_name = "portion of tow"
	max_amount = 20
	w_class = ITEM_SIZE_SMALL
	var/tmp/spinning = FALSE

/obj/item/stack/flax_tow/persistence_runtime_var(key)
	return key == "spinning" || ..()

/obj/item/stack/flax_tow/attack_self(mob/user)
	if (spinning || loc != user || amount < 2 || !flax_worker_can_reach(user, src))
		return
	spinning = TRUE
	if (!user.flax_processing_wait(50, src) || loc != user || amount < 2 || !flax_worker_can_reach(user, src))
		spinning = FALSE
		return
	var/turf/T = get_turf(user)
	spinning = FALSE
	if (use(2))
		var/obj/item/stack/material/rope/R = new(T, 1, FALSE)
		user.put_in_any_hand_if_possible(R)
		to_chat(user, SPAN_NOTICE("You spin the tow into a coil of twine, usable as rope."))

/obj/item/stack/textile_lint
	name = "textile lint"
	desc = "Fine flax fibres. Use in hand to prepare two portions as one portion of retted fabric for a loom."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-rettedfabric"
	color = "#D1C7A9"
	singular_name = "portion of textile lint"
	max_amount = 20
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/textile_lint/attack_self(mob/user)
	if (loc != user || amount < 2 || !flax_worker_can_reach(user, src))
		return
	var/turf/T = get_turf(user)
	if (use(2))
		var/obj/item/stack/material/rettedfabric/F = new(T, 1, FALSE)
		user.put_in_any_hand_if_possible(F)
