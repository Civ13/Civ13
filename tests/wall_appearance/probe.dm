#define FALSE 0
#define TRUE 1
#define DEFAULT_WALL_MATERIAL "fixture"
#define BLEND_MULTIPLY 3
var/list/cardinal = list(NORTH, SOUTH, EAST, WEST)
var/list/wall_cache = list()
var/scenes = 0
var/comparisons = 0
var/appearance_failures = 0
var/count_failures = 0
var/list/count_samples = list()
var/list/failure_samples = list()
var/save_comparisons = 0
var/save_failures = 0

/material
	var/display_name = "fixture"
	var/explosion_resistance = 5
	var/icon_base = "generic"
	var/icon_colour = "#778899"
	var/opacity = 1
	var/integrity = 100
	var/hitsound

/proc/get_material_by_name(name)
	return new /material

/turf/wall
	name = "wall"
	desc = "fixture wall"
	var/material/material
	var/explosion_resistance
	var/last_state
	var/damage = 0
	var/damage_overlay = 0
	var/global/damage_overlays[16]
	var/probe_checks = 0
	var/probe_rebuilds = 0
	var/hitsound
	icon = 'icons/turf/wall_masks.dmi'
	map_storage_saved_vars = "icon_state;name"
	density = TRUE
	opacity = TRUE

/turf/wall/proc/set_light(value)
	// Isolated adapter records the immediate observable lighting request.
	luminosity = value
/turf/wall/proc/update_icon()
/turf/wall/proc/check_relatives(update_self, update_others)
/turf/wall/proc/can_join_with(atom/W)
/atom/movable/lighting_overlay/proc/update_overlay()
	return
/turf/wall/baseline/sub_bulkhead
	var/draw_color_lines = TRUE
	var/color_lines_color = "#007F00"
/turf/wall/candidate/sub_bulkhead
	var/draw_color_lines = TRUE
	var/color_lines_color = "#007F00"
/turf/wall/baseline/rockwall
/turf/wall/candidate/rockwall

/proc/appearance_row(image/I)
	var/matrix/M = I.transform
	return list("icon"="[I.icon]", "state"=I.icon_state, "dir"=I.dir, "color"=I.color, "alpha"=I.alpha, "layer"=I.layer, "plane"=I.plane, "blend"=I.blend_mode, "x"=I.pixel_x, "y"=I.pixel_y, "flags"=I.appearance_flags, "transform"=list(M.a,M.b,M.c,M.d,M.e,M.f))

/proc/snapshot(turf/wall/W)
	var/list/result = list("name"=W.name, "desc"=W.desc, "state"=W.last_state, "damage"=W.damage_overlay, "density"=W.density, "opacity"=W.opacity, "light"=W.luminosity, "explosion"=W.explosion_resistance)
	result["appearance"] = appearance_row(new /image(W))
	var/list/ov = list()
	for (var/O in W.overlays)
		ov += list(appearance_row(new /image(O)))
	result["overlays"] = ov
	return json_encode(result)

/proc/group_snapshot(list/walls)
	var/list/result = list()
	for (var/turf/wall/W in walls)
		result += snapshot(W)
	return json_encode(result)

/proc/group_count(list/walls, field)
	var/result = 0
	for (var/turf/wall/W in walls)
		result += W.vars[field]
	return result

/proc/make_group(typepath, x, mask)
	var/turf/wall/center = new typepath(locate(x,8,1))
	var/list/result = list(center)
	var/bit = 1
	for (var/D in cardinal)
		if (mask & bit)
			var/turf/wall/W = new typepath(get_step(center,D))
			W.material = new /material
			result += W
		bit *= 2
	return result

/proc/clear_group(list/walls)
	for (var/turf/wall/W in walls)
		new /turf(W)

/proc/run_scene(btype, ctype, mask, dense, injury, facing)
	var/list/B = make_group(btype,8,mask)
	var/list/C = make_group(ctype,24,mask)
	var/turf/wall/b = B[1]
	var/turf/wall/c = C[1]
	b.density = c.density = dense
	b.damage = c.damage = injury
	b.dir = c.dir = facing
	for (var/pass = 1, pass <= 3, pass++)
		var/material/M = new
		if (pass == 2)
			M.icon_colour = "#AA5522"
			M.icon_base = "wood"
		else if (pass == 3)
			M = null
		var/beforeB = group_count(B,"probe_checks")
		var/beforeC = group_count(C,"probe_checks")
		var/rebuildB = group_count(B,"probe_rebuilds")
		var/rebuildC = group_count(C,"probe_rebuilds")
		b:set_material(M)
		c:set_material(M)
		comparisons++
		if (group_snapshot(B) != group_snapshot(C))
			appearance_failures++
			if (failure_samples.len < 2)
				failure_samples += list(list("type"="[btype]","mask"=mask,"dense"=dense,"injury"=injury,"pass"=pass,"baseline"=group_snapshot(B),"candidate"=group_snapshot(C)))
		var/bcount = group_count(B,"probe_checks") - beforeB
		var/ccount = group_count(C,"probe_checks") - beforeC
		// Null material exits every production check early (not counted).
		var/expected_saving = M ? B.len : 0
		if (bcount - ccount != expected_saving)
			count_failures++
		if (mask == 15 && dense && injury == 0 && facing == SOUTH && pass == 1)
			count_samples += list(list("type"="[btype]", "baseline"=bcount, "candidate"=ccount,"baseline_rebuilds"=group_count(B,"probe_rebuilds")-rebuildB,"candidate_rebuilds"=group_count(C,"probe_rebuilds")-rebuildC))
	scenes++
	clear_group(B)
	clear_group(C)

/proc/save_scene(btype, ctype)
	var/list/B = make_group(btype,8,15)
	var/list/C = make_group(ctype,24,15)
	var/turf/wall/b = B[1]
	var/turf/wall/c = C[1]
	b.dir = c.dir = NORTH
	b.damage = c.damage = 40
	b:set_material(new /material)
	c:set_material(new /material)
	map = new /obj/map_metadata(locate(1,1,1))
	map_storage.Save_World()
	// Native replacement of every saved turf by the real two-pass loader.
	if (!map_storage.Load_World() || map_storage.last_error || errors.len)
		throw EXCEPTION("Native wall save/load failed")
	B = list(locate(8,8,1))
	C = list(locate(24,8,1))
	for (var/D in cardinal)
		B += get_step(B[1],D)
		C += get_step(C[1],D)
	save_comparisons++
	if (group_snapshot(B) != group_snapshot(C))
		save_failures++
	clear_group(B)
	clear_group(C)
	qdel(map)
	map = null

/world
	maxx = 32
	maxy = 32
	maxz = 1
	turf = /turf
	fps = 10
/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE
/world/New()
	..()
	OpenPort("none")
	spawn(0)
		var/list/btypes = list(/turf/wall/baseline, /turf/wall/baseline/sub_bulkhead, /turf/wall/baseline/abashiri, /turf/wall/baseline/old_stone)
		var/list/ctypes = list(/turf/wall/candidate, /turf/wall/candidate/sub_bulkhead, /turf/wall/candidate/abashiri, /turf/wall/candidate/old_stone)
		for (var/k=1, k<=4, k++)
			for (var/mask=0, mask<16, mask++)
				for (var/dense=0, dense<=1, dense++)
					for (var/injury in list(0,40,100))
						for (var/facing in cardinal)
							run_scene(btypes[k],ctypes[k],mask,dense,injury,facing)
		for (var/k=1,k<=4,k++)
			save_scene(btypes[k],ctypes[k])
		var/list/result = list("scenes"=scenes,"comparisons"=comparisons,"appearance_failures"=appearance_failures,"count_failures"=count_failures,"count_samples"=count_samples,"cache_entries"=wall_cache.len,"failure_samples"=failure_samples,"save_comparisons"=save_comparisons,"save_failures"=save_failures)
		text2file(json_encode(result),"result.json")
		del(world)
