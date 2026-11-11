// Closed-world body adapter for the production persistence graph codec.
// Not a world save, not ExportText, and never an arbitrary ImportText endpoint.
// Local capture-bound quarantine roundtrip only, NOT remote import authority.
// No client/account attachment or source deletion. Not included in production DME.
#define TRAIN_BODY_NODES 1024
#define TRAIN_BODY_EDGES 16384
#define TRAIN_BODY_BYTES 600000

/map_storage/train_body_graph
	var/list/body_members = list()
	var/capture_tick = null
	var/wire_edges = 0
	var/body_error = null
	var/tmp/local_snapshot = null
	var/tmp/local_restore_used = FALSE
	var/tmp/datum/body_build/local_body_build
	var/tmp/datum/species/human/local_species
	var/tmp/datum/species/human/species_baseline
	var/tmp/metadata_checks = 0
	var/tmp/metadata_error = null
	var/tmp/list/local_icon_sources = list()
	var/tmp/list/local_icon_copies = list()
	var/tmp/list/restored_icon_copies = list()

/map_storage/train_body_graph/proc/admitted_type(path)
	if(path == /mob/living/human || ispath(path, /mob/living/simple_animal)) return TRUE
	if(ispath(path, /obj/item/organ)) return TRUE
	if(path == /obj/item/stack/teeth/human || path == /matrix) return TRUE
	if(path == /datum/reagents/metabolism || path == /datum/surgery_status) return TRUE
	if(ispath(path, /datum/wound) || ispath(path, /datum/reagent) || path == /datum/reagents || path == /datum/dna || path == /datum/corpse_decay_record) return TRUE
	var/datum/extraction_equipment_codec/equipment = new
	return equipment.supported(path)

/map_storage/train_body_graph/save_work_check()
	if(!isnull(capture_tick) && world.time != capture_tick)
		throw EXCEPTION("Body capture crossed a tick; source must remain unchanged")
	if(saving_reference_pins.len + saving_list_pins.len > TRAIN_BODY_NODES || wire_edges > TRAIN_BODY_EDGES)
		throw EXCEPTION("Body graph budget exceeded")

// Diagnostic paths/field names only: never character names, values or ckeys.
/map_storage/train_body_graph/proc/body_source_context()
	if(!saving_export_stack.len) return "root"
	var/datum/save_export_frame/frame = saving_export_stack[saving_export_stack.len]
	if(!frame || !frame.source) return "unknown"
	return "[frame.source.type].[frame.current_field]"

/map_storage/train_body_graph/BuildVarDirectory(savefile/F, datum/A, contents = 0, traversal = FALSE, datum/human_request = null)
	save_work_check()
	if(A && A.type == /matrix) return capture_matrix(F, A)
	if(traversal && (istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))) return 0
	if(!A || !admitted_type(A.type)) throw EXCEPTION("Unsupported body graph type: [A ? A.type : null] from [body_source_context()]")
	if(istype(A, /atom/movable) && !body_members[A])
		throw EXCEPTION("Body graph references an external movable")
	if(!A.should_save) throw EXCEPTION("Body graph contains an unsaved datum")
	if(A.type == /datum/surgery_status)
		var/datum/surgery_status/surgery = A
		if(!islist(surgery.in_progress) || surgery.in_progress.len) throw EXCEPTION("Active or malformed surgery cannot transfer")
	if(A.type == /datum/reagents/metabolism)
		var/datum/reagents/metabolism/metabolism = A
		if(!metabolism.parent || !body_members[metabolism.parent] || metabolism.my_atom != metabolism.parent || !(metabolism.metabolism_class in list(CHEM_TOUCH, CHEM_INGEST, CHEM_BLOOD)))
			throw EXCEPTION("Metabolism holder/class leaves body profile")
	return ..()

// Native transforms have exactly six coefficients. No generic native vars or
// arbitrary datum subtype admission; aliases retain production entry identity.
/map_storage/train_body_graph/proc/matrix_component_valid(value)
	return isnum(value) && value == value && abs(value) <= 1000000

/map_storage/train_body_graph/proc/capture_matrix(savefile/F, matrix/M)
	var/existing = saving_references[M]
	if(existing && saving_reference_pins[existing] == M) return existing
	var/list/components = list("a" = M.a, "b" = M.b, "c" = M.c, "d" = M.d, "e" = M.e, "f" = M.f)
	for(var/field in components)
		if(!matrix_component_valid(components[field])) throw EXCEPTION("Unsupported matrix coefficient")
	var/ref = saving_reference_pins.len + 1
	saving_reference_pins += M
	saving_references[M] = ref
	save_work_check()
	var/path = entry_path(F, ref)
	F["[path]/type"] << /matrix
	for(var/field in components)
		F["[path]/[field]"] << components[field]
	return ref

// Canonical metadata is a local registry dependency, never a cloned HUD graph.
// Only the audited Human constructor (data-only HUD and unarmed prototypes) is
// used for a baseline. Arbitrary species subclasses cannot select constructors.
/map_storage/train_body_graph/proc/metadata_mismatch(context)
	if(!metadata_error) metadata_error = context
	return FALSE

// create_organs() fills only descriptor with the instantiated limb's default
// name (species.dm:715). Accept that exact derived addition, not arbitrary
// modified limb paths, names, membership or extra data.
/map_storage/train_body_graph/proc/species_limbs_equal(list/A, list/B, context)
	if(!islist(A) || !islist(B) || A.len != B.len) return metadata_mismatch(context)
	for(var/i = 1, i <= A.len, i++)
		if(A[i] != B[i]) return metadata_mismatch("[context].keys")
		var/list/row = A[A[i]]
		var/list/base = B[B[i]]
		if(!islist(row) || !islist(base) || row["path"] != base["path"]) return metadata_mismatch("[context].[i].path")
		var/path = base["path"]
		if(!ispath(path, /obj/item/organ/external)) return metadata_mismatch("[context].[i].path")
		if(row.len < 1 || row.len > 2) return metadata_mismatch("[context].[i].fields")
		for(var/field in row)
			if(field != "path" && field != "descriptor") return metadata_mismatch("[context].[i].fields")
		if("descriptor" in row)
			if(row["descriptor"] != initial(path:name)) return metadata_mismatch("[context].[i].descriptor")
	return TRUE

/map_storage/train_body_graph/proc/metadata_equal(a, b, depth = 0, context = "species")
	metadata_checks++
	if(depth > 16 || metadata_checks > 8192) return metadata_mismatch("[context].budget")
	if(islist(a) || islist(b))
		if(!islist(a) || !islist(b)) return metadata_mismatch(context)
		var/list/A = a
		var/list/B = b
		if(A.len != B.len) return metadata_mismatch("[context].length")
		for(var/i = 1, i <= A.len, i++)
			if(!metadata_equal(A[i], B[i], depth + 1, "[context].[i].key")) return FALSE
			if(!isnum(A[i]) && !isnull(A[i]))
				if(!metadata_equal(A[A[i]], B[B[i]], depth + 1, "[context].[i].value")) return FALSE
		return TRUE
	if(istype(a, /datum) || istype(b, /datum))
		var/datum/A = a
		var/datum/B = b
		if(!istype(A) || !istype(B) || A.type != B.type) return metadata_mismatch("[context].type")
		if(A.type != /datum/species/human && A.type != /datum/hud_data && !istype(A, /datum/unarmed_attack)) return metadata_mismatch("[context].unsupported")
		for(var/field in A.vars)
			if(field == "vars" || (A.type == /datum/species/human && field == "race_key")) continue
			if(A.type == /datum/species/human && field == "has_limbs")
				if(!species_limbs_equal(A.vars[field], B.vars[field], "[context].has_limbs")) return FALSE
				continue
			if(!metadata_equal(A.vars[field], B.vars[field], depth + 1, "[context].[field]")) return FALSE
		return TRUE
	if(a != b) return metadata_mismatch(context)
	return TRUE

/map_storage/train_body_graph/proc/canonical_species_valid(datum/species/S)
	if(!S || S.type != /datum/species/human || all_species["Human"] != S) return FALSE
	var/list/species_types = typesof(/datum/species) - /datum/species
	if(S.race_key != species_types.Find(/datum/species/human)) return FALSE
	if(!species_baseline) species_baseline = new /datum/species/human
	metadata_checks = 0
	metadata_error = null
	return metadata_equal(S, species_baseline)

// Body-build definitions have no constructor-written fields. Only exact local
// registry identity with all declared values still at compiled defaults is valid.
/map_storage/train_body_graph/proc/canonical_body_build_valid(datum/body_build/B)
	if(!istype(B)) return FALSE
	var/list/catalog
	if(B.gender == MALE) catalog = male_body_builds
	else if(B.gender == FEMALE) catalog = female_body_builds
	else return FALSE
	if(catalog[B.name] != B) return FALSE
	for(var/field in B.vars)
		if(field == "vars") continue
		if(B.vars[field] != initial(B.vars[field])) return FALSE
	return TRUE

// Native icon copies are process-local capabilities, never resource payloads.
// Keep states/directions/frames/custom pixels intact; do not flatten to pixels.
// atom.icon may be a native resource while mob_icon is an /icon object. Keep
// their distinct captured values, rather than assume assignment retained alias.
/map_storage/train_body_graph/proc/capture_organ_icon(value, datum/save_export_frame/frame)
	if(!frame || !istype(frame.source, /obj/item/organ/external) || !(frame.current_field in list("mob_icon", "icon")))
		throw EXCEPTION("Unsupported native icon field from [body_source_context()]")
	var/obj/item/organ/external/O = frame.source
	var/bound_atom_resource = frame.current_field == "icon" && isfile(value) && value == O.icon
	if((!isicon(value) && !bound_atom_resource) || istext(value)) throw EXCEPTION("Not a native organ icon resource")
	if(frame.current_field == "mob_icon" && value != O.mob_icon) throw EXCEPTION("Native icon differs from organ mob_icon")
	if(frame.current_field == "icon" && value != O.icon) throw EXCEPTION("Native icon differs from organ icon")
	var/ref = local_icon_sources.Find(value)
	if(!ref)
		if(local_icon_copies.len >= 64) throw EXCEPTION("Too many local organ icons")
		// Input is the current native field, never a filename from the packet.
		var/icon/I = icon(value)
		if(I.Width() < 1 || I.Height() < 1 || I.Width() > 128 || I.Height() > 128 || length(icon_states(I)) > 64)
			throw EXCEPTION("Organ icon exceeds local copy bounds")
		local_icon_sources += value
		local_icon_copies += I
		ref = local_icon_copies.len
	return list("kind" = "body_local_icon", "ref" = ref)

/map_storage/train_body_graph/decode_saved_value(savefile/F, list/value)
	if(islist(value) && value["kind"] == "body_build")
		if(value.len != 3 || !local_body_build || value["name"] != local_body_build.name || value["gender"] != local_body_build.gender || !canonical_body_build_valid(local_body_build))
			throw EXCEPTION("Canonical local body-build changed")
		return local_body_build
	if(islist(value) && value["kind"] == "body_local_icon")
		var/ref = value["ref"]
		if(value.len != 2 || !body_ref(ref, local_icon_copies.len)) throw EXCEPTION("Invalid local icon reference")
		if(!restored_icon_copies["[ref]"]) restored_icon_copies["[ref]"] = icon(local_icon_copies[ref])
		return restored_icon_copies["[ref]"]
	if(islist(value) && value["kind"] == "body_species")
		if(value.len != 2 || value["name"] != "Human" || !local_species || all_species["Human"] != local_species)
			throw EXCEPTION("Canonical local species changed")
		return local_species
	if(islist(value) && value["kind"] == "body_empty_filters")
		if(value.len != 1) throw EXCEPTION("Malformed empty filter marker")
		return list()
	return ..()

/map_storage/train_body_graph/encode_saved_value(savefile/F, value)
	save_work_check()
	wire_edges++
	if(istype(value, /datum/body_build))
		if(!canonical_body_build_valid(value) || (local_body_build && local_body_build != value)) throw EXCEPTION("Noncanonical or modified body-build definition")
		local_body_build = value
		return list("kind" = "body_build", "name" = local_body_build.name, "gender" = local_body_build.gender)
	if(istype(value, /datum/species))
		if(local_species != value)
			if(!canonical_species_valid(value)) throw EXCEPTION("Noncanonical or modified species definition at [metadata_error]")
			local_species = value
		return list("kind" = "body_species", "name" = "Human")
	var/datum/save_export_frame/frame = saving_export_stack.len ? saving_export_stack[saving_export_stack.len] : null
	if(istype(value, /icon)) return capture_organ_icon(value, frame)
	if(frame && istype(frame.source, /obj/item/organ/external) && frame.current_field == "icon" && (isicon(value) || isfile(value)))
		return capture_organ_icon(value, frame)
	if(frame && frame.current_field == "filters" && istype(frame.source, /atom))
		var/atom/owner = frame.source
		if(length(owner.filters) || length(value)) throw EXCEPTION("Nonempty native filters are not supported")
		return list("kind" = "body_empty_filters")
	if(isturf(value) || isarea(value) || istype(value, /obj/map_metadata) || istype(value, /client))
		throw EXCEPTION("Body graph references external world/session state")
	if(!isnull(value) && !isnum(value) && !istext(value) && !ispath(value) && !islist(value) && !istype(value, /datum))
		throw EXCEPTION("Body graph contains a nonportable resource from [body_source_context()]")
	if(islist(value))
		var/list/L = value
		if(L.len > TRAIN_BODY_EDGES) throw EXCEPTION("Body graph list exceeds budget")
	return ..()

/map_storage/train_body_graph/level_link_target(datum/source, key, value)
	// Keep all supported references inside this one manifest. Never turn an
	// external movable into a world coordinate or another world's level ref.
	return FALSE

/map_storage/train_body_graph/drop_cross_level_reference(atom/movable/target)
	if(!body_members[target]) throw EXCEPTION("Body reference leaves its containment graph")
	return FALSE

/map_storage/train_body_graph/proc/enroll_body(mob/living/body)
	if(!istype(body) || !admitted_type(body.type)) throw EXCEPTION("Unsupported body root")
	var/list/queue = list(body)
	for(var/i = 1, i <= queue.len, i++)
		if(queue.len > TRAIN_BODY_NODES) throw EXCEPTION("Body containment exceeds budget")
		var/atom/movable/A = queue[i]
		if(body_members[A]) throw EXCEPTION("Body containment repeats an atom")
		if(!admitted_type(A.type) || !A.should_save) throw EXCEPTION("Unsupported body inventory: [A.type] in [A.loc ? A.loc.type : null]; should_save=[A.should_save]")
		body_members[A] = TRUE
		for(var/atom/movable/child in A.contents)
			// Lighting overlays are deliberately runtime-only in world saves.
			if(istype(child, /atom/movable/lighting_overlay) || istype(child, /atom/movable/lighting_fullbright)) continue
			queue += child

// Native savefile values are encoded explicitly. A list is rows of keys and
// associations, so numeric keys, nulls and ordered lists never become JSON maps.
/map_storage/train_body_graph/proc/to_wire(value, depth = 0)
	wire_edges++
	if(depth > 32 || wire_edges > TRAIN_BODY_EDGES) throw EXCEPTION("Body wire exceeds budget")
	if(isnull(value) || isnum(value) || istext(value)) return list("tag" = "scalar", "value" = value)
	if(ispath(value)) return list("tag" = "path", "value" = "[value]")
	if(!islist(value)) throw EXCEPTION("Nonportable body save value")
	var/list/input = value
	if(input.len > TRAIN_BODY_EDGES) throw EXCEPTION("Body wire list too large")
	var/list/rows = list()
	for(var/i = 1, i <= input.len, i++)
		var/key = input[i]
		rows += list(list(to_wire(key, depth + 1), to_wire((isnum(key) || isnull(key)) ? null : input[key], depth + 1)))
	return list("tag" = "list", "rows" = rows)

/map_storage/train_body_graph/proc/capture_body(mob/living/body)
	body_error = null
	local_snapshot = null
	local_restore_used = FALSE
	local_species = null
	local_body_build = null
	local_icon_sources = list()
	local_icon_copies = list()
	restored_icon_copies = list()
	clear_bookkeeping()
	body_members = list()
	wire_edges = 0
	capture_tick = world.time
	try
		if(persistence_save_active()) throw EXCEPTION("World save is active")
		enroll_body(body)
		var/turf/body_turf = get_turf(body)
		saving_z = body_turf ? body_turf.z : 0
		if(!saving_z) throw EXCEPTION("Body is not on a world level")
		var/savefile/F = new
		F["/format_version"] << 3
		F["/value_format"] << 2
		var/root = BuildVarDirectory(F, body, 1)
		if(!root) throw EXCEPTION("Body root was not saved")
		// load_contents=FALSE and debug policies must not silently drop inventory.
		for(var/atom/movable/member in body_members)
			if(!saving_references[member]) throw EXCEPTION("Body containment was omitted by production persistence")
		save_work_check()
		var/list/entries = list()
		var/list/lists = list()
		for(var/i = 1, i <= saving_reference_pins.len, i++)
			var/path = entry_path(F, i)
			F.cd = path
			var/list/fields = list()
			for(var/key in F.dir.Copy()) fields[key] = to_wire(F["[path]/[key]"])
			entries += list(fields)
		for(var/i = 1, i <= saving_list_pins.len, i++)
			var/path = "/lists/[i]"
			var/list/scalars = F[path]
			if(islist(scalars))
				lists += list(list("scalar" = to_wire(scalars)))
			else
				var/count = F["[path]/length"]
				var/list/rows = list()
				for(var/j = 1, j <= count, j++)
					rows += list(list(to_wire(F["[path]/[j]/key"]), to_wire(F["[path]/[j]/value"])))
				lists += list(list("rows" = rows))
		var/text = json_encode(list("schema" = "train-body-1", "root" = root, "entries" = entries, "lists" = lists))
		save_work_check()
		if(local_body_build && !canonical_body_build_valid(local_body_build)) throw EXCEPTION("Body-build changed during capture")
		if(local_species && !canonical_species_valid(local_species)) throw EXCEPTION("Species changed during capture at [metadata_error]")
		if(length(text) > TRAIN_BODY_BYTES) throw EXCEPTION("Body payload exceeds byte budget")
		capture_tick = null
		local_snapshot = text
		return text
	catch(var/exception/E)
		body_error = "[E]"
		capture_tick = null
		return null

// This is a one-shot capability to round-trip this instance's exact capture.
// It intentionally cannot restore a packet captured on another server/instance.
// A future remote importer needs authenticated custody AND a versioned static
// field/constructor admission profile, not removal of this equality check.
/map_storage/train_body_graph/rejuvenate_unowned_human_on_load()
	return FALSE

/obj/effect/train_body_quarantine
	name = "detached train body quarantine"
	should_save = FALSE
	var/tmp/mob/living/body

/map_storage/train_body_graph/proc/body_ref(ref, limit)
	return isnum(ref) && ref == round(ref) && ref >= 1 && ref <= limit

/map_storage/train_body_graph/proc/read_wire(list/V, depth = 0)
	wire_edges++
	if(!islist(V) || depth > 32 || wire_edges > TRAIN_BODY_EDGES) throw EXCEPTION("Malformed body wire")
	if(V["tag"] == "scalar")
		var/value = V["value"]
		if(!isnull(value) && !isnum(value) && !istext(value)) throw EXCEPTION("Invalid body scalar")
		return value
	if(V["tag"] == "path")
		// Called ONLY after exact local snapshot equality, never on remote input.
		var/path = istext(V["value"]) ? text2path(V["value"]) : null
		if(!ispath(path)) throw EXCEPTION("Unknown captured path")
		return path
	if(V["tag"] != "list" || !islist(V["rows"])) throw EXCEPTION("Malformed body list")
	var/list/out = list()
	for(var/list/row in V["rows"])
		if(!islist(row) || row.len != 2) throw EXCEPTION("Malformed body list row")
		var/key = read_wire(row[1], depth + 1)
		var/value = read_wire(row[2], depth + 1)
		out.len++
		out[out.len] = key
		if(!isnum(key) && !isnull(key)) out[key] = value
	return out

/map_storage/train_body_graph/proc/value_edges(value, entry_count, list_count, list/edges)
	if(!islist(value)) return
	var/list/V = value
	switch(V["kind"])
		if("body_build")
			if(V.len != 3 || !local_body_build || V["name"] != local_body_build.name || V["gender"] != local_body_build.gender || !canonical_body_build_valid(local_body_build)) throw EXCEPTION("Invalid local body-build reference")
		if("body_local_icon")
			if(V.len != 2 || !body_ref(V["ref"], local_icon_copies.len)) throw EXCEPTION("Invalid local icon reference")
		if("body_species")
			if(V.len != 2 || V["name"] != "Human" || !local_species || all_species["Human"] != local_species) throw EXCEPTION("Invalid local species reference")
		if("body_empty_filters")
			if(V.len != 1) throw EXCEPTION("Invalid empty filter marker")
		if("value")
			if(islist(V["value"]) || istype(V["value"], /datum)) throw EXCEPTION("Invalid scalar envelope")
		if("entry")
			if(!body_ref(V["ref"], entry_count)) throw EXCEPTION("Invalid body entry reference")
			edges |= "e[V["ref"]]"
		if("list")
			if(!body_ref(V["ref"], list_count)) throw EXCEPTION("Invalid body list reference")
			edges |= "l[V["ref"]]"
		else
			throw EXCEPTION("External or unknown body reference")

// Pass one: rebuild native savefile values, check closed references, unique
// containment, rooted graph reachability and exact local capture admission.
// No game-object constructor or lifecycle hook is called in this pass.
/map_storage/train_body_graph/proc/local_restore_preflight(text)
	if(!istext(text) || !istext(local_snapshot) || text != local_snapshot || length(text) > TRAIN_BODY_BYTES || local_restore_used)
		throw EXCEPTION("Restore requires this adapter's unconsumed exact local capture")
	if(local_body_build && !canonical_body_build_valid(local_body_build)) throw EXCEPTION("Local body-build changed before restore")
	if(local_species && !canonical_species_valid(local_species)) throw EXCEPTION("Local species changed before restore at [metadata_error]")
	var/list/doc = json_decode(text)
	var/list/entries = doc["entries"]
	var/list/lists = doc["lists"]
	if(doc["schema"] != "train-body-1" || !islist(entries) || !islist(lists) || entries.len + lists.len > TRAIN_BODY_NODES || !body_ref(doc["root"], entries.len))
		throw EXCEPTION("Malformed body graph")
	wire_edges = 0
	var/savefile/F = new
	F["/format_version"] << 3
	F["/value_format"] << 2
	F["/train_body_root"] << doc["root"]
	var/list/graph = list()
	var/list/parents = list()
	var/list/entry_types = list()
	for(var/i = 1, i <= entries.len, i++)
		var/list/fields = entries[i]
		if(!islist(fields) || !fields["type"]) throw EXCEPTION("Missing body entry identity")
		var/path = read_wire(fields["type"])
		if(!admitted_type(path)) throw EXCEPTION("Unsupported captured body type")
		if(path == /matrix)
			if(fields.len != 7) throw EXCEPTION("Invalid matrix field count")
			for(var/coefficient in list("a", "b", "c", "d", "e", "f"))
				if(!fields[coefficient] || !matrix_component_valid(read_wire(fields[coefficient]))) throw EXCEPTION("Invalid matrix component")
		else if(!fields["name"]) throw EXCEPTION("Missing captured name")
		entry_types += path
		var/list/edges = list()
		graph["e[i]"] = edges
		var/directory = entry_path(F, i)
		for(var/field in fields)
			if(!istext(field) || field in list("loc", "locs", "pixloc", "contents", "vars", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey", "verbs")) throw EXCEPTION("Forbidden body field")
			var/value = read_wire(fields[field])
			if(islist(value))
				var/list/envelope = value
				if(envelope["kind"] == "body_local_icon" && (!(field in list("mob_icon", "icon")) || !ispath(path, /obj/item/organ/external))) throw EXCEPTION("Local icon outside organ renderer")
				if(envelope["kind"] == "body_empty_filters" && (field != "filters" || !ispath(path, /atom))) throw EXCEPTION("Empty filter marker outside atom.filters")
			if(field == "content")
				if(!ispath(path, /atom/movable)) throw EXCEPTION("Nonmovable body container")
				for(var/ref_text in saved_content_refs(value, 3))
					var/ref = text2num(ref_text)
					if(!body_ref(ref, entries.len) || parents["[ref]"] || ref == doc["root"]) throw EXCEPTION("Invalid body containment")
					parents["[ref]"] = i
					edges |= "e[ref]"
			else
				value_edges(value, entries.len, lists.len, edges)
			F["[directory]/[field]"] << value
	for(var/i = 1, i <= lists.len, i++)
		var/list/node = lists[i]
		var/list/edges = list()
		graph["l[i]"] = edges
		if(!islist(node)) throw EXCEPTION("Malformed body list node")
		if(node["scalar"])
			var/value = read_wire(node["scalar"])
			F["/lists/[i]"] << value
			if(!saved_scalar_list(F, i)) throw EXCEPTION("Malformed scalar list node")
		else
			var/list/rows = node["rows"]
			if(!islist(rows)) throw EXCEPTION("Malformed body list rows")
			F["/lists/[i]/length"] << rows.len
			for(var/j = 1, j <= rows.len, j++)
				var/list/row = rows[j]
				if(!islist(row) || row.len != 2) throw EXCEPTION("Malformed body list pair")
				var/key = read_wire(row[1])
				var/value = read_wire(row[2])
				value_edges(key, entries.len, lists.len, edges)
				value_edges(value, entries.len, lists.len, edges)
				F["/lists/[i]/[j]/key"] << key
				F["/lists/[i]/[j]/value"] << value
	// Movables form a tree rooted at the body; data/list refs may be cyclic.
	for(var/i = 1, i <= entries.len, i++)
		if(i == doc["root"])
			if(!ispath(entry_types[i], /mob/living)) throw EXCEPTION("Body root is not living-mob type")
			continue
		if(!ispath(entry_types[i], /atom/movable)) continue
		var/current = i
		var/list/seen = list()
		while(current != doc["root"])
			if(seen["[current]"] || !parents["[current]"]) throw EXCEPTION("Detached or cyclic body containment")
			seen["[current]"] = TRUE
			current = parents["[current]"]
	var/list/queue = list("e[doc["root"]]")
	var/list/seen = list()
	for(var/i = 1, i <= queue.len, i++)
		var/node = queue[i]
		if(seen[node]) continue
		seen[node] = TRUE
		for(var/next in graph[node])
			if(!seen[next] && !(next in queue)) queue += next
	if(seen.len != entries.len + lists.len) throw EXCEPTION("Unreachable body graph nodes")
	return F

// Pass two: guarded production construction in a detached, non-saving holder.
// Returns QUARANTINED data, not a playable/registered body. Publication requires
// separate verified custody, lifecycle-finalization and placement procedures.
/map_storage/train_body_graph/proc/restore_local_capture(text)
	body_error = null
	var/obj/effect/train_body_quarantine/Q = null
	try
		if(persistence_save_active()) throw EXCEPTION("World save is active")
		var/savefile/F = local_restore_preflight(text)
		local_restore_used = TRUE
		clear_bookkeeping()
		Q = new(null)
		var/root = F["/train_body_root"]
		var/mob/living/body = Load_Entry(F, root, null, Q)
		if(!istype(body) || body.loc != Q || body.client || body.key) throw EXCEPTION("Invalid quarantine body")
		Q.body = body
		// Deliberately no after_load/restore_finished/account registration yet:
		// callbacks can activate gameplay and need a destination custody commit.
		return Q
	catch(var/exception/E)
		body_error = "[E]"
		// Remove only objects created by this isolated exporter, never sources.
		if(Q)
			for(var/i = all_loaded.len, i >= 1, i--)
				var/datum/D = all_loaded[i]
				if(D) qdel(D)
			qdel(Q)
		return null

#undef TRAIN_BODY_NODES
#undef TRAIN_BODY_EDGES
#undef TRAIN_BODY_BYTES
