// Special goods and passenger stock (docs/trains.md#special-stock): the stock
// car, the ice car, the baggage and mail van and the long sleeper and dining
// cars. Their layouts are in train_car_layout(); this file holds the ice
// car's bunker and cold lockers and the kits.
//
// The ice car builds on the ice house (small_ancient.dm). One ice bunker at
// the front of the car is packed with snow or cut ice; the cold lockers down
// both sides keep food the way a cold ice house does for as long as the
// bunker on their car has ice in it. The insulated body makes the ice last
// four times as long as it would in the open.

#define COLD_LOCKER_REACH 8 // tiles from a cold locker to the bunker of its car

// The ice car this stands on, if any.
/proc/train_ice_car(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	for (var/obj/structure/trains/platform/P in range(1, T))
		if ((P.car_kind == "ice_car" || train_car_insulated(P.car_kind)) && (T in train_platform_tiles(P.loc, P.dir)))
			return P
	return null

// A car drawn on a train sheet with insulated sides (train_draught.dm) keeps
// its ice like an ice car.
/proc/train_car_insulated(kind)
	if (copytext(kind, 1, 3) != "c:")
		return FALSE
	var/list/L = train_car_layout(kind)
	return L && L["insulated"]

/obj/structure/closet/ice_house/reefer
	name = "ice bunker"
	desc = "The zinc-lined ice bunker of an ice car. Pack snow or blocks of cut ice into it and the car's cold lockers keep food fresh far longer, until it melts. On an ice car the insulated body makes the ice last four times as long."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "ice_bunker"
	icon_closed = "ice_bunker"
	icon_opened = "ice_bunker_open"

/obj/structure/closet/ice_house/reefer/slow_melt()
	return !!train_ice_car(src)

/obj/structure/closet/ice_house/reefer/slow_melt_text()
	return "The insulated car around it makes the ice last."

/obj/structure/closet/ice_house/cold_locker
	name = "cold locker"
	desc = "An insulated food locker in an ice car. It keeps food as cold as the ice bunker on its car."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "cold_locker"
	icon_closed = "cold_locker"
	icon_opened = "cold_locker_open"
	var/tmp/obj/structure/closet/ice_house/reefer/feed = null

/obj/structure/closet/ice_house/cold_locker/persistence_runtime_var(key)
	return key == "feed" || ..()

// The bunker that cools this locker: the one on its own car, kept between
// looks for as long as it stays in reach.
/obj/structure/closet/ice_house/cold_locker/proc/bunker()
	if (feed && !QDELETED(feed) && feed.z == z && get_dist(src, feed) <= COLD_LOCKER_REACH)
		return feed
	feed = null
	var/obj/structure/trains/platform/car = train_ice_car(src)
	if (!car)
		return null
	for (var/obj/structure/closet/ice_house/reefer/B in range(COLD_LOCKER_REACH, src))
		var/obj/structure/trains/platform/other = train_ice_car(B)
		if (other && other.car_id == car.car_id)
			feed = B
			break
	return feed

/obj/structure/closet/ice_house/cold_locker/is_cold()
	var/obj/structure/closet/ice_house/reefer/B = bunker()
	return B && B.cold > 0

// Snow and ice go to the bunker, not into a locker.
/obj/structure/closet/ice_house/cold_locker/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/snowwall) || istype(W, /obj/item/weapon/ice_block))
		var/obj/structure/closet/ice_house/reefer/B = bunker()
		if (!B)
			to_chat(user, SPAN_WARNING("\The [src] is cooled by the ice bunker of an ice car. There is none on this car."))
			return
		return B.attackby(W, user)
	return ..()

/obj/structure/closet/ice_house/cold_locker/cold_text(mob/user)
	var/obj/structure/closet/ice_house/reefer/B = bunker()
	if (!B)
		to_chat(user, SPAN_WARNING("It is only cold on an ice car with an ice bunker."))
		return
	if (B.cold > 0)
		to_chat(user, SPAN_NOTICE("The car's ice bunker keeps it cold."))
	else
		to_chat(user, SPAN_WARNING("The car's ice bunker has melted out. Pack it with snow or cut ice."))

/obj/structure/train_car_kit/stock_car
	name = "stock car kit"
	car_kind = "stock_car"
/obj/structure/train_car_kit/ice_car
	name = "ice car kit"
	car_kind = "ice_car"
/obj/structure/train_car_kit/mail_van
	name = "baggage and mail van kit"
	car_kind = "mail_van"
/obj/structure/train_car_kit/bogie_sleeper
	name = "bogie sleeper car kit"
	car_kind = "bogie_sleeper"
/obj/structure/train_car_kit/bogie_dining
	name = "bogie dining car kit"
	car_kind = "bogie_dining"

#undef COLD_LOCKER_REACH
