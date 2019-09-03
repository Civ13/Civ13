/obj/structure/rails
	name = "rails"
	desc = "A bunch of rails used by trains."
	icon = 'icons/obj/trains.dmi'
	icon_state = "rails"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	layer = 2.5

/obj/structure/rails/end
	icon_state = "rails_end"

/obj/structure/trains
	icon = 'icons/obj/trains.dmi'
	icon_state = "miningcar"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	anchored = FALSE
	density = TRUE
	opacity = FALSE
	var/automovement = FALSE
	var/list/linked = list()
	var/health = 100
	var/train_speed = 4 //deciseconds of delay, so lower is better
/obj/structure/trains/Bumped(atom/AM)
	var/turf/tgt = get_step(src,AM.dir)
	if (!tgt)
		return FALSE
	if (rail_canmove(AM.dir))
		src.forceMove(tgt)
		return TRUE

/obj/structure/trains/verb/linking()
	set category = null
	set name = "Link"
	set desc = "Link with the carriage in front."

	set src in range(1)
	if (!istype(usr, /mob/living/carbon/human))
		return
	for (var/obj/structure/trains/TR in get_step(src,dir))
		if (!TR.linked.len && !linked.len)
			visible_message("[usr] links the two carriages together.","You link the two carriages together.")
			TR.linked += src
			return
	return

/obj/structure/trains/proc/rail_movement()
	if (!automovement)
		playsound(src.loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
		return FALSE
	spawn(train_speed)
		if (!automovement)
			playsound(src.loc, 'sound/machines/train/stopping.ogg', 100, TRUE)
			return FALSE
		playsound(src.loc, 'sound/machines/train/moving.ogg', 100, TRUE)
		process_rail_movement()
		rail_movement()
		rail_sound()

/obj/structure/trains/proc/rail_sound()
	if (automovement)
		spawn(10)
			playsound(src.loc, 'sound/machines/train/moving.ogg', 100, TRUE)

/obj/structure/trains/proc/process_rail_movement()
	if (automovement)
		var/turf/tgtt = get_step(src,dir)
		var/turf/curr = get_turf(src)
		if (rail_canmove(dir))
			//push (or hit) wtv is in front...
			for (var/obj/structure/trains/TF in tgtt)
				if (TF.rail_canmove(dir))
					TF.Bumped(src)
				else
					visible_message("\The [src] hits \the [TF]!")
					automovement = FALSE
					health -= 5
					return FALSE
			for (var/obj/O in tgtt)
				if (O.density && !istype(O, /obj/structure/trains) && !istype(O, /obj/structure/rails))
					visible_message("\The [src] hits \the [O]!")
					O.ex_act(1.0)
					health -= 15*O.w_class
					automovement = FALSE
					return FALSE
			for (var/mob/living/L in tgtt)
				if (L.mob_size <= 42)
					visible_message("\The [src] crushes \the [L]!")
					L.crush()
				else
					visible_message("\The [src] hits \the [L]!")
					health -= 8
					automovement = FALSE
					L.adjustBruteLoss(65)
					return FALSE
			// move this train...
			src.forceMove(tgtt)
			//...and drag wtv is linked
			for (var/obj/structure/trains/T in linked)
				if (T.rail_canmove(dir))
					T.forceMove(curr)
				else
					linked -= T
		return TRUE
	return FALSE
/obj/structure/trains/proc/rail_canmove(mdir=dir)
	var/turf/tgtt = get_step(src,mdir)
	if (!tgtt)
		return FALSE
	for (var/obj/structure/rails/R in tgtt)
		if (mdir in list(1,2) && R.dir in list(1,2))
			return TRUE
		else if (mdir in list(4,8) && R.dir in list(4,8))
			return TRUE
	return FALSE

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
	if (istype(user, /mob/living/carbon/human) && user in range(1,src))
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
