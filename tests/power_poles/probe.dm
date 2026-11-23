// Wall outlet and utility pole fixture (tests/power_poles/run.py). The
// fixture replaces world/New, so map autolink is still held at start.
/world
	maxx = 14
	maxy = 14
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/turf/pole_wall
	density = TRUE
	opacity = TRUE

/obj/structure/engine/pole_tester
	maxpower = 100
	on = TRUE
	anchored = TRUE

/obj/structure/engine/pole_tester/New()
	return

/obj/structure/pole_lamp
	powerneeded = 10
	anchored = TRUE
	density = FALSE

var/global/pole_failures = 0
/proc/pole_check(label, actual, expected)
	world.log << "POLE CHECK [label]: [actual] expected [expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected)
		pole_failures++

/proc/pole_engine_on(obj/structure/cable/C)
	var/obj/structure/engine/pole_tester/E = new(C.loc)
	C.connections |= E
	E.connections |= C
	return E

/world/New()
	OpenPort("none")
	sleep(1)
	try
		release_cable_autolink()

		// Outlet: turns to the wall beside it and feeds within three tiles.
		new /turf/pole_wall(locate(2, 13, 1))
		var/obj/structure/cable/oc = new(locate(2, 12, 1))
		pole_engine_on(oc)
		var/obj/structure/power_point/outlet/O = new(locate(2, 12, 1))
		pole_check("outlet faces the wall", O.dir, NORTH)
		pole_check("outlet does not block movement", O.density ? 1 : 0, 0)
		var/obj/structure/pole_lamp/onear = new(locate(5, 12, 1))
		var/obj/structure/pole_lamp/ofar = new(locate(6, 12, 1))
		O.anchored = TRUE
		pole_check("outlet finds its cable", O.attach_cable() ? 1 : 0, 1)
		pole_check("outlet serves one lamp", O.serve_nearby(), 1)
		O.update_icon()
		pole_check("outlet serves the lamp three tiles away", onear.draw_cable_power() ? 1 : 0, 1)
		pole_check("outlet leaves the lamp four tiles away", ofar.powersource ? 1 : 0, 0)
		pole_check("outlet shows live", O.icon_state, "wall_outlet_live")

		// Two separate grids: an engine under pole A, a lamp near pole B.
		var/obj/structure/cable/ca = new(locate(2, 2, 1))
		pole_engine_on(ca)
		var/obj/structure/cable/cb = new(locate(8, 2, 1))
		var/obj/structure/power_point/pole/A = new(locate(2, 2, 1))
		var/obj/structure/power_point/pole/B = new(locate(8, 2, 1))
		var/obj/structure/pole_lamp/lamp = new(locate(8, 4, 1))
		A.anchored = TRUE
		A.attach_cable()
		B.anchored = TRUE
		B.attach_cable()
		B.serve_nearby()
		pole_check("pole B feeds its lamp", lamp.power_point == B ? 1 : 0, 1)
		pole_check("before the wire: no supply on B's grid", lamp.draw_cable_power() ? 1 : 0, 0)
		pole_check("wire strung", A.link_span(B) ? 1 : 0, 1)
		pole_check("pole B shows live once wired", B.icon_state, "utility_pole_live")
		pole_check("wire listed both ways", (B in A.span_poles) && (A in B.span_poles) ? 1 : 0, 1)
		pole_check("cables linked", (cb in ca.riser_links) && (ca in cb.riser_links) ? 1 : 0, 1)
		pole_check("after the wire: lamp draws", lamp.draw_cable_power() ? 1 : 0, 1)
		pole_check("one wire drawn for the pair", length(A.span_images) + length(B.span_images), 1)
		pole_check("second wire to the same pole refused", A.link_span(B) ? 1 : 0, 0)

		new /obj/structure/cable(locate(2, 11, 1))
		var/obj/structure/power_point/pole/far = new(locate(2, 11, 1))
		far.anchored = TRUE
		far.attach_cable()
		pole_check("pole nine tiles away refused", A.link_span(far) ? 1 : 0, 0)

		// Unfastening B drops the link; fastening again restores it.
		B.detach_cable()
		B.anchored = FALSE
		pole_check("unfastened: lamp loses power", lamp.powersource ? 1 : 0, 0)
		pole_check("unfastened: cable link dropped", (cb in ca.riser_links) ? 1 : 0, 0)
		pole_check("unfastened: wire kept on the poles", (A in B.span_poles) ? 1 : 0, 1)
		B.anchored = TRUE
		B.attach_cable()
		B.serve_nearby()
		pole_check("refastened: cable link back", (cb in ca.riser_links) ? 1 : 0, 1)
		pole_check("refastened: lamp draws", lamp.draw_cable_power() ? 1 : 0, 1)

		// Simulated reload: the cable links are runtime, the pole lists are saved.
		ca.riser_links = null
		cb.riser_links = null
		pole_check("before reload: links gone", (cb in ca.riser_links) ? 1 : 0, 0)
		A.after_load()
		pole_check("after reload: links back", (cb in ca.riser_links) && (ca in cb.riser_links) ? 1 : 0, 1)
		pole_check("span_images is runtime", A.persistence_runtime_var("span_images") ? 1 : 0, 1)
		pole_check("span_poles is saved", A.persistence_runtime_var("span_poles") ? 1 : 0, 0)

		// Cutting the wire refunds the cable and splits the grids.
		var/refunded = A.cut_spans()
		pole_check("cut: six pieces back", refunded, 6)
		var/obj/item/stack/cable_coil/coil = locate() in locate(2, 2, 1)
		pole_check("cut: coil dropped", coil ? coil.amount : 0, 6)
		pole_check("cut: partner forgets the wire", (A in B.span_poles) ? 1 : 0, 0)
		pole_check("cut: cable link dropped", (cb in ca.riser_links) ? 1 : 0, 0)
		pole_check("cut: no wire drawn", length(A.span_images) + length(B.span_images), 0)
		pole_check("cut: lamp has no supply", lamp.draw_cable_power() ? 1 : 0, 0)
		pole_check("cut: pole B goes dark", B.icon_state, "utility_pole")

		// Destroying a pole takes its wires down without a refund.
		A.link_span(B)
		qdel(B)
		pole_check("destroyed: partner forgets it", (B in A.span_poles) ? 1 : 0, 0)
		pole_check("destroyed: link dropped", (cb in ca.riser_links) ? 1 : 0, 0)
		pole_check("destroyed: no refund coil on B's tile", (locate(/obj/item/stack/cable_coil) in locate(8, 2, 1)) ? 1 : 0, 0)
		pole_battery_checks()
	catch (var/exception/ex)
		world.log << "POLE EXCEPTION: [ex.name] [ex.file]:[ex.line]"
		pole_failures++
	text2file("[pole_failures ? "FAIL" : "PASS"]: power poles failures=[pole_failures]", "result.txt")
	shutdown()

/proc/pole_battery_checks()
	var/obj/structure/cable/A = new(locate(2, 6, 1))
	var/obj/structure/cable/B = new(locate(8, 6, 1))
	var/obj/structure/engine/pole_tester/E = pole_engine_on(A)
	E.maxpower = 35
	var/obj/structure/power_point/pole/P = new(A.loc)
	var/obj/structure/power_point/pole/Q = new(B.loc)
	P.anchored = TRUE
	Q.anchored = TRUE
	P.attach_cable()
	Q.attach_cable()
	var/obj/structure/pole_lamp/L = new(locate(8, 8, 1))
	Q.serve_nearby()
	var/obj/structure/battery/lithium_ion/S = new(B.loc)
	S.anchored = TRUE
	S.powersource = B
	B.connections |= S
	S.mode = "charge"
	pole_check("disconnected pole grid cannot charge", B.reserve_battery_charge(40), 0)
	pole_check("charging test links two overhead poles", P.link_span(Q) ? 1 : 0, 1)
	pole_check("remote idle lamp has no prior reservation", B.currentflow, 0)
	S.settle_tick()
	pole_check("battery charges across span after reserving remote idle lamp", S.stored_energy, 25)
	pole_check("remote lamp still gets all of its work power", L.draw_cable_power() ? 1 : 0, 1)
	pole_check("same interval cannot reuse the debited generation", B.reserve_battery_charge(40), 0)
	// Start a fresh generator budget for the lossy span check. Reserve only
	// what is available after the real material-loss function and the lamp.
	E.battery_charge_epoch = -1
	A.cable_color = "iron"
	var/delivered = cable_delivered(E.maxpower, cable_wire_loss("iron"))
	pole_check("lossy cable reduces delivered capacity", delivered < E.maxpower, TRUE)
	pole_check("span charging uses delivered headroom", B.reserve_battery_charge(40), max(0, delivered - L.powerneeded))
	pole_check("charging does not de-power the existing lamp", L.draw_cable_power() ? 1 : 0, 1)
	P.cut_spans(FALSE)
	pole_check("cut span removes the charging path", B.reserve_battery_charge(40), 0)
