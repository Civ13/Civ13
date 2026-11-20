// Actual production wounds and disk serializer; fixture owners suppress startup.
/world/OpenPort(port)
	return ..("none")
/obj/item/organ/external/wound_restore_probe
	max_damage = 113
/obj/item/organ/external/wound_restore_probe/New()
	return

/proc/wound_restore_fields()
	return list("current_stage", "desc", "damage", "bleed_timer", "min_damage", "bleed_threshold", "bandaged", "clamped", "salved", "disinfected", "created", "amount", "germ_level", "stages", "internal", "max_bleeding_stage", "damage_type", "autoheal_cutoff", "desc_list", "damage_list")

/proc/wound_restore_snapshot(datum/wound/W)
	var/list/state = list()
	for(var/key in wound_restore_fields())
		// created is a world.time stamp (persistence/world_time_stamps.dm):
		// neither saved nor imported, so a restored wound starts its own clock.
		if(key != "created")
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
	var/snapshot = wound_restore_snapshot(W)
	var/path = "wound-[method]-[clean]-[encoding].sav"
	var/savefile/F = new(path)
	var/ref = 1
	var/caches_omitted = FALSE
	map_storage.clear_bookkeeping()
	if(encoding == "roundtrip")
		F["/format_version"] << 2
		ref = map_storage.BuildVarDirectory(F, W)
		F.cd = map_storage.entry_path(F, ref)
		var/list/exported_fields = F.dir.Copy()
		caches_omitted = !("desc_list" in exported_fields) && !("damage_list" in exported_fields)
	else
		// Explicit historical-shaped entries exercise both decoder layouts.
		// Deliberately malformed tmp fields must never be decoded on import.
		if(encoding == "typed") F["/format_version"] << 2
		for(var/key in wound_restore_fields())
			if(key == "desc_list" || key == "damage_list") continue
			var/value = W.vars[key]
			if(encoding == "typed")
				value = map_storage.encode_saved_value(F, value)
			F["[map_storage.entry_path(F, 1)]/[key]"] << value
		var/poison = encoding == "typed" ? list("kind" = "invalid") : "**entry999999"
		F["[map_storage.entry_path(F, 1)]/desc_list"] << poison
		F["[map_storage.entry_path(F, 1)]/damage_list"] << poison
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
	if(encoding == "roundtrip")
		durable_world_check(caches_omitted, "wound helper caches were exported")
	durable_world_check(R.persistence_runtime_var("desc_list") && R.persistence_runtime_var("damage_list"), "wound helper caches are not runtime fields")
	durable_world_check(R.created != 717, "saved wound world.time stamp was restored")
	durable_world_check(R.parent_organ && R.parent_organ != O && R.parent_organ.wounds.len == 1 && R.parent_organ.wounds[1] == R, "saved organ/wound identity cycle changed")
	durable_world_check(!R.can_merge(W) && !R.bleeding(), "restored wound behavior changed")
	F = null
	map_storage.clear_bookkeeping()

/proc/wound_restore_reject(case_name, key, value, omit = FALSE)
	var/obj/item/organ/external/wound_restore_probe/O = new
	var/datum/wound/lost_limb/W = new(O, DROPLIMB_EDGE, FALSE)
	var/savefile/F = new("invalid-[case_name].sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	var/ref = map_storage.BuildVarDirectory(F, W)
	if(omit)
		F.cd = map_storage.entry_path(F, ref)
		F.dir -= key
	else
		F["[map_storage.entry_path(F, ref)]/[key]"] << map_storage.encode_saved_value(F, value)
	F = null
	map_storage.clear_bookkeeping()
	F = new("invalid-[case_name].sav")
	var/rejected = FALSE
	try
		map_storage.Load_Entry(F, ref)
	catch(var/exception/E)
		rejected = findtext(E.file, "wound.dm") > 0
	durable_world_check(rejected, "invalid saved lost-limb wound accepted: [case_name]")
	F = null
	map_storage.clear_bookkeeping()

// Saved limbs are often first reached through another limb's field, with no
// holder yet. Their owner arrives as a later field, so import must not let the
// ordinary orphan cleanup delete them. A fresh orphan still cleans itself up.
/proc/organ_restore_case()
	var/savefile/F = new("organ-graph.sav")
	F["/format_version"] << 2
	F["[map_storage.entry_path(F, 1)]/type"] << /obj/item/organ/external/chest
	F["[map_storage.entry_path(F, 1)]/children"] << list("kind" = "list", "ref" = 998)
	F["/lists/998/length"] << 1
	F["/lists/998/1/key"] << list("kind" = "entry", "ref" = 2)
	F["/lists/998/1/value"] << list("kind" = "value", "value" = null)
	F["[map_storage.entry_path(F, 2)]/type"] << /obj/item/organ/external/groin
	F["[map_storage.entry_path(F, 2)]/parent"] << list("kind" = "entry", "ref" = 1)
	F = null
	map_storage.clear_bookkeeping()
	F = new("organ-graph.sav")
	var/obj/item/organ/external/chest/R = map_storage.Load_Entry(F, 1)
	durable_world_check(istype(R) && !QDELETED(R), "saved limb deleted itself during import")
	var/obj/item/organ/external/groin/G = length(R.children) == 1 ? R.children[1] : null
	durable_world_check(istype(G) && !QDELETED(G), "field-referenced saved limb deleted itself during import")
	durable_world_check(G.parent == R, "saved limb parent link changed")
	durable_world_check(persistence_saved_atom_construction == 0, "organ import guard leaked")
	F = null
	map_storage.clear_bookkeeping()
	var/obj/item/organ/external/groin/orphan = new
	durable_world_check(QDELETED(orphan), "ordinary orphan limb no longer cleans itself up")

/world/New()
	world.OpenPort(0)
	try
		for(var/encoding in list("roundtrip", "typed", "legacy"))
			for(var/method in list(DROPLIMB_EDGE, DROPLIMB_BLUNT, DROPLIMB_BURN))
				for(var/clean in list(FALSE, TRUE))
					wound_restore_case(method, clean, encoding)
		wound_restore_reject("missing-stages", "stages", null, TRUE)
		wound_restore_reject("null-stages", "stages", null)
		wound_restore_reject("non-list-stages", "stages", 3)
		wound_restore_reject("empty-stages", "stages", list())
		wound_restore_reject("numeric-stage", "stages", list(7))
		wound_restore_reject("empty-stage-name", "stages", list("" = 5))
		wound_restore_reject("non-numeric-damage", "stages", list("bad" = "high"))
		wound_restore_reject("negative-damage", "stages", list("bad" = -1))
		wound_restore_reject("invalid-stage-index", "current_stage", 99)
		wound_restore_reject("fractional-stage-index", "current_stage", 1.5)
		wound_restore_reject("invalid-amount", "amount", 0)
		wound_restore_reject("wrong-description", "desc", "wrong stump")
		wound_restore_reject("wrong-minimum-damage", "min_damage", -1)
		organ_restore_case()
		text2file(json_encode(list("done" = TRUE, "checks" = durable_probe_checks, "roundtrips" = 18)), "metadata-result.json")
	catch(var/exception/E)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[E]", "source" = E.file, "line" = E.line)), "metadata-result.json")
	del(world)
