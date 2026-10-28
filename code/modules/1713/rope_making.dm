// An optional dressed-fibre/yarn/laid-rope route. Quantities and times are game tuning.
// Existing grass twine, tow twine and raw-plant recipes remain independent.
/proc/rope_worker_ready(mob/user, atom/target)
	return !persistence_save_in_progress && !persistence_active_operation && flax_worker_can_reach(user, target) && !QDELETED(target) && !QDELETED(user)

/proc/rope_held(mob/user, obj/item/I)
	return ishuman(user) && I && I.loc == user && (user:l_hand == I || user:r_hand == I)

/proc/rope_transfer_held(mob/user, obj/item/I, atom/target)
	var/mob/living/H = user
	return istype(H) && H.transfer_held_item_to(I, target) && I.loc == target

/mob/proc/rope_making_wait(delay, atom/target)
	return do_after(src, delay, target)

/obj/item/stack/material/hemp/verb/tie_hemp_bundle()
	set name = "Tie Hemp Bundle"
	set category = "Object"
	set src in usr
	tie_rope_bundle(usr)

/obj/item/stack/material/hemp/proc/tie_rope_bundle(mob/user)
	if (!rope_worker_ready(user, src) || !rope_held(user, src) || amount < 2)
		return FALSE
	var/turf/T = get_turf(user)
	if (!use(2))
		return FALSE
	var/obj/item/hemp_rope_bundle/B = new(T)
	user.put_in_any_hand_if_possible(B)
	return TRUE

/obj/item/hemp_rope_bundle
	name = "hemp rope-making bundle"
	desc = "Two paid portions of hemp. Use on fresh water to ret; then load into a hemp dressing bench to dry, break, scutch and comb. Each use completes one stage."
	icon = 'icons/obj/materials.dmi'
	icon_state = "hemp"
	w_class = ITEM_SIZE_NORMAL
	var/stage = 0
	var/tmp/working = FALSE

/obj/item/hemp_rope_bundle/persistence_runtime_var(key)
	return key == "working" || ..()

/obj/item/hemp_rope_bundle/proc/valid_stage()
	return isnum(stage) && stage == round(stage) && stage >= 0 && stage <= 4

/obj/item/hemp_rope_bundle/afterattack(atom/target, mob/user, proximity)
	if (!proximity || !rope_held(user, src) || !rope_worker_ready(user, target) || !istype(target, /turf/floor/beach/water))
		return
	var/turf/floor/beach/water/W = target
	if (working || stage != 0 || W.salty || W.radiation > 0)
		return
	if (!rope_transfer_held(user, src, W))
		return
	ret(user, W)

/obj/item/hemp_rope_bundle/attack_hand(mob/user)
	if (stage == 0 && istype(loc, /turf/floor/beach/water))
		return ret(user, loc)
	return ..()

/obj/item/hemp_rope_bundle/proc/ret(mob/user, turf/floor/beach/water/W)
	if (working || !valid_stage() || stage != 0 || !rope_worker_ready(user, src) || !istype(W) || loc != W || W.salty || W.radiation > 0)
		return FALSE
	working = TRUE
	var/datum/admission = persistence_admission_identity
	var/completed = user.rope_making_wait(300, src)
	if (!completed || !rope_worker_ready(user, src) || admission != persistence_admission_identity || loc != W || W.salty || W.radiation > 0 || stage != 0)
		working = FALSE
		return FALSE
	stage = 1
	working = FALSE
	to_chat(user, SPAN_NOTICE("The hemp is retted. Recover it for drying and dressing at a hemp dressing bench."))
	return TRUE

/obj/item/hemp_rope_bundle/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("Completed preparation stages: [stage]/5 (retting, drying, breaking, scutching, combing)."))

/obj/structure/hemp_dressing_bench
	name = "hemp dressing bench"
	desc = "A hand-worked brake, scutching board and comb. Load a retted hemp bundle; use by hand to dry, break woody stems, scutch away shives, then comb the fibres. Drag onto yourself to recover the batch."
	icon = 'icons/obj/structures.dmi'
	icon_state = "drying_rack_empty"
	anchored = TRUE
	density = TRUE
	var/tmp/working = FALSE

/obj/structure/hemp_dressing_bench/persistence_runtime_var(key)
	return key == "working" || ..()

/obj/structure/hemp_dressing_bench/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/hemp_rope_bundle))
		return ..()
	var/obj/item/hemp_rope_bundle/B = W
	if (working || contents.len || !rope_worker_ready(user, src) || !rope_held(user, B) || B.working || !B.valid_stage() || B.stage < 1)
		return
	rope_transfer_held(user, B, src)

/obj/structure/hemp_dressing_bench/attack_hand(mob/user)
	return dress(user)

/obj/structure/hemp_dressing_bench/proc/dress(mob/user)
	var/obj/item/hemp_rope_bundle/B = locate() in contents
	if (working || !B || B.working || !B.valid_stage() || B.stage < 1 || !isturf(loc) || !anchored || !rope_worker_ready(user, src))
		return FALSE
	working = TRUE
	var/old_stage = B.stage
	var/turf/site = loc
	var/datum/admission = persistence_admission_identity
	var/completed = user.rope_making_wait(100, src)
	if (!completed || !rope_worker_ready(user, src) || admission != persistence_admission_identity || loc != site || !anchored || !B || QDELETED(B) || B.loc != src || B.stage != old_stage)
		working = FALSE
		return FALSE
	B.stage++
	if (B.stage == 5)
		qdel(B)
		new /obj/item/stack/dressed_hemp(site, 2, FALSE)
	else
		var/list/steps = list("retted", "dried", "broken", "scutched")
		to_chat(user, SPAN_NOTICE("The hemp has been [steps[B.stage]]. Use the bench again for the next stage."))
	working = FALSE
	return TRUE

/obj/structure/hemp_dressing_bench/MouseDrop(atom/over_object)
	var/mob/user = usr
	if (over_object == user && !working && rope_worker_ready(user, src))
		release_rope_material()

/obj/structure/hemp_dressing_bench/proc/release_rope_material()
	var/turf/T = get_turf(src)
	if (T)
		for (var/obj/item/hemp_rope_bundle/B in contents)
			B.forceMove(T)

/obj/structure/hemp_dressing_bench/Destroy()
	release_rope_material()
	return ..()

/obj/structure/hemp_dressing_bench/Del()
	release_rope_material()
	return ..()

/obj/item/stack/dressed_hemp
	name = "dressed hemp fibres"
	desc = "Retted, dried, broken, scutched and combed hemp. Hold this and a hand spindle; use the spindle on the fibres to spin rope yarn."
	icon = 'icons/obj/materials.dmi'
	icon_state = "hemp"
	singular_name = "portion of dressed hemp"
	max_amount = 20

/obj/item/rope_spindle
	name = "hand spindle"
	desc = "Spins one portion of dressed hemp or flax tow into one bundle of rope yarn. Hold the spindle and fibres in opposite hands and use it on the fibres."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-wood"
	w_class = ITEM_SIZE_SMALL
	var/tmp/spinning = FALSE

/obj/item/rope_spindle/persistence_runtime_var(key)
	return key == "spinning" || ..()

/obj/item/rope_spindle/afterattack(atom/target, mob/user, proximity)
	if (proximity && istype(target, /obj/item/stack))
		spin(user, target)

/obj/item/rope_spindle/proc/spin(mob/user, obj/item/stack/F)
	var/product
	if (F && F.type == /obj/item/stack/dressed_hemp)
		product = /obj/item/stack/rope_yarn/hemp
	else if (F && F.type == /obj/item/stack/flax_tow)
		product = /obj/item/stack/rope_yarn/flax
	else
		return FALSE
	if (spinning || !rope_worker_ready(user, src) || !rope_held(user, src) || !rope_held(user, F) || F.amount < 1)
		return FALSE
	spinning = TRUE
	var/datum/admission = persistence_admission_identity
	var/completed = user.rope_making_wait(50, F)
	if (!completed || !rope_worker_ready(user, src) || admission != persistence_admission_identity || !rope_held(user, src) || !rope_held(user, F) || QDELETED(F) || F.amount < 1)
		spinning = FALSE
		return FALSE
	var/turf/T = get_turf(user)
	spinning = FALSE
	if (!F.use(1))
		return FALSE
	new product(T, 1, FALSE)
	return TRUE

/obj/item/stack/rope_yarn
	name = "rope yarn"
	desc = "Spun fibre for laid rope. Load four matching bundles into an empty ropewalk."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	singular_name = "bundle of rope yarn"
	max_amount = 20

/obj/item/stack/rope_yarn/hemp
	name = "hemp rope yarn"
	color = "#A3946E"

/obj/item/stack/rope_yarn/flax
	name = "flax rope yarn"
	color = "#C0AA74"

/obj/item/laid_rope_work
	name = "loaded rope-making batch"
	desc = "Four equal yarn bundles. Resume in an empty ropewalk. Completed strand-twisting survives removal; final laying twists in the opposite direction."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	var/stage = 0

/obj/item/laid_rope_work/hemp
	name = "hemp rope-making batch"

/obj/item/laid_rope_work/flax
	name = "flax rope-making batch"

/obj/item/laid_rope_work/proc/valid_stage()
	return (type == /obj/item/laid_rope_work/hemp || type == /obj/item/laid_rope_work/flax) && isnum(stage) && stage == round(stage) && stage >= 0 && stage <= 1

/obj/item/laid_rope_work/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("[stage == 1 ? "Strands twisted under tension; ready for counter-laying." : "Four yarn bundles loaded; strands await twisting."]"))

/obj/structure/ropewalk
	name = "hand ropewalk"
	desc = "A hand-powered rope-making frame with a tensioned movable end. Load four matching hemp or flax yarn bundles. Use once to twist the four strands under tension, then again to lay them together in the opposite direction. Drag onto yourself to recover unfinished work."
	icon = 'icons/obj/structures.dmi'
	icon_state = "drying_rack_empty"
	anchored = TRUE
	density = TRUE
	var/tmp/working = FALSE

/obj/structure/ropewalk/persistence_runtime_var(key)
	return key == "working" || ..()

/obj/structure/ropewalk/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/rope_yarn) || istype(W, /obj/item/laid_rope_work))
		return load_yarn(user, W)
	return ..()

/obj/structure/ropewalk/proc/load_yarn(mob/user, obj/item/W)
	if (working || contents.len || !anchored || !isturf(loc) || !rope_worker_ready(user, src) || !rope_held(user, W))
		return FALSE
	if (istype(W, /obj/item/laid_rope_work))
		var/obj/item/laid_rope_work/B = W
		return B.valid_stage() && rope_transfer_held(user, B, src)
	var/batch_type
	if (W.type == /obj/item/stack/rope_yarn/hemp)
		batch_type = /obj/item/laid_rope_work/hemp
	else if (W.type == /obj/item/stack/rope_yarn/flax)
		batch_type = /obj/item/laid_rope_work/flax
	else
		return FALSE
	var/obj/item/stack/rope_yarn/Y = W
	if (Y.amount < 4 || !Y.use(4))
		return FALSE
	new batch_type(src)
	return TRUE

/obj/structure/ropewalk/attack_hand(mob/user)
	return lay_rope(user)

/obj/structure/ropewalk/proc/lay_rope(mob/user)
	var/obj/item/laid_rope_work/B = locate() in contents
	if (working || !B || !B.valid_stage() || !anchored || !isturf(loc) || !rope_worker_ready(user, src))
		return FALSE
	working = TRUE
	var/old_stage = B.stage
	var/turf/site = loc
	var/datum/admission = persistence_admission_identity
	var/completed = user.rope_making_wait(100, src)
	if (!completed || !rope_worker_ready(user, src) || admission != persistence_admission_identity || loc != site || !anchored || !B || QDELETED(B) || B.loc != src || B.stage != old_stage)
		working = FALSE
		return FALSE
	if (B.stage == 0)
		B.stage = 1
		to_chat(user, SPAN_NOTICE("You twist four strands under tension. Use the ropewalk again to lay them together in the opposite direction."))
	else
		// Retire the paid batch before output; no callback can replay it.
		qdel(B)
		new /obj/item/stack/material/rope(site, 4, FALSE)
		to_chat(user, SPAN_NOTICE("You counter-lay the strands into four usable coils of rope."))
	working = FALSE
	return TRUE

/obj/structure/ropewalk/MouseDrop(atom/over_object)
	var/mob/user = usr
	if (over_object == user && !working && rope_worker_ready(user, src))
		release_rope_material()

/obj/structure/ropewalk/proc/release_rope_material()
	var/turf/T = get_turf(src)
	if (T)
		for (var/obj/item/laid_rope_work/B in contents)
			B.forceMove(T)

/obj/structure/ropewalk/Destroy()
	release_rope_material()
	return ..()

/obj/structure/ropewalk/Del()
	release_rope_material()
	return ..()
