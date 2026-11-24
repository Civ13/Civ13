// Trap lines: snares, deadfalls, covered pit traps and fish weirs.
// See docs/stone-age-traps.md.
//
// Snares, deadfalls and weirs never wait for a wild animal to walk in. Each
// one rolls a catch for every interval that passed since it was last looked
// at, so a trap costs nothing while nobody is near it and nothing has to run
// on a timer. Times are whole real minutes since 2000, kept as text because a
// JSON number that large loses its last digits in the save.
// Covered pits are the exception: they catch whatever walks onto them.

#define STONE_AGE_TRAP_ICON 'icons/obj/stone_age_traps.dmi'
#define TRAP_SNARE_INTERVAL 10 // minutes between catch rolls
#define TRAP_WEIR_INTERVAL 15
#define TRAP_MAX_ROLLS 72 // at most 12 hours of snare rolls per look
#define TRAP_SCAVENGED_AFTER 1440 // a catch left a day is eaten by scavengers
#define TRAP_BASE_CHANCE 10
#define TRAP_ANIMAL_BONUS 4 // per living wild animal within TRAP_LURE_RANGE
#define TRAP_LURE_RANGE 7
#define TRAP_MAX_CHANCE 35
#define WEIR_CAP 4
#define WEIR_CHANCE 35
#define PIT_DIG_TIME_SHOVEL 150
#define PIT_DIG_TIME_STICK 250
#define PIT_CLIMB_TIME 100
#define PIT_HELP_TIME 50
#define PIT_FALL_DAMAGE 5
#define PIT_STAKE_DAMAGE 20
#define PIT_NOTICE_CHANCE 50 // walking, not running, feels the cover give
#define PIT_ANIMAL_HOLD (15 MINUTES)

/proc/trap_now_minutes()
	return round(world.realtime / 600)

/proc/trap_minutes_text(value)
	return num2text(round(value), 12)

/proc/trap_minutes(text_value)
	var/value = istext(text_value) ? text2num(text_value) : text_value
	return isnum(value) ? value : 0

// Natural outdoor ground a snare, deadfall or pit can be set on.
/proc/trap_ground_ok(turf/T)
	if (!istype(T, /turf/floor) || T.density)
		return FALSE
	if (!(istype(T, /turf/floor/grass) || istype(T, /turf/floor/dirt) || istype(T, /turf/floor/winter) || istype(T, /turf/floor/beach/sand)))
		return FALSE
	var/area/A = get_area(T)
	return A && A.location == AREA_OUTSIDE

// Shallow fresh running water: not deep, salty or frozen.
/proc/weir_water_ok(turf/T)
	if (!istype(T, /turf/floor/beach/water) || T.density)
		return FALSE
	var/turf/floor/beach/water/W = T
	if (W.salty || istype(W, /turf/floor/beach/water/deep) || istype(W, /turf/floor/beach/water/ice) || istype(W, /turf/floor/beach/water/flooded))
		return FALSE
	var/area/A = get_area(T)
	return A && A.location == AREA_OUTSIDE

/proc/trap_cold_season(atom/A)
	var/area/AR = get_area(A)
	return AR && AR.location == AREA_OUTSIDE && season == SEASON_WINTER

/proc/trap_structure_on(turf/T)
	return locate(/obj/structure/stone_age_trap) in T

// ---------------------------------------------------------------- kits
// The carried trap. Use it on the ground next to you to set it.
/obj/item/weapon/trap_kit
	name = "trap kit"
	icon = STONE_AGE_TRAP_ICON
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	var/structure_type
	var/set_time = 40
	var/needs_water = FALSE

/obj/item/weapon/trap_kit/proc/target_ok(turf/T)
	return needs_water ? weir_water_ok(T) : trap_ground_ok(T)

/obj/item/weapon/trap_kit/proc/refuse_text()
	return needs_water ? "It has to stand in shallow fresh water, outdoors." : "It has to be set on open ground outdoors: grass, dirt, sand or snow."

/obj/item/weapon/trap_kit/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !ishuman(user))
		return ..()
	var/turf/T = get_turf(target)
	if (!T || !user.Adjacent(T))
		return ..()
	if (!target_ok(T))
		to_chat(user, SPAN_WARNING(refuse_text()))
		return TRUE
	if (trap_structure_on(T))
		to_chat(user, SPAN_WARNING("There is already a trap there."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts setting \a [src]."), SPAN_NOTICE("You start setting \the [src]."))
	if (!do_after(user, set_time, T) || QDELETED(src) || loc != user || trap_structure_on(T) || !target_ok(T))
		return TRUE
	var/obj/structure/stone_age_trap/S = new structure_type(T)
	S.setter_name = user.real_name
	S.arm()
	user.drop_from_inventory(src)
	qdel(src)
	to_chat(user, SPAN_NOTICE("You set \the [S]."))
	return TRUE

/obj/item/weapon/trap_kit/snare
	name = "snare"
	desc = "A twine noose on a bent stick. Set it on open ground; small game blunders into it while you are away."
	icon_state = "snare"
	w_class = ITEM_SIZE_SMALL
	structure_type = /obj/structure/stone_age_trap/snare
	value = 3

/obj/item/weapon/trap_kit/deadfall
	name = "deadfall trap"
	desc = "A flat stone and a set of carved trigger sticks. Prop the stone up on open ground and it falls on whatever takes the bait."
	icon_state = "deadfall"
	structure_type = /obj/structure/stone_age_trap/deadfall
	value = 4

/obj/item/weapon/trap_kit/weir
	name = "weir stakes"
	desc = "A bundle of stakes and woven wicker. Set it in shallow fresh water and fish swim in and can't find the way out."
	icon_state = "weir_stakes"
	w_class = ITEM_SIZE_LARGE
	structure_type = /obj/structure/stone_age_trap/weir
	set_time = 80
	needs_water = TRUE
	value = 6

// ---------------------------------------------------------------- set traps
/obj/structure/stone_age_trap
	name = "trap"
	icon = STONE_AGE_TRAP_ICON
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = TURF_LAYER + 0.2
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/kit_type
	var/setter_name
	var/armed = FALSE
	var/last_roll // text minutes
	var/caught_at // text minutes, set once something is caught
	var/catch_type
	var/roll_interval = TRAP_SNARE_INTERVAL
	var/base_state

/obj/structure/stone_age_trap/proc/arm()
	armed = TRUE
	catch_type = null
	caught_at = null
	last_roll = trap_minutes_text(trap_now_minutes())
	update_icon()

/obj/structure/stone_age_trap/update_icon()
	if (catch_type || !armed)
		icon_state = "[base_state]_sprung"
	else
		icon_state = "[base_state]_set"

// Chance, per roll, that something is caught: more wild animals close by,
// more catches; winter halves it.
/obj/structure/stone_age_trap/proc/catch_chance()
	var/animals = 0
	for (var/mob/living/simple_animal/A in range(TRAP_LURE_RANGE, src))
		if (A.stat != DEAD)
			animals++
	var/chance = min(TRAP_MAX_CHANCE, TRAP_BASE_CHANCE + animals * TRAP_ANIMAL_BONUS)
	if (trap_cold_season(src))
		chance = round(chance / 2)
	return chance

/obj/structure/stone_age_trap/proc/pick_catch()
	return /mob/living/simple_animal/rabbit

// Rolls every interval since the last look. Returns the number of rolls made.
/obj/structure/stone_age_trap/proc/settle(now = trap_now_minutes())
	if (!armed || catch_type)
		return 0
	var/last = trap_minutes(last_roll)
	if (!last || last > now)
		last_roll = trap_minutes_text(now)
		return 0
	var/steps = round((now - last) / roll_interval)
	if (steps <= 0)
		return 0
	var/rolls = min(steps, TRAP_MAX_ROLLS)
	var/chance = catch_chance()
	for (var/i = 1 to rolls)
		if (prob(chance))
			catch_type = pick_catch()
			caught_at = trap_minutes_text(last + i * roll_interval)
			armed = FALSE
			break
	last_roll = trap_minutes_text(last + steps * roll_interval)
	update_icon()
	return rolls

/obj/structure/stone_age_trap/examine(mob/user, distance = -1)
	..()
	trap_status(user)

/obj/structure/stone_age_trap/proc/trap_status(mob/user)
	settle()
	if (catch_type)
		var/atom/A = catch_type
		to_chat(user, SPAN_NOTICE("Something is caught in it: \a [initial(A.name)]."))
	else if (armed)
		to_chat(user, "It is set.[setter_name ? " [setter_name] set it." : ""]")
	else
		to_chat(user, "It has been sprung. Use it with an empty hand to set it again.")

/obj/structure/stone_age_trap/attack_hand(mob/user)
	if (!ishuman(user) || !user.Adjacent(src))
		return ..()
	settle()
	if (catch_type)
		take_catch(user)
		return TRUE
	if (!armed)
		user.visible_message(SPAN_NOTICE("[user] starts resetting \the [src]."), SPAN_NOTICE("You start resetting \the [src]."))
		if (do_after(user, 20, src) && !armed && !catch_type)
			arm()
			to_chat(user, SPAN_NOTICE("You set \the [src] again."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts taking up \the [src]."), SPAN_NOTICE("You start taking up \the [src]."))
	if (!do_after(user, 30, src) || QDELETED(src))
		return TRUE
	settle()
	if (catch_type || !armed)
		to_chat(user, SPAN_WARNING("The trap has sprung. Check it before taking it up."))
		return TRUE
	var/obj/item/K = new kit_type(get_turf(src))
	user.put_in_hands(K)
	qdel(src)
	return TRUE

/obj/structure/stone_age_trap/proc/take_catch(mob/user)
	var/caught = trap_minutes(caught_at)
	var/path = catch_type
	catch_type = null
	caught_at = null
	update_icon()
	if (caught && trap_now_minutes() - caught > TRAP_SCAVENGED_AFTER)
		to_chat(user, SPAN_WARNING("Whatever was caught here has been torn loose and eaten by scavengers. Check your traps more often."))
		return FALSE
	var/mob/living/simple_animal/A = new path(get_turf(src))
	A.death()
	user.visible_message(SPAN_NOTICE("[user] takes \a [A] out of \the [src]."), SPAN_NOTICE("You take \the [A] out of \the [src]. Use the trap again to reset it."))
	note_field_work(user, "forage")
	return TRUE

/obj/structure/stone_age_trap/snare
	name = "snare"
	desc = "A twine noose propped open on the ground."
	icon_state = "snare_set"
	base_state = "snare"
	kit_type = /obj/item/weapon/trap_kit/snare

/obj/structure/stone_age_trap/snare/pick_catch()
	return prob(75) ? /mob/living/simple_animal/rabbit : /mob/living/simple_animal/hostile/fox

/obj/structure/stone_age_trap/deadfall
	name = "deadfall trap"
	desc = "A heavy flat stone propped on a figure-four of sticks."
	icon_state = "deadfall_set"
	base_state = "deadfall"
	kit_type = /obj/item/weapon/trap_kit/deadfall
	flammable = FALSE

/obj/structure/stone_age_trap/deadfall/pick_catch()
	var/roll = rand(1, 100)
	if (roll <= 50)
		return /mob/living/simple_animal/rabbit
	if (roll <= 85)
		return /mob/living/simple_animal/hostile/fox
	return /mob/living/simple_animal/boar_gilt

// ---------------------------------------------------------------- fish weir
// Fish collect in the weir over time, up to WEIR_CAP. Unlike a fish pen it
// needs no stocking or feeding, but it never holds many fish. Every fish comes
// out of the fishing ground the weir stands in (fishing_grounds.dm), so a weir
// in a fished-out stretch stays empty until the fish come back.
/obj/structure/stone_age_trap/weir
	name = "fish weir"
	desc = "A fence of stakes and woven wicker standing in the river. Fish swim in through the mouth and can't find the way out."
	icon_state = "fish_weir"
	base_state = "fish_weir"
	kit_type = /obj/item/weapon/trap_kit/weir
	roll_interval = TRAP_WEIR_INTERVAL
	layer = OBJ_LAYER
	var/fish = 0

/obj/structure/stone_age_trap/weir/update_icon()
	icon_state = fish > 0 ? "fish_weir_full" : "fish_weir"

/obj/structure/stone_age_trap/weir/settle(now = trap_now_minutes())
	if (!armed)
		return 0
	var/last = trap_minutes(last_roll)
	if (!last || last > now)
		last_roll = trap_minutes_text(now)
		return 0
	var/steps = round((now - last) / roll_interval)
	if (steps <= 0)
		return 0
	var/rolls = min(steps, TRAP_MAX_ROLLS)
	var/chance = weir_water_ok(loc) ? (trap_cold_season(src) ? round(WEIR_CHANCE / 2) : WEIR_CHANCE) : 0
	for (var/i = 1 to rolls)
		if (fish >= WEIR_CAP)
			break
		if (prob(chance))
			if (!fish_ground_trap_catch(loc))
				break // this stretch has no more fish to give for now
			fish++
	last_roll = trap_minutes_text(last + steps * roll_interval)
	update_icon()
	return rolls

/obj/structure/stone_age_trap/weir/trap_status(mob/user)
	settle()
	if (!weir_water_ok(loc))
		to_chat(user, SPAN_WARNING("It is not standing in shallow fresh water, so it catches nothing."))
	to_chat(user, fish ? SPAN_NOTICE("[fish] fish [fish == 1 ? "is" : "are"] trapped in it.") : "It is empty.")
	if (!fish && weir_water_ok(loc))
		var/datum/fishing_ground/G = fishing_ground_at(loc, FALSE)
		if (G && G.available() < 1)
			to_chat(user, SPAN_WARNING("No fish are running in this stretch. It has been fished out for now."))

/obj/structure/stone_age_trap/weir/attack_hand(mob/user)
	if (!ishuman(user) || !user.Adjacent(src))
		return
	settle()
	if (fish > 0)
		var/count = fish
		fish = 0
		var/kind = fish_water_kind(loc)
		for (var/i = 1 to count)
			var/fish_path = kind ? fish_catch_type(loc, kind, FALSE) : /obj/item/weapon/reagent_containers/food/snacks/rawfish
			new fish_path(get_turf(user))
		user.visible_message(SPAN_NOTICE("[user] scoops fish out of \the [src]."), SPAN_NOTICE("You scoop [count] fish out of \the [src]."))
		note_field_work(user, "forage")
		update_icon()
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts pulling up \the [src]."), SPAN_NOTICE("You start pulling up \the [src]."))
	if (do_after(user, 60, src) && !QDELETED(src))
		var/obj/item/K = new kit_type(get_turf(user))
		user.put_in_hands(K)
		qdel(src)
	return TRUE

// ---------------------------------------------------------------- pit trap
// A pit dug with a shovel or digging stick and hidden under branches. It
// catches whoever walks onto it, people included, except the digger's own
// people (their civilization, or their side on a team map), who know where it is. Someone walking (not running) may feel
// the cover give and catch themselves. Punji sticks at the bottom wound.
/obj/item/weapon/pit_cover
	name = "pit cover"
	desc = "A bundle of thin branches and leaves. Hold a shovel or digging stick in your other hand and use this on open ground to dig a pit and hide it, or lay it over an open pit."
	icon = STONE_AGE_TRAP_ICON
	icon_state = "pit_cover"
	w_class = ITEM_SIZE_LARGE
	flammable = TRUE
	value = 2

/proc/pit_digging_tool(obj/item/I)
	if (istype(I, /obj/item/weapon/plough/digging_stick))
		return PIT_DIG_TIME_STICK
	if (is_tool(I, TOOL_SHOVEL))
		return PIT_DIG_TIME_SHOVEL
	return 0

/obj/item/weapon/pit_cover/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !ishuman(user))
		return ..()
	var/turf/T = get_turf(target)
	if (!T || !user.Adjacent(T) || T == get_turf(user))
		return ..()
	var/obj/structure/stone_age_trap/pit/P = locate() in T
	if (P)
		return P.cover(user, src)
	if (!trap_ground_ok(T))
		to_chat(user, SPAN_WARNING("A pit has to be dug in open ground outdoors: grass, dirt, sand or snow."))
		return TRUE
	if (trap_structure_on(T))
		to_chat(user, SPAN_WARNING("There is already a trap there."))
		return TRUE
	var/obj/item/tool = user.get_inactive_hand()
	var/delay = pit_digging_tool(tool)
	if (!delay)
		to_chat(user, SPAN_WARNING("Hold a shovel or a digging stick in your other hand to dig the pit."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts digging a pit."), SPAN_NOTICE("You start digging a pit with \the [tool]."))
	if (!do_after(user, delay, T) || QDELETED(src) || loc != user || user.get_inactive_hand() != tool || trap_structure_on(T) || !trap_ground_ok(T))
		return TRUE
	var/obj/structure/stone_age_trap/pit/pit = new(T)
	pit.dug_by(user)
	pit.cover(user, src, 0)
	return TRUE

/obj/structure/stone_age_trap/pit
	name = "pit"
	desc = "A deep pit dug into the ground."
	icon_state = "pit_open"
	base_state = "pit"
	layer = TURF_LAYER + 0.1
	flammable = FALSE
	can_buckle = FALSE
	var/covered = FALSE
	var/staked = FALSE
	var/tribe

/obj/structure/stone_age_trap/pit/persistence_runtime_var(key)
	return key == "buckled_mob" || ..()

/obj/structure/stone_age_trap/pit/after_load()
	..()
	unbuckle_mob()
	update_icon()

/obj/structure/stone_age_trap/pit/arm()
	update_icon()

/obj/structure/stone_age_trap/pit/settle(now)
	return 0

// Whose pit it is: the digger's civilization, or their side on a team map.
/proc/pit_side_of(mob/living/human/H)
	if (!istype(H))
		return null
	if (H.civilization && H.civilization != "none")
		return H.civilization
	return H.faction_text

/obj/structure/stone_age_trap/pit/proc/dug_by(mob/living/human/H)
	setter_name = H.real_name
	var/side = pit_side_of(H)
	if (side)
		tribe = side

/obj/structure/stone_age_trap/pit/update_icon()
	if (covered)
		icon_state = "pit_covered"
		name = "branches"
		desc = "Some branches and leaves lie on the ground."
	else
		icon_state = staked ? "pit_staked" : "pit_open"
		name = staked ? "staked pit" : "pit"
		desc = staked ? "A deep pit with sharpened stakes at the bottom." : "A deep pit dug into the ground."

/obj/structure/stone_age_trap/pit/proc/cover(mob/user, obj/item/weapon/pit_cover/C, delay = 40)
	if (covered)
		to_chat(user, SPAN_WARNING("The pit is already covered."))
		return TRUE
	if (buckled_mob)
		to_chat(user, SPAN_WARNING("Get [buckled_mob] out of the pit first."))
		return TRUE
	if (delay && !do_after(user, delay, src))
		return TRUE
	if (covered || QDELETED(C) || C.loc != user)
		return TRUE
	user.drop_from_inventory(C)
	qdel(C)
	covered = TRUE
	if (!tribe)
		dug_by(user)
	update_icon()
	to_chat(user, SPAN_NOTICE("You hide the pit under branches and leaves.[tribe ? " Your people know where it is and won't fall in." : ""]"))
	return TRUE

/obj/structure/stone_age_trap/pit/trap_status(mob/user)
	if (covered && !knows_pit(user))
		return
	if (covered)
		to_chat(user, SPAN_NOTICE("It is your people's pit trap, hidden under branches[staked ? ", with stakes at the bottom" : ""]."))
	if (buckled_mob)
		to_chat(user, SPAN_WARNING("[buckled_mob] is trapped in it."))

/obj/structure/stone_age_trap/pit/proc/knows_pit(mob/M)
	if (!ishuman(M))
		return FALSE
	var/mob/living/human/H = M
	if (setter_name && H.answers_to_name(setter_name))
		return TRUE
	return tribe && pit_side_of(H) == tribe

/obj/structure/stone_age_trap/pit/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/punji_sticks))
		if (staked)
			to_chat(user, SPAN_WARNING("There are already stakes in the pit."))
			return TRUE
		if (covered)
			to_chat(user, SPAN_WARNING("Uncover the pit first."))
			return TRUE
		if (!do_after(user, 30, src) || staked || covered || QDELETED(W))
			return TRUE
		user.drop_from_inventory(W)
		qdel(W)
		staked = TRUE
		update_icon()
		to_chat(user, SPAN_NOTICE("You plant the sharpened stakes at the bottom of the pit."))
		return TRUE
	if (istype(W, /obj/item/weapon/pit_cover))
		return cover(user, W)
	if (pit_digging_tool(W) && !covered && !buckled_mob)
		user.visible_message(SPAN_NOTICE("[user] starts filling in \the [src]."), SPAN_NOTICE("You start filling in \the [src]."))
		if (do_after(user, 100, src) && !QDELETED(src) && !buckled_mob)
			if (staked)
				new /obj/item/weapon/punji_sticks(get_turf(src))
			qdel(src)
		return TRUE
	return ..()

/obj/structure/stone_age_trap/pit/attack_hand(mob/user)
	if (!ishuman(user) || !user.Adjacent(src))
		return
	if (buckled_mob && buckled_mob != user)
		user_unbuckle_mob(user)
		return TRUE
	if (covered && knows_pit(user))
		user.visible_message(SPAN_NOTICE("[user] starts pulling the branches off \the [src]."), SPAN_NOTICE("You start uncovering the pit."))
		if (do_after(user, 30, src) && covered)
			covered = FALSE
			update_icon()
			user.put_in_hands(new /obj/item/weapon/pit_cover(get_turf(user)))
		return TRUE
	return TRUE

/obj/structure/stone_age_trap/pit/Crossed(atom/movable/AM)
	. = ..()
	if (!covered || buckled_mob || !isliving(AM))
		return
	var/mob/living/L = AM
	if (L.stat == DEAD || L.buckled)
		return
	if (ishuman(L))
		var/mob/living/human/H = L
		if (knows_pit(H))
			return
		if (H.m_intent == "walk" && prob(PIT_NOTICE_CHANCE))
			covered = FALSE
			update_icon()
			new /obj/item/weapon/pit_cover(get_turf(src))
			H.visible_message(SPAN_WARNING("[H] feels branches give underfoot and catches themselves on the edge of a hidden pit!"), SPAN_WARNING("The branches give underfoot, and you catch yourself on the edge of a hidden pit!"))
			return
	else if (!istype(L, /mob/living/simple_animal) || L.mob_size < MOB_MEDIUM)
		return
	fall(L)

/obj/structure/stone_age_trap/pit/proc/fall(mob/living/L)
	covered = FALSE
	update_icon()
	L.visible_message(SPAN_DANGER("The ground gives way and [L] falls into a hidden pit!"), SPAN_DANGER("The ground gives way under you and you fall into a hidden pit!"))
	playsound(src, 'sound/effects/thud.ogg', 50, TRUE)
	if (ishuman(L))
		var/mob/living/human/H = L
		H.Weaken(3)
		var/zone = pick("l_leg", "r_leg", "l_foot", "r_foot")
		H.apply_damage(PIT_FALL_DAMAGE, BRUTE, zone)
		if (staked)
			zone = pick("l_leg", "r_leg", "l_foot", "r_foot", "groin", "chest")
			var/blocked = H.run_armor_check(zone, "melee")
			H.apply_damage(PIT_STAKE_DAMAGE, BRUTE, zone, blocked, sharp = TRUE, used_weapon = "wooden stakes")
	else
		L.adjustBruteLoss(PIT_FALL_DAMAGE + (staked ? PIT_STAKE_DAMAGE : 0))
	if (L.stat == DEAD || QDELETED(L) || buckled_mob)
		return
	can_buckle = TRUE
	buckle_mob(L)
	can_buckle = FALSE
	if (istype(L, /mob/living/simple_animal))
		addtimer(CALLBACK(src, PROC_REF(release_animal), L), PIT_ANIMAL_HOLD)
	else
		to_chat(L, SPAN_WARNING("You are stuck in the pit. Resist to climb out."))

// A trapped animal eventually scrambles out if nobody comes for it.
/obj/structure/stone_age_trap/pit/proc/release_animal(mob/living/L)
	if (QDELETED(src) || buckled_mob != L)
		return
	unbuckle_mob()
	climb_out(L)

/obj/structure/stone_age_trap/pit/proc/climb_out(mob/living/L)
	for (var/d in cardinal)
		var/turf/T = get_step(src, d)
		if (T && !T.density && L.Move(T))
			return TRUE
	return FALSE

/obj/structure/stone_age_trap/pit/user_unbuckle_mob(mob/user)
	var/mob/living/M = buckled_mob
	if (!M)
		return null
	var/self = (M == user)
	var/delay = self ? PIT_CLIMB_TIME : PIT_HELP_TIME
	if (self)
		M.visible_message(SPAN_NOTICE("[M] starts climbing out of the pit."), SPAN_NOTICE("You start climbing out of the pit."))
	else
		user.visible_message(SPAN_NOTICE("[user] starts pulling [M] out of the pit."), SPAN_NOTICE("You start pulling [M] out of the pit."))
	if (!do_after(user, delay, src, incapacitation_flags = INCAPACITATION_DEFAULT & ~(INCAPACITATION_RESTRAINED | INCAPACITATION_BUCKLED_FULLY)))
		return null
	if (buckled_mob != M)
		return null
	unbuckle_mob()
	climb_out(M)
	M.visible_message(SPAN_NOTICE("[M] gets out of the pit."))
	return M

#undef PIT_ANIMAL_HOLD
