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
	var/list/open_users = list()   // Mobs currently viewing this console
	var/list/window_open = list()  // Assoc: mob -> TRUE while their window is open
	var/window_size = "700x600"
/obj/structure/machinery/sub_control/New()
	..()
	if(global.all_submarines.len)
		my_sub = global.all_submarines[1]
	update_icon()
	spawn()
		auto_refresh_loop()

/obj/structure/machinery/sub_control/proc/auto_refresh_loop()
	while(!QDELETED(src) && active && !broken)
		sleep(10)
		var/list/stale = list()
		for(var/mob/M in open_users)
			if(!M || !M.client || QDELETED(M))
				stale += M
				continue
			if(!window_open[M])
				stale += M
				continue
			if(!can_use(M))
				stale += M
				window_open -= M
				M << browse(null, "window=sub_control")
				continue
			send_ui(M)
		open_users -= stale

/obj/structure/machinery/sub_control/update_icon()
	overlays.Cut()
	if(active && !broken)
		overlays += image(icon = icon, icon_state = scr_overlay)

/obj/structure/machinery/sub_control/proc/can_use(mob/user)
	if(broken || !active)
		to_chat(user, "<span class='warning'>The console is powered down or broken.</span>")
		return FALSE
	// Ghost/dead check: allowed only in single-player mode (skip all below)
	if(user.stat == DEAD || isobserver(user))
		var/obj/map_metadata/subcom13/SM = map
		if(istype(SM) && SM.single_player)
			return TRUE
		to_chat(user, "<span class='warning'>Single-player mode is not enabled.</span>")
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
	return TRUE

/obj/structure/machinery/sub_control/attack_hand(mob/user)
	interact(user)

/obj/structure/machinery/sub_control/attack_ghost(mob/observer/ghost/user)
	var/obj/map_metadata/subcom13/SM = map
	if(istype(SM) && SM.single_player)
		interact(user)
		return
	..()

/obj/structure/machinery/sub_control/interact(mob/user)
	if(!can_use(user))
		user << browse(null, "window=sub_control")
		open_users -= user
		window_open -= user
		return

	if(!(user in open_users))
		open_users += user
	window_open[user] = TRUE

	send_ui(user)
	onclose(user, "sub_control", src)

/obj/structure/machinery/sub_control/proc/send_ui(mob/user)
	if(!user || !user.client) return
	user << browse_rsc('UI/css/submarine.css', "submarine.css")

	var/dat = "<html><head>"
	dat += "<link rel='stylesheet' type='text/css' href='submarine.css'>"
	dat += "<style>"
	dat += "a { color: #fff; text-decoration: none; border: 1px solid #0f0; padding: 2px 6px; background: #222; border-radius: 2px; }"
	dat += "a:hover { background: #0f0; color: #000; }"
	dat += "</style></head><body>"
	dat += "<div style='display:flex; justify-content:space-between; align-items:center;'>"
	dat += "<div class='label' style='font-size:13px;'>[vessel_name_header()]</div>"
	dat += "<a href='?src=\ref[src];close_console=1' class='btn btn-red' style='font-size:9px; min-width:40px;'>CLOSE</a>"
	dat += "</div>"

	dat += get_ui_content()

	dat += "</body></html>"
	user << browse(dat, "window=sub_control;size=[window_size]")

/obj/structure/machinery/sub_control/proc/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - SYSTEMS INTERFACE"

/obj/structure/machinery/sub_control/Topic(href, href_list)
	if(href_list["close_console"])
		open_users -= usr
		window_open -= usr
		usr << browse(null, "window=sub_control")
		return 1
	if(href_list["close"])
		open_users -= usr
		window_open -= usr
		return 1
	if(!can_use(usr))
		return 1
	return 0

/obj/structure/machinery/sub_control/proc/get_ui_content()
	return "BASE INTERFACE"

// Auto-refresh handled by spawn() loop in New()

// --- MANEUVER PANEL ---

/obj/structure/machinery/sub_control/maneuver_panel
	name = "helm control station"
	icon_state = "computer"
	scr_overlay = "navigation"
	window_size = "1000x600"

/obj/structure/machinery/sub_control/maneuver_panel/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - HELM & NAVIGATION"

/obj/structure/machinery/sub_control/maneuver_panel/get_ui_content()
	var/dat = ""

	// === TOP ROW: Large dials ===
	dat += "<div class='flex-row' style='justify-content:center; gap:16px; margin-bottom:8px;'>"

	// --- HEADING DIAL (360° compass) ---
	dat += "<div class='panel' style='text-align:center; padding:8px;'>"
	dat += "<div class='label'>HEADING</div>"
	dat += "<div class='gauge' style='margin:6px auto;'>"
	dat += "<div class='gauge-ticks-360'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([my_sub.target_heading]deg); background:rgba(255,0,0,0.3); height:45px; width:4px;'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([my_sub.heading]deg);'></div>"
	dat += "<div class='gauge-center'></div>"
	dat += "<div class='gauge-value'>[round(my_sub.heading)]&deg;</div>"
	// Cardinal direction labels
	dat += "<div style='position:absolute; top:2px; left:50%; transform:translateX(-50%); font-size:8px; color:#0f0; font-weight:bold;'>N</div>"
	dat += "<div style='position:absolute; bottom:2px; left:50%; transform:translateX(-50%); font-size:8px; color:#0f0; font-weight:bold;'>S</div>"
	dat += "<div style='position:absolute; top:50%; right:2px; transform:translateY(-50%); font-size:8px; color:#0f0; font-weight:bold;'>E</div>"
	dat += "<div style='position:absolute; top:50%; left:2px; transform:translateY(-50%); font-size:8px; color:#0f0; font-weight:bold;'>W</div>"
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
	var/target_sp_angle = (my_sub.target_speed / 30) * 270 - 135
	dat += "<div class='panel' style='text-align:center; padding:8px;'>"
	dat += "<div class='label'>SPEED</div>"
	dat += "<div class='gauge' style='margin:6px auto;'>"
	dat += "<div class='gauge-ticks'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([target_sp_angle]deg); background:rgba(255,0,0,0.3); height:45px; width:4px;'></div>"
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
	var/target_dp_angle = (my_sub.target_depth / my_sub.crush_depth) * 270 - 135
	var/depth_color = "#0f0"
	if(my_sub.depth > my_sub.crush_depth * 0.8)
		depth_color = "#f00"
	else if(my_sub.depth > my_sub.crush_depth * 0.5)
		depth_color = "#ff0"
	dat += "<div class='panel' style='text-align:center; padding:8px;'>"
	dat += "<div class='label'>DEPTH</div>"
	dat += "<div class='gauge' style='margin:6px auto;'>"
	dat += "<div class='gauge-ticks'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([target_dp_angle]deg); background:rgba(0,255,0,0.3); height:45px; width:4px;'></div>"
	dat += "<div class='gauge-needle' style='transform:rotate([dp_angle]deg); background:[depth_color];'></div>"
	dat += "<div class='gauge-center'></div>"
	dat += "<div class='gauge-value' style='color:[depth_color];'>[round(my_sub.depth)]</div>"
	dat += "<div class='gauge-label'>METERS</div>"
	dat += "</div>"
	dat += "<div style='font-size:12px; font-weight:bold; color:[depth_color]; margin:4px 0;'>[round(my_sub.depth)]m / [my_sub.crush_depth]m</div>"
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

	// --- POWER ---
	var/total_production = (my_sub.r_power_output[1] + my_sub.r_power_output[2]) * 1000 // MW -> kW
	var/total_usage = SUB_BATTERY_DRAIN_ELECTRIC // base drain
	if(my_sub.sonar_active)
		total_usage += my_sub.sonar_mode == SUB_SONAR_ACTIVE ? SUB_SONAR_POWER_ACTIVE : SUB_SONAR_POWER_PASSIVE
	if(my_sub.radar_active)
		total_usage += my_sub.radar_range_long ? SUB_RADAR_POWER_LONG : SUB_RADAR_POWER_SHORT
	
	if(my_sub.speed > 0)
		var/prop_drain = (my_sub.speed / 30) * 15000 // kW drain for propulsion
		if(my_sub.has_nuclear_engine)
			total_usage += prop_drain
		else if(my_sub.depth > 0)
			total_usage += prop_drain
			
	var/batt_pct = my_sub.battery_max > 0 ? (my_sub.battery_current / my_sub.battery_max * 100) : 0
	var/batt_color = batt_pct > 50 ? "#0f0" : (batt_pct > 20 ? "#ff0" : "#f00")
	var/power_balance = total_production - total_usage
	var/balance_color = power_balance >= 0 ? "#0f0" : "#f00"
	dat += "<div class='panel' style='padding:8px; min-width:140px;'>"
	dat += "<div class='label'>POWER</div>"
	dat += "<div style='margin-top:6px;'>"
	dat += "<div style='font-size:9px; color:#888;'>PRODUCTION</div>"
	dat += "<div style='font-size:12px; font-weight:bold; color:#0f0;'>[round(total_production)] kW</div>"
	dat += "<div style='font-size:9px; color:#888; margin-top:4px;'>USAGE</div>"
	dat += "<div style='font-size:12px; font-weight:bold; color:[total_usage > total_production ? "#f00" : "#0f0"];'>[round(total_usage)] kW</div>"
	dat += "<div style='font-size:9px; color:#888; margin-top:4px;'>BALANCE</div>"
	dat += "<div style='font-size:12px; font-weight:bold; color:[balance_color];'>[power_balance >= 0 ? "+" : ""][round(power_balance)] kW</div>"
	dat += "<div style='font-size:9px; color:#888; margin-top:4px;'>BATTERY</div>"
	dat += "<div style='background:#111; border:1px solid #333; height:10px; border-radius:2px; overflow:hidden;'>"
	dat += "<div style='height:100%; width:[batt_pct]%; background:[batt_color];'></div>"
	dat += "</div>"
	dat += "<div style='font-size:9px; color:[batt_color]; text-align:center;'>[round(my_sub.battery_current)]/[round(my_sub.battery_max)] kWh ([round(batt_pct)]%)</div>"
	dat += "</div></div>"

	// --- DIESEL THROTTLE (visible when surfaced) ---
	if(my_sub.depth == 0)
		dat += "<div class='panel' style='padding:8px; min-width:140px;'>"
		dat += "<div class='label'>DIESEL THROTTLE</div>"
		dat += "<div style='margin-top:6px; text-align:center;'>"
		dat += "<div style='font-size:18px; font-weight:bold; color:#0f0;'>[round(my_sub.diesel_throttle)]%</div>"
		dat += "</div>"
		dat += "<div style='text-align:center; margin-top:4px; gap:4px;'>"
		dat += "<a href='?src=\ref[src];adj_dt=-10' class='btn btn-grey' style='font-size:9px;'>-10</a> "
		dat += "<a href='?src=\ref[src];adj_dt=-5' class='btn btn-grey' style='font-size:9px;'>-5</a> "
		dat += "<a href='?src=\ref[src];adj_dt=5' class='btn btn-green' style='font-size:9px;'>+5</a> "
		dat += "<a href='?src=\ref[src];adj_dt=10' class='btn btn-green' style='font-size:9px;'>+10</a>"
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
		var/new_depth = text2num(href_list["set_dp"])
		my_sub.target_depth = new_depth
		if(new_depth >= 250)
			playsound(src, 'sound/machines/submarine/dive_alarm.ogg', 80, 1)
			visible_message("<span class='warning'><b>CRASH DIVE! Crash diving to [new_depth]m!</b></span>")

	if(href_list["blow_ballast"])
		my_sub.target_depth = 0
		my_sub.ballast = 0
		visible_message("<span class='warning'>The ballast tanks hiss violently!</span>")
		playsound(src, 'sound/machines/submarine/blowballast.ogg', 80, 1)
		playsound(src, 'sound/machines/submarine/dive_alarm.ogg', 60, 1)

	if(href_list["adj_dt"])
		my_sub.diesel_throttle = clamp(my_sub.diesel_throttle + text2num(href_list["adj_dt"]), 0, 100)

	interact(usr)

// --- REACTOR PANEL ---

/obj/structure/machinery/sub_control/reactor_panel
	name = "reactor control station"
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer-solgov"
	scr_overlay = "fuel_screen"
	var/obj/structure/machinery/sub_physical/reactor_core/reactor1
	var/obj/structure/machinery/sub_physical/reactor_core/reactor2
	window_size = "700x500"

/obj/structure/machinery/sub_control/reactor_panel/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - REACTOR CONTROL"

/obj/structure/machinery/sub_control/reactor_panel/New()
	..()
	spawn(20)
		assign_reactors()

/obj/structure/machinery/sub_control/reactor_panel/proc/assign_reactors()
	for(var/obj/structure/machinery/sub_physical/reactor_core/R in world)
		if(R.id == 1 && !reactor1)
			reactor1 = R
			R.name = "Reactor Core 1"
		else if(R.id == 2 && !reactor2)
			reactor2 = R
			R.name = "Reactor Core 2"

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
		playsound(src, 'sound/machines/submarine/scram_alarm.ogg', 80, 1)

	interact(usr)

// --- MISC SYSTEMS PANEL ---

/obj/structure/machinery/sub_control/misc_systems
	name = "auxiliary systems console"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "transponder"
	scr_overlay = "transponder_screen"
	window_size = "700x750"

	var/list/compartments = list(
		"Forward Torpedo Room",
		"Storage",
		"Operations",
		"Central Corridor",
		"Galley",
		"Medical Bay",
		"Rear Corridor",
		"Reactor Room",
		"Engine Room",
		"Maneuvering Room",
		"After Torpedo Room"
	)
	// Internal status tracking for simulation
	var/list/vents_open = list()
	var/list/fire_supp_active = list()

/obj/structure/machinery/sub_control/misc_systems/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - AUXILIARY SYSTEMS"

/obj/structure/machinery/sub_control/misc_systems/New()
	vents_open = list()
	fire_supp_active = list()
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
			playsound(src, 'sound/machines/submarine/gas.ogg', 50, 1)

	interact(usr)

// --- RADAR PANEL ---

/obj/structure/machinery/sub_control/radar_panel
	name = "radar console"
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer-retro"
	scr_overlay = "radar_screen"
	var/radar_channel = 0

/obj/structure/machinery/sub_control/radar_panel/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - RADAR SYSTEMS"

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
		dat += "<div style='margin-top:6px; padding:4px; background:#440; border:1px solid #ff0; text-align:center; color:#ff0; font-weight:bold;'>RADAR: SUBMERGED - LIMITED VISIBILITY</div>"

	dat += "</div>"

	// === CIRCULAR RADAR DISPLAY ===
	var/max_range = my_sub.radar_range_long ? SUB_RADAR_RANGE_LONG : SUB_RADAR_RANGE_SHORT
	var/display_size = 200
	var/radius = display_size / 2
	var/center = radius

	dat += "<div class='panel crt-overlay' style='padding:10px;'>"
	dat += "<div style='background:#001a00; border:1px solid #0a0; padding:8px; position:relative;'>"

	// Compass labels
	dat += "<div style='text-align:center; font-size:9px; color:#0a0; margin-bottom:4px;'>N</div>"

	dat += "<div style='display:flex; align-items:center;'>"
	dat += "<div style='font-size:9px; color:#0a0; padding-right:4px;'>W</div>"

	// Circular radar container
	dat += "<div style='position:relative; width:[display_size]px; height:[display_size]px; background:#000; border:1px solid #0a0; border-radius:50%; overflow:hidden;'>"

	// Range rings at 25%, 50%, 75%, 100%
	for(var/ring_pct = 25; ring_pct <= 100; ring_pct += 25)
		var/ring_r = radius * ring_pct / 100
		dat += "<div style='position:absolute; left:[center - ring_r]px; top:[center - ring_r]px; width:[ring_r * 2]px; height:[ring_r * 2]px; border:1px solid #0a200a; border-radius:50%; z-index:1;'></div>"

	// Cross-hair lines (N-S, E-W, NE/NW/SE/SW)
	dat += "<div style='position:absolute; left:[center]px; top:0; width:1px; height:[display_size]px; background:#0a200a; z-index:1;'></div>"
	dat += "<div style='position:absolute; left:0; top:[center]px; width:[display_size]px; height:1px; background:#0a200a; z-index:1;'></div>"
	// Diagonal lines
	dat += "<div style='position:absolute; left:0; top:0; width:[display_size]px; height:1px; background:#0a200a; transform-origin:0 0; transform:rotate(45deg); z-index:1;'></div>"
	dat += "<div style='position:absolute; left:0; top:0; width:[display_size]px; height:1px; background:#0a200a; transform-origin:0 0; transform:rotate(-45deg); z-index:1;'></div>"

	// Range ring labels
	dat += "<div style='position:absolute; left:[center + 2]px; top:[center - radius * 0.25 - 6]px; font-size:7px; color:#080; z-index:3;'>[round(max_range * 0.25 / 1000)]km</div>"
	dat += "<div style='position:absolute; left:[center + 2]px; top:[center - radius * 0.5 - 6]px; font-size:7px; color:#080; z-index:3;'>[round(max_range * 0.5 / 1000)]km</div>"
	dat += "<div style='position:absolute; left:[center + 2]px; top:[center - radius * 0.75 - 6]px; font-size:7px; color:#080; z-index:3;'>[round(max_range * 0.75 / 1000)]km</div>"

	// Draw contacts
	if(my_sub.radar_active && my_sub.detected_targets.len)
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			var/rel_x = C.range * sin(C.bearing)
			var/rel_y = C.range * cos(C.bearing)
			var/px = center + (rel_x / max_range) * radius
			var/py = center - (rel_y / max_range) * radius
			// Clamp to circle
			var/dist_from_center = sqrt((px - center) ** 2 + (py - center) ** 2)
			if(dist_from_center > radius - 4)
				var/clamp_scale = (radius - 4) / dist_from_center
				px = center + (px - center) * clamp_scale
				py = center + (py - center) * clamp_scale
			// Contact color
			var/contact_color = "#0af"
			if(C.contact_type == SUB_CONTACT_AIR)
				contact_color = "#f80"
			else if(C.contact_type == SUB_CONTACT_SUBMERGED)
				contact_color = "#0f0"
			else if(C.nationality == SUB_NATION_HOSTILE)
				contact_color = "#f00"
			var/is_tagged = (C in my_sub.tagged_contacts)
			var/blip_size = is_tagged ? 8 : 5
			var/blip_offset = is_tagged ? 4 : 2.5
			var/label_px = px + 6
			var/label_py = py - 4
			// Blip
			dat += "<div style='position:absolute; left:[px - blip_offset]px; top:[py - blip_offset]px; width:[blip_size]px; height:[blip_size]px; background:[contact_color]; border-radius:50%; box-shadow:0 0 [is_tagged ? "6" : "3"]px [contact_color]; z-index:4;'></div>"
			// Label for tagged contacts
			if(is_tagged)
				dat += "<div style='position:absolute; left:[label_px]px; top:[label_py]px; font-size:7px; color:[contact_color]; white-space:nowrap; z-index:4;'>[C.name]</div>"

	// Player sub (center)
	dat += "<div style='position:absolute; left:[center - 4]px; top:[center - 4]px; width:8px; height:8px; background:#fff; border:2px solid #0f0; border-radius:50%; box-shadow:0 0 8px #0f0; z-index:5;'></div>"

	dat += "</div>" // end circular radar

	dat += "<div style='text-align:center; font-size:9px; color:#0a0; margin-top:4px;'>S</div>"
	dat += "<div style='text-align:right; font-size:9px; color:#0a0; margin-top:-10px; margin-right:-12px;'>E</div>"

	dat += "</div>" // end crt-overlay panel

	// === CONTACT TABLE (below radar) ===
	dat += "<div class='panel' style='padding:10px; margin-top:8px;'>"
	dat += "<div class='label'>DETECTED CONTACTS</div>"
	if(my_sub.radar_active && my_sub.detected_targets.len)
		dat += "<table class='data-table' style='margin-top:6px;'>"
		dat += "<tr><th>NAME</th><th>RANGE</th><th>BEARING</th><th>TYPE</th><th></th></tr>"
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			var/type_color = "#0af"
			var/type_text = "SURFACE"
			if(C.contact_type == SUB_CONTACT_AIR)
				type_color = "#f80"
				type_text = "AIR"
			else if(C.contact_type == SUB_CONTACT_SUBMERGED)
				type_color = "#0f0"
				type_text = "SUBMERGED"
			var/is_tagged = (C in my_sub.tagged_contacts)
			dat += "<tr>"
			dat += "<td style='font-weight:bold; color:[is_tagged ? "#0ff" : "#fff"];'>[C.name]</td>"
			dat += "<td>[round(C.range)]m</td>"
			dat += "<td>[round(C.bearing)]&deg;</td>"
			dat += "<td style='color:[type_color];'>[type_text]</td>"
			dat += "<td><a href='?src=\ref[src];tag_contact=\ref[C];tag_contact_name=[C.name]' style='font-size:8px; color:[is_tagged ? "#0ff" : "#666"];'>[is_tagged ? "TAGGED" : "TAG"]</a></td>"
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
				my_sub.detected_targets.Cut()
				if(radar_channel)
					src << sound(null, channel = radar_channel)
					radar_channel = 0
			else
				var/sound/S = sound('sound/machines/submarine/dgen.ogg', repeat = TRUE, wait = 0, volume = 30, channel = 771)
				radar_channel = 771
				src << S
		else
			to_chat(usr, "<span class='warning'>Cannot activate radar while submerged!</span>")

	if(href_list["toggle_range"])
		if(my_sub.radar_active)
			my_sub.radar_range_long = !my_sub.radar_range_long
		else
			to_chat(usr, "<span class='notice'>Activate radar first to change range.</span>")

	if(href_list["tag_contact"])
		var/datum/vessel_contact/target = locate(href_list["tag_contact"]) in my_sub.detected_targets
		if(!target)
			var/tag_name = href_list["tag_contact_name"]
			if(tag_name)
				for(var/datum/vessel_contact/C in my_sub.detected_targets)
					if(C.name == tag_name)
						target = C
						break
		if(target)
			if(target in my_sub.tagged_contacts)
				my_sub.tagged_contacts -= target
			else
				my_sub.tagged_contacts += target

	interact(usr)

// --- SONAR PANEL ---

/obj/structure/machinery/sub_control/sonar_panel
	name = "sonar console"
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer-retro"
	scr_overlay = "sonar_screen"
	var/selected_contact = null
	var/sonar_channel = 0

/obj/structure/machinery/sub_control/sonar_panel/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - SONAR SYSTEMS"

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

	// === BEARING SWEEP DISPLAY ===
	dat += "<div class='panel crt-overlay' style='padding:10px;'>"
	dat += "<div class='label'>BEARING SWEEP</div>"
	dat += "<div style='margin-top:8px; background:#001a00; border:1px solid #0a0; height:100px; position:relative; overflow:hidden;'>"
	if(my_sub.sonar_active)
		// Calculate sweep marker position
		var/sweep_x = my_sub.bearing_sweep >= 180 ? ((my_sub.bearing_sweep - 180) / 180) * 50 : 50 + (my_sub.bearing_sweep / 180) * 50
		// Draw the noise baseline - a faint horizontal line at 65% height
		dat += "<div style='position:absolute; left:0; right:0; top:65%; height:1px; background:rgba(0,160,0,0.4);'></div>"
		// Draw contact amplitude spikes
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			if(C.contact_type == SUB_CONTACT_SUBMERGED || C.contact_type == SUB_CONTACT_SURFACE)
				var/blip_x = C.bearing >= 180 ? ((C.bearing - 180) / 180) * 50 : 50 + (C.bearing / 180) * 50
				var/spike_h = max(15, min(55, (C.noise_signature / 100.0) * 55))
				var/is_selected = (C == selected_contact)
				var/spike_color = is_selected ? "#0ff" : C.contact_type == SUB_CONTACT_SUBMERGED ? "#0f0" : "#0af"
				// Spike: a vertical line going UP from the baseline
				dat += "<a href='?src=\ref[src];select_contact=\ref[C]' style='position:absolute; left:[blip_x]%; bottom:35%; width:3px; height:[spike_h]px; display:block; transform:translateX(-50%);'>"
				dat += "<div style='width:100%; height:100%; background:[spike_color]; box-shadow:0 0 4px [spike_color];'></div>"
				dat += "</a>"
				if(is_selected)
					// Selected contact: small label above spike
					dat += "<div style='position:absolute; left:[blip_x]%; bottom:[35 + spike_h + 2]%; transform:translateX(-50%); font-size:7px; color:#0ff; white-space:nowrap;'>[C.name]</div>"
		// Noise waveform using SVG with a fixed viewBox coordinate space (percentages are invalid in SVG points)
		// viewBox "0 0 1000 100" means x=0-1000 maps to full width, y=0-100 maps to full height
		dat += "<svg style='position:absolute; left:0; top:0; width:100%; height:100%;' viewBox='0 0 1000 100' preserveAspectRatio='none'>"
		var/noise_points = ""
		var/num_pts = 80
		for(var/i = 0; i <= num_pts; i++)
			var/svgx = (i * 1000) / num_pts
			// Pseudo-noise: mix of two prime-modulo offsets to make a more complex waveform
			var/noise_amp = (((i * 7 + my_sub.tick_counter * 3) % 17) - 8) + (((i * 13 + my_sub.tick_counter) % 11) - 5)
			var/svgy = 65 + noise_amp  // baseline at y=65, noise ±13 units out of 100
			noise_points += "[svgx],[svgy] "
		dat += "<polyline points='[noise_points]' fill='none' stroke='rgba(0,200,0,0.7)' stroke-width='1.5'/>"
		dat += "</svg>"
		// Sweep position marker: downward-pointing triangle
		dat += "<div style='position:absolute; left:[sweep_x]%; top:4px; transform:translateX(-50%); width:0; height:0; border-left:5px solid transparent; border-right:5px solid transparent; border-top:8px solid #0f0;'></div>"
		// Bearing labels at bottom
		dat += "<div style='position:absolute; bottom:2px; left:0; right:0; height:12px; font-size:8px; color:#0a0;'>"
		dat += "<span style='position:absolute; left:2%; transform:translateX(-50%);'>180</span>"
		dat += "<span style='position:absolute; left:14%; transform:translateX(-50%);'>225</span>"
		dat += "<span style='position:absolute; left:27%; transform:translateX(-50%);'>270</span>"
		dat += "<span style='position:absolute; left:39%; transform:translateX(-50%);'>315</span>"
		dat += "<span style='position:absolute; left:50%; transform:translateX(-50%);'>0</span>"
		dat += "<span style='position:absolute; left:61%; transform:translateX(-50%);'>45</span>"
		dat += "<span style='position:absolute; left:73%; transform:translateX(-50%);'>90</span>"
		dat += "<span style='position:absolute; left:86%; transform:translateX(-50%);'>135</span>"
		dat += "<span style='position:absolute; left:98%; transform:translateX(-50%);'>180</span>"
		dat += "</div>"
	else
		dat += "<div style='text-align:center; color:#040; padding-top:35px;'>SONAR OFFLINE</div>"
	dat += "</div>"
	dat += "</div>"

	// === BOTTOM ROW: LOFAR + CONTACTS ===
	dat += "<div class='flex-row' style='gap:8px;'>"

	// --- LOFAR DISPLAY (left) ---
	dat += "<div class='panel crt-overlay' style='flex:1; padding:10px;'>"
	dat += "<div class='label'>LOFAR SPECTRAL</div>"
	if(selected_contact && my_sub.sonar_active)
		var/datum/vessel_contact/SC = selected_contact
		// NPC contacts have sig_low/sig_mid/sig_high directly on them
		var/has_tonals = FALSE
		var/sig_low_val = 0
		var/sig_mid_val = 0
		var/sig_high_val = 0
		var/classification_val = "Unknown"
		if(istype(SC, /datum/vessel_contact/npc))
			var/datum/vessel_contact/npc/SCN = SC
			if(SCN.sig_low > 0)
				has_tonals = TRUE
				sig_low_val = SCN.sig_low
				sig_mid_val = SCN.sig_mid
				sig_high_val = SCN.sig_high
				classification_val = SCN.classification
		if(has_tonals)
			dat += "<div style='margin-top:6px; background:#001a00; border:1px solid #0a0; padding:6px;'>"
			dat += "<div style='font-size:9px; color:#0a0; margin-bottom:4px;'>TARGET: [SC.name] ([SC.range]m [round(SC.bearing)]&deg;)</div>"
			// Frequency axis
			dat += "<div style='display:flex; justify-content:space-between; font-size:7px; color:#060; border-bottom:1px solid #0a0; padding-bottom:2px; margin-bottom:4px;'>"
			dat += "<span>0 Hz</span><span>500</span><span>1000</span><span>1500</span><span>2000</span>"
			dat += "</div>"
			// Three tonals
			dat += "<div style='display:flex; gap:8px; justify-content:center;'>"
			// Low tonal (propeller)
			var/low_x = (sig_low_val / 2000) * 100
			dat += "<div style='text-align:center;'>"
			dat += "<div style='width:100%; height:40px; background:#001a00; border:1px solid #0a0; position:relative;'>"
			dat += "<div style='position:absolute; left:[low_x]%; top:0; bottom:0; width:3px; background:#0f0; box-shadow:0 0 4px #0f0;'></div>"
			dat += "</div>"
			dat += "<div style='font-size:7px; color:#0f0; margin-top:2px;'>[sig_low_val] Hz</div>"
			dat += "<div style='font-size:6px; color:#080;'>PROP</div>"
			dat += "</div>"
			// Mid tonal (engine)
			var/mid_x = (sig_mid_val / 2000) * 100
			dat += "<div style='text-align:center;'>"
			dat += "<div style='width:100%; height:40px; background:#001a00; border:1px solid #0a0; position:relative;'>"
			dat += "<div style='position:absolute; left:[mid_x]%; top:0; bottom:0; width:3px; background:#ff0; box-shadow:0 0 4px #ff0;'></div>"
			dat += "</div>"
			dat += "<div style='font-size:7px; color:#ff0; margin-top:2px;'>[sig_mid_val] Hz</div>"
			dat += "<div style='font-size:6px; color:#880;'>ENGINE</div>"
			dat += "</div>"
			// High tonal (aux)
			var/high_x = (sig_high_val / 2000) * 100
			dat += "<div style='text-align:center;'>"
			dat += "<div style='width:100%; height:40px; background:#001a00; border:1px solid #0a0; position:relative;'>"
			dat += "<div style='position:absolute; left:[high_x]%; top:0; bottom:0; width:3px; background:#f80; box-shadow:0 0 4px #f80;'></div>"
			dat += "</div>"
			dat += "<div style='font-size:7px; color:#f80; margin-top:2px;'>[sig_high_val] Hz</div>"
			dat += "<div style='font-size:6px; color:#840;'>AUX</div>"
			dat += "</div>"
			dat += "</div>"
			dat += "<div style='text-align:center; margin-top:6px; font-size:8px; color:#0f0; border-top:1px solid #0a0; padding-top:4px;'>"
			dat += "CLASSIFICATION: [classification_val]"
			dat += "</div>"
			dat += "</div>"
		else
			dat += "<div style='text-align:center; color:#666; padding-top:20px;'>No signature data available.</div>"
	else if(!my_sub.sonar_active)
		dat += "<div style='text-align:center; color:#040; padding-top:20px;'>SONAR OFFLINE</div>"
	else
		dat += "<div style='text-align:center; color:#666; padding-top:20px;'>Select a contact to analyze.</div>"
	dat += "</div>"

	// --- CONTACT LIST (right) ---
	dat += "<div class='panel' style='width:220px; padding:10px;'>"
	dat += "<div class='label'>CONTACTS</div>"
	if(my_sub.sonar_active && my_sub.detected_targets.len)
		dat += "<table style='width:100%; margin-top:6px; font-size:10px;'>"
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			if(C.contact_type == SUB_CONTACT_AIR) continue  // Sonar doesn't display air contacts
			var/is_selected = (C == selected_contact)
			var/is_tagged = (C in my_sub.tagged_contacts)
			var/row_bg = is_selected ? "#003300" : "transparent"
			var/type_color = C.contact_type == SUB_CONTACT_SUBMERGED ? "#0f0" : "#0af"
			dat += "<tr style='background:[row_bg];'>"
			dat += "<td style='padding:3px; cursor:pointer;' onclick='window.location=\"?src=\ref[src];select_contact=\ref[C];select_contact_name=[C.name]\";'>"
			dat += "<span style='font-weight:bold; color:[is_tagged ? "#0ff" : "#0f0"];'>[C.name]</span>"
			dat += "</td>"
			dat += "<td style='padding:3px; color:#888;'>[round(C.range)]m</td>"
			dat += "<td style='padding:3px; color:#888;'>[round(C.bearing)]&deg;</td>"
			dat += "<td style='padding:3px; color:[type_color];'>[C.contact_type]</td>"
			dat += "<td style='padding:3px;'>"
			dat += "<a href='?src=\ref[src];tag_contact=\ref[C];tag_contact_name=[C.name]' style='font-size:8px; color:[is_tagged ? "#0ff" : "#666"];'>[is_tagged ? "TAGGED" : "TAG"]</a>"
			dat += "</td>"
			dat += "</tr>"
		dat += "</table>"
	else
		dat += "<div style='margin-top:6px; color:#666; text-align:center;'>No contacts detected.</div>"

	dat += "</div>"
	dat += "</div>" // end bottom row

	return dat

/obj/structure/machinery/sub_control/sonar_panel/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["toggle_power"])
		my_sub.sonar_active = !my_sub.sonar_active
		if(!my_sub.sonar_active)
			my_sub.detected_targets.Cut()
			selected_contact = null
			if(sonar_channel)
				src << sound(null, channel = sonar_channel)
				sonar_channel = 0
		else
			playsound(src, 'sound/machines/submarine/sonar_ping.ogg', 50, 1)
			var/sound/S = sound('sound/machines/submarine/sonar_passive.ogg', repeat = TRUE, wait = 0, volume = 40, channel = 770)
			sonar_channel = 770
			src << S

	if(href_list["toggle_mode"])
		if(my_sub.sonar_active)
			my_sub.sonar_mode = (my_sub.sonar_mode == SUB_SONAR_ACTIVE) ? SUB_SONAR_PASSIVE : SUB_SONAR_ACTIVE
			if(my_sub.sonar_mode == SUB_SONAR_ACTIVE)
				my_sub.noise_level = 100
				playsound(src, 'sound/machines/submarine/sonar_ping2.ogg', 60, 1)
				if(sonar_channel)
					src << sound(null, channel = sonar_channel)
					sonar_channel = 0
			else
				my_sub.noise_level = my_sub.speed * 5
				if(!sonar_channel)
					var/sound/S = sound('sound/machines/submarine/sonar_passive.ogg', repeat = TRUE, wait = 0, volume = 40, channel = 770)
					sonar_channel = 770
					src << S
		else
			to_chat(usr, "<span class='notice'>Activate sonar first to change mode.</span>")

	if(href_list["select_contact"])
		// Match by ref first, then by name as fallback for stale refs
		var/datum/vessel_contact/target = locate(href_list["select_contact"]) in my_sub.detected_targets
		if(target)
			selected_contact = target
		else
			// Ref is stale from sensor sweep rebuild — find by name from the href
			var/target_name = href_list["select_contact_name"]
			if(target_name)
				for(var/datum/vessel_contact/C in my_sub.detected_targets)
					if(C.name == target_name)
						selected_contact = C
						break
			else
				selected_contact = null

	if(href_list["tag_contact"])
		var/datum/vessel_contact/target = locate(href_list["tag_contact"]) in my_sub.detected_targets
		if(!target)
			var/tag_name = href_list["tag_contact_name"]
			if(tag_name)
				for(var/datum/vessel_contact/C in my_sub.detected_targets)
					if(C.name == tag_name)
						target = C
						break
		if(target)
			if(target in my_sub.tagged_contacts)
				my_sub.tagged_contacts -= target
			else
				my_sub.tagged_contacts += target

	interact(usr)

// --- WEAPONS PANEL ---

/obj/structure/machinery/sub_control/weapons_panel
	name = "weapons control station"
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer-retro"
	scr_overlay = "targeting_peace"

/obj/structure/machinery/sub_control/weapons_panel/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - WEAPONS CONTROL"

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
				dat += "<a href='?src=\ref[src];select_target=\ref[C];select_target_name=[C.name]' class='btn btn-blue' style='font-size:9px;'>[C.name] ([round(C.range)]m)</a>"
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

	if(href_list["select_target"])
		my_sub.selected_target = locate(href_list["select_target"]) in my_sub.detected_targets
		if(!my_sub.selected_target)
			// Fallback: match by name
			var/target_name = href_list["select_target_name"]
			if(target_name)
				for(var/datum/vessel_contact/C in my_sub.detected_targets)
					if(C.name == target_name)
						my_sub.selected_target = C
						break

	if(href_list["clear_target"])
		my_sub.selected_target = null

	if(href_list["launch_torpedo"])
		var/tube_idx = text2num(href_list["launch_torpedo"])
		if(tube_idx >= 1 && tube_idx <= 4)
			if(my_sub.launch_torpedo(tube_idx))
				visible_message("<span class='warning'>TORPEDO LAUNCHED from tube [tube_idx]!</span>")
				playsound(src, 'sound/machines/submarine/torpedo_launch.ogg', 100, 1)
			else
				to_chat(usr, "<span class='warning'>Torpedo launch failed. Check master arm, tube status, and target lock.</span>")

	interact(usr)

// --- RADIO / MISSION CONSOLE ---

/obj/structure/machinery/sub_control/radio_console
	name = "encrypted radio console"
	desc = "A hardened military radio transceiver with frequency hopping and burst encryption."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "transponder"
	scr_overlay = "transponder-screen"
	window_size = "700x700"
	var/list/message_log = list()       // List of radio messages
	var/max_log_entries = 50

/obj/structure/machinery/sub_control/radio_console/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - RADIO & COMMS"

/obj/structure/machinery/sub_control/radio_console/New()
	..()
	// Register with the mission controller
	if(global.subcom_map && global.subcom_map.missions)
		global.subcom_map.missions.radio_console = src

/obj/structure/machinery/sub_control/radio_console/proc/add_log(var/message)
	message_log.Add("\[[world.time / 10]\] [message]")
	if(message_log.len > max_log_entries)
		message_log.Cut(1, 2)  // Remove oldest entry
	playsound(src, 'sound/machines/submarine/radio_static.ogg', 50, 1)

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
	dat += "</div>"

	return dat

/obj/structure/machinery/sub_control/radio_console/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["clear_log"])
		message_log.Cut()

	interact(usr)

// ============================================================
// Compartment Status Panel - ship-wide damage/flood monitor
// ============================================================

/obj/structure/machinery/sub_control/compartment_panel
	name = "compartment status panel"
	desc = "A ruggedized flat-panel display showing real-time compartment status across the submarine."
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer"
	scr_overlay = "comm_monitor"

/obj/structure/machinery/sub_control/compartment_panel/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - DAMAGE CONTROL"

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
				if(SUB_COMP_STORAGE) display_name = "STORAGE"
				if(SUB_COMP_OPERATIONS) display_name = "OPERATIONS"
				if(SUB_COMP_MEDICAL_BAY) display_name = "MEDICAL BAY"
				if(SUB_COMP_GALLEY) display_name = "GALLEY"
				if(SUB_COMP_CENTRAL_CORRIDOR) display_name = "CENTRAL CORRIDOR"
				if(SUB_COMP_REAR_CORRIDOR) display_name = "REAR CORRIDOR"
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
				if(SUB_COMP_STORAGE) comp_display = "STORAGE"
				if(SUB_COMP_OPERATIONS) comp_display = "OPERATIONS"
				if(SUB_COMP_MEDICAL_BAY) comp_display = "MEDICAL BAY"
				if(SUB_COMP_GALLEY) comp_display = "GALLEY"
				if(SUB_COMP_CENTRAL_CORRIDOR) comp_display = "CENTRAL CORRIDOR"
				if(SUB_COMP_REAR_CORRIDOR) comp_display = "REAR CORRIDOR"
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

// ============================================================
// OVERWORLD MAP DISPLAY - ASCII tactical map
// ============================================================

/obj/structure/machinery/sub_control/map_display
	name = "tactical map display"
	icon = 'icons/obj/computers.dmi'
	icon_state = "wallconsole"
	scr_overlay = "wallconsole_navigation"
	window_size = "700x750"
	var/map_range = 20000   // Meters displayed from center to edge (half-width)

/obj/structure/machinery/sub_control/map_display/vessel_name_header()
	return "[my_sub ? my_sub.vessel_name : "NO LINK"] - TACTICAL MAP"

/obj/structure/machinery/sub_control/map_display/get_ui_content()
	var/dat = ""
	var/map_size = 11        // Grid cells radius (11x11 grid = 23x23), smaller to fit in 700px window
	var/cell_px = 14         // pixels per cell
	var/grid_dim = map_size * 2 + 1
	// === STATUS BAR ===
	dat += "<div class='panel' style='padding:8px; margin-bottom:8px;'>"
	dat += "<div class='flex-between'>"
	dat += "<div class='label'>TACTICAL MAP</div>"
	dat += "<div style='color:#888;'>[my_sub.x_pos], [my_sub.y_pos] | HDG [round(my_sub.heading)]&deg;</div>"
	dat += "</div>"
	dat += "<div class='flex-row' style='gap:8px; margin-top:6px;'>"
	dat += "<a href='?src=\ref[src];range_up=1' class='btn btn-blue'>&#9650; ZOOM OUT</a>"
	dat += "<a href='?src=\ref[src];range_down=1' class='btn btn-blue'>&#9660; ZOOM IN</a>"
	dat += "<div style='color:#888;'>RANGE: [map_range / 1000]km</div>"
	dat += "</div>"
	dat += "</div>"



	dat += "<div class='panel crt-overlay' style='padding:10px;'>"
	dat += "<div style='background:#001a00; border:1px solid #0a0; padding:8px; position:relative;'>"

	// Compass labels
	dat += "<div style='text-align:center; font-size:9px; color:#0a0; margin-bottom:4px;'>N</div>"

	dat += "<div style='display:flex; align-items:center;'>"
	dat += "<div style='font-size:9px; color:#0a0; padding-right:4px;'>W</div>"

	// Grid
	dat += "<div style='position:relative; width:[grid_dim * cell_px]px; height:[grid_dim * cell_px]px; background:#000; border:1px solid #0a0;'>"

	// Draw grid lines (faint)
	for(var/i = 0; i <= grid_dim; i++)
		var/line_pos = i * cell_px
		dat += "<div style='position:absolute; left:0; right:0; top:[line_pos]px; height:1px; background:#0a200a;'></div>"
		dat += "<div style='position:absolute; top:0; bottom:0; left:[line_pos]px; width:1px; background:#0a200a;'></div>"

	// Draw tagged contacts from sonar/radar
	for(var/datum/vessel_contact/C in my_sub.tagged_contacts)
		if(QDELETED(C)) continue
		// Calculate position on grid using bearing and range
		var/rel_x = C.range * sin(C.bearing)  // sin gives east-west (bearing 90 = east)
		var/rel_y = C.range * cos(C.bearing)  // cos gives north-south (bearing 0 = north)
		var/cell_x = map_size + round(rel_x / map_range * map_size)
		var/cell_y = map_size - round(rel_y / map_range * map_size) // Y inverted (screen Y goes down)
		// Clamp to grid
		cell_x = max(0, min(grid_dim - 1, cell_x))
		cell_y = max(0, min(grid_dim - 1, cell_y))
		var/pix_x = cell_x * cell_px + cell_px / 2
		var/pix_y = cell_y * cell_px + cell_px / 2
		var/contact_color = "#0ff"
		if(C.contact_type == SUB_CONTACT_AIR)
			contact_color = "#f80"
		else if(C.contact_type == SUB_CONTACT_SURFACE)
			contact_color = "#0af"
		else if(C.nationality == SUB_NATION_HOSTILE)
			contact_color = "#f00"
		// Contact marker
		dat += "<div style='position:absolute; left:[pix_x - 4]px; top:[pix_y - 4]px; width:8px; height:8px; background:[contact_color]; border-radius:50%; box-shadow:0 0 6px [contact_color]; z-index:3;'></div>"
		// Label
		dat += "<div style='position:absolute; left:[pix_x + 6]px; top:[pix_y - 5]px; font-size:7px; color:[contact_color]; white-space:nowrap; z-index:3;'>[C.name]</div>"
		// Range/bearing label below
		dat += "<div style='position:absolute; left:[pix_x + 6]px; top:[pix_y + 3]px; font-size:6px; color:#888; white-space:nowrap; z-index:3;'>[round(C.range / 1000)]km [round(C.bearing)]&deg;</div>"

	// Draw detected but untagged contacts (faint blips)
	for(var/datum/vessel_contact/C in my_sub.detected_targets)
		if(C in my_sub.tagged_contacts) continue
		var/rel_x = C.range * sin(C.bearing)
		var/rel_y = C.range * cos(C.bearing)
		var/cell_x = map_size + round(rel_x / map_range * map_size)
		var/cell_y = map_size - round(rel_y / map_range * map_size)
		cell_x = max(0, min(grid_dim - 1, cell_x))
		cell_y = max(0, min(grid_dim - 1, cell_y))
		var/pix_x = cell_x * cell_px + cell_px / 2
		var/pix_y = cell_y * cell_px + cell_px / 2
		var/blip_color = C.contact_type == SUB_CONTACT_AIR ? "#840" : C.contact_type == SUB_CONTACT_SURFACE ? "#048" : "#080"
		dat += "<div style='position:absolute; left:[pix_x - 2]px; top:[pix_y - 2]px; width:4px; height:4px; background:[blip_color]; border-radius:50%; opacity:0.5; z-index:2;'></div>"

	// Player sub (center) with heading indicator
	var/center_px = map_size * cell_px + cell_px / 2
	var/heading_indicator_len = 12
	var/hdx = heading_indicator_len * sin(my_sub.heading)
	var/hdy = -heading_indicator_len * cos(my_sub.heading) // negative because screen Y is inverted
	dat += "<div style='position:absolute; left:[center_px - 4]px; top:[center_px - 4]px; width:8px; height:8px; background:#fff; border:2px solid #0f0; border-radius:50%; box-shadow:0 0 8px #0f0; z-index:5;'></div>"
	dat += "<div style='position:absolute; left:[center_px + hdx - 1]px; top:[center_px + hdy - 1]px; width:2px; height:2px; background:#0f0; z-index:5;'></div>"
	dat += "<div style='position:absolute; left:[center_px + 10]px; top:[center_px - 5]px; font-size:8px; color:#0f0; font-weight:bold; z-index:5;'>YOU</div>"

	// Grid scale indicator
	var/scale_km = map_range / map_size / 1000
	var/scale_cells = max(1, round(5 / scale_km))
	dat += "<div style='position:absolute; right:4px; bottom:4px; font-size:7px; color:#0a0; z-index:3;'>"
	dat += "[scale_km * scale_cells]km"
	dat += "</div>"

	dat += "</div>" // end grid

	dat += "<div style='text-align:center; font-size:9px; color:#0a0; margin-top:4px;'>S</div>"
	dat += "<div style='text-align:right; font-size:9px; color:#0a0; margin-top:-10px; margin-right:-12px;'>E</div>"

	dat += "</div>" // end crt-overlay panel

	// === LEGEND ===
	dat += "<div class='panel' style='padding:8px; margin-top:8px;'>"
	dat += "<div class='label'>LEGEND</div>"
	dat += "<div class='flex-row' style='gap:12px; margin-top:6px; font-size:10px;'>"
	dat += "<div><span style='display:inline-block; width:8px; height:8px; background:#fff; border:2px solid #0f0; border-radius:50%; vertical-align:middle;'></span> Player Sub</div>"
	dat += "<div><span style='display:inline-block; width:8px; height:8px; background:#0ff; border-radius:50%; vertical-align:middle;'></span> Tagged Contact</div>"
	dat += "<div><span style='display:inline-block; width:6px; height:6px; background:#f00; border-radius:50%; vertical-align:middle;'></span> Hostile</div>"
	dat += "<div><span style='display:inline-block; width:6px; height:6px; background:#0af; border-radius:50%; vertical-align:middle;'></span> Surface</div>"
	dat += "<div><span style='display:inline-block; width:6px; height:6px; background:#f80; border-radius:50%; vertical-align:middle;'></span> Air</div>"
	dat += "<div><span style='display:inline-block; width:4px; height:4px; background:#080; border-radius:50%; vertical-align:middle; opacity:0.5;'></span> Untagged</div>"
	dat += "</div>"
	dat += "</div>"

	return dat

/obj/structure/machinery/sub_control/map_display/Topic(href, href_list)
	if(..()) return 1
	if(!can_use(usr)) return

	if(href_list["range_up"])
		map_range = min(200000, map_range * 2)

	if(href_list["range_down"])
		map_range = max(2500, map_range / 2)

	interact(usr)

// ============================================================
// IN-GAME BOOK: Sonar Operator's Manual
// ============================================================

/obj/item/weapon/book/subcom_sonar_manual
	name = "Sonar Operator's Manual"
	icon = 'icons/obj/library.dmi'
	icon_state = "book"
	author = "US Navy Submarine Command"
	title = "Sonar Operator's Manual"
	unique = TRUE

	dat = {"<html>
			<head>
			<style>
			body {font-family: Verdana, sans-serif; font-size: 12px; background-color: #f0f8ff; padding: 15px;}
			h1 {font-size: 18px; color: #003366; border-bottom: 2px solid #003366; padding-bottom: 5px;}
			h2 {font-size: 14px; color: #004488; margin-top: 15px;}
			h3 {font-size: 12px; color: #006699; margin-top: 10px;}
			li {margin: 3px 0px 3px 15px;}
			ul {margin: 5px; padding: 0px;}
			table {border-collapse: collapse; margin: 10px 0; width: 100%;}
			th, td {border: 1px solid #003366; padding: 4px 8px; text-align: left; font-size: 11px;}
			th {background-color: #003366; color: white;}
			.note {background-color: #ffeecc; border-left: 3px solid #ff9900; padding: 8px; margin: 10px 0; font-size: 11px;}
			.warning {background-color: #ffcccc; border-left: 3px solid #cc0000; padding: 8px; margin: 10px 0; font-size: 11px;}
			code {background-color: #e0e0e0; padding: 1px 3px; font-size: 11px;}
			</style>
			</head>
			<body>

			<h1>SONAR OPERATOR'S MANUAL</h1>
			<p><i>Classification: UNCLASSIFIED // For training purposes</i></p>

			<h2>1. SONAR MODES</h2>

			<h3>Passive Sonar</h3>
			<ul>
			<li>LISTENS only. Does not emit sound. <b>Stealth.</b></li>
			<li>Detects submerged contacts by their acoustic signature.</li>
			<li>Detection range: ~20,000m (varies with target noise and ocean conditions).</li>
			<li>Cannot detect surface vessels or aircraft (they make no underwater sound).</li>
			<li>Power draw: 50 kW.</li>
			</ul>

			<h3>Active Sonar</h3>
			<ul>
			<li>EMITS sound pulses (pings). Detects everything.</li>
			<li>Detection range: ~50,000m.</li>
			<li><b class="warning">WARNING: Active sonar makes your submarine extremely loud (noise level 100). Enemy submarines will detect you from far away.</b></li>
			<li>Power draw: 200 kW.</li>
			</ul>

			<h2>2. BEARING SWEEP</h2>
			<p>The bearing sweep display rotates continuously, showing detected contacts as blips on a 360-degree compass. The sweep line indicates the current bearing being scanned.</p>
			<ul>
			<li><b>Green blips:</b> Standard contacts (untagged).</li>
			<li><b>Cyan blips:</b> Selected/highlighted contacts.</li>
			<li>Click a contact in the list to select it for LOFAR analysis.</li>
			</ul>

			<h2>3. LOFAR SPECTRAL ANALYSIS</h2>
			<p>Low Frequency Analysis and Recording (LOFAR) identifies vessels by their acoustic tonals. Every ship has a unique sound signature based on its machinery.</p>

			<h3>The Three Tonals</h3>
			<table>
			<tr><th>Band</th><th>Frequency</th><th>Source</th><th>What It Tells You</th></tr>
			<tr><td><b>LOW</b> (green)</td><td>10-500 Hz</td><td>Propeller blade rate</td><td>Number of blades, RPM. Larger props = lower frequency.</td></tr>
			<tr><td><b>MID</b> (yellow)</td><td>500-900 Hz</td><td>Main engines</td><td>Engine type, power output. Diesel vs nuclear have different ranges.</td></tr>
			<tr><td><b>HIGH</b> (orange)</td><td>1000-2000 Hz</td><td>Auxiliary machinery</td><td>Pumps, generators, HVAC. Unique per vessel class.</td></tr>
			</table>

			<div class="note"><b>Tip:</b> Select a contact by clicking it in the contact list. The LOFAR display will show its three tonals and the classification.</div>

			<h2>4. SHIP IDENTIFICATION DATABASE</h2>

			<h3>Surface Combatants</h3>
			<table>
			<tr><th>Vessel</th><th>LOW (Hz)</th><th>MID (Hz)</th><th>HIGH (Hz)</th><th>Notes</th></tr>
			<tr><td>Perry FFG</td><td>170</td><td>840</td><td>1890</td><td>ASW frigate. Loud auxiliaries.</td></tr>
			<tr><td>Kirov CGN</td><td>120</td><td>490</td><td>920</td><td>Nuclear cruiser. Very low prop rate (huge blades).</td></tr>
			<tr><td>Krivak FFG</td><td>240</td><td>930</td><td>1520</td><td>Patrol frigate. Distinctive mid-range.</td></tr>
			<tr><td>Nanuchka CVS</td><td>210</td><td>760</td><td>1650</td><td>Light corvette. Fast, agile.</td></tr>
			<tr><td>Grisha MPK</td><td>190</td><td>680</td><td>1440</td><td>ASW patrol boat. Small but dangerous.</td></tr>
			</table>

			<h3>Merchant Vessels</h3>
			<table>
			<tr><th>Vessel</th><th>LOW (Hz)</th><th>MID (Hz)</th><th>HIGH (Hz)</th><th>Notes</th></tr>
			<tr><td>Bulk Freighter</td><td>170</td><td>840</td><td>1890</td><td>Large, slow, loud. Easy to detect.</td></tr>
			<tr><td>Fleet Tanker</td><td>130</td><td>620</td><td>1350</td><td>Very slow. High noise threshold (hard to hear).</td></tr>
			</table>

			<h3>Submarines</h3>
			<table>
			<tr><th>Vessel</th><th>LOW (Hz)</th><th>MID (Hz)</th><th>HIGH (Hz)</th><th>Notes</th></tr>
			<tr><td>Kilo SSK</td><td>380</td><td>720</td><td>1200</td><td>Diesel-electric. Very quiet when running on battery.</td></tr>
			<tr><td>Akula SSN</td><td>140</td><td>350</td><td>880</td><td>Nuclear attack sub. Extremely quiet. High threat.</td></tr>
			<tr><td>Delta III SSBN</td><td>150</td><td>380</td><td>950</td><td>Nuclear ballistic sub. Carries SLBMs. Heavy escort expected.</td></tr>
			</table>

			<h3>Aircraft (Active Sonar Only)</h3>
			<table>
			<tr><th>Aircraft</th><th>Notes</th></tr>
			<tr><td>Tu-22M Backfire</td><td>Bomber. Carries ASMs. Very dangerous. Low radar cross-section.</td></tr>
			<tr><td>Su-24 Fencer</td><td>Attack aircraft. Carries ASMs and bombs.</td></tr>
			<tr><td>Il-38 May</td><td>Maritime patrol. Carries depth charges and torpedoes. Has MAD (magnetic anomaly detector).</td></tr>
			</table>

			<div class="note"><b>Tip:</b> Nuclear submarines have lower prop rates (larger blades) than diesel boats. If you see LOW tonal below 200 Hz, it's likely nuclear-powered.</div>

			<h2>5. TACTICAL MAP</h2>
			<p>The tactical map display shows your position and all tagged contacts on a grid. Use the TAG button on the sonar or radar contact list to mark contacts for display.</p>
			<ul>
			<li><b>White circle:</b> Your submarine (center).</li>
			<li><b>Cyan markers:</b> Tagged contacts with name, range, and bearing labels.</li>
			<li><b>Faint blips:</b> Detected but untagged contacts.</li>
			<li>Use ZOOM IN/OUT to adjust the display range (2.5km to 200km).</li>
			</ul>

			<h3>Map Legend</h3>
			<table>
			<tr><th>Symbol</th><th>Meaning</th></tr>
			<tr><td><span style="color:#0f0;">&#9679;</span> White with green border</td><td>Your submarine</td></tr>
			<tr><td><span style="color:#0ff;">&#9679;</span> Cyan</td><td>Tagged contact</td></tr>
			<tr><td><span style="color:#f00;">&#9679;</span> Red</td><td>Hostile contact</td></tr>
			<tr><td><span style="color:#0af;">&#9679;</span> Blue</td><td>Surface contact</td></tr>
			<tr><td><span style="color:#f80;">&#9679;</span> Orange</td><td>Air contact</td></tr>
			<tr><td><span style="color:#080;">&#9679;</span> Faint green</td><td>Untagged contact</td></tr>
			</table>

			<h2>6. OPERATIONAL PROCEDURES</h2>

			<h3>Startup Sequence</h3>
			<ol>
			<li>Power ON the sonar system.</li>
			<li>Select PASSIVE mode (recommended for stealth).</li>
			<li>Wait for bearing sweep to complete full rotation.</li>
			<li>Review detected contacts in the contact list.</li>
			<li>Click contacts to view LOFAR analysis and identify.</li>
			<li>TAG important contacts for the tactical map.</li>
			</ol>

			<h3>When to Use Active Sonar</h3>
			<ul>
			<li>When you need to find a specific target at long range.</li>
			<li>When you are not concerned about stealth (e.g., during combat).</li>
			<li>When you suspect a submarine is nearby but passive cannot locate it.</li>
			</ul>

			<div class="warning"><b>Remember:</b> Active sonar is a double-edged sword. You will find them, but they will also find YOU. Use sparingly.</div>

			<h3>Noise Discipline</h3>
			<ul>
			<li>Your noise level increases with speed. Slow down to reduce detection.</li>
			<li>Active sonar sets noise to 100. Passive sonar noise = speed * 5.</li>
			<li>Enemy passive detection threshold varies by vessel type (8-50).</li>
			</ul>

			</body>
			</html>"}
