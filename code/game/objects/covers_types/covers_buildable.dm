/obj/covers/dirt_wall/blocks
	name = "dirt blocks wall"
	desc = "A dirt blocks wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drysod_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 550
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 4

/obj/covers/dirt_wall/blocks/incomplete
	name = "dirt blocks wall"
	desc = "A dirt blocks wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drysod_wall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 30
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE

/obj/covers/dirt_wall/blocks/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/barrier))
		if (stage == 3)
			user << "You start adding dirt to the wall..."
			if (do_after(user, 20, src) && W)
				user << "You finish adding dirt to the wall, completing it."
				qdel(W)
				new /obj/covers/dirt_wall/blocks(loc)
				qdel(src)
				return
		else if (stage <= 2)
			user << "You start adding dirt to the wall..."
			if (do_after(user, 20, src))
				if (stage <= 2)
					user << "You finish adding dirt to the wall."
					stage = (stage+1)
					icon_state = "drysod_wall_inc[stage]"
					base_icon_state = icon_state
					health = (20*stage)
					qdel(W)
					return
	..()

/obj/covers/clay_wall
	name = "clay block wall"
	desc = "A clay block wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claybrickwall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 750
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 6
	material = "Stone"
	hardness = 75
	buildstack = /obj/item/weapon/clay/claybricks/fired

/obj/covers/clay_wall/claydoorway //if you actually wanted to summon one.
	name = "clay block doorway"
	desc = "A clay block doorway."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "clay_doorway"
	passable = TRUE
	not_movable = TRUE
	density = FALSE
	opacity = FALSE

/obj/covers/clay_wall/incomplete
	name = "clay block wall"
	desc = "A clay block wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claybrickwall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 40
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"

/obj/covers/clay_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/claybricks/fired))
		if (stage >= 2)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src) && W)
				user << "You finish adding clay blocks to the wall, completing it."
				qdel(W)
				var/obj/covers/clay_wall/S = new /obj/covers/clay_wall(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of construction?","Clay Constructions","Normal",list("Wall", "Alternative Brick Style", "Doorway"))
				if (choice == "Wall")
					return
				else if (choice == "Alternative Brick Style")
					S.icon_state = "clay_block_alt"
					base_icon_state = icon_state
					S.name = "clay block wall"
				else if (choice == "Doorway")
					new /obj/covers/clay_wall/claydoorway(S.loc)
					qdel(S)
				return
		else if (stage <= 1)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src))
				if (stage <= 1)
					user << "You finish clay block to the wall."
					stage += 1
					icon_state = "claybrickwall_inc[stage]"
					base_icon_state = icon_state
					health = (30*stage)
					qdel(W)
					return
	..()

/obj/covers/clay_wall/sumerian
	name = "sumerian clay wall"
	desc = "A sumerian style clay wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "sumerian-wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 750
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 6
	material = "Stone"

/obj/covers/clay_wall/sumerian/doorway //if you actually wanted to summon one.
	name = "sumerian clay doorway"
	desc = "A sumerian style clay doorway."
	icon_state = "sumerian-door"
	density = FALSE
	opacity = FALSE

/obj/covers/clay_wall/sumerian/incomplete
	name = "sumerian clay wall"
	desc = "A sumerian style clay wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "sumerian-wall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 40
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"

/obj/covers/clay_wall/sumerian/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/claybricks/fired))
		if (stage >= 2)
			user << "You start adding clay to the wall..."
			if (do_after(user, 20, src) && W)
				user << "You finish adding clay to the wall, completing it."
				qdel(W)
				var/obj/covers/clay_wall/sumerian/S = new /obj/covers/clay_wall/sumerian(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of wall?","Sumerian Clay Walls","Normal",list("Normal","Doorway","Window","Corner"))
				if (choice == "Normal")
					return
				else if (choice == "Doorway")
					S.icon_state = "sumerian-door"
					base_icon_state = icon_state
					S.name = "sumerian clay door"
					S.density = FALSE
					S.opacity = FALSE
				else if (choice == "Window")
					new /obj/structure/window_frame/sumerian(S.loc)
					qdel(S)
				else if (choice == "Corner")
					S.icon_state = "sumerian-corner1"
					base_icon_state = icon_state
					var/choice1 = WWinput(user, "Which corner?","Clay Walls","North-West",list("North-West","North-East","South-West","South-East"))
					if (choice1 == "North-West")
						S.dir = SOUTH
					else if (choice1 == "North-East")
						S.dir = EAST
					else if (choice1 == "South-West")
						S.dir = NORTH
					else if (choice1 == "South-East")
						S.dir = WEST
				return
		else if (stage <= 1)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src))
				if (stage <= 1)
					user << "You finish adding clay to the wall."
					stage += 1
					icon_state = "sumerian-wall_inc[stage]"
					base_icon_state = icon_state
					health = (30*stage)
					qdel(W)
					return
	..()

/obj/covers/brick_wall
	name = "brick wall"
	desc = "A red brick wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "new_brick0"
	base_icon_state = "new_brick"
	adjusts = TRUE
	passable = FALSE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 2250
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 7
	material = "Stone"
	hardness = 92
	buildstack = /obj/item/weapon/clay/advclaybricks/fired

/obj/covers/brick_wall/attackby(var/obj/item/weapon/material/kitchen/utensil/I, var/mob/living/human/U)
	if (istype(I,/obj/item/weapon/material/kitchen/utensil/spoon) || istype(I,/obj/item/weapon/material/kitchen/utensil/fork) || istype(I,/obj/item/weapon/material/kitchen/utensil/chopsticks))
		if (I.shiv < 10)
			I.shiv++
			visible_message("<span class='warning'>[U] sharpens \the [I] on \the [src]!</span>")
			if (I.shiv >= 10)
				U.drop_from_inventory(I)
				var/obj/item/weapon/material/kitchen/utensil/knife/shank/SHK = new /obj/item/weapon/material/kitchen/utensil/knife/shank(U,I.material.name)
				U.put_in_hands(SHK)
				U << "\The [I] turns into a shank."
				qdel(I)
	..()


/obj/covers/cement_wall
	name = "concrete wall"
	desc = "A concrete wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "cement_wall0"
	base_icon_state = "cement_wall"
	passable = FALSE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 3250 //until there are stronger alternatives.
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 13
	material = "Stone"
	hardness = 95
	adjusts = TRUE
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement

/obj/covers/cement_wall/attackby(var/obj/item/weapon/material/kitchen/utensil/I, var/mob/living/human/U)
	if (istype(I,/obj/item/weapon/material/kitchen/utensil/spoon) || istype(I,/obj/item/weapon/material/kitchen/utensil/fork) || istype(I,/obj/item/weapon/material/kitchen/utensil/chopsticks))
		if (I.shiv < 10)
			I.shiv++
			visible_message("<span class='warning'>[U] sharpens \the [I] on \the [src]!</span>")
			if (I.shiv >= 10)
				U.drop_from_inventory(I)
				var/obj/item/weapon/material/kitchen/utensil/knife/shank/SHK = new /obj/item/weapon/material/kitchen/utensil/knife/shank(U,I.material.name)
				U.put_in_hands(SHK)
				U << "\The [I] turns into a shank."
				qdel(I)
	..()

/obj/covers/cement_wall/incomplete
	name = "incomplete concrete wall"
	desc = "A cement brick wall."
	icon = 'icons/turf/walls.dmi'
	base_icon_state = "cement_wall_inc"
	icon_state = "cement_wall_inc0"
	adjusts = FALSE
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 80
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement

/obj/covers/cement_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/advclaybricks/fired/cement))
		user << "You start adding cement to the wall..."
		if (do_after(user, 20, src) && W)
			user << "You finish adding cement to the wall, completing it."
			qdel(W)
			new /obj/covers/cement_wall(loc)
			qdel(src)
			return
	..()

/obj/covers/brick_wall/incomplete
	name = "incomplete brick wall"
	desc = "A red brick wall."
	icon = 'icons/turf/walls.dmi'
	base_icon_state = "new_brick_inc"
	icon_state = "new_brick_inc0"
	adjusts = FALSE
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 80
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	material = "Stone"

/obj/covers/brick_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/advclaybricks/fired))
		user << "You start adding bricks to the wall..."
		if (do_after(user, 20, src) && W)
			user << "You finish adding bricks to the wall, completing it."
			var/choice = WWinput(user, "What type of wall?","Brick Walls","Wall",list("Wall","Window","Full Window"))
			if (choice == "Wall")
				qdel(W)
				new /obj/covers/brick_wall(loc)
				qdel(src)
				return
			else if (choice == "Window")
				qdel(W)
				new /obj/structure/window_frame/brick(loc)
				qdel(src)
				return
			else if (choice == "Full Window")
				qdel(W)
				new /obj/structure/window_frame/brickfull(loc)
				qdel(src)
				return
	..()

/obj/covers/generic_wall
	name = "simple wall"
	desc = "A generic wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "generic0"
	base_icon_state = "generic"
	passable = FALSE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 1000
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 13
	material = "Stone"
	hardness = 95
	adjusts = TRUE
	buildstack = /obj/item/weapon/clay/advclaybricks/fired/cement



/obj/covers/metal
	name = "metal wall"
	desc = "A wall of metal panelling."
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "metal0"
	base_icon_state = "metal"
	adjusts = TRUE
	passable = FALSE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 999999
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 100
	material = "Stone"
	hardness = 100

/obj/covers/shipwindow
	name = "windscreen"
	desc = "A gap large gap in the structure of the ship skinned with a windscreen."
	icon = 'icons/obj/windows.dmi'
	icon_state = "windowmetal"
	base_icon_state = "windowmetal"
	adjusts = FALSE
	passable = FALSE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	amount = 0
	layer = 3
	health = 999999
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 100
	material = "Stone"
	hardness = 100