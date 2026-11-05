// Builds every gun, then unloads it, opens its bolt or cover and calls
// update_icon() after each step. Each sprite state the gun then asks for must
// exist: icon_state in its own icon (ground and inventory), item_state in the
// in-hand icons, and icon_state in the back/shoulder icon when it can be worn
// there, after the fallbacks the renderer applies. A missing state draws
// BYOND's error icon. run.py compares the gaps
// with known_missing.txt.
/obj/map_metadata/gun_icon_states_fixture/New()
	return
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	fps = 20
	turf = /turf
var/gun_icon_states_errors = 0
/world/Topic(T, addr, master, key)
	return "no"
/world/Error(exception/e, datum/e_src)
	gun_icon_states_errors++
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new /decl/observ/destroyed
	GLOB.nanomanager = new /datum/nanomanager
	map = new /obj/map_metadata/gun_icon_states_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	spawn(10) gun_icon_states_sweep()
/proc/gun_icon_states_record(obj/item/weapon/gun/G, step, list/seen)
	var/list/checks = list()
	if(G.icon && G.icon_state)
		checks["icon\t[G.icon_state]"] = G.icon
	if(G.item_state && G.item_icons)
		for(var/slot in list(slot_l_hand_str, slot_r_hand_str))
			if(G.item_icons[slot])
				checks["[slot]\t[G.sprite_state_for(G.item_icons[slot], G.item_state)]"] = G.item_icons[slot]
	if(G.icon_state && !G.icon_override && (G.slot_flags & (SLOT_BACK|SLOT_SHOULDER)))
		var/worn_icon = 'icons/mob/back.dmi'
		checks["worn\t[G.sprite_state_for(worn_icon, G.icon_state)]"] = worn_icon
	for(var/key in checks)
		var/icon_file = checks[key]
		var/list/parts = splittext(key, "\t")
		var/line = "[G.type]\t[parts[1]]\t[parts[2]]\t[icon_file]"
		if(seen[line])
			continue
		seen[line] = TRUE
		if(!(parts[2] in icon_states(icon_file)))
			text2file("MISSING\t[step]\t[line]", "gun_icon_missing.txt")
/proc/gun_icon_states_step(obj/item/weapon/gun/G, step, list/seen)
	try
		G.update_icon()
	catch(var/exception/e)
		text2file("THROW\t[G.type]\t[step]\t[e] on [e.file]:[e.line]", "gun_icon_throws.txt")
	gun_icon_states_record(G, step, seen)
/proc/gun_icon_states_sweep()
	var/n = 0
	for(var/T in typesof(/obj/item/weapon/gun))
		var/turf/loc = locate((n % 38) + 2, (round(n / 38) % 38) + 2, 1)
		n++
		var/obj/item/weapon/gun/G
		try
			G = new T(loc)
		catch(var/exception/e)
			text2file("THROW\t[T]\tnew\t[e] on [e.file]:[e.line]", "gun_icon_throws.txt")
			continue
		if(QDELETED(G))
			continue
		var/list/seen = list()
		gun_icon_states_record(G, "spawned", seen)
		gun_icon_states_step(G, "spawned", seen)
		if(istype(G, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/P = G
			P.ammo_magazine = null
			if(P.loaded)
				P.loaded.Cut()
			P.chambered = null
			gun_icon_states_step(G, "unloaded", seen)
		for(var/toggle in list("bolt_open", "cover_open", "cover_opened", "open"))
			if(toggle in G.vars)
				G.vars[toggle] = !G.vars[toggle]
				gun_icon_states_step(G, toggle, seen)
				G.vars[toggle] = !G.vars[toggle]
				gun_icon_states_step(G, "[toggle] reset", seen)
		if(n % 100 == 0)
			sleep(1)
	sleep(10)
	text2file("PASS: checked [n] gun types; [gun_icon_states_errors] async runtime errors", "gun_icon_result.txt")
	del(world)
