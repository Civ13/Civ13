#define TRUE 1
#define FALSE 0
#define GAME_PLANE 1
#define LIGHTING_PLANE 3
#define LIGHTING_MASK_PLANE 4
#define LIGHTING_LAYER 11
#define HUD_PLANE 15
#define INVISIBILITY_LIGHTING 20
#define INVISIBILITY_LEVEL_TWO 45

/datum/hud
	var/list/plane_masters = list()
/mob
	var/datum/hud/hud_used

var/checks = 0
/proc/check(value, label)
	checks++
	if(!value)
		throw EXCEPTION(label)

/proc/check_matrix(list/value, list/expected, label)
	check(islist(value) && value.len == 20, "[label] length")
	for(var/i in 1 to 20)
		check(value[i] == expected[i], "[label] coefficient [i]")

/atom/movable
	var/anchored = FALSE
	var/simulated = FALSE
	var/should_save = TRUE
/turf
	var/atom/movable/lighting_overlay
/area
	var/dynamic_lighting = TRUE
/datum/map_fixture
	var/list/zlevels_without_lighting = list()
var/datum/map_fixture/map
/proc/get_area(atom/A)
	return A.loc
/proc/qdel(atom/A)
	del(A)
/proc/environment_sweep_pause(work)
	return FALSE

/world
	hub = ""
	visibility = 0
	maxx = 1
	maxy = 1
	maxz = 1

/world/OpenPort(port)
	if(port == "none")
		return ..()
	return FALSE

/client/New()
	return null

/world/New()
	OpenPort("none")
	spawn(0)
		try
			check(!world.port && !OpenPort(59474) && !world.port, "closed port")
			var/obj/screen/plane_master/light_mask/P = new
			#if LIGHTING_COMPOSITION_V2
			var/obj/screen/plane_master/light_mask/other = new
			var/mob/M = new
			var/list/lit = list(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1)
			var/list/bypass = list(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1)
			#endif
			check(P.invisibility == 0 && P.blend_mode == BLEND_MULTIPLY, "eligible multiply plane")
			check(P.mouse_opacity == 0, "no input interception")
			var/obj/screen/plane_master/lighting/weather = new
			check(weather.plane != P.plane, "weather separated from light RGB")
			#if LIGHTING_COMPOSITION_V2
			check(weather.blend_mode == BLEND_OVERLAY && weather.invisibility == 0, "weather plane remains visible")
			for(var/vision in list(0,20,25,35,44,45,60,25,45,25))
				M.see_invisible = vision
				var/original_sight = M.sight
				P.backdrop(M)
				check_matrix(P.color, vision >= 45 ? bypass : lit, "vision [vision]")
				check(M.see_invisible == vision && M.sight == original_sight, "sight unchanged")
				var/retained_mode = P.last_lighting_bypass
				P.backdrop(M)
				check(P.last_lighting_bypass == retained_mode, "unchanged mode remains cached")
			M.see_invisible = 60
			other.backdrop(M)
			check_matrix(P.color, lit, "independent client mode")
			check_matrix(other.color, bypass, "other client bypass")
			check(P.color != other.color, "independent matrices")
			#else
			check(weather.blend_mode == BLEND_MULTIPLY && weather.invisibility == INVISIBILITY_LEVEL_TWO, "disabled retains legacy plane")
			#endif
			var/turf/T = locate(1,1,1)
			var/area/A = T.loc
			check(!T.needs_fullbright_coverage(), "missing dynamic overlay is not fullbright")
			A.dynamic_lighting = FALSE
			check(T.needs_fullbright_coverage(), "explicit non-dynamic policy")
			T.sync_fullbright_coverage()
			#if LIGHTING_COMPOSITION_V2
			var/atom/movable/lighting_fullbright/F = locate() in T
			check(F && F.plane == LIGHTING_MASK_PLANE, "explicit fullbright coverage")
			check(F.luminosity == 0 && !F.should_save, "coverage neither reveals nor persists")
			T.sync_fullbright_coverage()
			check((locate(/atom/movable/lighting_fullbright) in T) == F, "idempotent retained owner")
			new /atom/movable/lighting_fullbright(T)
			T.sync_fullbright_coverage()
			var/coverage_count = 0
			for(var/atom/movable/lighting_fullbright/owned in T)
				coverage_count++
			check(coverage_count == 1, "duplicate coverage retired")
			A.dynamic_lighting = TRUE
			T.sync_fullbright_coverage()
			check(!(locate(/atom/movable/lighting_fullbright) in T), "dynamic transition retires coverage")
			map = new
			map.zlevels_without_lighting += 1
			T.sync_fullbright_coverage()
			check(locate(/atom/movable/lighting_fullbright) in T, "excluded z has explicit coverage")
			T.lighting_overlay = new /atom/movable(T)
			T.sync_fullbright_coverage()
			check(!(locate(/atom/movable/lighting_fullbright) in T), "actual mask wins over fullbright policy")
			#else
			check(!(locate(/atom/movable/lighting_fullbright) in T), "disabled allocates no coverage")
			#endif
			world.log << "PASS checks=[checks]"
		catch(var/exception/E)
			world.log << "FAIL checks=[checks] [E.name]"
		del(world)
