// Real production typed codec. Separate write/verify entry points support a
// caller-controlled fresh-process reader using only the saved file.
// Caller explicitly invokes this proc in an isolated working directory. This is
// not a world-save generation test or full-world restore.
/proc/write_native_list_codec_fixture()
	if(fexists("list-codec.sav"))
		throw EXCEPTION("LIST_CODEC: refusing to overwrite prior fixture evidence")
	var/map_storage/writer = new
	var/savefile/F
	var/obj/native_holder = new /obj
	var/list/root = list()
	try
		var/list/equal_a = list("same", 7)
		var/list/equal_b = list("same", 7)
		var/list/empty_a = list()
		var/list/empty_b = list()
		var/list/self_cycle = list()
		self_cycle += list(self_cycle)
		var/list/cycle_a = list()
		var/list/cycle_b = list()
		cycle_a += list(cycle_b)
		cycle_b += list(cycle_a)
		var/list/assoc = list("number" = 42, "text" = "literal", "marker" = "__list__", "path" = "/lists/1", "kind" = "list", "ref" = "entry")
		var/list/held_overlays = native_holder.overlays
		var/list/held_underlays = native_holder.underlays
		var/list/held_filters = native_holder.filters
		root["equal_a"] = equal_a
		root["equal_alias"] = equal_a
		root["equal_b"] = equal_b
		root["empty_a"] = empty_a
		root["empty_b"] = empty_b
		root["self"] = self_cycle
		root["cycle_a"] = cycle_a
		root["cycle_b"] = cycle_b
		root["assoc"] = assoc
		root["overlays"] = held_overlays
		root["overlays_alias"] = held_overlays
		root["underlays"] = held_underlays
		root["filters"] = held_filters
		root["filters_alias"] = held_filters
		writer.clear_bookkeeping()
		F = new("list-codec.sav")
		F["/format_version"] << 3
		var/list/encoded = writer.encode_saved_value(F, root)
		F["/root"] << encoded
		if(writer.saving_list_pins.len > 19)
			throw EXCEPTION("LIST_CODEC: fixture exceeded bounded node count")
		F.Flush()
		F = null
		encoded = null
		writer.clear_bookkeeping()
		if(writer.saving_lists.len || writer.saving_list_pins.len || writer.saving_reference_pins.len)
			throw EXCEPTION("LIST_CODEC: writer bookkeeping retained pins")
	catch(var/exception/error)
		F = null
		writer.clear_bookkeeping()
		clear_native_list_codec_cycles(root)
		del(native_holder)
		throw error
	clear_native_list_codec_cycles(root)
	del(native_holder)
	return TRUE

/proc/verify_native_list_codec_fixture()
	if(!fexists("list-codec.sav"))
		throw EXCEPTION("LIST_CODEC: missing fixture evidence")
	var/map_storage/reader = new
	var/savefile/F
	var/list/restored
	var/list/assoc = list("number" = 42, "text" = "literal", "marker" = "__list__", "path" = "/lists/1", "kind" = "list", "ref" = "entry")
	try
		F = new("list-codec.sav")
		if(F["/format_version"] != 3)
			throw EXCEPTION("LIST_CODEC: format marker did not roundtrip")
		reader.clear_bookkeeping()
		var/list/reloaded_descriptor
		F["/root"] >> reloaded_descriptor
		restored = reader.decode_saved_value(F, reloaded_descriptor)
		if(!islist(restored) || restored.len != 14)
			throw EXCEPTION("LIST_CODEC: decoded root is not a fresh matching graph")
		if(restored["equal_a"] != restored["equal_alias"] || restored["overlays"] != restored["overlays_alias"] || restored["filters"] != restored["filters_alias"])
			throw EXCEPTION("LIST_CODEC: repeated held aliases were split")
		var/list/nodes = list(restored, restored["equal_a"], restored["equal_b"], restored["empty_a"], restored["empty_b"], restored["self"], restored["cycle_a"], restored["cycle_b"], restored["assoc"], restored["overlays"], restored["underlays"], restored["filters"])
		for(var/i = 1, i <= nodes.len, i++)
			if(!islist(nodes[i])) throw EXCEPTION("LIST_CODEC: decoded node is not a list")
			for(var/j = i + 1, j <= nodes.len, j++)
				if(nodes[i] == nodes[j]) throw EXCEPTION("LIST_CODEC: distinct nodes were merged")
		for(var/name in list("equal_a", "equal_b"))
			var/list/L = restored[name]
			if(L.len != 2 || L[1] != "same" || L[2] != 7)
				throw EXCEPTION("LIST_CODEC: equal-list scalar values changed")
		for(var/name in list("empty_a", "empty_b", "overlays", "underlays", "filters"))
			var/list/L = restored[name]
			if(L.len) throw EXCEPTION("LIST_CODEC: empty/native-empty list gained values")
		var/list/decoded_self = restored["self"]
		var/list/decoded_a = restored["cycle_a"]
		var/list/decoded_b = restored["cycle_b"]
		if(decoded_self.len != 1 || decoded_self[1] != decoded_self || decoded_a.len != 1 || decoded_b.len != 1 || decoded_a[1] != decoded_b || decoded_b[1] != decoded_a)
			throw EXCEPTION("LIST_CODEC: self or mutual cycles changed")
		var/list/decoded_assoc = restored["assoc"]
		if(decoded_assoc.len != assoc.len)
			throw EXCEPTION("LIST_CODEC: associative membership changed")
		for(var/key in assoc)
			if(decoded_assoc[key] != assoc[key])
				throw EXCEPTION("LIST_CODEC: numeric/string/literal-marker value changed: [key]")
		reader.clear_bookkeeping()
		if(reader.loaded_lists.len || reader.saving_list_pins.len)
			throw EXCEPTION("LIST_CODEC: reader bookkeeping retained lists")
		F = null
	catch(var/exception/error)
		F = null
		reader.clear_bookkeeping()
		clear_native_list_codec_cycles(restored)
		throw error
	clear_native_list_codec_cycles(restored)
	return TRUE

// Convenience wrapper is same-process only; separate invocations are needed
// for fresh-process evidence. Neither proc launches a process itself.
/proc/check_native_list_codec_roundtrip()
	write_native_list_codec_fixture()
	return verify_native_list_codec_fixture()

/proc/clear_native_list_codec_cycles(list/root)
	if(!root) return
	for(var/name in list("self", "cycle_a", "cycle_b"))
		var/list/L = root[name]
		if(islist(L)) L.Cut()
