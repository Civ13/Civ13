// Moveable-frame hives (bee farming 4). Langstroth's box hive (1852) holds
// removable wooden frames that the bees fill with comb and honey, so honey can
// be taken without cutting comb out of the hive. Kit, all at Advanced
// Agriculture: the frame hive, frames, a hive tool to lift the lid, a bellows
// smoker (1873), a centrifugal honey extractor (1865) that spins honey out
// and hands the drawn comb back, and a nucleus box for splitting colonies or
// catching swarms.
//
// Colonies tick with the kept hives (kept_hives.dm): kept_hive_cycle() runs
// every frame hive in the frame_hives registry once every few minutes. Frames
// whose comb is already drawn fill about twice as fast as bare foundation.

#define FRAME_HIVE_SMOKE_TIME (60 SECONDS)
#define FRAME_HIVE_FORAGE_REFRESH (30 MINUTES)
#define FRAME_HIVE_FILL_RATE 0.5 // frame percent per strength point per tick at full forage
#define BEE_SMOKER_LOAD_TIME (3 MINUTES)
#define BEE_SMOKER_MAX_LOADS 3
#define EXTRACTOR_CAPACITY 4

var/global/list/frame_hives = list()

/obj/structure/beehive
	name = "frame hive"
	desc = "A stacked wooden box hive, painted white, that holds removable frames for the bees to build their comb on."
	icon = 'icons/farming/frame_hives.dmi'
	icon_state = "frame_hive"
	density = TRUE
	anchored = FALSE
	flammable = TRUE

	var/closed = TRUE
	var/bee_count = 0 // colony strength, 0 to 100
	var/tmp/smoked_until = 0
	var/honeycombs = 0 // percent, 100 per filled frame
	var/frames = 0
	var/drawn_frames = 0 // installed frames that already carry comb
	var/maxFrames = 10
	var/tmp/forage = 0
	var/tmp/forage_at = -1
	var/tmp/harvesting = FALSE

/obj/structure/beehive/persistence_runtime_var(key)
	return key == "forage" || key == "forage_at" || key == "harvesting" || ..()

/obj/structure/beehive/New()
	..()
	frame_hives |= src
	update_icon()

/obj/structure/beehive/after_load()
	. = ..()
	frame_hives |= src
	update_icon()

/obj/structure/beehive/Destroy()
	frame_hives -= src
	return ..()

/obj/structure/beehive/Del()
	frame_hives -= src
	..()

/obj/structure/beehive/proc/smoked()
	return world.time < smoked_until

/obj/structure/beehive/update_icon()
	overlays.Cut()
	icon_state = closed ? "frame_hive" : "frame_hive_open"
	if (bee_count > 0 && !smoked())
		switch (bee_count)
			if (0 to 20)
				overlays += image(icon, "bees1")
			if (20 to 40)
				overlays += image(icon, "bees2")
			if (40 to 60)
				overlays += image(icon, "bees3")
			if (60 to 80)
				overlays += image(icon, "bees4")
			else
				overlays += image(icon, "bees5")
	// An empty hive can be carried to a swarm; a lived-in one stays put.
	anchored = bee_count > 0

/obj/structure/beehive/examine(mob/user)
	..()
	to_chat(user, closed ? "The lid is on." : "The lid is off.")
	if (!bee_count)
		to_chat(user, "There are no bees in it. Shake a swarm into it, or empty a full nucleus box into it with the lid off.")
	var/skilled = ishuman(user) && user:getStatCoeff("farming") >= 1.3
	if (bee_count && skilled)
		to_chat(user, "You judge the colony at about [round(bee_count)]% strength.[bee_count >= 60 ? " It is strong enough to split." : ""]")
	if (frames)
		var/filled = round(honeycombs / 100)
		to_chat(user, "[frames] of [maxFrames] frames are in it[drawn_frames ? ", [drawn_frames] with comb already drawn" : ""]. [filled ? "[filled] [filled == 1 ? "is" : "are"] full of capped honey." : "None is full yet."]")
		if (skilled && honeycombs < frames * 100)
			to_chat(user, "The next frame is about [round(honeycombs % 100)]% full.")
	else
		to_chat(user, "It has no frames. The bees need frames to store honey.")
	if (bee_count && !wild_bee_season_active() && honeycombs < 100)
		to_chat(user, SPAN_WARNING("The bees have little left to live on until the flowers return."))
	if (smoked())
		to_chat(user, SPAN_NOTICE("Smoke drifts through the hive; the bees are calm."))

/obj/structure/beehive/proc/is_lid_tool(obj/item/I)
	return istype(I, /obj/item/hive_tool) || is_tool(I, TOOL_CROWBAR)

/obj/structure/beehive/attackby(var/obj/item/I, var/mob/user)
	if (is_lid_tool(I))
		closed = !closed
		user.visible_message(SPAN_NOTICE("[user] [closed ? "sets the lid back on" : "prises the lid off"] \the [src]."), SPAN_NOTICE("You [closed ? "set the lid back on" : "prise the lid off"] \the [src]."))
		update_icon()
		return

	else if (is_bee_smoke(I))
		if (!bee_count)
			to_chat(user, SPAN_NOTICE("There are no bees in \the [src] to smoke."))
			return
		user.visible_message(SPAN_NOTICE("[user] puffs smoke into \the [src]."), SPAN_NOTICE("You puff smoke into \the [src]. The humming drops to a drowsy murmur."))
		smoked_until = world.time + FRAME_HIVE_SMOKE_TIME
		update_icon()
		addtimer(CALLBACK(src, PROC_REF(update_icon)), FRAME_HIVE_SMOKE_TIME + 1)
		return

	else if (istype(I, /obj/item/honey_frame))
		if (closed)
			to_chat(user, SPAN_NOTICE("Take the lid off \the [src] with a hive tool before putting frames in."))
			return
		if (frames >= maxFrames)
			to_chat(user, SPAN_WARNING("There is no room for another frame."))
			return
		var/obj/item/honey_frame/HF = I
		if (HF.honey)
			to_chat(user, SPAN_NOTICE("\The [I] is full of honey. Spin it in an extractor or cut the comb out first."))
			return
		++frames
		if (HF.drawn)
			++drawn_frames
		user.visible_message(SPAN_NOTICE("\The [user] slides \the [I] into \the [src]."), SPAN_NOTICE("You slide \the [I] into \the [src]."))
		user.drop_from_inventory(I)
		qdel(I)
		update_icon()
		return

	else if (istype(I, /obj/item/nucleus_box))
		var/obj/item/nucleus_box/B = I
		if (closed)
			to_chat(user, SPAN_NOTICE("Take the lid off \the [src] with a hive tool first."))
			return
		if (B.full)
			if (bee_count)
				to_chat(user, SPAN_NOTICE("\The [src] already has bees in it."))
				return
			user.visible_message(SPAN_NOTICE("\The [user] tips the bees from \the [I] into \the [src]."), SPAN_NOTICE("You tip the queen and her bees from \the [I] into \the [src]."))
			settle(B.colony_strength)
			B.empty()
			return
		if (bee_count < 60)
			to_chat(user, SPAN_NOTICE("The colony in \the [src] is not strong enough to split."))
			return
		if (!smoked())
			to_chat(user, SPAN_NOTICE("Smoke \the [src] first, or the bees will not stand for it."))
			return
		user.visible_message(SPAN_NOTICE("\The [user] lifts bees and brood from \the [src] into \the [I]."), SPAN_NOTICE("You lift a frame of brood and nurse bees into \the [I]. They will raise a new queen."))
		var/half = round(bee_count / 2)
		bee_count -= half
		B.fill(half)
		update_icon()
		return

	else if (istype(I, /obj/item/hive_tool) || is_tool(I, TOOL_HAMMER) || is_tool(I, TOOL_SCREWDRIVER))
		dismantle(user)
		return
	return ..()

/obj/structure/beehive/proc/dismantle(mob/user)
	if (bee_count)
		to_chat(user, SPAN_NOTICE("You can't take \the [src] apart with bees inside."))
		return
	to_chat(user, SPAN_NOTICE("You start taking \the [src] apart..."))
	playsound(loc, 'sound/items/Screwdriver.ogg', 50, 1)
	if (!do_after(user, 30, src))
		return
	if (QDELETED(src) || QDELETED(user) || !Adjacent(user) || bee_count)
		return
	user.visible_message(SPAN_NOTICE("\The [user] takes \the [src] apart."), SPAN_NOTICE("You take \the [src] apart."))
	for (var/i = 1, i <= 6, i++)
		new /obj/item/stack/material/woodplank(loc) // 6 of the 8 planks it cost
	var/drawn = drawn_frames
	for (var/i = 1, i <= frames, i++)
		if (honeycombs >= 100)
			new /obj/item/honey_frame/filled(loc)
			honeycombs -= 100
		else if (drawn > 0)
			new /obj/item/honey_frame/drawn(loc)
			drawn--
		else
			new /obj/item/honey_frame(loc)
	qdel(src)

/obj/structure/beehive/attack_hand(var/mob/user)
	if (closed)
		to_chat(user, SPAN_NOTICE("The lid is on. Prise it off with a hive tool to get at the frames."))
		return
	if (honeycombs < 100)
		to_chat(user, SPAN_NOTICE("No frame is full of honey yet."))
		return
	if (bee_count && !smoked())
		user.visible_message(SPAN_DANGER("[user] reaches into \the [src] and the bees boil out!"), SPAN_DANGER("The bees boil out at you! Smoke them first."))
		if (ishuman(user))
			wild_bee_attack(user, src)
		return
	if (harvesting)
		to_chat(user, SPAN_NOTICE("Someone is already lifting frames out of \the [src]."))
		return
	harvesting = TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts lifting full frames out of \the [src]."), SPAN_NOTICE("You start lifting the full frames out of \the [src]..."))
	while (honeycombs >= 100 && frames > 0 && do_after(user, 30, src))
		if (QDELETED(src) || QDELETED(user) || !Adjacent(user) || closed || (!smoked() && bee_count) || frames <= 0 || honeycombs < 100)
			break
		new /obj/item/honey_frame/filled(loc)
		honeycombs -= 100
		--frames
		drawn_frames = min(max(drawn_frames - 1, 0), frames)
		if (ishuman(user))
			var/mob/living/human/H = user
			H.adaptStat("farming", 1)
		update_icon()
	harvesting = FALSE
	if (!QDELETED(src) && honeycombs < 100)
		to_chat(user, SPAN_NOTICE("You have lifted out all the full frames."))

/obj/structure/beehive/proc/settle(colony_strength)
	bee_count = clamp(colony_strength, 10, 100)
	forage_at = -1
	update_icon()

/obj/structure/beehive/proc/die_out()
	bee_count = 0
	update_icon()
	visible_message(SPAN_WARNING("The last bees in \the [src] have died."))

// One colony step from kept_hive_cycle(). Bees store honey only on frames.
/obj/structure/beehive/proc/colony_tick(active, swarm_season)
	if (!bee_count)
		return
	if (active)
		if (forage_at < 0 || world.time - forage_at > FRAME_HIVE_FORAGE_REFRESH)
			forage = bee_forage_points(src)
			forage_at = world.time
		var/f = forage / bee_forage_full()
		if (f < 0.1)
			bee_count = max(bee_count - 1, 1)
		else
			bee_count = min(bee_count + 4 * f, 100)
		if (frames && !closed)
			// An open hive is chilled and robbed; the bees only defend it.
			f *= 0.25
		if (frames)
			var/speed = 1 + drawn_frames / frames
			honeycombs = min(honeycombs + bee_count * f * FRAME_HIVE_FILL_RATE * speed, frames * 100)
		// Room on the frames keeps most colonies from swarming.
		if (swarm_season && bee_count >= 80 && prob(frames >= maxFrames / 2 ? 2 : 8) && cast_swarm(src, 40))
			bee_count -= 40
	else if (prob(bee_count * 0.1))
		if (honeycombs >= 25)
			honeycombs -= 25
		else
			honeycombs = 0
			bee_count -= 15
			if (bee_count <= 0)
				die_out()
				return
	update_icon()

/////// The bellows smoker

/obj/item/bee_smoker
	name = "bee smoker"
	desc = "A tin fire pot with a spout and a pair of leather bellows. Load it with leaves, light it, and puff cool smoke to calm bees."
	icon = 'icons/farming/frame_hives.dmi'
	icon_state = "bee_smoker"
	w_class = ITEM_SIZE_SMALL
	var/loads = 0
	var/tmp/lit = FALSE
	var/tmp/burn_generation = 0

/obj/item/bee_smoker/persistence_runtime_var(key)
	return key == "lit" || key == "burn_generation" || ..()

/obj/item/bee_smoker/examine(mob/user)
	..()
	to_chat(user, lit ? "It is smouldering." : (loads ? "It is loaded with leaves." : "It is empty. Load it with leaves."))

/obj/item/bee_smoker/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/leaf))
		if (loads >= BEE_SMOKER_MAX_LOADS)
			to_chat(user, SPAN_NOTICE("\The [src] is packed full."))
			return TRUE
		var/obj/item/stack/S = W
		if (!S.use(1))
			return TRUE
		loads++
		to_chat(user, SPAN_NOTICE("You pack leaves into \the [src]."))
		return TRUE
	if (!lit && isflamesource(W))
		if (!loads)
			to_chat(user, SPAN_NOTICE("There is nothing in \the [src] to burn."))
			return TRUE
		light(user)
		return TRUE
	return ..()

/obj/item/bee_smoker/proc/light(mob/user)
	lit = TRUE
	burn_generation++
	icon_state = "bee_smoker_lit"
	if (user)
		to_chat(user, SPAN_NOTICE("You light \the [src] and work the bellows until it smokes."))
	addtimer(CALLBACK(src, PROC_REF(burn_down), burn_generation), BEE_SMOKER_LOAD_TIME)

/obj/item/bee_smoker/proc/burn_down(generation)
	if (QDELETED(src) || !lit || generation != burn_generation)
		return
	loads = max(loads - 1, 0)
	if (loads > 0)
		addtimer(CALLBACK(src, PROC_REF(burn_down), burn_generation), BEE_SMOKER_LOAD_TIME)
		return
	lit = FALSE
	icon_state = "bee_smoker"
	var/mob/M = loc
	if (istype(M))
		to_chat(M, SPAN_NOTICE("\The [src] has burned out."))

/obj/item/bee_smoker/attack_self(mob/user)
	if (lit)
		lit = FALSE
		burn_generation++
		icon_state = "bee_smoker"
		to_chat(user, SPAN_NOTICE("You snuff \the [src]."))
		return
	return ..()

/////// Hive tool

/obj/item/hive_tool
	name = "hive tool"
	desc = "A flat steel bar with a hooked end, for prising off a hive lid, lifting stuck frames and taking a hive apart."
	icon = 'icons/farming/frame_hives.dmi'
	icon_state = "hive_tool"
	w_class = ITEM_SIZE_SMALL
	force = 5

/////// Frames

/obj/item/honey_frame
	name = "hive frame"
	desc = "A wooden frame with a thin sheet of wax foundation, for the bees to build comb on."
	icon = 'icons/farming/frame_hives.dmi'
	icon_state = "honey_frame"
	w_class = ITEM_SIZE_SMALL

	var/honey = 0
	var/drawn = FALSE

/obj/item/honey_frame/drawn
	name = "drawn hive frame"
	desc = "A hive frame with empty comb already built on it. Bees fill it with honey much faster than bare foundation."
	icon_state = "honey_frame_drawn"
	drawn = TRUE

/obj/item/honey_frame/filled/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/material/kitchen/utensil/knife/))
		user.visible_message(SPAN_NOTICE("\The [user] starts taking the honeycombs out of \the [src]."), SPAN_NOTICE("You start taking the honeycombs out of \the [src]..."))
		if(!do_after(user, 90, src))
			return
		if (QDELETED(src) || QDELETED(user) || !Adjacent(user))
			return
		to_chat(user, SPAN_NOTICE("You take all filled honeycombs out."))
		new /obj/item/weapon/reagent_containers/food/snacks/honeycomb(loc)
		new /obj/item/honey_frame(loc)
		qdel(src)
		return

/obj/item/honey_frame/filled
	name = "full hive frame"
	desc = "A hive frame heavy with capped honey. Spin it in an extractor to keep the comb, or cut the comb out with a knife."
	icon_state = "honey_frame_filled"
	honey = 20
	drawn = TRUE

/////// Honey extractor

/obj/structure/honey_extractor
	name = "honey extractor"
	desc = "A tin drum with a hand crank. Full frames spun inside fling their honey out against the wall, and the empty comb goes back in the hive."
	icon = 'icons/farming/frame_hives.dmi'
	icon_state = "extractor"
	density = TRUE
	anchored = FALSE
	var/loaded = 0 // full frames inside
	var/tmp/spinning = FALSE

/obj/structure/honey_extractor/persistence_runtime_var(key)
	return key == "spinning" || ..()

/obj/structure/honey_extractor/New()
	..()
	create_reagents(200)

/obj/structure/honey_extractor/examine(mob/user)
	..()
	to_chat(user, "It holds [loaded] of [EXTRACTOR_CAPACITY] full frames[reagents && reagents.total_volume ? " and [round(reagents.total_volume)] units of honey" : ""].")

/obj/structure/honey_extractor/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/honey_frame))
		var/obj/item/honey_frame/F = I
		if (!F.honey)
			to_chat(user, SPAN_NOTICE("\The [I] has no honey to spin out."))
			return TRUE
		if (loaded >= EXTRACTOR_CAPACITY)
			to_chat(user, SPAN_NOTICE("\The [src] is full. Crank it first."))
			return TRUE
		if (spinning)
			return TRUE
		loaded++
		user.drop_from_inventory(I)
		qdel(I)
		to_chat(user, SPAN_NOTICE("You set the full frame in \the [src]'s basket."))
		return TRUE
	if (istype(I, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/G = I
		if (!G.is_open_container())
			to_chat(user, SPAN_NOTICE("\The [G] is closed."))
			return TRUE
		if (!reagents.total_volume)
			to_chat(user, SPAN_NOTICE("There is no honey in \the [src]."))
			return TRUE
		var/moved = reagents.trans_to_obj(G, G.reagents.get_free_space())
		if (moved)
			to_chat(user, SPAN_NOTICE("You open the honey gate and fill \the [G] with [round(moved)] units of honey."))
		else
			to_chat(user, SPAN_NOTICE("\The [G] is full."))
		return TRUE
	return ..()

/obj/structure/honey_extractor/attack_hand(mob/user)
	if (!ishuman(user))
		return ..()
	if (spinning)
		return
	if (!loaded)
		to_chat(user, SPAN_NOTICE("\The [src] is empty. Put full hive frames in it first."))
		return
	if (reagents.get_free_space() < 20)
		to_chat(user, SPAN_NOTICE("\The [src] is full of honey. Draw some off into a pot or bucket first."))
		return
	spinning = TRUE
	icon_state = "extractor_spin"
	user.visible_message(SPAN_NOTICE("[user] cranks \the [src]."), SPAN_NOTICE("You crank \the [src]. Honey patters against the drum."))
	var/done = do_after(user, 40, src)
	spinning = FALSE
	icon_state = "extractor"
	if (!done || QDELETED(src) || QDELETED(user) || !Adjacent(user) || loaded <= 0)
		return
	var/spun = 0
	while (loaded > 0 && reagents.get_free_space() >= 20)
		loaded--
		spun++
		reagents.add_reagent("honey", 20)
		new /obj/item/honey_frame/drawn(loc)
	to_chat(user, SPAN_NOTICE("You lift out [spun] empty frame[spun == 1 ? "" : "s"] with the comb still whole."))

/////// Nucleus box

/obj/item/nucleus_box
	name = "nucleus box"
	desc = "A small hive box for a few frames, for splitting a strong colony or carrying a caught swarm to a new hive."
	icon = 'icons/farming/frame_hives.dmi'
	icon_state = "nucleus_box"
	w_class = ITEM_SIZE_NORMAL
	var/full = FALSE
	var/colony_strength = 0

/obj/item/nucleus_box/examine(mob/user)
	..()
	to_chat(user, full ? "Bees hum inside. Tip them into an empty frame hive with its lid off." : "It is empty.")

/obj/item/nucleus_box/proc/empty()
	full = FALSE
	colony_strength = 0
	icon_state = "nucleus_box"

/obj/item/nucleus_box/proc/fill(strength)
	full = TRUE
	colony_strength = clamp(strength, 10, 60)
	icon_state = "nucleus_box_full"

// The bees of an empty frame hive or kept hive within reach of a swarm.
/proc/bee_swarm_home_near(atom/A)
	for (var/obj/structure/kept_hive/K in range(1, A))
		if (!K.occupied)
			return K
	for (var/obj/structure/beehive/B in range(1, A))
		if (!B.bee_count)
			return B
	return null

#undef FRAME_HIVE_SMOKE_TIME
#undef FRAME_HIVE_FORAGE_REFRESH
#undef FRAME_HIVE_FILL_RATE
#undef BEE_SMOKER_LOAD_TIME
#undef BEE_SMOKER_MAX_LOADS
#undef EXTRACTOR_CAPACITY
