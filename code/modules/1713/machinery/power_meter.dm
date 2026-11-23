// Power units shown to players, and the power meter.
//
// Grid numbers stay abstract power units (PU) in code. Players see one PU as
// one kilowatt, and stored PU seconds as watt-hours (3600 PU s = 1 kWh).

/proc/power_text(pu)
	if (abs(pu) >= 1000)
		return "[round(pu / 1000, 0.01)] MW"
	return "[round(pu, 0.1)] kW"

/proc/energy_text(pu_seconds)
	var/kwh = pu_seconds / 3600
	if (abs(kwh) >= 1000)
		return "[round(kwh / 1000, 0.01)] MWh"
	if (abs(kwh) >= 1)
		return "[round(kwh, 0.01)] kWh"
	return "[round(kwh * 1000, 1)] Wh"

// ---------------------------------------------------------------- meter

#define POWER_METER_LIMIT 64
#define POWER_METER_SAMPLES 60 // one a second: the last minute

var/global/list/power_meters = list()

// A panel meter secured on a cable. Once a second it copies the grid's
// published supply, service and active refusals (no grid traversal), and shows the last minute as
// a graph to whoever has it open.
/obj/structure/power_meter
	name = "power meter"
	desc = "A panel of dials and a chart recorder for a cable grid. Secure it on a cable with a wrench, then read it."
	icon = 'icons/obj/computers.dmi'
	icon_state = "terminal"
	anchored = FALSE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	flammable = FALSE
	var/tmp/list/supply_log = list()
	var/tmp/list/demand_log = list() // requested (served + current refusals)
	var/tmp/list/served_log = list()
	var/tmp/shortage_grid = 0
	var/tmp/shortage_since = -1
	var/tmp/shortage_announced = FALSE
	var/tmp/list/readers = list()
	var/tmp/registered = FALSE

/obj/structure/power_meter/New()
	..()
	if (power_meters.len < POWER_METER_LIMIT)
		power_meters |= src
		registered = TRUE

/obj/structure/power_meter/on_runtime_spawn()
	..()
	if (cable_autolink_holds)
		cable_autolink_queue += src

/obj/structure/power_meter/Destroy()
	detach_cable()
	power_meters -= src
	registered = FALSE
	readers.Cut()
	return ..()

/obj/structure/power_meter/persistence_runtime_var(key)
	return (key in list("supply_log", "demand_log", "served_log", "shortage_grid", "shortage_since", "shortage_announced", "readers", "registered")) || ..()

/obj/structure/power_meter/proc/in_service()
	return registered && anchored && isturf(loc) && powersource && isturf(powersource.loc) && powersource.loc == loc && (src in powersource.connections)

/obj/structure/power_meter/update_icon()
	icon_state = in_service() ? "terminal_on" : "terminal"

/obj/structure/power_meter/proc/attach_cable()
	if (!anchored || !isturf(loc))
		return FALSE
	if (!powersource)
		var/obj/structure/cable/C = locate(/obj/structure/cable) in loc
		if (!C)
			return FALSE
		powersource = C
	powersource.connections |= src
	update_icon()
	return TRUE

/obj/structure/power_meter/proc/detach_cable()
	if (powersource)
		powersource.connections -= src
		powersource = null
	supply_log.Cut()
	demand_log.Cut()
	served_log.Cut()
	shortage_alarm(world.time, 0, 0)
	update_icon()

/obj/structure/power_meter/after_load()
	..()
	if (anchored && isturf(loc))
		powersource = restored_port_cable(src)
	update_icon()

/obj/structure/power_meter/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		detach_cable()
		anchored = FALSE

/obj/structure/power_meter/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous)
		detach_cable()
		anchored = FALSE

// A short, one-off refusal is shown but cannot trigger the audible warning.
// Each connected meter warns once after five seconds, then rearms at recovery
// or when it starts monitoring a different component.
/obj/structure/power_meter/proc/shortage_alarm(now, shed, network)
	if (!network || shortage_grid != network || shed <= 0)
		shortage_grid = network
		shortage_since = -1
		shortage_announced = FALSE
	if (!network || shed <= 0)
		return FALSE
	if (shortage_since < 0)
		shortage_since = now
	if (shortage_announced || now - shortage_since < 50)
		return FALSE
	shortage_announced = TRUE
	return TRUE

// Called once a second by the civ_generation process.
/obj/structure/power_meter/proc/sample()
	var/supply = 0
	var/served = 0
	var/shed = 0
	var/network = 0
	if (in_service())
		supply = max(0, powersource.powerflow)
		served = max(0, powersource.currentflow)
		shed = powersource.grid_shortage(world.time)
		network = powersource.component_id
	else if (!supply_log.len)
		shortage_alarm(world.time, 0, 0)
		return
	if (shortage_alarm(world.time, shed, network))
		playsound(src, 'sound/machines/computer/beep.ogg', 35, FALSE)
		for (var/mob/M in hearers(3, src))
			to_chat(M, SPAN_WARNING("The power meter sounds a sustained shortage alarm."))
	supply_log += supply
	demand_log += served + shed
	served_log += served
	if (supply_log.len > POWER_METER_SAMPLES)
		supply_log.Cut(1, 2)
	if (demand_log.len > POWER_METER_SAMPLES)
		demand_log.Cut(1, 2)
	if (served_log.len > POWER_METER_SAMPLES)
		served_log.Cut(1, 2)
	if (readers.len)
		for (var/mob/M in readers.Copy())
			// A reader who closed the window or walked away stops being refreshed.
			if (!GLOB.nanomanager.get_open_ui(M, src, "main"))
				readers -= M
				continue
			if (!M.client || get_dist(M, src) > 1 || M.z != z)
				readers -= M
				GLOB.nanomanager.close_user_uis(M, src)
				continue
			ui_interact(M, force_open = FALSE)

// The meter's window: live readings and a one-minute chart as panel sections.
/obj/structure/power_meter/proc/report_sections()
	if (!in_service())
		return list(panel_section("Readings", empty = "Not connected. Secure it on a cable with a wrench."))
	var/supply = max(0, powersource.powerflow)
	var/served = max(0, powersource.currentflow)
	var/list/failed = list()
	var/shed = powersource.grid_shortage(world.time, failed)
	var/tone = (supply <= 0 || shed > 0) ? "warn" : (served >= supply * 0.9 ? "progress" : "good")
	var/list/rows = list(panel_row("Supply", power_text(supply)), panel_row("Requested", power_text(served + shed)),
		panel_row("Served", power_text(served), tone), panel_row("Shed", power_text(shed), shed > 0 ? "warn" : "muted"))
	if (supply > 0)
		rows += list(panel_row("Load", "[round(served * 100 / supply)]%"))
	if (shortage_announced && shed > 0)
		rows += list(panel_row("Alarm", "Sustained shortage", "warn"))
	var/list/failure_rows = list()
	for (var/obj/device in failed)
		failure_rows += list(panel_row(device.name, power_text(failed[device]), "warn"))
	rows += list(panel_row("Grid", "[powersource.component_size] cable section\s"))
	var/top = 1
	for (var/v in supply_log)
		top = max(top, v)
	for (var/v in demand_log)
		top = max(top, v)
	return list(panel_section("Readings", rows = rows),
		panel_section("Last minute", list("The chart updates every second while you stand by the meter."),
			chart = panel_chart(list(panel_series("supply", "good", supply_log.Copy()), panel_series("requested", "progress", demand_log.Copy()),
				panel_series("served", "info", served_log.Copy())), POWER_METER_SAMPLES, power_text(top), "one minute ago", "now")),
		panel_section("Current refusals", list("Up to six machines. Retrying requests expire after five seconds without another draw."),
			rows = failure_rows, empty = "No current refusals."))

/obj/structure/power_meter/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	open_panel(user, name, 440, 540, report_sections(), ui = ui, force_open = force_open)

/obj/structure/power_meter/attack_hand(mob/user)
	if (!ishuman(user) || get_dist(user, src) > 1)
		return
	if (in_service() && !supply_log.len)
		sample()
	readers |= user
	ui_interact(user)

/obj/structure/power_meter/attackby(obj/item/W, mob/user)
	var/mob/living/human/H = user
	if (is_tool(W, TOOL_WRENCH))
		if (!istype(H) || H.stat != CONSCIOUS || get_dist(H, src) > 1)
			return
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		if (anchored)
			detach_cable()
			anchored = FALSE
			to_chat(user, "<span class='notice'>You unfasten \the [src].</span>")
			return
		if (!isturf(loc) || !(locate(/obj/structure/cable) in loc))
			to_chat(user, "<span class='warning'>Lay a cable under \the [src] first.</span>")
			return
		anchored = TRUE
		attach_cable()
		to_chat(user, "<span class='notice'>You secure \the [src] on the cable.</span>")
		return
	..()

/obj/structure/power_meter/examine(mob/user)
	. = ..()
	if (in_service())
		var/served = max(0, powersource.currentflow)
		var/shed = powersource.grid_shortage(world.time)
		to_chat(user, "The needles read [power_text(served + shed)] requested, [power_text(served)] served and [power_text(shed)] shed of [power_text(max(0, powersource.powerflow))] available.")
	else
		to_chat(user, "It is not connected. Secure it on a cable with a wrench.")

// Placed in a map already secured; it joins the cable under it on load.
/obj/structure/power_meter/secured
	anchored = TRUE

// Only set priority for machines the operator can actually reach, and recheck
// physical and electrical ownership after the player dismisses the picker.
/obj/structure/power_meter/proc/priority_load_reachable(mob/living/human/H, obj/structure/load)
	return istype(H) && H.stat == CONSCIOUS && !H.restrained() && H.z == z && H.Adjacent(src) && in_service() && istype(load) && !QDELETED(load) && H.z == load.z && H.Adjacent(load) && load.powerneeded > 0 && load.powersource && load.cable_reach(load.powersource) && (load in load.powersource.connections)

/obj/structure/power_meter/verb/toggle_grid_priority()
	set name = "Toggle nearby machine power priority"
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || H.restrained() || H.z != z || !H.Adjacent(src) || !in_service())
		return
	powersource.rebuild_supply()
	var/list/choices = list()
	for (var/obj/structure/load in range(1, H))
		if (priority_load_reachable(H, load) && load.powersource.component_id == powersource.component_id)
			choices += load
	if (!choices.len)
		to_chat(H, SPAN_NOTICE("There are no reachable machines on this grid."))
		return
	var/obj/structure/selected = player_input(H, "Choose a nearby machine on this grid.", "Power priority", null, "anything", choices, TRUE)
	if (QDELETED(src) || !priority_load_reachable(H, selected))
		return
	powersource.rebuild_supply()
	if (selected.powersource.component_id != powersource.component_id)
		return
	selected.grid_power_priority = !selected.grid_power_priority
	to_chat(H, SPAN_NOTICE("[selected] now has [selected.grid_power_priority ? "priority" : "normal"] power. This setting lasts until the world restarts."))
