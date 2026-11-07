// Factory monitor (phase 4b of docs/factory-automation-design.md): a terminal
// that lists the arms, fabricators, belt drives and belts within its range,
// with each machine's state, items per minute and power draw. Counters are runtime only
// and cost one addition per moved item; nothing is scanned until someone looks.

#define FACTORY_RATE_BUCKET 600 // deciseconds per counting bucket (one minute)
#define FACTORY_MONITOR_RANGE 7

// Items counted over the current minute and the one before it.
/datum/factory_rate
	var/start = 0
	var/current = 0
	var/previous = 0
	var/has_previous = FALSE

/datum/factory_rate/New()
	start = world.time

/datum/factory_rate/proc/advance()
	var/elapsed = world.time - start
	if (elapsed < FACTORY_RATE_BUCKET)
		return
	if (elapsed < FACTORY_RATE_BUCKET * 2)
		previous = current
		start += FACTORY_RATE_BUCKET
	else
		previous = 0
		start = world.time
	current = 0
	has_previous = TRUE

/datum/factory_rate/proc/add(amount)
	advance()
	current += amount

// Items per minute over up to the last two minutes.
/datum/factory_rate/proc/per_minute()
	advance()
	var/window = (world.time - start) + (has_previous ? FACTORY_RATE_BUCKET : 0)
	if (window <= 0)
		return current
	return round((current + previous) * FACTORY_RATE_BUCKET / window, 0.1)

/proc/factory_rate_add(datum/D, var_name, amount)
	var/datum/factory_rate/R = D.vars[var_name]
	if (!R)
		R = new
		D.vars[var_name] = R
	R.add(amount)

/proc/factory_rate_of(datum/factory_rate/R)
	return R ? R.per_minute() : 0

/obj/structure/factory_monitor
	name = "factory monitor"
	desc = "A terminal wired to the machines around it. It shows what each arm, fabricator and belt drive within seven tiles is doing, how many items it moves or makes a minute, and how much power it draws."
	icon = 'icons/obj/computers.dmi'
	icon_state = "terminal"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

// Power units a machine has reserved on its grid right now.
/proc/factory_power_draw(obj/O)
	if (!O || !O.powersource)
		return 0
	var/reserved = O.powersource.power_consumers[O]
	return isnum(reserved) ? reserved : 0

// One row per machine: list(name, kind, x, y, state, rate, detail, power).
/obj/structure/factory_monitor/proc/report_rows()
	var/list/rows = list()
	var/belts = 0
	var/carrying = 0
	var/waiting = 0
	var/turf/here = get_turf(src)
	if (!here)
		return rows
	for (var/obj/O in range(FACTORY_MONITOR_RANGE, here))
		if (istype(O, /obj/structure/factory_arm))
			var/obj/structure/factory_arm/A = O
			var/state = A.on ? (A.arm_status == "off" ? "starting" : A.arm_status) : "off"
			rows[++rows.len] = list(A.name, "arm", A.x, A.y, state, factory_rate_of(A.move_rate), A.filter_type ? "only [factory_filter_name(A.filter_type)]" : "", factory_power_draw(A))
		else if (istype(O, /obj/structure/factory_fabricator))
			var/obj/structure/factory_fabricator/F = O
			var/state = F.recipe_name ? F.fab_status : "no recipe"
			var/detail = ""
			var/datum/factory_recipe/R = F.current_recipe()
			if (R)
				detail = "[F.recipe_name], [round(100 * F.progress / F.cycle_time(R))]%"
			rows[++rows.len] = list(F.name, "fabricator", F.x, F.y, state, factory_rate_of(F.output_rate), detail, factory_power_draw(F))
		else if (istype(O, /obj/structure/factory_drive))
			var/obj/structure/factory_drive/D = O
			rows[++rows.len] = list(D.name, "drive", D.x, D.y, D.on ? (D.powered ? "running" : "no power") : "off", 0, "range [D.drive_range]", factory_power_draw(D))
		else if (istype(O, /obj/structure/factory_belt))
			var/obj/structure/factory_belt/B = O
			belts++
			var/loaded = FALSE
			for (var/obj/item/I in B.cargo)
				loaded = TRUE
				break
			if (loaded)
				carrying++
				if (B.next_poll > factory_belt_tick)
					waiting++
	if (belts)
		rows[++rows.len] = list("belts", "belts", null, null, waiting ? "[waiting] blocked" : (carrying ? "running" : "idle"), 0, "[belts] belts, [carrying] carrying items", 0)
	return rows

// Power for the listed machines: list(total PU drawn, list(list(used, capacity)) per grid).
// A grid's use covers everything on it, not only the machines listed here.
/obj/structure/factory_monitor/proc/power_summary(list/rows)
	var/total = 0
	for (var/list/row in rows)
		total += row[8]
	var/list/grids = list()
	var/turf/here = get_turf(src)
	if (here)
		for (var/obj/O in range(FACTORY_MONITOR_RANGE, here))
			if (!O.powersource || !(istype(O, /obj/structure/factory_arm) || istype(O, /obj/structure/factory_fabricator) || istype(O, /obj/structure/factory_drive)))
				continue
			var/obj/structure/cable/C = O.powersource
			var/key = "[C.component_id ? C.component_id : C.grid_identity()]"
			if (!grids[key])
				grids[key] = list(C.currentflow, C.powerflow)
	var/list/grid_list = list()
	for (var/key in grids)
		grid_list[++grid_list.len] = grids[key]
	return list(total, grid_list)

/obj/structure/factory_monitor/proc/report_html()
	var/list/rows = report_rows()
	var/list/out = list("<h3>[html_encode(name)]</h3>")
	if (!rows.len)
		out += "<p>No factory machines within [FACTORY_MONITOR_RANGE] tiles.</p>"
		return out.Join()
	out += "<table border=1 cellpadding=3><tr><th>Machine</th><th>Where</th><th>State</th><th>Items/min</th><th>Power (PU)</th><th>Notes</th></tr>"
	for (var/list/row in rows)
		var/where = isnull(row[3]) ? "" : "[row[3] - x], [row[4] - y]"
		var/state = row[5]
		var/colour = (state == "running") ? "#3a3" : ((state in list("off", "idle", "waiting")) ? "#888" : "#c33")
		out += "<tr><td>[html_encode(row[1])]</td><td>[where]</td><td><font color='[colour]'>[html_encode(state)]</font></td><td>[row[6]]</td><td>[row[8]]</td><td>[html_encode(row[7])]</td></tr>"
	out += "</table>"
	var/list/power = power_summary(rows)
	out += "<p>These machines draw [power[1]] PU.</p>"
	var/list/grids = power[2]
	for (var/list/grid in grids)
		var/used = grid[1]
		var/capacity = grid[2]
		var/colour = (capacity <= 0 || used > capacity) ? "#c33" : (used >= capacity * 0.9 ? "#c90" : "#3a3")
		out += "<p>Power grid: <font color='[colour]'>[used] of [capacity] PU in use</font>.</p>"
	out += "<p>Where is east, north of this monitor. Rates cover the last two minutes. A grid's use counts everything on it.</p>"
	return out.Join()

/obj/structure/factory_monitor/attack_hand(mob/user)
	if (!istype(user) || !user.Adjacent(src))
		return
	icon_state = "terminal_on"
	user << browse(report_html(), "window=factory_monitor;size=620x520")
	spawn(50)
		if (!QDELETED(src))
			icon_state = "terminal"

#undef FACTORY_RATE_BUCKET
#undef FACTORY_MONITOR_RANGE
