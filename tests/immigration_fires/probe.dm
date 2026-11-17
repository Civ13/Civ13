// Native probe of code/modules/1713/immigration_fires.dm,
// included by tests/ecology_spawning/run_linux.py, never by the game DME.
/world
	hub = ""
	hub_password = ""
	maxx = 220
	maxy = 220
	maxz = 1
	turf = /turf/floor/grass
	area = /area/fire_probe
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/area/fire_probe
	climate = "temperate"
/obj/map_metadata/nomads/fire_probe
	new_player_start_z = 1
/obj/map_metadata/nomads/fire_probe/New()
	map = src
/mob/living/human/fire_tester/New()
	return
var/fire_failures = 0
var/fire_runtime_error = FALSE
/proc/fire_check(condition, label)
	if (!condition)
		fire_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fire_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
var/fire_probe_host = TRUE
/obj/structure/oven/fireplace/fire_probe/immigration_host_near()
	return fire_probe_host
/proc/fire_probe_open(obj/structure/oven/fireplace/F, host, faction)
	F.on = TRUE
	var/lapses = world.time + 6000
	F.immigration_until = lapses
	F.immigration_host = host
	F.immigration_faction = faction
	immigration_fires |= F
/world/New()
	OpenPort("none")
	try
		var/obj/map_metadata/nomads/fire_probe/M = new
		var/obj/structure/oven/fireplace/fire_probe/F = new(locate(100, 100, 1))
		fire_check(immigration_land(), "a world outside any group is its own mainland")
		fire_check(!F.immigration_open() && !immigration_fire_choices().len, "a fire is closed until its keeper invites newcomers")
		fire_probe_open(F, "Ada Reed", "Rivermen")
		var/list/choices = immigration_fire_choices()
		fire_check(F.immigration_open() && choices.len == 1 && choices["Near Ada Reed's signal fire (Rivermen)"] == F, "an open fire is offered by its keeper's name and faction")
		fire_check(immigration_faction_calling("Rivermen") && !immigration_faction_calling("Hillfolk"), "only the keeper's faction is marked as calling")
		var/safe = TRUE
		var/found = 0
		for (var/i in 1 to 100)
			var/turf/T = F.immigration_ground()
			if (!T)
				continue
			found++
			var/away = sqrt((T.x - F.x) ** 2 + (T.y - F.y) ** 2)
			if (away < 5 || away > 21 || !M.new_player_has_exit(T))
				safe = FALSE
		fire_check(found == 100 && safe, "newcomers start on a safe tile 6 to 20 tiles from the fire ([found] of 100 found)")
		fire_probe_host = FALSE
		fire_check(!F.immigration_open() && (F in immigration_fires) && !immigration_fire_choices().len, "with nobody awake nearby the fire is not offered, but the invitation stands")
		fire_probe_host = TRUE
		fire_check(F.immigration_open(), "it is offered again when someone is back")
		F.on = FALSE
		fire_check(!F.immigration_open() && !(F in immigration_fires) && !F.immigration_until, "a fire that goes out ends the invitation at once")
		F.on = TRUE
		fire_check(!F.immigration_open(), "relighting does not bring the invitation back")
		fire_probe_open(F, "Ada Reed", null)
		choices = immigration_fire_choices()
		fire_check(choices["Near Ada Reed's signal fire"] == F, "a keeper without a faction is named alone")
		var/past = world.time - 1
		F.immigration_until = past
		fire_check(!F.immigration_open() && !(F in immigration_fires), "the invitation lapses when its time is up")
		fire_probe_open(F, "Ada Reed", null)
		shard_group.enabled = TRUE
		shard_group.mainland = "gaia"
		shard_group.region = "north_america"
		fire_check(!immigration_land() && !F.immigration_open() && !(F in immigration_fires), "other lands never offer immigration")
		shard_group.region = "gaia"
		fire_check(immigration_land(), "the mainland does")
		shard_group.enabled = FALSE
		fire_probe_open(F, "Ada Reed", null)
		M.new_player_start_z = 0
		fire_check(!F.immigration_open(), "a land without random starts takes no immigrants")
		M.new_player_start_z = 1
		fire_probe_open(F, "Ada Reed", null)
		fire_check(F.persistence_runtime_var("immigration_until") && F.persistence_runtime_var("immigration_host") && F.persistence_runtime_var("next_signal"), "the invitation is never saved, and the signal cooldown still is not")
		qdel(F)
		fire_check(!(F in immigration_fires) && !immigration_fire_choices().len, "a deleted fire leaves the list")
		fire_check(isnull(immigration_start_turf(null)), "no lobby gives no start")
	catch(var/exception/e)
		fire_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fire_failures, "runtime_error" = fire_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
