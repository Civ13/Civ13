// Native checks of the production bounded structure-state projection.
// Does not exercise network custody or authorize production departure.
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
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
			world.log << "CODEC DIAG unprojected key=[key] value=[value] list=[islist(value)] datum=[istype(value, /datum)]"
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
	catch(var/exception/E)
		train_codec_runtime_error = TRUE
		world.log << "Fixture aborted: [E] at [E.file]:[E.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = train_codec_checks.len, "failed_labels" = train_codec_failed, "runtime_error" = train_codec_runtime_error, "checks" = train_codec_checks)), "result.json")
	world.log << "COMPLETE train codec fixture"
	del(world)
