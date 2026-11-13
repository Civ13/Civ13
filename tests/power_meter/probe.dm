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
		var/html = M.report_html()
		meter_check("page shows supply in kW", findtext(html, "Supply: <b>100 kW</b>") ? 1 : 0, 1)
		meter_check("page shows load", findtext(html, "Load: <b>10%</b>") ? 1 : 0, 1)
		meter_check("page draws two lines", length(splittext(html, "<polyline")) - 1, 2)
		text2file(html, "meter.html")

		// Unfastened: no service, and the log clears.
		M.detach_cable()
		M.anchored = FALSE
		meter_check("unfastened: out of service", M.in_service() ? 1 : 0, 0)
		meter_check("unfastened: log cleared", M.supply_log.len, 0)
		M.sample()
		meter_check("unfastened: no samples taken", M.supply_log.len, 0)
		meter_check("unfastened page asks for a cable", findtext(M.report_html(), "Not connected") ? 1 : 0, 1)
		qdel(M)
		meter_check("destroyed meter leaves the registry", (M in power_meters) ? 1 : 0, 0)
	catch (var/exception/ex)
		world.log << "METER EXCEPTION: [ex.name] [ex.file]:[ex.line]"
		meter_failures++
	text2file("[meter_failures ? "FAIL" : "PASS"]: power meter failures=[meter_failures]", "result.txt")
	shutdown()
