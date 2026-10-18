#define TRUE 1
#define FALSE 0
#define GAME_PLANE 1
#define LIGHTING_PLANE 3
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
			var/obj/screen/plane_master/lighting/P = new
			var/obj/screen/plane_master/lighting/other = new
			var/mob/M = new
			var/list/lit = list(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1)
			var/list/bypass = list(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1)
			check(P.invisibility == 0 && P.blend_mode == BLEND_MULTIPLY, "eligible multiply plane")
			check(P.mouse_opacity == 0, "no input interception")
			for(var/vision in list(0,20,25,35,44,45,60,25,45,25))
				M.see_invisible = vision
				var/original_sight = M.sight
				P.backdrop(M)
				check_matrix(P.color, vision >= 45 ? bypass : lit, "vision [vision]")
				check(M.see_invisible == vision && M.sight == original_sight, "sight unchanged")
				var/list/retained_color = P.color
				P.backdrop(M)
				check(P.color == retained_color, "unchanged mode retains matrix")
			M.see_invisible = 60
			other.backdrop(M)
			check_matrix(P.color, lit, "independent client mode")
			check_matrix(other.color, bypass, "other client bypass")
			check(P.color != other.color, "independent matrices")
			world.log << "PASS checks=[checks]"
		catch(var/exception/E)
			world.log << "FAIL checks=[checks] [E.name]"
		del(world)
