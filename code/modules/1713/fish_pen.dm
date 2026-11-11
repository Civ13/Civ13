// Fish pen: low-tech aquaculture (docs/fish-pen.md, issue #3051).
// A wooden pen set in fresh water holds a small stock of fish. Stock it with
// raw fish you caught, feed it grain, seeds or meat scraps, and the fish breed
// up to a cap. Fish are caught back out with any fishing tool. Unfed fish die
// off; a pen out of fresh water loses its fish. No power is needed.

#define FISH_PEN_CAP 8
#define FISH_PEN_FEED_CAP 20
#define FISH_PEN_CYCLE (5 MINUTES)
#define FISH_PEN_HUNGRY_LOSS 3 // unfed cycles before one fish dies

/proc/fish_pen_water_ok(turf/T)
	if (!istype(T, /turf/floor) || T.density)
		return FALSE
	var/turf/floor/F = T
	if (F.salty)
		return FALSE
	if (istype(F, /turf/floor/beach/water))
		return !istype(F, /turf/floor/beach/water/ice)
	return F.flooded && (istype(F, /turf/floor/trench/flooded) || F.irrigation)

// Feed value of one offered item, or 0 when fish will not eat it.
/proc/fish_pen_feed_value(obj/item/I)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/oat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/barley) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/rice))
		return 2
	if (istype(I, /obj/item/stack/farming/seeds))
		return 1 // per seed
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat))
		return 3
	return 0

/proc/fish_pen_stock_ok(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawfish) && !istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod/salted)

/obj/structure/fish_pen
	name = "fish pen"
	desc = "A ring of wooden stakes for keeping fish. Push it into fresh water, stock it with raw fish you have caught and feed it grain, seeds or meat scraps; the fish breed. Catch them back out with a fishing pole or net."
	icon = 'icons/mob/fish.dmi'
	icon_state = "crabcage0"
	anchored = FALSE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	flammable = TRUE
	var/stock = 0
	var/feed = 0
	var/hungry_cycles = 0
	var/fish_type = /obj/item/weapon/reagent_containers/food/snacks/rawfish
	var/tmp/cycle_epoch = 0

/obj/structure/fish_pen/persistence_runtime_var(key)
	return key == "cycle_epoch" || ..()

/obj/structure/fish_pen/New()
	..()
	schedule_cycle()
	update_icon()

/obj/structure/fish_pen/after_load()
	..()
	schedule_cycle()
	update_icon()

/obj/structure/fish_pen/Move()
	. = ..()
	update_icon()

/obj/structure/fish_pen/proc/schedule_cycle()
	cycle_epoch++
	addtimer(CALLBACK(src, PROC_REF(fish_cycle), cycle_epoch), FISH_PEN_CYCLE)

/obj/structure/fish_pen/proc/in_water()
	return isturf(loc) && fish_pen_water_ok(loc)

/obj/structure/fish_pen/proc/cold_season()
	var/area/A = get_area(src)
	return A && A.location == AREA_OUTSIDE && season == "WINTER"

// One five-minute cycle. Returns FALSE for a stale or retired callback.
/obj/structure/fish_pen/proc/fish_cycle(epoch)
	if (QDELETED(src) || epoch != cycle_epoch)
		return FALSE
	if (stock > 0)
		if (!in_water())
			stock--
		else
			var/need = round((stock + 1) / 2)
			if (feed >= need)
				feed -= need
				hungry_cycles = 0
				if (stock >= 2 && stock < FISH_PEN_CAP && !cold_season())
					stock++
			else
				feed = 0
				hungry_cycles++
				if (hungry_cycles >= FISH_PEN_HUNGRY_LOSS)
					stock--
					hungry_cycles = 0
	if (stock <= 0)
		stock = 0
		hungry_cycles = 0
	update_icon()
	addtimer(CALLBACK(src, PROC_REF(fish_cycle), epoch), FISH_PEN_CYCLE)
	return TRUE

/obj/structure/fish_pen/update_icon()
	if (stock >= 4)
		icon_state = "fish2"
	else if (stock > 0)
		icon_state = "fish1"
	else
		icon_state = in_water() ? "crabcage1" : "crabcage0"

/obj/structure/fish_pen/examine(mob/user)
	..()
	if (!in_water())
		to_chat(user, SPAN_WARNING("It needs to stand in fresh water."))
	if (!stock)
		to_chat(user, SPAN_NOTICE("It is empty. Stock it with raw fish; two or more will breed."))
		return
	to_chat(user, SPAN_NOTICE("It holds [stock] fish (room for [FISH_PEN_CAP])."))
	if (feed <= 0)
		to_chat(user, SPAN_WARNING("The fish are hungry. Feed them grain, seeds or meat scraps."))
	else
		to_chat(user, SPAN_NOTICE("There is feed for about [round(feed / max(1, round((stock + 1) / 2)))] more feeding[feed == 1 ? "" : "s"]."))
	if (cold_season())
		to_chat(user, SPAN_NOTICE("The fish do not breed in the winter cold."))

/obj/structure/fish_pen/attackby(obj/item/W, mob/user)
	if (fish_pen_stock_ok(W))
		if (!in_water())
			to_chat(user, SPAN_WARNING("Put the pen in fresh water first."))
			return
		if (stock >= FISH_PEN_CAP)
			to_chat(user, SPAN_WARNING("The pen is full."))
			return
		if (!stock)
			fish_type = W.type
		stock++
		user.drop_from_inventory(W)
		qdel(W)
		to_chat(user, SPAN_NOTICE("You release the fish into the pen. It now holds [stock]."))
		update_icon()
		return
	var/value = fish_pen_feed_value(W)
	if (value)
		if (feed >= FISH_PEN_FEED_CAP)
			to_chat(user, SPAN_WARNING("The fish have plenty of feed already."))
			return
		if (istype(W, /obj/item/stack/farming/seeds))
			var/obj/item/stack/S = W
			var/used = min(S.amount, FISH_PEN_FEED_CAP - feed)
			feed += used
			S.use(used)
		else
			feed = min(FISH_PEN_FEED_CAP, feed + value)
			user.drop_from_inventory(W)
			qdel(W)
		to_chat(user, SPAN_NOTICE("You scatter the feed into the pen."))
		return
	if (istype(W, /obj/item/weapon/fishing))
		if (!stock)
			to_chat(user, SPAN_WARNING("There are no fish in the pen."))
			return
		user.visible_message("[user] starts fishing in \the [src].")
		if (!do_after(user, 50, src) || !stock)
			return
		catch_fish(user)
		return
	return ..()

/obj/structure/fish_pen/proc/catch_fish(mob/user)
	if (stock <= 0)
		return null
	stock--
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/F = new fish_type(user ? get_turf(user) : get_turf(src))
	if (user)
		to_chat(user, SPAN_NOTICE("You catch \a [F] from the pen.[stock < 2 ? " Leave at least two if you want them to keep breeding." : ""]"))
	update_icon()
	return F

#undef FISH_PEN_CAP
#undef FISH_PEN_FEED_CAP
#undef FISH_PEN_CYCLE
#undef FISH_PEN_HUNGRY_LOSS
