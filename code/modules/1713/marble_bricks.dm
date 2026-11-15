// Marble bricks: mined marble comes as rough blocks; cutting them into bricks
// is a separate crafting step (brickmaking), like stone bricks.

/material/marblebrick
	name = "marblebrick"
	display_name = "marble"
	icon_base = "new_stonebrick"
	icon_colour = "#fffcf0"
	hardness = 50
	integrity = 450
	weight = 11
	shard_type = SHARD_STONE_PIECE
	door_icon_base = "stone"
	sheet_singular_name = "brick"
	sheet_plural_name = "bricks"
	stack_type = /obj/item/stack/material/marblebrick

/obj/item/stack/material/marblebrick
	name = "marble brick"
	icon_state = "sheet-marble-brick"
	default_type = "marblebrick"
	value = 2

// A wall laid from cut marble bricks. It can be re-carved like a smooth marble wall.
/obj/covers/marble_wall/plain/brick
	name = "marble brick wall"
	desc = "A wall laid from cut marble bricks."
	icon_state = "b_brick_marble_wall"
	buildstack = /obj/item/stack/material/marblebrick
