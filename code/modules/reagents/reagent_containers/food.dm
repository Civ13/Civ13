#define CELLS 8
#define CELLSIZE (32/CELLS)

////////////////////////////////////////////////////////////////////////////////
/// Food.
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food
	possible_transfer_amounts = null
	volume = 50 //Sets the default container amount for all food items.
	var/filling_color = "#FFFFFF" //Used by sandwiches.
	var/list/center_of_mass = list() // Used for table placement
	var/roasted = FALSE
	var/boiled = FALSE
	var/raw = FALSE
	var/decay = 0 //Decay time limit, in deciseconds. 0 means it doesn't decay.
	var/decaytimer = 0 //counter of decay
	var/satisfaction = 0
	var/disgusting = FALSE

	var/rots = FALSE
	var/rotten = FALSE
	var/rotten_icon_state = ""

/obj/item/weapon/reagent_containers/food/New()
	..()
	if (decay > 0)
		food_decay()
	if (center_of_mass.len && !pixel_x && !pixel_y)
		pixel_x = rand(-6.0, 6) //Randomizes postion
		pixel_y = rand(-6.0, 6)

/obj/item/weapon/reagent_containers/food/proc/rot()
	if (rotten || !rots)
		return
	icon_state = rotten_icon_state
	name = "rotten [name]"
	if (reagents)
		reagents.remove_reagent("protein", 2)
		reagents.add_reagent("food_poisoning", 1)
	rotten = TRUE
	disgusting = TRUE
	satisfaction = -30
	spawn(1000)
		if (isturf(loc) && prob(30))
			var/scavengerspawn = rand(1,3)
			if(scavengerspawn ==  1)
				new/mob/living/simple_animal/mouse(get_turf(src))
			else if(scavengerspawn ==  2)
				new/mob/living/simple_animal/cockroach(get_turf(src))
			else
				new/mob/living/simple_animal/fly(get_turf(src))


/obj/item/weapon/reagent_containers/food/proc/food_decay()
	spawn(rand(590,610)) //some spreading and randomness
		if (decay == 0)
			return
		if (istype(loc, /obj/structure/vending))
			food_decay()
			return
		else if (istype(loc, /obj/item/weapon/can))
			var/obj/item/weapon/can/C = loc
			if (!C.open)
				food_decay()
				return
		//temp until I put a continuing proc somewhere else like by the potatoes but i cant figure it right now because i have other stuff to do k thx bye.
		if(istype(src, /obj/item/weapon/reagent_containers/food/snacks/grown/potato))
			if (isturf(loc))
				if(prob(10))
					new/obj/item/weapon/reagent_containers/food/snacks/grown/greenpotato(src.loc)
					qdel(src)
					return
		if (istype(loc, /obj/structure/closet/fridge))
			var/obj/structure/closet/fridge/F = loc
			if (F.powersource && F.powersource.powered)
				decaytimer += 75 //much slower
			else
				decaytimer += 200 //unpowered fridge still better, than storage container
		else if (istype(loc, /obj/structure/closet/crate/freezer))
			decaytimer += 50 //to be readjusted according to gameplay, since freezers don't require power
		else if (isturf(loc)) //if on the floor (i.e. not stored inside something), decay faster
			decaytimer += 600
		else if (!istype(loc, /obj/item/weapon/can)) //if not canned, since canned food doesn't spoil
			decaytimer += 300
		if (decaytimer >= decay)
			qdel(src)
			return
		else if (decaytimer >= decay/2 && !rotten && rots)
			rot()
		food_decay()

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
