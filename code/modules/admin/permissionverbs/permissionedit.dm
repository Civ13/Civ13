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

	var/F = file("SQL/admins.txt")
	var/list/admincheck = splittext(file2text("SQL/admins.txt"),"|||\n")

	if (new_rank == "Removed")
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i=1;i<admincheck.len;i++)
				var/list/admincheck_two = splittext(admincheck[i], ";")
				if (admincheck_two[2] == "[adm_ckey]")
					admincheck_two[3] = "NONE"
			fdel(F)
			spawn(1)
				for(var/i=1;i<admincheck.len;i++)
					var/list/admincheck_two = splittext(admincheck[i], ";")
					if (admincheck_two[3] != "NONE")
						text2file("[admincheck[i]]|||","SQL/admins.txt")
				spawn(1)
					var/full_banlist_new = file2text("SQL/admins.txt")
					text2file(full_banlist_new,"SQL/admins.txt")
		return

	var/list/rowdata = list()
	for(var/i=1;i<admincheck.len;i++)
		var/list/admincheck_two = splittext(admincheck[i], ";")
		if (admincheck_two[1] == "[adm_ckey]")
			rowdata += list(admincheck_two[1])
	var/new_admin = TRUE
	var/admin_id = 0

	if (islist(rowdata) && !isemptylist(rowdata))
		new_admin = FALSE
		admin_id = text2num(rowdata["id"])

	if (new_admin)
		text2file("[num2text(rand(1, 1000*1000*1000), 20)];[adm_ckey];[new_rank];[num2text(admin_ranks[ckeyEx(new_rank)])]|||","SQL/admins.txt")
		message_admins("[key_name_admin(usr)] made '[adm_ckey]' an admin with the rank [new_rank].")
		log_admin("[key_name(usr)] made '[adm_ckey]' an admin with the rank [new_rank].")
		usr << "<span class = 'good'>New admin successfully added.</span>"
	else
		if (admin_id == 0 || !isnum(admin_id))
			admin_id = num2text(rand(1, 1000*1000*1000), 20)
		else
			admin_id = num2text(admin_id)
		for(var/i=1;i<admincheck.len;i++)
			var/list/admincheck_two = splittext(admincheck[i], ";")
			if (admincheck_two[1] == "[admin_id]")
				admincheck_two[3] = "[new_rank]"
				admincheck_two[3] = "[num2text(admin_ranks[ckeyEx(new_rank)])]"
				text2file("[admincheck[i]]|||","SQL/admins.txt")


		message_admins("[key_name_admin(usr)] changed '[adm_ckey]''s admin rank to [new_rank].")
		log_admin("[key_name(usr)] changed '[adm_ckey]''s  admin rank to [new_rank].")
		usr << "<span class = 'good'>Admin rank successfully changed.</span>"

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
	var/F = file("SQL/admins.txt")
	var/list/admincheck = splittext(file2text("SQL/admins.txt"),"|||\n")
	if (islist(admincheck) && !isemptylist(admincheck))
		for(var/i=1;i<admincheck.len;i++)
			var/list/admincheck_two = splittext(admincheck[i], ";")
			if (admincheck_two[2] == "[adm_ckey]")
				rowdata = list(admincheck_two)

	var/admin_id
	var/admin_rights

	if (islist(rowdata) && !isemptylist(rowdata))
		admin_id = text2num(rowdata[1])
		if (rowdata.len >= 4)
			admin_rights = text2num(rowdata[4])

	if (!admin_id)
		return

	if (admin_rights & new_permission) //This admin already has this permission, so we are removing it.
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i=1;i<admincheck.len;i++)
				var/list/admincheck_two = splittext(admincheck[i], ";")
				if (admincheck_two[2] == "[adm_ckey]")
					admincheck_two[4] = "[admin_rights & ~new_permission]"
		message_admins("[key_name_admin(usr)] removed the [nominal] permission of [key_name_admin(adm_ckey)]")
		log_admin("[key_name(usr)] removed the [nominal] permission of [key_name(adm_ckey)]")
		usr << "<span class = 'notice'>Permission removed.</span>"
	else //This admin doesn't have this permission, so we are adding it.
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i=1;i<admincheck.len;i++)
				var/list/admincheck_two = splittext(admincheck[i], ";")
				if (admincheck_two[2] == "[adm_ckey]")
					admincheck_two[4] = "[admin_rights | new_permission]"
			spawn(1)
				fdel(F)
				spawn(1)
					for(var/i=1;i<admincheck.len;i++)
						var/list/admincheck_three = splittext(admincheck[i], ";")
						if (admincheck_three[3] != "NONE")
							text2file("[admincheck[i]]|||","SQL/admins.txt")
					spawn(1)
						var/full_banlist_new = file2text("SQL/admins.txt")
						text2file(full_banlist_new,"SQL/admins.txt")
		message_admins("[key_name_admin(usr)] added the [nominal] permission of [key_name_admin(adm_ckey)]")
		log_admin("[key_name(usr)] added the [nominal] permission of [key_name(adm_ckey)]")
		usr << "<span class = 'notice'>Permission added.</span>"
	spawn(1)
		fdel(F)
		spawn(1)
			for(var/i=1;i<admincheck.len;i++)
				var/list/admincheck_three = splittext(admincheck[i], ";")
				if (admincheck_three[3] != "NONE")
					text2file("[admincheck[i]]|||","SQL/admins.txt")
			spawn(1)
				var/full_banlist_new = file2text("SQL/admins.txt")
				text2file(full_banlist_new,"SQL/admins.txt")