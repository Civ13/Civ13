// Diagnostic-only inventory. Never produces an accepted snapshot or follows
// unknown/external datums. Report schema paths/categories, not player values.
/datum/body_fixture_diagnostic
	var/list/findings = list()
	var/list/owned = list()
	var/list/queue = list()
	var/list/lists_seen = list()
	var/edges = 0
	var/map_storage/train_body_graph/codec
/datum/body_fixture_diagnostic/proc/note(context, category)
	if(findings.len < 32) findings |= "[context]: [category]"
/datum/body_fixture_diagnostic/proc/inspect_value(value, context, depth = 0)
	edges++
	if(edges > 8192 || depth > 16)
		note("diagnostic", "budget exceeded")
		return
	if(isnull(value) || isnum(value) || istext(value) || ispath(value)) return
	if(islist(value))
		if(lists_seen.Find(value)) return
		lists_seen += list(value)
		var/list/L = value
		if(L.len > 1024)
			note(context, "list exceeds diagnostic bound")
			return
		for(var/i = 1, i <= L.len, i++)
			var/key = L[i]
			inspect_value(key, context, depth + 1)
			if(istext(key)) inspect_value(L[key], context, depth + 1)
			else if(!isnull(key) && !isnum(key)) note(context, "nontext associative values not inspected")
		return
	if(istype(value, /datum/species))
		if(!codec.canonical_species_valid(value)) note(context, "noncanonical species")
		return
	if(istype(value, /datum))
		var/datum/D = value
		if(!codec.admitted_type(D.type))
			note(context, "unsupported [D.type]")
			return
		if(istype(D, /atom/movable) && !(D in owned))
			note(context, "external movable [D.type]")
			return
		if(!(D in queue))
			if(queue.len >= 512)
				note("diagnostic", "node budget exceeded")
				return
			queue += D
		return
	note(context, isicon(value) ? "native icon resource" : "native nonportable value")
/datum/body_fixture_diagnostic/proc/inspect_body(mob/living/body)
	codec = new
	owned = list(body)
	for(var/i = 1, i <= owned.len && i <= 512, i++)
		var/atom/movable/A = owned[i]
		for(var/atom/movable/child in A.contents)
			if(owned.len >= 512) break
			if(!(child in owned)) owned += child
	queue = owned.Copy()
	for(var/i = 1, i <= queue.len && i <= 512 && edges <= 8192, i++)
		var/datum/D = queue[i]
		if(!codec.admitted_type(D.type))
			note("[D.type]", "unsupported contained type")
			continue
		if(D.type == /matrix) continue
		var/list/fields = D.get_saved_vars()
		for(var/field in fields)
			if(!(field in D.vars))
				note("[D.type].[field]", "saved field not present")
				continue
			if(D.persistence_runtime_var(field) || field in list("loc", "locs", "pixloc", "contents", "vars", "type", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey")) continue
			if(field == "filters" && istype(D, /atom))
				var/atom/A = D
				if(!length(A.filters)) continue
			if(istype(D, /obj/item/organ/external) && field in list("mob_icon", "icon") && isicon(D.vars[field])) continue
			inspect_value(D.vars[field], "[D.type].[field]")
	return findings

// Full production bodies; no replacement constructors/get_saved_vars hooks.
// No restoration, account login, world save, listeners or network clients.
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
	return "Closed body capture fixture"
var/global/list/body_checks = list()
var/global/list/body_failed = list()
var/global/list/body_capture_errors = list()
var/global/list/body_diagnostics = list()
var/global/body_runtime_error = FALSE
/world/Error(exception/E)
	body_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()
/proc/body_check(label, passed)
	body_checks += list(list("label" = label, "passed" = !!passed))
	if(!passed) body_failed += label

// Fixture-only decoder: returns text for paths, never instantiates anything.
/proc/body_wire_value(list/V, depth = 0)
	if(!islist(V) || depth > 32) throw EXCEPTION("Malformed fixture wire")
	if(V["tag"] == "scalar" || V["tag"] == "path") return V["value"]
	if(V["tag"] != "list") throw EXCEPTION("Unknown fixture wire tag")
	var/list/out = list()
	for(var/list/row in V["rows"])
		var/key = body_wire_value(row[1], depth + 1)
		var/value = body_wire_value(row[2], depth + 1)
		out.len++
		out[out.len] = key
		if(!isnum(key) && !isnull(key)) out[key] = value
	return out
/proc/body_ref_valid(ref, limit)
	return isnum(ref) && ref >= 1 && ref <= limit && ref == round(ref)
/proc/body_value_closed(value, entries, lists)
	if(!islist(value)) return TRUE
	var/list/V = value
	switch(V["kind"])
		if("body_local_icon") return V.len == 2 && isnum(V["ref"]) && V["ref"] >= 1
		if("body_species") return V.len == 2 && V["name"] == "Human"
		if("body_empty_filters") return V.len == 1
		if("value") return !islist(V["value"])
		if("entry") return body_ref_valid(V["ref"], entries)
		if("list") return body_ref_valid(V["ref"], lists)
	return FALSE
/proc/body_document_closed(list/doc, human = FALSE)
	if(!islist(doc) || doc["schema"] != "train-body-1") return FALSE
	var/list/entries = doc["entries"]
	var/list/lists = doc["lists"]
	if(!islist(entries) || !islist(lists) || !body_ref_valid(doc["root"], entries.len)) return FALSE
	var/list/root = entries[doc["root"]]
	if(!root["type"] || !root["name"]) return FALSE
	if(human && (!root["organs"] || !root["dna"])) return FALSE
	for(var/list/fields in entries)
		if(!fields["type"]) return FALSE
		for(var/field in fields)
			var/value = body_wire_value(fields[field])
			if(field == "content")
				if(!islist(value)) return FALSE
				for(var/chunk in value)
					for(var/ref in params2list(chunk))
						if(!body_ref_valid(text2num(ref), entries.len)) return FALSE
			else if(!body_value_closed(value, entries.len, lists.len)) return FALSE
	for(var/list/node in lists)
		if(node["scalar"])
			var/list/scalars = body_wire_value(node["scalar"])
			var/list/keys = scalars["keys"]
			var/list/values = scalars["values"]
			if(scalars["kind"] != "scalars" || !islist(keys) || !islist(values) || keys.len != scalars["length"] || values.len != keys.len) return FALSE
			for(var/i = 1, i <= keys.len, i++)
				if(islist(keys[i]) || islist(values[i])) return FALSE
			continue
		for(var/list/row in node["rows"])
			if(!body_value_closed(body_wire_value(row[1]), entries.len, lists.len) || !body_value_closed(body_wire_value(row[2]), entries.len, lists.len)) return FALSE
	return TRUE
// Inspect actual exported values, not just the presence of some entries.
/proc/body_export_has(list/doc, type_name, field, expected)
	if(!islist(doc)) return FALSE
	for(var/list/fields in doc["entries"])
		if(body_wire_value(fields["type"]) != type_name || !fields[field]) continue
		var/value = body_wire_value(fields[field])
		if(islist(value))
			var/list/envelope = value
			if(envelope["kind"] != "value") continue
			value = envelope["value"]
		if(value == expected) return TRUE
	return FALSE
// isolated_startup suppresses global_init/New; restore only production data
// catalogs needed by real body constructors, not services/world startup.
// Same isolated metadata fixture pattern as human_corpse_decay: real metadata
// fields, no production map timers. Human nomads_spawn callback remains intact.
/obj/map_metadata/train_body_fixture
	ID = "TRAIN_BODY_FIXTURE"
/obj/map_metadata/train_body_fixture/New()
	map = src

/proc/body_fixture_catalogs()
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	movementMachine = new
	var/process/garbage/garbage = new
	garbage.setup()
	makeDatumRefLists()
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	populate_material_list()
	new /obj/map_metadata/train_body_fixture
	if(!all_species["Human"] || !all_languages.len || !male_body_builds["Default"] || !female_body_builds["Default"] || !chemical_reagents_list["blood"])
		throw EXCEPTION("Production body fixture catalogs unavailable")

/proc/body_capture_probe()
	var/map_storage/train_body_graph/G = new
	var/datum/species/human/canonical = all_species["Human"]
	body_check("canonical_species_definition_admitted", G.canonical_species_valid(canonical))
	var/datum/species/human/noncanonical = new
	body_check("noncanonical_species_rejected", !G.canonical_species_valid(noncanonical))
	var/old_brute_mod = canonical.brute_mod
	canonical.brute_mod = old_brute_mod + 0.5
	body_check("mutated_species_rejected", !G.canonical_species_valid(canonical))
	canonical.brute_mod = old_brute_mod
	var/mob/living/human/H = new(locate(3, 3, 1))
	H.persistence_owner_ckey = "trainbodyfixture"
	// Let real constructor icon/blood callbacks settle before snapshotting.
	sleep(20)
	body_check("post_constructor_species_admitted", G.canonical_species_valid(canonical))
	var/list/head_row = canonical.has_limbs["head"]
	var/original_descriptor = head_row["descriptor"]
	head_row["descriptor"] = "modified descriptor"
	body_check("modified_limb_descriptor_rejected", !G.canonical_species_valid(canonical) && findtext(G.metadata_error, "has_limbs"))
	head_row["descriptor"] = original_descriptor
	var/obj/item/organ/external/head/source_head = H.get_organ("head")
	var/obj/item/stack/teeth/human/source_teeth = source_head ? locate(/obj/item/stack/teeth/human) in source_head : null
	if(source_teeth) source_teeth.amount = 23
	var/obj/item/organ/external/arm = H.get_organ("l_arm")
	if(arm)
		arm.brute_dam = 17
		arm.createwound(CUT, 17)
	var/custom_icon_pixel = null
	var/custom_atom_icon_pixel = null
	if(arm && arm.mob_icon)
		arm.mob_icon.DrawBox("#13a5c7", 1, 1, 1, 1)
		custom_icon_pixel = arm.mob_icon.GetPixel(1, 1)
		var/icon/independent_atom_icon = icon(arm.icon)
		independent_atom_icon.DrawBox("#2468ac", 1, 1, 1, 1)
		arm.icon = independent_atom_icon
		custom_atom_icon_pixel = independent_atom_icon.GetPixel(1, 1)
	var/obj/item/extraction_salvage/cargo = new(H)
	cargo.name = "Body fixture carried item"
	body_check("real_human_has_organs_and_wound", arm && arm.wounds.len && H.organs.len && H.dna && cargo.loc == H)
	var/datum/body_fixture_diagnostic/diagnostic = new
	body_diagnostics["human"] = diagnostic.inspect_body(H)
	var/human_text = G.capture_body(H)
	body_capture_errors["human"] = G.body_error
	body_check("owned_injured_human_capture", istext(human_text))
	var/list/human_doc = istext(human_text) ? json_decode(human_text) : null
	body_check("human_wire_closed", body_document_closed(human_doc, TRUE))
	body_check("exported_arm_damage_and_inventory", arm && body_export_has(human_doc, "[arm.type]", "brute_dam", 17) && body_export_has(human_doc, "[cargo.type]", "name", cargo.name))
	var/list/missing = istext(human_text) ? json_decode(human_text) : list()
	if(missing["entries"])
		var/list/root = missing["entries"][missing["root"]]
		root -= "organs"
	body_check("missing_required_organs_rejected", !body_document_closed(missing, TRUE))
	var/list/dangling = istext(human_text) ? json_decode(human_text) : list()
	if(dangling["entries"])
		var/list/root = dangling["entries"][dangling["root"]]
		root["organs"] = G.to_wire(list("kind" = "list", "ref" = 999999))
	body_check("dangling_reference_rejected", !body_document_closed(dangling, TRUE))
	if(arm && arm.mob_icon) arm.mob_icon.DrawBox("#c7a513", 1, 1, 1, 1)
	var/obj/effect/train_body_quarantine/Q = G.restore_local_capture(human_text)
	body_check("owned_body_quarantined", Q && Q.body && Q.body.loc == Q && !Q.body.client && !Q.loc)
	var/mob/living/human/restored = Q ? Q.body : null
	body_check("species_registry_identity_roundtrip", restored && restored.species == canonical)
	var/obj/item/organ/external/restored_arm = restored ? restored.get_organ("l_arm") : null
	body_check("injury_roundtrip", restored_arm && restored_arm.brute_dam == 17 && restored_arm.wounds.len)
	body_check("custom_organ_icon_snapshot_roundtrip", restored_arm && restored_arm.mob_icon && custom_icon_pixel && restored_arm.mob_icon.GetPixel(1, 1) == custom_icon_pixel && arm.mob_icon.GetPixel(1, 1) != custom_icon_pixel)
	var/icon/restored_atom_icon = restored_arm ? icon(restored_arm.icon) : null
	body_check("distinct_organ_icon_resource_roundtrip", restored_atom_icon && custom_atom_icon_pixel && restored_atom_icon.GetPixel(1, 1) == custom_atom_icon_pixel && custom_atom_icon_pixel != custom_icon_pixel)
	var/datum/save_export_frame/wrong_icon_frame = new
	wrong_icon_frame.source = cargo
	wrong_icon_frame.current_field = "icon"
	var/wrong_icon_rejected = FALSE
	try
		G.capture_organ_icon(arm.mob_icon, wrong_icon_frame)
	catch(var/exception/icon_error)
		wrong_icon_rejected = findtext("[icon_error]", "Unsupported native icon field")
	body_check("nonorgan_icon_field_rejected", wrong_icon_rejected)
	var/obj/item/organ/external/head/restored_head = restored ? restored.get_organ("head") : null
	var/obj/item/stack/teeth/human/restored_teeth = restored_head ? locate(/obj/item/stack/teeth/human) in restored_head : null
	body_check("human_teeth_count_roundtrip", source_teeth && restored_teeth && source_teeth.amount == 23 && restored_teeth.amount == 23)
	body_check("local_capture_one_shot", !G.restore_local_capture(human_text))
	body_check("source_injury_inventory_unchanged", arm && arm.brute_dam == 17 && arm.wounds.len && cargo.loc == H)
	var/mob/living/simple_animal/sheep/S = new(locate(5, 5, 1))
	S.transform = matrix(1.25, 0.125, 3, -0.25, 0.75, -4)
	var/animal_text = G.capture_body(S)
	body_capture_errors["animal"] = G.body_error
	body_check("real_sheep_capture", istext(animal_text))
	body_check("animal_wire_closed", istext(animal_text) && body_document_closed(json_decode(animal_text)))
	var/obj/effect/train_body_quarantine/animal_Q = G.restore_local_capture(animal_text)
	var/matrix/restored_transform = animal_Q && animal_Q.body ? animal_Q.body.transform : null
	body_check("six_matrix_coefficients_roundtrip", restored_transform && restored_transform.a == 1.25 && restored_transform.b == 0.125 && restored_transform.c == 3 && restored_transform.d == -0.25 && restored_transform.e == 0.75 && restored_transform.f == -4)
	body_check("matrix_components_bounded_numeric", !G.matrix_component_valid(1000001) && !G.matrix_component_valid("1") && G.matrix_component_valid(-0.25))
	body_check("empty_filters_roundtrip", animal_Q && animal_Q.body && !length(animal_Q.body.filters))
	S.filters = list(filter(type = "blur", size = 1))
	var/filtered_text = G.capture_body(S)
	body_check("custom_filters_rejected", !filtered_text && findtext(G.body_error, "Nonempty native filters"))
	S.filters = list()
	H.stat = DEAD
	var/corpse_text = G.capture_body(H)
	body_capture_errors["corpse"] = G.body_error
	body_check("real_human_corpse_capture", istext(corpse_text))
	body_check("corpse_wire_closed", istext(corpse_text) && body_document_closed(json_decode(corpse_text), TRUE))
	body_check("exported_dead_state", istext(corpse_text) && body_export_has(json_decode(corpse_text), "[H.type]", "stat", DEAD))
	var/obj/effect/train_body_quarantine/dead_Q = G.restore_local_capture(corpse_text)
	body_check("corpse_roundtrip_stays_dead", dead_Q && dead_Q.body && dead_Q.body.stat == DEAD)
	var/external_ref_rejected = FALSE
	try
		G.encode_saved_value(new /savefile, locate(1, 1, 1))
	catch(var/exception/E)
		external_ref_rejected = !!findtext("[E]", "external world/session state")
	body_check("external_turf_reference_rejected", external_ref_rejected)
	H.stat = CONSCIOUS
	H.persistence_owner_ckey = null
	body_check("unowned_human_not_healed_policy", !G.rejuvenate_unowned_human_on_load())
	body_check("no_capture_removed_sources", H && S && cargo && cargo.loc == H)
/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.destroyed_event = new
	try
		body_fixture_catalogs()
		body_capture_probe()
	catch(var/exception/E)
		body_runtime_error = TRUE
		world.log << "Fixture aborted: [E] at [E.file]:[E.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = body_checks.len, "failed_labels" = body_failed, "runtime_error" = body_runtime_error, "capture_errors" = body_capture_errors, "diagnostics" = body_diagnostics, "checks" = body_checks)), "result.json")
	world.log << "COMPLETE train body capture fixture"
	del(world)
