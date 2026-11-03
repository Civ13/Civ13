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

// A body saved after a pre-guard load keeps its self-deleted limbs as null or
// deleted entries in `organs`. Load repair rebuilds exactly those limbs, keeps
// a real stump and leaves a clean body untouched.
/mob/living/human/organ_repair_probe
	var/regenerated = 0
/mob/living/human/organ_repair_probe/New()
	return
/mob/living/human/organ_repair_probe/regenerate_appearance()
	regenerated++

/proc/organ_repair_body()
	var/mob/living/human/organ_repair_probe/H = new
	H.species = new /datum/species/human
	H.organs = list()
	H.organs_by_name = list()
	H.internal_organs = list()
	H.internal_organs_by_name = list()
	for(var/tag in H.species.has_limbs)
		var/list/data = H.species.has_limbs[tag]
		var/path = data["path"]
		new path(H)
	return H

/proc/organ_repair_case()
	var/mob/living/human/organ_repair_probe/clean = organ_repair_body()
	durable_world_check(clean.organs.len == 11 && clean.repair_import_lost_limbs() == 0 && clean.organs.len == 11 && !clean.regenerated, "intact body changed by limb repair")
	var/mob/living/human/organ_repair_probe/H = organ_repair_body()
	var/obj/item/organ/external/chest = H.organs_by_name["chest"]
	var/obj/item/organ/external/left_foot = H.organs_by_name["l_foot"]
	// Pre-guard import: the deleted limbs never left `organs`.
	var/list/damaged = list(chest)
	for(var/tag in list("groin", "head", "l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "r_foot"))
		var/obj/item/organ/external/E = H.organs_by_name[tag]
		E.owner = null
		E.children = null
		qdel(E)
		damaged += (tag == "head" ? null : E)
	// A real amputation leaves a stump in the body.
	var/obj/item/organ/external/stump/S = new(H, FALSE, left_foot)
	H.organs -= left_foot
	left_foot.loc = null
	damaged += S
	H.organs = damaged
	durable_world_check(H.repair_import_lost_limbs() == 9, "self-deleted limbs not rebuilt")
	var/intact = 0
	for(var/tag in H.species.has_limbs)
		var/obj/item/organ/external/E = H.organs_by_name[tag]
		if(E && !QDELETED(E) && E.loc == H && E.owner == H && (E in H.organs))
			intact++
	durable_world_check(intact == 11 && H.organs.len == 11 && !(null in H.organs), "repaired body limbs incomplete")
	durable_world_check(H.organs_by_name["l_foot"] == S && H.organs_by_name["chest"] == chest, "limb repair replaced a surviving limb or stump")
	var/obj/item/organ/external/arm = H.organs_by_name["l_arm"]
	var/obj/item/organ/external/hand = H.organs_by_name["l_hand"]
	durable_world_check(hand.parent == arm && (hand in arm.children) && arm.parent == chest, "rebuilt limb hierarchy broken")
	durable_world_check(H.regenerated == 1 && H.repair_import_lost_limbs() == 0, "limb repair appearance or idempotence changed")

/world/New()
	world.OpenPort(0)
	try
		for(var/encoding in list("roundtrip", "typed", "legacy"))
			for(var/method in list(DROPLIMB_EDGE, DROPLIMB_BLUNT, DROPLIMB_BURN))
				for(var/clean in list(FALSE, TRUE))
					wound_restore_case(method, clean, encoding)
		for(var/key in list("stages", "desc_list", "damage_list"))
			wound_restore_reject_missing(key)
		organ_restore_case()
		organ_repair_case()
		text2file(json_encode(list("done" = TRUE, "checks" = durable_probe_checks, "roundtrips" = 18)), "metadata-result.json")
	catch(var/exception/E)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[E]", "source" = E.file, "line" = E.line)), "metadata-result.json")
	del(world)
