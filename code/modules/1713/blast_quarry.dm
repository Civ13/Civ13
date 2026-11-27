// A game blast converts one native rock tile into one finite stock.
#define QUARRY_LOAD 5
#define QUARRY_OUTPUT_STACKS 12

/turf/proc/quarry_hardness()
	return 0

/turf/floor/dirt/underground/quarry_hard
	name = "hard quarry rock"
	desc = "A band of dense rock. A pickaxe or shovel will not open it. Requires a blasting charge and leaves a larger stone cluster."
	color = "#a39686"
	is_mineable = FALSE

/turf/floor/dirt/underground/quarry_hard/quarry_hardness()
	return 1

/turf/floor/dirt/underground/quarry_hard/deep
	name = "deep quarry rock"
	desc = "A band of especially dense rock. Only a reinforced quarry charge will open it. It leaves the largest stone clusters."
	color = "#837286"

/turf/floor/dirt/underground/quarry_hard/deep/quarry_hardness()
	return 2

// Accidental damage must not sidestep the excavation gate.
/turf/floor/dirt/underground/quarry_hard/ex_act(severity)
	return

/turf/floor/dirt/underground/quarry_hard/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/material/pickaxe) || is_tool(W, TOOL_SHOVEL))
		to_chat(user, SPAN_NOTICE(desc))
		return TRUE
	return ..()

/turf/proc/quarry_blast_eligible(charge_grade = 1)
	var/hardness = quarry_hardness()
	return charge_grade >= 1 && charge_grade >= hardness && istype(src, /turf/floor/dirt/underground) && !istype(src, /turf/floor/dirt/underground/empty) && (is_mineable || hardness) && !!density && !mining_in_progress && !pickaxe_mining_owner

// Sparse, deterministic pockets on naturally formed dry rock. Remain clear of
// the rim so region edge arrivals and ordinary access tunnels stay available.
/proc/quarry_band_type(x, y, depth, vein)
	if (depth < 1 || tutorial_region_here() || x <= 6 || y <= 6 || x > world.maxx - 6 || y > world.maxy - 6)
		return null
	if (dug_underground_noise("quarry-band:[depth]", x, y) < (vein > 0.65 ? 0.64 : 0.82))
		return null
	return depth >= 3 ? /turf/floor/dirt/underground/quarry_hard/deep : /turf/floor/dirt/underground/quarry_hard

// Change the terrain first, so a second blast cannot open the same stock.
/turf/proc/quarry_open(rock_type, stock, list/rubble = null)
	var/tx = x
	var/ty = y
	var/tz = z
	var/hardness = quarry_hardness()
	change_the_turf()
	var/turf/opened = locate(tx, ty, tz)
	if (!opened || opened.density || opened.is_mineable || stock < 1)
		return
	var/obj/structure/quarry_cluster/Q = new(opened)
	Q.stone_type = rock_type
	Q.rubble_left = rubble
	Q.stone_left = round(stock * (1.5 + hardness * 0.5))
	Q.update_icon()
	return Q

/obj/structure/quarry_cluster
	name = "blasted rock cluster"
	desc = "A finite heap of fractured rock. Work it with a pickaxe in small loads and clear away the stone as you go."
	icon = 'icons/obj/mining.dmi'
	icon_state = "boulder1"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = OBJ_LAYER
	var/stone_type = /obj/item/stack/material/stone
	var/stone_left = 0
	var/list/rubble_left
	var/tmp/working = FALSE

/obj/structure/quarry_cluster/persistence_runtime_var(key)
	return key == "working" || ..()

/obj/structure/quarry_cluster/after_load()
	..()
	if (stone_left < 1 && !length(rubble_left))
		qdel(src)
	else
		update_icon()

/obj/structure/quarry_cluster/update_icon()
	var/scale = stone_left > 20 ? 1 : (stone_left > 10 ? 0.8 : 0.6)
	transform = matrix(scale, 0, 0, 0, scale, 0)

/obj/structure/quarry_cluster/examine(mob/user)
	..()
	var/obj/item/stack/S = stone_type
	to_chat(user, SPAN_NOTICE("About [stone_left] units of [initial(S.name)] remain."))
	for (var/path in rubble_left)
		var/obj/item/stack/quarry_rubble/sample = path
		to_chat(user, SPAN_NOTICE("It contains [initial(sample.name)]."))

// The existing blasting charge damage is processed from an explosion queue. Do not let
// that same blast destroy resources it just uncovered.
/obj/structure/quarry_cluster/ex_act(severity)
	return

/obj/structure/quarry_cluster/proc/quarry_ready(mob/living/human/H, obj/item/W, turf/site, datum/identity)
	return !QDELETED(src) && !QDELETED(H) && !QDELETED(W) && site && loc == site && H.z == site.z && Adjacent(H) && H.pickaxe_mining_ready() && W.loc == H && (H.l_hand == W || H.r_hand == W) && !persistence_admission_changed(identity)

/obj/structure/quarry_cluster/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/weapon/material/pickaxe) || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	var/turf/site = get_turf(src)
	var/datum/identity = persistence_admission_identity
	if (tutorial_region_here() && !tutorial_workshop_access(H, src))
		return TRUE
	if (working || !quarry_ready(H, W, site, identity))
		return TRUE
	working = TRUE
	to_chat(H, SPAN_NOTICE("You start working loose a load from the cluster."))
	playsound(src, 'sound/effects/pickaxe.ogg', 60, TRUE)
	if (do_after(H, work_delay(H, 45, WORK_MINE, W), src) && quarry_ready(H, W, site, identity))
		if (!quarry_take_load())
			to_chat(H, SPAN_WARNING("Clear the loose rock beside the cluster before mining more."))
	working = FALSE
	return TRUE

/obj/structure/quarry_cluster/proc/quarry_take_load()
	var/turf/site = get_turf(src)
	if (QDELETED(src) || persistence_admission_blocked() || !site || !(stone_type in list(/obj/item/stack/material/stone, /obj/item/stack/material/marble, /obj/item/stack/material/sandstone)))
		return FALSE
	// Each load deposits exactly one stack type; a blocked output never spends stock.
	if (length(rubble_left))
		var/path = rubble_left[1]
		var/amount = min(QUARRY_LOAD, rubble_left[path])
		if (!ispath(path, /obj/item/stack/quarry_rubble) || !site.deposit_small_resource(path, amount, QUARRY_OUTPUT_STACKS))
			return FALSE
		rubble_left[path] -= amount
		if (!rubble_left[path])
			rubble_left -= path
	else
		var/amount = min(QUARRY_LOAD, stone_left)
		var/path = stone_type == /obj/item/stack/material/stone ? /obj/item/stack/material/stone/quarried : stone_type
		if (!site.deposit_small_resource(path, amount, QUARRY_OUTPUT_STACKS))
			return FALSE
		stone_left -= amount
	if (!stone_left && !length(rubble_left))
		visible_message(SPAN_NOTICE("The last of the fractured rock breaks loose."))
		qdel(src)
	else
		update_icon()
	return TRUE

/obj/structure/quarry_cluster/practice
	should_save = FALSE
	stone_left = 15

/obj/structure/quarry_cluster/practice/New()
	. = ..()
	rubble_left = list(/obj/item/stack/quarry_rubble/iron = 3)

// Same building material and recipes, but its deposit has already paid out
// any ore. Keep it distinct from stone with no known origin in every stack path.
/obj/item/stack/material/stone/quarried
	stacktype = /obj/item/stack/material/stone/quarried

/obj/item/stack/material/stone/quarried/New()
	. = ..()
	stacktype = type

/obj/item/stack/material/stone/stack_compatible(obj/item/stack/S)
	return S && S.type == type && ..()

/obj/item/stack/material/stone/quarried/examine(mob/user, distance)
	..()
	to_chat(user, SPAN_NOTICE("This quarried stone contains no recoverable ore. It can still be cut into bricks or crushed for sand."))

// Machine recipes that take ordinary stone work with either provenance.
/proc/stone_workshop_feed_type(obj/item/I)
	return istype(I, /obj/item/stack/material/stone) ? /obj/item/stack/material/stone : I?.type

// A blast already rolled the source tile's geology. Keep half of each multi-unit
// ore find in mill feed, not in a second loot roll. Single-unit finds stay loose.
/turf/proc/quarry_drop_ore(path, units, list/rubble)
	if (rubble && units > 1)
		var/prefix = "/obj/item/stack/ore/"
		var/feed = text2path("/obj/item/stack/quarry_rubble/[copytext("[path]", length(prefix) + 1)]")
		var/obj/item/stack/quarry_rubble/sample = feed
		if (sample && initial(sample.ore_type) == path)
			var/embedded = (units - (units % 2)) / 2
			rubble[feed] = (rubble[feed] || 0) + embedded
			units -= embedded
	// Use a fresh stack, as hand mining does, without touching deposits already
	// on this tile (which may predate the blast or belong to another player).
	var/obj/item/stack/ore/O = new path(src, units, FALSE)
	O.update_icon()
	return O

// Identity is entirely in the type and amount. Stack splitting/merging, mill
// hoppers, save/load and freight do not need to carry mutable provenance fields.
/obj/item/stack/quarry_rubble
	name = "ore-bearing rubble"
	singular_name = "chunk of ore-bearing rubble"
	desc = "Fractured rock with ore still trapped in it. Use it on a stone crusher or load it into a stamp mill to recover one unit per chunk."
	icon = 'icons/obj/mining.dmi'
	icon_state = "boulder1"
	max_amount = 50
	w_class = ITEM_SIZE_NORMAL
	var/ore_type

/obj/item/stack/quarry_rubble/stack_compatible(obj/item/stack/S)
	return S && S.type == type && ..()

/obj/item/stack/quarry_rubble/copper
	name = "copper-bearing rubble"
	singular_name = "chunk of copper-bearing rubble"
	ore_type = /obj/item/stack/ore/copper

/obj/item/stack/quarry_rubble/tin
	name = "tin-bearing rubble"
	singular_name = "chunk of tin-bearing rubble"
	ore_type = /obj/item/stack/ore/tin

/obj/item/stack/quarry_rubble/iron
	name = "iron-bearing rubble"
	singular_name = "chunk of iron-bearing rubble"
	ore_type = /obj/item/stack/ore/iron

/obj/item/stack/quarry_rubble/zinc
	name = "calamine-bearing rubble"
	singular_name = "chunk of calamine-bearing rubble"
	ore_type = /obj/item/stack/ore/zinc

/obj/item/stack/quarry_rubble/coal
	name = "coal-bearing rubble"
	singular_name = "chunk of coal-bearing rubble"
	ore_type = /obj/item/stack/ore/coal

/obj/item/stack/quarry_rubble/lead
	name = "lead-bearing rubble"
	singular_name = "chunk of lead-bearing rubble"
	ore_type = /obj/item/stack/ore/lead

/obj/item/stack/quarry_rubble/saltpeter
	name = "saltpeter-bearing rubble"
	singular_name = "chunk of saltpeter-bearing rubble"
	ore_type = /obj/item/stack/ore/saltpeter

/obj/item/stack/quarry_rubble/sulphur
	name = "sulphur-bearing rubble"
	singular_name = "chunk of sulphur-bearing rubble"
	ore_type = /obj/item/stack/ore/sulphur

/obj/item/stack/quarry_rubble/silver
	name = "silver-bearing rubble"
	singular_name = "chunk of silver-bearing rubble"
	ore_type = /obj/item/stack/ore/silver

/obj/item/stack/quarry_rubble/gold
	name = "gold-bearing rubble"
	singular_name = "chunk of gold-bearing rubble"
	ore_type = /obj/item/stack/ore/gold

/obj/item/stack/quarry_rubble/diamond
	name = "diamond-bearing rubble"
	singular_name = "chunk of diamond-bearing rubble"
	ore_type = /obj/item/stack/ore/diamond

/obj/item/stack/quarry_rubble/bauxite
	name = "bauxite-bearing rubble"
	singular_name = "chunk of bauxite-bearing rubble"
	ore_type = /obj/item/stack/ore/bauxite

/obj/item/stack/quarry_rubble/nickel
	name = "nickel-bearing rubble"
	singular_name = "chunk of nickel-bearing rubble"
	ore_type = /obj/item/stack/ore/nickel

/obj/item/stack/quarry_rubble/cobalt
	name = "cobalt-bearing rubble"
	singular_name = "chunk of cobalt-bearing rubble"
	ore_type = /obj/item/stack/ore/cobalt

/obj/item/stack/quarry_rubble/chromite
	name = "chromite-bearing rubble"
	singular_name = "chunk of chromite-bearing rubble"
	ore_type = /obj/item/stack/ore/chromite

/obj/item/stack/quarry_rubble/obsidian
	name = "obsidian-bearing rubble"
	singular_name = "chunk of obsidian-bearing rubble"
	ore_type = /obj/item/stack/ore/obsidian

#undef QUARRY_LOAD
#undef QUARRY_OUTPUT_STACKS
