// Full-source probe: pointing at a tile with Shift+middle-click.
/world
	hub = ""
	visibility = 0
	maxx = 20
	maxy = 20
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/pointing_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/pointing_probe/New()
	map = src

/turf/floor/plating/pointing_probe

/mob/living/human/pointing_probe/human_subtile_authority(client/owner)
	return TRUE

var/pointing_probe_checks = 0
var/list/pointing_probe_notes = list()

/proc/pointing_probe_assert(ok, label)
	pointing_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/pointing_probe_actor(tx, ty)
	var/mob/living/human/pointing_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Pointer"
	H.name = H.real_name
	return H

/proc/pointing_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/pointing_probe
	pointing_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	// Shift+middle-click on a tile: an arrow over it, drawn above lighting,
	// roofs and canopies, and the pointer turns to face it.
	var/mob/living/human/pointing_probe/H = pointing_probe_actor(10, 8)
	H.dir = SOUTH
	var/turf/T = locate(13, 8, 1)
	H.next_click = -1
	H.ClickOn(T, "shift=1;middle=1")
	var/obj/effect/decal/point/P = locate() in T
	pointing_probe_assert(P, "tile_point_makes_arrow")
	pointing_probe_assert(P.plane == CHAT_PLANE && P.plane > LIGHTING_MASK_PLANE && P.plane > ROOT_WEATHER_PLANE, "arrow_above_light_roof_weather")
	pointing_probe_assert(P.icon_state in icon_states(P.icon), "arrow_sprite_exists")
	pointing_probe_assert(!P.mouse_opacity && !P.invisibility && !P.should_save, "arrow_is_a_marker")
	pointing_probe_assert(H.dir == EAST, "pointer_faces_target")

	// A plain middle-click is not a point.
	var/turf/plain = locate(10, 11, 1)
	H.next_click = -1
	H.ClickOn(plain, "middle=1")
	pointing_probe_assert(!(locate(/obj/effect/decal/point) in plain), "plain_middle_click_does_not_point")

	// The widescreen view is ten tiles to each side and seven up and down.
	var/turf/wide = locate(20, 8, 1)
	pointing_probe_assert(H.pointed(wide) && (locate(/obj/effect/decal/point) in wide), "widescreen_edge_point")
	H.forceMove(locate(9, 8, 1))
	pointing_probe_assert(!H.pointed(wide) && !H.pointed(locate(9, 16, 1)), "off_screen_refused")
	pointing_probe_assert(H.pointed(locate(9, 15, 1)), "top_edge_point")

	// People and things: the arrow goes over their tile.
	var/mob/living/human/pointing_probe/other = pointing_probe_actor(6, 6)
	pointing_probe_assert(H.pointed(other) && (locate(/obj/effect/decal/point) in other.loc), "points_at_person")
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(locate(7, 10, 1))
	pointing_probe_assert(H.pointed(K) && (locate(/obj/effect/decal/point) in K.loc), "points_at_item")
	var/obj/item/weapon/material/kitchen/utensil/knife/held = new(other)
	pointing_probe_assert(!H.pointed(held), "hidden_item_refused")
	pointing_probe_assert(!H.pointed(P), "arrow_itself_refused")

	// Out cold, dead or tied up: no pointing.
	H.stat = UNCONSCIOUS
	pointing_probe_assert(!H.pointed(T), "unconscious_refused")
	H.stat = CONSCIOUS
	H.canmove = FALSE
	pointing_probe_assert(!H.pointed(T), "immobile_refused")
	H.canmove = TRUE

	// The arrow goes away by itself after two seconds.
	sleep(25)
	pointing_probe_assert(QDELETED(P) || !P.loc, "arrow_expires")
	pointing_probe_assert(!(locate(/obj/effect/decal/point) in wide), "all_arrows_expire")

/world/New()
	OpenPort("none")
	var/error = null
	try
		pointing_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = pointing_probe_checks, "error" = error, "notes" = pointing_probe_notes, "byond_build" = byond_build)), "receipt.json")
	del(world)
