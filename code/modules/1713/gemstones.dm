// Gemstones: rough stones found while mining, cut with a chisel and hammer,
// and set into clothing or jewellery as decoration. See docs/gemstones.md.
// Included after flint_mining.dm, ores.dm and clothing_accessories.dm: the
// clothing attackby/examine and rough diamond overrides fall back to those.

#define GEM_POCKET_CHANCE 2 // percent per mined wall, independent of the ore table
#define GEM_CUT_TIME 80
#define GEM_CUT_FLAW_CHANCE 15
#define GEM_SET_TIME 50
#define GEM_PRY_TIME 40

// Weights for the stone found in a gem pocket. Rough diamonds keep their own
// roll in the ore table (docs/mining-drop-balance.md).
var/global/list/gem_pocket_weights = list(
	/obj/item/stack/ore/gem/quartz = 30, // gem_science.dm
	/obj/item/stack/ore/gem/garnet = 30,
	/obj/item/stack/ore/gem/amethyst = 25,
	/obj/item/stack/ore/gem/topaz = 20,
	/obj/item/stack/ore/gem/emerald = 10,
	/obj/item/stack/ore/gem/sapphire = 8,
	/obj/item/stack/ore/gem/ruby = 7,
)

// Mined rock: one independent gem roll per wall, like flint nodules, so the
// ore table is unchanged.
/turf/proc/mining_gem_pocket(mob/living/human/H)
	if (!prob(GEM_POCKET_CHANCE * continent_ore_factor("gems"))) // continent_resources.dm
		return null
	var/gem_type = pickweight(gem_pocket_weights)
	var/obj/item/stack/ore/gem/G = new gem_type(src)
	if (istype(get_area(src), /area/caribbean/void/caves/special))
		G.amount = 2
	if (H)
		to_chat(H, SPAN_GREEN_BOLD("You found \a [G.singular_name]!"))
	return G

// ---- Rough stones ----

/obj/item/stack/ore/gem
	name = "rough gemstones"
	singular_name = "rough gemstone"
	desc = "An uncut stone. A chisel and a hammer would bring out its colour."
	icon = 'icons/obj/gemstones.dmi'
	w_class = ITEM_SIZE_TINY
	max_amount = 20
	flammable = FALSE
	value = 3
	var/cut_type = null

/obj/item/stack/ore/gem/update_icon()
	icon_state = initial(icon_state) // single sprite, no ore pile stages

/obj/item/stack/ore/gem/attackby(obj/item/W, mob/user)
	if (cut_gemstone(W, user, cut_type))
		return
	..()

/obj/item/stack/ore/gem/garnet
	name = "rough garnets"
	singular_name = "rough garnet"
	icon_state = "garnet_uncut"
	cut_type = /obj/item/stack/gemstone/garnet

/obj/item/stack/ore/gem/amethyst
	name = "rough amethysts"
	singular_name = "rough amethyst"
	icon_state = "amethyst_uncut"
	cut_type = /obj/item/stack/gemstone/amethyst

/obj/item/stack/ore/gem/topaz
	name = "rough topazes"
	singular_name = "rough topaz"
	icon_state = "topaz_uncut"
	value = 4
	cut_type = /obj/item/stack/gemstone/topaz

/obj/item/stack/ore/gem/emerald
	name = "rough emeralds"
	singular_name = "rough emerald"
	icon_state = "emerald_uncut"
	value = 6
	cut_type = /obj/item/stack/gemstone/emerald

/obj/item/stack/ore/gem/sapphire
	name = "rough sapphires"
	singular_name = "rough sapphire"
	icon = 'icons/obj/pocket_stronghold_gems.dmi'
	icon_state = "sapphire_uncut"
	value = 6
	cut_type = /obj/item/stack/gemstone/sapphire

/obj/item/stack/ore/gem/ruby
	name = "rough rubies"
	singular_name = "rough ruby"
	icon = 'icons/obj/pocket_stronghold_gems.dmi'
	icon_state = "ruby_uncut"
	value = 7
	cut_type = /obj/item/stack/gemstone/ruby

// Mined diamonds are the rough stones for cut diamonds.
/obj/item/stack/ore/diamond
	singular_name = "rough diamond"
	desc = "Uncut diamonds. A chisel and a hammer would bring out their sparkle."

/obj/item/stack/ore/diamond/attackby(obj/item/W, mob/user)
	if (cut_gemstone(W, user, /obj/item/stack/gemstone/diamond))
		return
	..()

// Chisel in the active hand, hammer in the other. Cuts one stone per action.
// Returns TRUE when the click was a cutting attempt (handled), else FALSE.
/obj/item/stack/proc/cut_gemstone(obj/item/W, mob/user, cut_type)
	if (!cut_type || !is_tool(W, TOOL_CHISEL) || !ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	if (!is_tool(H.l_hand, TOOL_HAMMER) && !is_tool(H.r_hand, TOOL_HAMMER))
		to_chat(H, SPAN_WARNING("You need a hammer in your other hand to use a chisel."))
		return TRUE
	if (!H.may_do_after)
		return TRUE
	if (!crafting_node_allowed_or_warn(H, "regalia"))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] starts cutting \a [singular_name]."), SPAN_NOTICE("You start cutting \a [singular_name]."))
	playsound(get_turf(src), 'sound/effects/pickaxe.ogg', 40, TRUE)
	// A charged lapping wheel beside the cutter halves the time and takes
	// the stone down without splitting it (gem_science.dm).
	var/obj/structure/lapping_wheel/lap = gem_lap_near(H, cut_type)
	if (!do_after(H, GEM_CUT_TIME / max(0.5, H.getStatCoeff("dexterity")) / (lap ? 2 : 1), src))
		return TRUE
	if (QDELETED(src) || amount < 1 || W.loc != H || H.get_active_hand() != W || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
		return TRUE
	var/turf/T = get_turf(src)
	var/stone_name = singular_name
	if (!use(1))
		return TRUE
	H.adaptStat("crafting", 1)
	if (lap && !QDELETED(lap) && lap.use_charge(cut_type))
		to_chat(H, SPAN_NOTICE("You finish the stone on \the [lap]."))
	else if (prob(GEM_CUT_FLAW_CHANCE / max(0.5, H.getStatCoeff("crafting")) / (inclusions_mapped ? 2 : 1)))
		var/leftover = gem_flaw_leftovers(T, cut_type)
		to_chat(H, SPAN_WARNING("The [stone_name] cracks along a hidden flaw and splinters into [leftover ? leftover : "worthless chips"]."))
		return TRUE
	var/obj/item/stack/gemstone/G = new cut_type(T)
	to_chat(H, SPAN_NOTICE("You cut \a [G.singular_name]."))
	return TRUE

// ---- Cut stones ----

/obj/item/stack/gemstone
	name = "gemstones"
	singular_name = "gemstone"
	desc = "A cut and polished gemstone. Set it into clothing or jewellery with a chisel held in your other hand."
	icon = 'icons/obj/gemstones.dmi'
	w_class = ITEM_SIZE_TINY
	max_amount = 20
	amount = 1
	flammable = FALSE
	value = 10
	var/gem_colour = "#ffffff" // tint for pendant settings (necklaces.dm)

/obj/item/stack/gemstone/garnet
	name = "garnets"
	singular_name = "garnet"
	gem_colour = "#8b1a2b"
	icon_state = "garnet"

/obj/item/stack/gemstone/amethyst
	name = "amethysts"
	singular_name = "amethyst"
	gem_colour = "#9b59d0"
	icon_state = "amethyst"

/obj/item/stack/gemstone/topaz
	name = "topazes"
	singular_name = "topaz"
	gem_colour = "#e8a33a"
	icon_state = "topaz"
	value = 12

/obj/item/stack/gemstone/emerald
	name = "emeralds"
	singular_name = "emerald"
	gem_colour = "#2fa35a"
	icon_state = "emerald"
	value = 18

/obj/item/stack/gemstone/sapphire
	name = "sapphires"
	singular_name = "sapphire"
	gem_colour = "#2a5fd6"
	icon = 'icons/obj/pocket_stronghold_gems.dmi'
	icon_state = "sapphire"
	value = 18

/obj/item/stack/gemstone/ruby
	name = "rubies"
	singular_name = "ruby"
	gem_colour = "#d0263a"
	icon = 'icons/obj/pocket_stronghold_gems.dmi'
	icon_state = "ruby"
	value = 21

/obj/item/stack/gemstone/diamond
	name = "diamonds"
	singular_name = "diamond"
	gem_colour = "#d8f4ff"
	icon = 'icons/obj/pocket_stronghold_gems.dmi'
	icon_state = "diamond"
	value = 30

// ---- Decoration: set a cut stone into clothing ----

/obj/item/clothing
	var/set_gem = null // singular name of the cut stone set into it, if any
	var/set_gem_colour = null // its colour, for items that show the stone
	var/set_gem_type = null // cut stone path, returned when the stone is pried out

/obj/item/clothing/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/stack/gemstone) && ishuman(user))
		var/mob/living/human/H = user
		if (is_tool(H.get_inactive_hand(), TOOL_CHISEL))
			set_gemstone(I, H)
			return
	if (set_gem && is_tool(I, TOOL_CHISEL) && ishuman(user))
		pry_gemstone(I, user)
		return
	..()

/obj/item/clothing/proc/set_gemstone(obj/item/stack/gemstone/G, mob/living/human/H)
	if (set_gem)
		to_chat(H, SPAN_WARNING("\The [src] is already set with \a [set_gem]."))
		return FALSE
	if (!H.may_do_after)
		return FALSE
	to_chat(H, SPAN_NOTICE("You start setting \a [G.singular_name] into \the [src]..."))
	if (!do_after(H, GEM_SET_TIME, src))
		return FALSE
	if (QDELETED(src) || QDELETED(G) || G.amount < 1 || G.loc != H || set_gem || !is_tool(H.get_inactive_hand(), TOOL_CHISEL))
		return FALSE
	var/stone_name = G.singular_name
	var/stone_value = G.value
	var/stone_colour = G.gem_colour
	var/stone_type = G.type
	if (!G.use(1))
		return FALSE
	set_gem = stone_name
	set_gem_colour = stone_colour
	set_gem_type = stone_type
	value += stone_value
	update_icon()
	to_chat(H, SPAN_NOTICE("You set \a [stone_name] into \the [src]."))
	return TRUE

// The cut stone path for the set stone: the stored path, or the cut stone
// with the same singular name for items set before set_gem_type existed.
/obj/item/clothing/proc/set_gemstone_type()
	if (ispath(set_gem_type, /obj/item/stack/gemstone))
		return set_gem_type
	for (var/path in subtypesof(/obj/item/stack/gemstone))
		var/obj/item/stack/gemstone/G = path
		if (initial(G.singular_name) == set_gem)
			return path
	return null

// Chisel the set stone back out: the same cut stone comes back whole, and the
// item loses the stone's value and its tinted setting.
/obj/item/clothing/proc/pry_gemstone(obj/item/W, mob/living/human/H)
	if (!set_gem)
		return FALSE
	if (!H.may_do_after)
		return FALSE
	var/stone_name = set_gem
	H.visible_message(SPAN_NOTICE("[H] starts prying \a [stone_name] out of \the [src]."), SPAN_NOTICE("You start prying \a [stone_name] out of \the [src]..."))
	if (!do_after(H, tool_work_time(W, GEM_PRY_TIME), src))
		return FALSE
	if (QDELETED(src) || set_gem != stone_name || W.loc != H || H.get_active_hand() != W)
		return FALSE
	var/stone_type = set_gemstone_type()
	set_gem = null
	set_gem_colour = null
	set_gem_type = null
	if (!stone_type)
		update_icon()
		to_chat(H, SPAN_WARNING("The setting comes loose, but the stone crumbles away."))
		return TRUE
	var/obj/item/stack/gemstone/G = new stone_type(get_turf(H))
	value = max(0, value - G.value)
	update_icon()
	H.put_in_any_hand_if_possible(G)
	to_chat(H, SPAN_NOTICE("You pry \a [G.singular_name] out of \the [src]."))
	return TRUE

/obj/item/clothing/examine(mob/user)
	..(user)
	if (set_gem)
		to_chat(user, "It is set with \a [set_gem].")

#undef GEM_POCKET_CHANCE
#undef GEM_CUT_TIME
#undef GEM_CUT_FLAW_CHANCE
#undef GEM_SET_TIME
#undef GEM_PRY_TIME
