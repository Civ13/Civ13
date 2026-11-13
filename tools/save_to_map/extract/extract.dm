// Save-to-map level reader. A standalone world: it includes no game code,
// constructs nothing from the save and only reads a disposable copy of one
// saved level (tools/save_to_map/export.py stages and runs it).
//
// Params: index=<copied level index .sav>, z=<level>, out=<new .jsonl file>,
// entries=1 to read entry records (formats 3 and 4; format 5 entries live in
// the stream file, which export.py reads itself).
//
// Every output line is one JSON object:
//   header  format, generation, dimensions and the sparse baseline
//   cell    x, y, saved turf entry ref and captured zone ID
//   entry   ref, type text, field names, the numeric placement fields and
//           direct content refs (turfs and their direct contents only)
//   end     totals; a file without it is incomplete
// No saved text value other than type paths and zone IDs is written out.

#define EXTRACT_FLUSH_LINES 2000

/world
	sleep_offline = 0

var/extract_out = null
var/list/extract_lines = list()
var/extract_entry_count = 0

/proc/extract_emit(list/row)
	extract_lines += json_encode(row)
	if(extract_lines.len >= EXTRACT_FLUSH_LINES) extract_flush()

/proc/extract_flush()
	if(!extract_lines.len) return
	if(!text2file(jointext(extract_lines, "\n") + "\n", extract_out)) throw EXCEPTION("output_write_failed")
	extract_lines.Cut()

// Type paths of types this world does not declare read back as null, so the
// path is taken from the node's savefile text instead.
/proc/extract_type_text(savefile/F, path)
	var/text = F.ExportText(path)
	var/start = findtext(text, "/")
	if(!start || copytext(text, 1, start) != ". = ") return null
	var/end = findtext(text, "\n", start)
	return copytext(text, start, end ? end : 0)

/proc/extract_scalar(value)
	// Value format 1 wraps scalars in an envelope; format 2 writes them raw.
	if(islist(value))
		var/list/L = value
		if(L.len == 2 && L["kind"] == "value") return L["value"]
		return null
	return value

/proc/extract_content_refs(value)
	var/list/refs = list()
	var/list/chunks = islist(value) ? value : (istext(value) ? list(value) : list())
	for(var/chunk in chunks)
		if(!istext(chunk)) throw EXCEPTION("invalid_content")
		for(var/ref in params2list(chunk))
			var/number = text2num(ref)
			if(!isnum(number) || number < 1 || number != round(number)) throw EXCEPTION("invalid_content")
			refs += number
	return refs

/proc/extract_dir_has(savefile/F, path, name)
	F.cd = path
	. = (name in F.dir)
	F.cd = "/"

/datum/level_source
	var/savefile/index
	var/index_path
	var/version
	var/list/entry_last
	var/list/open_files = list()

/datum/level_source/New(savefile/F, path)
	index = F
	index_path = path
	version = F["/format_version"]
	if(version == 4)
		var/count = F["/segments/count"]
		entry_last = F["/segments/entries"]
		if(!isnum(count) || count < 1 || !islist(entry_last) || entry_last.len != count) throw EXCEPTION("invalid_segment_table")

/datum/level_source/proc/entry_file(ref)
	if(version != 4) return index
	for(var/number = 1, number <= entry_last.len, number++)
		if(entry_last[number] >= ref) return segment(number)
	throw EXCEPTION("entry_outside_segments")

/datum/level_source/proc/segment(number)
	var/savefile/S = open_files["[number]"]
	if(S) return S
	var/path = "[copytext(index_path, 1, length(index_path) - 3)].part[number].sav"
	if(!fexists(path)) throw EXCEPTION("missing_segment")
	S = new(path)
	if(S["/format_version"] != 3 || S["/segment"] != number || S["/generation"] != index["/generation"]) throw EXCEPTION("segment_generation_mismatch")
	// Keep few segments open; each one holds its whole tree in memory.
	if(open_files.len >= 2)
		open_files.Cut()
	open_files["[number]"] = S
	return S

/datum/level_source/proc/read_entry(ref, depth)
	var/savefile/F = entry_file(ref)
	// This is a disposable copy: a missing entry read here only adds an empty
	// node to the copy, and an entry without a type is refused.
	var/path = "/entries/[round((ref - 1) / 512)]/[ref]"
	F.cd = path
	var/list/names = F.dir.Copy()
	if(!("type" in names)) throw EXCEPTION("missing_entry")
	var/list/numbers = list()
	for(var/field in list("dir", "pixel_x", "pixel_y"))
		if(!(field in names)) continue
		var/value = extract_scalar(F[field])
		if(isnum(value)) numbers[field] = value
	var/list/content = ("content" in names) ? extract_content_refs(F["content"]) : list()
	F.cd = "/"
	var/type_text = extract_type_text(F, "[path]/type")
	var/list/fields = names.Copy()
	fields -= list("type", "content")
	extract_emit(list("kind" = "entry", "ref" = ref, "depth" = depth, "type" = type_text, "fields" = fields, "num" = numbers, "content" = content))
	extract_entry_count++
	return content

/proc/extract_level(index_path, z, read_entries)
	if(!fexists(index_path)) throw EXCEPTION("missing_level")
	var/savefile/F = new(index_path)
	var/version = F["/format_version"]
	if(!(version in list(3, 4, 5))) throw EXCEPTION("unsupported_save_version")
	var/maxx = F["/maxx"]
	var/maxy = F["/maxy"]
	var/maxz = F["/maxz"]
	if(!isnum(maxx) || !isnum(maxy) || !isnum(maxz) || maxx < 1 || maxy < 1 || z > maxz) throw EXCEPTION("invalid_dimensions")
	var/list/header = list("kind" = "header", "z" = z, "format" = version, "value_format" = F["/value_format"], "generation" = F["/generation"], "maxx" = maxx, "maxy" = maxy, "maxz" = maxz)
	F.cd = "/"
	var/list/top = F.dir.Copy()
	if("sparse" in top)
		// A level with plain cells names its baseline in "baseline" and lists
		// its plain templates and their run-length grid (saving.dm).
		var/plain = extract_dir_has(F, "/sparse", "plain")
		header["sparse_kind"] = F["/sparse/kind"]
		header["sparse_turf"] = extract_type_text(F, plain ? "/sparse/baseline" : "/sparse/turf")
		header["sparse_zone"] = F["/sparse/zone"]
		header["sparse_cells"] = F["/sparse/cells"]
		if(plain)
			var/count = F["/sparse/plain/count"]
			if(!isnum(count) || count < 1 || count > 255 || count != round(count)) throw EXCEPTION("invalid_plain_cells")
			var/list/templates = list()
			for(var/i = 1, i <= count, i++)
				var/list/saved_fields = F["/sparse/plain/[i]/fields"]
				if(!islist(saved_fields)) throw EXCEPTION("invalid_plain_cells")
				var/list/names = list()
				var/list/numbers = list()
				for(var/name in saved_fields)
					names += name
					if((name in list("dir", "pixel_x", "pixel_y")) && isnum(saved_fields[name])) numbers[name] = saved_fields[name]
				templates += list(list("type" = extract_type_text(F, "/sparse/plain/[i]/type"), "zone" = F["/sparse/plain/[i]/zone"], "fields" = names, "num" = numbers))
			var/list/runs = F["/sparse/plain/runs"]
			if(!islist(runs)) throw EXCEPTION("invalid_plain_cells")
			header["plain_templates"] = templates
			header["plain_runs"] = runs
	if(version == 5) header["stream_file"] = F["/stream/file"]
	extract_emit(header)
	// Stream levels keep their entries in the stream file (export.py reads it).
	if(version == 5) read_entries = FALSE
	var/datum/level_source/source = new(F, index_path)
	// Directory listings of large nodes are slow to scan, so cells and zones
	// are read directly; absent ones read back as null (in the copy only).
	var/has_zones = ("zone_capture" in top)
	var/has_level = ("map" in top) && extract_dir_has(F, "/map", "[z]")
	var/cells = 0
	for(var/y = 1, y <= maxy, y++)
		if(!has_level) break
		for(var/x = 1, x <= maxx, x++)
			var/ref = F["/map/[z]/[y]/[x]"]
			if(isnull(ref)) continue
			if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("invalid_turf_ref")
			var/zone = has_zones ? F["/zone_capture/[ref]/id"] : null
			extract_emit(list("kind" = "cell", "x" = x, "y" = y, "ref" = ref, "zone" = zone))
			cells++
			if(read_entries)
				for(var/child in source.read_entry(ref, 0))
					source.read_entry(child, 1)
		// Yield now and then so a large level never trips the loop guard.
		if(!(y % 16)) sleep(world.tick_lag)
	extract_emit(list("kind" = "end", "cells" = cells, "entries" = extract_entry_count))

/world/New()
	..()
	extract_out = world.params["out"]
	try
		if(!istext(extract_out) || !length(extract_out) || fexists(extract_out)) throw EXCEPTION("invalid_output")
		extract_level(world.params["index"], text2num(world.params["z"]), world.params["entries"] == "1")
	catch(var/exception/error)
		extract_lines.Cut()
		extract_emit(list("kind" = "error", "reason" = "[error.name]"))
	extract_flush()
	del(world)
