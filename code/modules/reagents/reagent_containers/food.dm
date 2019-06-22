#define CELLS 8
#define CELLSIZE (32/CELLS)

////////////////////////////////////////////////////////////////////////////////
/// Food.
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food
	flags = OPENCONTAINER
	possible_transfer_amounts = null
	volume = 50 //Sets the default container amount for all food items.
	var/filling_color = "#FFFFFF" //Used by sandwiches.
	var/list/center_of_mass = list() // Used for table placement
	var/roasted = FALSE
	var/boiled = FALSE
	var/raw = FALSE
	var/decay = 0 //Decay time limit, in deciseconds. 0 means it doesn't decay.
	var/decaytimer = 0
	var/satisfaction = 0
/obj/item/weapon/reagent_containers/food/New()
	..()
	if (decay > 0)
		food_decay()
	if (center_of_mass.len && !pixel_x && !pixel_y)
		pixel_x = rand(-6.0, 6) //Randomizes postion
		pixel_y = rand(-6.0, 6)

/obj/item/weapon/reagent_containers/food/proc/food_decay()
	spawn(600)
		if (decay == 0)
			return
		if (isturf(loc)) //if on the floor (i.e. not stored inside something), decay faster
			decaytimer += 600
		else if (!istype(loc, /obj/item/weapon/can)) //if not canned, since canned food doesn't spoil
			decaytimer += 300
		if (istype(loc, /obj/item/weapon/can))
			var/obj/item/weapon/can/C = loc
			if (C.open)
				decaytimer += 300
		if (decaytimer >= decay)
			qdel(src)
			return
		else
			food_decay()
			return

/obj/item/weapon/reagent_containers/food/afterattack(atom/A, mob/user, proximity, params)
	if (center_of_mass.len && proximity && params && istype(A, /obj/structure/table))
		//Places the item on a grid
		var/list/mouse_control = params2list(params)

		var/mouse_x = text2num(mouse_control["icon-x"])
		var/mouse_y = text2num(mouse_control["icon-y"])

		if (!isnum(mouse_x) || !isnum(mouse_y))
			return

		var/cell_x = max(0, min(CELLS-1, round(mouse_x/CELLSIZE)))
		var/cell_y = max(0, min(CELLS-1, round(mouse_y/CELLSIZE)))

		pixel_x = (CELLSIZE * (0.5 + cell_x)) - center_of_mass["x"]
		pixel_y = (CELLSIZE * (0.5 + cell_y)) - center_of_mass["y"]

#undef CELLS
#undef CELLSIZE
