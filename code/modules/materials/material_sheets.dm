#define SHEET_MATERIAL_AMOUNT 2000
// Stacked resources. They use a material datum for a lot of inherited values.
/obj/item/stack/material
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = ITEM_SIZE_NORMAL
	throw_speed = 3
	throw_range = 3
	max_amount = 50
	can_stack = TRUE
	var/default_type = DEFAULT_WALL_MATERIAL
	var/material/material
	var/perunit = SHEET_MATERIAL_AMOUNT
	var/apply_colour //temp pending icon rewrite
	icon = 'icons/obj/materials.dmi'

/obj/item/stack/material/New()
	..()
	pixel_x = rand(0,4)-4
	pixel_y = rand(0,4)-4
	if (!default_type)
		default_type = DEFAULT_WALL_MATERIAL
	material = get_material_by_name("[default_type]")
	if (material)
		recipes = material.get_recipes_civs(forced=TRUE)
		stacktype = material.stack_type
		if (apply_colour)
			color = material.icon_colour
		/* // NEVER USED!
		if (material.conductive)
			flags |= CONDUCT
		*/
		matter = material.get_matter()
	update_strings()
	return TRUE

/obj/item/stack/material/get_material()
	return material

/obj/item/stack/material/proc/update_strings()
	// Update from material datum.
	if (material)
		singular_name = material.sheet_singular_name
		if (amount>1)
			name = "[material.use_name] [material.sheet_plural_name]"
			desc = "A stack of [material.use_name] [material.sheet_plural_name]."
			gender = PLURAL
		else
			name = "[material.use_name] [material.sheet_singular_name]"
			desc = "A [material.sheet_singular_name] of [material.use_name]."
			gender = NEUTER

/obj/item/stack/material/use(var/used)
	. = ..()
	update_strings()
	return

/obj/item/stack/material/transfer_to(obj/item/stack/S, var/tamount=null, var/type_verified)
	var/obj/item/stack/material/M = S
	if (!M || !istype(M, /obj/item/stack/material) || !M.material)
		return FALSE
	if (!istype(M) || material.name != M.material.name)
		return FALSE
	var/transfer = ..(S,tamount,1)
	if (src) update_strings()
	if (M) M.update_strings()
	return transfer

/obj/item/stack/material/attack_self(var/mob/user)
//	if (!material.build_windows(user, src))
	..()

/obj/item/stack/material/attackby(var/obj/item/W, var/mob/user)
	if (istype(W, /obj/item/stack/rods))
		material.build_rod_product(user, W, src)
		return
	..()

/obj/item/stack/material/iron
	name = "iron"
	icon_state = "sheet-iron"
	default_type = "iron"
	apply_colour = TRUE
	value = 3
	flags = CONDUCT

/obj/item/stack/material/iron/twentyfive
	amount = 25

/obj/item/stack/material/barbwire
	name = "Barbwire"
	icon_state = "barbwire_stack"
	default_type = "barbedwire"
	value = 2
	flags = CONDUCT

/obj/item/stack/material/barbwire/ten
	name = "Barbwire"
	icon_state = "barbwire_stack"
	default_type = "barbedwire"
	value = 2
	amount = 10

/obj/item/stack/material/barbwire/twnt
	amount = 20
/obj/item/stack/material/bronze
	name = "bronze"
	icon_state = "sheet-bronze"
	default_type = "bronze"
	apply_colour = TRUE
	value = 2
	flags = CONDUCT

/obj/item/stack/material/copper
	name = "copper"
	icon_state = "sheet-copper"
	default_type = "copper"
	apply_colour = TRUE
	value = 1
	flags = CONDUCT

/obj/item/stack/material/tin
	name = "tin"
	icon_state = "sheet-tin"
	default_type = "tin"
	apply_colour = TRUE
	value = 3
	flags = CONDUCT

/obj/item/stack/material/plastic
	name = "plastic"
	icon_state = "sheet-plastic"
	default_type = "plastic"
	apply_colour = TRUE
	value = 3

/obj/item/stack/material/lead
	name = "lead"
	icon_state = "sheet-lead"
	default_type = "lead"
	apply_colour = TRUE
	value = 3
	flags = CONDUCT

/obj/item/stack/material/sandstone
	name = "sandstone"
	icon_state = "sheet-sandstone"
	default_type = "sandstone"
	value = 2

/obj/item/stack/material/stone
	name = "stone block"
	icon_state = "sheet-stone"
	default_type = "stone"
	value = 2

/obj/item/stack/material/stonebrick
	name = "stone brick"
	icon_state = "sheet-stonebrick"
	default_type = "stonebrick"
	value = 1

/obj/item/stack/material/clay
	name = "clay lump"
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claylump"
	default_type = "clay"
	value = 2

/obj/item/stack/material/clay/attackby(obj/item/W as obj, mob/user as mob)
	if (map.ID == MAP_GULAG13)
		if (!istype(W)) return//I really don't understand why this check is needed
		if (istype(W, /obj/item/weapon/key/soviet/guard))
			user << "<span class='notice'>You make the clay into a mold of the key.</span>"
			new/obj/item/weapon/clay/mold/key(user.loc)
			qdel(src)
	if (istype(W, type))
		var/obj/item/stack/S = W
		merge(S)
		S.update_icon()
		src.update_icon()
		spawn(0) //give the stacks a chance to delete themselves if necessary
		if (S && usr.using_object == S)
			S.interact(usr)
		if (src && usr.using_object == src)
			interact(usr)

/obj/item/stack/material/electronics
	name = "electronic circuits"
	icon_state = "sheet-electronics"
	default_type = "electronic"
	value = 5
	flags = CONDUCT

/obj/item/stack/material/marble
	name = "marble block"
	icon_state = "sheet-marble"
	default_type = "marble"
	value = 3

/obj/item/stack/material/diamond
	name = "diamond"
	icon_state = "sheet-diamond"
	default_type = "diamond"
	value = 40
	w_class = ITEM_SIZE_TINY

/obj/item/stack/material/obsidian
	name = "obsidian"
	icon_state = "sheet-obsidian"
	default_type = "obsidian"
	value = 7
	w_class = ITEM_SIZE_TINY

/obj/item/stack/material/rope
	name = "Rope"
	icon_state = "rope"
	default_type = "rope"
	value = 2
	flammable = TRUE

/obj/item/stack/material/hemp
	name = "Hemp"
	icon_state = "hemp"
	default_type = "hemp"
	value = 2
	flammable = TRUE

/obj/item/stack/material/flax
	name = "Flax"
	icon_state = "flax"
	default_type = "flax"
	value = 2
	flammable = TRUE

/obj/item/stack/material/leaf
	name = "Leaf"
	icon = 'icons/obj/items.dmi'
	icon_state = "leaves1"
	default_type = "leaf"
	value = 0
	flammable = TRUE
	var/decay = 0
	var/decaytimer = 0
	decay = 80*600

/obj/item/stack/material/leaf/New()
	..()
	food_decay()

/obj/item/stack/material/leaf/proc/food_decay()
	spawn(600)
		if (decay == 0)
			return
		if (istype(loc, /obj/structure/vending))
			food_decay()
			return
		if (istype(loc, /obj/structure/closet/fridge))
			var/obj/structure/closet/fridge/F = loc
			if (F.powersource && F.powersource.powered)
				decaytimer += 100 //much slower
			else
				decaytimer += 300
		else if (isturf(loc) && !findtext(src.name, "canned")) //if on the floor (i.e. not stored inside something), decay faster
			decaytimer += 600
		else if (!istype(loc, /obj/item/weapon/can) && !findtext(src.name, "canned")) //if not canned, since canned food doesn't spoil
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

/obj/item/stack/material/leaf/palm
	name = "Palm"
	icon = 'icons/obj/items.dmi'
	icon_state = "palm_leaves"
	default_type = "palm"
	value = 0
	flammable = TRUE
	decay = 80*600

/obj/item/stack/material/leaf/fern
	name = "Fern"
	icon = 'icons/obj/items.dmi'
	icon_state = "fernleaf1"
	default_type = "fern"
	value = 0
	flammable = TRUE

/obj/item/stack/material/leaves/fern/New()
		..()
		icon_state = pick("fernleaves1","fernleaves2")

/obj/item/stack/material/tobacco_green
	name = "fresh tobacco leaves"
	icon_state = "tobacco_green"
	default_type = "tobacco"
	value = 2
	w_class = ITEM_SIZE_TINY
	dried_type = /obj/item/stack/material/tobacco
	dry_size = 9

/obj/item/stack/material/tobacco
	name = "dried tobacco leaves"
	icon_state = "tobacco"
	default_type = "tobacco"
	value = 3
	w_class = ITEM_SIZE_TINY
	flammable = TRUE

/obj/item/stack/material/coca
	name = "coca leaves"
	desc = "Can be made into cocaine."
	icon_state = "coca"
	default_type = "coca"
	value = 2
	w_class = ITEM_SIZE_TINY
	flammable = TRUE

/obj/item/stack/material/poppy
	name = "poppy"
	desc = "Dried opium poppies. Opium can be extracted."
	icon_state = "poppy"
	default_type = "poppy"
	value = 5
	w_class = ITEM_SIZE_TINY
	flammable = TRUE

/obj/item/stack/material/straw
	name = "straw"
	icon_state = "sheet-straw"
	default_type = "straw"
	value = 3
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/rope/attackby(var/obj/item/W, var/mob/M)
	if (anchored)
		return FALSE
	else
		return ..()

/obj/item/stack/material/rope/attack_hand(var/mob/M)
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.hand && H.l_hand && H.l_hand.type == /obj/item/stack/material/rope)
			return
		else if (!H.hand && H.r_hand && H.r_hand.type == /obj/item/stack/material/rope)
			return
		var/obj/rope = new /obj/item/stack/material/rope
		rope.anchored = FALSE
		if (H.put_in_any_hand_if_possible(rope, prioritize_active_hand = TRUE))
			--amount
			visible_message("<span class = 'warning'>[H] takes a coil of rope from the pile of rope.</span>")
			if (amount < 1)
				qdel(src)

/obj/item/stack/material/gold
	name = "gold"
	icon_state = "sheet-gold"
	default_type = "gold"
	value = 40
	flags = CONDUCT

/obj/item/stack/material/silver
	name = "silver"
	icon_state = "sheet-silver"
	default_type = "silver"
	value = 20
	flags = CONDUCT

/obj/item/stack/material/steel
	name = "steel"
	icon_state = "sheet-metal"
	default_type = "steel"
	value = 5
	max_amount = 2000
	flags = CONDUCT

/obj/item/stack/material/steel/twentyfive
	amount = 25

/obj/item/stack/material/wood
	name = "wooden plank"
	icon_state = "sheet-wood"
	default_type = "wood"
	dropsound = 'sound/effects/drop_wood.ogg'
	value = 1
	flammable = TRUE
	var/onfire = FALSE
	var/ash_production = FALSE

/obj/item/stack/material/wood/twentyfive
	amount = 25

/obj/item/stack/material/wood/proc/start_fire()
	var/burn_time = amount * 1
	var/old_amount = amount
	if (onfire)
		var/obj/effect/fire/NF = new/obj/effect/fire(src.loc)
		spawn(burn_time)
			for(var/i = 0, i < old_amount, i++)
				new/obj/item/wood_ash(src.loc)
			qdel(NF)
			qdel(src)

/obj/item/stack/material/wood/attackby(obj/item/T as obj, mob/user as mob)
	if (istype(T, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/F = T
		if(user.a_intent == "harm" && F.on && !onfire)
			visible_message("<span class = 'red'>[user.name] tries to set the [src] on fire.</span>")
			if(prob(30))
				ash_production = 1
				src.onfire = 1
				start_fire()
				visible_message("<span class = 'red'>[user.name] sets the [src] on fire.</span>")
				return
	return ..()

/obj/item/stack/material/bamboo
	name = "bamboo bundle"
	icon_state = "sheet-bamboo"
	default_type = "bamboo"
	dropsound = 'sound/effects/drop_wood.ogg'
	value = 1
	flammable = TRUE

/obj/item/stack/material/cotton
	name = "cotton pile"
	icon_state = "sheet-cotton"
	default_type = "cotton"
	value = 2
	flammable = TRUE

/obj/item/stack/material/cloth
	name = "cloth"
	icon_state = "sheet-cloth"
	default_type = "cloth"
	value = 3
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/rettedfabric
	name = "retted fabric"
	icon_state = "sheet-rettedfabric"
	default_type = "rettedfabric"
	value = 1
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/rawkevlar
	name = "raw kevlar"
	icon_state = "sheet-rawkevlar"
	default_type = "rawkevlar"
	value = 1
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/preparedkevlar
	name = "prepared kevlar"
	icon_state = "sheet-preparedkevlar"
	default_type = "preparedkevlar"
	value = 1
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/kevlar
	name = "kevlar sheets"
	icon_state = "sheet-kevlar"
	default_type = "kevlar"
	value = 15
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/rags
	name = "rags"
	icon = 'icons/obj/trash.dmi'
	icon_state = "rag"
	default_type = "rags"
	value = 0.5
	w_class = ITEM_SIZE_TINY
	flammable = TRUE

/obj/item/stack/material/wool
	name = "wool pile"
	icon_state = "woolpile"
	default_type = "wool"
	value = 2
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/woolcloth
	name = "wool cloth"
	icon_state = "wool_roll"
	default_type = "woolcloth"
	value = 3
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/leather
	name = "leather"
	desc = "The by-product of mob grinding."
	icon_state = "sheet-leather"
	default_type = "leather"
	value = 2
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
/*
/obj/item/stack/material/scales/gator_scale  //placeholder for alternative scaly hide crafting
	name = "alligator scales"
	desc = "The fine scales of a alligator."
	icon_state = "sheet-scales"
	default_type = "alligator scales"
	value = 2
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
*/

/obj/item/stack/material/pelt
	name = "animal pelt"
	desc = "A pelt from a skinned animal."
	icon_state = "sheet-bearpelt"
	default_type = "pelt"
	value = 3
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/pelt/bearpelt/black
	name = "black bear pelt"
	desc = "A pelt from a skinned bear."
	icon_state = "sheet-bearpelt"
	default_type = "bearpelt"
	value = 3
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
/obj/item/stack/material/pelt/bearpelt/brown
	name = "brown bear pelt"
	desc = "A pelt from a skinned bear."
	icon_state = "sheet-brownbearpelt"
	default_type = "brownbearpelt"
	value = 3

/obj/item/stack/material/pelt/bearpelt/white
	name = "white bear pelt"
	desc = "A pelt from a skinned bear."
	icon_state = "sheet-whitebearpelt"
	default_type = "whitebearpelt"
	value = 3

/obj/item/stack/material/pelt/wolfpelt
	name = "wolf pelt"
	desc = "A pelt from a skinned wolf."
	icon_state = "sheet-wolfpelt"
	default_type = "wolfpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3

/obj/item/stack/material/pelt/wolfpelt/white
	name = "white wolf pelt"
	desc = "A pelt from a skinned white wolf."
	icon_state = "sheet-whitewolfpelt"
	default_type = "whitewolfpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3

/obj/item/stack/material/pelt/catpelt
	name = "cat pelt"
	desc = "A pelt from a skinned cat."
	icon_state = "sheet-catpelt"
	default_type = "catpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3
/obj/item/stack/material/pelt/pantherpelt
	name = "panther pelt"
	desc = "A pelt from a skinned panther."
	icon_state = "sheet-pantherpelt"
	default_type = "pantherpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3

/obj/item/stack/material/pelt/lionpelt
	name = "lion pelt"
	desc = "A pelt from a skinned lion."
	icon_state = "sheet-lionpelt"
	default_type = "lionpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3

/obj/item/stack/material/pelt/gatorpelt
	name = "gator pelt"
	desc = "A pelt from a skinned alligator."
	icon_state = "sheet-gatorpelt"
	default_type = "gatorpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	value = 3

/obj/item/stack/material/pelt/lizardpelt
	name = "lizard pelt"
	desc = "A pelt from a skinned lizard."
	icon_state = "sheet-lizardpelt"
	default_type = "lizardpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	value = 3

/obj/item/stack/material/pelt/monkeypelt
	name = "monkey pelt"
	desc = "A pelt from a skinned monkey."
	icon_state = "sheet-monkeypelt"
	default_type = "monkeypelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3

/obj/item/stack/material/pelt/foxpelt
	name = "fox pelt"
	desc = "A pelt from a skinned fox."
	icon_state = "sheet-foxpelt"
	default_type = "foxpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3
/obj/item/stack/material/pelt/foxpelt/white
	name = "white fox pelt"
	desc = "A pelt from a skinned white fox."
	icon_state = "sheet-whitefoxpelt"
	default_type = "whitefoxpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 3

/obj/item/stack/material/pelt/sheeppelt
	name = "sheep pelt"
	desc = "A wooly pelt from a skinned sheep."
	icon_state = "sheet-sheeppelt"
	default_type = "sheeppelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 2

/obj/item/stack/material/pelt/goatpelt
	name = "goat pelt"
	desc = "A pelt from a skinned goat."
	icon_state = "sheet-goatpelt"
	default_type = "goatpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 2

/obj/item/stack/material/pelt/cowpelt
	name = "cattle pelt"
	desc = "A pelt from skinned cattle."
	icon_state = "sheet-cowpelt"
	default_type = "cowpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 5

/obj/item/stack/material/pelt/bisonpelt
	name = "bison pelt"
	desc = "A pelt from a skinned bison."
	icon_state = "sheet-bisonpelt"
	default_type = "bisonpelt"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 15

/obj/item/stack/material/pelt/orcpelt
	name = "Orc Pelt"
	desc = "The skin of an Orc"
	icon_state = "sheet-orcpelt"
	default_type = "orcpelt"
	value = 0
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/pelt/humanpelt
	name = "human pelt"
	desc = "A skin from a dead person."
	icon_state = "sheet-humanpelt"
	default_type = "humanpelt"
	value = 0
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/pelt/humanpelt/New()
	..()
	if (map && !map.civilizations)
		qdel(src)

/obj/item/stack/material/pelt/antpelt
	name = "ant pelt"
	desc = "The skin from a dead ant."
	icon_state = "sheet-antpelt"
	default_type = "ant"
	flammable = TRUE
	value = 4
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/chitin
	name = "chitin"
	desc = "The armor of Trilobites...and Ants"
	icon_state = "chitin_material"
	default_type = "chitin"
	flammable = TRUE
	value = 4
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/pelt/orcpelt
	name = "orc skin"
	desc = "A rough skin, it'l like a flexible rock..."
	icon_state = "sheet-orcpelt"
	default_type = "orcpelt"
	flammable = TRUE
	value = 0
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/pelt/gorillapelt
	name = "gorilla pelt"
	desc = "The skin from a dead gorilla."
	icon_state = "sheet-gorillapelt"
	default_type = "gorillapelt"
	flammable = TRUE
	value = 3
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/glass
	name = "glass"
	icon_state = "sheet-glass"
	default_type = "glass"
	dropsound = 'sound/effects/drop_glass.ogg'
	value = 3

/obj/item/stack/material/glass/reinforced
	name = "reinforced glass"
	icon_state = "sheet-rglass"
	default_type = "rglass"
	value = 6
	flags = CONDUCT

/obj/item/stack/material/bone
	name = "bones"
	icon_state = "sheet-bone"
	default_type = "bone"
	dropsound = 'sound/effects/drop_wood.ogg'
	w_class = ITEM_SIZE_SMALL
	value = 0
	singular_name = "bone"

/obj/item/stack/material/bone/New()
	..()
	spawn(7200)
		if (isturf(loc))
			qdel(src)

/obj/item/stack/material/list_recipes(mob/user as mob, recipes_sublist)
	var/mob/living/human/U = user
	recipes = material.get_recipes_civs(U)
	..()

/obj/item/stack/material/fossil
	name = "fossil"
	icon = 'icons/obj/materials.dmi'
	icon_state = "fossil_1"
	default_type = "stone"
	dropsound = 'sound/effects/drop_wood.ogg'
	w_class = ITEM_SIZE_NORMAL
	value = 10
	max_amount = 1
	singular_name = "fossil"
	New()
		icon_state = "fossil_[rand(1, 10)]"
		value = rand(10, 18)
		..()
/*
/obj/item/stack/material/steelrods
	name = "steel rods"
	icon_state = "rods"
	default_type = "steelrods"
	w_class = ITEM_SIZE_SMALL
	value = 6
	max_amount = 500
	singular_name = "steel rod"*/
