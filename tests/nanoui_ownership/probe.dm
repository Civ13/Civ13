#define FALSE 0
#define TRUE 1
#define STATUS_INTERACTIVE 3
var/global/datum/topic_state/default_state = new
var/global/datum/fixture_global/GLOB = new
var/global/failed = FALSE
var/global/browse_closes = 0
/datum/topic_state
/datum/fixture_global
	var/datum/fixture_manager/nanomanager = new
/datum/fixture_manager
	var/list/active = list()

/datum/fixture_manager/proc/ui_opened(datum/nanoui/UI)
	active |= UI
/datum/fixture_manager/proc/ui_closed(datum/nanoui/UI)
	active -= UI
	UI.fixture_close_count++
/datum/asset
/datum/asset/nanoui
/datum/asset/proc/send(user, file)
	return
/proc/get_asset_datum(path)
	return new path
/proc/sanitize(text)
	return text
/proc/fixture_browse_close(datum/nanoui/UI)
	browse_closes++
/datum/nanoui/var/fixture_close_count = 0
/datum/nanoui/proc/add_template(key, filename)
	templates[key] = filename
/datum/nanoui/proc/add_common_assets()
	return
/datum/nanoui/proc/open()
	GLOB.nanomanager.ui_opened(src)
/proc/check(value, label)
	if(!value)
		failed = TRUE
		world.log << "FAIL [label]"
/proc/new_ui(datum/nanoui/master = null)
	var/datum/nanoui/UI = new(null, null, "ownership", "ownership.tmpl", FALSE, FALSE, FALSE, null, master)
	UI.open()
	return UI
/proc/run_checks()
	var/datum/nanoui/master = new_ui()
	for(var/wave = 1 to 5)
		for(var/cycle = 1 to 100)
			var/datum/nanoui/child = new_ui(master)
			check(child.master_ui == master && (child in master.children), "constructor creates reciprocal ownership")
			child.close()
			check(!child.master_ui && !child.state && !child.is_auto_updating, "close clears child state")
			check(!(child in GLOB.nanomanager.active), "close releases manager adapter registration")
			child = null
		world.log << "OBS wave=[wave] retained_children=[master.children.len]"
	check(master.children.len == 0, "independent close releases master ownership")
	master.close()
	check(master.children.len == 0, "master close empties children")

	// Copy iteration must visit every sibling while each child removes itself.
	master = new_ui()
	var/list/held = list()
	for(var/cycle = 1 to 12)
		var/datum/nanoui/child = new_ui(master)
		child.is_auto_updating = TRUE
		held += child
		var/datum/nanoui/grandchild = new_ui(child)
		grandchild.is_auto_updating = TRUE
		held += grandchild
	master.close()
	check(master.children.len == 0, "recursive close empties master ownership")
	for(var/datum/nanoui/UI in held)
		check(!UI.master_ui && !UI.state && !UI.is_auto_updating && UI.children.len == 0, "recursive close visits all siblings and grandchildren")
		check(UI.fixture_close_count == 1, "recursive close invokes each child once")
	check(GLOB.nanomanager.active.len == 0, "recursive close releases all manager registrations")

	// Existing same-datum reopen remains possible with its window and template.
	var/datum/nanoui/reopened = held[1]
	var/window = reopened.window_id
	reopened.reinitialise("replacement.tmpl", list("value"=7))
	check((reopened in GLOB.nanomanager.active) && reopened.window_id == window && reopened.templates["main"] == "replacement.tmpl" && reopened.initial_data["value"] == 7, "reinitialise reopens same interface")
	check(!reopened.master_ui && master.children.len == 0, "reopen preserves existing cleared relationship semantics")
	reopened.close()
	reopened.close()
	check(!reopened.master_ui && reopened.children.len == 0 && GLOB.nanomanager.active.len == 0, "repeated close remains safe")
	if(!failed)
		world.log << "PASS nanoui ownership"
	shutdown()
/world/New()
	..()
	world.OpenPort(0)
	spawn(0)
		run_checks()
