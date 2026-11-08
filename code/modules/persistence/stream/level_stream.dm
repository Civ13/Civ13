// Stream-backed levels (level format 5).
//
// A format-5 level is a small index savefile, map_saves/<z>.sav, plus one
// stream file, map_saves/<z>.stream.sav, written and read by the 64-bit
// helper in tools/savestream. The index holds what a format-4 index holds
// (turf grid, zone capture, header); every entry and list lives in the
// stream. Dream Daemon only ever holds one small scratch savefile at a time
// on save and a few on load, so the level's savefile tree (about 6x the file
// size, never returned to the OS) is never built in the 32-bit process.
//
// It reuses the format-4 seams: the save writes each segment into a scratch
// savefile and hands it to the helper when the segment closes, and the
// reader materialises one entry shard (512 entries) or list block (512 lists)
// on demand behind level_entry_file()/level_list_file(), each with a single
// helper request rendered as savefile text and one native ImportText(). Without the shim and helper
// (no call_ext, or the files are missing) saves stay on /savefile levels.

// Most scratch savefiles a normal-memory stream load keeps open at once. Each
// is a temporary file in the BYOND cache; the Windows C runtime allows 512
// open files per process, which the whole world shares.
#define PERSISTENCE_STREAM_SCRATCH_FILE_CAP 96
// Entry shards (or list blocks) a normal-memory load imports into one scratch
// file, so the cache keeps more of a level without holding more files open.
#define PERSISTENCE_STREAM_SHARDS_PER_FILE 4

/map_storage
	var/stream_level_saves_state = null // TRUE/FALSE once probed this boot.
	var/stream_level_saves_override = null // TRUE/FALSE pins the choice for admins and fixtures.
	var/last_stream_level_plan

/map_storage/stream_level_writer_type()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	// The human spatial prototype reads level files directly; keep it on format 3.
	last_stream_level_plan = "off (human spatial prototype)"
	return null
#else
	if(!isnull(stream_level_saves_override))
		last_stream_level_plan = stream_level_saves_override ? "on (override)" : "off (override)"
		return stream_level_saves_override ? /datum/level_segment_writer/stream : null
	var/datum/settings = ("config" in global.vars) ? global.vars["config"] : null
	if(settings && ("persistence_stream_saves" in settings.vars) && !settings.vars["persistence_stream_saves"])
		last_stream_level_plan = "off (PERSISTENCE_NO_STREAM_SAVES)"
		return null
	if(isnull(stream_level_saves_state))
		var/datum/save_stream/probe = new
		stream_level_saves_state = probe.probe()
		last_stream_level_plan = stream_level_saves_state ? "on" : "off ([probe.last_error])"
		world.log << "Stream level saves: [last_stream_level_plan]."
		persistence_game_log("Stream level saves: [last_stream_level_plan].")
	return stream_level_saves_state ? /datum/level_segment_writer/stream : null
#endif

/map_storage/new_stream_level_reader(savefile/F, cache_limit)
	return new /datum/level_segment_reader/stream(F, cache_limit)

/map_storage/stream_level_entries(datum/level_segment_reader/R)
	var/datum/level_segment_reader/stream/S = R
	return S.entry_refs()

// map_saves/2.sav -> map_saves/2.stream.sav, beside its index like segments.
/proc/level_stream_path(index_path)
	index_path = "[index_path]"
	if(copytext(index_path, max(1, length(index_path) - 3)) != ".sav") throw EXCEPTION("Stream level index has no .sav name")
	return "[copytext(index_path, 1, length(index_path) - 3)].stream.sav"

/proc/level_stream_name(index_path)
	var/path = level_stream_path(index_path)
	var/cut = findlasttext(path, "/")
	return cut ? copytext(path, cut + 1) : path

/datum/level_segment_writer/stream
	var/datum/save_stream/stream
	var/stream_path
	var/list/late_loaded = list()
	var/drained = 0

/datum/level_segment_writer/stream/New(map_storage/storage, savefile/F, path, level, generation_id, segment_budget)
	stream_path = level_stream_path(path)
	if(fexists(stream_path) && !fdel(stream_path)) throw EXCEPTION("Could not replace level stream [stream_path]")
	if(fexists("[stream_path].tmp")) fdel("[stream_path].tmp")
	stream = new
	if(!stream.open_write(stream_path)) throw EXCEPTION("Could not start level stream [stream_path]: [stream.last_error]")
	stream.put("/generation", generation_id)
	stream.put("/level", level)
	..()

/datum/level_segment_writer/stream/open_next()
	close_current()
	number++
	current = new /savefile
	current["/format_version"] << 3
	// The exporter notes nodes whose value does not survive savefile text while this segment is open.
	owner.saving_stream_native_paths = list()
	start_nodes = owner.saving_reference_pins.len + owner.saving_list_pins.len

/datum/level_segment_writer/stream/close_current()
	if(!current) return
	entry_last += owner.saving_reference_pins.len
	list_last += owner.saving_list_pins.len
	drain(current, owner.saving_stream_native_paths)
	owner.saving_stream_native_paths = null
	current = null

// Hands every node of a scratch segment to the helper. The helper keeps the
// last value written to a path, so a late rewrite of a node replaces it.
//
// Each top-level subtree goes as one piece of BYOND savefile text
// (ExportText), which the helper parses natively: one call per subtree
// instead of a cd, directory copy, read, encode and put per node, which cost
// about a third of a level's save. The text drops text macros such as
// \improper (rare: a few dozen names on a Gaia level) and renders infinities
// and resources in forms the helper does not take, so the nodes the exporter
// noted while the segment was open (persistence_stream_text_unsafe) are
// rewritten natively after the text; the helper keeps the last value written
// to a path. Finite numbers are rendered at full precision, strings escaped,
// and type paths and lists in the syntax the converter path (put_text) has
// always used.
/datum/level_segment_writer/stream/proc/drain(savefile/S, list/native_paths)
	S.cd = "/"
	var/list/top = S.dir.Copy()
	for(var/key in top)
		if(key == "format_version") continue
		if(!stream.put_text("/[key]", S.ExportText("/[key]"))) throw EXCEPTION("Stream save of level [z] failed: [stream.last_error]")
		S.cd = "/"
		if(!owner.moving_save_chunk) owner.save_work_check()
	for(var/path in native_paths)
		if(!stream.put(path, native_paths[path])) throw EXCEPTION("Stream save of level [z] failed: [stream.last_error]")
	S.cd = "/"
	if(!stream.flush()) throw EXCEPTION("Stream save of level [z] failed: [stream.last_error]")

// Node-by-node drain (the previous path): kept for the converter and tests.
/datum/level_segment_writer/stream/proc/drain_nodes(savefile/S)
	S.cd = "/"
	var/list/top = S.dir.Copy()
	for(var/key in top)
		if(key == "format_version") continue
		drain_node(S, "/[key]")
	S.cd = "/"
	if(!stream.flush()) throw EXCEPTION("Stream save of level [z] failed: [stream.last_error]")

/datum/level_segment_writer/stream/proc/drain_node(savefile/S, path)
	S.cd = path
	var/list/children = S.dir.Copy()
	var/value = S[path]
	if(!isnull(value) || !children.len)
		if(!stream.put(path, value)) throw EXCEPTION("Stream save of level [z] failed: [stream.last_error]")
		if(++drained % 256 == 0 && !owner.moving_save_chunk) owner.save_work_check()
	for(var/child in children)
		drain_node(S, "[path]/[child]")

// The only late writes (roster drain, animal sweep) append to a saved turf's
// content. Bring that one node back from the stream into a scratch file.
/datum/level_segment_writer/stream/file_for_entry(ref)
	if(!isnum(ref)) ref = text2num("[ref]")
	var/closed = entry_last.len ? entry_last[entry_last.len] : 0
	if(!isnum(ref) || ref < 1) throw EXCEPTION("Invalid saved entry for a level segment")
	if(ref > closed) return current
	if(!late_file)
		late_file = new /savefile
		late_file["/format_version"] << 3
	var/key = "[ref]"
	if(!late_loaded[key])
		late_loaded[key] = TRUE
		var/path = "[owner.entry_path(late_file, ref)]/content"
		var/value = stream.get(path)
		if(stream.found) late_file[path] << value
	return late_file

/datum/level_segment_writer/stream/finish()
	close_current()
	if(late_file) drain(late_file, list()) // Late writes rewrite content lists: no text.
	late_file = null
	late_loaded = list()
	var/list/summary = stream.finish()
	var/error = stream.last_error
	stream = null
	if(!summary || !summary["published"])
		throw EXCEPTION("Stream save of level [z] was not published: [error ? error : json_encode(summary)]")
	index["/stream/file"] << level_stream_name(index_path)
	index["/stream/nodes"] << summary["nodes"]
	index["/stream/bytes"] << summary["bytes"]

/datum/level_segment_writer/stream/abort()
	if(stream) stream.abort()
	stream = null
	current = null
	late_file = null
	owner.saving_stream_native_paths = null

/datum/level_segment_reader/stream
	var/datum/save_stream/stream
	var/list/scratch_names = list()
	var/list/list_filled = list()
	var/shards_per_file = 1
	var/tmp/part_needs_import = FALSE // Set by part_file(): the part is not in its file yet.
	var/list/file_parts = list() // Cache key -> shards/blocks already imported into that file.

/datum/level_segment_reader/stream/New(savefile/F, cache_limit)
	index = F
	base_path = "[F.name]"
	part_prefix = "\n" // No segment files: scratch files are matched by name.
	generation = F["/generation"]
	if(isnum(cache_limit) && cache_limit >= 1) limit = cache_limit
	// Entry shards and list blocks share the cache; both are small (a few
	// hundred KB of savefile tree each), and a refill re-reads a whole block.
	limit = max(8, limit * 4)
	// A normal-memory load keeps most of a level: with 24 files, Gaia's 572
	// shards and blocks were imported 3050 times across the preflight walk
	// and the load. Low-memory plans keep the small cache.
	// Each scratch file is a temporary savefile held open in the BYOND cache,
	// and evicted ones stay open while an entry frame still holds them. 256
	// went past the Windows C runtime's 512 open-file limit on Gaia: the
	// preflight failed with errno 24 and the world came up without its save.
	// Load time flattens past about 128 files (24: 748 s, 128: 584 s, 256: 559 s
	// on a Gaia copy); 96 keeps most of that gain well clear of the limit.
	// 6 is PERSISTENCE_SEGMENT_CACHE_NORMAL (loading.dm, undefined here).
	// Grouping shards keeps the file count at the cap while about four times
	// as many shards stay resident (Gaia: imports fall toward one per shard).
	if(isnum(cache_limit) && cache_limit >= 6)
		limit = PERSISTENCE_STREAM_SCRATCH_FILE_CAP
		shards_per_file = PERSISTENCE_STREAM_SHARDS_PER_FILE
	var/path = level_stream_path(base_path)
	if(F["/stream/file"] != level_stream_name(base_path)) throw EXCEPTION("Stream level index does not name [path]")
	if(!fexists(path)) throw EXCEPTION("Missing level stream [path]")
	stream = new
	if(!stream.open_read(path)) throw EXCEPTION("Could not read level stream [path]: [stream.last_error]")
	if(stream.get("/generation") != generation) throw EXCEPTION("Level stream [path] belongs to another generation")

/datum/level_segment_reader/stream/Del()
	close()
	..()

/datum/level_segment_reader/stream/close()
	if(stream) stream.close()
	stream = null
	scratch_names = list()
	file_parts = list()

/datum/level_segment_reader/stream/owns_file(savefile/F)
	return F && scratch_names["[F.name]"]

/datum/level_segment_reader/stream/proc/scratch(key)
	var/savefile/S = open_files[key]
	if(S)
		open_order -= key
		open_order += key
		return S
	S = new /savefile
	S["/format_version"] << 3
	S["/generation"] << generation
	scratch_names["[S.name]"] = TRUE
	open_files[key] = S
	file_parts[key] = list()
	open_order += key
	while(open_order.len > limit)
		var/oldest = open_order[1]
		open_order.Cut(1, 2)
		// Keep the evicted file's name: an entry frame may still hold it and
		// must keep routing its list lookups through this reader.
		open_files -= oldest
		file_parts -= oldest
	return S

// The cached file for shard/block number part of kind ("e" or "l"), and
// whether that part still has to be imported into it.
/datum/level_segment_reader/stream/proc/part_file(kind, part)
	var/key = "[kind][round(part / shards_per_file)]"
	var/savefile/S = scratch(key)
	var/list/parts = file_parts[key]
	var/part_key = "[part]"
	part_needs_import = !parts[part_key]
	parts[part_key] = TRUE
	return S

/datum/level_segment_reader/stream/proc/fill(savefile/S, path, batch_size)
	if(!stream) throw EXCEPTION("Level stream [base_path] is closed")
	var/list/nodes = stream.subtree(path, batch_size)
	for(var/i = 1, i <= nodes.len, i += 2)
		S[nodes[i]] << nodes[i + 1]
	return nodes.len / 2

/datum/level_segment_reader/stream/entry_file(ref)
	if(!isnum(ref)) ref = text2num("[ref]")
	if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("Invalid saved entry [ref]")
	var/shard = round((ref - 1) / 512)
	var/savefile/S = part_file("e", shard)
	if(!part_needs_import) return S
	if(isnull(stream.import_text(S, "/entries/[shard]")))
		fill(S, "/entries/[shard]", 256)
	return S

/datum/level_segment_reader/stream/list_file(id)
	if(!isnum(id)) id = text2num("[id]")
	if(!isnum(id) || id < 1 || id != round(id)) throw EXCEPTION("Invalid saved list [id]")
	var/block = round((id - 1) / 512)
	if(stream && stream.text_supported)
		var/savefile/B = part_file("l", block)
		if(!part_needs_import) return B
		// The whole block in one request: lists of one block are read together.
		if(!isnull(stream.import_text(B, "/lists", block * 512 + 1, block * 512 + 512))) return B
		// The helper predates text requests: fill this list on its own below.
	var/savefile/S = scratch("l[round(block / shards_per_file)]")
	var/filled_key = "[id]"
	if(list_filled[filled_key] != "[S.name]")
		list_filled[filled_key] = "[S.name]"
		fill(S, "/lists/[id]", 8)
	return S

/datum/level_segment_reader/stream/proc/entry_refs()
	if(!stream) throw EXCEPTION("Level stream [base_path] is closed")
	var/list/refs = list()
	for(var/shard in stream.dir("/entries"))
		var/shard_number = text2num(shard)
		for(var/ref in stream.dir("/entries/[shard]"))
			var/value = text2num(ref)
			if(!isnum(value) || value < 1 || round((value - 1) / 512) != shard_number) throw EXCEPTION("Saved entry [ref] is outside its shard")
			refs += ref
		TICK_CHECK
	return refs
