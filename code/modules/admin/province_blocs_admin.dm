// Admin > Province Blocs: break up structuring (docs/character-slots.md).
// Mark groups as one bloc, clear a mark, freeze or unfreeze a group's
// province claims, or release a held province. Each needs a reason, which is
// logged and shown to admins.
/client/proc/province_blocs_admin()
	set name = "Province Blocs"
	set category = "Admin"
	set desc = "Mark factions as one bloc, freeze claims or release provinces."
	if(!check_rights(R_ADMIN))
		return
	if(!map || !map.province_map())
		to_chat(src, SPAN_WARNING("This land has no provinces."))
		return
	var/list/groups = list()
	for(var/faction in map.custom_civs)
		groups |= province_group_of(faction)
	var/list/marks = map.province_bloc_marks()
	var/list/frozen = map.province_frozen_groups()
	var/list/lines = list("<b>Province blocs</b>")
	for(var/group in groups)
		var/list/bloc = province_bloc_groups(group)
		var/list/names = list()
		for(var/other in bloc)
			if(other != group)
				names += province_group_name(other)
		lines += "[province_group_name(group)]: [province_bloc_holdings(group)] held by its bloc[names.len ? " (with [jointext(names, ", ")])" : ""][marks[group] ? ", marked bloc [marks[group]]" : ""][islist(frozen[group]) ? ", CLAIMS FROZEN" : ""]"
	to_chat(src, jointext(lines, "<br>"))
	var/choice = input(src, "What do you want to do?", "Province Blocs") as null|anything in list("Mark as one bloc", "Clear a bloc mark", "Freeze claims", "Unfreeze claims", "Release a province", "Nothing")
	if(!choice || choice == "Nothing")
		return
	var/list/named = list()
	for(var/group in groups)
		named[province_group_name(group)] = group
	var/reason
	switch(choice)
		if("Mark as one bloc")
			var/first = input(src, "First side:", "Province Blocs") as null|anything in named
			if(!first)
				return
			var/second = input(src, "Second side (shares the first one's cap):", "Province Blocs") as null|anything in (named - first)
			if(!second)
				return
			reason = sanitize(input(src, "Reason:", "Province Blocs") as text|null)
			if(!length(reason))
				return
			var/bloc = marks[named[first]] || marks[named[second]] || "bloc [md5("[named[first]]|[world.realtime]")]"
			marks[named[first]] = bloc
			marks[named[second]] = bloc
			province_blocs_log("marked [first] and [second] as one bloc", reason)
		if("Clear a bloc mark")
			var/list/marked = list()
			for(var/name in named)
				if(marks[named[name]])
					marked += name
			var/pick = input(src, "Which side?", "Province Blocs") as null|anything in marked
			if(!pick)
				return
			reason = sanitize(input(src, "Reason:", "Province Blocs") as text|null)
			if(!length(reason))
				return
			marks -= named[pick]
			province_blocs_log("cleared the bloc mark on [pick]", reason)
		if("Freeze claims", "Unfreeze claims")
			var/pick = input(src, "Which side?", "Province Blocs") as null|anything in named
			if(!pick)
				return
			reason = sanitize(input(src, "Reason:", "Province Blocs") as text|null)
			if(!length(reason))
				return
			if(choice == "Freeze claims")
				frozen[named[pick]] = list(reason, ckey, world.realtime)
				province_tell_leaders(named[pick], "Staff froze your side's province claims: [reason]")
			else
				frozen -= named[pick]
				province_tell_leaders(named[pick], "Staff lifted the freeze on your side's province claims.")
			province_blocs_log("[choice == "Freeze claims" ? "froze" : "unfroze"] province claims of [pick]", reason)
		if("Release a province")
			var/datum/province_map/P = map.province_map()
			var/list/held = list()
			for(var/c in map.province_holders())
				var/holder = province_holder_of(c)
				if(holder)
					held["[P.names[c]] ([province_group_name(holder)])"] = c
			var/pick = input(src, "Which province?", "Province Blocs") as null|anything in held
			if(!pick)
				return
			reason = sanitize(input(src, "Reason:", "Province Blocs") as text|null)
			if(!length(reason))
				return
			if(province_release(held[pick], reason, key_name(src)))
				province_blocs_log("released [pick]", reason)

/client/proc/province_blocs_log(action, reason)
	log_admin("[key_name(src)] [action]: [reason]")
	message_admins("[key_name_admin(src)] [action]: [reason]")
