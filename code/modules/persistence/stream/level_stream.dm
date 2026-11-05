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
// reader materialises one entry shard (512 entries) or list block on demand
// behind level_entry_file()/level_list_file(). Without the shim and helper
// (no call_ext, or the files are missing) saves stay on /savefile levels.

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
	start_nodes = owner.saving_reference_pins.len + owner.saving_list_pins.len

/datum/level_segment_writer/stream/close_current()
	if(!current) return
	entry_last += owner.saving_reference_pins.len
	list_last += owner.saving_list_pins.len
	drain(current)
	current = null

// Hands every node of a scratch segment to the helper. The helper keeps the
// last value written to a path, so a late rewrite of a node replaces it.
/datum/level_segment_writer/stream/proc/drain(savefile/S)
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
	if(late_file) drain(late_file)
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

/datum/level_segment_reader/stream
	var/datum/save_stream/stream
	var/list/scratch_names = list()
	var/list/list_filled = list()

/datum/level_segment_reader/stream/New(savefile/F, cache_limit)
	index = F
	base_path = "[F.name]"
	part_prefix = "\n" // No segment files: scratch files are matched by name.
	generation = F["/generation"]
	if(isnum(cache_limit) && cache_limit >= 1) limit = cache_limit
	// Entry shards and list blocks share the cache; both are small.
	limit = max(4, limit * 2)
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
	open_order += key
	while(open_order.len > limit)
		var/oldest = open_order[1]
		open_order.Cut(1, 2)
		var/savefile/dropped = open_files[oldest]
		if(dropped) scratch_names -= "[dropped.name]"
		open_files -= oldest
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
	var/key = "e[shard]"
	if(open_files[key]) return scratch(key)
	var/savefile/S = scratch(key)
	fill(S, "/entries/[shard]", 256)
	return S

/datum/level_segment_reader/stream/list_file(id)
	if(!isnum(id)) id = text2num("[id]")
	if(!isnum(id) || id < 1 || id != round(id)) throw EXCEPTION("Invalid saved list [id]")
	var/key = "l[round((id - 1) / 512)]"
	var/savefile/S = scratch(key)
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
