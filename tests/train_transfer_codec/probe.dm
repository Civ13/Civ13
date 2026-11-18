// Native checks of the production bounded structure-state projection.
// Does not exercise network custody or authorize production departure.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 24
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
/world/OpenPort(port)
	if(port == "none") return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed train codec fixture"
var/global/list/train_codec_checks = list()
var/global/list/train_codec_failed = list()
var/global/train_codec_runtime_error = FALSE
/world/Error(exception/E)
	train_codec_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()
/proc/train_codec_check(label, passed)
	train_codec_checks += list(list("label" = label, "passed" = !!passed))
	if(!passed) train_codec_failed += label
// Diagnostic only: never broadens production admission or skips failed checks.
/proc/train_codec_diagnose(obj/structure/A)
	var/list/fields = train_transfer_structure_fields(A.type)
	var/list/ignored = list("train_transfer_id", "train_transfer_journey", "train_transfer_digest", "loc", "locs", "pixloc", "contents", "x", "y", "z")
	world.log << "CODEC DIAG type=[A.type] buckled=[!!A.buckled_mob] fields=[fields ? fields.len : 0]"
	for(var/key in A.get_saved_vars())
		if(!(key in fields) && !(key in ignored))
			var/value = A.vars[key]
			world.log << "CODEC DIAG unprojected key=[key] value=[value] list=[islist(value)] datum=[istype(value, /datum)] length=[length(value)] baseline=[train_transfer_structure_baseline(A, key)]"
			if(key == "animate_movement") world.log << "CODEC DIAG animation initial=[initial(A.animate_movement)] current=[A.animate_movement]"
	var/list/raw = list()
	for(var/key in fields)
		if(!(key in A.vars))
			world.log << "CODEC DIAG absent key=[key]"
			continue
		var/value = A.vars[key]
		if(key in list("material", "padding_material"))
			var/material/M = value
			raw[key] = istype(M) ? M.name : null
			world.log << "CODEC DIAG material key=[key] canonical=[istype(M) && get_material_by_name(M.name) == M]"
		else
			raw[key] = value
		world.log << "CODEC DIAG field=[key] value=[raw[key]] null=[isnull(raw[key])] num=[isnum(raw[key])] text=[istext(raw[key])]"
	world.log << "CODEC DIAG raw_valid=[train_transfer_structure_state_valid(A.type, raw)] raw_count=[raw.len]"
/proc/train_codec_probe()
	var/obj/structure/closet/crate/C = new(locate(3, 3, 1))
	C.name = "Journey cargo"
	C.health = 731
	C.locked = TRUE
	C.custom_code = 1793
	train_codec_diagnose(C)
	var/list/state = train_transfer_structure_state(C)
	train_codec_check("crate_capture", islist(state))
	var/list/wire_state = islist(state) ? json_decode(json_encode(state)) : null
	train_codec_check("crate_wire_valid", train_transfer_structure_state_valid(C.type, wire_state))
	var/obj/structure/closet/crate/restored = new(locate(6, 6, 1))
	var/applied = train_transfer_apply_structure_state(restored, wire_state)
	train_codec_check("crate_state_roundtrip", applied && restored.name == C.name && restored.health == C.health && restored.locked == C.locked && restored.custom_code == C.custom_code)
	C.alpha = 123
	train_codec_check("unknown_durable_field_refused", !train_transfer_structure_state(C))
	C.alpha = initial(C.alpha)
	var/list/missing = islist(state) ? state.Copy() : list()
	missing -= "custom_code"
	train_codec_check("missing_field_refused", !train_transfer_structure_state_valid(C.type, missing))
	var/list/extra = islist(state) ? state.Copy() : list()
	extra["unexpected"] = "bad"
	train_codec_check("unknown_wire_field_refused", !train_transfer_structure_state_valid(C.type, extra))
	var/list/mistyped = islist(state) ? state.Copy() : list()
	mistyped["health"] = "healthy"
	train_codec_check("invalid_scalar_refused", !train_transfer_structure_state_valid(C.type, mistyped))
	train_codec_check("crate_subtype_refused", !train_transfer_structure_fields(/obj/structure/closet/crate/large))
	var/obj/structure/bed/B = new(locate(2, 2, 1))
	B.persistence_bed_owner_ckey = "trainfixture"
	train_codec_diagnose(B)
	var/list/bed_state = train_transfer_structure_state(B)
	train_codec_check("bed_owner_and_material", islist(bed_state) && bed_state["persistence_bed_owner_ckey"] == "trainfixture" && bed_state["material"] == B.material.name)
	var/list/bad_material = islist(bed_state) ? bed_state.Copy() : list()
	bad_material["material"] = "not-a-real-material"
	train_codec_check("unknown_material_refused", !train_transfer_structure_state_valid(B.type, bad_material))
/proc/train_codec_baseline_probe()
	var/obj/structure/closet/crate/C = new(locate(4, 4, 1))
	for(var/key in list("paths", "climbers"))
		var/list/values = C.vars[key]
		values += "custom"
		train_codec_check("active_[key]_refused", !train_transfer_structure_state(C))
		values.Cut()
	var/obj/structure/closet/crate/other = new(locate(5, 5, 1))
	C.vis_contents += other
	train_codec_check("vis_contents_refused", !train_transfer_structure_state(C))
	train_codec_check("vis_locs_refused", !train_transfer_structure_state(other))
	C.vis_contents.Cut()
	C.underlays += image(C.icon, "custom")
	train_codec_check("underlays_refused", !train_transfer_structure_state(C))
	C.underlays.Cut()
	C.animate_movement = 1
	train_codec_check("animation_refused", !train_transfer_structure_state(C))
	C.animate_movement = 2
	C.vars["override"] = 1
	train_codec_check("override_refused", !train_transfer_structure_state(C))
	C.vars["override"] = 0
	C.transform = matrix(2, 0, 0, 0, 1, 0)
	train_codec_check("transform_refused", !train_transfer_structure_state(C))
	C.transform = matrix()
	C.filters += filter(type="blur", size=1)
	train_codec_check("filters_refused", !train_transfer_structure_state(C))
	C.filters = null
	C.overlays += image(C.icon, "custom")
	train_codec_check("crate_overlay_refused", !train_transfer_structure_state(C))
	C.overlays.Cut()
	train_codec_check("baseline_restored_admitted", islist(train_transfer_structure_state(C)))
	var/obj/structure/bed/B = new(locate(7, 7, 1))
	B.overlays += image(B.icon, "custom")
	train_codec_check("custom_bed_overlay_refused", !train_transfer_structure_state(B))
/proc/train_codec_kit(kind, x, y)
	var/obj/structure/train_car_kit/K = new(locate(x, y, 1))
	K.set_kind(kind)
	K.furnished = TRUE
	return K.assemble(NORTH)
/proc/train_codec_chain(obj/structure/trains/head)
	var/list/cars = list()
	while(head && cars.len < 64)
		cars += head
		head = head.connected
	return cars
// A copy of the manifest with one change made by the caller, as wire text.
/proc/train_codec_refused(list/M)
	return !train_transfer_decode(json_encode(M))
// A main-line diesel and a loaded hopper: capture, wire, build and the
// manifests a hostile or stale sender could offer instead.
/proc/train_codec_heavy_probe()
	var/obj/structure/trains/locomotive/heavy_diesel/mainline/E = train_codec_kit("loco_dieselmain", 3, 22)
	var/list/unit = train_codec_chain(E)
	train_codec_check("heavy_engine_assembled", istype(E) && unit.len == 6)
	var/obj/structure/trains/platform/last = unit[unit.len]
	var/obj/structure/trains/platform/H = train_codec_kit("hopper", 3, 16)
	last.connected = H
	var/list/cars = train_codec_chain(E)
	E.fuel = 321.4
	E.sand = 7
	E.mileage = 1234
	E.front_coupling = 40
	last.rear_auto = TRUE
	H.front_auto = TRUE
	H.bulk_path = "/obj/item/stack/ore/coal"
	H.bulk_amount = 300
	H.update_bulk()
	H.handbrake = TRUE
	H.axle_oil = -20.6
	H.brake_shoes = 120
	var/list/capture = train_transfer_capture(E, "ckey:trainfixture", "alpha", "beta", "station")
	if(capture["error"]) world.log << "CODEC DIAG capture error: [capture["error"]]"
	var/list/M = capture["manifest"]
	train_codec_check("heavy_capture", islist(M) && M["version"] == 2 && length(M["segments"]) == cars.len)
	if(!islist(M)) return
	var/text = json_encode(M)
	var/list/wire = train_transfer_decode(text)
	train_codec_check("heavy_wire_valid", islist(wire))
	if(!islist(wire)) return
	var/list/S1 = wire["segments"][1]
	train_codec_check("heavy_engine_segment", S1["type"] == "[E.type]" && S1["car_kind"] == "loco_dieselmain" && S1["seg_index"] == 1 && S1["fuel"] == 321 && S1["car_id"] == E.car_id)
	var/levers = 0
	for(var/list/entity in wire["entities"])
		var/list/payload = entity["payload"]
		if(entity["kind"] == "fitting" && payload["type"] == "/obj/structure/train_hopper_lever") levers++
	train_codec_check("hopper_lever_travels", levers == 1)
	// The source is removed before the destination builds; the fixture has no
	// garbage collector, so the removed objects' tags are cleared by hand.
	var/list/gone = capture["cars"] + capture["loads"]
	train_transfer_remove(M["id"], M["journey"])
	for(var/atom/movable/A in gone) A.train_transfer_id = null
	var/list/centres = list()
	for(var/i in 1 to cars.len) centres += locate(8, 23 - i, 1)
	var/obj/structure/trains/locomotive/heavy_diesel/mainline/B = train_transfer_build(wire, centres)
	var/list/built = train_codec_chain(B)
	train_codec_check("heavy_build", istype(B) && B != E && built.len == cars.len && B.loc == centres[1] && B.car_id == S1["car_id"] && length(B.body_parts) >= 2)
	if(!istype(B) || built.len != cars.len) return
	var/sections = TRUE
	for(var/i in 2 to 6)
		var/obj/structure/trains/platform/P = built[i]
		if(!istype(P) || P.seg_index != i || P.car_id != B.car_id || P.car_kind != "loco_dieselmain" || !length(P.deck_parts) || P.car_engine() != B) sections = FALSE
	train_codec_check("heavy_body_sections", sections && B.rear_cab() == built[6])
	train_codec_check("engine_state_roundtrip", B.fuel == 321 && B.sand == 7 && B.mileage == 1234 && B.front_coupling == 40 && !B.on)
	var/obj/structure/trains/platform/BL = built[6]
	var/obj/structure/trains/platform/BH = built[7]
	train_codec_check("car_state_roundtrip", BL.rear_auto && BH.front_auto && BH.bulk_path == "/obj/item/stack/ore/coal" && BH.bulk_amount == 300 && BH.bulk_fill == 1 && BH.handbrake && BH.axle_oil == -21 && BH.brake_shoes == 120)
	var/rebuilt = 0
	for(var/obj/structure/train_hopper_lever/lever in range(1, BH)) rebuilt++
	train_codec_check("lever_rebuilt", rebuilt == 1)
	var/list/X = json_decode(text)
	var/list/segments = X["segments"]
	segments.Cut(6, 7)
	train_codec_check("truncated_body_refused", train_codec_refused(X))
	X = json_decode(text)
	segments = X["segments"]
	segments.Cut(1, 2)
	train_codec_check("headless_body_refused", train_codec_refused(X))
	X = json_decode(text)
	X["segments"][1]["state"]["front_coupling"] = 101
	train_codec_check("state_range_refused", train_codec_refused(X))
	X = json_decode(text)
	X["segments"][1]["state"]["icon"] = "custom"
	train_codec_check("unknown_state_refused", train_codec_refused(X))
	X = json_decode(text)
	var/list/stateless = X["segments"][7]
	stateless -= "state"
	train_codec_check("missing_state_refused", train_codec_refused(X))
	X = json_decode(text)
	X["segments"][7]["state"]["bulk_path"] = "/obj/item/weapon/gun"
	train_codec_check("bad_bulk_refused", train_codec_refused(X))
	X = json_decode(text)
	X["segments"][7]["state"]["bulk_amount"] = 801
	train_codec_check("overload_refused", train_codec_refused(X))
	X = json_decode(text)
	X["version"] = 1
	train_codec_check("old_version_refused", train_codec_refused(X))
	X = json_decode(text)
	for(var/i in 7 to cars.len) X["segments"][i]["car_id"] = S1["car_id"]
	train_codec_check("shared_car_id_refused", train_codec_refused(X))
	X = json_decode(text)
	X["segments"][1]["fuel"] = 601
	train_codec_check("fuel_limit_refused", train_codec_refused(X))
	X = json_decode(text)
	X["segments"][1]["type"] = "/obj/structure/trains/locomotive"
	train_codec_check("plain_engine_body_refused", train_codec_refused(X))
	train_codec_check("unchanged_copy_admitted", !train_codec_refused(json_decode(text)))
	BL.derailed = TRUE
	var/list/again = train_transfer_capture(B, "ckey:trainfixture", "beta", "alpha", "station")
	train_codec_check("derailed_refused", istext(again["error"]))
	BL.derailed = FALSE
	B.broken_down = TRUE
	again = train_transfer_capture(B, "ckey:trainfixture", "beta", "alpha", "station")
	train_codec_check("broken_engine_refused", istext(again["error"]))
	B.broken_down = FALSE
	var/obj/structure/trains/locomotive/coal/mainline/steam = new(locate(11, 22, 1))
	steam.water = 55.5
	steam.pressure = 40
	steam.clinker = 30
	steam.plug_dropped = TRUE
	steam.injector = FALSE
	var/list/steam_state = train_transfer_car_state(steam)
	var/list/steam_wire = islist(steam_state) ? json_decode(json_encode(steam_state)) : null
	var/obj/structure/trains/locomotive/coal/mainline/other = new(locate(11, 10, 1))
	train_codec_check("steam_state_roundtrip", train_transfer_apply_car_state(other, steam_wire) && other.water == 56 && other.pressure == 40 && other.clinker == 30 && other.plug_dropped && !other.injector)
/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new
	try
		train_codec_probe()
		train_codec_baseline_probe()
		train_codec_heavy_probe()
	catch(var/exception/E)
		train_codec_runtime_error = TRUE
		world.log << "Fixture aborted: [E] at [E.file]:[E.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = train_codec_checks.len, "failed_labels" = train_codec_failed, "runtime_error" = train_codec_runtime_error, "checks" = train_codec_checks)), "result.json")
	world.log << "COMPLETE train codec fixture"
	del(world)
