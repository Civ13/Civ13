// Actual production wounds and disk serializer; fixture owners suppress startup.
/world/OpenPort(port)
	return ..("none")
/obj/item/organ/external/wound_restore_probe
	max_damage = 113
/obj/item/organ/external/wound_restore_probe/New()
	return
/obj/item/wound_restore_probe
	var/marker = "embedded-wound-item"
/obj/item/wound_restore_probe/New()
	return

/proc/wound_restore_fields()
	return list("current_stage", "desc", "damage", "bleed_timer", "min_damage", "bleed_threshold", "bandaged", "clamped", "salved", "disinfected", "created", "amount", "germ_level", "stages", "internal", "max_bleeding_stage", "damage_type", "autoheal_cutoff", "desc_list", "damage_list")

/proc/wound_restore_snapshot(datum/wound/W)
	var/list/state = list()
	for(var/key in wound_restore_fields())
		state[key] = W.vars[key]
	return json_encode(state)

/proc/wound_restore_case(method, clean, encoding)
	var/obj/item/organ/external/wound_restore_probe/O = new
	var/datum/wound/lost_limb/W = new(O, method, clean)
	var/expected_damage = clean ? 56.5 : 113
	durable_world_check(W.damage == expected_damage && W.bleed_timer == expected_damage, "ordinary lost-limb damage changed")
	durable_world_check(W.damage_type == (method == DROPLIMB_BURN ? BURN : CUT), "ordinary lost-limb damage type changed")
	durable_world_check(W.stages[W.stages[1]] == expected_damage * 1.3, "ordinary lost-limb stages changed")
	durable_world_check(W.max_bleeding_stage == (method == DROPLIMB_BURN ? FALSE : 3), "ordinary lost-limb bleeding changed")
	W.parent_organ = O
	O.wounds = list(W)
	W.bandaged = TRUE
	W.clamped = TRUE
	W.salved = TRUE
	W.disinfected = TRUE
	W.germ_level = 19
	W.created = 717
	W.amount = 2
	W.damage = expected_damage * 0.4
	W.init_stage(W.damage)
	W.bleed_timer = 29
	var/obj/item/wound_restore_probe/I = new
	W.embedded_objects = list(I)
	var/snapshot = wound_restore_snapshot(W)
	var/path = "wound-[method]-[clean]-[encoding].sav"
	var/savefile/F = new(path)
	var/ref = 1
	map_storage.clear_bookkeeping()
	if(encoding == "roundtrip")
		F["/format_version"] << 2
		ref = map_storage.BuildVarDirectory(F, W)
	else
		// Explicit historical-shaped entries exercise both decoder layouts.
		// Native lists are supported by the legacy flat-value fallback; helper
		// arrays and reference cycles also exercise its old **list/**entry forms.
		if(encoding == "typed") F["/format_version"] << 2
		for(var/key in wound_restore_fields())
			var/value = W.vars[key]
			if(encoding == "typed")
				value = map_storage.encode_saved_value(F, value)
			else if(key == "desc_list" || key == "damage_list")
				value = "**list[list2params(value)]"
			F["[map_storage.entry_path(F, 1)]/[key]"] << value
		F["[map_storage.entry_path(F, 1)]/type"] << /datum/wound/lost_limb
		if(encoding == "typed")
			F["[map_storage.entry_path(F, 1)]/parent_organ"] << list("kind" = "entry", "ref" = 2)
			F["/lists/999/length"] << 1
			F["/lists/999/1/key"] << list("kind" = "entry", "ref" = 1)
			F["/lists/999/1/value"] << list("kind" = "value", "value" = null)
			F["[map_storage.entry_path(F, 2)]/wounds"] << list("kind" = "list", "ref" = 999)
		else
			F["/entries/1/parent_organ"] << "**entry2"
			F["/entries/2/wounds"] << "**list**entry1"
		F["[map_storage.entry_path(F, 2)]/type"] << /obj/item/organ/external/wound_restore_probe
	// Close and reopen the native file; no in-memory object cache may supply W.
	F = null
	map_storage.clear_bookkeeping()
	F = new(path)
	var/datum/wound/lost_limb/R = map_storage.Load_Entry(F, ref)
	durable_world_check(R && R != W && wound_restore_snapshot(R) == snapshot, "saved wound state changed")
	durable_world_check(R.parent_organ && R.parent_organ != O && R.parent_organ.wounds.len == 1 && R.parent_organ.wounds[1] == R, "saved organ/wound identity cycle changed")
	if(encoding == "roundtrip")
		durable_world_check(R.embedded_objects.len == 1 && istype(R.embedded_objects[1], /obj/item/wound_restore_probe), "embedded object lost")
		durable_world_check(R.embedded_objects[1]:marker == I.marker && R.embedded_objects[1] != I, "embedded object identity changed")
	durable_world_check(!R.can_merge(W) && !R.bleeding(), "restored wound behavior changed")
	F = null
	map_storage.clear_bookkeeping()

/proc/wound_restore_reject_missing(key)
	var/obj/item/organ/external/wound_restore_probe/O = new
	var/datum/wound/lost_limb/W = new(O, DROPLIMB_EDGE, FALSE)
	var/savefile/F = new("missing-[key].sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	var/ref = map_storage.BuildVarDirectory(F, W)
	F["[map_storage.entry_path(F, ref)]/[key]"] << list("kind" = "value", "value" = null)
	F = null
	map_storage.clear_bookkeeping()
	F = new("missing-[key].sav")
	var/rejected = FALSE
	try
		map_storage.Load_Entry(F, ref)
	catch(var/exception/E)
		rejected = findtext("[E]", "missing its stage tables") > 0
	durable_world_check(rejected, "incomplete saved lost-limb wound accepted")
	map_storage.clear_bookkeeping()

/world/New()
	world.OpenPort(0)
	try
		for(var/encoding in list("roundtrip", "typed", "legacy"))
			for(var/method in list(DROPLIMB_EDGE, DROPLIMB_BLUNT, DROPLIMB_BURN))
				for(var/clean in list(FALSE, TRUE))
					wound_restore_case(method, clean, encoding)
		for(var/key in list("stages", "desc_list", "damage_list"))
			wound_restore_reject_missing(key)
		text2file(json_encode(list("done" = TRUE, "checks" = durable_probe_checks, "roundtrips" = 18)), "metadata-result.json")
	catch(var/exception/E)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[E]", "source" = E.file, "line" = E.line)), "metadata-result.json")
	del(world)
