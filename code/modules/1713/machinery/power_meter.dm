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
// published supply and demand (no traversal), and shows the last minute as
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
	var/tmp/list/demand_log = list()
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
	return (key in list("supply_log", "demand_log", "readers", "registered")) || ..()

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

// Called once a second by the civ_generation process.
/obj/structure/power_meter/proc/sample()
	var/supply = 0
	var/demand = 0
	if (in_service())
		supply = max(0, powersource.powerflow)
		demand = max(0, powersource.currentflow)
	else if (!supply_log.len)
		return
	supply_log += supply
	demand_log += demand
	if (supply_log.len > POWER_METER_SAMPLES)
		supply_log.Cut(1, 2)
	if (demand_log.len > POWER_METER_SAMPLES)
		demand_log.Cut(1, 2)
	if (readers.len)
		for (var/mob/M in readers.Copy())
			if (!M.client || get_dist(M, src) > 1 || M.z != z)
				readers -= M
				continue
			show(M)

/obj/structure/power_meter/proc/chart_svg()
	var/width = 360
	var/height = 120
	var/top = 1
	for (var/v in supply_log)
		top = max(top, v)
	for (var/v in demand_log)
		top = max(top, v)
	var/list/out = list("<svg width='[width]' height='[height + 16]' style='background:#14181c'>")
	out += "<line x1='0' y1='[height]' x2='[width]' y2='[height]' stroke='#555'/>"
	for (var/list/series in list(list(supply_log, "#4caf50"), list(demand_log, "#ffb300")))
		var/list/samples = series[1]
		if (!samples.len)
			continue
		var/list/points = list()
		for (var/i = 1, i <= samples.len, i++)
			var/px = round((POWER_METER_SAMPLES - samples.len + i - 1) * width / (POWER_METER_SAMPLES - 1), 0.1)
			var/py = round(height - (samples[i] / top) * (height - 20), 0.1)
			points += "[px],[py]"
		out += "<polyline fill='none' stroke='[series[2]]' stroke-width='2' points='[points.Join(" ")]'/>"
	out += "<text x='4' y='12' fill='#bbb' font-size='11'>[power_text(top)]</text>"
	out += "<text x='4' y='[height + 13]' fill='#bbb' font-size='11'>one minute ago</text>"
	out += "<text x='[width - 30]' y='[height + 13]' fill='#bbb' font-size='11'>now</text>"
	out += "</svg>"
	return out.Join()

/obj/structure/power_meter/proc/report_html()
	var/list/out = list("<html><head><meta charset='utf-8'></head><body style='background:#1c2126;color:#ddd;font-family:Verdana,sans-serif;font-size:12px'>")
	out += "<h3>[html_encode(name)]</h3>"
	if (!in_service())
		out += "<p>Not connected. Secure it on a cable with a wrench.</p></body></html>"
		return out.Join()
	var/supply = max(0, powersource.powerflow)
	var/demand = max(0, powersource.currentflow)
	var/colour = (supply <= 0 || demand > supply) ? "#e57373" : (demand >= supply * 0.9 ? "#ffb300" : "#81c784")
	out += "<p>Supply: <b>[power_text(supply)]</b> &nbsp; Demand: <b><font color='[colour]'>[power_text(demand)]</font></b>"
	if (supply > 0)
		out += " &nbsp; Load: <b>[round(demand * 100 / supply)]%</b>"
	out += "</p>"
	out += "<p>Grid: [powersource.component_size] cable section\s.</p>"
	out += chart_svg()
	out += "<p><font color='#4caf50'>&#9632;</font> supply &nbsp; <font color='#ffb300'>&#9632;</font> demand. The chart updates every second while you stand by the meter.</p>"
	out += "</body></html>"
	return out.Join()

/obj/structure/power_meter/proc/show(mob/M)
	show_browse(M, report_html(), "window=power_meter_\ref[src];size=420x320")

/obj/structure/power_meter/Topic(href, href_list)
	if (href_list["close"])
		readers -= usr
		return
	..()

/obj/structure/power_meter/attack_hand(mob/user)
	if (!ishuman(user) || get_dist(user, src) > 1)
		return
	if (in_service() && !supply_log.len)
		sample()
	readers |= user
	show(user)
	onclose(user, "power_meter_\ref[src]", src)

/obj/structure/power_meter/attackby(obj/item/W, mob/user)
	var/mob/living/human/H = user
	if (istype(W, /obj/item/weapon/wrench))
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
		to_chat(user, "The needles read [power_text(max(0, powersource.currentflow))] drawn of [power_text(max(0, powersource.powerflow))] available.")
	else
		to_chat(user, "It is not connected. Secure it on a cable with a wrench.")

// Placed in a map already secured; it joins the cable under it on load.
/obj/structure/power_meter/secured
	anchored = TRUE
