// Holiday calendar: on real-world holidays, players get a greeting when they
// take control of a character, and at Christmas each character gets one
// wrapped gift with a treat inside.
// Based on CM-SS13's holidays.dm (cmss13-devs/cmss13, AGPL-3.0, originally
// from /tg/station); reimplemented for Civ13. Dates use the server's clock.

/datum/holiday
	var/name = "holiday"
	var/begin_month = 1
	var/begin_day = 1
	var/end_day = 0 // last day in begin_month; 0 means a single day
	var/greeting = null
	var/gives_gift = FALSE

/datum/holiday/proc/celebrated_on(month, day)
	if (month != begin_month)
		return FALSE
	return day >= begin_day && day <= (end_day ? end_day : begin_day)

/datum/holiday/proc/greet()
	return greeting ? greeting : "Happy [name]!"

/datum/holiday/new_year
	name = "New Year"
	greeting = "Happy New Year!"

/datum/holiday/valentines
	name = "Valentine's Day"
	begin_month = 2
	begin_day = 14
	greeting = "Happy Valentine's Day! Be kind to someone today."

/datum/holiday/halloween
	name = "Halloween"
	begin_month = 10
	begin_day = 31
	greeting = "Happy Halloween! Mind the shadows tonight."

/datum/holiday/christmas
	name = "Christmas"
	begin_month = 12
	begin_day = 24
	end_day = 26
	greeting = "Merry Christmas! There is a wrapped gift for you."
	gives_gift = TRUE

/datum/holiday/new_years_eve
	name = "New Year's Eve"
	begin_month = 12
	begin_day = 31
	greeting = "Happy New Year's Eve!"

/proc/holiday_for_date(month, day)
	for (var/path in subtypesof(/datum/holiday))
		var/datum/holiday/H = new path
		if (H.celebrated_on(month, day))
			return H
	return null

/proc/current_holiday()
	return holiday_for_date(text2num(time2text(world.realtime, "MM")), text2num(time2text(world.realtime, "DD")))

/client/var/tmp/holiday_greeted = null
var/global/list/holiday_gift_ckeys = list()

// Greets the player once per connection and, on a gift holiday, gives each
// player one gift per round.
/mob/living/human/proc/holiday_login(datum/holiday/H)
	if (!H)
		H = current_holiday()
	if (!client || !H)
		return FALSE
	if (client.holiday_greeted != H.name)
		client.holiday_greeted = H.name
		to_chat(src, "<span class='notice'><big><b>[H.greet()]</b></big></span>")
	if (H.gives_gift && ckey && !(ckey in holiday_gift_ckeys) && stat != DEAD)
		holiday_gift_ckeys += ckey
		var/obj/item/weapon/holiday_gift/G = new(get_turf(src))
		put_in_hands(G)
		return TRUE
	return FALSE

/obj/item/weapon/holiday_gift
	name = "wrapped gift"
	desc = "A small present in bright paper. Use it in your hand to open it."
	icon = 'icons/obj/christmas.dmi'
	icon_state = "gift1"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

// First spawn only: a restored gift keeps the paper it was saved with.
/obj/item/weapon/holiday_gift/on_runtime_spawn()
	..()
	icon_state = pick("gift1", "gift2", "gift3")

/obj/item/weapon/holiday_gift/attack_self(mob/user)
	var/path = pick(/obj/item/weapon/reagent_containers/food/snacks/cookie, /obj/item/weapon/reagent_containers/food/snacks/chocolatebar)
	var/obj/item/treat = new path(get_turf(user))
	user.visible_message("<span class='notice'>[user] unwraps \the [src] and finds \a [treat] inside.</span>", "<span class='notice'>You unwrap \the [src] and find \a [treat] inside.</span>")
	user.drop_from_inventory(src)
	user.put_in_hands(treat)
	qdel(src)
