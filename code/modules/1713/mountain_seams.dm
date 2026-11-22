// Mountain seams: the ground where a mountain stood stays a mine.
// See docs/mountain-seams.md.
//
// A map that sets mountain_seams lets a pickaxe work open dirt inside the caves
// area: on the Americas maps every rock tile is in that area, and mining keeps
// the area while it swaps the turf, so this ground is exactly the mined-out
// mountain footprint. Most of it is bedrock that gives stone without end. About
// one tile in MOUNTAIN_SEAM_SHARE is an ore seam; its ore is chosen per
// MOUNTAIN_SEAM_DISTRICT block, so a hillside is a copper or an iron district.
// A seam holds MOUNTAIN_SEAM_LOADS loads and one comes back every
// MOUNTAIN_SEAM_REGROW. Working the floor takes twice as long as a rock wall
// and yields about half, so fresh mountains stay the better dig; rare finds
// (gems, flint, obsidian, diamonds, bauxite, uranium) stay fresh rock only.
//
// Nothing here is saved: seam, ore and marker come from position, stocks live
// in a runtime table and restart full with the server, like flint rocks.

#define MOUNTAIN_SEAM_SHARE 12
#define MOUNTAIN_SEAM_DISTRICT 12
#define MOUNTAIN_SEAM_LOADS 6
#define MOUNTAIN_SEAM_REGROW (20 MINUTES)
#define MOUNTAIN_SEAM_WORK 480 // a rock wall takes 240, same divisors
#define MOUNTAIN_SEAM_POLL (10 SECONDS)

/obj/map_metadata/var/mountain_seams = FALSE

// "x,y,z" -> /datum/resource_stock, made the first time a seam is worked.
var/global/list/mountain_seam_stock = list()
// Busy workers and tiles, so one pickaxe swing never queues a second.
var/global/list/mountain_seam_busy = list()
var/global/mountain_seam_marked = FALSE

// Ore -> weight out of 100, its age gate, and its per-load amount range.
/proc/mountain_seam_ores()
	var/static/list/ores = list(
		/obj/item/stack/ore/copper = list(22, 0, 4, 8),
		/obj/item/stack/ore/tin = list(16, 0, 4, 8),
		/obj/item/stack/ore/iron = list(22, 1, 4, 8),
		/obj/item/stack/ore/zinc = list(6, 1, 4, 8),
		/obj/item/stack/ore/coal = list(10, 2, 8, 12),
		/obj/item/stack/ore/saltpeter = list(4, 2, 3, 4),
		/obj/item/stack/ore/sulphur = list(4, 2, 3, 4),
		/obj/item/stack/ore/lead = list(4, 2, 3, 4),
		/obj/item/stack/ore/silver = list(3, 0, 1, 2),
		/obj/item/stack/ore/gold = list(1, 0, 1, 2),
		/obj/item/stack/ore/mercury = list(2, 1, 1, 2), // cinnabar (mercury.dm)
		/obj/item/stack/ore/gold_quartz = list(3, 1, 2, 4), // lode ore (lode.dm)
		/obj/item/stack/ore/silver_lode = list(3, 1, 2, 4),
	)
	return ores

// 16 bits from md5, exact in BYOND numbers.
/proc/mountain_seam_hash(text)
	return hex2num(copytext(md5(text), 1, 5))

/proc/mountain_seam_map_key()
	return map ? "[map.ID]" : ""

/proc/mountain_seam_is_seam(x, y)
	return mountain_seam_hash("[x],[y],[mountain_seam_map_key()]") % MOUNTAIN_SEAM_SHARE == 0

// The ore of the district holding x, y (ignoring the age gate).
/proc/mountain_seam_district_ore(x, y)
	var/bx = round((x - 1) / MOUNTAIN_SEAM_DISTRICT)
	var/by = round((y - 1) / MOUNTAIN_SEAM_DISTRICT)
	var/roll = mountain_seam_hash("[bx],[by],[mountain_seam_map_key()],ore") % 100
	var/list/ores = mountain_seam_ores()
	for (var/ore_type in ores)
		var/list/row = ores[ore_type]
		roll -= row[1]
		if (roll < 0)
			return ore_type
	return /obj/item/stack/ore/copper

// The ore a seam tile gives, or null for a seam whose ore is not open yet.
/proc/mountain_seam_live_ore(x, y)
	var/ore_type = mountain_seam_district_ore(x, y)
	var/list/row = mountain_seam_ores()[ore_type]
	return map && map.ordinal_age >= row[2] ? ore_type : null

/proc/mountain_seam_ground(turf/T)
	if (!T || !map || !map.mountain_seams || T.z != 1)
		return FALSE
	if (!istype(T, /turf/floor/dirt) || istype(T, /turf/floor/dirt/underground) || T.is_mineable)
		return FALSE
	if (!istype(T.loc, /area/caribbean/void/caves))
		return FALSE
	if (locate(/obj/covers) in T)
		return FALSE
	for (var/obj/O in T)
		if (O.density && O.anchored)
			return FALSE
	return TRUE

/proc/mountain_seam_stock_at(turf/T)
	var/key = "[T.x],[T.y],[T.z]"
	var/datum/resource_stock/stock = mountain_seam_stock[key]
	if (!stock)
		stock = new /datum/resource_stock(MOUNTAIN_SEAM_LOADS, MOUNTAIN_SEAM_REGROW)
		mountain_seam_stock[key] = stock
	return stock

/proc/mountain_seam_ore_name(ore_type)
	var/obj/item/stack/ore/O = ore_type
	var/text = initial(O.name)
	return replacetext(text, " ore", "")

// ---------------------------------------------------------------- marker
// The seam's own ore sprite, faded and small, on the floor tile. Runtime only.
/proc/mountain_seam_marker(ore_type)
	var/static/list/markers = list()
	var/image/I = markers[ore_type]
	if (!I)
		var/obj/item/stack/ore/O = ore_type
		I = image(initial(O.icon), icon_state = initial(O.icon_state), layer = TURF_LAYER + 0.01)
		I.alpha = 150
		I.transform = matrix(0.6, 0, 0, 0, 0.6, 0)
		I.appearance_flags = RESET_COLOR
		markers[ore_type] = I
	return I

/proc/mountain_seam_show(turf/T, announce = FALSE)
	if (!mountain_seam_ground(T) || !mountain_seam_is_seam(T.x, T.y))
		return null
	var/ore_type = mountain_seam_district_ore(T.x, T.y)
	var/image/I = mountain_seam_marker(ore_type)
	T.overlays -= I
	T.overlays += I
	if (announce)
		T.visible_message(SPAN_NOTICE("A vein of [mountain_seam_ore_name(ore_type)] runs on down into the floor here."))
	return ore_type

// Mining a wall over a seam reveals it (pickaxe, shovel and blasts all end here).
/turf/change_the_turf()
	var/tx = x
	var/ty = y
	var/tz = z
	..()
	if (map && map.mountain_seams)
		mountain_seam_show(locate(tx, ty, tz), TRUE)

// Markers are runtime, so put them back once the world is up.
/proc/mountain_seam_mark_all()
	. = 0
	var/work = 0
	// The Americas maps use the plain caves area for all their rock.
	var/area/A = locate(/area/caribbean/void/caves)
	if (!A)
		return
	for (var/turf/floor/dirt/T in A)
		if (T.z == 1 && mountain_seam_show(T))
			.++
		if (environment_sweep_pause(++work))
			work = 0

/proc/mountain_seam_watch_loop()
	set waitfor = FALSE
	while (!mountain_seam_marked)
		if (map && !map.mountain_seams)
			return
		if (map && building_standing_ready())
			mountain_seam_marked = TRUE
			var/count = mountain_seam_mark_all()
			world.log << "Mountain seams: [count] exposed seams marked."
			return
		sleep(MOUNTAIN_SEAM_POLL)

/hook/startup/proc/mountain_seams()
	mountain_seam_watch_loop()
	return TRUE

// ---------------------------------------------------------------- working
/turf/floor/dirt/attackby(obj/item/C, mob/user)
	if (istype(C, /obj/item/weapon/material/pickaxe) && ishuman(user) && mountain_seam_ground(src))
		mountain_seam_work(user, C, src)
		return TRUE
	return ..()

/turf/floor/dirt/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	if (!mountain_seam_ground(src))
		return
	if (!mountain_seam_is_seam(x, y))
		to_chat(user, "Bare bedrock of an old mountain. A pickaxe can still quarry stone from it.")
		return
	var/ore_type = mountain_seam_district_ore(x, y)
	var/ore_name = mountain_seam_ore_name(ore_type)
	if (!mountain_seam_live_ore(x, y))
		to_chat(user, "A seam of [ore_name] runs down into the rock, an ore you cannot work yet.")
		return
	var/datum/resource_stock/stock = mountain_seam_stock[ "[x],[y],[z]" ]
	var/left = stock ? stock.available() : MOUNTAIN_SEAM_LOADS
	var/state = left >= MOUNTAIN_SEAM_LOADS ? "rich" : (left > 0 ? "thinning" : "worked out for now")
	to_chat(user, "A seam of [ore_name] runs down into the rock. It looks [state].")

// Puts the load on the tile; returns the ore type given, or null for stone only.
/proc/mountain_seam_yield(turf/T, mob/living/human/H)
	var/ore_type = mountain_seam_is_seam(T.x, T.y) ? mountain_seam_live_ore(T.x, T.y) : null
	if (ore_type)
		var/datum/resource_stock/stock = mountain_seam_stock_at(T)
		if (!stock.take())
			ore_type = null
			if (H)
				to_chat(H, SPAN_NOTICE("The seam is worked back to bare rock; give it time."))
	// The continent's own rate (continent_resources.dm): a scarce ore sometimes gives only stone.
	var/amount = 0
	if (ore_type)
		var/list/row = mountain_seam_ores()[ore_type]
		amount = continent_seam_amount(ore_type, rand(row[3], row[4]), T)
		if (amount < 1)
			ore_type = null
	var/obj/item/stack/material/stone/S = new /obj/item/stack/material/stone(T)
	if (ore_type)
		S.amount = rand(4, 6)
		var/obj/item/stack/ore/O = new ore_type(T)
		O.amount = min(amount, O.max_amount)
		O.update_icon()
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You work some [initial(O.name)] loose from the seam."))
	else
		S.amount = rand(6, 10)
		if (H)
			to_chat(H, SPAN_NOTICE("You quarry some stone from the bedrock."))
	S.update_icon()
	return ore_type

/proc/mountain_seam_work(mob/living/human/H, obj/item/weapon/material/pickaxe/P, turf/T)
	var/tile_key = "[T.x],[T.y],[T.z]"
	var/worker_key = "\ref[H]"
	if (mountain_seam_busy[tile_key] || mountain_seam_busy[worker_key] || H.pickaxe_mining_action || !H.may_do_after)
		return FALSE
	if (get_dist(H, T) > 1)
		return FALSE
	mountain_seam_busy[tile_key] = TRUE
	mountain_seam_busy[worker_key] = TRUE
	. = FALSE
	var/time = work_delay_per_speed(H, MOUNTAIN_SEAM_WORK, WORK_MINE, P)
	H.visible_message(SPAN_NOTICE("[H] starts to work the old mountain floor with \the [P]."), SPAN_NOTICE("You start to work the old mountain floor with \the [P]."))
	playsound(T, 'sound/effects/pickaxe.ogg', 100, TRUE)
	var/datum/resource_work_animation/work_animation = H.prepare_resource_work_animation(P, T, time)
	var/done = do_after(H, time, T)
	if (work_animation)
		work_animation.stop()
	if (done && P.loc == H && get_dist(H, T) <= 1 && mountain_seam_ground(T))
		H.adaptStat("strength", 1)
		mountain_seam_yield(T, H)
		. = TRUE
	mountain_seam_busy -= tile_key
	mountain_seam_busy -= worker_key

#undef MOUNTAIN_SEAM_POLL
