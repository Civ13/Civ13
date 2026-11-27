// Small Stone Age additions. See docs/stone-age-extras.md.
// - Bone flute and frame drum: play them to lift the mood of people nearby.
// - Flint sickle: knapped sickle teeth lashed to a branch. It cuts like a knife
//   and reaps the ripe crops of the same kind next to the one you harvest.
// - Bison herds: when one bison cow is hurt, the cows around it bolt together.

#define EXTRAS_ICON 'icons/obj/stone_age_extras.dmi'
#define MUSIC_RANGE 7
#define MUSIC_MOOD 3
#define MUSIC_MOOD_GAP 1200 // a listener is cheered at most once in two minutes
#define SICKLE_EXTRA_REAP 2
#define HERD_RANGE 7

// ---- Instruments ----

/mob/living/human/var/tmp/next_music_mood = 0

/mob/living/human/persistence_runtime_var(key)
	return key == "next_music_mood" || ..()

/obj/item/stone_age_instrument/persistence_runtime_var(key)
	return key == "next_play" || ..()

/obj/item/stone_age_instrument
	name = "instrument"
	icon = EXTRAS_ICON
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3
	var/play_verb = "plays"
	var/list/tunes = list("a tune")
	var/next_play = 0

/obj/item/stone_age_instrument/attack_self(mob/living/user)
	if (!ishuman(user) || user.stat || user.restrained() || world.time < next_play)
		return
	next_play = world.time + 5 SECONDS
	user.visible_message(SPAN_NOTICE("[user] [play_verb] [pick(tunes)] on \the [src]."), SPAN_NOTICE("You play [pick(tunes)] on \the [src]."))
	cheer_listeners(user)

/obj/item/stone_age_instrument/proc/cheer_listeners(mob/living/human/player)
	var/cheered = 0
	for (var/mob/living/human/H in hearers(MUSIC_RANGE, get_turf(player)))
		if (H.stat != CONSCIOUS || world.time < H.next_music_mood)
			continue
		H.next_music_mood = world.time + MUSIC_MOOD_GAP
		H.adjust_mood(MUSIC_MOOD, "music")
		cheered++
	return cheered

/obj/item/stone_age_instrument/bone_flute
	name = "bone flute"
	desc = "A hollow bird bone with finger holes. Use it in hand to play."
	icon_state = "bone_flute"
	play_verb = "plays"
	tunes = list("a high, breathy tune", "a slow, haunting tune", "a quick, bright tune", "a soft lullaby")

/obj/item/stone_age_instrument/frame_drum
	name = "frame drum"
	desc = "A rawhide drumhead laced over a wooden hoop. Use it in hand to play."
	icon_state = "frame_drum"
	w_class = ITEM_SIZE_NORMAL
	play_verb = "beats out"
	tunes = list("a steady rhythm", "a rolling beat", "a dancing rhythm", "a slow, heavy beat")

// ---- Flint sickle ----

/obj/item/weapon/flint_sickle_teeth
	name = "flint sickle teeth"
	desc = "A row of small knapped flint teeth. Lash them to a branch to make a sickle."
	icon = 'icons/obj/flint_mining.dmi'
	icon_state = "flint_arrowheads"
	w_class = ITEM_SIZE_TINY
	value = 2

/obj/item/weapon/branch/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!istype(W, /obj/item/weapon/flint_sickle_teeth) || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You start setting \the [W] into \the [src]..."))
	if (!do_after(H, 50, src) || QDELETED(W) || QDELETED(src) || W.loc != H || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
		return
	var/turf/T = get_turf(src)
	qdel(W)
	qdel(src)
	var/obj/item/weapon/material/kitchen/utensil/knife/flint_sickle/S = new(T)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You make \a [S]."))

/obj/item/weapon/material/kitchen/utensil/knife/flint_sickle
	name = "flint sickle"
	desc = "A curved wooden haft set with flint teeth. It cuts like a knife, and reaps the ripe crops of the same kind beside the one you harvest."
	icon = EXTRAS_ICON
	icon_state = "flint_sickle"
	item_state = "knife"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	default_material = "flint"
	applies_material_colour = FALSE
	value = 4

/obj/item/weapon/material/kitchen/utensil/knife/flint_sickle/set_material(new_material)
	..()
	name = initial(name)

var/global/sickle_reaping = FALSE

/obj/structure/farming/plant/proc/sickle_neighbours()
	. = list()
	for (var/obj/structure/farming/plant/P in orange(1, src))
		if (length(.) >= SICKLE_EXTRA_REAP)
			break
		if (P.type == type && P.plant == plant && P.readyHarvest() && P.Adjacent(src))
			. += P

/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)
	var/list/extra = null
	if (!sickle_reaping && istype(W, /obj/item/weapon/material/kitchen/utensil/knife/flint_sickle) && stage >= readyStageMin && readyHarvest())
		extra = sickle_neighbours()
	. = ..()
	if (!length(extra))
		return
	sickle_reaping = TRUE
	for (var/obj/structure/farming/plant/P in extra)
		if (!QDELETED(P) && P.readyHarvest())
			P.attackby(W, user)
	sickle_reaping = FALSE

// ---- Bison herds ----

/mob/living/simple_animal/bison/var/tmp/next_herd_alarm = 0

/mob/living/simple_animal/bison/persistence_runtime_var(key)
	return key == "next_herd_alarm" || ..()

/mob/living/simple_animal/bison/proc/herd_alarm()
	if (world.time < next_herd_alarm)
		return 0
	next_herd_alarm = world.time + 5 SECONDS
	var/bolted = 0
	for (var/mob/living/simple_animal/bison/B in range(HERD_RANGE, src))
		if (B == src || B.stat != CONSCIOUS || B.client)
			continue
		B.next_herd_alarm = world.time + 5 SECONDS
		B.do_behaviour("scared")
		bolted++
	if (bolted)
		visible_message(SPAN_WARNING("The bison herd bolts!"))
	return bolted

/mob/living/simple_animal/bison/adjustBruteLoss(damage)
	var/before = health
	. = ..()
	if (damage > 0 && stat == CONSCIOUS && health < before)
		herd_alarm()

#undef MUSIC_RANGE
#undef MUSIC_MOOD
#undef MUSIC_MOOD_GAP
#undef SICKLE_EXTRA_REAP
#undef HERD_RANGE
