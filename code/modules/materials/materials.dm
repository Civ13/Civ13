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
	var/name							  // Unique name for use in indexing the list.
	var/display_name					  // Prettier name for display.
	var/use_name
	var/flags = FALSE						 // Various status modifiers.
	var/sheet_singular_name = "sheet"
	var/sheet_plural_name = "sheets"

	// Shards/tables/structures
	var/shard_type = SHARD_SHRAPNEL	   // Path of debris object.
	var/shard_icon						// Related to above.
	var/shard_can_repair = TRUE			  // Can shards be turned into sheets with a welder?
	var/list/recipes					  // Holder for all recipes usable with a sheet of this material.
	var/destruction_desc = "breaks apart" // Fancy string for barricades/tables/objects exploding.

	// Icons
	var/icon_colour									  // Colour applied to products of this material.
	var/icon_base = "metal"							  // Wall and table base icon tag. See header.
	var/door_icon_base = "metal"						 // Door base icon tag. See header.
	var/icon_reinf = "reinf_metal"					   // Overlay used

	// Attributes
	var/cut_delay = FALSE			// Delay in ticks when cutting through this wall.
	var/integrity = 150		  // General-use HP value for products.
	var/opacity = TRUE			  // Is the material transparent? 0.5< makes transparent walls/doors.
	var/explosion_resistance = 5 // Only used by walls currently.
	//var/conductive = TRUE		   // Objects with this var add CONDUCTS to flags on spawn. NEVER USED!
	var/list/composite_material  // If set, object matter var will be a list containing these values.

	// Placeholder vars for the time being, todo properly integrate windows/light tiles/rods.
	var/created_window
	var/rod_product
	var/wire_product
//	var/list/window_options = list()

	// Damage values.
	var/hardness = 60			// Prob of wall destruction by hulk, used for edge damage in weapons.
	var/weight = 20			  // Determines blunt damage/throwforce for weapons.

	// Noise when someone is faceplanted onto a table made of this material.
	var/tableslam_noise = 'sound/weapons/tablehit1.ogg'
	// Noise made when a simple door made of this material opens or closes.
	var/dooropen_noise = 'sound/effects/stonedoor_openclose.ogg'
	// Noise made when you hit structure made of this material.
	var/hitsound = 'sound/weapons/genhit.ogg'
	// Path to resulting stacktype. Todo remove need for this.
	var/stack_type

// Placeholders for light tiles and rglass.
/material/proc/build_rod_product(var/mob/user, var/obj/item/stack/used_stack, var/obj/item/stack/target_stack)
	if (!rod_product)
		user << "<span class='warning'>You cannot make anything out of \the [target_stack]</span>"
		return
	if (used_stack.amount < 1 || target_stack.amount < 1)
		user << "<span class='warning'>You need one rod and one sheet of [display_name] to make anything useful.</span>"
		return
	used_stack.use(1)
	target_stack.use(1)
	var/obj/item/stack/S = new rod_product(get_turf(user))
	S.add_fingerprint(user)
	for(var/obj/item/stack/T in get_turf(user))
		if(T == src)
			T.merge(src)

/material/proc/build_wired_product(var/mob/user, var/obj/item/stack/used_stack, var/obj/item/stack/target_stack)
	if (!wire_product)
		user << "<span class='warning'>You cannot make anything out of \the [target_stack]</span>"
		return
	if (used_stack.amount < 5 || target_stack.amount < 1)
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
	icon_colour = "#00FFE1"
	hardness = 100
	cut_delay = 60
	opacity = 0.4
	shard_type = SHARD_SHARD
	tableslam_noise = 'sound/effects/Glasshit.ogg'
	stack_type = /obj/item/stack/material/diamond
	flags = MATERIAL_UNMELTABLE
	integrity = 30000

/material/obsidian
	name = "obsidian"
	icon_colour = "#060606"
	hardness = 85
//	door_icon_base = "stone" (too dark)
	sheet_singular_name = "cut rock"
	sheet_plural_name = "cut rocks"
	stack_type = /obj/item/stack/material/obsidian
	integrity = 15000

/material/barbedwire
	name = "barbedwire"
	icon_colour = "#FFFFFF"
	hardness = 30
	cut_delay = 10
	shard_type = SHARD_SHARD
	tableslam_noise = 'sound/effects/Glasshit.ogg'
	stack_type = /obj/item/stack/material/barbwire
	flags = MATERIAL_UNMELTABLE

/material/rope
	name = "rope"
	icon_colour = "#FFFFFF"
	hardness = 10
	cut_delay = 5
	shard_type = null
	tableslam_noise = null
	sheet_singular_name = "coil"
	sheet_plural_name = "coils"
	stack_type = /obj/item/stack/material/rope
	flags = MATERIAL_UNMELTABLE

/material/tobacco
	name = "tobacco"
	icon_colour = "#FFFFFE"
	hardness = 10
	cut_delay = 5
	shard_type = null
	tableslam_noise = null
	sheet_singular_name = "leave"
	sheet_plural_name = "leaves"
	stack_type = /obj/item/stack/material/tobacco
	flags = MATERIAL_UNMELTABLE

/material/hemp
	name = "hemp"
	icon_colour = "#32cd32" //lime green
	hardness = 10
	cut_delay = 5
	shard_type = null
	tableslam_noise = null
	sheet_singular_name = "leaf"
	sheet_plural_name = "leaves"
	stack_type = /obj/item/stack/material/hemp
	flags = MATERIAL_UNMELTABLE

/material/flax
	name = "flax"
	icon_colour = "#5f9ea0" //desaturated dark cyan.
	hardness = 10
	cut_delay = 5
	shard_type = null
	tableslam_noise = null
	sheet_singular_name = "bundle"
	sheet_plural_name = "bundles"
	stack_type = /obj/item/stack/material/flax
	flags = MATERIAL_UNMELTABLE

/material/leaf
	name = "leaf"
	icon_colour = "#556b2f" // dark olive-green
	hardness = 10
	cut_delay = 5
	shard_type = null
	tableslam_noise = null
	sheet_singular_name = "bundle"
	sheet_plural_name = "bundles"
	stack_type = /obj/item/stack/material/leaf
	flags = MATERIAL_UNMELTABLE

/material/leaf/palm
	name = "palm"
	icon_colour = "#adff2f" //green yellow
	stack_type = /obj/item/stack/material/leaf/palm

/material/leaf/fern
	name = "fern"
	icon_colour = "#006400" //dark green
	stack_type = /obj/item/stack/material/leaf/fern

/material/coca
	name = "coca"
	icon_colour = "#faeff1"
	hardness = 10
	cut_delay = 5
	shard_type = null
	tableslam_noise = null
	sheet_singular_name = "leaf"
	sheet_plural_name = "leaves"
	stack_type = /obj/item/stack/material/coca
	flags = MATERIAL_UNMELTABLE

/material/poppy
	name = "poppy"
	icon_colour = "#2b1d0e"
	hardness = 10
	cut_delay = 5
	shard_type = null
	tableslam_noise = null
	sheet_singular_name = "plant"
	sheet_plural_name = "plants"
	stack_type = /obj/item/stack/material/poppy
	flags = MATERIAL_UNMELTABLE

/material/gold
	name = "gold"
	icon_colour = "#EDD12F"
	hardness = 70
	weight = 24
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	stack_type = /obj/item/stack/material/gold
	integrity = 75

/material/copper
	name = "copper"
	icon_colour = "#b87333"
	hardness = 42
	weight = 14
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	stack_type = /obj/item/stack/material/copper
	integrity = 90

/material/plastic
	name = "plastic"
	icon_colour = "#dddddd"
	hardness = 36
	weight = 8
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/plastic
	integrity = 30

/material/tin
	name = "tin"
	icon_colour = "#d3d4d5"
	hardness = 40
	weight = 11
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	stack_type = /obj/item/stack/material/tin
	integrity = 60

/material/bronze
	name = "bronze"
	icon_colour = "#7c4611"
	hardness = 47
	weight = 17
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	stack_type = /obj/item/stack/material/bronze
	integrity = 150

/material/lead
	name = "lead"
	icon_colour = "#444f53"
	hardness = 35
	weight = 30
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	stack_type = /obj/item/stack/material/lead
	integrity = 50

/material/silver
	name = "silver"
	icon_colour = "#D1E6E3"
	hardness = 65
	weight = 22
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	stack_type = /obj/item/stack/material/silver
	integrity = 100

/material/sandstone
	name = "sandstone"
	icon_base = "new_stonebrick"
	icon_colour = "#D9C179"
	hardness = 45
	integrity = 90
	weight = 22
	shard_type = SHARD_STONE_PIECE
	door_icon_base = "stone"
	sheet_singular_name = "block"
	sheet_plural_name = "blocks"
	stack_type = /obj/item/stack/material/sandstone

/material/stone
	name = "stone"
	icon_base = "stone_block_wall"
	icon_colour = "#808080"
	hardness = 50
	integrity = 200
	weight = 22
	shard_type = SHARD_STONE_PIECE
	door_icon_base = "stone"
	sheet_singular_name = "block"
	sheet_plural_name = "blocks"
	stack_type = /obj/item/stack/material/stone

/material/concrete
	name = "concrete"
	icon_base = "cement_wall"
	icon_colour = null
	hardness = 50
	integrity = 400
	weight = 18
	sheet_singular_name = "block"
	sheet_plural_name = "blocks"

/material/stonebrick
	name = "stonebrick"
	display_name = "stone brick"
	icon_base = "new_stonebrick"
	icon_colour = "#808080"
	hardness = 50
	integrity = 450
	weight = 11
	sheet_singular_name = "brick"
	sheet_plural_name = "bricks"
	stack_type = /obj/item/stack/material/stonebrick

/material/brick
	name = "brick"
	display_name = "brick"
	icon_base = "new_brick"
	icon_colour = null
	hardness = 40
	integrity = 350
	weight = 8
	sheet_singular_name = "brick"
	sheet_plural_name = "bricks"

/material/flint
	name = "flint"
	icon_colour = "#6f6a64"
	hardness = 50
	integrity = 110
	weight = 22
	sheet_singular_name = "stone"
	sheet_plural_name = "stones"

/material/bone
	name = "bone"
	icon_colour = "#ccd1c4"
	hardness = 45
	door_icon_base = "bone"
	sheet_singular_name = "piece"
	sheet_plural_name = "pieces"
	dooropen_noise = 'sound/effects/doorcreaky.ogg'
	stack_type = /obj/item/stack/material/bone
	integrity = 55
/*
/material/stone/marble
	name = "marble"
	icon_colour = "#fffcf0" // marble - white
	weight = 26
	integrity = 201 //hack to stop kitchen benches being flippable, todo: refactor into weight system
	hardness = 100
	door_icon_base = "stone"
	stack_type = /obj/item/stack/material/marble
*/

/material/marble
	name = "marble"
	icon_base = "new_stonebrick"
	icon_colour = "#fffcf0" // marble - white
	hardness = 45
	integrity = 160
	weight = 22
	shard_type = SHARD_STONE_PIECE
	door_icon_base = "stone"
	sheet_singular_name = "block"
	sheet_plural_name = "blocks"
	stack_type = /obj/item/stack/material/marble

/material/steel
	name = "steel"
	icon_base = "solid"
	icon_reinf = "reinf_over"
	icon_colour = "#666666"
	hardness = 60
	integrity = 350
	hitsound = 'sound/weapons/genhit.ogg'
	door_icon_base = "metal"
	stack_type = /obj/item/stack/material/steel

/material/glass
	name = "glass"
	icon_colour = "#00E1FF"
	hardness = 30
	integrity = 15
	weight = 15
	opacity = 0.3
	shard_type = SHARD_SHARD
	tableslam_noise = 'sound/effects/Glasshit.ogg'
	hitsound = 'sound/effects/Glasshit.ogg'
	door_icon_base = "stone"
	destruction_desc = "shatters"
	stack_type = /obj/item/stack/material/glass
	flags = MATERIAL_BRITTLE
//	window_options = list("One Direction" = 1, "Full Window" = 4)
	created_window = /obj/structure/window/classic
	rod_product = /obj/item/stack/material/glass/reinforced

/material/glass/proc/is_reinforced()
	return (hardness > 35) //todo

/material/iron
	name = "iron"
	icon_base = "metal"
	icon_colour = "#5C5454"
	hardness = 55
	weight = 22
	door_icon_base = "metal"
	sheet_singular_name = "ingot"
	sheet_plural_name = "ingots"
	hitsound = 'sound/weapons/smash.ogg'
	stack_type = /obj/item/stack/material/iron
	integrity = 250

/material/iron/indestructable
	name = "indestructable"
	icon_base = "metal"
	integrity = 1000000
	hardness = 1000000

/material/wood
	name = "wood"
	icon_base = "wood"
	icon_colour = "#824B28"
	hardness = 40
	integrity = 39
	weight = 18
	explosion_resistance = 2
	shard_type = SHARD_SPLINTER
	shard_can_repair = FALSE // you can't weld splinters back into planks
	door_icon_base = "wood"
	dooropen_noise = 'sound/effects/doorcreaky.ogg'
	destruction_desc = "splinters"
	sheet_singular_name = "plank"
	sheet_plural_name = "planks"
	hitsound = 'sound/effects/woodhit.ogg'
	stack_type = /obj/item/stack/material/wood

/material/wood/hard
	name = "hardwood"
	hardness = 200
	integrity = 175
	icon_base = "wood"
	icon_colour = null
	weight = 13


/material/wood/soft
	name = "softwood"
	hardness = 90
	integrity = 80
	door_icon_base = "wood"
	icon_colour = "#D2BA9C"
	weight = 10

/material/bamboo
	name = "bamboo"
	icon_base = "wood"
	icon_colour = "#414833"
	hardness = 45
	integrity = 45
	weight = 15
	explosion_resistance = 2
	shard_type = SHARD_SPLINTER
	shard_can_repair = FALSE
	dooropen_noise = 'sound/effects/doorcreaky.ogg'
	door_icon_base = "wood"
	hitsound = 'sound/effects/woodhit.ogg'
	destruction_desc = "splinters"
	sheet_singular_name = "bundle"
	sheet_plural_name = "bundles"
	stack_type = /obj/item/stack/material/bamboo

/material/clay
	name = "clay"
	icon_colour = "#734222"
	hardness = 90
	integrity = 60

/material/wood/straw
	name = "straw"
	icon_colour = "#BCB9B4"
	hardness = 35
	integrity = 55
//	icon_base = "straw"

/material/wood/log
	name = "log"
	hardness = 200
	integrity = 175
	door_icon_base = "rustic"

/material/paper
	name = "paper"
	hardness = 25
	integrity = 35
	door_icon_base = "shoji"
	hitsound = 'sound/effects/cardboardpunch.ogg'

/material/cloth
	name = "cloth"
	hardness = 10
	door_icon_base = "wood"
	flags = MATERIAL_PADDING

/material/rettedfabric
	name = "rettedfabric"
	display_name = "retted fabric"
	icon_colour = "#c19a6b"
	hardness = 7
	sheet_singular_name = "bundle"
	sheet_plural_name = "bundles"
	stack_type = /obj/item/stack/material/rettedfabric

/material/rawkevlar
	name = "rawkevlar"
	display_name = "raw kevlar"
	icon_colour = "#fafad2"
	hardness = 7
	sheet_singular_name = "bundle"
	sheet_plural_name = "bundles"
	stack_type = /obj/item/stack/material/rawkevlar

/material/preparedkevlar
	name = "preparedkevlar"
	display_name = "prepared kevlar"
	icon_colour = "#fafad2" //goldenrod faint yellow
	hardness = 7
	sheet_singular_name = "bundle"
	sheet_plural_name = "bundles"
	stack_type = /obj/item/stack/material/preparedkevlar

/material/kevlar
	name = "kevlar"
	display_name = "kevlar"
	icon_colour = "#696969" //dim grey
	hardness = 45
	weight = 15
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/kevlar

/material/woolcloth
	name = "woolcloth"
	hardness = 10
	door_icon_base = "wood"
	flags = MATERIAL_PADDING


/material/rags
	name = "rags"
	icon_colour = "#EBEFFF"
	hardness = 7
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/rags

/material/electronics
	name = "electronic"
	icon_colour = "#272727"
	hardness = 20
	weight = 14
	sheet_singular_name = "circuit"
	sheet_plural_name = "circuits"
	stack_type = /obj/item/stack/material/electronics

//TODO PLACEHOLDERS:
/material/leather
	name = "leather"
	icon_colour = "#5C4831"
	hardness = 25
	weight = 10
	flags = MATERIAL_PADDING

/material/leather/dark
	name = "darkleather"
	use_name = "dark leather"
	icon_colour = "#241C13"

/material/pelt
	name = "pelt"
	use_name = "pelt"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt

/material/bearpelt/black
	name = "bearpelt"
	use_name = "bear"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/bearpelt/black

/material/bearpelt/white
	name = "whitebearpelt"
	use_name = "white bear"
	icon_colour = "#e8e8e8" // "white smoke"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/bearpelt/white

/material/bearpelt/brown
	name = "brownbearpelt"
	use_name = "brown bear"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/bearpelt/brown

/material/wolfpelt
	name = "wolfpelt"
	use_name = "wolf"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/wolfpelt

/material/whitewolfpelt
	name = "white wolfpelt"
	use_name = "wolf"
	icon_colour = "#e8e8e8" // "white smoke"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/wolfpelt/white

/material/catpelt
	name = "catpelt"
	use_name = "cat"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/catpelt

/material/pantherpelt
	name = "pantherpelt"
	use_name = "panther"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/pantherpelt

/material/lionpelt
	name = "lionpelt"
	use_name = "lion"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/lionpelt

/material/gatorpelt
	name = "gatorpelt"
	use_name = "alligator"
	icon_colour = "#443d36"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/gatorpelt

/material/lizardpelt
	name = "lizardpelt"
	use_name = "lizard"
	icon_colour = "#6b8e23" 	//olive drab
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/lizardpelt

/material/monkeypelt
	name = "monkeypelt"
	use_name = "monkey"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/monkeypelt

/material/foxpelt
	name = "foxpelt"
	use_name = "fox"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/foxpelt

/material/whitefoxpelt
	name = "whitefoxpelt"
	use_name = "white fox"
	icon_colour = "#e8e8e8" // "white smoke"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/foxpelt/white

/material/sheeppelt
	name = "sheeppelt"
	use_name = "sheep"
	icon_colour = "#8C7E6E" 	//white
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/sheeppelt

/material/goatpelt
	name = "goatpelt"
	use_name = "goat"
	icon_colour = "#f5f5dc" 	//beige
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/goatpelt

/material/cowpelt
	name = "cowpelt"
	use_name = "cow"
	icon_colour = "#f5f5dc" 	//beige
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/cowpelt

/material/bisonpelt
	name = "bisonpelt"
	use_name = "bison"
	icon_colour = "#8C7E6E" 	//beige
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/bisonpelt

/material/hairlesshide
	name = "hairlesshide"
	use_name = "hairless hide"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/hairlesshide

/*/material/scalelesshide //deactivated for now, prepped up for skinned gatorpelts
	name = "scalelesshide"
	use_name = "scaleless hide"
	icon_colour = "#443d36"


	hardness = 30
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/scalelesshide*/
	/*
/material/gatorscale // In preparation, snakes and other reptiles have other sorts.
	name = "alligator scale"
	icon_colour = "#443d36"

	flags = MATERIAL_PADDING
	ignition_point = T0C+300

	hardness = 25
*/
/material/humanpelt
	name = "humanpelt"
	use_name = "human"
	icon_colour = "#8C7E6E"
	hardness = 30
	sheet_singular_name = "skin"
	sheet_plural_name = "skins"
	stack_type = /obj/item/stack/material/pelt/humanpelt

/material/antpelt
	name = "antpelt"
	use_name = "ant"
	icon_colour = "#0C0000"
	hardness = 50
	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/antpelt

/material/chitin
	name = "chitin"
	use_name = "chitin"
	icon_colour = "#3F0000"
	hardness = 51
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/chitin

/material/gorillapelt
	name = "gorillapelt"
	use_name = "gorilla"
	icon_colour = "#8C7E6E"
	hardness = 30


	sheet_singular_name = "pelt"
	sheet_plural_name = "pelts"
	stack_type = /obj/item/stack/material/pelt/gorillapelt

/material/orcpelt
	name = "orcnpelt"
	use_name = "orc"
	icon_colour = "#013220"
	hardness = 45
	sheet_singular_name = "skin"
	sheet_plural_name = "skins"
	stack_type = /obj/item/stack/material/pelt/orcpelt

/material/carpet
	name = "carpet"
	display_name = "comfy"
	use_name = "red upholstery"
	icon_colour = "#DA020A"
	hardness = 12
	sheet_singular_name = "tile"
	sheet_plural_name = "tiles"
	flags = MATERIAL_PADDING

/material/cotton
	name = "cotton"
	display_name ="cotton"
	icon_colour = "#FFFFFF"
	hardness = 6
	sheet_singular_name = "stack"
	sheet_plural_name = "stacks"
	stack_type = /obj/item/stack/material/cotton
	flags = MATERIAL_PADDING

/material/wool
	name = "wool"
	display_name ="wool"
	icon_colour = "#F1F1F1"
	hardness = 6
	sheet_singular_name = "pile"
	sheet_plural_name = "piles"
	stack_type = /obj/item/stack/material/wool
	flags = MATERIAL_PADDING

/material/cloth_teal
	name = "teal"
	display_name ="teal"
	use_name = "teal cloth"
	icon_colour = "#00EAFA"
	hardness = 6
	flags = MATERIAL_PADDING

/material/cloth_black
	name = "black"
	display_name = "black"
	use_name = "black cloth"
	icon_colour = "#505050"
	hardness = 6
	flags = MATERIAL_PADDING

/material/cloth_green
	name = "green"
	display_name = "green"
	use_name = "green cloth"
	icon_colour = "#01C608"
	hardness = 6
	flags = MATERIAL_PADDING

/material/cloth_puple
	name = "purple"
	display_name = "purple"
	use_name = "purple cloth"
	icon_colour = "#9C56C4"
	hardness = 6
	flags = MATERIAL_PADDING

/material/cloth_blue
	name = "blue"
	display_name = "blue"
	use_name = "blue cloth"
	icon_colour = "#6B6FE3"
	hardness = 6
	flags = MATERIAL_PADDING

/material/cloth_beige
	name = "beige"
	display_name = "beige"
	use_name = "beige cloth"
	icon_colour = "#E8E7C8"
	hardness = 6
	flags = MATERIAL_PADDING

/material/cloth_lime
	name = "lime"
	display_name = "lime"
	use_name = "lime cloth"
	icon_colour = "#62E36C"
	hardness = 6
	flags = MATERIAL_PADDING

/material/crystal
	name = "white_crystal"
	display_name = "white crystal"
	use_name = "white crystal"
	hardness = 75
	flags = MATERIAL_PADDING

/material/crystal/red
	name = "red_crystal"
	display_name = "red crystal"
	use_name = "red crystal"
	hardness = 65
	flags = MATERIAL_PADDING

/material/crystal/blue
	name = "blue_crystal"
	display_name = "blue crystal"
	use_name = "blue crystal"
	hardness = 75
	flags = MATERIAL_PADDING

/material/crystal/magenta
	name = "magenta_crystal"
	display_name = "magenta crystal"
	use_name = "magenta crystal"
	hardness = 75
	flags = MATERIAL_PADDING

/material/crystal/purple
	name = "purple_crystal"
	display_name = "purple crystal"
	use_name = "purple crystal"
	hardness = 75
	flags = MATERIAL_PADDING

/material/crystal/orange
	name = "orange_crystal"
	display_name = "orange crystal"
	use_name = "orange crystal"
	hardness = 75
	flags = MATERIAL_PADDING

/material/crystal/green
	name = "green_crystal"
	display_name = "green crystal"
	use_name = "green crystal"
	hardness = 75
	flags = MATERIAL_PADDING