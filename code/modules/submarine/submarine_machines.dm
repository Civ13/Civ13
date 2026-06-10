/obj/structure/machinery/sub_control
	name = "submarine control console"
	desc = "A heavy-duty industrial terminal with a green phosphor CRT display."
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer"
	density = TRUE
	anchored = TRUE
	var/health = 100
	var/broken = FALSE
	var/active = TRUE
	var/datum/submarine/my_sub
	var/scr_overlay = "comm_monitor"

/obj/structure/machinery/sub_control/New()
	..()
	// Bind to the first submarine datum for simplicity in this mode
	// In a multi-sub scenario, this could look for a specific vessel_name
	if(global.all_submarines.len)
		my_sub = global.all_submarines[1]

/obj/structure/machinery/sub_control/proc/can_use(mob/user)
	if(broken || !active)
		to_chat(user, "<span class='warning'>The console is powered down or broken.</span>")
		return FALSE
	if(!user.IsAdvancedToolUser())
		return FALSE
	if(user.incapacitated() || user.lying)
		return FALSE
	if(get_dist(user, src) > 1)
		return FALSE
	if(!my_sub)
		to_chat(user, "<span class='notice'>No submarine link detected.</span>")
		return FALSE
	// Single-player mode: allow dead/ghost users
	if(user.stat == DEAD || isobserver(user))
		// Check if we're on the subcom13 map with single-player enabled
		var/obj/map_metadata/subcom13/SM = map
		if(istype(SM) && SM.single_player)
			return TRUE
		to_chat(user, "<span class='warning'>Single-player mode is not enabled.</span>")
		return FALSE
	return TRUE

/obj/structure/machinery/sub_control/attack_hand(mob/user)
	interact(user)

/obj/structure/machinery/sub_control/interact(mob/user)
	if(!can_use(user))
		user << browse(null, "window=sub_control")
		return

	// Send the shared submarine CSS to the client
	user << browse_rsc('UI/css/submarine.css', "submarine.css")

	var/dat = "<html><head>"
	dat += "<link rel='stylesheet' type='text/css' href='submarine.css'>"
	dat += "<style>"
	dat += "a { color: #fff; text-decoration: none; border: 1px solid #0f0; padding: 2px 6px; background: #222; border-radius: 2px; }"
	dat += "a:hover { background: #0f0; color: #000; }"
	dat += "</style></head><body>"
	dat += "<div class='label' style='font-size:13px;'>[vessel_name_header()]</div>"

	dat += get_ui_content()

	dat += "</body></html>"
	user << browse(dat, "window=sub_control;size=450x550")
	onclose(user, "sub_control")

/obj/structure/machinery/sub_control/proc/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - SYSTEMS INTERFACE"

/obj/structure/machinery/sub_control/proc/get_ui_content()
	return "BASE INTERFACE"

/obj/structure/machinery/sub_control/process()
	if(!active || broken) return
	// Throttle UI refresh to every 5 ticks (~5 seconds) to reduce bandwidth
	var/static/refresh_counter = 0
	refresh_counter++
	if(refresh_counter % 5 != 0) return
	// Refresh UI for all users looking at this console
	for(var/mob/M in range(1, src))
		if(M.client)
			interact(M)

// --- MANEUVER PANEL ---

/obj/structure/machinery/sub_control/maneuver_panel
	name = "helm control station"
	icon_state = "computer"
	scr_overlay = "navigation"

/obj/structure/machinery/sub_control/maneuver_panel/get_ui_content()
	var/dat = ""

	// === TOP ROW: Large dials ===
	dat += "<div class='flex-row' style='justify-content:center; gap:16px; margin-bottom:8px;'>"

	// --- HEADING DIAL ---
	var/hd_angle = (my_sub.heading / 360) * 270 - 135
	dat += "<div class='panel' style='text-align:center; padding:8px;'>"
	dat += "<div class='label'>HEADING</div>"
	dat += "<div class='gauge' style='margin:6px auto;'>"
	dat += "<div class='gauge-ticks'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([hd_angle]deg);'></div>"
	dat += "<div class='gauge-center'></div>"
	dat += "<div class='gauge-value'>[round(my_sub.heading)]&deg;</div>"
	dat += "<div class='gauge-label'>DEG</div>"
	dat += "</div>"
	dat += "<div style='font-size:10px; color:#888;'>TGT: [round(my_sub.target_heading)]&deg;</div>"
	dat += "<div style='margin-top:4px;'>"
	dat += "<a href='?src=\ref[src];adj_hd=-45' class='btn btn-grey' style='min-width:30px;'>-45</a> "
	dat += "<a href='?src=\ref[src];adj_hd=-10' class='btn btn-grey' style='min-width:30px;'>-10</a> "
	dat += "<a href='?src=\ref[src];adj_hd=-5' class='btn btn-grey' style='min-width:30px;'>-5</a> "
	dat += "<a href='?src=\ref[src];adj_hd=5' class='btn btn-green' style='min-width:30px;'>+5</a> "
	dat += "<a href='?src=\ref[src];adj_hd=10' class='btn btn-green' style='min-width:30px;'>+10</a> "
	dat += "<a href='?src=\ref[src];adj_hd=45' class='btn btn-green' style='min-width:30px;'>+45</a>"
	dat += "</div></div>"

	// --- SPEED DIAL ---
	var/sp_angle = (my_sub.speed / 30) * 270 - 135
	dat += "<div class='panel' style='text-align:center; padding:8px;'>"
	dat += "<div class='label'>SPEED</div>"
	dat += "<div class='gauge' style='margin:6px auto;'>"
	dat += "<div class='gauge-ticks'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([sp_angle]deg);'></div>"
	dat += "<div class='gauge-center'></div>"
	dat += "<div class='gauge-value'>[round(my_sub.speed)]</div>"
	dat += "<div class='gauge-label'>KTS</div>"
	dat += "</div>"
	dat += "<div style='font-size:10px; color:#888;'>TGT: [round(my_sub.target_speed)] KTS</div>"
	dat += "<div style='margin-top:4px;'>"
	dat += "<a href='?src=\ref[src];adj_sp=-10' class='btn btn-grey' style='min-width:30px;'>-10</a> "
	dat += "<a href='?src=\ref[src];adj_sp=-5' class='btn btn-grey' style='min-width:30px;'>-5</a> "
	dat += "<a href='?src=\ref[src];adj_sp=-1' class='btn btn-grey' style='min-width:30px;'>-1</a> "
	dat += "<a href='?src=\ref[src];adj_sp=1' class='btn btn-green' style='min-width:30px;'>+1</a> "
	dat += "<a href='?src=\ref[src];adj_sp=5' class='btn btn-green' style='min-width:30px;'>+5</a> "
	dat += "<a href='?src=\ref[src];adj_sp=10' class='btn btn-green' style='min-width:30px;'>+10</a>"
	dat += "</div></div>"

	// --- DEPTH DIAL ---
	var/dp_angle = (my_sub.depth / my_sub.crush_depth) * 270 - 135
	var/depth_color = "#0f0"
	if(my_sub.depth > my_sub.crush_depth * 0.8)
		depth_color = "#f00"
	else if(my_sub.depth > my_sub.crush_depth * 0.5)
		depth_color = "#ff0"
	dat += "<div class='panel' style='text-align:center; padding:8px;'>"
	dat += "<div class='label'>DEPTH</div>"
	dat += "<div class='gauge' style='margin:6px auto;'>"
	dat += "<div class='gauge-ticks'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([dp_angle]deg); background:[depth_color];'></div>"
	dat += "<div class='gauge-center'></div>"
	dat += "<div class='gauge-value' style='color:[depth_color];'>[round(my_sub.depth)]</div>"
	dat += "<div class='gauge-label'>METERS</div>"
	dat += "</div>"
	dat += "<div style='font-size:10px; color:#888;'>CRUSH: [my_sub.crush_depth]m</div>"
	dat += "<div style='margin-top:4px;'>"
	dat += "<a href='?src=\ref[src];set_dp=0' class='btn btn-green'>SURFACE</a> "
	dat += "<a href='?src=\ref[src];set_dp=15' class='btn btn-blue'>PERISCOPE</a> "
	dat += "<a href='?src=\ref[src];set_dp=150' class='btn btn-yellow'>DEEP</a> "
	dat += "<a href='?src=\ref[src];set_dp=250' class='btn btn-red'>CRASH</a>"
	dat += "</div></div>"

	dat += "</div>" // end flex-row

	// === BOTTOM ROW: Status panels ===
	dat += "<div class='flex-row' style='justify-content:center; gap:12px;'>"

	// --- PROPULSION STATUS ---
	dat += "<div class='panel' style='padding:8px; min-width:180px;'>"
	dat += "<div class='label'>PROPULSION</div>"
	if(my_sub.has_nuclear_engine)
		var/total_output = my_sub.r_power_output[1] + my_sub.r_power_output[2]
		var/prop_color = total_output > 5.0 ? "#0f0" : "#f80"
		dat += "<div style='margin-top:6px;'>"
		dat += "<span class='light [total_output > 5.0 ? "light-green" : "light-amber"]'></span> "
		dat += "<span style='color:[prop_color]; font-weight:bold;'>[total_output > 5.0 ? "NUCLEAR TURBINES" : "BATTERY (EMERGENCY)"]</span>"
		dat += "</div>"
		dat += "<div style='font-size:10px; color:#888; margin-top:4px;'>OUTPUT: [round(total_output, 0.1)] MW</div>"
	else
		var/prop_status = "BATTERY"
		var/prop_color = "#f80"
		if(my_sub.depth == 0 && my_sub.diesel_throttle > 0 && my_sub.diesel_fuel > 0)
			prop_status = "DIESEL ([my_sub.diesel_throttle]%)"
			prop_color = "#0f0"
		dat += "<div style='margin-top:6px;'>"
		dat += "<span class='light [my_sub.depth == 0 && my_sub.diesel_throttle > 0 ? "light-green" : "light-amber"]'></span> "
		dat += "<span style='color:[prop_color]; font-weight:bold;'>[prop_status]</span>"
		dat += "</div>"
		dat += "<div style='font-size:10px; color:#888; margin-top:4px;'>FUEL: [my_sub.diesel_fuel]/[my_sub.diesel_max]L</div>"
	dat += "</div>"

	// --- VISIBILITY STATUS ---
	dat += "<div class='panel' style='padding:8px; min-width:180px;'>"
	dat += "<div class='label'>VISIBILITY</div>"
	dat += "<div style='margin-top:6px;'>"
	var/vis_state = "NOT VISIBLE"
	var/vis_light = "light-green"
	if(my_sub.depth > 0 && my_sub.depth <= 15)
		vis_state = "PERISCOPE DEPTH"
		vis_light = "light-yellow"
	else if(my_sub.depth == 0 && my_sub.speed > 0)
		vis_state = "SURFACED"
		vis_light = "light-red"
	dat += "<span class='light [vis_light]'></span> "
	dat += "<span style='font-weight:bold;'>[vis_state]</span>"
	dat += "</div></div>"

	// --- BALLAST ---
	dat += "<div class='panel' style='padding:8px; min-width:120px;'>"
	dat += "<div class='label'>BALLAST</div>"
	dat += "<div style='margin-top:6px; text-align:center;'>"
	dat += "<div style='font-size:18px; font-weight:bold; color:#0f0;'>[round(my_sub.ballast)]</div>"
	dat += "<div style='font-size:9px; color:#888;'>TONS</div>"
	dat += "</div>"
	dat += "<div style='text-align:center; margin-top:4px;'>"
	dat += "<a href='?src=\ref[src];blow_ballast=1' class='btn btn-red' style='font-size:9px;'>BLOW BALLAST</a>"
	dat += "</div></div>"

	dat += "</div>" // end flex-row

	return dat

/obj/structure/machinery/sub_control/maneuver_panel/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["adj_hd"])
		my_sub.target_heading = (my_sub.target_heading + text2num(href_list["adj_hd"]) + 360) % 360
	
	if(href_list["adj_sp"])
		my_sub.target_speed = clamp(my_sub.target_speed + text2num(href_list["adj_sp"]), 0, 30)

	if(href_list["set_dp"])
		my_sub.target_depth = text2num(href_list["set_dp"])

	if(href_list["blow_ballast"])
		my_sub.target_depth = 0
		my_sub.ballast = 0
		visible_message("<span class='warning'>The ballast tanks hiss violently!</span>")

	interact(usr)

// --- REACTOR PANEL ---

/obj/structure/machinery/sub_control/reactor_panel
	name = "reactor control station"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "transponder"
	scr_overlay = "transponder_screen"

/obj/structure/machinery/sub_control/reactor_panel/get_ui_content()
	if(!my_sub.has_nuclear_engine)
		var/dat = "<div class='panel' style='padding:12px; text-align:center;'>"
		dat += "<div class='label' style='font-size:13px;'>REACTOR SYSTEMS</div>"
		dat += "<div style='margin:12px 0; color:#f80; font-weight:bold;'>NO NUCLEAR REACTOR INSTALLED</div>"
		dat += "<div style='color:#888; margin-bottom:8px;'>This vessel operates on diesel-electric propulsion.</div>"
		dat += "<div class='flex-row' style='justify-content:center; gap:20px;'>"
		dat += "<div><span class='light [my_sub.diesel_fuel > 0 ? "light-green" : "light-red"]'></span> FUEL: [my_sub.diesel_fuel]/[my_sub.diesel_max]L</div>"
		dat += "<div>THROTTLE: [my_sub.diesel_throttle]%</div>"
		dat += "<div>CONSUMPTION: [my_sub.diesel_throttle * 2] L/tick</div>"
		dat += "</div></div>"
		return dat

	var/dat = ""
	dat += "<div class='flex-row' style='justify-content:center; gap:16px;'>"

	for(var/i = 1, i <= 2, i++)
		var/temp_color = "#0f0"
		if(my_sub.r_core_temp[i] > 500)
			temp_color = "#f00"
		else if(my_sub.r_core_temp[i] > 250)
			temp_color = "#f80"

		var/output_color = my_sub.r_power_output[i] > 5.0 ? "#0f0" : "#f80"

		// --- REACTOR CARD ---
		dat += "<div class='panel' style='padding:10px; min-width:260px;'>"
		dat += "<div class='flex-between mb-4'>"
		dat += "<div class='label'>REACTOR [i]</div>"
		if(my_sub.r_scrammed[i])
			dat += "<div class='light light-critical'></div>"
		else
			dat += "<div class='light light-green'></div>"
		dat += "</div>"

		// Gauges row
		dat += "<div class='flex-row' style='justify-content:center; gap:10px;'>"

		// Power output gauge (0-70 MW)
		var/pwr_angle = (my_sub.r_power_output[i] / 70) * 270 - 135
		dat += "<div style='text-align:center;'>"
		dat += "<div class='gauge-sm' style='margin:0 auto;'>"
		dat += "<div class='gauge-ticks'></div>"
		dat += "<div class='gauge-needle' style='transform:rotate([pwr_angle]deg); background:[output_color];'></div>"
		dat += "<div class='gauge-center'></div>"
		dat += "<div class='gauge-value' style='color:[output_color]; font-size:10px;'>[round(my_sub.r_power_output[i], 0.1)]</div>"
		dat += "<div class='gauge-label'>MW</div>"
		dat += "</div>"
		dat += "<div style='font-size:9px; color:#888;'>POWER OUTPUT</div>"
		dat += "</div>"

		// Core temperature gauge (0-1000 C)
		var/temp_angle = (my_sub.r_core_temp[i] / 1000) * 270 - 135
		dat += "<div style='text-align:center;'>"
		dat += "<div class='gauge-sm' style='margin:0 auto;'>"
		dat += "<div class='gauge-ticks'></div>"
		dat += "<div class='gauge-needle' style='transform:rotate([temp_angle]deg); background:[temp_color];'></div>"
		dat += "<div class='gauge-center'></div>"
		dat += "<div class='gauge-value' style='color:[temp_color]; font-size:10px;'>[round(my_sub.r_core_temp[i])]</div>"
		dat += "<div class='gauge-label'>&deg;C</div>"
		dat += "</div>"
		dat += "<div style='font-size:9px; color:#888;'>CORE TEMP</div>"
		dat += "</div>"

		dat += "</div>" // end gauges row

		// Control rods
		dat += "<div class='mt-4 mb-4'>"
		dat += "<div style='font-size:10px; color:#aaa; margin-bottom:2px;'>CONTROL RODS</div>"
		dat += "<div class='flex-row' style='gap:3px;'>"
		var/list/rod_pcts = list(0, 25, 50, 75, 100)
		for(var/rp in rod_pcts)
			var/rod_class = my_sub.r_control_rods[i] == rp ? "btn btn-green" : "btn btn-grey"
			dat += "<a href='?src=\ref[src];r=[i];rods=[rp]' class='[rod_class]' style='min-width:36px; font-size:9px;'>[rp]%</a>"
		dat += "</div></div>"

		// Coolant pumps
		dat += "<div class='flex-row' style='gap:12px;'>"
		dat += "<div style='flex:1;'>"
		dat += "<div style='font-size:9px; color:#888;'>PRIMARY PUMP</div>"
		dat += "<div class='flex-row' style='gap:2px; align-items:center;'>"
		dat += "<a href='?src=\ref[src];r=[i];pri=-1' class='btn btn-grey' style='min-width:22px; font-size:10px;'>-</a>"
		dat += "<span style='color:#0f0; font-weight:bold;'>[my_sub.r_primary_pump_speed[i]]</span>"
		dat += "<a href='?src=\ref[src];r=[i];pri=1' class='btn btn-green' style='min-width:22px; font-size:10px;'>+</a>"
		dat += "</div></div>"
		dat += "<div style='flex:1;'>"
		dat += "<div style='font-size:9px; color:#888;'>SECONDARY PUMP</div>"
		dat += "<div class='flex-row' style='gap:2px; align-items:center;'>"
		dat += "<a href='?src=\ref[src];r=[i];sec=-1' class='btn btn-grey' style='min-width:22px; font-size:10px;'>-</a>"
		dat += "<span style='color:#0f0; font-weight:bold;'>[my_sub.r_secondary_pump_speed[i]]</span>"
		dat += "<a href='?src=\ref[src];r=[i];sec=1' class='btn btn-green' style='min-width:22px; font-size:10px;'>+</a>"
		dat += "</div></div>"
		dat += "</div>"

		// SCRAM button
		dat += "<div style='text-align:center; margin-top:6px;'>"
		dat += "<a href='?src=\ref[src];r=[i];scram=1' class='btn btn-red' style='min-width:120px;'>SCRAM REACTOR [i]</a>"
		dat += "</div>"

		dat += "</div>" // end reactor card

	dat += "</div>" // end flex-row
	return dat

/obj/structure/machinery/sub_control/reactor_panel/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return
	
	var/r_idx = text2num(href_list["r"])
	if(!r_idx) return

	if(href_list["rods"])
		my_sub.r_control_rods[r_idx] = text2num(href_list["rods"])
	
	if(href_list["pri"])
		my_sub.r_primary_pump_speed[r_idx] = clamp(my_sub.r_primary_pump_speed[r_idx] + text2num(href_list["pri"]), 0, 18)

	if(href_list["sec"])
		my_sub.r_secondary_pump_speed[r_idx] = clamp(my_sub.r_secondary_pump_speed[r_idx] + text2num(href_list["sec"]), 0, 10)

	if(href_list["scram"])
		my_sub.r_scrammed[r_idx] = TRUE
		my_sub.r_control_rods[r_idx] = 100
		visible_message("<span class='warning'>A loud klaxon sounds! Reactor [r_idx] has been SCRAMMED!</span>")

	interact(usr)

// --- MISC SYSTEMS PANEL ---

/obj/structure/machinery/sub_control/misc_systems
	name = "auxiliary systems console"
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer-middle"
	scr_overlay = "comm_logs"

	var/list/compartments = list(
		"Forward Torpedo Room",
		"Forward Battery",
		"Operations",
		"CPO Quarters",
		"Galley",
		"Crew Quarters",
		"After Battery",
		"Reactor Room",
		"Engine Room",
		"Maneuvering Room",
		"After Torpedo Room"
	)
	// Internal status tracking for simulation
	var/list/vents_open = list()
	var/list/fire_supp_active = list()

/obj/structure/machinery/sub_control/misc_systems/New()
	..()
	for(var/C in compartments)
		vents_open[C] = TRUE
		fire_supp_active[C] = FALSE

/obj/structure/machinery/sub_control/misc_systems/get_ui_content()
	var/dat = ""

	// === TOP: O2 Generator + Battery ===
	dat += "<div class='flex-row' style='justify-content:center; gap:16px; margin-bottom:8px;'>"

	// --- O2 GENERATOR ---
	dat += "<div class='panel' style='padding:10px; min-width:180px; text-align:center;'>"
	dat += "<div class='label'>ELECTROLYSIS</div>"
	dat += "<div style='margin:10px 0;'>"
	if(my_sub.electrolysis_active)
		dat += "<div class='light light-green' style='width:20px; height:20px; margin:0 auto;'></div>"
		dat += "<div style='color:#0f0; font-weight:bold; margin-top:4px;'>ACTIVE</div>"
	else
		dat += "<div class='light light-off' style='width:20px; height:20px; margin:0 auto;'></div>"
		dat += "<div style='color:#666; font-weight:bold; margin-top:4px;'>OFF</div>"
	dat += "</div>"
	dat += "<a href='?src=\ref[src];toggle_o2=1' class='btn [my_sub.electrolysis_active ? "btn-red" : "btn-green"]'>[my_sub.electrolysis_active ? "SHUTDOWN" : "START"]</a>"
	dat += "</div>"

	// --- BATTERY ---
	var/batt_pct = my_sub.battery_max > 0 ? (my_sub.battery_current / my_sub.battery_max * 100) : 0
	var/batt_color = "#0f0"
	if(batt_pct < 25)
		batt_color = "#f00"
	else if(batt_pct < 50)
		batt_color = "#f80"
	dat += "<div class='panel' style='padding:10px; min-width:180px; text-align:center;'>"
	dat += "<div class='label'>BATTERY</div>"
	dat += "<div style='margin:10px 0;'>"
	dat += "<div style='font-size:20px; font-weight:bold; color:[batt_color];'>[round(batt_pct)]%</div>"
	dat += "<div style='font-size:10px; color:#888;'>[my_sub.battery_current] / [my_sub.battery_max] kWh</div>"
	dat += "</div>"
	dat += "<div class='bar-h' style='width:120px; height:14px; margin:0 auto;'>"
	dat += "<div class='bar-h-fill [batt_pct < 25 ? "fill-danger" : batt_pct < 50 ? "fill-warning" : "fill-good"]' style='width:[batt_pct]%;'></div>"
	dat += "</div>"
	dat += "</div>"

	dat += "</div>" // end top row

	// === VENTILATION TABLE ===
	dat += "<div class='panel' style='padding:10px;'>"
	dat += "<div class='flex-between mb-4'>"
	dat += "<div class='label'>VENTILATION SYSTEM</div>"
	dat += "<div class='label'>FIRE SUPPRESSION</div>"
	dat += "</div>"
	dat += "<table class='data-table'>"
	dat += "<tr><th style='width:40%;'>COMPARTMENT</th><th style='width:20%; text-align:center;'>VENT</th><th style='width:20%; text-align:center;'>FSS</th></tr>"

	for(var/C in compartments)
		var/vent_on = vents_open[C]
		var/fss_on = fire_supp_active[C]
		dat += "<tr>"
		dat += "<td style='font-weight:bold;'>[C]</td>"
		dat += "<td style='text-align:center;'>"
		dat += "<a href='?src=\ref[src];vent=[C]' style='text-decoration:none;'>"
		dat += "<span class='switch [vent_on ? "switch-on" : ""]'></span>"
		dat += " <span style='font-size:10px; color:[vent_on ? "#0f0" : "#888"];'>[vent_on ? "OPEN" : "SHUT"]</span>"
		dat += "</a></td>"
		dat += "<td style='text-align:center;'>"
		dat += "<a href='?src=\ref[src];fss=[C]' style='text-decoration:none;'>"
		if(fss_on)
			dat += "<span class='btn btn-red' style='font-size:8px; min-width:50px;'>ACTIVE</span>"
		else
			dat += "<span class='btn btn-grey' style='font-size:8px; min-width:50px;'>OFF</span>"
		dat += "</a></td>"
		dat += "</tr>"

	dat += "</table>"
	dat += "</div>"

	return dat

/obj/structure/machinery/sub_control/misc_systems/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["toggle_o2"])
		my_sub.electrolysis_active = !my_sub.electrolysis_active

	if(href_list["vent"])
		var/C = href_list["vent"]
		vents_open[C] = !vents_open[C]
	
	if(href_list["fss"])
		var/C = href_list["fss"]
		fire_supp_active[C] = !fire_supp_active[C]
		if(fire_supp_active[C])
			visible_message("<span class='notice'>Hissing sounds heard from [C] fire suppression vents.</span>")

	interact(usr)

// --- RADAR PANEL ---

/obj/structure/machinery/sub_control/radar_panel
	name = "radar console"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "bsm_off"
	scr_overlay = "bsm_on"

/obj/structure/machinery/sub_control/radar_panel/get_ui_content()
	var/dat = ""

	// === STATUS BAR ===
	dat += "<div class='panel' style='padding:8px; margin-bottom:8px;'>"
	dat += "<div class='flex-between'>"
	dat += "<div class='label'>RADAR SYSTEMS</div>"
	dat += "<div>"
	dat += "<span class='light [my_sub.radar_active ? "light-green" : "light-off"]'></span> "
	dat += "<span style='font-weight:bold; color:[my_sub.radar_active ? "#0f0" : "#888"];'>[my_sub.radar_active ? "ACTIVE" : "INACTIVE"]</span>"
	dat += "</div>"
	dat += "</div>"
	dat += "<div class='flex-row' style='gap:12px; margin-top:6px;'>"
	dat += "<a href='?src=\ref[src];toggle_power=1' class='btn [my_sub.radar_active ? "btn-red" : "btn-green"]'>[my_sub.radar_active ? "POWER OFF" : "POWER ON"]</a>"
	dat += "<a href='?src=\ref[src];toggle_range=1' class='btn btn-blue' style='min-width:120px;'>RANGE: [my_sub.radar_range_long ? "LONG" : "SHORT"]</a>"
	var/power_draw = my_sub.radar_active ? (my_sub.radar_range_long ? SUB_RADAR_POWER_LONG : SUB_RADAR_POWER_SHORT) : 0
	dat += "<div style='color:#888;'>DRAW: [power_draw] kW</div>"
	dat += "</div>"

	// Submerged warning
	if(my_sub.depth > 0)
		dat += "<div style='margin-top:6px; padding:4px; background:#400; border:1px solid #f00; text-align:center; color:#f00; font-weight:bold;'>RADAR INOPERATIVE — SUBMERGED</div>"

	dat += "</div>"

	// === CONTACT TABLE ===
	dat += "<div class='panel' style='padding:10px;'>"
	dat += "<div class='label'>DETECTED CONTACTS</div>"
	if(my_sub.radar_active && my_sub.depth == 0 && my_sub.detected_targets.len)
		dat += "<table class='data-table' style='margin-top:6px;'>"
		dat += "<tr><th>NAME</th><th>RANGE</th><th>BEARING</th><th>TYPE</th></tr>"
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			if(C.contact_type == SUB_CONTACT_SURFACE || C.contact_type == SUB_CONTACT_AIR)
				var/type_color = C.contact_type == SUB_CONTACT_AIR ? "#f80" : "#0af"
				var/type_text = C.contact_type == SUB_CONTACT_AIR ? "AIR" : "SURFACE"
				dat += "<tr>"
				dat += "<td style='font-weight:bold;'>[C.name]</td>"
				dat += "<td>[round(C.range)]m</td>"
				dat += "<td>[round(C.bearing)]&deg;</td>"
				dat += "<td style='color:[type_color];'>[type_text]</td>"
				dat += "</tr>"
		dat += "</table>"
	else
		dat += "<div style='margin-top:6px; color:#666; text-align:center;'>No contacts detected.</div>"

	dat += "</div>"

	return dat

/obj/structure/machinery/sub_control/radar_panel/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["toggle_power"])
		if(my_sub.depth == 0) // Can only toggle if surfaced
			my_sub.radar_active = !my_sub.radar_active
			if(!my_sub.radar_active)
				my_sub.detected_targets.Cut() // Clear targets when off
		else
			to_chat(usr, "<span class='warning'>Cannot activate radar while submerged!</span>")

	if(href_list["toggle_range"])
		if(my_sub.radar_active)
			my_sub.radar_range_long = !my_sub.radar_range_long
		else
			to_chat(usr, "<span class='notice'>Activate radar first to change range.</span>")

	interact(usr)

// --- SONAR PANEL ---

/obj/structure/machinery/sub_control/sonar_panel
	name = "sonar console"
	icon = 'icons/obj/computers.dmi'
	icon_state = "wallconsole"
	scr_overlay = "wallconsole_sonar"

/obj/structure/machinery/sub_control/sonar_panel/get_ui_content()
	var/dat = ""

	// === STATUS BAR ===
	dat += "<div class='panel' style='padding:8px; margin-bottom:8px;'>"
	dat += "<div class='flex-between'>"
	dat += "<div class='label'>SONAR SYSTEMS</div>"
	dat += "<div>"
	dat += "<span class='light [my_sub.sonar_active ? (my_sub.sonar_mode == SUB_SONAR_ACTIVE ? "light-red" : "light-green") : "light-off"]'></span> "
	dat += "<span style='font-weight:bold; color:[my_sub.sonar_active ? (my_sub.sonar_mode == SUB_SONAR_ACTIVE ? "#f80" : "#0f0") : "#888"];'>"
	dat += my_sub.sonar_active ? (my_sub.sonar_mode == SUB_SONAR_ACTIVE ? "ACTIVE (HIGH EMISSION)" : "PASSIVE (STEALTH)") : "INACTIVE"
	dat += "</span>"
	dat += "</div>"
	dat += "</div>"
	dat += "<div class='flex-row' style='gap:12px; margin-top:6px;'>"
	dat += "<a href='?src=\ref[src];toggle_power=1' class='btn [my_sub.sonar_active ? "btn-red" : "btn-green"]'>[my_sub.sonar_active ? "POWER OFF" : "POWER ON"]</a>"
	dat += "<a href='?src=\ref[src];toggle_mode=1' class='btn btn-blue' style='min-width:120px;'>MODE: [my_sub.sonar_mode == SUB_SONAR_ACTIVE ? "ACTIVE" : "PASSIVE"]</a>"
	var/power_draw = my_sub.sonar_active ? (my_sub.sonar_mode == SUB_SONAR_ACTIVE ? SUB_SONAR_POWER_ACTIVE : SUB_SONAR_POWER_PASSIVE) : 0
	dat += "<div style='color:#888;'>DRAW: [power_draw] kW</div>"
	dat += "<div style='color:#888;'>NOISE: [my_sub.noise_level]</div>"
	dat += "</div>"
	dat += "</div>"

	// === LOFAR ANALYSIS (visual display) ===
	dat += "<div class='panel crt-overlay' style='padding:10px;'>"
	dat += "<div class='label'>PASSIVE SONAR — LOFAR</div>"
	dat += "<div style='margin-top:8px; background:#001a00; border:1px solid #0a0; padding:8px; position:relative; height:100px;'>"

	if(my_sub.sonar_active)
		// Bearing labels across the top
		dat += "<div style='display:flex; justify-content:space-between; font-size:8px; color:#0a0; margin-bottom:4px;'>"
		dat += "<span>180 S</span><span>225 SW</span><span>270 W</span><span>315 NW</span><span>0 N</span><span>45 NE</span><span>90 E</span><span>135 SE</span><span>180 S</span>"
		dat += "</div>"
		// Simulated waterfall line
		dat += "<div style='border-top:1px solid #0a0; height:60px; position:relative;'>"
		// Draw contact blips
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			if(C.contact_type == SUB_CONTACT_SUBMERGED)
				var/blip_x = (C.bearing / 360) * 100
				var/blip_size = max(4, min(12, 100 - C.range / 500))
				dat += "<div style='position:absolute; left:[blip_x]%; top:50%; transform:translate(-50%,-50%); width:[blip_size]px; height:[blip_size]px; background:#0f0; border-radius:50%; box-shadow:0 0 4px #0f0;'></div>"
		// Center bearing marker
		dat += "<div style='position:absolute; left:50%; bottom:0; width:0; height:0; border-left:4px solid transparent; border-right:4px solid transparent; border-bottom:6px solid #0f0; transform:translateX(-50%);'></div>"
		dat += "</div>"
	else
		dat += "<div style='text-align:center; color:#040; padding-top:30px;'>SONAR OFFLINE</div>"

	dat += "</div>"
	dat += "</div>"

	// === DETECTED CONTACTS ===
	dat += "<div class='panel' style='padding:10px;'>"
	dat += "<div class='label'>DETECTED CONTACTS</div>"
	if(my_sub.sonar_active && my_sub.detected_targets.len)
		dat += "<table class='data-table' style='margin-top:6px;'>"
		dat += "<tr><th>NAME</th><th>RANGE</th><th>BEARING</th><th>NOISE</th></tr>"
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			if(C.contact_type == SUB_CONTACT_SUBMERGED)
				var/noise_color = C.noise_signature > 50 ? "#f00" : C.noise_signature > 20 ? "#ff0" : "#0f0"
				dat += "<tr>"
				dat += "<td style='font-weight:bold;'>[C.name]</td>"
				dat += "<td>[round(C.range)]m</td>"
				dat += "<td>[round(C.bearing)]&deg;</td>"
				dat += "<td style='color:[noise_color];'>[C.noise_signature]</td>"
				dat += "</tr>"
		dat += "</table>"
	else
		dat += "<div style='margin-top:6px; color:#666; text-align:center;'>No subsurface contacts detected.</div>"

	dat += "</div>"

	return dat

/obj/structure/machinery/sub_control/sonar_panel/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["toggle_power"])
		my_sub.sonar_active = !my_sub.sonar_active
		if(!my_sub.sonar_active)
			my_sub.detected_targets.Cut() // Clear targets when off

	if(href_list["toggle_mode"])
		if(my_sub.sonar_active)
			my_sub.sonar_mode = (my_sub.sonar_mode == SUB_SONAR_ACTIVE) ? SUB_SONAR_PASSIVE : SUB_SONAR_ACTIVE
			if(my_sub.sonar_mode == SUB_SONAR_ACTIVE)
				my_sub.noise_level = 100 // Active sonar is very loud
			else
				my_sub.noise_level = my_sub.speed * 5 // Passive mode noise based on speed
		else
			to_chat(usr, "<span class='notice'>Activate sonar first to change mode.</span>")

	interact(usr)

// --- WEAPONS PANEL ---

/obj/structure/machinery/sub_control/weapons_panel
	name = "weapons control station"
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer-retro"
	scr_overlay = "targeting_peace"

/obj/structure/machinery/sub_control/weapons_panel/get_ui_content()
	var/dat = ""

	// === TOP ROW: Master Arm + Tube Status ===
	dat += "<div class='flex-row' style='justify-content:center; gap:16px; margin-bottom:8px;'>"

	// --- MASTER ARM ---
	dat += "<div class='panel' style='padding:10px; min-width:160px; text-align:center;'>"
	dat += "<div class='label'>MASTER ARM</div>"
	dat += "<div style='margin:10px 0;'>"
	if(my_sub.master_arm)
		dat += "<div class='light light-red' style='width:20px; height:20px;'></div>"
		dat += "<div style='color:#f00; font-weight:bold; font-size:14px; margin-top:4px;'>ARMED</div>"
	else
		dat += "<div class='light light-green' style='width:20px; height:20px;'></div>"
		dat += "<div style='color:#0f0; font-weight:bold; font-size:14px; margin-top:4px;'>SAFE</div>"
	dat += "</div>"
	dat += "<a href='?src=\ref[src];toggle_master_arm=1' class='btn [my_sub.master_arm ? "btn-red" : "btn-green"]' style='min-width:100px;'>[my_sub.master_arm ? "DISARM" : "ARM"]</a>"
	dat += "</div>"

	// --- TORPEDO TUBES ---
	dat += "<div class='panel' style='padding:10px;'>"
	dat += "<div class='label'>TORPEDO TUBES</div>"
	dat += "<div class='flex-row' style='justify-content:center; gap:8px; margin-top:8px;'>"
	for(var/i = 1, i <= 4, i++)
		var/tube_color = my_sub.tubes_loaded[i] ? "#0f0" : "#666"
		var/tube_status = my_sub.tubes_loaded[i] ? "LOADED" : "EMPTY"
		var/light_class = my_sub.tubes_loaded[i] ? "light-green" : "light-off"
		dat += "<div style='text-align:center; min-width:55px;'>"
		dat += "<div class='panel' style='padding:6px; margin:0; text-align:center;'>"
		dat += "<div class='light [light_class]' style='margin:0 auto 4px auto;'></div>"
		dat += "<div style='font-size:10px; font-weight:bold; color:[tube_color];'>TUBE [i]</div>"
		dat += "<div style='font-size:8px; color:#888;'>[tube_status]</div>"
		dat += "</div>"
		dat += "<a href='?src=\ref[src];load_tube=[i]' class='btn btn-grey' style='min-width:55px; font-size:8px; margin-top:2px;'>[my_sub.tubes_loaded[i] ? "UNLOAD" : "LOAD"]</a>"
		dat += "</div>"
	dat += "</div>"
	dat += "</div>"

	dat += "</div>" // end top row

	// === BOTTOM ROW: Targeting ===
	dat += "<div class='panel' style='padding:10px;'>"
	dat += "<div class='label'>TARGETING</div>"
	if(my_sub.selected_target)
		dat += "<div class='flex-row' style='gap:16px; margin-top:8px;'>"
		dat += "<div style='flex:1;'>"
		dat += "<div style='font-size:10px; color:#888;'>SELECTED TARGET</div>"
		dat += "<div style='font-weight:bold; color:#0f0; font-size:12px;'>[my_sub.selected_target.name]</div>"
		dat += "<div style='font-size:10px; color:#aaa;'>RANGE: [round(my_sub.selected_target.range)]m | BEARING: [round(my_sub.selected_target.bearing)]&deg;</div>"
		dat += "</div>"
		dat += "<div>"
		dat += "<a href='?src=\ref[src];clear_target=1' class='btn btn-grey' style='font-size:9px;'>CLEAR TARGET</a>"
		dat += "</div>"
		dat += "</div>"
		// Launch buttons
		dat += "<div class='flex-row' style='gap:6px; margin-top:8px;'>"
		for(var/i = 1, i <= 4, i++)
			if(my_sub.tubes_loaded[i] && my_sub.master_arm)
				dat += "<a href='?src=\ref[src];launch_torpedo=[i]' class='btn btn-red' style='min-width:100px;'>LAUNCH TUBE [i]</a>"
		dat += "</div>"
	else
		dat += "<div style='margin-top:8px; color:#888;'>No target selected.</div>"
		if(my_sub.detected_targets.len)
			dat += "<div style='margin-top:4px; font-size:10px; color:#aaa;'>SELECT FROM CONTACTS:</div>"
			dat += "<div class='flex-row' style='flex-wrap:wrap; gap:4px; margin-top:4px;'>"
			for(var/datum/vessel_contact/C in my_sub.detected_targets)
				dat += "<a href='?src=\ref[src];select_target=\ref[C]' class='btn btn-blue' style='font-size:9px;'>[C.name] ([round(C.range)]m)</a>"
			dat += "</div>"
		else
			dat += "<div style='margin-top:4px; color:#666; font-size:10px;'>No contacts detected.</div>"
	dat += "</div>"

	return dat

/obj/structure/machinery/sub_control/weapons_panel/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["toggle_master_arm"])
		my_sub.master_arm = !my_sub.master_arm
		if(!my_sub.master_arm)
			my_sub.selected_target = null // Clear target if disarmed

	if(href_list["load_tube"])
		var/tube_idx = text2num(href_list["load_tube"])
		if(tube_idx >= 1 && tube_idx <= 4)
			my_sub.tubes_loaded[tube_idx] = !my_sub.tubes_loaded[tube_idx] // Toggle load status for now
			// In a real game, this would trigger a loading animation/delay and consume an item

	if(href_list["select_target"])
		my_sub.selected_target = locate(href_list["select_target"])

	if(href_list["clear_target"])
		my_sub.selected_target = null

	if(href_list["launch_torpedo"])
		var/tube_idx = text2num(href_list["launch_torpedo"])
		if(tube_idx >= 1 && tube_idx <= 4)
			if(my_sub.launch_torpedo(tube_idx))
				visible_message("<span class='warning'>TORPEDO LAUNCHED from tube [tube_idx]!</span>")
			else
				to_chat(usr, "<span class='warning'>Torpedo launch failed. Check master arm, tube status, and target lock.</span>")

	interact(usr)

// --- RADIO / MISSION CONSOLE ---

/obj/structure/machinery/sub_control/radio_console
	name = "encrypted radio console"
	desc = "A hardened military radio transceiver with frequency hopping and burst encryption."
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer"
	scr_overlay = "comm_logs"

	var/list/message_log = list()       // List of radio messages
	var/max_log_entries = 50

/obj/structure/machinery/sub_control/radio_console/New()
	..()
	// Register with the mission controller
	if(global.subcom_map && global.subcom_map.missions)
		global.subcom_map.missions.radio_console = src

/obj/structure/machinery/sub_control/radio_console/proc/add_log(var/message)
	message_log.Add("\[[world.time / 10]\] [message]")
	if(message_log.len > max_log_entries)
		message_log.Cut(1, 2)  // Remove oldest entry

/obj/structure/machinery/sub_control/radio_console/get_ui_content()
	var/dat = ""

	// === TOP: Radio Status ===
	dat += "<div class='panel' style='padding:8px; margin-bottom:8px;'>"
	dat += "<div class='flex-between'>"
	dat += "<div class='label'>ENCRYPTED RADIO</div>"
	dat += "<div><span class='light light-green'></span> <span style='color:#0f0; font-weight:bold;'>LINKED</span></div>"
	dat += "</div>"
	dat += "<div style='font-size:10px; color:#888; margin-top:4px;'>FREQ: 147.325 MHz | MOD: FHSS-AES | BANDWIDTH: 25 kHz</div>"
	dat += "</div>"

	// === CURRENT ORDERS ===
	dat += "<div class='panel' style='padding:10px; margin-bottom:8px;'>"
	dat += "<div class='label'>CURRENT ORDERS</div>"
	if(global.subcom_map && global.subcom_map.missions)
		dat += "<pre style='color:#0f0; font-size:11px; margin-top:6px; white-space:pre-wrap;'>[global.subcom_map.missions.get_status_text()]</pre>"
	else
		dat += "<div style='color:#666; margin-top:6px;'>No mission controller active.</div>"
	dat += "</div>"

	// === TRANSMISSION LOG ===
	dat += "<div class='panel crt-overlay' style='padding:10px; margin-bottom:8px;'>"
	dat += "<div class='flex-between mb-4'>"
	dat += "<div class='label'>TRANSMISSION LOG</div>"
	dat += "<a href='?src=\ref[src];clear_log=1' class='btn btn-grey' style='font-size:9px;'>CLEAR</a>"
	dat += "</div>"
	dat += "<div style='background:#001a00; border:1px solid #0a0; padding:6px; max-height:200px; overflow-y:auto;'>"
	if(message_log.len)
		for(var/i = message_log.len, i >= max(1, message_log.len - 25), i--)
			dat += "<div style='color:#0a0; font-size:10px; padding:1px 0; border-bottom:1px solid #020;'>[message_log[i]]</div>"
	else
		dat += "<div style='color:#040; text-align:center; padding:20px;'>Awaiting transmissions...</div>"
	dat += "</div>"
	dat += "</div>"

	// === NAVIGATION ===
	dat += "<div class='panel' style='padding:8px;'>"
	dat += "<div class='label'>NAVIGATION</div>"
	dat += "<div style='margin-top:6px;'>"
	if(global.subcom_map)
		if(global.subcom_map.fast_travel_active)
			dat += "<div class='flex-between'>"
			dat += "<div><span class='light light-red'></span> <span style='color:#f00; font-weight:bold;'>FAST TRAVEL ENGAGED</span></div>"
			dat += "<a href='?src=\ref[src];fast_travel=0' class='btn btn-red'>DISENGAGE</a>"
			dat += "</div>"
		else
			dat += "<div class='flex-between'>"
			dat += "<div><span class='light light-off'></span> <span style='color:#888;'>FAST TRAVEL STANDBY</span></div>"
			dat += "<a href='?src=\ref[src];fast_travel=1' class='btn btn-green'>ENGAGE (10x)</a>"
			dat += "</div>"
	dat += "</div></div>"

	return dat

/obj/structure/machinery/sub_control/radio_console/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["clear_log"])
		message_log.Cut()

	if(href_list["fast_travel"])
		if(global.subcom_map)
			if(text2num(href_list["fast_travel"]) == 1)
				global.subcom_map.enable_fast_travel()
				add_log("FAST TRAVEL ENGAGED. Speed x10. Auto-disabling on hostile contact.")
			else
				global.subcom_map.disable_fast_travel("Manual disengagement by operator.")

	interact(usr)

// ============================================================
// Compartment Status Panel — ship-wide damage/flood monitor
// ============================================================

/obj/structure/machinery/sub_control/compartment_panel
	name = "compartment status panel"
	desc = "A ruggedized flat-panel display showing real-time compartment status across the submarine."
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer"
	scr_overlay = "engineering"

/obj/structure/machinery/sub_control/compartment_panel/get_ui_content()
	var/dat = ""

	// === TOP: Summary bar ===
	var/total_water = 0
	var/flooded_count = 0
	var/total_turfs = 0
	if(global.subcom_flooding)
		for(var/cid in global.subcom_flooding.compartment_turfs)
			var/wl = global.subcom_flooding.get_compartment_water_level(cid)
			total_water += wl
			total_turfs++
			if(wl >= 150)
				flooded_count++

	dat += "<div class='panel' style='padding:8px; margin-bottom:8px;'>"
	dat += "<div class='flex-between'>"
	dat += "<div class='label'>DAMAGE CONTROL</div>"
	dat += "<div style='font-size:11px;'>"
	dat += "<span style='color:#888;'>WATER:</span> <span style='color:[total_water > 0 ? "#f80" : "#0f0"]; font-weight:bold;'>[round(total_water)]cm</span> | "
	dat += "<span style='color:#888;'>FLOODED:</span> <span style='color:[flooded_count > 0 ? "#f00" : "#0f0"]; font-weight:bold;'>[flooded_count]/[total_turfs]</span>"
	dat += "</div></div></div>"

	// === COMPARTMENT TABLE ===
	dat += "<div class='panel' style='padding:10px;'>"
	dat += "<table class='data-table'>"
	dat += "<tr>"
	dat += "<th style='width:22%;'>COMPARTMENT</th>"
	dat += "<th style='width:12%; text-align:right;'>WATER</th>"
	dat += "<th style='width:12%; text-align:right;'>O<sub>2</sub></th>"
	dat += "<th style='width:12%; text-align:right;'>CO<sub>2</sub></th>"
	dat += "<th style='width:16%; text-align:center;'>STATUS</th>"
	dat += "<th style='width:12%; text-align:center;'>VENT</th>"
	dat += "</tr>"

	if(global.subcom_flooding)
		var/list/all_status = global.subcom_flooding.get_all_compartment_status()
		for(var/cid in all_status)
			var/list/data = all_status[cid]
			var/water = data["water_level"]
			var/o2 = data["oxygen"]
			var/co2 = data["co2"]
			var/flooded = data["flooded"]
			var/vacuum = data["vacuum"]

			// Compartment name
			var/display_name = cid
			switch(cid)
				if(SUB_COMP_FORWARD_TORPEDO) display_name = "FWD TORPEDO"
				if(SUB_COMP_FORWARD_BATTERY) display_name = "FWD BATTERY"
				if(SUB_COMP_OPERATIONS) display_name = "OPERATIONS"
				if(SUB_COMP_CREW_QUARTERS) display_name = "CREW QUARTERS"
				if(SUB_COMP_GALLEY) display_name = "GALLEY"
				if(SUB_COMP_CPO_QUARTERS) display_name = "CPO QUARTERS"
				if(SUB_COMP_AFT_BATTERY) display_name = "AFT BATTERY"
				if(SUB_COMP_REACTOR_ROOM) display_name = "REACTOR"
				if(SUB_COMP_ENGINE_ROOM) display_name = "ENGINE"
				if(SUB_COMP_MANEUVERING) display_name = "MANEUVERING"
				if(SUB_COMP_AFT_TORPEDO) display_name = "AFT TORPEDO"

			// Status
			var/status_color = "#0f0"
			var/status_text = "OK"
			var/light_class = "light-green"
			if(vacuum)
				status_color = "#f00"; status_text = "VACUUM"; light_class = "light-critical"
			else if(flooded)
				status_color = "#f00"; status_text = "FLOODED"; light_class = "light-red"
			else if(water > 100)
				status_color = "#f80"; status_text = "FLOODING"; light_class = "light-amber"
			else if(water > 50)
				status_color = "#ff0"; status_text = "WATER"; light_class = "light-yellow"

			// O2 color
			var/o2_color = "#0f0"
			if(o2 < 5) o2_color = "#f00"
			else if(o2 < 12) o2_color = "#f80"

			// CO2 color
			var/co2_color = "#0f0"
			if(co2 > 5) co2_color = "#f00"
			else if(co2 > 2) co2_color = "#f80"

			// Water color
			var/water_color = "#0f0"
			if(water > 50) water_color = "#f80"
			else if(water > 10) water_color = "#ff0"

			// Vent state
			var/vent_on = (cid in global.subcom_flooding.vent_networks)

			dat += "<tr>"
			dat += "<td style='font-weight:bold;'>[display_name]</td>"
			dat += "<td style='text-align:right; color:[water_color];'>[round(water)]cm</td>"
			dat += "<td style='text-align:right; color:[o2_color];'>[round(o2, 0.1)]</td>"
			dat += "<td style='text-align:right; color:[co2_color];'>[round(co2, 0.1)]</td>"
			dat += "<td style='text-align:center;'><span class='light [light_class]'></span> <span style='color:[status_color]; font-size:10px;'>[status_text]</span></td>"
			dat += "<td style='text-align:center;'>"
			dat += "<a href='?src=\ref[src];toggle_vent=[cid]' style='text-decoration:none;'>"
			var/vent_class = vent_on ? "switch switch-on" : "switch"
			dat += "<span class='[vent_class]'></span>"
			dat += "</a></td>"
			dat += "</tr>"

	dat += "</table>"
	dat += "</div>"

	// === CREW STATUS ===
	if(my_sub && my_sub.crew.len > 0)
		dat += "<div class='panel' style='padding:10px; margin-top:8px;'>"
		dat += "<div class='label'>CREW STATUS</div>"
		dat += "<table class='data-table'>"
		dat += "<tr>"
		dat += "<th style='width:25%;'>NAME</th>"
		dat += "<th style='width:20%;'>ROLE</th>"
		dat += "<th style='width:15%; text-align:center;'>STATUS</th>"
		dat += "<th style='width:20%;'>OXYGEN</th>"
		dat += "<th style='width:20%;'>COMPARTMENT</th>"
		dat += "</tr>"

		for(var/datum/crew_member/CM in my_sub.crew)
			var/status_color = "#0f0"
			var/status_text = "OK"
			if(!CM.conscious)
				status_color = "#f00"
				status_text = "UNCONSCIOUS"
			else if(CM.injured)
				status_color = "#f80"
				status_text = "INJURED"

			var/o2_color = "#0f0"
			if(CM.oxygen_status == "Suffocating" || CM.oxygen_status == "Drowning")
				o2_color = "#f00"
			else if(CM.oxygen_status == "Low O2")
				o2_color = "#f80"

			// Compartment display name
			var/comp_display = CM.compartment ? CM.compartment : "UNKNOWN"
			switch(CM.compartment)
				if(SUB_COMP_FORWARD_TORPEDO) comp_display = "FWD TORPEDO"
				if(SUB_COMP_FORWARD_BATTERY) comp_display = "FWD BATTERY"
				if(SUB_COMP_OPERATIONS) comp_display = "OPERATIONS"
				if(SUB_COMP_CREW_QUARTERS) comp_display = "CREW QUARTERS"
				if(SUB_COMP_GALLEY) comp_display = "GALLEY"
				if(SUB_COMP_CPO_QUARTERS) comp_display = "CPO QUARTERS"
				if(SUB_COMP_AFT_BATTERY) comp_display = "AFT BATTERY"
				if(SUB_COMP_REACTOR_ROOM) comp_display = "REACTOR"
				if(SUB_COMP_ENGINE_ROOM) comp_display = "ENGINE"

			dat += "<tr>"
			dat += "<td style='font-weight:bold;'>[CM.name]</td>"
			dat += "<td>[CM.assignment]</td>"
			dat += "<td style='text-align:center; color:[status_color];'>[status_text]</td>"
			dat += "<td style='color:[o2_color];'>[CM.oxygen_status]</td>"
			dat += "<td>[comp_display]</td>"
			dat += "</tr>"

		dat += "</table>"
		dat += "</div>"

	// === ACTION BUTTONS ===
	dat += "<div class='flex-row' style='justify-content:center; gap:6px; margin-top:6px;'>"
	dat += "<a href='?src=\ref[src];drain_all=1' class='btn btn-red' style='min-width:140px;'>EMERGENCY DRAIN</a>"
	dat += "<a href='?src=\ref[src];inject_o2=1' class='btn btn-blue' style='min-width:140px;'>O<sub>2</sub> INJECT ALL</a>"
	dat += "<a href='?src=\ref[src];seal_all=1' class='btn btn-yellow' style='min-width:140px;'>SEAL BULKHEADS</a>"
	dat += "</div>"

	return dat

/obj/structure/machinery/sub_control/compartment_panel/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["toggle_vent"])
		var/cid = href_list["toggle_vent"]
		if(global.subcom_flooding)
			if(cid in global.subcom_flooding.vent_networks)
				var/list/vents = global.subcom_flooding.vent_networks[cid]
				for(var/turf/floor/sub_deck/T in vents)
					T.vent_active = FALSE
				global.subcom_flooding.vent_networks -= cid
				to_chat(usr, "<span class='notice'>Ventilation shut down for [cid].</span>")
			else
				if(cid in global.subcom_flooding.compartment_turfs)
					global.subcom_flooding.vent_networks[cid] = list()
					for(var/turf/floor/sub_deck/T in global.subcom_flooding.compartment_turfs[cid])
						T.vent_active = TRUE
						T.vent_id = cid
						global.subcom_flooding.vent_networks[cid] += T
					to_chat(usr, "<span class='notice'>Ventilation restored for [cid].</span>")

	if(href_list["drain_all"])
		if(global.subcom_flooding)
			var/total_drained = 0
			for(var/cid in global.subcom_flooding.compartment_turfs)
				total_drained += global.subcom_flooding.emergency_drain(cid, 15)
			to_chat(usr, "<span class='notice'>Emergency drain activated. [round(total_drained)]cm of water removed.</span>")

	if(href_list["inject_o2"])
		if(global.subcom_flooding)
			for(var/cid in global.subcom_flooding.compartment_turfs)
				global.subcom_flooding.inject_oxygen(cid, 5)
			to_chat(usr, "<span class='notice'>Oxygen injection activated across all compartments.</span>")

	if(href_list["seal_all"])
		var/sealed = 0
		for(var/turf/wall/sub_bulkhead/B in world)
			if(QDELETED(B)) continue
			if(!B.watertight && B.health > 0)
				B.watertight = TRUE
				sealed++
		to_chat(usr, "<span class='notice'>[sealed] bulkhead(s) sealed.</span>")

	interact(usr)
