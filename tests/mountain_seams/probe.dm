// Native fixture for code/modules/1713/mountain_seams.dm, built by native.py
// with the real mountain_seams.dm, resource_stock.dm and hex2num().
#define MINUTES *600
#define SECONDS *10
#define TURF_LAYER 2
#define SPAN_NOTICE(X) X
#define SPAN_GREEN_BOLD(X) X

/world
	maxx = 240
	maxy = 240
	maxz = 2
	turf = /turf/floor/dirt
	area = /area/caribbean/void/caves

/area/caribbean/void/caves
/area/plain

/turf/var/is_mineable = FALSE
/turf/floor
/turf/floor/dirt
/turf/floor/dirt/underground
	is_mineable = TRUE
/turf/proc/change_the_turf()
	new /turf/floor/dirt(src)

/obj/var/anchored = FALSE
/proc/pass()
	return
/obj/covers
/obj/structure/wall_stub
	density = TRUE
	anchored = TRUE
/obj/item
/obj/item/stack
	var/amount = 1
/obj/item/stack/material/stone
	name = "stone"
/obj/item/stack/ore
	name = "ore"
	icon_state = "ore2"
/obj/item/stack/ore/copper
	name = "copper ore"
/obj/item/stack/ore/tin
	name = "tin ore"
/obj/item/stack/ore/iron
	name = "iron ore"
/obj/item/stack/ore/zinc
	name = "calamine"
/obj/item/stack/ore/coal
	name = "coal"
/obj/item/stack/ore/saltpeter
	name = "saltpeter"
/obj/item/stack/ore/sulphur
	name = "sulphur"
/obj/item/stack/ore/lead
	name = "lead ore"
/obj/item/stack/ore/silver
	name = "silver ore"
/obj/item/stack/ore/gold
	name = "gold ore"
/obj/item/weapon/material/pickaxe
	var/usespeed = 1
/atom/proc/update_icon()
	return
/atom/proc/attackby(obj/item/C, mob/user)
	return FALSE
/atom/proc/examine(mob/user, distance = -1, infix = "", suffix = "")
	return TRUE
/atom/proc/visible_message(message)
	world.log << "SAY [message]"

/mob/living/human
	var/may_do_after = TRUE
	var/pickaxe_mining_action = null
	var/strength_gained = 0
/mob/living/human/proc/getStatCoeff(stat)
	return 1
/mob/living/human/proc/adaptStat(stat, amount)
	strength_gained += amount
/mob/living/human/proc/prepare_resource_work_animation(tool, target, duration)
	return null
/mob/living/human/visible_message(message, self_message)
	return
/datum/resource_work_animation/proc/stop()
	return

/obj/map_metadata
	var/ID = "NOMADS_AMERICAS_NORTH"
	var/ordinal_age = 0
var/global/obj/map_metadata/map = null
var/global/list/probe_chat = list()
/proc/to_chat(target, message)
	probe_chat += "[message]"
/proc/ishuman(A)
	return istype(A, /mob/living/human)
/proc/playsound()
	return
/proc/do_after(mob/user, delay, atom/target)
	return TRUE
/proc/building_standing_ready()
	return TRUE
/proc/environment_sweep_pause(work)
	return FALSE
/hook/startup

var/global/probe_failures = 0
/proc/check(condition, text)
	if (!condition)
		probe_failures++
		world.log << "FAIL [text]"

/proc/count_type(turf/T, type)
	. = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, type))
			. += S.amount

/proc/clear_tile(turf/T)
	for (var/obj/O in T)
		del(O)

// The first seam tile at or after x, y whose district ore is ore_type.
/proc/find_seam(ore_type)
	for (var/y = 1, y <= world.maxy, y++)
		for (var/x = 1, x <= world.maxx, x++)
			if (mountain_seam_is_seam(x, y) && mountain_seam_district_ore(x, y) == ore_type)
				return locate(x, y, 1)
	return null

/proc/find_bedrock()
	for (var/x = 1, x <= world.maxx, x++)
		if (!mountain_seam_is_seam(x, 1))
			return locate(x, 1, 1)

/proc/run_probe()
	map = new
	// Hash parity with the Python mirror in test_source.py.
	for (var/text in list("1,1,NOMADS_AMERICAS_NORTH", "517,233,NOMADS_AMERICAS_SOUTH", "3,4,NOMADS_AMERICAS_NORTH,ore"))
		world.log << "HASH [text]=[mountain_seam_hash(text)]"

	// Off by default.
	map.mountain_seams = FALSE
	var/turf/T = locate(10, 10, 1)
	check(!mountain_seam_ground(T), "a map without mountain_seams has no seam ground")
	map.mountain_seams = TRUE
	check(mountain_seam_ground(T), "open dirt in the caves area is seam ground")
	check(!mountain_seam_ground(locate(10, 10, 2)), "only the surface level counts")
	var/turf/floor/dirt/underground/rock = new /turf/floor/dirt/underground(locate(11, 10, 1))
	check(!mountain_seam_ground(rock), "standing rock is mined the usual way")
	var/area/plain/P = new
	P.contents += locate(12, 10, 1)
	check(!mountain_seam_ground(locate(12, 10, 1)), "dirt outside the old mountains is not seam ground")
	new /obj/covers(locate(13, 10, 1))
	check(!mountain_seam_ground(locate(13, 10, 1)), "a covered tile is not seam ground")
	new /obj/structure/wall_stub(locate(14, 10, 1))
	check(!mountain_seam_ground(locate(14, 10, 1)), "a tile under a dense structure is not seam ground")

	// Share and districts over the whole fixture.
	var/seams = 0
	var/list/ores = list()
	for (var/y = 1, y <= world.maxy, y++)
		for (var/x = 1, x <= world.maxx, x++)
			if (mountain_seam_is_seam(x, y))
				seams++
				var/ore = mountain_seam_district_ore(x, y)
				ores[ore] = (ores[ore] || 0) + 1
	var/share = seams / (world.maxx * world.maxy)
	check(share > 0.07 && share < 0.097, "about one tile in twelve is a seam ([share])")
	check(ores[/obj/item/stack/ore/iron] && ores[/obj/item/stack/ore/copper] && ores[/obj/item/stack/ore/coal], "iron, copper and coal districts exist")

	// Mining the rock over a seam reveals it.
	var/turf/copper = find_seam(/obj/item/stack/ore/copper)
	var/turf/iron = find_seam(/obj/item/stack/ore/iron)
	check(copper && iron, "copper and iron seams found")
	var/cx = copper.x
	var/cy = copper.y
	new /turf/floor/dirt/underground(copper)
	copper = locate(cx, cy, 1)
	copper.change_the_turf()
	copper = locate(cx, cy, 1)
	check(copper.overlays.len == 1, "a revealed seam shows its marker")
	copper.change_the_turf()
	copper = locate(cx, cy, 1)
	var/turf/again = locate(cx, cy, 1)
	again.overlays.Cut()
	mountain_seam_show(again)
	mountain_seam_show(again)
	check(again.overlays.len == 1, "the marker is never added twice")

	// Six loads, then stone only, then one comes back.
	var/mob/living/human/H = new(locate(cx + 1, cy, 1))
	var/obj/item/weapon/material/pickaxe/pick = new(H)
	for (var/i = 1, i <= 6, i++)
		clear_tile(copper)
		check(mountain_seam_yield(copper, H) == /obj/item/stack/ore/copper, "load [i] gives copper")
		var/got = count_type(copper, /obj/item/stack/ore/copper)
		check(got >= 4 && got <= 8, "a copper load is 4-8 ore ([got])")
		var/stone = count_type(copper, /obj/item/stack/material/stone)
		check(stone >= 4 && stone <= 6, "a seam load carries 4-6 stone ([stone])")
	clear_tile(copper)
	check(!mountain_seam_yield(copper, H), "a worked-out seam gives no ore")
	check(!count_type(copper, /obj/item/stack/ore/copper), "no ore on a worked-out seam")
	check(count_type(copper, /obj/item/stack/material/stone) >= 6, "a worked-out seam still gives bedrock stone")
	var/datum/resource_stock/stock = mountain_seam_stock_at(copper)
	stock.since -= 20 MINUTES
	check(stock.available() == 1, "one load comes back after the regrowth time")

	// Age gates.
	clear_tile(iron)
	check(!mountain_seam_yield(iron, H), "iron seams wait for the Bronze Age")
	map.ordinal_age = 1
	clear_tile(iron)
	check(mountain_seam_yield(iron, H) == /obj/item/stack/ore/iron, "iron seams open at age 1")

	// Bedrock never runs out.
	var/turf/bed = find_bedrock()
	for (var/i = 1, i <= 20, i++)
		clear_tile(bed)
		mountain_seam_yield(bed, H)
		var/stone = count_type(bed, /obj/item/stack/material/stone)
		check(stone >= 6 && stone <= 10, "bedrock gives 6-10 stone ([stone])")

	// The full action: pickaxe on the floor, strength practice, busy flags cleared.
	clear_tile(bed)
	H.loc = locate(bed.x + 1, bed.y, 1)
	check(bed.attackby(pick, H), "a pickaxe on seam ground is handled")
	check(count_type(bed, /obj/item/stack/material/stone) >= 6, "the action quarries stone")
	check(H.strength_gained == 1, "the action trains strength once")
	check(!length(mountain_seam_busy), "busy flags are cleared")
	H.loc = locate(bed.x + 5, bed.y, 1)
	clear_tile(bed)
	check(!mountain_seam_work(H, pick, bed), "too far away does nothing")
	check(!count_type(bed, /obj/item/stack/material/stone), "no stone from too far away")

	// The start pass marks every exposed seam once.
	var/marked = mountain_seam_mark_all()
	check(marked > 100, "the start pass marks exposed seams ([marked])")

	if (!probe_failures)
		world.log << "PASS mountain seams probe"

/world/New()
	..()
	spawn(1)
		run_probe()
		del(world)
