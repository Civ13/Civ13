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
	not_disassemblable = TRUE // The raft's hammer rule; a canoe is taken apart by canoe_work().
	var/paddle_delay = 8
	var/open_sea = FALSE                 // TRUE for a craft that may cross deep salt water.
	var/rough_wind = DUGOUT_ROUGH_WIND   // Salt water in wind this strong is refused.
	var/seat_spacing = DUGOUT_SEAT_SPACING
	var/seat_lift = DUGOUT_SEAT_LIFT
	var/booms_fitted = FALSE             // Outrigger booms and float laid on, not yet lashed (naval/outrigger_canoe.dm).

/obj/structure/vehicle/raft/dugout/proc/paddling()
	return driver && (istype(driver.l_hand, /obj/item/weapon/paddle) || istype(driver.r_hand, /obj/item/weapon/paddle))

// Tenths of a second her next tile takes, heading m_dir (the raft's
// processmove asks, naval/small_boat_upkeep.dm).
/obj/structure/vehicle/raft/dugout/step_delay(m_dir)
	return (paddling() ? paddle_delay : initial(vehicle_m_delay)) + wear_delay()

/obj/structure/vehicle/raft/dugout/can_travel_open_sea()
	return open_sea

/obj/structure/vehicle/raft/dugout/do_vehicle_check()
	if (!driver)
		return FALSE
	if (booms_fitted)
		to_chat(driver, SPAN_WARNING("The booms and float are loose on \the [src]. Lash them with rope first."))
		return FALSE
	var/turf/DT = get_step(src, driver.dir)
	if (istype(DT, /turf/floor/beach/water))
		var/turf/floor/beach/water/W = DT
		if (!can_travel_open_sea() && W.salty && istype(W, /turf/floor/beach/water/deep))
			to_chat(driver, SPAN_WARNING("The open sea is too much for a canoe. Keep to the shallows."))
			return FALSE
		if (W.salty && weather_wind_at(W) >= rough_wind)
			to_chat(driver, SPAN_WARNING("The waves are too rough for a canoe. Wait for the wind to drop."))
			return FALSE
	return ..()

// The two paddlers sit one behind the other along the hull, not on one spot.
/obj/structure/vehicle/raft/dugout/update_icon()
	..()
	var/old_w = pixel_w
	var/old_z = pixel_z
	dress_hull()
	if (on_rollers && (pixel_w != old_w || pixel_z != old_z))
		dress_rollers()
	seat_paddlers()

// The hull's own look. An outrigger's sheet is three tiles square with the
// hull in the middle, so it is drawn a tile down and left of where it stands.
/obj/structure/vehicle/raft/dugout/proc/dress_hull()
	if (booms_fitted)
		icon = OUTRIGGER_ICON
		icon_state = "outrigger_fitted"
		pixel_w = -32
		pixel_z = -32
	else
		icon = initial(icon)
		icon_state = initial(icon_state)
		pixel_w = initial(pixel_w)
		pixel_z = initial(pixel_z)

// Fitting an outrigger, and taking the canoe apart (naval/outrigger_canoe.dm).
/obj/structure/vehicle/raft/dugout/attackby(obj/item/O as obj, mob/user as mob)
	if (canoe_work(O, user))
		return TRUE
	return ..()

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
	var/offset = aboard.len > 1 ? seat_spacing : 0
	for (var/mob/living/M in aboard)
		switch (dir)
			if (NORTH, SOUTH)
				M.pixel_x = 0
				M.pixel_y = (dir == NORTH ? offset : -offset)
			else
				M.pixel_y = seat_lift
				M.pixel_x = (dir == EAST ? offset : -offset)
		offset = -offset
