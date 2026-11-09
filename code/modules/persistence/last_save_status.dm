// "Last save" line on the Status tab of persistent worlds. The time comes from
// the completed save's round.json (saved_at), so it survives restarts and
// handovers. A save in progress removes the marker first; the line keeps the
// previous completed save until the new one finishes.

#define LAST_SAVE_STATUS_REFRESH 600

var/global/persistence_last_save_checked = null

/proc/persistence_last_save_refresh()
	if(!isnull(persistence_last_save_checked) && world.time < persistence_last_save_checked + LAST_SAVE_STATUS_REFRESH) return
	persistence_last_save_checked = world.time
	if(!fexists("map_saves/save_complete.txt")) return
	var/marker = trim(file2text("map_saves/save_complete.txt"))
	if(!length(marker) || (persistence_last_save && persistence_last_save["generation"] == marker)) return
	var/list/stamp
	try
		var/list/state = json_decode(file2text("map_saves/round.json"))
		if(islist(state) && state["generation"] == marker && valid_persistence_save_stamp(state["saved_at"]))
			stamp = state["saved_at"]
	catch
		stamp = null
	persistence_last_save = list("generation" = marker, "stamp" = stamp)

/proc/persistence_last_save_ago(elapsed)
	var/minutes = round(max(0, elapsed) / 600)
	if(minutes < 1) return "just now"
	if(minutes < 60) return "[minutes] minute[minutes == 1 ? "" : "s"] ago"
	var/hours = round(minutes / 60)
	if(hours < 48) return "[hours] hour[hours == 1 ? "" : "s"] [minutes % 60] min ago"
	return "[round(hours / 24)] days ago"

/proc/persistence_last_save_text(now_timeofday = world.timeofday, now_realtime = world.realtime)
	if(!persistence_round_active()) return null
	persistence_last_save_refresh()
	if(!persistence_last_save) return "No completed save yet."
	var/list/stamp = persistence_last_save["stamp"]
	if(!valid_persistence_save_stamp(stamp)) return "Saved before save times were recorded."
	var/elapsed = wall_clock_elapsed(stamp["timeofday"], stamp["realtime"], now_timeofday, now_realtime)
	return "[stamp["utc"]] UTC ([persistence_last_save_ago(elapsed)])"

#undef LAST_SAVE_STATUS_REFRESH
