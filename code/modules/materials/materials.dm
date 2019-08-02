/*
	MATERIAL DATUMS
	This data is used by various parts of the game for basic physical properties and behaviors
	of the metals/materials used for constructing many objects. Each var is commented and should be pretty
	self-explanatory but the various object types may have their own documentation. ~Z

	PATHS THAT USE DATUMS
		turf/simulated/wall
		obj/item/weapon/material
		obj/structure/barricade
		obj/item/stack/material
		obj/structure/table

	VALID ICONS
		WALLS
			stone
			metal
			solid
			cult
			wood
		DOORS
			stone
			metal
			resin
			wood
*/

// Assoc list containing all material datums indexed by name.
var/list/name_to_material

//Returns the material the object is made of, if applicable.
//Will we ever need to return more than one value here? Or should we just return the "dominant" material.
/obj/proc/get_material()
	return null

//mostly for convenience
/obj/proc/get_material_name()
	var/material/material = get_material()
	if (material)
		return material.name

// Builds the datum list above.
/proc/populate_material_list(force_remake=0)
	if (name_to_material && !force_remake) return // Already set up!
	name_to_material = list()
	for (var/type in typesof(/material) - /material)
		var/material/new_mineral = new type
		if (!new_mineral.name)
			continue
		name_to_material[lowertext(new_mineral.name)] = new_mineral
	return TRUE

// Safety proc to make sure the material list exists before trying to grab from it.
/proc/get_material_by_name(name)
	if (!name_to_material)
		populate_material_list()
	return name_to_material[name]

/proc/material_display_name(name)
	var/material/material = get_material_by_name(name)
	if (material)
		return material.display_name
	return null

// Material definition and procs follow.
/material
	var/name	                          // Unique name for use in indexing the list.
	var/display_name                      // Prettier name for display.
	var/use_name
	var/flags = FALSE                         // Various status modifiers.
	var/sheet_singular_name = "sheet"
	var/sheet_plural_name = "sheets"

	// Shards/tables/structures
	var/shard_type = SHARD_SHRAPNEL       // Path of debris object.
	var/shard_icon                        // Related to above.
	var/shard_can_repair = TRUE              // Can shards be turned into sheets with a welder?
	var/list/recipes                      // Holder for all recipes usable with a sheet of this material.
	var/destruction_desc = "breaks apart" // Fancy string for barricades/tables/objects exploding.

	// Icons
	var/icon_colour                                      // Colour applied to products of this material.
	var/icon_base = "metal"                              // Wall and table base icon tag. See header.
	var/door_icon_base = "metal"                         // Door base icon tag. See header.
	var/icon_reinf = "reinf_metal"                       // Overlay used

	// Attributes
	var/cut_delay = FALSE            // Delay in ticks when cutting through this wall.
	var/radioactivity            // Radiation var. Used in wall and object processing to irradiate surroundings.
	var/ignition_point           // K, point at which the material catches on fire.
	var/melting_point = 1800     // K, walls will take damage if they're next to a fire hotter than this
	var/integrity = 150          // General-use HP value for products.
	var/opacity = TRUE              // Is the material transparent? 0.5< makes transparent walls/doors.
	var/explosion_resistance = 5 // Only used by walls currently.
	var/conductive = TRUE           // Objects with this var add CONDUCTS to flags on spawn.
	var/list/composite_material  // If set, object matter var will be a list containing these values.

	// Placeholder vars for the time being, todo properly integrate windows/light tiles/rods.
	var/created_window
	var/rod_product
	var/wire_product
//	var/list/window_options = list()

	// Damage values.
	var/hardness = 60            // Prob of wall destruction by hulk, used for edge damage in weapons.
	var/weight = 20              // Determines blunt damage/throwforce for weapons.

	// Noise when someone is faceplanted onto a table made of this material.
	var/tableslam_noise = 'sound/weapons/tablehit1.ogg'
	// Noise made when a simple door made of this material opens or closes.
	var/dooropen_noise = 'sound/effects/stonedoor_openclose.ogg'
	// Noise made when you hit structure made of this material.
	var/hitsound = 'sound/weapons/genhit.ogg'
	// Path to resulting stacktype. Todo remove need for this.
	var/stack_type
	// Wallrot crumble message.
	var/rotting_touch_message = "crumbles under your touch"

// Placeholders for light tiles and rglass.
/material/proc/build_rod_product(var/mob/user, var/obj/item/stack/used_stack, var/obj/item/stack/target_stack)
	if (!rod_product)
		user << "<span class='warning'>You cannot make anything out of \the [target_stack]</span>"
		return
	if (used_stack.get_amount() < 1 || target_stack.get_amount() < 1)
		user << "<span class='warning'>You need one rod and one sheet of [display_name] to make anything useful.</span>"
		return
	used_stack.use(1)
	target_stack.use(1)
	var/obj/item/stack/S = new rod_product(get_turf(user))
	S.add_fingerprint(user)
	S.add_to_stacks(user)

/material/proc/build_wired_product(var/mob/user, var/obj/item/stack/used_stack, var/obj/item/stack/target_stack)
	if (!wire_product)
		user << "<span class='warning'>You cannot make anything out of \the [target_stack]</span>"
		return
	if (used_stack.get_amount() < 5 || target_stack.get_amount() < 1)
		user << "<span class='warning'>You need five wires and one sheet of [display_name] to make anything useful.</span>"
		return

	used_stack.use(5)
	target_stack.use(1)
	user << "<span class='notice'>You attach wire to the [name].</span>"
	var/obj/item/product = new wire_product(get_turf(user))
	if (!(user.l_hand && user.r_hand))
		user.put_in_hands(product)

// Make sure we have a display name and shard icon even if they aren't explicitly set.
/material/New()
	..()
	if (!display_name)
		display_name = name
	if (!use_name)
		use_name = display_name
	if (!shard_icon)
		shard_icon = shard_type
/*
// This is a placeholder for proper integration of windows/windoors into the system.
/material/proc/build_windows(var/mob/living/user, var/obj/item/stack/used_stack)
	return FALSE
*/
// Weapons handle applying a divisor for this value locally.
/material/proc/get_blunt_damage()
	return weight //todo

// Return the matter comprising this material.
/material/proc/get_matter()
	var/list/temp_matter = list()
	if (islist(composite_material))
		for (var/material_string in composite_material)
			temp_matter[material_string] = composite_material[material_string]
	else if (SHEET_MATERIAL_AMOUNT)
		temp_matter[name] = SHEET_MATERIAL_AMOUNT
	return temp_matter

// As above.
/material/proc/get_edge_damage()
	return hardness //todo

// Currently used for weapons and objects made of uranium to irradiate things.
/material/proc/products_need_process()
	return (radioactivity>0) //todo

// Used by walls when qdel()ing to avoid neighbor merging.
/material/placeholder
	name = "placeholder"

// Places a girder object when a wall is dismantled, also applies reinforced material.

// General wall debris product placement.
// Not particularly necessary aside from snowflakey cult girders.
/material/proc/place_dismantled_product(var/turf/target,var/is_devastated)
	for (var/x=1;x<(is_devastated?2:3);x++)
		place_sheet(target)

// Debris product. Used ALL THE TIME.
/material/proc/place_sheet(var/turf/target)
	if (stack_type)
		return new stack_type(target)

// As above.
/material/proc/place_shard(var/turf/target)
	if (shard_type)
		return new /obj/item/weapon/material/shard(target, name)

// Used by walls and weapons to determine if they break or not.
/material/proc/is_brittle()
	return !!(flags & MATERIAL_BRITTLE)

/material/proc/combustion_effect(var/turf/T, var/temperature)
	return

// Datum definitions follow.

/material/diamond
	name = "diamond"
	stack_type = /obj/item/stack/material/diamond
	flags = MATERIAL_UNMELTABLE
	cut_delay = 60
	icon_colour = "#00FFE1"
	opacity = 0.4
	shard_type = SHARD_SHARD
	tableslam_noise = 'sound/effects/Glasshit.ogg'
	hardness = 100

/material/barbedwire
	name = "barbedwire"
	stack_type = /obj/item/stack/material/barbwire
	flags = MATERIAL_UNMELTABLE
	cut_delay = 10
	icon_colour = "#FFFFFF"
	shard_type = SHARD_SHARD
	tableslam_noise = 'sound/effects/Glasshit.ogg'
	hardness = 30

/material/rope
	name = "rope"
	stack_type = /obj/item/stack/material/rope
	flags = MATERIAL_UNMELTABLE
	cut_delay = 5
	icon_colour = "#FFFFFF"
	shard_type = null
	tableslam_noise = null
	hardness = 10

	sheet_singular_name = "coil"
	sheet_plural_name = "coils"

/material/tobacco
	name = "tobacco"
	stack_type = /obj/item/stack/material/tobacco
	flags = MATERIAL_UNMELTABLE
	cut_delay = 5
	icon_colour = "#FFFFFE"
	shard_type = null
	tableslam_noise = null
	hardness = 10

	sheet_singular_name = "leave"
	sheet_plural_name = "leaves"


/material/coca
	name = "coca"
	stack_type = /obj/item/stack/material/coca
	flags = MATERIAL_UNMELTABLE
	cut_delay = 5
	icon_colour = "#faeff1"
	shard_type = null
	tableslam_noise = null
	hardness = 10

	sheet_singular_name = "leave"
	sheet_plural_name = "leaves"

/material/poppy
	name = "poppy"
	stack_type = /obj/item/stack/material/poppy
	flags = MATERIAL_UNMELTABLE
	cut_delay = 5
	icon_colour = "#2b1d0e"
	shard_type = null
	tableslam_noise = null
	hardness = 10

	sheet_singular_name = "plant"
	sheet_plural_name = "plants"

/material/gold
	name = "gold"
	stack_type = /obj/item/stack/material/gold
	icon_colour = "#EDD12F"
	weight = 24
	hardness = 70
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"

/material/copper
	name = "copper"
	icon_colour = "#b87333"
	stack_type = /obj/item/stack/material/copper
	weight = 14
	hardness = 42
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"

/material/plastic
	name = "plastic"
	icon_colour = "#dddddd"
	stack_type = /obj/item/stack/material/plastic
	weight = 8
	hardness = 36
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"

/material/tin
	name = "tin"
	icon_colour = "#d3d4d5"
	stack_type = /obj/item/stack/material/tin
	weight = 11
	hardness = 40
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"

/material/bronze
	name = "bronze"
	icon_colour = "#7c4611"
	stack_type = /obj/item/stack/material/bronze
	weight = 17
	hardness = 47
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"

/material/lead
	name = "lead"
	icon_colour = "#444f53"
	stack_type = /obj/item/stack/material/lead
	weight = 30
	hardness = 35
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"

/material/silver
	name = "silver"
	stack_type = /obj/item/stack/material/silver
	icon_colour = "#D1E6E3"
	weight = 22
	hardness = 65

	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"

/material/sandstone
	name = "sandstone"
	stack_type = /obj/item/stack/material/sandstone
	icon_base = "stone"
	icon_reinf = "reinf_stone"
	icon_colour = "#D9C179"
	shard_type = SHARD_STONE_PIECE
	weight = 22
	integrity = 500
	hardness = 45
	door_icon_base = "stone"
	sheet_singular_name = "brick"
	sheet_plural_name = "bricks"

/material/stone
	name = "stone"
	hardness = 50
	weight = 22
	integrity = 500
	shard_type = SHARD_STONE_PIECE
	icon_base = "stone"
	icon_reinf = "reinf_stone"
	icon_colour = "#808080"
	sheet_singular_name = "block"
	sheet_plural_name = "blocks"
	stack_type = /obj/item/stack/material/stone
	door_icon_base = "stone"

/material/bone
	name = "bone"
	hardness = 45
	icon_colour = "#ccd1c4"
	sheet_singular_name = "piece"
	sheet_plural_name = "pieces"

/material/stone/stonebrick
	name = "brick"
	icon_base = "newbrick"
	icon_colour = "#808080"
	stack_type = /obj/item/stack/material/marble

/material/stone/marble
	name = "marble"
	icon_colour = "#AAAAAA"
	weight = 26
	hardness = 100
	integrity = 201 //hack to stop kitchen benches being flippable, todo: refactor into weight system
	stack_type = /obj/item/stack/material/marble

/material/steel
	name = DEFAULT_WALL_MATERIAL
	stack_type = /obj/item/stack/material/steel
	integrity = 300
	hardness = 60
	icon_base = "solid"
	icon_reinf = "reinf_over"
	icon_colour = "#666666"
	hitsound = 'sound/weapons/genhit.ogg'

/material/glass
	name = "glass"
	stack_type = /obj/item/stack/material/glass
	flags = MATERIAL_BRITTLE
	icon_colour = "#00E1FF"
	opacity = 0.3
	integrity = 100
	shard_type = SHARD_SHARD
	tableslam_noise = 'sound/effects/Glasshit.ogg'
	hardness = 30
	weight = 15
	door_icon_base = "stone"
	destruction_desc = "shatters"
//	window_options = list("One Direction" = 1, "Full Window" = 4)
	created_window = /obj/structure/window/classic
	rod_product = /obj/item/stack/material/glass/reinforced
	hitsound = 'sound/effects/Glasshit.ogg'

/material/glass/proc/is_reinforced()
	return (hardness > 35) //todo

/material/iron
	name = "iron"
	icon_base = "metal"
	stack_type = /obj/item/stack/material/iron
	icon_colour = "#5C5454"
	weight = 22
	hardness = 55
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	hitsound = 'sound/weapons/smash.ogg'

/material/iron/indestructable
	name = "indestructable"
	icon_base = "metal"
	integrity = 1000000
	hardness = 1000000
	melting_point = 1000000

/material/wood
	name = "wood"
	stack_type = /obj/item/stack/material/wood
	icon_colour = "#824B28"
	integrity = 50
	icon_base = "wood"
	explosion_resistance = 2
	shard_type = SHARD_SPLINTER
	shard_can_repair = FALSE // you can't weld splinters back into planks
	hardness = 40
	weight = 18
	melting_point = T0C+300 //okay, not melting in this case, but hot enough to destroy wood
	ignition_point = T0C+288

	dooropen_noise = 'sound/effects/doorcreaky.ogg'
	door_icon_base = "wood"
	destruction_desc = "splinters"
	sheet_singular_name = "plank"
	sheet_plural_name = "planks"
	hitsound = 'sound/effects/woodhit.ogg'

/material/wood/hard
	name = "hardwood"
	integrity = 175
	hardness = 200

/material/wood/soft
	name = "softwood"
	integrity = 80
	hardness = 90
	icon_colour = "#D2BA9C"

/material/clay
	name = "clay"
	integrity = 60
	hardness = 90
	icon_colour = "#734222"

/material/wood/straw
	hardness = 35
	icon_colour = "#BCB9B4"
	integrity = 55
	name = "straw"
//	icon_base = "straw"

/material/wood/log
	name = "log"
	integrity = 175
	hardness = 200
	door_icon_base = "rustic"

/material/paper
	name = "paper"
	hardness = 25
	integrity = 35
	door_icon_base = "shoji"
	hitsound = 'sound/effects/cardboardpunch.ogg'
	melting_point = T0C+300
	ignition_point = T0C+288

/material/cloth //todo
	name = "cloth"
	hardness = 10

	door_icon_base = "wood"
	ignition_point = T0C+232
	melting_point = T0C+300
	flags = MATERIAL_PADDING

/material/woolcloth //todo
	name = "woolcloth"
	hardness = 10

	door_icon_base = "wood"
	ignition_point = T0C+232
	melting_point = T0C+300
	flags = MATERIAL_PADDING

/material/electronics
	name = "electronic"
	icon_colour = "#272727"
	stack_type = /obj/item/stack/material/electronics
	weight = 14
	hardness = 20
	sheet_singular_name = "circuit"
	sheet_plural_name = "circuits"

//TODO PLACEHOLDERS:
/material/leather
	name = "leather"
	icon_colour = "#5C4831"

	flags = MATERIAL_PADDING
	ignition_point = T0C+300
	melting_point = T0C+300
	hardness = 25

/material/pelt
	name = "pelt"
	use_name = "pelt"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt

/material/bearpelt/black
	name = "bearpelt"
	use_name = "bear"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/bearpelt/black

/material/bearpelt/white
	name = "whitebearpelt"
	use_name = "white bear"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/bearpelt/white

/material/bearpelt/brown
	name = "brownbearpelt"
	use_name = "brown bear"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/bearpelt/brown

/material/wolfpelt
	name = "wolfpelt"
	use_name = "wolf"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/wolfpelt

/material/catpelt
	name = "catpelt"
	use_name = "cat"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/catpelt

/material/monkeypelt
	name = "monkeypelt"
	use_name = "monkey"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/monkeypelt

/material/humanpelt
	name = "humanpelt"
	use_name = "human"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "skin"
	sheet_plural_name = "skins"
	stack_type = /obj/item/stack/material/humanpelt

/material/antpelt
	name = "antpelt"
	use_name = "ant"
	icon_colour = "#0C0000"
	ignition_point = T0C+700
	melting_point = T0C+700
	hardness = 50
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/antpelt

/material/chitin
	name = "chitin"
	use_name = "chitin"
	icon_colour = "#3F0000"
	ignition_point = T0C+800
	melting_point = T0C+800
	hardness = 60
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/chitin

/material/gorillapelt
	name = "gorillapelt"
	use_name = "gorilla"
	icon_colour = "#8C7E6E"
	ignition_point = T0C+400
	melting_point = T0C+400
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/gorillapelt

/material/orcpelt
	name = "orcnpelt"
	use_name = "orc"
	icon_colour = "#013220"
	ignition_point = T0C+700
	melting_point = T0C+700
	hardness = 45
	sheet_singular_name = "skin"
	sheet_plural_name = "skins"
	stack_type = /obj/item/stack/material/orcpelt

/material/carpet
	name = "carpet"
	display_name = "comfy"
	use_name = "red upholstery"
	icon_colour = "#DA020A"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	sheet_singular_name = "tile"
	sheet_plural_name = "tiles"
	hardness = 12

/material/cotton
	name = "cotton"
	hardness = 6
	stack_type = /obj/item/stack/material/cotton
	display_name ="cotton"
	icon_colour = "#FFFFFF"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	sheet_singular_name = "stack"
	sheet_plural_name = "stacks"

/material/wool
	name = "wool"
	hardness = 6
	stack_type = /obj/item/stack/material/wool
	display_name ="wool"
	icon_colour = "#F1F1F1"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	sheet_singular_name = "pile"
	sheet_plural_name = "piles"

/material/cloth_teal
	name = "teal"
	display_name ="teal"
	use_name = "teal cloth"
	icon_colour = "#00EAFA"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	hardness = 6

/material/cloth_black
	name = "black"
	display_name = "black"
	use_name = "black cloth"
	icon_colour = "#505050"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	hardness = 6

/material/cloth_green
	name = "green"
	display_name = "green"
	use_name = "green cloth"
	icon_colour = "#01C608"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	hardness = 6

/material/cloth_puple
	name = "purple"
	display_name = "purple"
	use_name = "purple cloth"
	icon_colour = "#9C56C4"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	hardness = 6

/material/cloth_blue
	name = "blue"
	display_name = "blue"
	use_name = "blue cloth"
	icon_colour = "#6B6FE3"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	hardness = 6

/material/cloth_beige
	name = "beige"
	display_name = "beige"
	use_name = "beige cloth"
	icon_colour = "#E8E7C8"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	hardness = 6

/material/cloth_lime
	name = "lime"
	display_name = "lime"
	use_name = "lime cloth"
	icon_colour = "#62E36C"
	flags = MATERIAL_PADDING
	ignition_point = T0C+232
	melting_point = T0C+300
	hardness = 6
