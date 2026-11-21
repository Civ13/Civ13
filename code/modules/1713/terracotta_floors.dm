// Terracotta floor tiles: clay shaped into tiles, fired in a kiln, then laid as
// a floor. The tiles are an ordinary material stack, so the floors go through
// the same placement, storey and salvage rules as every other built floor.

/material/terracotta
	name = "terracotta"
	display_name = "terracotta"
	icon_base = "new_stonebrick"
	icon_colour = "#9a6048"
	hardness = 40
	integrity = 250
	weight = 9
	shard_type = SHARD_STONE_PIECE
	door_icon_base = "stone"
	sheet_singular_name = "tile"
	sheet_plural_name = "tiles"
	stack_type = /obj/item/stack/material/terracotta

/obj/item/stack/material/terracotta
	name = "terracotta tile"
	desc = "Kiln-fired clay floor tiles."
	icon_state = "sheet-terracotta-tile"
	default_type = "terracotta"
	value = 2

/obj/item/weapon/clay/floortiles
	name = "unfired terracotta tiles"
	desc = "Clay pressed into flat floor tiles. Fire them in a kiln."
	icon_state = "unfired_claybricks"
	result = /obj/item/stack/material/terracotta
	loose_pile_max = LOOSE_PILE_MAX

// A pile of unfired tiles fires into stacks holding the same count. They are
// made unmerged so the kiln can track each one it is handed.
/obj/item/weapon/clay/floortiles/fired_result(atom/where)
	var/left = max(1, amount)
	var/obj/item/stack/material/terracotta/last
	while (left > 0)
		last = new result(where, min(left, initial(last.max_amount)), FALSE)
		left -= last.amount
	return last

// Border and corner pieces are laid facing south; this turns them into place.
/obj/covers/stone/slab/decorative/terracotta/New()
	..()
	if (!directional_border)
		verbs -= /obj/covers/stone/slab/decorative/terracotta/verb/rotate_border

/obj/covers/stone/slab/decorative/terracotta/verb/rotate_border()
	set name = "Rotate Terracotta Border"
	set category = null
	set src in oview(1)
	if (!directional_border || !isliving(usr) || usr.incapacitated() || !usr.Adjacent(src))
		return
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return
	// Diagonal construction facings use their north/south component.
	var/cardinal_dir = dir & (NORTH | SOUTH)
	if (!cardinal_dir)
		cardinal_dir = dir
	set_dir(turn(cardinal_dir, 90))
