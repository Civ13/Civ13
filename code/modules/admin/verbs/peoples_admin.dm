// Admin tools for peoples that formed in play (docs/peoples.md): list them,
// found one by hand, rename one, or merge one back into its first parent.
// Every change is logged and announced to admins.

// Renames a world people. Returns null on success, else why not.
/proc/rename_world_people(id, new_name)
	var/list/records = people_records()
	var/list/record = records[id]
	if (!islist(record))
		return "There is no such people."
	var/problem = people_name_problem(new_name)
	if (problem)
		return problem
	var/list/summaries = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.origin_id == id)
			summaries[H] = H.origin_summary()
	record["name"] = people_clean_name(new_name)
	if (world_peoples_cache)
		world_peoples_cache -= id
	for (var/mob/living/human/H in summaries)
		if (summaries[H])
			H.remove_note("Origin", summaries[H])
		H.add_note("Origin", H.origin_summary())
	return null

// Merges a world people back into its first parent: every member moves to the
// parent, the record goes, and characters not in the world follow when they
// next log in (peoples_merged). Returns the member count, or null.
/proc/merge_world_people(id)
	var/list/records = people_records()
	var/list/record = records[id]
	if (!islist(record))
		return null
	for (var/other in records)
		var/list/R = records[other]
		if (islist(R) && islist(R["parents"]) && (id in R["parents"]))
			return null // a people that others formed from stays until they are merged
	var/list/parents = record["parents"]
	var/parent_id = (islist(parents) && parents.len) ? parents[1] : record["root"]
	if (!origin_by_id(parent_id))
		parent_id = record["root"]
	. = 0
	var/list/summaries = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.origin_id == id)
			summaries[H] = H.origin_summary()
	records -= id
	if (world_peoples_cache)
		world_peoples_cache -= id
	var/list/merged = language_lineage_part("peoples_merged")
	merged[id] = parent_id
	for (var/mob/living/human/H in summaries)
		.++
		if (summaries[H])
			H.remove_note("Origin", summaries[H])
		H.origin_id = parent_id
		H.add_note("Origin", H.origin_summary())

/proc/world_peoples_report()
	var/list/lines = list()
	var/list/records = people_records()
	if (!records.len)
		return list("No peoples have formed in this world yet.")
	for (var/id in records)
		var/datum/origin/O = world_people(id)
		if (!O)
			lines += "[id]: unreadable record"
			continue
		var/list/parent_names = list()
		for (var/pid in O.parents)
			var/datum/origin/P = origin_by_id(pid)
			parent_names += P ? P.name : pid
		lines += "<b>[O.name]</b>: from [parent_names.len ? jointext(parent_names, " and ") : "?"], speaking [O.language], formed in year [O.formed_year][O.homeland ? " at [O.homeland]" : ""][O.nation ? " among the [O.nation]" : ""][O.imported ? ", arrived with a traveller" : ""]. [people_members(id)] living."
	return lines

/proc/world_people_choices()
	var/list/choices = list()
	for (var/id in people_records())
		var/datum/origin/O = world_people(id)
		if (O)
			choices["[O.name] ([people_members(id)] living)"] = id
	return choices

/client/proc/cmd_admin_check_peoples()
	set category = "Admin"
	set name = "Check Peoples"
	set desc = "Every people that formed in this world: parents, language, where and when, and living members."
	if (!check_rights(R_ADMIN))
		return
	to_chat(usr, jointext(world_peoples_report(), "<br>"))

/client/proc/cmd_admin_found_people()
	set category = "Admin"
	set name = "Found People"
	set desc = "Record a new people by hand, for events or to fix a split. Nobody joins it until you Set Origin."
	if (!check_rights(R_ADMIN))
		return
	var/list/choices = all_people_choices()
	var/picked = input(usr, "Which people does it grow from?", "Found People") as null|anything in sortList(choices)
	if (!picked)
		return
	var/datum/origin/parent = choices[picked]
	var/wanted = input(usr, "What is the new people called? (3 to 24 letters, not a real-world people.)", "Found People") as text|null
	if (isnull(wanted))
		return
	var/problem = people_name_problem(wanted)
	if (problem)
		to_chat(usr, SPAN_WARNING(problem))
		return
	var/datum/origin/O = found_people(people_clean_name(wanted), list(parent.id), parent.language, land_display_name(map))
	if (!O)
		to_chat(usr, SPAN_WARNING("The people could not be recorded."))
		return
	log_admin("[key_name(usr)] founded the people [O.name] from [parent.name].")
	message_admins("[key_name_admin(usr)] founded the people [O.name] from [parent.name].")

/client/proc/cmd_admin_rename_people()
	set category = "Admin"
	set name = "Rename People"
	set desc = "Rename a people that formed in this world."
	if (!check_rights(R_ADMIN))
		return
	var/list/choices = world_people_choices()
	if (!choices.len)
		to_chat(usr, "No peoples have formed in this world yet.")
		return
	var/picked = input(usr, "Which people?", "Rename People") as null|anything in choices
	if (!picked)
		return
	var/id = choices[picked]
	var/datum/origin/O = world_people(id)
	var/old_name = O ? O.name : id
	var/wanted = input(usr, "New name for the [old_name]:", "Rename People", old_name) as text|null
	if (isnull(wanted))
		return
	var/problem = rename_world_people(id, wanted)
	if (problem)
		to_chat(usr, SPAN_WARNING(problem))
		return
	log_admin("[key_name(usr)] renamed the people [old_name] to [people_clean_name(wanted)].")
	message_admins("[key_name_admin(usr)] renamed the people [old_name] to [people_clean_name(wanted)].")

/client/proc/cmd_admin_merge_people()
	set category = "Admin"
	set name = "Merge People Back"
	set desc = "Undo a people that formed in this world: its members return to the people it grew from."
	if (!check_rights(R_ADMIN))
		return
	var/list/choices = world_people_choices()
	if (!choices.len)
		to_chat(usr, "No peoples have formed in this world yet.")
		return
	var/picked = input(usr, "Which people?", "Merge People Back") as null|anything in choices
	if (!picked)
		return
	var/id = choices[picked]
	var/datum/origin/O = world_people(id)
	var/old_name = O ? O.name : id
	if (alert(usr, "Merge the [old_name] back? Every member returns to the people it grew from. This cannot be undone.", "Merge People Back", "Merge", "Cancel") != "Merge")
		return
	var/moved = merge_world_people(id)
	if (isnull(moved))
		to_chat(usr, SPAN_WARNING("The [old_name] cannot be merged: another people grew from them. Merge that one first."))
		return
	log_admin("[key_name(usr)] merged the people [old_name] back ([moved] characters moved).")
	message_admins("[key_name_admin(usr)] merged the people [old_name] back ([moved] characters moved).")
