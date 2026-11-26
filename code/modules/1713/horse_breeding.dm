// Horses: breaking in, breeding and shoeing (docs/horse-breeding.md).
//
// On persistence maps, horses born in the wild are wild like the other herd
// animals (domestication.dm): they won't take a saddle, tack or a leash, and
// throw anyone who climbs on. Every feeding by hand and every ride a wild
// horse throws its rider from counts toward breaking it in.
//
// A tame mare beside a tame stallion now and then carries a foal, born an
// hour later (real time). A foal takes after its parents' speed and stamina
// and grows up in two hours; it can't be ridden until then.
//
// Speed sets how fast a horse is ridden (ride_delay); stamina how hungry
// hauling makes it. An unshod horse goes slower on stone roads and rocky
// ground; iron shoes keep its pace there until they wear out.

#define HORSE_GESTATION 60
#define HORSE_GROW_TIME 120
#define HORSE_HERD_CAP 6
#define HORSE_TRAIT_MIN 20
#define HORSE_TRAIT_MAX 80
#define HORSE_UNSHOD_ROUGH 1.25
#define HORSE_SHOE_LIFE 2000
#define HORSE_BREAK_TIME 30

/mob/living/simple_animal/horse
	domesticable = TRUE
	var/female = FALSE
	var/horse_speed = 0
	var/stamina = 0
	var/foal = FALSE
	var/grown_at = null // text minutes
	var/foal_due = null // text minutes
	var/sire_type = null
	var/shod = FALSE
	var/shoe_wear = 0
	var/adult_state = null

// Breed stats and sex are rolled once, at first spawn. Under a load the saved
// values arrive after the constructor, and a horse saved as a stallion (female
// is omitted at its FALSE default) must not be re-rolled into a mare.
/mob/living/simple_animal/horse/New()
	..()
	if (!restoring)
		horse_apply_age()

/mob/living/simple_animal/horse/on_runtime_spawn()
	..()
	if (!horse_speed)
		horse_speed = rand(35, 65)
	if (!stamina)
		stamina = rand(35, 65)
	if (isnull(adult_state))
		adult_state = initial(icon_living)
		female = prob(50)
	horse_apply_age()

// Only persistence worlds have wild horses; battle maps keep theirs saddled.
/mob/living/simple_animal/horse/make_wild()
	if (!map || !map.persistence)
		return FALSE
	return ..()

/mob/living/simple_animal/horse/domestic_family()
	return /mob/living/simple_animal/horse

// Sprites and riding for a foal or a grown horse.
/mob/living/simple_animal/horse/proc/horse_apply_age()
	var/base = adult_state ? adult_state : initial(icon_living)
	if (foal)
		var/young = replacetext(base, "horse", "foal")
		icon_living = young
		icon_dead = "[young]_dead"
		can_ride = FALSE
		mob_size = MOB_MEDIUM
		meat_amount = 2
	else
		icon_living = base
		icon_dead = "[base]_dead"
		can_ride = TRUE
		mob_size = MOB_LARGE
		meat_amount = initial(meat_amount)
	icon_riding = "[icon_living]_riding"
	cover_overlay = image("icon" = icon, "icon_state" = icon_riding, "layer" = 4.15)
	if (stat != DEAD)
		icon_state = icon_living
	else
		icon_state = icon_dead

/mob/living/simple_animal/horse/Life()
	. = ..()
	if (stat != CONSCIOUS || !prob(5))
		return
	horse_tick()

// Growing up and breeding, a few times a minute.
/mob/living/simple_animal/horse/proc/horse_tick(now = trap_now_minutes())
	if (foal)
		var/grown = trap_minutes(grown_at)
		if (!grown || now >= grown)
			foal = FALSE
			grown_at = null
			horse_apply_age()
			visible_message(SPAN_NOTICE("\The [src] has grown into a full-sized horse."))
		return
	if (!female || wild)
		return
	var/due = trap_minutes(foal_due)
	if (due)
		if (now >= due)
			give_birth()
		return
	var/mob/living/simple_animal/horse/sire = horse_sire()
	if (sire && horse_herd_room())
		foal_due = trap_minutes_text(now + HORSE_GESTATION)
		sire_type = sire.type
		foal_sire_speed = sire.horse_speed
		foal_sire_stamina = sire.stamina

/mob/living/simple_animal/horse/var/foal_sire_speed = 50
/mob/living/simple_animal/horse/var/foal_sire_stamina = 50

// A tame grown stallion standing beside her.
/mob/living/simple_animal/horse/proc/horse_sire()
	for (var/mob/living/simple_animal/horse/H in range(1, src))
		if (H != src && !H.female && !H.foal && !H.wild && H.stat == CONSCIOUS)
			return H
	return null

/mob/living/simple_animal/horse/proc/horse_herd_room()
	var/count = 0
	for (var/mob/living/simple_animal/horse/H in range(7, src))
		if (H.stat != DEAD)
			count++
	return count <= HORSE_HERD_CAP && !animal_spot_crowded(src, 0)

/proc/horse_inherit(a, b)
	return clamp(round((a + b) / 2) + rand(-5, 5), HORSE_TRAIT_MIN, HORSE_TRAIT_MAX)

/mob/living/simple_animal/horse/proc/give_birth()
	var/path = sire_type && prob(50) ? sire_type : type
	var/mob/living/simple_animal/horse/F = new path(loc)
	F.foal = TRUE
	F.wild = FALSE
	F.grown_at = trap_minutes_text(trap_now_minutes() + HORSE_GROW_TIME)
	F.horse_speed = horse_inherit(horse_speed, foal_sire_speed)
	F.stamina = horse_inherit(stamina, foal_sire_stamina)
	F.horse_apply_age()
	foal_due = null
	sire_type = null
	visible_message(SPAN_NOTICE("\The [src] has given birth to a foal!"))
	return F

// ---- breaking in -----------------------------------------------------------------

/mob/living/simple_animal/horse/MouseDrop_T(mob/living/M, mob/living/human/user)
	if (wild && stat == CONSCIOUS && M == user && ishuman(user) && !user.lying)
		break_in(user)
		return
	return ..()

// One go at riding a wild horse: it always throws you, but it learns.
/mob/living/simple_animal/horse/proc/break_in(mob/living/human/user)
	user.visible_message(SPAN_WARNING("[user] grabs \the [src]'s mane and swings onto its bare back!"), SPAN_WARNING("You swing onto \the [src]'s bare back. Hold on!"))
	if (!do_after(user, HORSE_BREAK_TIME, src) || QDELETED(src) || stat != CONSCIOUS)
		return FALSE
	var/turf/T = get_step(src, pick(cardinal))
	if (!T || T.density)
		T = get_turf(src)
	user.forceMove(T)
	user.Weaken(3)
	user.adjustBruteLoss(rand(2, 5))
	user.visible_message(SPAN_DANGER("\The [src] bucks and throws [user]!"), SPAN_DANGER("\The [src] bucks and throws you off!"))
	tame_feeding(user)
	return TRUE

// ---- riding pace and shoes --------------------------------------------------------

// Deciseconds a ridden step takes, before a hitched cart.
/mob/living/simple_animal/proc/ride_delay()
	return 0.5

/mob/living/simple_animal/horse/ride_delay()
	. = 0.5 * (1.2 - horse_speed / 250)
	if (horse_rough_ground(get_turf(src)))
		if (shod)
			shoe_wear++
			if (shoe_wear >= HORSE_SHOE_LIFE)
				throw_shoes()
		else
			. *= HORSE_UNSHOD_ROUGH

/proc/horse_rough_ground(turf/T)
	if (!T)
		return FALSE
	if (istype(T, /turf/floor/rocky) || istype(T, /turf/floor/gravel) || istype(T, /turf/floor/mining) || istype(T, /turf/floor/plating) || istype(T, /turf/floor/dirt/underground))
		return TRUE
	for (var/obj/covers/C in T)
		if (istype(C, /obj/covers/roads/cobble) || istype(C, /obj/covers/roads/roman) || istype(C, /obj/covers/roads/sandstone) || istype(C, /obj/covers/roads/modern) || istype(C, /obj/covers/road))
			return TRUE
	return FALSE

/mob/living/simple_animal/horse/proc/throw_shoes()
	shod = FALSE
	shoe_wear = 0
	new /obj/item/horseshoes/worn(get_turf(src))
	visible_message(SPAN_NOTICE("\The [src] casts its worn-out shoes."))

// Stamina: a hardier horse gets less hungry hauling.
/mob/living/simple_animal/horse/animal_draft_hunger_cost()
	return ..() * (1.5 - stamina / 100)

/obj/item/horseshoes
	name = "horseshoes"
	desc = "A set of four iron horseshoes and their nails. Use them on a tame grown horse to shoe it: shod, it keeps its pace on stone roads and rocky ground."
	icon = 'icons/obj/horseshoes.dmi'
	icon_state = "horseshoe"
	w_class = ITEM_SIZE_SMALL
	force = 3

/obj/item/horseshoes/worn
	name = "worn horseshoes"
	desc = "Horseshoes worn thin on stone. They are only good for scrap now."
	icon_state = "horseshoe_worn"

/obj/item/horseshoes/proc/shoe(mob/living/simple_animal/horse/H, mob/user)
	if (istype(src, /obj/item/horseshoes/worn))
		to_chat(user, SPAN_WARNING("These shoes are worn out."))
		return FALSE
	if (H.stat == DEAD || H.wild || H.foal)
		to_chat(user, SPAN_WARNING("Only a tame, grown horse will stand to be shod."))
		return FALSE
	if (H.shod)
		to_chat(user, SPAN_WARNING("\The [H] is already shod."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts to shoe \the [H]."), SPAN_NOTICE("You lift each hoof in turn and nail on a shoe."))
	if (!do_after(user, 50, H) || QDELETED(src) || QDELETED(H) || H.stat == DEAD || H.shod)
		return FALSE
	H.shod = TRUE
	H.shoe_wear = 0
	user.drop_from_inventory(src)
	qdel(src)
	to_chat(user, SPAN_NOTICE("\The [H] is shod."))
	return TRUE

/mob/living/simple_animal/horse/attackby(obj/item/O, mob/user)
	if (istype(O, /obj/item/horseshoes))
		var/obj/item/horseshoes/S = O
		S.shoe(src, user)
		return
	return ..()

/mob/living/simple_animal/horse/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	if (get_dist(src, user) > 3)
		return
	to_chat(user, "It is \a [foal ? "foal" : (female ? "mare" : "stallion")][shod ? ", shod" : ""].")
	if (!foal && !wild)
		to_chat(user, horse_judgement())
	if (female && foal_due)
		to_chat(user, SPAN_NOTICE("She is in foal."))

// A rider's eye for a horse.
/mob/living/simple_animal/horse/proc/horse_judgement()
	var/pace = horse_speed >= 60 ? "fleet" : (horse_speed >= 45 ? "steady" : "slow")
	var/wind = stamina >= 60 ? "tireless" : (stamina >= 45 ? "sound" : "soon winded")
	return "It looks [pace] and [wind]."

#undef HORSE_GESTATION
#undef HORSE_GROW_TIME
#undef HORSE_HERD_CAP
#undef HORSE_TRAIT_MIN
#undef HORSE_TRAIT_MAX
#undef HORSE_UNSHOD_ROUGH
#undef HORSE_SHOE_LIFE
#undef HORSE_BREAK_TIME
