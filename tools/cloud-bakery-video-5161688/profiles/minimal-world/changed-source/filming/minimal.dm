// Standalone control: no Civ13 game includes, project art, sounds or simulation.
#define MINIMAL_WORLD_RELEASED TRUE
var/client/minimal_client
var/minimal_port
var/minimal_ready = FALSE
var/minimal_stopping = FALSE

/world
	name = "Civ13 minimal startup control"
	hub = ""
	hub_password = ""
	visibility = FALSE
	maxx = 15
	maxy = 15
	maxz = 1
	fps = 20
	view = 7
	mob = /mob/minimal_observer
	turf = /turf/minimal

/turf/minimal
	icon = null

/mob/minimal_observer
	icon = null
	density = FALSE
	invisibility = 101

/proc/minimal_stop(reason)
	if (minimal_stopping)
		return
	minimal_stopping = TRUE
	world.OpenPort("none")
	text2file(reason, "intro-stop.txt")
	del(world)

/proc/minimal_marker(label)
	text2file("[world.time] [label]", "intro-checks.txt")

/world/OpenPort(requested)
	if (requested == "none")
		return ..("none")
	if (MINIMAL_WORLD_RELEASED && minimal_ready && requested == minimal_port)
		return ..(requested)
	return FALSE

/world/Topic()
	return null

/world/Reboot()
	minimal_stop("reboot prohibited")

/world/Error(exception/E)
	minimal_stop("minimal native error: [E.name]")

/world/New()
	OpenPort("none")
	if (!MINIMAL_WORLD_RELEASED)
		minimal_stop("NATIVE HOLD: minimal world source review only")
		return
	if (port || byond_version != 516 || byond_build != 1688 || maxx != 15 || maxy != 15 || maxz != 1)
		minimal_stop("minimal engine, dimensions or closed-port mismatch")
		return
	minimal_port = text2num(params["intro_port"])
	if (params["observer_mode"] != "engine_guest_camera" || minimal_port < 1024 || minimal_port > 65535)
		minimal_stop("minimal explicit loopback observer parameters missing")
		return
	minimal_ready = TRUE
	OpenPort(minimal_port)
	if (port != minimal_port)
		minimal_stop("minimal listener failed")
		return
	text2file("port=[port];version=516;build=1688", "cloud-listening.txt")
	spawn(2400)
		minimal_stop("bounded minimal-world timeout")

/client/New()
	if (!MINIMAL_WORLD_RELEASED || !minimal_ready || minimal_client || copytext(key,1,7) != "Guest-" || address != "127.0.0.1" || byond_version != 516 || byond_build != 1688)
		del(src)
		return
	minimal_client = src
	minimal_marker("minimal client before native New")
	..()
	minimal_marker("minimal client after native New")
	if (!istype(mob,/mob/minimal_observer) || mob.client != src)
		minimal_stop("minimal observer binding failed")
		return
	eye = mob
	perspective = EYE_PERSPECTIVE
	view = 7
	fps = 20
	minimal_marker("minimal guest engine 516.1688")
	text2file("guest=1;version=516;build=1688", "cloud-client.txt")

/mob/minimal_observer/Login()
	..()
	loc = locate(8,8,1)
	if (client != minimal_client)
		minimal_stop("minimal Login binding failed")
		return
	minimal_marker("minimal observer Login")

/client/Del()
	if (src == minimal_client)
		minimal_stop("minimal observer disconnected")
	return ..()

/client/Topic()
	return null

/client/Move()
	return FALSE
