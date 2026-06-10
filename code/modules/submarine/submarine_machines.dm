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
	return TRUE

/obj/structure/machinery/sub_control/attack_hand(mob/user)
	interact(user)

/obj/structure/machinery/sub_control/interact(mob/user)
	if(!can_use(user))
		user << browse(null, "window=sub_control")
		return
	
	var/dat = "<html><head><style>"
	dat += "body { background-color: #333333; color: #00ff00; font-family: 'Courier New', monospace; padding: 10px; }"
	dat += "table { border: 1px solid #444; width: 100%; border-collapse: collapse; margin-bottom: 10px; }"
	dat += "th, td { border: 1px solid #444; padding: 5px; text-align: left; }"
	dat += "a { color: #ffffff; text-decoration: none; border: 1px solid #00ff00; padding: 2px 5px; background: #222; }"
	dat += "a:hover { background: #00ff00; color: #000; }"
	dat += ".warning { color: #ff0000; font-weight: bold; }"
	dat += ".header { font-size: 1.2em; border-bottom: 2px solid #00ff00; margin-bottom: 10px; }"
	dat += "</style></head><body>"
	dat += "<div class='header'>[vessel_name_header()]</div>"
	
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
	var/dat = "<table>"
	dat += "<tr><td>HEADING</td><td>[my_sub.heading]&deg;</td><td>TARGET: [my_sub.target_heading]&deg;</td></tr>"
	dat += "<tr><td>SPEED</td><td>[my_sub.speed] KTS</td><td>TARGET: [my_sub.target_speed] KTS</td></tr>"
	dat += "<tr><td>DEPTH</td><td>[my_sub.depth] M</td><td>TARGET: [my_sub.target_depth] M</td></tr>"
	dat += "</table>"

	dat += "<b>SET TARGET HEADING:</b><br>"
	dat += "<a href='?src=\ref[src];adj_hd=-45'>-45</a> <a href='?src=\ref[src];adj_hd=-10'>-10</a> <a href='?src=\ref[src];adj_hd=-5'>-5</a> "
	dat += "<a href='?src=\ref[src];adj_hd=5'>+5</a> <a href='?src=\ref[src];adj_hd=10'>+10</a> <a href='?src=\ref[src];adj_hd=45'>+45</a><br><br>"

	dat += "<b>SET TARGET SPEED:</b><br>"
	dat += "<a href='?src=\ref[src];adj_sp=-10'>-10</a> <a href='?src=\ref[src];adj_sp=-5'>-5</a> <a href='?src=\ref[src];adj_sp=-1'>-1</a> "
	dat += "<a href='?src=\ref[src];adj_sp=1'>+1</a> <a href='?src=\ref[src];adj_sp=5'>+5</a> <a href='?src=\ref[src];adj_sp=10'>+10</a><br><br>"

	dat += "<b>SET TARGET DEPTH:</b><br>"
	dat += "<a href='?src=\ref[src];set_dp=0'>SURFACE (0m)</a> "
	dat += "<a href='?src=\ref[src];set_dp=15'>PERISCOPE (15m)</a><br>"
	dat += "<a href='?src=\ref[src];set_dp=150'>DEEP (150m)</a> "
	dat += "<a href='?src=\ref[src];set_dp=250'>CRASH DIVE (250m)</a><br><br>"

	dat += "<a href='?src=\ref[src];blow_ballast=1' class='warning'>EMERGENCY BLOW BALLAST</a>"
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
	var/dat = ""
	for(var/i=1, i<=2, i++)
		dat += "<b>REACTOR [i]</b> [my_sub.r_scrammed[i] ? "<span class='warning'>(SCRAMMED)</span>" : ""]<br>"
		dat += "<table>"
		dat += "<tr><td>CORE TEMP</td><td colspan='2'>[my_sub.r_core_temp[i]]&deg;C</td></tr>"
		dat += "<tr><td>OUTPUT</td><td colspan='2'>[my_sub.r_power_output[i]] MW</td></tr>"
		dat += "<tr><td>PUMPS</td><td>PRI: [my_sub.r_primary_pump_speed[i]] RPM</td><td>SEC: [my_sub.r_secondary_pump_speed[i]] RPM</td></tr>"
		dat += "</table>"
		
		dat += "RODS: <a href='?src=\ref[src];r=[i];rods=0'>0%</a> <a href='?src=\ref[src];r=[i];rods=25'>25%</a> <a href='?src=\ref[src];r=[i];rods=50'>50%</a> <a href='?src=\ref[src];r=[i];rods=75'>75%</a> <a href='?src=\ref[src];r=[i];rods=100'>100%</a><br>"
		dat += "PRI PUMP: <a href='?src=\ref[src];r=[i];pri=-1'>-</a> <a href='?src=\ref[src];r=[i];pri=1'>+</a> | SEC PUMP: <a href='?src=\ref[src];r=[i];sec=-1'>-</a> <a href='?src=\ref[src];r=[i];sec=1'>+</a><br>"
		dat += "<a href='?src=\ref[src];r=[i];scram=1' class='warning'>SCRAM REACTOR [i]</a><hr>"
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
	icon_state = "computer_middle"
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
	var/dat = "<b>ATMOSPHERIC SYSTEMS</b><br>"
	dat += "O2 GEN: [my_sub.electrolysis_active ? "ACTIVE" : "OFF"] <a href='?src=\ref[src];toggle_o2=1'>TOGGLE</a><br>"
	dat += "BATTERY: [my_sub.battery_current] / [my_sub.battery_max] kWh<br><br>"
	
	dat += "<table><tr><th>COMPARTMENT</th><th>VENT</th><th>FSS</th></tr>"
	for(var/C in compartments)
		dat += "<tr>"
		dat += "<td>[C]</td>"
		dat += "<td><a href='?src=\ref[src];vent=[C]'>[vents_open[C] ? "OPEN" : "CLOSED"]</a></td>"
		dat += "<td><a href='?src=\ref[src];fss=[C]'>[fire_supp_active[C] ? "<span class='warning'>ON</span>" : "OFF"]</a></td>"
		dat += "</tr>"
	dat += "</table>"
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
	var/dat = "<b>RADAR SYSTEMS</b><br>"
	dat += "STATUS: [my_sub.radar_active ? "ACTIVE" : "INACTIVE"] "
	dat += "<a href='?src=\ref[src];toggle_power=1'>TOGGLE POWER</a><br>"
	dat += "RANGE: [my_sub.radar_range_long ? "LONG ([SUB_RADAR_RANGE_LONG]m)" : "SHORT ([SUB_RADAR_RANGE_SHORT]m)"] "
	dat += "<a href='?src=\ref[src];toggle_range=1'>TOGGLE RANGE</a><br>"
	dat += "POWER DRAW: [my_sub.radar_active ? (my_sub.radar_range_long ? SUB_RADAR_POWER_LONG : SUB_RADAR_POWER_SHORT) : 0] kW<br>"
	dat += "SUBMERGED: [my_sub.depth > 0 ? "<span class='warning'>RADAR INOPERATIVE</span>" : "OPERATIONAL"]<br><br>"

	dat += "<b>DETECTED CONTACTS:</b><br>"
	if(my_sub.detected_targets.len)
		dat += "<table><tr><th>NAME</th><th>RANGE</th><th>BEARING</th></tr>"
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			if(C.contact_type == SUB_CONTACT_SURFACE || C.contact_type == SUB_CONTACT_AIR)
				dat += "<tr><td>[C.name]</td><td>[round(C.range)]m</td><td>[round(C.bearing)]&deg;</td></tr>"
		dat += "</table>"
	else
		dat += "<i>No contacts detected.</i><br>"
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
	var/dat = "<b>SONAR SYSTEMS</b><br>"
	dat += "STATUS: [my_sub.sonar_active ? "ACTIVE" : "INACTIVE"] "
	dat += "<a href='?src=\ref[src];toggle_power=1'>TOGGLE POWER</a><br>"
	dat += "MODE: [my_sub.sonar_mode == SUB_SONAR_ACTIVE ? "<span class='warning'>ACTIVE (HIGH EMISSION)</span>" : "PASSIVE (STEALTH)"] "
	dat += "<a href='?src=\ref[src];toggle_mode=1'>TOGGLE MODE</a><br>"
	dat += "POWER DRAW: [my_sub.sonar_active ? (my_sub.sonar_mode == SUB_SONAR_ACTIVE ? SUB_SONAR_POWER_ACTIVE : SUB_SONAR_POWER_PASSIVE) : 0] kW<br>"
	dat += "OWN NOISE: [my_sub.noise_level]<br><br>"

	dat += "<b>LOFAR ANALYSIS:</b><br>"
	dat += "<i>(Simulated frequency lines and acoustic database comparison)</i><br>"
	dat += "----------------------------------------<br>"
	dat += "SIGNAL 1: 250Hz - Propeller Cavitation (Possible Destroyer)<br>"
	dat += "SIGNAL 2: 120Hz - Engine Harmonics (Possible Merchant Vessel)<br>"
	dat += "----------------------------------------<br><br>"

	dat += "<b>DETECTED CONTACTS:</b><br>"
	if(my_sub.detected_targets.len)
		dat += "<table><tr><th>NAME</th><th>RANGE</th><th>BEARING</th><th>NOISE</th></tr>"
		for(var/datum/vessel_contact/C in my_sub.detected_targets)
			if(C.contact_type == SUB_CONTACT_SUBMERGED)
				dat += "<tr><td>[C.name]</td><td>[round(C.range)]m</td><td>[round(C.bearing)]&deg;</td><td>[C.noise_signature]</td></tr>"
		dat += "</table>"
	else
		dat += "<i>No contacts detected.</i><br>"
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
	var/dat = "<b>WEAPONS SYSTEMS</b><br>"
	dat += "MASTER ARM: [my_sub.master_arm ? "<span class='warning'>ARMED</span>" : "DISARMED"] "
	dat += "<a href='?src=\ref[src];toggle_master_arm=1'>TOGGLE MASTER ARM</a><br><br>"

	dat += "<b>TORPEDO TUBES:</b><br>"
	dat += "<table><tr><th>TUBE</th><th>STATUS</th><th>ACTION</th></tr>"
	for(var/i=1, i<=4, i++)
		dat += "<tr><td>[i]</td><td>[my_sub.tubes_loaded[i] ? "LOADED" : "EMPTY"]</td>"
		dat += "<td><a href='?src=\ref[src];load_tube=[i]'>[my_sub.tubes_loaded[i] ? "UNLOAD" : "LOAD"]</a></td></tr>"
	dat += "</table><br>"

	dat += "<b>TARGETING:</b><br>"
	if(my_sub.selected_target)
		dat += "SELECTED: [my_sub.selected_target.name] (R: [round(my_sub.selected_target.range)]m, B: [round(my_sub.selected_target.bearing)]&deg;)<br>"
		dat += "<a href='?src=\ref[src];clear_target=1'>CLEAR TARGET</a><br><br>"
		for(var/i=1, i<=4, i++)
			if(my_sub.tubes_loaded[i])
				dat += "<a href='?src=\ref[src];launch_torpedo=[i]' class='warning'>LAUNCH TORPEDO (TUBE [i])</a><br>"
	else
		dat += "<i>No target selected.</i><br>"
		if(my_sub.detected_targets.len)
			dat += "SELECT FROM:<br>"
			for(var/datum/vessel_contact/C in my_sub.detected_targets)
				dat += "<a href='?src=\ref[src];select_target=\ref[C]'>[C.name] ([round(C.range)]m, [round(C.bearing)]&deg;)</a><br>"
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
