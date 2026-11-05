// Stream save benchmark and converter. Run one mode per Dream Daemon process
// so each memory peak is clean:
//
//   DreamDaemon bench.dmb -trusted -invisible -params "mode=convert&src=2.sav&dst=2.stream"
//
// Modes:
//   idle            baseline process memory
//   convert         walk a level /savefile (format 3) and write it as a stream (put_text)
//   verify          compare every savefile node with the stream (src=sav, dst=stream)
//   read_savefile   read every node of a level /savefile (load-side memory today)
//   read_stream     read every node of a stream through the helper
//   write_savefile  replay a stream into a new /savefile (save-side memory today)
//   write_stream    replay a stream into a new stream (save-side memory with the helper)
//
// Writes bench_<mode>.json beside the dmb and appends phase markers to
// bench_phases.log so an external sampler (diagnosis/address_space.py) can
// line its snapshots up with the phases. Linux results include /proc memory.
/world/New()
	..()
	spawn(1)
		var/list/result = list("mode" = world.params["mode"], "ok" = FALSE)
		var/started = world.timeofday
		try
			run_bench(result)
		catch(var/exception/e)
			result["error"] = "[e] at [e.file]:[e.line]"
		result["seconds"] = (world.timeofday - started) / 10
		result["memory_end"] = proc_memory()
		text2file(json_encode(result), "bench_[world.params["mode"]].json")
		phase("exit")
		shutdown()

/datum/proc/Destroy()
	return

/proc/phase(name)
	text2file("[num2text(world.realtime, 12)] [world.timeofday] [world.params["mode"]] [name]\n", "bench_phases.log")
	world.log << "phase [name]"

// Linux only: VmPeak/VmHWM/VmRSS from /proc (file2text cannot read /proc).
/proc/proc_memory()
	if(world.system_type != UNIX) return null
	shell("cat /proc/[world.process]/status > bench_status.txt")
	var/list/memory = list()
	for(var/line in splittext(file2text("bench_status.txt"), "\n"))
		var/key = copytext(line, 1, findtext(line, ":"))
		if(key in list("VmPeak", "VmSize", "VmHWM", "VmRSS", "VmData"))
			memory[key] = text2num(splittext(trim_text(copytext(line, findtext(line, ":") + 1)), " ")[1])
	return memory

/proc/trim_text(t)
	while(length(t) && (copytext(t, 1, 2) == " " || copytext(t, 1, 2) == "\t")) t = copytext(t, 2)
	return t

/proc/run_bench(list/result)
	var/mode = world.params["mode"]
	var/src_file = world.params["src"]
	var/dst_file = world.params["dst"]
	phase("start")
	result["memory_start"] = proc_memory()
	switch(mode)
		if("idle")
			sleep(50)
		if("convert")
			bench_convert(result, src_file, dst_file)
		if("verify")
			bench_verify(result, src_file, dst_file)
		if("read_savefile")
			var/savefile/F = new(src_file)
			var/list/counts = list("nodes" = 0)
			walk_savefile(F, "", 0, counts, null, null)
			result["nodes"] = counts["nodes"]
			phase("read_complete")
			result["memory_peak_phase"] = proc_memory()
			F = null
			sleep(20)
			phase("released")
		if("read_stream")
			var/datum/save_stream/S = new
			if(!S.open_read(src_file)) throw EXCEPTION(S.last_error)
			var/nodes = 0
			var/index = 0
			do
				var/list/batch = S.iterate(index, 256)
				nodes += batch.len / 2
				index = S.next_index
				if(!batch.len) break
			while(TRUE)
			result["nodes"] = nodes
			result["helper"] = S.stats()
			phase("read_complete")
			result["memory_peak_phase"] = proc_memory()
			S.close()
		if("write_savefile", "write_stream")
			var/datum/save_stream/source = new
			if(!source.open_read(src_file)) throw EXCEPTION(source.last_error)
			var/savefile/F
			var/datum/save_stream/sink
			if(mode == "write_savefile")
				if(fexists(dst_file)) fdel(dst_file)
				F = new(dst_file)
			else
				sink = new
				if(!sink.open_write(dst_file)) throw EXCEPTION(sink.last_error)
			var/nodes = 0
			var/index = 0
			do
				var/list/batch = source.iterate(index, 256)
				if(!batch.len) break
				index = source.next_index
				for(var/i = 1, i < batch.len, i += 2)
					if(F)
						F[batch[i]] << batch[i + 1]
					else if(!sink.put(batch[i], batch[i + 1]))
						throw EXCEPTION(sink.last_error)
					nodes++
			while(TRUE)
			source.close()
			result["nodes"] = nodes
			phase("written")
			result["memory_peak_phase"] = proc_memory()
			if(F)
				F.Flush()
				F = null
			else
				result["summary"] = sink.finish(TRUE)
			phase("closed")
		else
			throw EXCEPTION("unknown mode [mode]")
	result["ok"] = TRUE

// Visits every node. With a stream, sends each subtree at depth 3 (one entry,
// map row or list item) or each leaf as BYOND savefile text.
/proc/walk_savefile(savefile/F, path, depth, list/counts, datum/save_stream/S, list/result)
	F.cd = path || "/"
	var/list/children = F.dir.Copy()
	if(!children.len || (S && depth >= 3))
		counts["nodes"]++
		if(S)
			send_subtree(F, path, S, counts)
		else
			var/value
			F[path] >> value
		return
	for(var/name in children)
		walk_savefile(F, "[path]/[name]", depth + 1, counts, S, result)

// BYOND cannot import its own mutable_appearance or object(".0") text, so those leaves are read
// natively and sent with put() (the stream stores them as savefile bytes).
/proc/send_subtree(savefile/F, path, datum/save_stream/S, list/counts)
	var/text = F.ExportText(path || "/")
	if(!findtext(text, "mutable_appearance(") && !findtext(text, "object(\""))
		if(!S.put_text(path, text)) throw EXCEPTION(S.last_error)
		return
	F.cd = path
	var/list/children = F.dir.Copy()
	if(children.len)
		for(var/name in children)
			send_subtree(F, "[path]/[name]", S, counts)
		return
	var/value
	F[path] >> value
	counts["native_values"]++
	if(!S.put(path, value)) throw EXCEPTION(S.last_error)

/proc/bench_convert(list/result, src_file, dst_file)
	var/savefile/F = new(src_file)
	result["format_version"] = F["/format_version"]
	var/datum/save_stream/S = new
	if(!S.open_write(dst_file)) throw EXCEPTION(S.last_error)
	var/list/counts = list("nodes" = 0, "native_values" = 0)
	walk_savefile(F, "", 0, counts, S, result)
	result["subtrees"] = counts["nodes"]
	result["native_values"] = counts["native_values"]
	phase("converted")
	result["memory_peak_phase"] = proc_memory()
	result["summary"] = S.finish(TRUE)
	if(!result["summary"]) throw EXCEPTION(S.last_error)
	result["source_bytes"] = length(file(src_file))

// Compares every savefile leaf with the stream: values decoded both ways (an
// undefined type path reads as null on both sides) and type paths as text.
/proc/bench_verify(list/result, src_file, dst_file)
	var/savefile/F = new(src_file)
	var/datum/save_stream/S = new
	if(!S.open_read(dst_file)) throw EXCEPTION(S.last_error)
	var/list/state = list("leaves" = 0, "mismatches" = 0, "examples" = list(), "types" = 0)
	verify_walk(F, "", S, state)
	result["leaves"] = state["leaves"]
	result["type_paths_checked"] = state["types"]
	result["mismatches"] = state["mismatches"]
	result["examples"] = state["examples"]
	result["stream_nodes"] = S.stats()
	S.close()
	if(state["mismatches"]) throw EXCEPTION("[state["mismatches"]] mismatches")

/proc/verify_walk(savefile/F, path, datum/save_stream/S, list/state)
	F.cd = path || "/"
	var/list/children = F.dir.Copy()
	if(children.len)
		for(var/name in children)
			verify_walk(F, "[path]/[name]", S, state)
		return
	state["leaves"]++
	var/expected
	F[path] >> expected
	var/actual = S.get(path)
	var/ok = S.found && values_match(expected, actual)
	if(ok && copytext(path, length(path) - 4) == "/type")
		state["types"]++
		var/raw = S.lib_call("savestream_get", list(S.id, path))
		var/text = F.ExportText(path)
		ok = findtext(text, copytext(raw, findtext(raw, ":") + 1)) != 0
	if(!ok)
		state["mismatches"]++
		var/list/examples = state["examples"]
		if(examples.len < 20) examples += path

/proc/values_match(a, b)
	if(islist(a) && islist(b))
		var/list/x = a
		var/list/y = b
		if(x.len != y.len) return FALSE
		for(var/i = 1, i <= x.len, i++)
			if(!values_match(x[i], y[i])) return FALSE
			var/k = x[i]
			if(!isnum(k) && !isnull(k) && !values_match(x[k], y[y[i]])) return FALSE
		return TRUE
	if(isnum(a) && isnum(b))
		return a == b || (a != a && b != b)
	if(isicon(a) || isfile(a))
		return (isicon(b) || isfile(b)) && md5(a) == md5(b)
	if(!isnull(a) && !istext(a) && !ispath(a) && !isnum(a))
		var/savefile/T = new
		T["a"] << a
		T["b"] << b
		return T.ExportText("a") == T.ExportText("b")
	return a == b
