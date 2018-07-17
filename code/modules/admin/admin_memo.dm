#define ENABLE_MEMOS 1				//using a define because screw making a config variable for it. This is more efficient and purty.
/proc/get_admin_memo_file_dir()
	if (serverswap && serverswap.Find("master_data_dir"))
		return "[serverswap["master_data_dir"]]memo.sav"
	return "data/memo.sav"
//switch verb so we don't spam up the verb lists with like, 3 verbs for this feature.
/client/proc/admin_memo(task in list("write","show","delete"))
	set name = "Admin Memo"
	set category = "Server"
	if (!ENABLE_MEMOS)		return
	if (!check_rights(0))	return
	switch(task)
		if ("write")		admin_memo_write()
		if ("show")		admin_memo_show()
		if ("delete")	admin_memo_delete()

//write a message
/client/proc/admin_memo_write()
	var/savefile/F = new(get_admin_memo_file_dir())
	if (F)
		var/memo = russian_to_cp1251(input(src,"Type your memo\n(Leaving it blank will delete your current memo):","Write Memo",null) as null|message)
		switch(memo)
			if (null)
				return
			if ("")
				F.dir.Remove(ckey)
				src << "<b>Memo removed</b>"
				return
		if ( findtext(memo,"<script",1,0) )
			return
		F[ckey] << "Admin Memo from <b>[capitalize(key)]</b> on [time2text(world.realtime,"(DDD) DD MMM hh:mm")]<br><i>[memo]</i>"
		message_admins("[key] has set an admin memo:<br>[memo]")

//show all memos
/client/proc/admin_memo_show()
	if (ENABLE_MEMOS)
		var/savefile/F = new(get_admin_memo_file_dir())
		if (F)
			for (var/ckey in F.dir)
				src << "<center><span class='motd'>[F[ckey]]</span></center>"

//delete your own or somebody else's memo
/client/proc/admin_memo_delete()
	var/savefile/F = new(get_admin_memo_file_dir())
	if (F)
		var/_ckey
		if (check_rights(R_SERVER,0))	//high ranking admins can delete other admin's memos
			_ckey = WWinput(src, "Whose memo shall we remove?", "Remove Memo", WWinput_first_choice(F.dir), WWinput_list_or_null(F.dir))
		else
			_ckey = ckey
		if (_ckey)
			F.dir.Remove(_ckey)
			src << "<b>Removed Memo created by [_ckey].</b>"

#undef MEMOFILE
#undef ENABLE_MEMOS