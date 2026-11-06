// Format 5 read path: the helper's savefile text (one ImportText per entry
// shard or list block) must build exactly the tree the per-token wire path
// builds, including the nodes it hands back one by one (text macros, inf).
// Stream fixture only; roundtrip.dm reaches it through text2path.
/proc/check_stream_text_matches_wire()
	var/handed_back = 0
	var/compared = 0
	for(var/z = 1, z <= world.maxz, z++)
		var/savefile/index = new("map_saves/[z].sav")
		var/datum/level_segment_reader/stream/R = new(index, 1)
		var/datum/save_stream/S = R.stream
		for(var/shard in S.dir("/entries"))
			var/savefile/text_tree = new
			var/savefile/wire_tree = new
			var/missing = S.import_text(text_tree, "/entries/[shard]")
			check(!isnull(missing), "stream helper refused a text request")
			handed_back += missing
			R.fill(wire_tree, "/entries/[shard]", 256)
			compared += compare_saved_trees(text_tree, wire_tree, "/entries/[shard]")
		var/top = 0
		for(var/id in S.dir("/lists"))
			top = max(top, text2num(id))
		for(var/block = 0, block * 512 < top, block++)
			var/savefile/text_tree = new
			var/savefile/wire_tree = new
			var/missing = S.import_text(text_tree, "/lists", block * 512 + 1, block * 512 + 512)
			check(!isnull(missing), "stream helper refused a list block")
			handed_back += missing
			for(var/id = block * 512 + 1, id <= min(top, block * 512 + 512), id++)
				R.fill(wire_tree, "/lists/[id]", 8)
			compared += compare_saved_trees(text_tree, wire_tree, "/lists")
		R.close()
	check(compared > 100, "stream text check compared too few nodes ([compared])")
	check(handed_back >= 2, "stream text check never handed a node back ([handed_back])")
	world.log << "Stream text read matches the wire read: [compared] nodes, [handed_back] handed back."

/proc/compare_saved_trees(savefile/A, savefile/B, path)
	A.cd = path
	B.cd = path
	var/list/a_children = A.dir.Copy()
	var/list/b_children = B.dir.Copy()
	check(a_children.len == b_children.len && !length(a_children - b_children), "stream text tree differs at [path]: [jointext(a_children, ",")] vs [jointext(b_children, ",")]")
	check(saved_values_match(A[path], B[path]), "stream text value differs at [path]")
	. = 1
	for(var/child in a_children)
		. += compare_saved_trees(A, B, path == "/" ? "/[child]" : "[path]/[child]")

/proc/saved_values_match(a, b)
	if(islist(a) || islist(b))
		if(!islist(a) || !islist(b)) return FALSE
		var/list/x = a
		var/list/y = b
		if(x.len != y.len) return FALSE
		for(var/i = 1, i <= x.len, i++)
			var/key = x[i]
			if(!saved_values_match(key, y[i])) return FALSE
			if(!isnum(key) && !isnull(key) && !saved_values_match(x[key], y[y[i]])) return FALSE
		return TRUE
	if(isfile(a) || isfile(b))
		return isfile(a) && isfile(b) && md5(a) == md5(b)
	if(isnum(a) && isnum(b) && a != a) return b != b // NaN
	return a == b
