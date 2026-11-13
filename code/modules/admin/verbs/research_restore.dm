// Gives a character back research and scholarship they lost to a bug, from a
// record such as the last save. It only adds: known research is merged in and
// each discipline keeps the higher of the two levels, so nothing learned since
// is taken away.
//
// The record is JSON, as read from a save:
// {"known": ["basic_tools", "weaving"], "scholarship": {"mathematics": 17.3}}

/mob/living/human/proc/admin_restore_research(list/record)
	var/list/added = list()
	if (!islist(record))
		return added
	var/list/known = clean_recipe_node_ids(known_recipe_nodes)
	for (var/node_id in clean_recipe_node_ids(record["known"]))
		if (!(node_id in known))
			known += node_id
			added += node_id
	known_recipe_nodes = known
	recipe_knowledge_initialized = TRUE
	var/list/levels = clean_scholarship(scholarship)
	var/list/restored = clean_scholarship(record["scholarship"])
	for (var/discipline in restored)
		if (restored[discipline] > scholar_level(discipline))
			levels[discipline] = restored[discipline]
			added += "[discipline] [restored[discipline]]"
	scholarship = levels
	refresh_recipe_knowledge_menus()
	return added

/client/proc/cmd_admin_restore_research(mob/living/human/H as mob in human_mob_list)
	set category = "Admin"
	set name = "Restore Research Knowledge"
	set desc = "Give a character back research and scholarship they lost to a bug. Only adds; never removes."
	if (!check_rights(R_ADMIN))
		return
	if (!istype(H) || QDELETED(H))
		return
	var/text = input(usr, "Paste the record as JSON, for example {\"known\": \[\"basic_tools\"\], \"scholarship\": {\"mathematics\": 17}}", "Restore research for [H.real_name]") as message|null
	if (!text || !istype(H) || QDELETED(H))
		return
	var/list/record
	try
		record = json_decode(text)
	catch
		record = null
	if (!islist(record))
		to_chat(usr, SPAN_WARNING("That is not a JSON object."))
		return
	var/list/added = H.admin_restore_research(record)
	if (!added.len)
		to_chat(usr, SPAN_NOTICE("[H.real_name] already knew all of that."))
		return
	log_admin("[key_name(usr)] restored research for [key_name(H)]: [jointext(added, ", ")]")
	message_admins("[key_name_admin(usr)] restored [added.len] research entries for [key_name_admin(H)].")
	to_chat(usr, SPAN_NOTICE("Restored for [H.real_name]: [jointext(added, ", ")]."))
