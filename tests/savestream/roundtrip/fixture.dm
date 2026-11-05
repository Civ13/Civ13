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
	if(names.len != 17) mismatches += "dir:[names.len]"
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
	result["ok"] = !mismatches.len
	return result
