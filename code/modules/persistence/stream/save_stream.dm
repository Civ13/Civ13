// Stream save sessions. World saves write level entries and lists through
// this (level_stream.dm) when the shim and helper sit beside the .dmb.
//
// A /datum/save_stream writes or reads the same logical path -> value tree a
// level /savefile holds, but through tools/savestream: a 32-bit call_ext shim
// forwards batches to a 64-bit helper process that owns the file, its index and
// structural validation. Dream Daemon never builds the savefile tree, which
// BYOND keeps resident at about 6x the file size and never returns to the OS.
//
//   var/datum/save_stream/S = new
//   if(!S.open_write("map_saves/2.stream")) CRASH(S.last_error)
//   S.put("/entries/0/1/type", /turf/floor/grass)   // absolute paths only
//   var/list/summary = S.finish()                    // helper JSON, decoded
//
//   S.open_read("map_saves/2.stream"); S.get(path); S.dir(path); S.close()
//
// Values with no native token (icons, sounds, appearances) are encoded as
// BYOND savefile text through a scratch savefile, so they round trip exactly as
// a savefile would store them. See tools/savestream/README.md.
/datum/save_stream
	var/lib
	var/helper
	var/id
	var/mode
	var/last_error
	var/list/batch = list()
	// Finished call_ext arguments for the next write: joined plain tokens and,
	// on their own, tokens holding text macros (see encode()).
	var/list/segments = list()
	var/batch_bytes = 0
	var/encoded_macros = FALSE
	var/batch_limit = 262144
	var/records = 0
	var/value_files = 0
	var/savefile/scratch

/datum/save_stream/New(lib_path, helper_path)
	..()
	lib = lib_path || (world.system_type == MS_WINDOWS ? "savestream.dll" : "./libsavestream.so")
	// The shim resolves relative helper and file paths against its own directory.
	helper = helper_path || (world.system_type == MS_WINDOWS ? "savestream_helper.exe" : "savestream_helper")

/datum/save_stream/Destroy()
	close()
	scratch = null
	return ..()

// A dropped handle must not leave its helper running: the helper holds the
// file open, and Windows cannot replace an open file at the next save.
/datum/save_stream/Del()
	if(id) abort()
	..()

/datum/save_stream/proc/available()
	if(!fexists(lib) || !fexists(helper))
		last_error = "stream save library or helper is missing"
		return FALSE
	return TRUE

// TRUE when the library loads and answers; needs call_ext (a trusted daemon).
/datum/save_stream/proc/probe()
	if(!available()) return FALSE
	var/reply = lib_call("savestream_version", list())
	if(failed(reply)) return FALSE
	if(!length(reply))
		last_error = "stream save library gave no version"
		return FALSE
	return TRUE

/datum/save_stream/proc/lib_call(fn, list/arguments)
	try
		return call_ext(lib, fn)(arglist(arguments))
	catch(var/exception/error)
		last_error = "call_ext [fn] failed: [error]"
		return "ERR:[last_error]"

/datum/save_stream/proc/failed(reply)
	if(!istext(reply) || copytext(reply, 1, 5) == "ERR:")
		last_error = istext(reply) ? copytext(reply, 5) : "no reply"
		return TRUE
	return FALSE

/datum/save_stream/proc/open_session(new_mode, file)
	if(id)
		last_error = "session already open"
		return FALSE
	if(!available()) return FALSE
	var/reply = lib_call("savestream_open", list(new_mode, "[file]", helper))
	if(failed(reply)) return FALSE
	id = reply
	mode = new_mode
	records = 0
	return TRUE

/datum/save_stream/proc/open_write(file)
	return open_session("write", file)

/datum/save_stream/proc/open_read(file)
	return open_session("read", file)

/datum/save_stream/proc/put(path, value)
	if(mode != "write") CRASH("save stream is not writing")
	encoded_macros = FALSE
	var/token = "W[length(path)]:[path]" + encode(value)
	batch_bytes += length(token)
	records++
	if(encoded_macros)
		// jointext() would drop the macros: send this token unjoined.
		if(batch.len)
			segments += jointext(batch, "")
			batch.Cut()
		segments += token
	else
		batch += token
	if(batch_bytes >= batch_limit) return flush()
	return TRUE

// Converter path: one node's BYOND savefile text (savefile.ExportText(base)).
/datum/save_stream/proc/put_text(base, text)
	if(mode != "write") CRASH("save stream is not writing")
	var/body = "[base]|[text]"
	var/token = "T[length(body)]:[body]"
	batch += token
	batch_bytes += length(token)
	records++
	if(batch_bytes >= batch_limit) return flush()
	return TRUE

// Hands the batch to the helper. Writes are pipelined: an error in one batch
// is reported by the next flush or by finish().
/datum/save_stream/proc/flush()
	if(!batch.len && !segments.len) return TRUE
	// The shim joins its arguments into one batch.
	if(batch.len)
		segments += jointext(batch, "")
		batch.Cut()
	var/list/arguments = list(id) + segments
	segments.Cut()
	batch_bytes = 0
	return !failed(lib_call("savestream_write", arguments))

// Publishes the file when its structure validates (or force is set) and closes
// the session. Returns the helper's summary, or null with last_error set.
/datum/save_stream/proc/finish(force = FALSE)
	if(mode != "write") CRASH("save stream is not writing")
	var/flushed = flush()
	var/reply = lib_call("savestream_finish", list(id, force ? "1" : "0"))
	close()
	if(!flushed) return null
	if(failed(reply)) return null
	var/list/summary = json_decode(reply)
	if(!summary["published"])
		last_error = "stream save was not published: [reply]"
	return summary

/datum/save_stream/proc/abort()
	if(id)
		batch.Cut()
		segments.Cut()
		batch_bytes = 0
		lib_call("savestream_abort", list(id))
	close()

/datum/save_stream/proc/stats()
	if(!id) return null
	var/reply = lib_call("savestream_stats", list(id))
	if(failed(reply)) return null
	return json_decode(reply)

/datum/save_stream/proc/close()
	if(id)
		lib_call("savestream_close", list(id))
	id = null
	mode = null

// Returns the stored value; `found` is set FALSE for a missing path.
/datum/save_stream/var/found = FALSE
// In write mode this reads back the last value written to path.
/datum/save_stream/proc/get(path)
	if(mode != "read" && mode != "write") CRASH("save stream is not open")
	if(mode == "write" && !flush()) CRASH("stream write failed before reading [path]: [last_error]")
	var/reply = lib_call("savestream_get", list(id, path))
	found = FALSE
	if(failed(reply)) CRASH("stream read failed at [path]: [last_error]")
	if(reply == "?") return null
	found = TRUE
	var/list/cursor = list(1)
	return decode(reply, cursor)

/datum/save_stream/proc/dir(path)
	if(mode != "read") CRASH("save stream is not reading")
	var/reply = lib_call("savestream_dir", list(id, path))
	if(failed(reply)) CRASH("stream dir failed at [path]: [last_error]")
	var/list/cursor = list(1)
	return decode(reply, cursor)

// Reads up to `max` nodes in path order from index position `start`. Keep
// batches small: DM's positional text procs slow down on long replies. Returns
// a flat list (path, value, path, value, ...); next_index is the next start
// and equals node_count() once the stream is exhausted.
/datum/save_stream/var/next_index = 0
/datum/save_stream/proc/iterate(start, max = 256)
	if(mode != "read") CRASH("save stream is not reading")
	var/reply = lib_call("savestream_iter", list(id, "[start];[max]"))
	if(failed(reply)) CRASH("stream iterate failed at [start]: [last_error]")
	var/semi = findtext(reply, ";")
	next_index = text2num(copytext(reply, 1, semi))
	var/list/nodes = list()
	var/list/cursor = list(semi + 1)
	var/n = length(reply)
	while(cursor[1] <= n)
		var/i = cursor[1]
		var/colon = findtext(reply, ":", i)
		var/plen = text2num(copytext(reply, i + 1, colon))
		nodes += copytext(reply, colon + 1, colon + 1 + plen)
		cursor[1] = colon + 1 + plen
		nodes += list(decode(reply, cursor))
	return nodes

// Index position of the first node at or after path.
/datum/save_stream/proc/seek(path)
	if(mode != "read") CRASH("save stream is not reading")
	var/reply = lib_call("savestream_seek", list(id, path))
	if(failed(reply)) CRASH("stream seek failed at [path]: [last_error]")
	return text2num(reply)

// Every node at path or beneath it, in path order, as a flat (path, value)
// list. Sorted paths keep a subtree contiguous: "/" sorts before digits, so
// /lists/12 and /lists/12/... come before /lists/120.
/datum/save_stream/proc/subtree(path, batch_size = 64)
	var/list/found_nodes = list()
	var/prefix = "[path]/"
	var/prefix_length = length(prefix)
	var/start = seek(path)
	while(TRUE)
		var/list/nodes = iterate(start, batch_size)
		if(!nodes.len) break
		for(var/i = 1, i <= nodes.len, i += 2)
			var/node = nodes[i]
			if(node != path && copytext(node, 1, prefix_length + 1) != prefix) return found_nodes
			found_nodes += node
			found_nodes += list(nodes[i + 1])
		start = next_index
		batch_size = min(batch_size * 2, 512)
	return found_nodes

// Builds the subtree at base (or, with first and last, base's numeric
// children first..last) inside S with one native ImportText() call. The
// helper renders the nodes as savefile text and names the few with no exact
// text form (text macros, value files, inf/nan), which are fetched one by one.
// Decoding every wire token in DM instead made a Gaia-sized load take tens of
// minutes. Returns the number of nodes, or null when the shim or helper
// predates the text request; the caller then falls back to subtree().
/datum/save_stream/var/text_supported = TRUE
/datum/save_stream/proc/import_text(savefile/S, base, first, last)
	if(mode != "read") CRASH("save stream is not reading")
	if(!text_supported) return null
	var/request = isnull(first) ? "[base]" : "[base]\n[first]\n[last]"
	var/reply = lib_call("savestream_text", list(id, request))
	if(failed(reply))
		// An older shim has no savestream_text export, an older helper no OP_TEXT.
		if(findtext(last_error, "call_ext savestream_text failed") == 1 || last_error == "unknown op")
			text_supported = FALSE
			return null
		CRASH("stream text read failed at [base]: [last_error]")
	var/semi = findtext(reply, ";")
	var/missing_count = text2num(copytext(reply, 1, semi))
	var/position = semi + 1
	var/list/missing = list()
	for(var/i = 1, i <= missing_count, i++)
		var/colon = findtext(reply, ":", position)
		var/path_length = text2num(copytext(reply, position + 1, colon))
		missing += copytext(reply, colon + 1, colon + 1 + path_length)
		position = colon + 1 + path_length
	if(position <= length(reply))
		S.ImportText(base, copytext(reply, position))
	for(var/path in missing)
		var/value = get(path)
		if(found) S[path] << value
	return missing_count

// One value as a wire token. DM's jointext() and "[]" embedding drop text
// macros (\improper and friends) from saved names, so text that holds one is
// joined with + instead and sets encoded_macros.
/datum/save_stream/proc/encode(value)
	if(isnull(value)) return "N"
	if(isnum(value)) return "F[num2text(value, 9)];"
	if(istext(value))
		if(length("[value]") == length(value)) return "S[length(value)]:[value]"
		encoded_macros = TRUE
		return "S[length(value)]:" + value
	if(ispath(value))
		var/path_text = "[value]"
		return "P[length(path_text)]:[path_text]"
	if(islist(value))
		var/list/L = value
		var/list/parts = list("L[L.len];")
		var/had_macros = encoded_macros
		encoded_macros = FALSE
		for(var/i = 1, i <= L.len, i++)
			var/key = L[i]
			parts += encode(key)
			var/assoc = (isnum(key) || isnull(key)) ? null : L[key]
			if(isnull(assoc))
				parts += "."
			else
				parts += "="
				parts += encode(assoc)
		if(!encoded_macros)
			encoded_macros = had_macros
			return jointext(parts, "")
		var/joined = ""
		for(var/part in parts)
			joined += part
		return joined
	// Icons, sounds, appearances: BYOND's own savefile text for the value.
	if(!scratch) scratch = new /savefile()
	scratch["v"] << value
	var/text = scratch.ExportText("v")
	scratch.dir.Cut()
	// BYOND cannot import its own text for mutable appearances or saved
	// objects (object(".0") with child nodes), so such a value
	// travels as a one-node savefile file that the helper reads and deletes.
	if(findtext(text, "mutable_appearance(") || findtext(text, "object(\""))
		var/file_name = "savestream_value_[++value_files]_[world.timeofday].sav"
		var/savefile/value_file = new(file_name)
		value_file["v"] << value
		del(value_file)
		return "Y[length(file_name)]:[file_name]"
	if(copytext(text, 1, 5) == ". = ") text = copytext(text, 5)
	while(length(text) && copytext(text, length(text)) == "\n") text = copytext(text, 1, length(text))
	return "X[length(text)]:[text]"

// cursor is a one-element list holding the next byte position.
/datum/save_stream/proc/decode(text, list/cursor)
	var/i = cursor[1]
	var/t = copytext(text, i, i + 1)
	switch(t)
		if("N")
			cursor[1] = i + 1
			return null
		if("F")
			var/stop = findtext(text, ";", i)
			var/number_text = copytext(text, i + 1, stop)
			cursor[1] = stop + 1
			return decode_number(number_text)
		if("S", "P", "X", "Y")
			var/colon = findtext(text, ":", i)
			var/n = text2num(copytext(text, i + 1, colon))
			var/body = copytext(text, colon + 1, colon + 1 + n)
			cursor[1] = colon + 1 + n
			if(t == "S") return body
			if(t == "P") return text2path(body)
			if(t == "Y") return decode_value_file(body)
			return decode_savefile_text(body)
		if("L")
			var/stop = findtext(text, ";", i)
			var/count = text2num(copytext(text, i + 1, stop))
			cursor[1] = stop + 1
			var/list/L = list()
			for(var/k = 1, k <= count, k++)
				var/key = decode(text, cursor)
				var/marker = copytext(text, cursor[1], cursor[1] + 1)
				cursor[1] = cursor[1] + 1
				if(marker == "=")
					var/assoc = decode(text, cursor)
					L[key] = assoc
				else
					L += list(key)
			return L
	CRASH("bad stream token '[t]' at [i]")

/datum/save_stream/proc/decode_number(number_text)
	switch(number_text)
		if("inf") return 1.#INF
		if("-inf") return -1.#INF
		if("nan") return 1.#INF - 1.#INF
	return text2num(number_text)

/datum/save_stream/proc/decode_value_file(file_name)
	var/savefile/value_file = new(file_name)
	var/value
	value_file["v"] >> value
	del(value_file)
	fdel(file_name)
	return value

/datum/save_stream/proc/decode_savefile_text(body)
	if(!scratch) scratch = new /savefile()
	scratch.ImportText("v", ". = [body]")
	var/value
	scratch["v"] >> value
	scratch.dir.Cut()
	return value
