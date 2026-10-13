// Optional diagnostic wrappers. No extra yields or production overrides.
// Trace runs add overhead and must not be compared to untraced baselines.
var/latency_last_check = 0
var/latency_stage = "startup"
/proc/latency_trace_time()
	return world.timeofday
/proc/latency_trace_end(start, unit)
	var/elapsed = (world.timeofday-start+864000)%864000
	if(elapsed >= 2)
		world.log << "TRACE_SLOW_UNIT unit=[unit] ticks=[elapsed]"
/proc/latency_write(savefile/F, path, value)
	var/start = latency_trace_time()
	F[path] << value
	latency_trace_end(start, "write [path]")
/proc/latency_before_save(datum/A)
	var/type = A.type
	var/start = latency_trace_time()
	. = A.before_save()
	latency_trace_end(start, "before_save [type]")
/proc/latency_saved_vars(datum/A)
	var/type = A.type
	var/start = latency_trace_time()
	. = A.get_saved_vars()
	latency_trace_end(start, "get_saved_vars [type]")
/proc/latency_list_copy(list/L, start_index = 1, end_index = 0)
	var/start = latency_trace_time()
	. = end_index ? L.Copy(start_index, end_index) : L.Copy()
	latency_trace_end(start, "list_copy [L.len]")
/proc/latency_list_params(list/L)
	var/start = latency_trace_time()
	. = list2params(L)
	latency_trace_end(start, "list2params [L.len]")
/proc/latency_trace_check(level, work)
	var/now = latency_trace_time()
	if(latency_last_check)
		latency_trace_end(latency_last_check, "between_checks stage=[latency_stage] level=[level] work=[work]")
	latency_last_check = now
/proc/latency_reset(map_storage/S, field)
	var/count = length(S.vars[field])
	var/start = latency_trace_time()
	S.vars[field] = list()
	latency_trace_end(start, "reset [field] length=[count]")

/proc/latency_entry_path(map_storage/S, savefile/F, ref)
	var/start = latency_trace_time()
	. = S.entry_path(F, ref)
	latency_trace_end(start, "entry_path [ref]")
