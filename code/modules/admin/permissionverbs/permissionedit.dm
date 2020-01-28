/client/proc/edit_admin_permissions()
	set category = "Admin"
	set name = "Permissions Panel"
	set desc = "Edit admin permissions"
	if (!check_rights(R_PERMISSIONS))	return
	usr.client.holder.edit_admin_permissions()

/datum/admins/proc/edit_admin_permissions()
	if (!check_rights(R_PERMISSIONS))	return

	var/output = {"<!DOCTYPE html>
<html>
<head>
<title>Permissions Panel</title>
<script type='text/javascript' src='search.js'></script>
<link rel='stylesheet' type='text/css' href='panels.css'>
</head>
<body onload='selectTextField();updateSearch();'>
<div id='main'><table id='searchable' cellspacing='0'>
<tr class='title'>
<th style='width:125px;text-align:right;'>CKEY <a class='small' href='?src=\ref[src];editrights=add'>\[+\]</a></th>
<th style='width:125px;'>RANK</th><th style='width:100%;'>PERMISSIONS</th>
</tr>
"}

	for (var/adm_ckey in admin_datums)
		var/datum/admins/D = admin_datums[adm_ckey]
		if (!D)	continue
		var/rank = D.rank ? D.rank : "*none*"
		var/rights = rights2text(D.rights," ")
		if (!rights)	rights = "*none*"

		output += "<tr>"
		output += "<td style='text-align:right;'>[adm_ckey] <a class='small' href='?src=\ref[src];editrights=remove;ckey=[adm_ckey]'>\[-\]</a></td>"
		output += "<td><a href='?src=\ref[src];editrights=rank;ckey=[adm_ckey]'>[rank]</a></td>"
		output += "<td><a class='small' href='?src=\ref[src];editrights=permissions;ckey=[adm_ckey]'>[rights]</a></td>"
		output += "</tr>"

	output += {"
</table></div>
<div id='top'><b>Search:</b> <input type='text' id='filter' value='' style='width:70%;' onkeyup='updateSearch();'></div>
</body>
</html>"}

	usr << browse(output,"window=editrights;size=600x500")

// see admin/topic.dm
/datum/admins/proc/log_admin_rank_modification(var/adm_ckey, var/new_rank)

	if (!usr.client)
		return

	if (!usr.client.holder || !(usr.client.holder.rights & R_PERMISSIONS))
		usr << "<span class = 'red'>You do not have permission to do this!</span>"
		return

	if (!adm_ckey || !new_rank)
		return

	adm_ckey = ckey(adm_ckey)

	if (!adm_ckey)
		return

	if (!istext(adm_ckey) || !istext(new_rank))
		return

	var/F = "SQL/admins.txt"
	var/list/admincheck = splittext(file2text(F),"|||\n")
	if (isemptylist(admincheck))
		return

	if (new_rank == "Removed")
		//clean the list. Start from the end and skip repeated entries.
		var/list/admincheck2 = list()
		var/list/ckeyschecked = list()
		for(var/i=admincheck.len, i>=1, i--)
			var/list/admincheck_two = splittext(admincheck[i], ";")
			if (admincheck_two.len && !(admincheck_two[1] in ckeyschecked))
				if (admincheck_two[1] != "[adm_ckey]")
					ckeyschecked += list(admincheck_two[1])
					admincheck2 += list(admincheck_two)
		fdel(F)
		for(var/list/nc in admincheck2)
			text2file("[nc[1]];[nc[2]];[nc[3]]|||",F)
		return

	else
		var/foundnew = FALSE
		//clean the list. Start from the end and skip repeated entries.
		var/list/admincheck2 = list()
		var/list/ckeyschecked = list()
		for(var/i=admincheck.len, i>=1, i--)
			var/list/admincheck_two = splittext(admincheck[i], ";")
			if (admincheck_two.len && !(admincheck_two[1] in ckeyschecked))
				if (admincheck_two[1] == "[adm_ckey]")
					foundnew = TRUE
					ckeyschecked += list(admincheck_two[1])
					admincheck2 += list("[admincheck_two[1]];[new_rank];[num2text(admin_ranks[ckeyEx(new_rank)])]|||")
				else
					ckeyschecked += list(admincheck_two[1])
					admincheck2 += list(admincheck_two)
		fdel(F)
		for(var/list/nc in admincheck2)
			text2file("[nc[1]];[nc[2]];[nc[3]]|||",F)

		if (!foundnew)
			text2file("[adm_ckey];[new_rank];[num2text(admin_ranks[ckeyEx(new_rank)])]|||",F)
			message_admins("[key_name_admin(usr)] made '[adm_ckey]' an admin with the rank [new_rank].")
			log_admin("[key_name(usr)] made '[adm_ckey]' an admin with the rank [new_rank].")
			usr << "<span class = 'good'>New admin successfully added.</span>"
			return
		else
			message_admins("[key_name_admin(usr)] changed '[adm_ckey]''s admin rank to [new_rank].")
			log_admin("[key_name(usr)] changed '[adm_ckey]''s  admin rank to [new_rank].")
			usr << "<span class = 'good'>Admin rank successfully changed.</span>"
			return
// see admin/topic.dm
/datum/admins/proc/log_admin_permission_modification(var/adm_ckey, var/new_permission, var/nominal)

	if (!usr.client)
		return

	if (!usr.client.holder || !(usr.client.holder.rights & R_PERMISSIONS))
		usr << "<span class = 'red'>You do not have permission to do this!</span>"
		return

	if (!adm_ckey || !new_permission)
		return

	adm_ckey = ckey(adm_ckey)

	if (!adm_ckey)
		return

	if (istext(new_permission))
		new_permission = text2num(new_permission)

	if (!istext(adm_ckey) || !isnum(new_permission))
		return

	var/list/rowdata = list()
	var/F = "SQL/admins.txt"
	var/list/admincheck = splittext(file2text(F),"|||\n")
	if (islist(admincheck) && !isemptylist(admincheck))
		for(var/i in admincheck)
			var/list/admincheck_two = splittext(i, ";")
			if (admincheck_two.len && admincheck_two[1] == "[adm_ckey]")
				rowdata = admincheck_two

	var/admin_rights

	if (islist(rowdata) && !isemptylist(rowdata))
		if (rowdata.len >= 3)
			admin_rights = text2num(rowdata[3])

	if (admin_rights & new_permission) //This admin already has this permission, so we are removing it.
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i in admincheck)
				var/list/admincheck_two = splittext(i, ";")
				if (admincheck_two.len && admincheck_two[1] == "[adm_ckey]")
					admincheck -= i
					admincheck += list("[admincheck_two[1]];[admincheck_two[2]];[admin_rights & ~new_permission]|||")
		//clean the list. Start from the end and skip repeated entries.
		var/list/admincheck2 = list()
		var/list/ckeyschecked = list()
		for(var/i=admincheck.len, i>=1, i--)
			var/list/admincheck_two = splittext(admincheck[i], ";")
			if (admincheck_two.len && !(admincheck_two[1] in ckeyschecked))
				ckeyschecked += list(admincheck_two[1])
				admincheck2 += list(admincheck_two)
		fdel(F)
		for(var/list/nc in admincheck2)
			text2file("[nc[1]];[nc[2]];[nc[3]]|||",F)

		message_admins("[key_name_admin(usr)] removed the [nominal] permission of [key_name_admin(adm_ckey)].")
		log_admin("[key_name(usr)] removed the [nominal] permission of [key_name(adm_ckey)].")
		usr << "<span class = 'notice'>Permission removed.</span>"
	else //This admin doesn't have this permission, so we are adding it.
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i in admincheck)
				var/list/admincheck_two = splittext(i, ";")
				if (admincheck_two.len && admincheck_two[1] == "[adm_ckey]")
					admincheck -= i
					admincheck += list("[admincheck_two[1]];[admincheck_two[2]];[admin_rights | new_permission]|||")
		//clean the list. Start from the end and skip repeated entries.
		var/list/admincheck2 = list()
		var/list/ckeyschecked = list()
		for(var/i=admincheck.len, i>=1, i--)
			var/list/admincheck_two = splittext(admincheck[i], ";")
			if (admincheck_two.len && !(admincheck_two[1] in ckeyschecked))
				ckeyschecked += list(admincheck_two[1])
				admincheck2 += list(admincheck_two)
		fdel(F)
		for(var/list/nc in admincheck2)
			text2file("[nc[1]];[nc[2]];[nc[3]]|||",F)

		message_admins("[key_name_admin(usr)] added the [nominal] permission of [key_name_admin(adm_ckey)].")
		log_admin("[key_name(usr)] added the [nominal] permission of [key_name(adm_ckey)].")
		usr << "<span class = 'notice'>Permission added.</span>"
	return