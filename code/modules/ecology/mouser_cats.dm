// Cats against mice (docs/mouse-nests.md).
//
// Wildcats live wild in temperate, semiarid and savanna land (ecology table).
// They keep their distance from people unless someone holds meat or fish.
// Feed one by hand often enough and it becomes a tame cat (the shared
// domestication rules, domestication.dm). Tame cats raise kittens slowly, up to
// MOUSER_CAT_CAP cats in the world. Every cat within MOUSER_RANGE of a mouse
// nest takes a mouse each settle step and stops that nest spreading; a dog
// counts for half a cat.

#define MOUSER_CAT_CAP 12
#define MOUSER_RANGE 7
#define MOUSER_LITTER_GAP 120 // real minutes between litters for one cat
#define MOUSER_LITTER_CHANCE 1 // percent per Life tick once the gap has passed
#define MOUSER_SHY_RANGE 3

var/global/list/mouser_cat_list = list()

/mob/living/simple_animal/pet/cat
	domesticable = TRUE
	var/last_litter = null // text minutes

/mob/living/simple_animal/pet/cat/domestic_family()
	return /mob/living/simple_animal/pet/cat

/mob/living/simple_animal/pet/cat/New()
	..()
	mouser_cat_list |= src

/mob/living/simple_animal/pet/cat/Destroy()
	mouser_cat_list -= src
	return ..()

/mob/living/simple_animal/pet/cat/wild
	name = "wildcat"
	real_name = "wildcat"
	desc = "A lean, striped wild cat. It hunts mice and keeps well away from people."
	icon_state = "cat3"
	item_state = "cat3"
	icon_living = "cat3"
	icon_dead = "cat3_dead"

/mob/living/simple_animal/pet/cat/wild/New()
	..()
	make_wild()

/mob/living/simple_animal/pet/cat/tame_done_text()
	return "It will stay around your home and hunt the mice."

/mob/living/simple_animal/pet/cat/tame_feeding(mob/user, now = trap_now_minutes())
	. = ..()
	if (!wild && name == "wildcat")
		name = "cat"
		real_name = "cat"
		desc = "A striped cat that has made its home among people. It keeps the mice down."

/proc/mouser_food(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawfish) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/fishfillet) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/driedfish)

// Cats take meat and fish by hand; wild ones count it toward taming.
/mob/living/simple_animal/pet/cat/attackby(obj/item/O, mob/user)
	if (stat == CONSCIOUS && mouser_food(O))
		if (simplehunger >= 900 && !wild)
			to_chat(user, SPAN_NOTICE("\The [src] sniffs \the [O] and turns away; it is not hungry."))
			return
		user.visible_message(SPAN_NOTICE("[user] feeds [src] \the [O]."))
		simplehunger = min(1000, simplehunger + 400)
		adjustBruteLoss(-4)
		qdel(O)
		if (wild)
			npc_set_flee_target(null)
			tame_feeding(user)
		return
	return ..()

/mob/living/simple_animal/pet/cat/proc/mouser_holds_food(mob/living/human/H)
	return mouser_food(H.get_active_hand()) || mouser_food(H.get_inactive_hand())

/mob/living/simple_animal/pet/cat/Life()
	..()
	if (stat != CONSCIOUS || client)
		return
	if (wild)
		if (!flee_target)
			for (var/mob/living/human/H in range(MOUSER_SHY_RANGE, src))
				if (H.stat != DEAD && !mouser_holds_food(H))
					set_flee_target(H)
					break
		return
	mouser_try_litter()

/mob/living/simple_animal/pet/cat/proc/mouser_try_litter(now = trap_now_minutes())
	if (istype(src, /mob/living/simple_animal/pet/cat/kitten) || mouser_cat_list.len >= MOUSER_CAT_CAP || !isturf(loc))
		return null
	var/last = trap_minutes(last_litter)
	if (last && now - last < MOUSER_LITTER_GAP)
		return null
	if (!prob(MOUSER_LITTER_CHANCE))
		return null
	for (var/mob/living/simple_animal/pet/cat/mate in range(3, src))
		if (mate == src || mate.wild || mate.stat != CONSCIOUS || istype(mate, /mob/living/simple_animal/pet/cat/kitten))
			continue
		var/mate_last = trap_minutes(mate.last_litter)
		if (mate_last && now - mate_last < MOUSER_LITTER_GAP)
			continue
		last_litter = trap_minutes_text(now)
		mate.last_litter = last_litter
		visible_message(SPAN_NOTICE("A kitten tumbles out from beside \the [src]."))
		return new /mob/living/simple_animal/pet/cat/kitten(loc)
	return null

// Mice each cat (or half a dog) near a nest takes per settle step.
/obj/structure/mouse_nest/proc/predator_pressure()
	. = 0
	for (var/mob/living/simple_animal/pet/P in range(MOUSER_RANGE, src))
		if (P.stat != CONSCIOUS)
			continue
		if (istype(P, /mob/living/simple_animal/pet/cat))
			. += 1
		else if (istype(P, /mob/living/simple_animal/pet/dog))
			. += 0.5
