// Prepared only. A reviewed isolated harness is required before native launch.
var/failures = 0

/proc/check(value, label)
	if (!value)
		failures++
		world.log << "FAIL: [label]"

/proc/identity()
	var/digest = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	return list("scenario_id" = "expedition_1", "colony_id" = "colony_1", "gateway_id" = "doorway_1", "instance_id" = "instance_1", "template_id" = digest, "scenario_spec_sha256" = digest, "manifest_sha256" = digest, "scenario_year" = 1990)

/proc/ready_core()
	var/datum/backrooms_supply/S = new(100, 600)
	S.connect()
	var/datum/backrooms_gateway_core/G = new(identity(), S)
	G.enabled = TRUE
	check(G.start(0, TRUE), "start")
	for (var/t = 10, t <= 300, t += 10)
		check(G.service(t, TRUE), "continuous startup")
	return G

/proc/probe()
	var/datum/backrooms_supply/S = new(100, 600)
	check(!S.draw(1) && S.charge == 100, "disconnected debit")
	S.connect()
	check(!S.draw(0) && !S.draw(0.5) && !S.draw(101) && S.charge == 100, "invalid debit atomic")
	check(S.draw(100) && S.charge == 0 && !S.draw(1), "finite debit")
	check(!S.credit(601) && !S.credit(0.5) && S.charge == 0, "invalid credit atomic")
	check(S.credit(100) && S.charge == 100, "credit")
	var/datum/backrooms_gateway_core/G = new(identity(), S)
	check(!G.start(0, TRUE) && S.charge == 100, "disabled")
	G.stop()
	G.enabled = TRUE
	check(!G.start(0, FALSE) && S.charge == 100, "destination admission")
	G.stop()
	check(G.start(0, TRUE) && S.charge == 89, "startup debit")
	check(!G.can_cross(0, TRUE), "startup crossing refused")
	check(G.service(0, TRUE) && S.charge == 89, "same time idempotent")
	check(!G.service(11, TRUE) && G.state == "FAULT" && S.charge == 89, "missed interval")
	G.stop()
	check(G.start(11, TRUE) && S.charge == 78, "restart pays again")
	S.disconnect()
	check(!G.service(12, TRUE) && G.state == "FAULT", "startup interruption")
	S.connect()
	check(!G.start(13, TRUE), "no automatic fault restart")
	G = ready_core()
	check(G.state == "READY" && G.supply.charge == 59, "startup exact boundary")
	check(G.can_cross(300, TRUE) && !G.can_cross(310, TRUE), "lease exact expiry")
	check(G.service(300, TRUE) && G.supply.charge == 59, "ready same time idempotent")
	check(!G.can_cross(300, FALSE), "destination failure at admission")
	G.supply.disconnect()
	check(!G.can_cross(300, TRUE), "outage admission")
	G.supply.connect()
	check(!G.can_cross(300, TRUE), "reconnected source epoch")
	check(!G.service(300, TRUE) && G.state == "FAULT", "reconnected source fault")
	G = ready_core()
	G.stop()
	check(!G.can_cross(300, TRUE) && G.supply.charge == 59 && G.binding["colony_id"] == "colony_1", "shutdown preserves colony")
	G = ready_core()
	check(!G.service(299, TRUE) && G.last_error == "clock", "clock reversal")
	G = ready_core()
	G.supply.charge = 1
	check(!G.can_cross(300, TRUE), "crossing minimum charge")
	G.supply.charge = 0
	check(!G.service(310, TRUE), "depleted maintenance")
	G = ready_core()
	var/list/record = G.snapshot()
	check(record.len == 4 && record["supply_charge"] == 59, "snapshot allowlist")
	// Native savefile disk round trip of the explicit ABI, not world serializer.
	var/savefile/F = new("gateway-test.sav")
	F["record"] << record
	F = null
	F = new("gateway-test.sav")
	var/list/loaded
	F["record"] >> loaded
	F = null
	check(G.restore(loaded), "disk snapshot restore")
	check(G.state == "OFF" && !G.supply.connected && G.supply.charge == 59 && !G.can_cross(0, TRUE), "restore off")
	check(G.binding["manifest_sha256"] == record["binding"]["manifest_sha256"], "manifest preserved")
	var/datum/backrooms_supply/prior = G.supply
	for (var/key in list("colony_id", "gateway_id", "scenario_id", "instance_id", "template_id", "scenario_spec_sha256", "manifest_sha256", "scenario_year"))
		var/list/bad = json_decode(json_encode(record))
		var/list/B = bad["binding"]
		if (key == "scenario_year")
			B[key] = 1991
		else if (key in list("template_id", "scenario_spec_sha256", "manifest_sha256"))
			B[key] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
		else
			B[key] = "different"
		check(!G.restore(bad) && G.supply == prior && G.supply.charge == 59, "identity mismatch [key]")
	for (var/bad_charge in list(-1, 0.5, 601, "5", null))
		var/list/bad = record.Copy()
		bad["supply_charge"] = bad_charge
		check(!G.restore(bad) && G.supply == prior, "malformed charge")
	var/list/extra = record.Copy()
	extra["state"] = "READY"
	check(!G.restore(extra) && G.supply == prior, "unknown field rejection")
	var/list/missing = record.Copy()
	missing -= "schema"
	check(!G.restore(missing) && G.supply == prior, "missing schema rejection")
	var/list/wrong_capacity = record.Copy()
	wrong_capacity["supply_capacity"] = 601
	check(!G.restore(wrong_capacity) && G.supply == prior, "capacity mismatch")
	var/list/wrong_schema = record.Copy()
	wrong_schema["schema"] = 2
	check(!G.restore(wrong_schema) && G.supply == prior, "schema mismatch")
	G.supply.connect()
	check(G.start(0, TRUE) && G.supply.charge == 48, "restored startup repaid")
	world.log << "BACKROOMS_GATEWAY_FAILURES=[failures]"
	del(world)
	return

/world
	maxx = 1
	maxy = 1
	maxz = 1
	visibility = 0
	hub = ""
	New()
		..()
		OpenPort("none")
		check(port == 0 && !OpenPort(0) && port == 0, "port closed")
		probe()
	OpenPort(value)
		if (value == "none")
			return ..(value)
		return 0
	Error(exception/E)
		failures++
		world.log << "NATIVE_ERROR: [E]"
		del(world)
		return

/client/New()
	del(src)
