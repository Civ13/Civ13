// Immutable log_error from 3ce4ece23, before bounded history.
/datum/error_viewer/error_cache/proc/log_error(exception/e, list/desclines, skip_count, datum/e_src)
	if (!istype(e))
		return // Abnormal exception, don't even bother

	var/erroruid = "[e.file],[e.line]"
	var/datum/error_viewer/error_source/error_source = error_sources[erroruid]
	if (!error_source)
		error_source = new(e)
		error_sources[erroruid] = error_source

	var/datum/error_viewer/error_entry/error_entry = new(e, desclines, skip_count)
	error_entry.error_source = error_source
	errors += error_entry
	error_source.errors += error_entry
	if (skip_count)
		return // Skip notifying admins about skipped errors.

	// Show the error to admins with debug messages turned on, but only if one
	//  from the same source hasn't been shown too recently
	if (config && error_source.next_message_at <= world.time)
		var/const/viewtext = "\[view]" // Nesting these in other brackets went poorly
		//log_debug("Runtime in <b>[e.file]</b>, line <b>[e.line]</b>: <b>[rhtml_encode(e.name)]</b> [error_entry.make_link(viewtext)]")
		log_debug("Runtime in [e.file],[e.line]: [html_encode(e.name)] [error_entry.make_link(viewtext)]")
		error_source.next_message_at = world.time + ERROR_MSG_DELAY

