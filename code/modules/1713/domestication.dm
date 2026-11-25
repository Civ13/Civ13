// Domestication: wild cattle, goats, sheep and pigs must be tamed before they
// can be leashed, milked, sheared, hitched or fitted with tack. See
// docs/domestication.md.
//
// Animals that spawn in the wild are wild; young take after a wild animal on
// their mother's tile. Animals that were already living before this shipped
// (and anything spawned by admins) start tame. Taming is feeding by hand: each
// feeding at least TAME_FEED_GAP real minutes after the last counts once, and
// after TAME_FEEDINGS of them the animal is tame. Trust fades by one feeding
// for each full day without one. Times are real minutes kept as text, as in
// stone_age_traps.dm.

#define TAME_FEEDINGS 6
#define TAME_FEED_GAP 10
#define TAME_FADE_AFTER 1440

/mob/living/simple_animal/var/domesticable = FALSE
/mob/living/simple_animal/var/wild = FALSE
/mob/living/simple_animal/var/tame_trust = 0
/mob/living/simple_animal/var/tame_fed // text minutes

/mob/living/simple_animal/cattle
	domesticable = TRUE
/mob/living/simple_animal/goat
	domesticable = TRUE
/mob/living/simple_animal/sheep
	domesticable = TRUE
/mob/living/simple_animal/pig_boar
	domesticable = TRUE
/mob/living/simple_animal/pig_gilt
	domesticable = TRUE

// The kind an animal breeds with, so young take after their own herd.
/mob/living/simple_animal/proc/domestic_family()
	if (istype(src, /mob/living/simple_animal/cattle))
		return /mob/living/simple_animal/cattle
	if (istype(src, /mob/living/simple_animal/goat))
		return /mob/living/simple_animal/goat
	if (istype(src, /mob/living/simple_animal/sheep))
		return /mob/living/simple_animal/sheep
	if (istype(src, /mob/living/simple_animal/pig_boar) || istype(src, /mob/living/simple_animal/pig_gilt))
		return /mob/living/simple_animal/pig_gilt
	return null

/mob/living/simple_animal/proc/make_wild()
	if (!domesticable)
		return FALSE
	wild = TRUE
	tame_trust = 0
	tame_fed = null
	return TRUE

// Young born (or spawned) on a tile with a wild animal of their kind are wild.
/mob/living/simple_animal/on_runtime_spawn()
	..()
	if (!domesticable || wild || !isturf(loc))
		return
	var/family = domestic_family()
	for (var/mob/living/simple_animal/A in loc)
		if (A != src && A.wild && A.stat != DEAD && A.domestic_family() == family)
			make_wild()
			return

// Stored trust is the balance at the last counted feeding. Calculate the
// elapsed decay without rewriting that timestamp or charging it twice.
/mob/living/simple_animal/proc/tame_current_trust(now = trap_now_minutes())
	var/last = trap_minutes(tame_fed)
	if (!wild || !tame_trust || !last || now <= last)
		return tame_trust
	var/days = round((now - last) / TAME_FADE_AFTER)
	return max(0, tame_trust - days)

// Called after a hand feeding went through. Returns TRUE when it counted.
/mob/living/simple_animal/proc/tame_feeding(mob/user, now = trap_now_minutes())
	if (!wild || stat == DEAD)
		return FALSE
	var/last = trap_minutes(tame_fed)
	if (last && now - last < TAME_FEED_GAP)
		to_chat(user, SPAN_NOTICE("\The [src] eats, but it will take more time, not more food, to trust you."))
		return FALSE
	tame_trust = tame_current_trust(now) + 1
	tame_fed = trap_minutes_text(now)
	if (tame_trust >= TAME_FEEDINGS)
		wild = FALSE
		tame_trust = 0
		tame_fed = null
		user.visible_message(SPAN_NOTICE("\The [src] has grown used to people. It is tame now."), SPAN_NOTICE("\The [src] trusts you now. It is tame: [tame_done_text()]"))
		if (ishuman(user))
			accolade_meet_mob(user, "herder")
	else
		to_chat(user, SPAN_NOTICE("\The [src] is getting used to you ([tame_trust] of [TAME_FEEDINGS]). Feed it again later."))
	return TRUE

/mob/living/simple_animal/proc/tame_done_text()
	return "you can lead, milk, shear and work it."

/mob/living/simple_animal/proc/tame_state_text()
	if (!domesticable)
		return null
	if (!wild)
		return "It is tame."
	var/trust = tame_current_trust()
	if (!trust)
		return "It is wild and wary of people. Feed it by hand, again and again, to tame it."
	return "It is wild, but getting used to people ([trust] of [TAME_FEEDINGS] feedings)."

/mob/living/simple_animal/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	var/text = tame_state_text()
	if (text)
		to_chat(user, text)

/mob/living/simple_animal/feed(obj/item/O, mob/user)
	var/before = istype(O, /obj/item/stack) ? O:amount : 0
	..()
	if (!wild || !user)
		return
	if (QDELETED(O) || (istype(O, /obj/item/stack) && O:amount < before))
		tame_feeding(user)

// What a wild animal won't let anyone do to it.
/proc/domestication_refused(obj/item/O)
	return istype(O, /obj/item/weapon/leash) || istype(O, /obj/item/weapon/shears) || istype(O, /obj/item/animal_tack) || istype(O, /obj/item/weapon/plough) || istype(O, /obj/item/weapon/reagent_containers/glass)

/mob/living/simple_animal/proc/domestication_intercept(obj/item/O, mob/user)
	if (!wild || stat == DEAD || !domestication_refused(O))
		return FALSE
	to_chat(user, SPAN_WARNING("\The [src] shies away from you. It is wild: tame it first by feeding it by hand."))
	return TRUE

/mob/living/simple_animal/attackby(obj/item/O, mob/user)
	if (domestication_intercept(O, user))
		return
	return ..()

/mob/living/simple_animal/cattle/attackby(obj/item/O, mob/user)
	if (domestication_intercept(O, user))
		return
	return ..()

/mob/living/simple_animal/cattle/cow/attackby(obj/item/O, mob/user)
	if (domestication_intercept(O, user))
		return
	return ..()

/mob/living/simple_animal/pig_gilt/attackby(obj/item/O, mob/user)
	if (domestication_intercept(O, user))
		return
	return ..()

/mob/living/simple_animal/goat/female/attackby(obj/item/O, mob/user)
	if (domestication_intercept(O, user))
		return
	return ..()

/mob/living/simple_animal/sheep/attackby(obj/item/O, mob/user)
	if (domestication_intercept(O, user))
		return
	return ..()

/mob/living/simple_animal/sheep/female/attackby(obj/item/O, mob/user)
	if (domestication_intercept(O, user))
		return
	return ..()
