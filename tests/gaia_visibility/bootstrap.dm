// Test-only bootstrap. External admission must additionally own loopback bind,
// an empty runtime cwd, process cleanup and OS egress containment. No live files.
var/global/list/gaia_visibility_allowlist = list()
var/global/gaia_visibility_port = 0
var/global/gaia_visibility_opening = FALSE
var/global/gaia_visibility_ready = FALSE
var/global/gaia_visibility_deadline = 0
var/global/gaia_visibility_denied_effects = 0

/world
	name = "Isolated Gaia visibility candidate"
	hub = ""
	hub_password = ""
	visibility = 0
	mob = /mob/living/human

/proc/gaia_visibility_denied_native()
	gaia_visibility_denied_effects++
	return null
/proc/gaia_visibility_denied_shell()
	gaia_visibility_denied_effects++
	return FALSE
/world/proc/gaia_visibility_denied_setting()
	gaia_visibility_denied_effects++
	return FALSE
/world/Export()
	gaia_visibility_denied_effects++
	return null
/world/Import()
	gaia_visibility_denied_effects++
	return null
/world/OpenPort(port)
	if(port == "none")
		return ..()
	if(gaia_visibility_opening && gaia_visibility_ready && port == gaia_visibility_port && port >= 1024 && port <= 65535)
		return ..()
	return FALSE

/proc/gaia_visibility_global_init()
	world.OpenPort("none")
	config = new /datum/configuration()
	config.disable_fov = TRUE
	makeDatumRefLists()
	initialize_chemical_reagents()
	initialize_chemical_reactions()

/proc/gaia_visibility_admit(client/C)
	if(!gaia_visibility_ready || world.time >= gaia_visibility_deadline || clients.len >= 3)
		return FALSE
	if(!(C.address in list(null, "127.0.0.1", "::1")) || !(C.ckey in gaia_visibility_allowlist))
		return FALSE
	for(var/client/existing in clients)
		if(existing.ckey == C.ckey)
			return FALSE
	return TRUE

/proc/gaia_visibility_start()
	world.OpenPort("none")
	// No normal startup, hooks, restart/import detection, scheduler or services.
	// Parameter admission is not an approval: external owner must review first.
	var/list/options = params2list(world.params)
	var/list/keys = splittext(istext(options["fixture_clients"]) ? options["fixture_clients"] : "", ",")
	if(options["fixture_admit"] != "gaia-visibility-reviewed" || keys.len != 3)
		world.log << "GAIA VISIBILITY CLOSED: missing reviewed three-client admission"
		del(world)
		return
	for(var/key in keys)
		var/normalized = ckey(key)
		if(!normalized || normalized in gaia_visibility_allowlist)
			del(world)
			return
		gaia_visibility_allowlist += normalized
	gaia_visibility_port = text2num(options["fixture_port"])
	if(gaia_visibility_port < 1024 || gaia_visibility_port > 65535 || gaia_visibility_port != round(gaia_visibility_port))
		del(world)
		return
	populate_material_list()
	create_lighting("night")
	var/process/time_of_day_change/daylight = new
	daylight.setup()
	daylight.changeto = "night"
	daylight.announce = FALSE
	daylight.fire(TRUE)
	// Only lighting and per-client visibility, not full game process setup.
	var/process/lighting_sources/sources = new
	var/process/lighting_overlays/overlays = new
	sources.setup()
	overlays.setup()
	gaia_visibility_deadline = world.time + 6000 // fixed ten-minute ceiling
	gaia_visibility_ready = TRUE
	gaia_visibility_opening = TRUE
	world.OpenPort(gaia_visibility_port)
	gaia_visibility_opening = FALSE
	if(world.port != gaia_visibility_port)
		gaia_visibility_stop()
		return
	spawn(0)
		while(gaia_visibility_ready && world.time < gaia_visibility_deadline)
			sources.run_time_tick_usage = world.tick_usage
			sources.fire()
			overlays.run_time_tick_usage = world.tick_usage
			overlays.fire()
			for(var/client/C in clients)
				C.reconcile_geometric_los()
			sleep(1)
		gaia_visibility_stop()

/proc/gaia_visibility_stop()
	gaia_visibility_ready = FALSE
	world.OpenPort("none")
	for(var/client/C in clients.Copy())
		C.set_geometric_los(FALSE)
		del(C)
	gaia_visibility_allowlist.Cut()
	world.log << "GAIA VISIBILITY STOPPED: denied effects [gaia_visibility_denied_effects]"
	del(world)
