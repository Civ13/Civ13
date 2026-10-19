// The runner supplies production defaults and the unchanged ClickOn early gate.
// Modifier handlers are route counters, not rendered client/examine acceptance.
/mob/var/tmp/fixture_clicks = 0
/mob/var/tmp/fixture_shifts = 0
/mob/var/tmp/list/fixture_icon_coordinates
/mob/proc/CtrlShiftClickOn(atom/A)
	return
/mob/proc/ShiftMiddleClickOn(atom/A)
	return
/mob/proc/MiddleClickOn(atom/A)
	return
/mob/proc/ShiftClickOn(atom/A)
	fixture_shifts++
/mob/proc/AltClickOn(atom/A)
	return
/mob/proc/CtrlClickOn(atom/A)
	return

/proc/check_input_runtime()
	sleep(2) // The unchanged click gate rejects world.time == its zero default.
	var/list/counts = list()
	blackout_click_increment(counts, "entry")
	check(counts["entry"] == 1, "fixed click counter did not increment")
	counts["entry"] = 65535
	blackout_click_increment(counts, "entry")
	blackout_click_increment(counts, "private raw target text")
	check(counts["entry"] == 65535 && counts.len == 1, "click counter unbounded or accepted arbitrary code")
	var/list/fields = list("next_click", "next_move", "may_do_after", "may_do_mob")
	var/list/stale = list("next_click" = 10000000, "next_move" = 10000000, "may_do_after" = FALSE, "may_do_mob" = FALSE)
	var/mob/living/human/H = new(locate(2,2,1))
	H.name = "durable identity"
	H.persistence_owner_ckey = "inputaccount"
	H.blackout_click_owner = "inputaccount"
	H.blackout_click_client_ref = "fixture unavailable client"
	H.blackout_click_counts = list("entry" = 9)
	H.blackout_click_started = world.time
	H.blackout_click_expires = world.time + 100
	H.blackout_click_trace("entry")
	check(H.blackout_click_counts["entry"] == 9, "trace counted without an authenticated current client")
	var/obj/item/test/I = new(H)
	I.number = 731
	for(var/key in fields)
		H.vars[key] = stale[key]
	var/savefile/F = new("input-runtime.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, H, 1)
	var/path = map_storage.entry_path(F, ref)
	F.cd = path
	for(var/key in list("blackout_click_owner", "blackout_click_client_ref", "blackout_click_counts", "blackout_click_started", "blackout_click_expires"))
		check(!(key in F.dir), "private runtime click trace exported: [key]")
	for(var/key in fields)
		check(!(key in F.dir), "runtime input field exported: [key]")
		check(H.vars[key] == stale[key], "saving reset live input state: [key]")
	// Inject fields from a historical completed v2 save into an actual disk save.
	for(var/key in fields)
		F["[path]/[key]"] << list("kind" = "value", "value" = stale[key])
	F = null
	F = new("input-runtime.sav")
	map_storage.clear_bookkeeping()
	var/mob/living/human/R = map_storage.Load_Entry(F, ref, starting_loc = locate(3,2,1))
	for(var/key in fields)
		check(R.vars[key] == initial(R.vars[key]), "legacy input field restored: [key]")
	check(R.name == H.name && R.persistence_owner_ckey == H.persistence_owner_ckey, "input migration changed identity")
	var/obj/item/test/RI = locate(/obj/item/test) in R
	check(RI && RI.number == 731 && R.loc == locate(3,2,1), "input migration changed inventory or location")
	R.ClickOn(I, "shift=1")
	check(R.fixture_shifts == 1, "restored shift route blocked by old click clock")
	R.ClickOn(I, null)
	check(!R.fixture_clicks, "live one-tick click cooldown bypassed")
	sleep(2)
	R.ClickOn(I, "icon-x=7&icon-y=11")
	check(R.fixture_clicks == 1, "restored ordinary click route blocked")
	check(R.fixture_icon_coordinates[1] == 7 && R.fixture_icon_coordinates[2] == 11, "ordinary click coordinates not parsed")
	R.next_click = world.time + 100
	R.may_do_after = FALSE
	R.may_do_mob = FALSE
	var/live_deadline = R.next_click
	R.ClickOn(I, "shift=1")
	check(R.fixture_shifts == 1 && R.next_click == live_deadline, "live future click cooldown reset")
	// Import into an existing replacement must not erase its active action state.
	map_storage.clear_bookkeeping()
	map_storage.Load_Entry(F, ref, replacement = R)
	check(R.next_click == live_deadline && !R.may_do_after && !R.may_do_mob, "replacement import reset live action state")
	// Unversioned flat entries use the same exclusion, before legacy decoding.
	var/savefile/L = new("input-legacy.sav")
	L["/entries/1/type"] << /mob/living/human
	for(var/key in fields)
		L["/entries/1/[key]"] << stale[key]
	map_storage.clear_bookkeeping()
	var/mob/living/human/legacy = map_storage.Load_Entry(L, 1, starting_loc = locate(4,2,1))
	for(var/key in fields)
		check(legacy.vars[key] == initial(legacy.vars[key]), "flat legacy input field restored: [key]")
	map_storage.clear_bookkeeping()
	qdel(H)
	qdel(R)
	qdel(legacy)
