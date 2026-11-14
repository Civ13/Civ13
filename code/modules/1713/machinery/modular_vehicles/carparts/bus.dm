// ============================================================
// Double-decker bus (multi-deck vehicles plan, Phase 1b)
// ------------------------------------------------------------
// The upper deck is the raised roof deck of vehicle_decks.dm, not a second
// z-level: every bus frame is an upper deck, and a staircase inside the bus
// leads up to it, so passengers go upstairs and down without leaving the bus.
// Walking off the edge of the upper deck is still a jump to the street.
// Built piece by piece at the automobile workshop (craft/vehicle_works.dm).
// ============================================================

/obj/structure/vehicleparts/axis/car/bus
	name = "double-decker bus"
	desc = "A powered axis from a bus."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	speeds = 4
	maxpower = 2000
	speedlist = alist(1=9,2=6,3=4,4=3)
	turntimer = 12

/obj/structure/vehicleparts/frame/car/bus
	name = "bus frame"
	desc = "A steel bus frame. Its roof is the bus's upper deck."
	icon_state = "frame_steel"
	upper_deck = TRUE
	noroof = FALSE

/obj/structure/vehicleparts/frame/car/bus/rf
	w_right = list("c_windoweddoor",TRUE,TRUE,5,20,TRUE,TRUE)
	w_front = list("c_windshield",FALSE,TRUE,5,20,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/bus/lf
	w_left = list("c_wall",TRUE,TRUE,5,20,FALSE,FALSE)
	w_front = list("c_windshield",FALSE,TRUE,5,20,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/bus/right
	w_right = list("c_window",FALSE,TRUE,5,20,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/bus/left
	w_left = list("c_window",FALSE,TRUE,5,20,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/bus/rb
	w_right = list("c_window",FALSE,TRUE,5,20,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,5,20,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/bus/lb
	w_left = list("c_window",FALSE,TRUE,5,20,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,5,20,FALSE,FALSE)

// The staircase between the bus's lower and upper decks. It rides with the
// bus like its seats do. Standing on it, click it (or use Climb Through
// Hatch) to go up; on the upper deck above it, click it or Climb Down to
// come back inside.
/obj/structure/vehicle_stairs
	name = "bus stairs"
	desc = "A narrow staircase up to the upper deck."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "wood_stairs2"
	density = FALSE
	anchored = TRUE
	layer = 2.9

/obj/structure/vehicle_stairs/proc/deck_frame()
	for (var/obj/structure/vehicleparts/frame/F in loc)
		if (F.axis && vehicle_deck_walkable(F))
			return F
	return null

/obj/structure/vehicle_stairs/attack_hand(mob/user)
	if (!ishuman(user))
		return ..()
	var/mob/living/human/H = user
	var/obj/structure/vehicleparts/frame/F = deck_frame()
	if (!F)
		to_chat(H, SPAN_WARNING("\The [src] lead nowhere without a bus around them."))
		return
	if (H.vehicle_deck)
		if (H.vehicle_deck == F)
			H.start_vehicle_deck_down()
		else
			to_chat(H, SPAN_WARNING("Walk over to the top of \the [src] first."))
		return
	if (H.loc != loc)
		to_chat(H, SPAN_WARNING("Step onto \the [src] first."))
		return
	H.climb_onto_vehicle(F, TRUE)

/obj/structure/vehicle_stairs/examine(mob/user, distance = -1)
	. = ..()
	to_chat(user, SPAN_NOTICE("Stand on them and click them to go up to the upper deck."))

/obj/effects/premadevehicles/bus/doubledecker
	name = "Double-decker bus"
	icon_state = "4x4"
	custom_color = "#a32424"
	axis = /obj/structure/vehicleparts/axis/car/bus
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/bus/rf, /obj/structure/vehicleparts/movement),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/bus/lf, /obj/structure/bed/chair/drivers, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/bus/right, /obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/bus/left, /obj/structure/bed/chair/carseat/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/bus/right, /obj/structure/bed/chair/carseat/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/bus/left, /obj/structure/bed/chair/carseat/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/bus/right, /obj/structure/vehicle_stairs),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/bus/left, /obj/structure/bed/chair/carseat/left),

	"1,5" = list(/obj/structure/vehicleparts/frame/car/bus/rb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline, /obj/structure/vehicleparts/movement/reversed),
	"2,5" = list(/obj/structure/vehicleparts/frame/car/bus/lb, /obj/structure/engine/internal/gasoline/premade/v6, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/eu/centered),
	)
