// Power meter and power units fixture (tests/power_meter/run.py). The fixture
// replaces world/New, so map autolink is still held at start. It writes the
// meter page to meter.html for a rendered review.
/world
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/structure/engine/meter_tester
	maxpower = 100
	on = TRUE
	anchored = TRUE

/obj/structure/engine/meter_tester/New()
	return

/obj/meter_lamp
	powerneeded = 10
	anchored = TRUE

var/global/meter_failures = 0
/proc/meter_check(label, actual, expected)
	world.log << "METER CHECK [label]: [actual] expected [expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected)
		meter_failures++

/world/New()
	OpenPort("none")
	sleep(1)
	try
		meter_check("kW", power_text(12), "12 kW")
		meter_check("MW", power_text(2500), "2.5 MW")
		meter_check("fractional kW", power_text(0.5), "0.5 kW")
		meter_check("Wh", energy_text(600), "167 Wh")
		meter_check("kWh", energy_text(12000), "3.33 kWh")
		meter_check("MWh", energy_text(3600 * 2500), "2.5 MWh")

		// A secured meter placed in a map joins its cable on release.
		var/obj/structure/cable/c1 = new(locate(2, 2, 1))
		var/obj/structure/cable/c2 = new(locate(3, 2, 1))
		var/obj/structure/engine/meter_tester/E = new(locate(2, 2, 1))
		var/obj/structure/power_meter/secured/M = new(locate(3, 2, 1))
		meter_check("held: meter waits", M.in_service() ? 1 : 0, 0)
		release_cable_autolink()
		meter_check("released: meter on its cable", M.in_service() ? 1 : 0, 1)
		meter_check("released: engine joined", (E in c1.connections) ? 1 : 0, 1)
		meter_check("released: cables joined", (c2 in c1.connections) ? 1 : 0, 1)

		var/obj/meter_lamp/L = new(locate(3, 3, 1))
		L.powersource = c2
		c2.connections |= L
		meter_check("lamp draws", L.draw_cable_power() ? 1 : 0, 1)
		M.sample()
		meter_check("first sample supply", M.supply_log[1], 100)
		meter_check("first sample demand", M.demand_log[1], 10)
		for (var/i = 1, i <= 70, i++)
			M.sample()
		meter_check("log keeps one minute", M.supply_log.len, 60)
		meter_check("demand log keeps one minute", M.demand_log.len, 60)
		var/list/sections = M.report_sections()
		var/html = json_encode(sections)
		meter_check("page shows supply in kW", findtext(html, "{\"label\":\"Supply\",\"value\":\"100 kW\"}") ? 1 : 0, 1)
		meter_check("page shows load", findtext(html, "{\"label\":\"Load\",\"value\":\"10%\"}") ? 1 : 0, 1)
		var/list/chart = sections[2]["chart"]
		var/list/series = chart["series"]
		var/list/first_line = series[1]
		var/list/first_points = first_line["points"]
		meter_check("page charts supply, requested and served", series.len, 3)
		meter_check("a line carries the whole minute", first_points.len, 60)
		// Capacity is 100; a second 100 kW load cannot run beside the lamp.
		var/obj/meter_lamp/F = new(locate(2, 3, 1))
		F.name = "overloaded test lamp"
		F.powerneeded = 100
		F.powersource = c1
		c1.connections |= F
		meter_check("large load refused", F.draw_cable_power(), FALSE)
		meter_check("other cable sees refusal", c2.grid_shortage(world.time), 100)
		meter_check("probe read has no expiry leak", c2.grid_shortage(F.grid_power_request_until), 0)
		meter_check("repeat denial is idempotent", F.draw_cable_power(), FALSE)
		M.sample()
		meter_check("missed load contributes to requested", M.demand_log[M.demand_log.len], 110)
		meter_check("missed load is not served", M.served_log[M.served_log.len], 10)
		html = json_encode(M.report_sections())
		meter_check("page identifies refused machine", findtext(html, "overloaded test lamp") ? 1 : 0, 1)
		meter_check("page labels shed", findtext(html, "\"label\":\"Shed\",\"value\":\"100 kW\"") ? 1 : 0, 1)
		text2file(html, "meter.json")
		c1.update_power(0, 1, F)
		meter_check("explicit stop clears refused demand", c2.grid_shortage(world.time), 0)
		meter_check("starts incident silently", M.shortage_alarm(0, 10, 99), FALSE)
		meter_check("transient dip stays silent", M.shortage_alarm(49, 10, 99), FALSE)
		meter_check("sustained dip alerts once", M.shortage_alarm(50, 10, 99), TRUE)
		meter_check("same incident stays quiet", M.shortage_alarm(99, 10, 99), FALSE)
		meter_check("recovery resets alarm", M.shortage_alarm(101, 0, 99), FALSE)
		meter_check("next incident starts quietly", M.shortage_alarm(110, 10, 99), FALSE)
		meter_check("new incident can alert", M.shortage_alarm(160, 10, 99), TRUE)
		meter_check("switching grid resets alarm", M.shortage_alarm(161, 10, 100), FALSE)

		// Unfastened: no service, and the log clears.
		M.detach_cable()
		M.anchored = FALSE
		meter_check("unfastened: out of service", M.in_service() ? 1 : 0, 0)
		meter_check("unfastened: log cleared", M.supply_log.len, 0)
		M.sample()
		meter_check("unfastened: no samples taken", M.supply_log.len, 0)
		meter_check("unfastened page asks for a cable", findtext(json_encode(M.report_sections()), "Not connected") ? 1 : 0, 1)
		qdel(M)
		meter_check("destroyed meter leaves the registry", (M in power_meters) ? 1 : 0, 0)
	catch (var/exception/ex)
		world.log << "METER EXCEPTION: [ex.name] [ex.file]:[ex.line]"
		meter_failures++
	text2file("[meter_failures ? "FAIL" : "PASS"]: power meter failures=[meter_failures]", "result.txt")
	shutdown()
