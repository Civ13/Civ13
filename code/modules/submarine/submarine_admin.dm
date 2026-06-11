// ============================================================
// SUBCOM13 Admin Panel - debug tools for testing and balance
// ============================================================

/datum/admins/proc/subcom13_panel()
	set category = "Map Controls"
	set name = "Subcom13 Panel"
	set desc = "Open the Submarine Commander debug panel"

	if(!check_rights(R_ADMIN)) return
	if(!istype(map, /obj/map_metadata/subcom13))
		to_chat(usr, "<span class='warning'>Not on SUBCOM13 map.</span>")
		return

	usr.client.holder.show_subcom13_panel()

/datum/admins/proc/show_subcom13_panel()
	var/dat = {"
	<html><head>
	<style>
		body { background: #111; color: #0f0; font-family: monospace; font-size: 12px; }
		h2 { color: #0f0; border-bottom: 1px solid #0f0; padding-bottom: 4px; }
		.panel { border: 1px solid #0f0; padding: 8px; margin: 8px 0; background: #1a1a1a; }
		.label { color: #0f0; font-weight: bold; font-size: 11px; }
		.btn { display: inline-block; padding: 4px 10px; margin: 2px; border: 1px solid #0f0;
		       background: #222; color: #0f0; text-decoration: none; cursor: pointer;
		       font-family: monospace; font-size: 11px; }
		.btn:hover { background: #0f0; color: #000; }
		.btn-red { border-color: #f00; color: #f00; }
		.btn-red:hover { background: #f00; color: #000; }
		.btn-yellow { border-color: #ff0; color: #ff0; }
		.btn-yellow:hover { background: #ff0; color: #000; }
		.btn-blue { border-color: #0af; color: #0af; }
		.btn-blue:hover { background: #0af; color: #000; }
		table { border-collapse: collapse; width: 100%; margin: 4px 0; }
		th, td { border: 1px solid #0f0; padding: 4px 8px; text-align: left; font-size: 11px; }
		th { background: #222; }
		.status-ok { color: #0f0; }
		.status-warn { color: #ff0; }
		.status-crit { color: #f00; }
	</style>
	</head><body>
	<h2>SUBCOM13 DEBUG PANEL</h2>
	"}

	// --- SUBMARINE STATUS ---
	var/obj/map_metadata/subcom13/SM = map
	var/datum/submarine/sub = SM?.created_sub
	if(sub)
		dat += "<div class='panel'>"
		dat += "<div class='label'>SUBMARINE STATUS</div>"
		dat += "<table>"
		dat += "<tr><th>Stat</th><th>Value</th></tr>"
		dat += "<tr><td>Position</td><td>[round(sub.x_pos)], [round(sub.y_pos)]</td></tr>"
		dat += "<tr><td>Heading</td><td>[round(sub.heading)]&deg;</td></tr>"
		dat += "<tr><td>Speed</td><td>[round(sub.speed)] kts / [round(sub.target_speed)] kts</td></tr>"
		dat += "<tr><td>Depth</td><td>[round(sub.depth)]m / [sub.crush_depth]m crush</td></tr>"
		dat += "<tr><td>Battery</td><td>[round(sub.battery_current)]/[round(sub.battery_max)] kWh</td></tr>"
		dat += "<tr><td>Diesel Fuel</td><td>[round(sub.diesel_fuel)]/[round(sub.diesel_max)] L</td></tr>"
		dat += "<tr><td>Noise Level</td><td>[sub.noise_level]</td></tr>"
		dat += "</table>"
		dat += "</div>"

		// --- REACTOR STATUS ---
		dat += "<div class='panel'>"
		dat += "<div class='label'>REACTOR STATUS</div>"
		dat += "<table>"
		dat += "<tr><th>Reactor</th><th>Rods %</th><th>Temp &deg;C</th><th>Output MW</th><th>Primary</th><th>Secondary</th><th>SCRAM</th></tr>"
		for(var/i = 1, i <= 2, i++)
			var/scram_class = sub.r_scrammed[i] ? "status-crit" : "status-ok"
			dat += "<tr>"
			dat += "<td>Reactor [i]</td>"
			dat += "<td>[sub.r_control_rods[i]]%</td>"
			dat += "<td>[round(sub.r_core_temp[i])]</td>"
			dat += "<td>[round(sub.r_power_output[i], 0.1)]</td>"
			dat += "<td>[sub.r_primary_pump_speed[i]] RPM</td>"
			dat += "<td>[sub.r_secondary_pump_speed[i]] RPM</td>"
			dat += "<td class='[scram_class]'>[sub.r_scrammed[i] ? "YES" : "NO"]</td>"
			dat += "</tr>"
		dat += "</table>"
		dat += "</div>"

		// --- WEAPONS ---
		dat += "<div class='panel'>"
		dat += "<div class='label'>WEAPONS</div>"
		dat += "<table>"
		dat += "<tr><th>Tube</th><th>Status</th></tr>"
		for(var/i = 1, i <= 4, i++)
			dat += "<tr><td>Tube [i]</td><td>[sub.tubes_loaded[i] ? "<span class='status-ok'>LOADED</span>" : "<span class='status-warn'>EMPTY</span>"]</td></tr>"
		dat += "<tr><td>Master Arm</td><td>[sub.master_arm ? "<span class='status-ok'>ARMED</span>" : "<span class='status-warn'>SAFE</span>"]</td></tr>"
		dat += "<tr><td>Selected Target</td><td>[sub.selected_target ? sub.selected_target.name : "NONE"]</td></tr>"
		dat += "</table>"
		dat += "</div>"

		// --- SENSORS ---
		dat += "<div class='panel'>"
		dat += "<div class='label'>SENSORS</div>"
		dat += "<table>"
		dat += "<tr><td>Radar</td><td>[sub.radar_active ? "<span class='status-ok'>ON</span>" : "OFF"]</td></tr>"
		dat += "<tr><td>Sonar</td><td>[sub.sonar_active ? "<span class='status-ok'>ON</span>" : "OFF"] ([sub.sonar_mode == SUB_SONAR_PASSIVE ? "PASSIVE" : "ACTIVE"])</td></tr>"
		dat += "<tr><td>Detected Contacts</td><td>[sub.detected_targets.len]</td></tr>"
		dat += "</table>"
		dat += "</div>"

		// --- SPEED CONTROLS ---
		dat += "<div class='panel'>"
		dat += "<div class='label'>QUICK CONTROLS</div>"
		dat += "<a href='?src=\ref[src];subcom_speed=0' class='btn'>STOP</a> "
		dat += "<a href='?src=\ref[src];subcom_speed=5' class='btn'>5 KTS</a> "
		dat += "<a href='?src=\ref[src];subcom_speed=15' class='btn'>15 KTS</a> "
		dat += "<a href='?src=\ref[src];subcom_speed=30' class='btn'>30 KTS</a> "
		dat += "<a href='?src=\ref[src];subcom_surface' class='btn btn-blue'>SURFACE</a> "
		dat += "<a href='?src=\ref[src];subcom_crash' class='btn btn-red'>CRASH DIVE</a>"
		dat += "</div>"

		// --- TORPEDO CONTROLS ---
		dat += "<div class='panel'>"
		dat += "<div class='label'>TORPEDO CONTROLS</div>"
		dat += "<a href='?src=\ref[src];subcom_load_all' class='btn'>LOAD ALL TUBES</a> "
		dat += "<a href='?src=\ref[src];subcom_arm_toggle' class='btn btn-yellow'>TOGGLE MASTER ARM</a>"
		dat += "</div>"

		// --- ATTACK SIMULATION ---
		dat += "<div class='panel'>"
		dat += "<div class='label'>ATTACK SIMULATION</div>"
		dat += "<div style='margin:4px 0; font-size:10px; color:#888;'>Simulate incoming attacks for testing damage response</div>"
		dat += "<a href='?src=\ref[src];subcom_attack=depth_charge' class='btn btn-red'>DEPTH CHARGE</a> "
		dat += "<a href='?src=\ref[src];subcom_attack=reactor_meltdown' class='btn btn-red'>REACTOR MELTDOWN</a> "
		dat += "<a href='?src=\ref[src];subcom_attack=fire' class='btn btn-yellow'>START FIRE</a> "
		dat += "<a href='?src=\ref[src];subcom_attack=hull_breach' class='btn btn-red'>HULL BREACH</a> "
		dat += "<a href='?src=\ref[src];subcom_attack=flood' class='btn btn-blue'>FLOOD COMPARTMENT</a> "
		dat += "<a href='?src=\ref[src];subcom_attack=torpedo' class='btn btn-red'>TORPEDO HIT</a> "
		dat += "<a href='?src=\ref[src];subcom_attack=missile' class='btn btn-red'>MISSILE STRIKE</a>"
		dat += "</div>"

	else
		dat += "<div class='panel'><span class='status-crit'>NO SUBMARINE FOUND</span></div>"

	// --- SPAWN ENEMIES ---
	dat += "<div class='panel'>"
	dat += "<div class='label'>SPAWN ENEMY VESSELS</div>"
	dat += "<div style='margin:4px 0; font-size:10px; color:#888;'>Spawns at player sub position + offset</div>"

	dat += "<div style='margin:4px 0;'><b>Surface Combatants</b></div>"
	dat += "<a href='?src=\ref[src];subcom_spawn=destroyer' class='btn btn-red'>Perry FFG</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=frigate_kirov' class='btn btn-red'>Kirov CGN</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=frigate_krivak' class='btn btn-red'>Krivak FFG</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=corvette' class='btn btn-red'>Nanuchka</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=patrol_boat' class='btn btn-red'>Grisha MPK</a>"

	dat += "<div style='margin:4px 0;'><b>Cargo / Tankers</b></div>"
	dat += "<a href='?src=\ref[src];subcom_spawn=cargo_freight' class='btn'>Bulk Freighter</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=cargo_tanker' class='btn'>Fleet Tanker</a>"

	dat += "<div style='margin:4px 0;'><b>Aircraft</b></div>"
	dat += "<a href='?src=\ref[src];subcom_spawn=bomber' class='btn btn-yellow'>Tu-22M</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=strike' class='btn btn-yellow'>Su-24</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=asw_patrol' class='btn btn-yellow'>Il-38</a>"

	dat += "<div style='margin:4px 0;'><b>Submarines</b></div>"
	dat += "<a href='?src=\ref[src];subcom_spawn=sub_diesel' class='btn btn-blue'>Kilo SSK</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=sub_nuclear' class='btn btn-blue'>Akula SSN</a> "
	dat += "<a href='?src=\ref[src];subcom_spawn=sub_ballistic' class='btn btn-blue'>Delta III</a>"

	dat += "<div style='margin:4px 0;'><b>Random</b></div>"
	dat += "<a href='?src=\ref[src];subcom_spawn_random' class='btn btn-red'>SPAWN RANDOM HOSTILE</a>"

	dat += "</div>"

	// --- NPC MANAGEMENT ---
	dat += "<div class='panel'>"
	dat += "<div class='label'>ACTIVE NPC VESSELS</div>"
	if(global.subcom_map && global.subcom_map.active_vessels.len)
		dat += "<table>"
		dat += "<tr><th>#</th><th>Name</th><th>Type</th><th>Hull</th><th>State</th><th>Dist</th></tr>"
		var/idx = 0
		for(var/datum/vessel_contact/npc/NPC in global.subcom_map.active_vessels)
			if(QDELETED(NPC)) continue
			idx++
			var/dist = sub ? round(sqrt((NPC.x_pos - sub.x_pos)**2 + (NPC.y_pos - sub.y_pos)**2)) : "?"
			var/state_name = "PATROL"
			switch(NPC.ai_state)
				if(SUB_AI_HUNT) state_name = "HUNT"
				if(SUB_AI_ATTACK) state_name = "ATTACK"
			dat += "<tr>"
			dat += "<td>[idx]</td>"
			dat += "<td>[NPC.name]</td>"
			dat += "<td>[NPC.contact_type]</td>"
			dat += "<td>[NPC.hull_strength]/[NPC.max_hull_strength]</td>"
			dat += "<td>[state_name]</td>"
			dat += "<td>[dist]m</td>"
			dat += "</tr>"
		dat += "</table>"
	else
		dat += "<div style='color:#888;'>No active vessels</div>"

	dat += "<a href='?src=\ref[src];subcom_despawn_all' class='btn btn-red'>DESPAWN ALL NPCS</a>"
	dat += "</div>"

	// --- FLOODING STATUS ---
	dat += "<div class='panel'>"
	dat += "<div class='label'>COMPARTMENT STATUS</div>"
	if(global.subcom_flooding)
		dat += "<table>"
		dat += "<tr><th>Compartment</th><th>Water</th><th>O2</th><th>Status</th></tr>"
		for(var/cid in global.subcom_flooding.compartment_turfs)
			var/water = global.subcom_flooding.get_compartment_water_level(cid)
			var/flooded = global.subcom_flooding.is_compartment_flooded(cid)
			var/water_class = flooded ? "status-crit" : water > 50 ? "status-warn" : "status-ok"
			dat += "<tr>"
			dat += "<td>[cid]</td>"
			dat += "<td class='[water_class]'>[round(water)] cm</td>"
			dat += "<td>--</td>"
			dat += "<td class='[water_class]'>[flooded ? "FLOODED" : water > 0 ? "WET" : "DRY"]</td>"
			dat += "</tr>"
		dat += "</table>"
	else
		dat += "<div style='color:#888;'>Flooding controller not initialized</div>"
	dat += "</div>"

	// --- SINGLE PLAYER TOGGLE ---
	dat += "<div class='panel'>"
	dat += "<div class='label'>GAME SETTINGS</div>"
	dat += "<a href='?src=\ref[src];subcom_toggle_sp' class='btn btn-yellow'>TOGGLE SINGLE PLAYER MODE</a> "
	dat += "Status: [SM.single_player ? "<span class='status-ok'>ENABLED</span>" : "DISABLED"]"
	dat += "</div>"

	dat += "<br><a href='?src=\ref[src];subcom_refresh' class='btn'>REFRESH</a>"
	dat += "</body></html>"

	usr << browse(dat, "window=subcom13_panel;size=650x800")
