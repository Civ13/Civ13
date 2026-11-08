// Minimal world for the stream save round trip. Writes a tree with every value
// kind through the shim and helper, reads it back and compares.
/datum/proc/Destroy()
	return
/datum/probe_thing
	var/a = 1


/world/New()
	..()
	spawn(1)
		var/list/result = list("ok" = FALSE)
		try
			result = run_roundtrip()
		catch(var/exception/e)
			result["error"] = "[e] at [e.file]:[e.line]"
		text2file(json_encode(result), "result.json")
		shutdown()

/proc/sample_values()
	var/obj/o = new
	o.overlays += 'probe.dmi'
	var/list/cyclic = list(1, 2)
	var/image/I = image('probe.dmi', icon_state = "x")
	I.pixel_x = 3
	var/mutable_appearance/M = new(I)
	M.layer = 2.91
	return list(
		"/format_version" = 3,
		"/generation" = "round-v2:abc",
		"/entries/0/1/type" = /datum/probe_thing,
		"/entries/0/1/name" = list("kind" = "value", "value" = "he said \"hi\"\nnew ü \[x\] \\"),
		"/entries/0/1/n" = list("kind" = "value", "value" = 1.123456789),
		"/entries/0/1/big" = 16777217,
		"/entries/0/1/tiny" = -1e-30,
		"/entries/0/1/inf" = 1.#INF,
		"/entries/0/1/ninf" = -1.#INF,
		"/entries/0/1/empty" = "",
		"/entries/0/1/content" = list("1;2;3", "4"),
		"/entries/0/1/nested" = list(null, /datum, "x" = list(), "y" = list("z" = 3), cyclic),
		"/entries/0/1/icon" = list("kind" = "value", "value" = 'probe.dmi'),
		"/entries/0/1/icon2" = list("kind" = "value", "value" = 'probe.dmi'),
		"/entries/0/1/appearance" = list("kind" = "value", "value" = o.appearance),
		"/entries/0/1/overlays" = list("kind" = "value", "value" = o.overlays.Copy()),
		// Repeats reuse the stream's first encoding (text token, value file copy).
		"/entries/0/1/appearance2" = list("kind" = "value", "value" = o.appearance),
		"/entries/0/1/overlays2" = list("kind" = "value", "value" = o.overlays.Copy()),
		"/entries/0/1/owner" = list("kind" = "entry", "ref" = 1),
		"/entries/0/1/mutable" = list("kind" = "value", "value" = M),
		"/entries/0/1/proper" = list("kind" = "value", "value" = "\improper turkey"),
		"/entries/0/2/name" = "\proper Bob and \the axe",
		"/map/1/1/1" = 1,
	)

/proc/same(a, b)
	if(islist(a) && islist(b))
		var/list/x = a
		var/list/y = b
		if(x.len != y.len) return FALSE
		for(var/i = 1, i <= x.len, i++)
			if(!same(x[i], y[i])) return FALSE
			var/k = x[i]
			if(!isnum(k) && !isnull(k) && !same(x[k], y[y[i]])) return FALSE
		return TRUE
	if(isnum(a) && isnum(b))
		if(a != a && b != b) return TRUE
		return a == b
	if(isicon(a) || isfile(a))
		return "[a]" == "[b]" && (isicon(b) || isfile(b)) && md5(a) == md5(b)
	if(!isnull(a) && !istext(a) && !ispath(a) && !isnum(a))
		// Appearances compare by savefile text. A mutable appearance read back
		// from a savefile gains explicit defaults (plane = 0), so compare the
		// expected value after the same savefile round trip.
		var/savefile/F = new
		F["a0"] << a
		var/normalized
		F["a0"] >> normalized
		F["a"] << normalized
		F["b"] << b
		return F.ExportText("a") == F.ExportText("b")
	// Text macros (\improper) are bytes of the text; compare lengths too.
	if(istext(a) && istext(b) && length(a) != length(b)) return FALSE
	return a == b

/proc/run_roundtrip()
	var/list/result = list("ok" = FALSE)
	var/list/values = sample_values()
	var/datum/save_stream/S = new
	if(!S.open_write("roundtrip.stream"))
		result["error"] = "open_write: [S.last_error]"
		return result
	for(var/path in values)
		if(!S.put(path, values[path]))
			result["error"] = "put [path]: [S.last_error]"
			return result
	// The repeated file and appearance were encoded once and reused.
	var/reused = S.value_tokens ? S.value_tokens.len : 0
	var/list/summary = S.finish()
	result["summary"] = summary
	if(!summary || !summary["published"])
		result["error"] = "finish: [S.last_error]"
		return result
	if(!S.open_read("roundtrip.stream"))
		result["error"] = "open_read: [S.last_error]"
		return result
	var/list/mismatches = list()
	for(var/path in values)
		var/value = S.get(path)
		if(!S.found || !same(values[path], value))
			mismatches += path

	if(!isnull(S.get("/missing")) || S.found) mismatches += "/missing"
	var/list/names = S.dir("/entries/0/1")
	if(names.len != 19) mismatches += "dir:[names.len]"
	if(reused < 2) mismatches += "reused:[reused]"
	// A repeated value file body is decoded once per stream; datums never are.
	var/obj/shown = new
	shown.overlays += 'probe.dmi'
	for(var/copy in list("value_a.sav", "value_b.sav"))
		var/savefile/V = new(copy)
		V["v"] << shown.appearance
		del(V)
	var/first = S.decode_value_file("value_a.sav")
	var/second = S.decode_value_file("value_b.sav")
	if(!S.decoded_values || S.decoded_values.len != 1 || first != second || !same(shown.appearance, second)) mismatches += "value file decode reuse"
	if(fexists("value_a.sav") || fexists("value_b.sav")) mismatches += "value files kept"
	// Closing the stream deletes the kept value-file templates.
	if(S.value_tokens || flist("savestream_template_").len) mismatches += "templates kept"
	S.close()
	// A truncated stream is never readable.
	var/datum/save_stream/broken = new
	if(broken.open_read("roundtrip.missing")) mismatches += "opened a missing file"
	result["missing_error"] = broken.last_error
	// A batch the helper cannot parse fails the session at finish.
	var/datum/save_stream/bad = new
	if(bad.open_write("bad.stream"))
		bad.batch += "W2:/aZ"
		bad.flush()
		if(bad.finish()) mismatches += "bad batch published"
		result["bad_error"] = bad.last_error
	if(fexists("bad.stream")) mismatches += "bad.stream exists"
	result["mismatches"] = mismatches
	var/list/text_mismatches = run_text_roundtrip()
	result["text_mismatches"] = text_mismatches
	mismatches += text_mismatches
	result["ok"] = !mismatches.len
	return result

// The level writer's drain (level_stream.dm): a scratch savefile goes to the
// helper as one piece of savefile text per top-level subtree, and the nodes
// whose values do not survive that text are rewritten natively. Mirrors
// persistence_stream_text_unsafe in saving.dm, which this fixture does not
// compile; keep the two in step.
/proc/text_unsafe(value, depth = 0)
	if(isnull(value) || ispath(value)) return FALSE
	if(istext(value)) return length("[value]") != length(value)
	if(isnum(value)) return value != value || value == 1.#INF || value == -1.#INF
	if(!islist(value)) return TRUE
	var/list/L = value
	switch(L["kind"])
		if("value")
			return text_unsafe(L["value"], depth + 1)
		if("scalars")
			return scalars_text_unsafe(L["keys"]) || scalars_text_unsafe(L["values"])
		if("entry", "list", "turf", "area", "map", "zone")
			return FALSE
	if(depth > 3) return FALSE
	for(var/i = 1, i <= L.len, i++)
		var/key = L[i]
		if(text_unsafe(key, depth + 1)) return TRUE
		if(!isnum(key) && !isnull(key) && text_unsafe(L[key], depth + 1)) return TRUE
	return FALSE

/proc/scalars_text_unsafe(list/L)
	if(!islist(L)) return FALSE
	for(var/i = 1, i <= L.len, i++)
		var/item = L[i]
		if(istext(item))
			if(length("[item]") != length(item)) return TRUE
		else if(isnum(item))
			if(item != item || item == 1.#INF || item == -1.#INF) return TRUE
	return FALSE

/proc/run_text_roundtrip()
	var/list/mismatches = list()
	var/list/values = sample_values()
	values["/entries/0/3/nan"] = 1.#INF - 1.#INF
	values["/entries/0/3/scalars"] = list("kind" = "scalars", "length" = 3, "keys" = list("a", 2, "\improper c"), "values" = list(1.#INF, null, "x"))
	values["/entries/0/3/precise"] = 1234567.875
	values["/entries/0/3/quoted"] = "tab\tquote\" back\\ end"
	var/savefile/scratch = new
	var/list/native = list()
	for(var/path in values)
		if(path == "/format_version") continue
		var/value = values[path]
		// note_stream_native_value: resources and appearances leave a null
		// placeholder in the text and reach the stream natively.
		if(text_unsafe(value))
			native[path] = value
			if(!istext(value) && !isnum(value)) value = null
		scratch[path] << value
	var/datum/save_stream/S = new
	if(!S.open_write("text.stream"))
		return list("text open_write: [S.last_error]")
	scratch.cd = "/"
	for(var/key in scratch.dir.Copy())
		if(!S.put_text("/[key]", scratch.ExportText("/[key]")))
			return list("put_text /[key]: [S.last_error]")
		scratch.cd = "/"
	for(var/path in native)
		if(!S.put(path, native[path]))
			return list("native put [path]: [S.last_error]")
	var/list/summary = S.finish()
	if(!summary || !summary["published"])
		return list("text finish: [S.last_error]")
	if(!S.open_read("text.stream"))
		return list("text open_read: [S.last_error]")
	for(var/path in values)
		if(path == "/format_version") continue
		var/value = S.get(path)
		if(!S.found || !same(values[path], value))
			mismatches += "text:[path]"
	if(native.len < 6) mismatches += "text:native paths [native.len]"
	S.close()
	return mismatches
