/* Doors*/

/obj/covers/saloon_door
	name = "saloon door"
	desc = "A wood door."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "saloon"
	passable = TRUE
	not_movable = TRUE
	density = FALSE
	opacity = FALSE
	amount = 2
	layer = 3
	health = 90
	wall = FALSE
	explosion_resistance = 3
	material = "Wood"


/obj/covers/saloon_door/Crossed(mob/living/human/M as mob )
	if (ismob(M) && !isghost(M) && M.mob_size >= MOB_MEDIUM)
		visible_message("[M] pushes \the [src].","You push \the [src]")
		icon_state = "saloon_opening"
		update_icon()
		spawn(20)
			icon_state = "saloon"
			update_icon()

/* Doors - End*/

/obj/covers/wood_wall/oriental/doorway
	name = "oriental doorway"
	desc = "A east-oriental style doorway."
	icon = 'icons/turf/walls.dmi'
	icon_state = "oriental-door"
	density = FALSE
	opacity = FALSE
	health = 180

/obj/covers/wood_wall/bamboo/door
	name = "bamboo doorway"
	desc = "A doorway made from bamboo."
	icon = 'icons/obj/bamboostuff.dmi'
	icon_state = "bamboo-door"
	density = FALSE
	opacity = FALSE
	health = 80
	amount = 3
	layer = 3
	health = 70
	wall = TRUE
	explosion_resistance = 3
	material = "Wood"
	hardness = 40

/obj/covers/sandstone_wall/classic/archway
	name = "sandstone block archway"
	desc = "A sandstone block archway."
	icon_state = "sandstone_block_archway"
	base_icon_state = "sandstone_block_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/sandstone_wall/classic/archway/red
	name = "red sandstone block archway"
	desc = "red sandstone stone block archway."
	icon_state = "redsandstone_block_archway"
	base_icon_state = "redsandstone_block_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/sandstone_wall/egyptian/archway
	name = "egyptian archway"
	desc = "A egyptian style sandstone archway."
	icon_state = "egyptian_archway"
	base_icon_state = "egyptian_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/stone_wall/classic/archway
	name = "stone block archway"
	desc = "A stone block archway."
	icon_state = "stone_block_archway"
	base_icon_state = "stone_block_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/stone_wall/classic/archway/marble
	name = "marble block archway"
	desc = "A marble block archway."
	icon_state = "marble_block_archway"
	base_icon_state = "marble_block_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/marble_wall/grecian/archway
	name = "grecian archway"
	desc = "A impressive grecian archway."
	icon_state = "grecian_archway"
	base_icon_state = "grecian_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/marble_wall/grecian/archway/modern
	name = "grand marble archway"
	desc = "A impressive marble archway."

/obj/covers/stone_wall/brick/archway
	name = "stone brick archway"
	desc = "A stone brick archway."
	icon_state = "new_stonebrick_archway"
	base_icon_state = "new_stonebrick_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/obj/covers/stone_wall/fortress/archway
	name = "fortress brick archway"
	desc = "A fortress brick archway."
	icon_state = "fortress_brickwall_archway"
	base_icon_state = "fortress_brickwall_archway"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE
