// Dugout canoes. See docs/dugout-canoe.md.
// A big log is burned and hollowed in turns: a flame chars the wood, a stone
// adze (or any hatchet) scoops out the charcoal. Three of each and the log is a
// canoe. The canoe is a raft for two with room for one crate. Paddling with a
// paddle in hand is quicker. It keeps to rivers, lakes and the shallows: deep
// salt water is refused, and salt water in a strong wind is too rough.

#define DUGOUT_ICON 'icons/obj/vehicles/dugout_canoe.dmi'
#define DUGOUT_STAGES 6
#define DUGOUT_CHAR_TIME 80
#define DUGOUT_HOLLOW_TIME 120
#define DUGOUT_ROUGH_WIND 3
#define DUGOUT_SEAT_SPACING 6
#define DUGOUT_SEAT_LIFT 5

/obj/structure/dugout_log
	name = "dugout log"
	desc = "A big trimmed log laid out to be made into a canoe. Char the top with a flame, then scoop out the charred wood with an adze, until it is hollow."
	icon = DUGOUT_ICON
	icon_state = "dugout_log0"
	anchored = FALSE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/stage = 0 // even: needs charring, odd: needs hollowing

/obj/structure/dugout_log/update_icon()
	icon_state = "dugout_log[round(stage / 2)][stage % 2 ? "_charred" : ""]"

/obj/structure/dugout_log/examine(mob/user, distance = -1)
	..()
	if (stage % 2)
		to_chat(user, "The top is charred. Scoop out the charred wood with an adze or hatchet.")
	else
		to_chat(user, "It needs charring with a flame next. [round(stage / 2)] of 3 rounds done.")

/proc/dugout_hollowing_tool(obj/item/W)
	if (istype(W, /obj/item/weapon/material/hatchet/tribal/adze))
		return DUGOUT_HOLLOW_TIME
	if (is_tool(W, TOOL_HATCHET))
		return DUGOUT_HOLLOW_TIME * 1.5
	return 0

/obj/structure/dugout_log/attackby(obj/item/W, mob/user)
	if (!ishuman(user))
		return ..()
	if (!(stage % 2) && isflamesource(W))
		user.visible_message(SPAN_NOTICE("[user] starts charring the top of \the [src] with \the [W]."), SPAN_NOTICE("You start charring the top of \the [src]."))
		if (do_after(user, DUGOUT_CHAR_TIME, src) && !(stage % 2) && isflamesource(W))
			stage++
			update_icon()
			to_chat(user, SPAN_NOTICE("The wood is charred black. Scoop it out with an adze."))
		return TRUE
	var/delay = dugout_hollowing_tool(W)
	if (delay)
		if (!(stage % 2))
			to_chat(user, SPAN_WARNING("The raw wood is too hard to scoop. Char it with a flame first."))
			return TRUE
		user.visible_message(SPAN_NOTICE("[user] starts hollowing \the [src] with \the [W]."), SPAN_NOTICE("You start scooping out the charred wood."))
		if (do_after(user, delay, src) && (stage % 2))
			stage++
			if (stage >= DUGOUT_STAGES)
				finish(user)
			else
				update_icon()
				to_chat(user, SPAN_NOTICE("You scoop out the charred wood. Char it again to go deeper."))
		return TRUE
	return ..()

/obj/structure/dugout_log/proc/finish(mob/user)
	var/obj/structure/vehicle/raft/dugout/C = new(get_turf(src))
	C.dir = dir
	user.visible_message(SPAN_NOTICE("[user] finishes hollowing out \a [C]."), SPAN_NOTICE("The log is hollow: you have made \a [C]. Drag it to the water."))
	note_craft_practice(user, "/obj/structure/dugout_log")
	qdel(src)

/obj/item/weapon/paddle
	name = "paddle"
	desc = "A carved wooden canoe paddle. Hold it while steering a dugout canoe to go faster."
	icon = DUGOUT_ICON
	icon_state = "paddle"
	item_state = "stick"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	w_class = ITEM_SIZE_LARGE
	force = 7
	throwforce = 5
	flammable = TRUE
	attack_verb = list("bashed", "whacked")
	value = 3

/obj/structure/vehicle/raft/dugout
	name = "dugout canoe"
	desc = "A canoe hollowed from a single log, for two. Steer it on rivers, lakes and near the shore; it is no boat for the open sea. Holding a paddle makes it faster."
	icon = DUGOUT_ICON
	icon_state = "dugout"
	mobcapacity = 2
	storagecapacity = 1
	vehicle_m_delay = 14
	health = 80
	not_disassemblable = TRUE
	var/paddle_delay = 8

/obj/structure/vehicle/raft/dugout/proc/paddling()
	return driver && (istype(driver.l_hand, /obj/item/weapon/paddle) || istype(driver.r_hand, /obj/item/weapon/paddle))

/obj/structure/vehicle/raft/dugout/processmove(m_dir = null)
	vehicle_m_delay = paddling() ? paddle_delay : initial(vehicle_m_delay)
	return ..()

/obj/structure/vehicle/raft/dugout/do_vehicle_check()
	if (!driver)
		return FALSE
	var/turf/DT = get_step(src, driver.dir)
	if (istype(DT, /turf/floor/beach/water))
		var/turf/floor/beach/water/W = DT
		if (W.salty && istype(W, /turf/floor/beach/water/deep))
			to_chat(driver, SPAN_WARNING("The open sea is too much for a canoe. Keep to the shallows."))
			return FALSE
		if (W.salty && weather_wind_at(W) >= DUGOUT_ROUGH_WIND)
			to_chat(driver, SPAN_WARNING("The waves are too rough for a canoe. Wait for the wind to drop."))
			return FALSE
	return ..()

// The two paddlers sit one behind the other along the hull, not on one spot.
/obj/structure/vehicle/raft/dugout/update_icon()
	..()
	icon_state = "dugout"
	seat_paddlers()

// A turn on the spot swings the hull at once, so the seats swing with it:
// the next tile step (update_icon) may be most of a tile away.
/obj/structure/vehicle/raft/dugout/updatepassdir()
	..()
	seat_paddlers()

// One paddler sits amidships; two sit fore and aft. Lying east or west the hull
// is drawn low on its tile, so they are lifted to keep their feet inside it.
/obj/structure/vehicle/raft/dugout/proc/seat_paddlers()
	var/list/aboard = list()
	for (var/mob/living/M in ontop)
		if (M.loc == loc)
			aboard += M
	var/offset = aboard.len > 1 ? DUGOUT_SEAT_SPACING : 0
	for (var/mob/living/M in aboard)
		switch (dir)
			if (NORTH, SOUTH)
				M.pixel_x = 0
				M.pixel_y = (dir == NORTH ? offset : -offset)
			else
				M.pixel_y = DUGOUT_SEAT_LIFT
				M.pixel_x = (dir == EAST ? offset : -offset)
		offset = -offset
