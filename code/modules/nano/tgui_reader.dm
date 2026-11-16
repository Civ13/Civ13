// Shared base for read-only "snapshot" windows: a reader opens something, sees
// the data collected at that moment, and nothing is collected again until they
// open it again. Each window supplies only its data and any extra access rule.

// Binds one window to the thing being read and the mob reading it.
/datum/topic_state/reader
	var/datum/subject
	var/mob/reader
	// What a valid reader gets. Readers cannot act; a window with its own
	// navigation (the Crafting Atlas) raises this to STATUS_INTERACTIVE.
	var/granted_status = STATUS_UPDATE

/datum/topic_state/reader/New(datum/new_subject, mob/new_reader)
	..()
	subject = new_subject
	reader = new_reader

// An open snapshot stays readable while walking away; only a different
// subject, a different body, a lost client or the window's own rule closes it.
/datum/topic_state/reader/can_use_topic(var/src_object, var/mob/user)
	if (!user || !user.client || !subject || src_object != subject || user != reader || !reader_allowed(user))
		return STATUS_CLOSE
	return granted_status

// The window's own rule, rechecked on every status and transport check.
/datum/topic_state/reader/proc/reader_allowed(mob/user)
	return TRUE

/datum/topic_state/reader/proc/bound_to(datum/expected_subject, mob/expected_reader)
	return subject == expected_subject && reader == expected_reader

// The reader's open window on this subject. A window of another type or with a
// stale binding is closed and null is returned, so the caller opens a new one.
/proc/open_reader_ui(mob/user, datum/subject, ui_key, ui_type, state_type)
	var/datum/nanoui/ui = GLOB.nanomanager.get_open_ui(user, subject, ui_key)
	if (!ui)
		return null
	var/datum/topic_state/reader/old_state = ui.state
	if (!istype(ui, ui_type) || !istype(old_state, state_type) || !old_state.bound_to(subject, user))
		ui.close()
		return null
	return ui

// A window that keeps its snapshot. Manager refreshes recheck status and
// never collect data again.
/datum/nanoui/tgui/snapshot
	// The complete plain page, for windows that keep one for content the
	// modern screen cannot show.
	var/legacy_snapshot
	var/fixed_classic_page = FALSE
	var/reader_closed = FALSE

/datum/nanoui/tgui/snapshot/has_plain_page()
	return fixed_classic_page

/datum/nanoui/tgui/snapshot/get_html()
	if (!fixed_classic_page)
		return ..()
	if (!state || state.can_use_topic(src_object, user) == STATUS_CLOSE)
		return ""
	if (plain_page)
		return legacy_snapshot
	return ..()

/datum/nanoui/tgui/snapshot/update(var/force_open = FALSE)
	if (!user || !src_object || !state)
		close()
		return
	if (plain_page && fixed_classic_page)
		update_status(FALSE)
	else
		push_data(null, TRUE)

/datum/nanoui/tgui/snapshot/close()
	if (reader_closed)
		return
	reader_closed = TRUE
	legacy_snapshot = null
	return ..()
