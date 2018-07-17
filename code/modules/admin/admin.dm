
var/global/BSACooldown = FALSE
var/global/floorIsLava = FALSE


////////////////////////////////
/proc/message_admins(var/msg)
	msg = "<span class=\"log_message\"><span class=\"prefix\">ADMIN LOG:</span> <span class=\"message\">[msg]</span></span>"
	log_adminwarn(msg)
	for (var/client/C in admins)
		C << msg

/proc/msg_admin_attack(var/text) //Toggleable Attack Messages
	log_attack(text)
	var/rendered = "<span class=\"log_message\"><span class=\"prefix\">ATTACK:</span> <span class=\"message\">[text]</span></span>"
	for (var/client/C in admins)
		if (R_ADMIN & C.holder.rights)
			if (C.is_preference_enabled(/datum/client_preference/admin/show_attack_logs))
				var/msg = rendered
				C << msg

proc/admin_notice(var/message, var/rights)
	for (var/mob/M in mob_list)
		if (check_rights(rights, FALSE, M))
			M << message

///////////////////////////////////////////////////////////////////////////////////////////////Panels

/datum/admins/proc/show_player_panel(var/mob/M in mob_list)
	set category = null
	set name = "Show Player Panel"
	set desc="Edit player (respawn, ban, heal, etc)"

	if (!M)
		usr << "You seem to be selecting a mob that doesn't exist anymore."
		return

	if (!istype(src,/datum/admins))
		src = usr.client.holder
	if (!istype(src,/datum/admins))
		usr << "Error: you are not an admin!"
		return

	var/body = "<html><head><title>Options for [M.key]</title></head>"
	body += "<body>Options panel for <b>[M]</b>"
	if (M.client)
		body += " played by <b>[M.client]</b> "
		body += "\[<A href='?src=\ref[src];editrights=show'>[M.client.holder ? M.client.holder.rank : "Player"]</A>\]"

	if (istype(M, /mob/new_player))
		body += " <b>Hasn't Entered Game</b> "
	else
		body += " \[<A href='?src=\ref[src];revive=\ref[M]'>Heal</A>\] "

	body += {"
		<br><br>\[
		<a href='?_src_=vars;Vars=\ref[M]'>VV</a> -
		<a href='?src=\ref[src];traitor=\ref[M]'>TP</a> -
		<a href='?src=\ref[usr];priv_msg=\ref[M]'>PM</a> -
		<a href='?src=\ref[src];subtlemessage=\ref[M]'>SM</a> -
		[admin_jump_link(M, src)]\] <br>
		<b>Mob type</b> = [M.type]<br><br>
		<A href='?src=\ref[src];boot2=\ref[M]'>Kick</A> |
		<A href='?_src_=holder;warn=[M.ckey]'>Warn</A> |
		<A href='?src=\ref[src];notes=show;mob=\ref[M]'>Notes</A>
	"}

// <A href='?src=\ref[src];newban=\ref[M]'>Ban</A> |
// <A href='?src=\ref[src];jobban2=\ref[M]'>Jobban</A> |

	if (M.client)
	//	body += "| <A HREF='?src=\ref[src];sendtoprison=\ref[M]'>Prison</A> | "
		var/muted = M.client.prefs.muted
		body += {"<br><b>Mute: </b>
			\[<A href='?src=\ref[src];mute=\ref[M];mute_type=[MUTE_IC]'><font color='[(muted & MUTE_IC)?"red":"blue"]'>IC</font></a> |
			<A href='?src=\ref[src];mute=\ref[M];mute_type=[MUTE_OOC]'><font color='[(muted & MUTE_OOC)?"red":"blue"]'>OOC</font></a> |
			<A href='?src=\ref[src];mute=\ref[M];mute_type=[MUTE_PRAY]'><font color='[(muted & MUTE_PRAY)?"red":"blue"]'>PRAY</font></a> |
			<A href='?src=\ref[src];mute=\ref[M];mute_type=[MUTE_ADMINHELP]'><font color='[(muted & MUTE_ADMINHELP)?"red":"blue"]'>ADMINHELP</font></a> |
			<A href='?src=\ref[src];mute=\ref[M];mute_type=[MUTE_DEADCHAT]'><font color='[(muted & MUTE_DEADCHAT)?"red":"blue"]'>DEADCHAT</font></a>\]
			(<A href='?src=\ref[src];mute=\ref[M];mute_type=[MUTE_ALL]'><font color='[(muted & MUTE_ALL)?"red":"blue"]'>toggle all</font></a>)
		"}

	body += {"<br><br>
		<A href='?src=\ref[src];jumpto=\ref[M]'><b>Jump to</b></A> |
		<A href='?src=\ref[src];getmob=\ref[M]'>Get</A> |
		<A href='?src=\ref[src];sendmob=\ref[M]'>Send To</A>
		<br><br>
		[check_rights(R_ADMIN|R_MOD,0) ? "<A href='?src=\ref[src];traitor=\ref[M]'>Traitor panel</A> | " : "" ]
		<A href='?src=\ref[src];narrateto=\ref[M]'>Narrate to</A> |
		<A href='?src=\ref[src];subtlemessage=\ref[M]'>Subtle message</A>
	"}

	if (M.client)
		if (!istype(M, /mob/new_player))
			body += "<br><br>"
			body += "<b>Transformation:</b>"
			body += "<br>"

			//Monkey
			if (issmall(M))
				body += "<b>Monkeyized</b> | "
			else
				body += "<A href='?src=\ref[src];monkeyone=\ref[M]'>Monkeyize</A> | "

			//Corgi
			if (iscorgi(M))
				body += "<b>Corgized</b> | "
			else
				body += "<A href='?src=\ref[src];corgione=\ref[M]'>Corgize</A> | "

			//AI / Cyborg
	/*		if (isAI(M))
				body += "<b>Is an AI</b> "
			else if (ishuman(M))
				body += {"<A href='?src=\ref[src];makeai=\ref[M]'>Make AI</A> |
					<A href='?src=\ref[src];makerobot=\ref[M]'>Make Robot</A> |
					<A href='?src=\ref[src];makealien=\ref[M]'>Make Alien</A> |
					<A href='?src=\ref[src];makeslime=\ref[M]'>Make slime</A>
				"}*/

			//Simple Animals
			if (isanimal(M))
				body += "<A href='?src=\ref[src];makeanimal=\ref[M]'>Re-Animalize</A> | "
			else
				body += "<A href='?src=\ref[src];makeanimal=\ref[M]'>Animalize</A> | "
/*
			// DNA2 - Admin Hax
			if (M.dna && iscarbon(M))
				body += "<br><br>"
				body += "<b>DNA Blocks:</b><br><table border='0'><tr><th>&nbsp;</th><th>1</th><th>2</th><th>3</th><th>4</th><th>5</th>"
				var/bname
				for (var/block=1;block<=DNA_SE_LENGTH;block++)
					if (((block-1)%5)==0)
						body += "</tr><tr><th>[block-1]</th>"
					bname = assigned_blocks[block]
					body += "<td>"
					if (bname)
						var/bstate=M.dna.GetSEState(block)
						var/bcolor="[(bstate)?"#006600":"#ff0000"]"
						body += "<A href='?src=\ref[src];togmutate=\ref[M];block=[block]' style='color:[bcolor];'>[bname]</A><sub>[block]</sub>"
					else
						body += "[block]"
					body+="</td>"
				body += "</tr></table>"
*/
			body += {"<br><br>
				<b>Rudimentary transformation:</b><font size=2><br>These transformations only create a new mob type and copy stuff over. They do not take into account MMIs and similar mob-specific things. The buttons in 'Transformations' are preferred, when possible.</font><br>
				<A href='?src=\ref[src];simplemake=observer;mob=\ref[M]'>Observer</A> |
				\[ Default: <A href='?src=\ref[src];simplemake=human;mob=\ref[M]'>Human</A>

				\[ Admin Memery: <A href='?src=\ref[src];simplemake=mechahitler;mob=\ref[M]'>Mecha Hitler</A>,
				<A href='?src=\ref[src];simplemake=megastalin;mob=\ref[M]'>Mega Stalin</A>"}

/*
	\[ Xenos: <A href='?src=\ref[src];simplemake=larva;mob=\ref[M]'>Larva</A>
	<A href='?src=\ref[src];simplemake=human;species=Xenomorph Drone;mob=\ref[M]'>Drone</A>
	<A href='?src=\ref[src];simplemake=human;species=Xenomorph Hunter;mob=\ref[M]'>Hunter</A>
	<A href='?src=\ref[src];simplemake=human;species=Xenomorph Sentinel;mob=\ref[M]'>Sentinel</A>
	<A href='?src=\ref[src];simplemake=human;species=Xenomorph Queen;mob=\ref[M]'>Queen</A> \] |
				*/
//	<A href='?src=\ref[src];simplemake=nazicyborg;mob=\ref[M]'>Nazi Cyborg</A>
			if (check_rights(R_PERMISSIONS,FALSE))
				body += {"
				<A href='?src=\ref[src];simplemake=pillarman;mob=\ref[M]'>Pillar Man</A>"}

			body += {"
				<A href='?src=\ref[src];simplemake=vampire;mob=\ref[M]'>Vampire</A> \]
				<A href='?src=\ref[src];simplemake=nymph;mob=\ref[M]'>Nymph</A>
				<A href='?src=\ref[src];simplemake=monkey;mob=\ref[M]'>Monkey</A> |
				<A href='?src=\ref[src];simplemake=cat;mob=\ref[M]'>Cat</A> |
				<A href='?src=\ref[src];simplemake=runtime;mob=\ref[M]'>Runtime</A> |
				<A href='?src=\ref[src];simplemake=corgi;mob=\ref[M]'>Corgi</A> |
				<A href='?src=\ref[src];simplemake=ian;mob=\ref[M]'>Ian</A> |
				<A href='?src=\ref[src];simplemake=crab;mob=\ref[M]'>Crab</A> |
				<A href='?src=\ref[src];simplemake=coffee;mob=\ref[M]'>Coffee</A>
				<br>"}

				/*
				<A href='?src=\ref[src];simplemake=robot;mob=\ref[M]'>Cyborg</A> |*/
				/*
								\[ Construct: <A href='?src=\ref[src];simplemake=constructarmoured;mob=\ref[M]'>Armoured</A> ,
				<A href='?src=\ref[src];simplemake=constructbuilder;mob=\ref[M]'>Builder</A> ,
				<A href='?src=\ref[src];simplemake=constructwraith;mob=\ref[M]'>Wraith</A> \]
				<A href='?src=\ref[src];simplemake=shade;mob=\ref[M]'>Shade</A>*/
				/*
								\[ slime: <A href='?src=\ref[src];simplemake=slime;mob=\ref[M]'>Baby</A>,
				<A href='?src=\ref[src];simplemake=adultslime;mob=\ref[M]'>Adult</A> \]*/

	body += {"<br><br>
			<b>Other actions:</b>
			<br>
			<A href='?src=\ref[src];forcespeech=\ref[M]'>Forcesay</A>
			"}
	/*if (M.client)
		body += {" |
			<A href='?src=\ref[src];tdome1=\ref[M]'>Thunderdome 1</A> |
			<A href='?src=\ref[src];tdome2=\ref[M]'>Thunderdome 2</A> |
			<A href='?src=\ref[src];tdomeadmin=\ref[M]'>Thunderdome Admin</A> |
			<A href='?src=\ref[src];tdomeobserve=\ref[M]'>Thunderdome Observer</A> |
		"}*/
	// language toggles
	body += "<br><br><b>Languages:</b><br>"
	var/f = TRUE
	for (var/k in all_languages)
		var/datum/language/L = all_languages[k]
		if (!(L.flags & INNATE))
			if (!f) body += " | "
			else f = FALSE
			if (L in M.languages)
				body += "<a href='?src=\ref[src];toglang=\ref[M];lang=[rhtml_encode(k)]' style='color:#006600'>[k]</a>"
			else
				body += "<a href='?src=\ref[src];toglang=\ref[M];lang=[rhtml_encode(k)]' style='color:#ff0000'>[k]</a>"

	body += {"<br>
		</body></html>
	"}

	usr << browse(body, "window=adminplayeropts;size=550x515")



/datum/player_info/var/author // admin who authored the information
/datum/player_info/var/rank //rank of admin who made the notes
/datum/player_info/var/content // text content of the information
/datum/player_info/var/timestamp // Because this is bloody annoying

#define PLAYER_NOTES_ENTRIES_PER_PAGE 50
/datum/admins/proc/PlayerNotes()
	set category = "Admin"
	set name = "Player Notes"
	if (!istype(src,/datum/admins))
		src = usr.client.holder
	if (!istype(src,/datum/admins))
		usr << "Error: you are not an admin!"
		return
	PlayerNotesPage(1)

/datum/admins/proc/PlayerNotesPage(page)
	var/dat = "<b>Player notes</b><HR>"
	var/savefile/S=new("[(serverswap && serverswap.Find("master_data_dir")) ? serverswap["master_data_dir"] : "data/"]player_notes.sav")
	var/list/note_keys
	S >> note_keys
	if (!note_keys)
		dat += "No notes found."
	else
		dat += "<table>"
		note_keys = sortList(note_keys)

		// Display the notes on the current page
		var/number_pages = note_keys.len / PLAYER_NOTES_ENTRIES_PER_PAGE
		// Emulate ceil(why does BYOND not have ceil)
		if (number_pages != round(number_pages))
			number_pages = round(number_pages) + 1
		var/page_index = page - 1
		if (page_index < 0 || page_index >= number_pages)
			return

		var/lower_bound = page_index * PLAYER_NOTES_ENTRIES_PER_PAGE + 1
		var/upper_bound = (page_index + 1) * PLAYER_NOTES_ENTRIES_PER_PAGE
		upper_bound = min(upper_bound, note_keys.len)
		for (var/index = lower_bound, index <= upper_bound, index++)
			var/t = note_keys[index]
			dat += "<tr><td><a href='?src=\ref[src];notes=show;ckey=[t]'>[t]</a></td></tr>"

		dat += "</table><br>"

		// Display a footer to select different pages
		for (var/index = TRUE, index <= number_pages, index++)
			if (index == page)
				dat += "<b>"
			dat += "<a href='?src=\ref[src];notes=list;index=[index]'>[index]</a> "
			if (index == page)
				dat += "</b>"

	usr << browse(dat, "window=player_notes;size=400x400")

/proc/get_player_notes_file_dir()
	if (serverswap && serverswap.Find("master_data_dir"))
		return "[serverswap["master_data_dir"]]player_saves/"
	return "data/player_saves/"

/datum/admins/proc/player_has_info(var/key as text)
	var/savefile/info = new("[get_player_notes_file_dir()][copytext(key, TRUE, 2)]/[key]/info.sav")
	var/list/infos
	info >> infos
	if (!infos || !infos.len) return FALSE
	else return TRUE

/datum/admins/proc/show_player_info(var/key as text)
	set category = "Admin"
	set name = "Show Player Info"
	if (!istype(src,/datum/admins))
		src = usr.client.holder
	if (!istype(src,/datum/admins))
		usr << "Error: you are not an admin!"
		return
	var/dat = "<html><head><title>Info on [key]</title></head>"
	dat += "<body>"

	var/p_age = "unknown"
	for (var/client/C in clients)
		if (C.ckey == key)
			p_age = C.player_age
			break
	dat +="<span style='color:#000000; font-weight: bold'>Player age: [p_age]</span><br>"

	var/savefile/info = new("[get_player_notes_file_dir()][copytext(key, TRUE, 2)]/[key]/info.sav")
	var/list/infos
	info >> infos
	if (!infos)
		dat += "No information found on the given key.<br>"
	else
		var/update_file = FALSE
		var/i = FALSE
		for (var/datum/player_info/I in infos)
			i += 1
			if (!I.timestamp)
				I.timestamp = "Pre-4/3/2012"
				update_file = TRUE
			if (!I.rank)
				I.rank = "N/A"
				update_file = TRUE
			dat += "<font color=#008800>[I.content]</font> <i>by [I.author] ([I.rank])</i> on <i><font color=blue>[I.timestamp]</i></font> "
			if (I.author == usr.key || I.author == "Adminbot" || ishost(usr))
				dat += "<A href='?src=\ref[src];remove_player_info=[key];remove_index=[i]'>Remove</A>"
			dat += "<br><br>"
		if (update_file) info << infos

	dat += "<br>"
	dat += "<A href='?src=\ref[src];add_player_info=[key]'>Add Comment</A><br>"

	dat += "</body></html>"
	usr << browse(dat, "window=adminplayerinfo;size=480x480")
/*
/datum/admins/proc/Jobbans()
	if (!check_rights(R_BAN))	return

	var/dat = "<b>Job Bans!</b><HR><table>"
	for (var/t in jobban_keylist)
		var/r = t
		if ( findtext(r,"##") )
			r = copytext( r, TRUE, findtext(r,"##") )//removes the description
		dat += text("<tr><td>[t] (<A href='?src=\ref[src];removejobban=[r]'>unban</A>)</td></tr>")
	dat += "</table>"
	usr << browse(dat, "window=ban;size=400x400")*/

/datum/admins/proc/game_panel()
	if (!check_rights(R_ADMIN))	return

	var/dat = {"
		<style>
		[common_browser_style]
		</style>
		<br>
		<center><b><big>Game Panel</big></b></center><hr>\n
		"}
		//		<A href='?src=\ref[src];c_mode=1'>Change Game Mode</A><br>
/*	if (master_mode == "secret")
		dat += "<A href='?src=\ref[src];f_secret=1'>(Force Secret Mode)</A><br>"*/

	dat += {"
		<br>
		<A href='?src=\ref[src];create_object=1'>Create Object</A> (<A href='?src=\ref[src];quick_create_object=1'>Quick</A>)<br><br>
		<A href='?src=\ref[src];create_turf=1'>Create Turf</A><br><br>
		<A href='?src=\ref[src];create_mob=1'>Create Mob</A><br><br>
		<br><br>
		<A href='?src=\ref[src];debug_global=1'>View/Debug a Global Variable, List, or Object</A><br><br>
		<br><br>
		<A href='?src=\ref[src];modify_global=1'>Modify a Global Variable (may not be an object or list)</A><br><br>
		<br><br>
		<A href='?src=\ref[src];modify_world_var=1'>Modify a World Variable (may not be an object or list)</A><br><br>
		"}

	dat = "<center><big>[dat]</big></center>"

	usr << browse(dat, "window=admin2;size=400x500")
	return

/datum/admins/proc/Secrets()
	if (!check_rights(0))	return

	var/dat = "<b>The first rule of adminbuse is: you don't talk about the adminbuse.</b><HR>"
	for (var/datum/admin_secret_category/category in admin_secrets.categories)
		if (!category.can_view(usr))
			continue
		dat += "<b>[category.name]</b><br>"
		if (category.desc)
			dat += "<I>[category.desc]</I><BR>"
		for (var/datum/admin_secret_item/item in category.items)
			if (!item.can_view(usr))
				continue
			dat += "<A href='?src=\ref[src];admin_secrets=\ref[item]'>[item.name()]</A><BR>"
		dat += "<BR>"
	usr << browse(dat, "window=secrets")
	return



/////////////////////////////////////////////////////////////////////////////////////////////////admins2.dm merge
//i.e. buttons/verbs


/datum/admins/proc/restart()
	set category = "Server"
	set name = "Restart"
	set desc="Restarts the world"
	if (!usr.client.holder)
		return
	var/confirm = WWinput(usr, "Restart the game world?", "Restart", "Yes", list("Yes", "Cancel"))
	if (confirm == "Cancel")
		return
	if (processes.mapswap && ticker.restarting_is_very_bad && serverswap.Find("snext"))
		var/unconfirm = WWinput(usr, "Mapswap is in progress. Restarting now may break the linked server. Continue?", "Warning", "No", list("No", "Yes"))
		if (unconfirm == "No")
			return
	if (confirm == "Yes")
		world << "<span class='danger'>Restarting world!</span> <span class='notice'>Initiated by <b>[usr.client.holder.fakekey ? "Admin" : usr.key]</b>!</span>"
		log_admin("[key_name(usr)] initiated a reboot.")
		sleep(50)
		world.Reboot()

/datum/admins/proc/jojorestart()
	set category = "Server"
	set name = "Jojo Restart"
	set desc="Restarts the world with to be continued memes"
	if (!usr.client.holder)
		return
	var/confirm = WWinput(usr, "Restart the game world?", "Restart", "Yes", list("Yes", "Cancel"))
	if (confirm == "Cancel")
		return
	if (processes.mapswap && ticker.restarting_is_very_bad && serverswap.Find("snext"))
		var/unconfirm = WWinput(usr, "Mapswap is in progress. Restarting now may break the linked server. Continue?", "Warning", "No", list("No", "Yes"))
		if (unconfirm == "No")
			return
	if (confirm == "Yes")
		config.jojoreference = TRUE
		world << "<span class='danger'>Restarting world!</span> <span class='notice'>Initiated by <b>[usr.client.holder.fakekey ? "Admin" : usr.key]</b>!</span>"
		log_admin("[key_name(usr)] initiated a reboot.")
		sleep(50)
		world.Reboot()


/datum/admins/proc/announce()
	set category = "Special"
	set name = "Announce"
	set desc="Announce your desires to the world"
	if (!check_rights(0))	return

	var/message = russian_to_cp1251(input("Global message to send:", "Admin Announce", null, null))  as message
	if (message)
		if (!check_rights(R_SERVER,0))
			message = sanitize(message, 500, extra = FALSE)
		message = replacetext(message, "\n", "<br>") // required since we're putting it in a <p> tag
		world << "<big><span class=notice><b>[usr.client.holder.fakekey ? "Administrator" : usr.key] Announces:</b></big><p style='text-indent: 50px'>[message]</p></span>"
		log_admin("Announce: [key_name(usr)] : [message]")


/datum/admins/proc/toggleooc()
	set category = "Server"
	set desc="Globally Toggles OOC"
	set name="Toggle OOC"

	if (!check_rights(R_ADMIN))
		return

	config.ooc_allowed = !(config.ooc_allowed)
	if (config.ooc_allowed)
		world << "<b>The OOC channel has been globally enabled!</b>"
	else
		world << "<b>The OOC channel has been globally disabled!</b>"
	log_and_message_admins("toggled OOC.")


/datum/admins/proc/togglelooc()
	set category = "Server"
	set desc="Globally Toggles LOOC"
	set name="Toggle LOOC"

	if (!check_rights(R_ADMIN))
		return

	config.looc_allowed = !(config.looc_allowed)
	if (config.looc_allowed)
		world << "<b>The LOOC channel has been globally enabled!</b>"
	else
		world << "<b>The LOOC channel has been globally disabled!</b>"
	log_and_message_admins("toggled LOOC.")



/datum/admins/proc/toggledsay()
	set category = "Server"
	set desc="Globally Toggles DSAY"
	set name="Toggle DSAY"

	if (!check_rights(R_ADMIN))
		return

	config.dsay_allowed = !(config.dsay_allowed)
	if (config.dsay_allowed)
		world << "<b>Deadchat has been globally enabled!</b>"
	else
		world << "<b>Deadchat has been globally disabled!</b>"
	log_admin("[key_name(usr)] toggled deadchat.")
	message_admins("[key_name_admin(usr)] toggled deadchat.", TRUE)


/datum/admins/proc/toggleoocdead()
	set category = "Server"
	set desc="Toggle Dead OOC."
	set name="Toggle Dead OOC"

	if (!check_rights(R_ADMIN))
		return

	config.dooc_allowed = !( config.dooc_allowed )
	log_admin("[key_name(usr)] toggled Dead OOC.")
	message_admins("[key_name_admin(usr)] toggled Dead OOC.", TRUE)



/datum/admins/proc/toggletraitorscaling()
	set category = "Server"
	set desc="Toggle traitor scaling"
	set name="Toggle Traitor Scaling"
	config.traitor_scaling = !config.traitor_scaling
	log_admin("[key_name(usr)] toggled Traitor Scaling to [config.traitor_scaling].")
	message_admins("[key_name_admin(usr)] toggled Traitor Scaling [config.traitor_scaling ? "on" : "off"].", TRUE)


/datum/admins/proc/startnow()
	set category = "Server"
	set desc="Start the round immediately"
	set name="Start Now"
	if (!ticker)
		WWalert(usr, "Unable to start the game as it is not set up.", "Error")
		return
	if (ticker.current_state == GAME_STATE_PREGAME)
		if (!round_progressing)
			round_progressing = TRUE
		ticker.pregame_timeleft = 1
		ticker.admin_started = TRUE
		log_admin("[usr.key] has started the game.")
		message_admins("[usr.key] has started the game.")
		return TRUE
	else
		usr << "<font color='red'>Error: Start Now: Game has already started</font>"
		return FALSE

/datum/admins/proc/toggleenter()
	set category = "Server"
	set desc="People can't enter"
	set name="Toggle Entering"
	config.enter_allowed = !(config.enter_allowed)
	if (!(config.enter_allowed))
		world << "<b>New players may no longer enter the game.</b>"
	else
		world << "<b>New players may now enter the game.</b>"
	log_admin("[key_name(usr)] toggled new player game entering.")
	message_admins("<span class = 'notice'>[key_name_admin(usr)] toggled new player game entering.</span>", TRUE)
	world.update_status()


/datum/admins/proc/toggleAI()
	set category = "Server"
	set desc="People can't be AI"
	set name="Toggle AI"
	config.allow_ai = !( config.allow_ai )
	if (!( config.allow_ai ))
		world << "<b>The AI job is no longer chooseable.</b>"
	else
		world << "<b>The AI job is chooseable now.</b>"
	log_admin("[key_name(usr)] toggled AI allowed.")
	world.update_status()


/datum/admins/proc/toggleaban()
	set category = "Server"
	set desc="Respawn basically"
	set name="Toggle Respawn"
	config.abandon_allowed = !(config.abandon_allowed)
	if (config.abandon_allowed)
		world << "<b>You may now respawn.</b>"
	else
		world << "<b>You may no longer respawn :(</b>"
	message_admins("<span class = 'notice'>[key_name_admin(usr)] toggled respawn to [config.abandon_allowed ? "On" : "Off"].</span>", TRUE)
	log_admin("[key_name(usr)] toggled respawn to [config.abandon_allowed ? "On" : "Off"].")
	world.update_status()

/*
/datum/admins/proc/toggle_aliens()
	set category = "Server"
	set desc="Toggle alien mobs"
	set name="Toggle Aliens"
	config.aliens_allowed = !config.aliens_allowed
	log_admin("[key_name(usr)] toggled Aliens to [config.aliens_allowed].")
	message_admins("[key_name_admin(usr)] toggled Aliens [config.aliens_allowed ? "on" : "off"].", TRUE)

*/
/datum/admins/proc/delay()
	set category = "Server"
	set desc="Delay the game start/end"
	set name="Delay"

	if (!check_rights(R_SERVER))	return
	if (!ticker || ticker.current_state != GAME_STATE_PREGAME)
		ticker.delay_end = !ticker.delay_end
		log_admin("[key_name(usr)] [ticker.delay_end ? "delayed the round end" : "has made the round end normally"].")
		message_admins("<span class = 'notice'>[key_name(usr)] [ticker.delay_end ? "delayed the round end" : "has made the round end normally"].</span>", TRUE)
		return
	round_progressing = !round_progressing
	if (!round_progressing)
		if ((input(usr, "Delay the round indefinitely or temporarily?") in list("Indefinitely", "Temporarily")) == "Temporarily")
			ticker.pregame_timeleft += round(GAMETICKER_PREGAME_TIME/2)
			ticker.pregame_timeleft = min(ticker.pregame_timeleft, GAMETICKER_PREGAME_TIME)
			round_progressing = TRUE
			world << "<b>The game start has been delayed by 90 seconds.</b>"
			log_admin("[key_name(usr)] delayed the game by 90 seconds.")
		else
			world << "<b>The game start has been delayed.</b>"
			log_admin("[key_name(usr)] delayed the game.")
	else
		world << "<b>The game will start soon.</b>"
		log_admin("[key_name(usr)] removed the roundstart delay.")

/datum/admins/proc/adjump()
	set category = "Server"
	set desc="Toggle admin jumping"
	set name="Toggle Jump"
	config.allow_admin_jump = !(config.allow_admin_jump)
	message_admins("<span class = 'notice'>[key_name(usr)] toggled admin jumping to [config.allow_admin_jump].</span>")


/datum/admins/proc/adspawn()
	set category = "Server"
	set desc="Toggle admin spawning"
	set name="Toggle Spawn"
	config.allow_admin_spawning = !(config.allow_admin_spawning)
	message_admins("<span class = 'notice'>[key_name(usr)] toggled admin item spawning to [config.allow_admin_spawning].</span>")


/datum/admins/proc/adrev()
	set category = "Server"
	set desc="Toggle admin revives"
	set name="Toggle Revive"
	config.allow_admin_rev = !(config.allow_admin_rev)
	message_admins("<span class = 'notice'>Toggled reviving to [config.allow_admin_rev].</span>")


/datum/admins/proc/immreboot()
	set category = "Server"
	set desc="Reboots the server post haste"
	set name="Immediate Reboot"
	if (!usr.client.holder)	return
	if (WWinput(usr, "Reboot the server?", "Reboot", "Yes", list("Yes","No")) == "No")
		return
	world << "<span class = 'red'><b>Rebooting world!</b> <span class = 'notice'>Initiated by [usr.client.holder.fakekey ? "Admin" : usr.key]!</span></span>"
	log_admin("[key_name(usr)] initiated an immediate reboot.")
	world.Reboot()

/datum/admins/proc/unprison(var/mob/M in mob_list)
	set category = "Admin"
	set name = "Unprison"
	if (M.z == 6)
		if (config.allow_admin_jump)
			M.loc = pick(latejoin)
			message_admins("[key_name_admin(usr)] has unprisoned [key_name_admin(M)]", TRUE)
			log_admin("[key_name(usr)] has unprisoned [key_name(M)]")
		else
			WWalert(usr, "Admin jumping is disabled.", "Denied")
	else
		WWalert(usr, "[M.name] is not prisoned.", "Unprison")


////////////////////////////////////////////////////////////////////////////////////////////////ADMIN HELPER PROCS

/proc/is_special_character(mob/M as mob) // returns TRUE for specail characters and 2 for heroes of gamemode
/*	if (!ticker || !ticker.mode)
		return FALSE*/
	if (!istype(M))
		return FALSE

	if (M.mind)
/*		if (ticker.mode.antag_templates && ticker.mode.antag_templates.len)
			for (var/datum/antagonist/antag in ticker.mode.antag_templates)
				if (antag.is_antagonist(M.mind))
					return 2
		else */
		if (M.mind.special_role)
			return TRUE

	return FALSE

	/*
/datum/admins/proc/spawn_custom_item()
	set category = "Debug"
	set desc = "Spawn a custom item."
	set name = "Spawn Custom Item"

	if (!check_rights(R_SPAWN))	return

	var/owner = WWinput(usr, "Select a ckey.", "Spawn Custom Item", WWinput_first_choice(custom_items), WWinput_choice_or_null(custom_items))
	if (!owner|| !custom_items[owner])
		return

	var/list/possible_items = custom_items[owner]
	var/datum/custom_item/item_to_spawn = WWinput(usr, "Select an item to spawn.", "Spawn Custom Item", WWinput_first_choice(possible_items), WWinput_choice_or_null(possible_items))
	if (!item_to_spawn)
		return

	item_to_spawn.spawn_item(get_turf(usr))

/datum/admins/proc/check_custom_items()

	set category = "Debug"
	set desc = "Check the custom item list."
	set name = "Check Custom Items"

	if (!check_rights(R_SPAWN))	return

	if (!custom_items)
		usr << "Custom item list is null."
		return

	if (!custom_items.len)
		usr << "Custom item list not populated."
		return

	for (var/assoc_key in custom_items)
		usr << "[assoc_key] has:"
		var/list/current_items = custom_items[assoc_key]
		for (var/datum/custom_item/item in current_items)
			usr << "- name: [item.name] icon: [item.item_icon] path: [item.item_path] desc: [item.item_desc]"
*/

var/list/atom_types = null
/datum/admins/proc/spawn_atom(var/object as text)
	set category = "Debug"
	set desc = "(atom path) Spawn an atom"
	set name = "Spawn"

	if (!check_rights(R_SPAWN))	return

	if (!atom_types)
		atom_types = typesof(/atom)

	var/list/matches = list()

	for (var/path in atom_types)
		if (findtext("[path]", object))
			matches += path

	if (matches.len==0)
		return

	var/chosen
	if (matches.len==1)
		chosen = matches[1]
	else
		chosen = WWinput(usr, "Select an atom type", "Spawn Atom", matches[1], WWinput_list_or_null(matches))
		if (!chosen)
			return

	if (ispath(chosen,/turf))
		var/turf/T = get_turf(usr.loc)
		T.ChangeTurf(chosen)
	else
		new chosen(usr.loc)

	log_and_message_admins("spawned [chosen] at ([usr.x],[usr.y],[usr.z])")

/datum/admins/proc/spawn_player_as_job()
	set category = "Admin"
	set desc = "Spawn a player in as a job"
	set name = "Spawn Player"
	if (!check_rights(R_SPAWN))	return

	var/mob/observer/ghost/G = WWinput(usr, "Which observer? Please note that unlike the Player Panel spawn, this will always send the observer to their spawnpoint.", "Spawn Player", WWinput_first_choice(observer_mob_list), WWinput_list_or_null(observer_mob_list))
	if (G == "Cancel")
		return
	else if (!istype(G))
		return

	var/list/job_master_occupation_names = list()
	for (var/datum/job/J in job_master.occupations)
		if (J.title)
			job_master_occupation_names[J.title] = J

	var/J = WWinput(usr, "Which job?", "Spawn Player", WWinput_first_choice(job_master_occupation_names), WWinput_list_or_null(job_master_occupation_names))
	if (J != "Cancel" && G)
		var/mob_type = job2mobtype(J)
		var/mob/living/carbon/human/H = new mob_type(G.loc)
		G.mind.transfer_to(H)
		G.reenter_corpse()
		job_master.EquipRank(H, J)
		H.original_job = job_master_occupation_names[J]
		var/msg = "[key_name(usr)] assigned the new mob [H] the job '[J]'."
		message_admins(msg)
		log_admin(msg)

/*
/datum/admins/proc/toggletintedweldhelmets()
	set category = "Debug"
	set desc="Reduces view range when wearing welding helmets"
	set name="Toggle tinted welding helmets."
	config.welder_vision = !( config.welder_vision )
	if (config.welder_vision)
		world << "<b>Reduced welder vision has been enabled!</b>"
	else
		world << "<b>Reduced welder vision has been disabled!</b>"
	log_admin("[key_name(usr)] toggled welder vision.")
	message_admins("[key_name_admin(usr)] toggled welder vision.", TRUE)

*/

/datum/admins/proc/toggleguests()
	set category = "Server"
	set desc="Guests can't enter"
	set name="Toggle guests"
	config.guests_allowed = !(config.guests_allowed)
	if (!(config.guests_allowed))
		world << "<b>Guests may no longer enter the game.</b>"
	else
		world << "<b>Guests may now enter the game.</b>"
	log_admin("[key_name(usr)] toggled guests game entering [config.guests_allowed?"":"dis"]allowed.")
	message_admins("<span class = 'notice'>[key_name_admin(usr)] toggled guests game entering [config.guests_allowed?"":"dis"]allowed.</span>", TRUE)


/datum/admins/proc/output_ai_laws()
	return FALSE

/client/proc/update_mob_sprite(mob/living/carbon/human/H as mob)
	set category = "Admin"
	set name = "Update Mob Sprite"
	set desc = "Should fix any mob sprite update errors."

	if (!holder)
		src << "Only administrators may use this command."
		return

	if (istype(H))
		H.regenerate_icons()


/*
	helper proc to test if someone is a mentor or not.  Got tired of writing this same check all over the place.
*/
/proc/is_mentor(client/C)

	if (!istype(C))
		return FALSE
	if (!C.holder)
		return FALSE

	if (C.holder.rights == R_MENTOR)
		return TRUE
	return FALSE

/proc/get_options_bar(whom, detail = 2, name = FALSE, link = TRUE, highlight_special = TRUE)
	if (!whom)
		return "<b>(*null*)</b>"
	var/mob/M
	var/client/C
	if (istype(whom, /client))
		C = whom
		M = C.mob
	else if (istype(whom, /mob))
		M = whom
		C = M.client
	else
		return "<b>(*not an mob*)</b>"
	switch(detail)
		if (0)
			return "<b>[key_name(C, link, name, highlight_special)]</b>"

		if (1)	//Private Messages
			return "<b>[key_name(C, link, name, highlight_special)](<A HREF='?_src_=holder;adminmoreinfo=\ref[M]'>?</A>)</b>"

		if (2)	//Admins
			var/ref_mob = "\ref[M]"
			return "<b>[key_name(C, link, name, highlight_special)](<A HREF='?_src_=holder;adminmoreinfo=[ref_mob]'>?</A>) (<A HREF='?_src_=holder;adminplayeropts=[ref_mob]'>PP</A>) (<A HREF='?_src_=vars;Vars=[ref_mob]'>VV</A>) (<A HREF='?_src_=holder;subtlemessage=[ref_mob]'>SM</A>) ([admin_jump_link(M, src)]) (<A HREF='?_src_=holder;check_antagonist=1'>CA</A>)</b>"

		if (3)	//Devs
			var/ref_mob = "\ref[M]"
			return "<b>[key_name(C, link, name, highlight_special)](<A HREF='?_src_=vars;Vars=[ref_mob]'>VV</A>)([admin_jump_link(M, src)])</b>"

		if (4)	//Mentors
			var/ref_mob = "\ref[M]"
			return "<b>[key_name(C, link, name, highlight_special)] (<A HREF='?_src_=holder;adminmoreinfo=\ref[M]'>?</A>) (<A HREF='?_src_=holder;adminplayeropts=[ref_mob]'>PP</A>) (<A HREF='?_src_=vars;Vars=[ref_mob]'>VV</A>) (<A HREF='?_src_=holder;subtlemessage=[ref_mob]'>SM</A>)</b>"


/proc/ishost(whom)
	if (!whom)
		return FALSE
	var/client/C
	var/mob/M
	if (istype(whom, /client))
		C = whom
	if (istype(whom, /mob))
		M = whom
		C = M.client
	if (R_HOST & C.holder.rights)
		return TRUE
	else
		return FALSE
//
//
//ALL DONE
//*********************************************************************************************************
//

//Returns TRUE to let the dragdrop code know we are trapping this event
//Returns FALSE if we don't plan to trap the event
/datum/admins/proc/cmd_ghost_drag(var/mob/observer/ghost/frommob, var/mob/living/tomob)
	if (!istype(frommob))
		return //Extra sanity check to make sure only observers are shoved into things

	//Same as assume-direct-control perm requirements.
	if (!check_rights(R_VAREDIT,0) || !check_rights(R_ADMIN|R_DEBUG,0))
		return FALSE
	if (!frommob.ckey)
		return FALSE
	var/question = ""
	if (tomob.ckey)
		question = "This mob already has a user ([tomob.key]) in control of it! "
	question += "Are you sure you want to place [frommob.name]([frommob.key]) in control of [tomob.name]?"
	var/ask = WWinput(usr, question, "Place ghost in control of mob?", "Yes", list("Yes", "No"))
	if (ask != "Yes")
		return TRUE
	if (!frommob || !tomob) //make sure the mobs don't go away while we waited for a response
		return TRUE
	if (tomob.client) //No need to ghostize if there is no client
		tomob.ghostize(0)
	message_admins("<span class='adminnotice'>[key_name_admin(usr)] has put [frommob.ckey] in control of [tomob.name].</span>")
	log_admin("[key_name(usr)] stuffed [frommob.ckey] into [tomob.name].")

	tomob.ckey = frommob.ckey
	qdel(frommob)
	return TRUE

/datum/admins/proc/paralyze_mob(mob/living/H as mob)
	set category = "Admin"
	set name = "Toggle Paralyze"
	set desc = "Paralyzes a player. Or unparalyses them."

	var/msg

	if (check_rights(R_ADMIN))
		if (H.paralysis == FALSE)
			H.paralysis = 8000
			msg = "has paralyzed [key_name(H)]."
		else
			H.paralysis = FALSE
			msg = "has unparalyzed [key_name(H)]."
		log_and_message_admins(msg)

/client/proc/reload_admins()
	set name = "Reload Admins"
	set category = "Debug"

	if (!check_rights(R_SERVER))	return

	message_admins("[key_name(usr)] manually reloaded admins")
	load_admins(1)