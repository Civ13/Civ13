
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
	set desc = "Edit player (respawn, ban, heal, etc)"

	if (!M)
		usr << "You seem to be selecting a mob that doesn't exist anymore."
		return

	if (!istype(src,/datum/admins))
		src = usr.client.holder
	if (!istype(src,/datum/admins))
		usr << "Error: you are not an admin!"
		return

	var/body = "<html>[common_browser_style]<head><title>Options for [M.key]</title></head>"
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

			body += {"<br><br>
				<b>Rudimentary transformation:</b><font size=2><br>These transformations only create a new mob type and copy stuff over. They do not take into account MMIs and similar mob-specific things. The buttons in 'Transformations' are preferred, when possible.</font><br>
				<A href='?src=\ref[src];simplemake=observer;mob=\ref[M]'>Observer</A> |
				\[ Default: <A href='?src=\ref[src];simplemake=human;mob=\ref[M]'>Human</A> |
				<A href='?src=\ref[src];simplemake=monkey;mob=\ref[M]'>Monkey</A> |
				<A href='?src=\ref[src];simplemake=cat;mob=\ref[M]'>Cat</A> |
				<A href='?src=\ref[src];simplemake=parrot;mob=\ref[M]'>Parrot</A> |
				<A href='?src=\ref[src];simplemake=chicken;mob=\ref[M]'>Chicken</A> |
				<A href='?src=\ref[src];simplemake=turkey;mob=\ref[M]'>Turkey</A> |
				<A href='?src=\ref[src];simplemake=cow;mob=\ref[M]'>Cow</A> |
				<A href='?src=\ref[src];simplemake=bull;mob=\ref[M]'>Bull</A> |
				<A href='?src=\ref[src];simplemake=nouse;mob=\ref[M]'>Mouse</A> |
				<A href='?src=\ref[src];simplemake=bear;mob=\ref[M]'>Bear</A> |
				<A href='?src=\ref[src];simplemake=velociraptor;mob=\ref[M]'>Velociraptor</A> ]
				<br>"}
			body += {"<br><br>
				<b>Body type transformation:</b><font size=2><br>These transformations will keep the user as "human" but change the body type.</font><br>
				<A href='?src=\ref[src];simplemake=default;mob=\ref[M]'>Default</A> |
				<A href='?src=\ref[src];simplemake=gorilla;mob=\ref[M]'>Gorilla</A> |
				<A href='?src=\ref[src];simplemake=wolfman;mob=\ref[M]'>Werewolf</A> |
				<A href='?src=\ref[src];simplemake=ant;mob=\ref[M]'>Ant</A> |
				<A href='?src=\ref[src];simplemake=orc;mob=\ref[M]'>Orc</A> |
				<br>"}
	body += {"<br><br>
			<b>Other actions:</b>
			<br>
			<A href='?src=\ref[src];forcespeech=\ref[M]'>Forcesay</A>
			"}

	// language toggles
	body += "<br><br><b>Languages:</b><br>"
	var/f = TRUE
	for (var/k in all_languages)
		var/datum/language/L = all_languages[k]
		if (!(L.flags & INNATE))
			if (!f) body += " | "
			else f = FALSE
			if (L in M.languages)
				body += "<a href='?src=\ref[src];toglang=\ref[M];lang=[html_encode(k)]' style='color:#006600'>[k]</a>"
			else
				body += "<a href='?src=\ref[src];toglang=\ref[M];lang=[html_encode(k)]' style='color:#ff0000'>[k]</a>"

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
	var/savefile/S=new("data/player_notes.sav")
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
	var/dat = "<html>[common_browser_style]<head><title>Info on [key]</title></head>"
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

/datum/admins/proc/game_panel()
	if (!check_rights(R_ADMIN))	return

	var/dat = {"
		[common_browser_style]
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

/////////////////////////////////////////////////////////////////////////////////////////////////admins2.dm merge
//i.e. buttons/verbs


/datum/admins/proc/restart()
	set category = "Server"
	set name = "Restart"
	set desc = "Restarts the world"
	if (!usr.client.holder)
		return
	var/confirm = WWinput(usr, "Restart the game world?", "Restart", "Yes", list("Yes", "Cancel"))
	if (confirm == "Cancel")
		return
	if (processes.mapswap && ticker.restarting_is_very_bad)
		var/unconfirm = WWinput(usr, "Mapswap is in progress. Restarting now may break the linked server. Continue?", "Warning", "No", list("No", "Yes"))
		if (unconfirm == "No")
			return
	if (confirm == "Yes")
		world << "<span class='danger'>Restarting world!</span> <span class='notice'>Initiated by <b>[usr.client.holder.fakekey ? "Admin" : usr.key]</b>!</span>"
		log_admin("[key_name(usr)] initiated a reboot.")
		sleep(50)
		world.Reboot()

/datum/admins/proc/announce()
	set category = "Special"
	set name = "Announce"
	set desc = "Announce your desires to the world"
	if (!check_rights(0))	return

	var/message = input("Global message to send:", "Admin Announce", null, null)
	if (message)
		if (!check_rights(R_SERVER,0))
			message = sanitize(message, 500, extra = FALSE)
		message = replacetext(message, "\n", "<br>") // required since we're putting it in a <p> tag
		if (usr && usr.client)
			world << "<big><span class=notice><b>[usr.client.holder.fakekey ? "Administrator" : usr.key] Announces:</b></big><p style='text-indent: 50px'>[message]</p></span>"
			log_admin("Announce: [key_name(usr)] : [message]")

/datum/admins/proc/ic_announce()
	set category = "Special"
	set name = "IC Announcement"
	set desc = "Announce events"
	if (!check_rights(0))	return
	var/messaget = input("Message Title:", "IC Announcement", null, null)
	var/message = input("Global message to send:", "IC Announcement", null, null)
	if (message)
		if (!check_rights(R_SERVER,0))
			message = sanitize(message, 500, extra = FALSE)
		message = replacetext(message, "\n", "<br>") // required since we're putting it in a <p> tag
		world << "<big><span class=notice><b>[messaget]</b></big><p style='text-indent: 30px'>[message]</p></span>"
		log_admin("Announce: [key_name(usr)] - [messaget] : [message]")


/datum/admins/proc/toggleooc()
	set category = "Server"
	set desc = "Globally Toggles OOC"
	set name = "Toggle OOC"

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
	set desc = "Globally Toggles LOOC"
	set name = "Toggle LOOC"

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
	set desc = "Globally Toggles DSAY"
	set name = "Toggle DSAY"

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
	set desc = "Toggle Dead OOC."
	set name = "Toggle Dead OOC"

	if (!check_rights(R_ADMIN))
		return

	config.dooc_allowed = !( config.dooc_allowed )
	log_admin("[key_name(usr)] toggled Dead OOC.")
	message_admins("[key_name_admin(usr)] toggled Dead OOC.", TRUE)

/datum/admins/proc/startnow()
	set category = "Server"
	set desc = "Start the round immediately"
	set name = "Start Now"
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
	set desc = "People can't enter"
	set name = "Toggle Entering"
	config.enter_allowed = !(config.enter_allowed)
	if (!(config.enter_allowed))
		world << "<b>New players may no longer enter the game.</b>"
	else
		world << "<b>New players may now enter the game.</b>"
	log_admin("[key_name(usr)] toggled new player game entering.")
	message_admins("<span class = 'notice'>[key_name_admin(usr)] toggled new player game entering.</span>", TRUE)
	world.update_status()


/datum/admins/proc/toggleaban()
	set category = "Server"
	set desc = "Respawn basically"
	set name = "Toggle Respawn"
	config.abandon_allowed = !(config.abandon_allowed)
	if (config.abandon_allowed)
		world << "<b>You may now respawn.</b>"
	else
		world << "<b>You may no longer respawn :(</b>"
	message_admins("<span class = 'notice'>[key_name_admin(usr)] toggled respawn to [config.abandon_allowed ? "On" : "Off"].</span>", TRUE)
	log_admin("[key_name(usr)] toggled respawn to [config.abandon_allowed ? "On" : "Off"].")
	world.update_status()

/datum/admins/proc/delay()
	set category = "Server"
	set desc = "Delay the game start/end"
	set name = "Delay"

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
	set desc = "Toggle admin jumping"
	set name = "Toggle Jump"
	config.allow_admin_jump = !(config.allow_admin_jump)
	message_admins("<span class = 'notice'>[key_name(usr)] toggled admin jumping to [config.allow_admin_jump].</span>")


/datum/admins/proc/adspawn()
	set category = "Server"
	set desc = "Toggle admin spawning"
	set name = "Toggle Spawn"
	config.allow_admin_spawning = !(config.allow_admin_spawning)
	message_admins("<span class = 'notice'>[key_name(usr)] toggled admin item spawning to [config.allow_admin_spawning].</span>")


/datum/admins/proc/adrev()
	set category = "Server"
	set desc = "Toggle admin revives"
	set name = "Toggle Revive"
	config.allow_admin_rev = !(config.allow_admin_rev)
	message_admins("<span class = 'notice'>Toggled reviving to [config.allow_admin_rev].</span>")


/datum/admins/proc/immreboot()
	set category = "Server"
	set desc = "Reboots the server post haste"
	set name = "Immediate Reboot"
	if (!usr.client.holder)	return
	if (WWinput(usr, "Reboot the server?", "Reboot", "Yes", list("Yes","No")) == "No")
		return
	world << "<span class = 'red'><b>Rebooting world!</b> <span class = 'notice'>Initiated by [usr.client.holder.fakekey ? "Admin" : usr.key]!</span></span>"
	log_admin("[key_name(usr)] initiated an immediate reboot.")
	world.Reboot()
/datum/admins/proc/set_research()
	set category = "Special"
	set desc = "Activates or Deactivates research."
	set name = "Toggle Research"
	if ((!map.civilizations && !map.nomads) || map.ID == MAP_TRIBES || map.ID == MAP_FOUR_KINGDOMS || map.ID == MAP_THREE_TRIBES)
		usr << "<font color='red'>Error: This is only available on Civ/Nomads modes.</font>"
		return
	if (!(map.research_active))
		map.research_active = TRUE
		world << "<big>Research has been <b>activated.</b></big>"
		log_admin("[key_name(usr)] has activated the Research.")
		return
	else
		map.research_active = FALSE
		world << "<big>Research has been <b>deactivated.</b></big>"
		log_admin("[key_name(usr)] has deactivated the Research.")
		return
/datum/admins/proc/redirect_all_players()
	set category = "Debug"
	set desc = "Redirects all players to another server."
	set name = "Server Redirection"
	if (!usr.client.holder)
		return
	if (usr.client.holder.rank == "Admiral" || usr.client.holder.rank == "Host")
		redirect_all_players = input("Where to redirect them to? Use byond://server:port format","Redirection",null) as text
		if (redirect_all_players == null || redirect_all_players == "0" || redirect_all_players == "")
			return
		for (var/C in clients)
			winset(C, null, "mainwindow.flash=1")
			C << link(redirect_all_players)
	else
		return
/datum/admins/proc/set_research_speed()
	set category = "Special"
	set desc = "Changes research speed in Auto-Research mode."
	set name = "Set Research Speed"
	if (!map.civilizations && !map.nomads)
		usr << "<font color='red'>Error: This is only available on Civ/Nomads modes.</font>"
	if (!(map.autoresearch))
		usr << "<font color='red'>Error: This is only available within the Auto-Research Gamemode.</font>"
		return
	else
		var/customresearchsp = input("How many Research Points to increase per minute?", "Auto-Research Multiplier") as num|null
		if (customresearchsp == null)
			return
		if (customresearchsp < 0)
			customresearchsp = 0
		if (customresearchsp > 230)
			customresearchsp = 230
		map.autoresearch_mult = customresearchsp
		world << "<big>Research increase per minute has been changed to <b>[map.autoresearch_mult]</b></big>"
		log_admin("[key_name(usr)] has changed the research modifier to [map.autoresearch_mult].")
		return

/datum/admins/proc/set_custom_research()
	set category = "Special"
	set desc = "Changes the research."
	set name = "Set Custom Research"
	if (!map.civilizations && !map.nomads && map.ID != MAP_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID != MAP_THREE_TRIBES)
		usr << "<font color='red'>Error: This is only available on Civ/Nomads modes.</font>"
		return
	else
		var/customresearch = input("What do you want the research to be?", "Custom Research") as num|null
		if (customresearch == null)
			return
		if (customresearch <= 0)
			customresearch = 0
		if (customresearch >= 280)
			customresearch = 280

		map.default_research = customresearch
		map.civa_research = list(customresearch,customresearch,customresearch,null)
		map.civb_research = list(customresearch,customresearch,customresearch,null)
		map.civc_research = list(customresearch,customresearch,customresearch,null)
		map.civd_research = list(customresearch,customresearch,customresearch,null)
		map.cive_research = list(customresearch,customresearch,customresearch,null)
		map.civf_research = list(customresearch,customresearch,customresearch,null)
		world << "<big>The research has been set to  <b>[customresearch]</b>.</big>"
		log_admin("[key_name(usr)] set the research to [customresearch].")
		return
/datum/admins/proc/set_custom_age()
	set category = "Special"
	set desc = "Changes the starting age."
	set name = "Set Custom Age"
	if (!map.civilizations && !map.nomads && map.ID != MAP_TRIBES && map.ID != MAP_THREE_TRIBES && map.ID != MAP_FOUR_KINGDOMS)
		usr << "<font color='red'>Error: This is only available on Civ/Nomads modes.</font>"
		return
	else
		var/customage = WWinput(src, "Choose the starting age:", "Starting Age", "5000 B.C.", list("5000 B.C.", "313 B.C.", "1013", "1713", "1873", "1903","1943","1969","2013", "Cancel"))
		if (customage == "Cancel")
			return
		else if (customage == "5000 B.C.")
			map.ordinal_age = 0
			map.age = "5000 B.C."
			world << "<big>The Epoch has been changed to <b>[map.age]</b>.</big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "313 B.C.")
			map.ordinal_age = 1
			map.age = "313 B.C."
			map.age1_done = TRUE
			map.default_research = 35
			world << "<big>The Epoch has been changed to <b>[map.age]</b>.</big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "1013")
			map.ordinal_age = 2
			map.age = "1013"
			map.age1_done = TRUE
			map.age2_done = TRUE
			map.default_research = 50
			world << "<big>The Epoch has been changed to <b>[map.age]</b>.</big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "1713")
			map.ordinal_age = 3
			map.age = "1713"
			map.age1_done = TRUE
			map.age2_done = TRUE
			map.age3_done = TRUE
			map.default_research = 90
			world << "<big>The Epoch has been changed to <b>[map.age]</b></big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "1873")
			map.ordinal_age = 4
			map.age = "1873"
			map.age1_done = TRUE
			map.age2_done = TRUE
			map.age3_done = TRUE
			map.age4_done = TRUE
			map.default_research = 105
			world << "<big>The Epoch has been changed to <b>[map.age]</b></big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "1903")
			map.ordinal_age = 5
			map.age = "1903"
			map.age1_done = TRUE
			map.age2_done = TRUE
			map.age3_done = TRUE
			map.age4_done = TRUE
			map.age5_done = TRUE
			map.default_research = 135
			world << "<big>The Epoch has been changed to <b>[map.age]</b></big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "1943")
			map.ordinal_age = 6
			map.age = "1943"
			map.age1_done = TRUE
			map.age2_done = TRUE
			map.age3_done = TRUE
			map.age4_done = TRUE
			map.age5_done = TRUE
			map.age6_done = TRUE
			map.default_research = 152
			world << "<big>The Epoch has been changed to <b>[map.age]</b></big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "1969")
			map.ordinal_age = 7
			map.age = "1969"
			map.age1_done = TRUE
			map.age2_done = TRUE
			map.age3_done = TRUE
			map.age4_done = TRUE
			map.age5_done = TRUE
			map.age6_done = TRUE
			map.age7_done = TRUE
			map.default_research = 185
			world << "<big>The Epoch has been changed to <b>[map.age]</b></big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
		else if (customage == "2013")
			map.ordinal_age = 8
			map.age = "2013"
			map.age1_done = TRUE
			map.age2_done = TRUE
			map.age3_done = TRUE
			map.age4_done = TRUE
			map.age5_done = TRUE
			map.age6_done = TRUE
			map.age7_done = TRUE
			map.age8_done = TRUE
			map.default_research = 230
			world << "<big>The Epoch has been changed to <b>[map.age]</b></big>"
			log_admin("[key_name(usr)] changed the map's epoch to [map.age].")
			return
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
		var/mob/living/human/H = new mob_type(G.loc)
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
	set desc = "Reduces view range when wearing welding helmets"
	set name = "Toggle tinted welding helmets."
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
	set desc = "Guests can't enter"
	set name = "Toggle guests"
	config.guests_allowed = !(config.guests_allowed)
	if (!(config.guests_allowed))
		world << "<b>Guests may no longer enter the game.</b>"
	else
		world << "<b>Guests may now enter the game.</b>"
	log_admin("[key_name(usr)] toggled guests game entering [config.guests_allowed?"":"dis"]allowed.")
	message_admins("<span class = 'notice'>[key_name_admin(usr)] toggled guests game entering [config.guests_allowed?"":"dis"]allowed.</span>", TRUE)


/datum/admins/proc/output_ai_laws()
	return FALSE

/client/proc/update_mob_sprite(mob/living/human/H as mob)
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
		return "<b>(*not a mob*)</b>"
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
	set desc = "Paralyzes a player and the area around. Or unparalyses them."

	var/msg

	if (check_rights(R_ADMIN))
		var/chc = WWinput(usr, "Paralyze area or player?", "Player", list("Player", "Area"))
		if (chc == "Area")
			var/rngd = WWinput(usr, "What range to paralyze/unparalyze?", 3, list(2,3,4,5,6))
			if (H.paralysis == FALSE)
				H.paralysis = 8000
				msg = "has paralyzed [key_name(H)] and everyone in [rngd] tiles around."
				for (var/mob/living/human/HH in range(rngd,H))
					if (HH.paralysis == FALSE)
						HH.paralysis = 8000
			else
				H.paralysis = FALSE
				msg = "has unparalyzed [key_name(H)] and everyone in [rngd] tiles around."
				for (var/mob/living/human/HH in range(rngd,H))
					if (HH.paralysis == TRUE)
						HH.paralysis = 0
		else
			if (H.paralysis == FALSE)
				H.paralysis = 8000
				msg = "has paralyzed [key_name(H)]."
			else
				H.paralysis = FALSE
				msg = "has unparalyzed [key_name(H)]."
		log_and_message_admins(msg)
/datum/admins/proc/punish(mob/living/human/H as mob)
	set category = "Admin"
	set name = "Punish"
	set desc = "Punishes a player."

	var/msg

	if (check_rights(R_ADMIN))
		var/chc = WWinput(usr, "What to do?", "Cancel", list("Cancel", "Cholera", "Brain Damage"))
		if (chc == "Cancel")
			return
		else if (chc == "Cholera")
			H.disease_progression = 0
			H.disease_type ="cholera"
			H.disease = 1
			msg = "has given [key_name(H)] cholera."
		else if (chc == "Brain Damage")
			H.adjustBrainLoss(15)
			msg = "has given [key_name(H)] 15 units of brain damage."
		log_and_message_admins(msg)

/client/proc/reload_admins()
	set name = "Reload Lists"
	set category = "Debug"

	if (!check_rights(R_SERVER))	return

	message_admins("[key_name(usr)] manually reloaded admins, whitelists and approved lists.")

	load_admins(1)

	var/F = file("SQL/approved.txt")
	if (fexists(F))
		var/list/approved_list_temp = file2list(F,"\n")
		for (var/i in approved_list_temp)
			if (findtext(i, "="))
				var/list/current = splittext(i, "=")
				approved_list += current[1]

	var/F2 = file("SQL/whitelist.txt")
	if (fexists(F2))
		var/list/whitelist_temp = file2list(F2,"\n")
		for (var/i in whitelist_temp)
			if (findtext(i, "="))
				var/list/current = splittext(i, "=")
				whitelist_list += current[1]
	var/F3 = file("SQL/factionlist.txt")
	if (fexists(F3))
		faction_list_blue = list()
		faction_list_red = list()
		var/list/flist_temp = file2list(F3,"\n")
		for (var/i in flist_temp)
			if (findtext(i, ";"))
				var/list/current = splittext(i, ";")
				if (current[2] == "red")
					faction_list_red += current[1]
				else if (current[2] == "blue")
					faction_list_blue += current[1]

/client/proc/reload_bans()
	set name = "Update Bans"
	set category = "Debug"

	if (!check_rights(R_SERVER))	return

	message_admins("[key_name(usr)] manually reloaded bans.")
	load_bans()

/client/proc/start_forcelife()
	set name = "Start Forcelife"
	set category = "Debug"

	if (!check_rights(R_SERVER))	return

	message_admins("[key_name(usr)] manually set the Life() proc of living mobs.")
	for(var/mob/living/L in world)
		if (!L.life_forced)
			L.forcelife()

/client/proc/reload_craft_list()
	set name = "Reload Crafting"
	set category = "Debug"

	if (!check_rights(R_SERVER))	return

	message_admins("[key_name(usr)] manually reloaded crafting recipes.")
	load_recipes()

/client/proc/load_voyage_event()
	set name = "Load Event"
	set category = "Debug"

	if (!check_rights(R_SERVER))	return
	if (!map || map.ID != MAP_VOYAGE)
		WWalert(usr, "This only works on Voyage!","Wrong Map")
		return
	var/obj/map_metadata/voyage/nmap = map
	var/do_clear = FALSE
	var/do_load = FALSE
	var/checking = WWinput(usr, "Do you just want to clear the map, load, or load without clearing?","Load Map","Cancel",list("Clear and load","Load without clearing","Just clear","Cancel"))
	switch(checking)
		if("Clear and load")
			do_clear = TRUE
			do_load = TRUE
		if("Load without clearing")
			do_clear = FALSE
			do_load = TRUE
		if("Just clear")
			do_clear = TRUE
			do_load = FALSE
			nmap.clear_map()
			message_admins("[key_name(usr)] manually cleared the map.")
			return
		if("Cancel")
			return
	if (do_load)
		var/loct = WWinput(usr, "Which location to load into?","Load Map","Random",list("north","south","random"))
		var/options = list("manual input")
		var/t_options = flist("maps/zones/[loct]/")
		for(var/i in t_options)
			if(findtext(i,"dmm"))
				options += replacetext(i, ".dmm", "")
		var/nam = WWinput(usr, "Which map to load?","Load Map","manual input",options)
		if (nam == "manual input")
			nam = input(usr, "which map?","Manual Input","") as text
		nmap.navmoving = FALSE
		for(var/obj/effect/sailing_effect/S in world)
			S.icon_state = "sailing_effect_stopped"
			S.update_icon()
		nmap.inzone = TRUE
		nmap.ship_anchored = TRUE
		for(var/obj/structure/voyage/anchor_capstan/VAC in world)
			VAC.update_icon()
		world << "<font size=4 color='yellow'>The ship arrives at the destination.</font>"
		if (do_clear)
			nmap.clear_map()
			message_admins("[key_name(usr)] manually cleared the map.")
		if (do_load)
			nmap.load_map(nam,loct)
			message_admins("[key_name(usr)] manually loaded an event.")

client/proc/debug_variables_map()
	set name = "Debug Map Variables"
	set category = "Debug"

	if (!check_rights(R_SERVER))	return

	debug_variables(map)

/proc/load_recipes()
	var/all_craft_lists = flist("config/crafting/")
	for (var/i in all_craft_lists)
		var/current_list = "global"
		var/F3 = file("config/crafting/[i]")
		current_list = replacetext(i,"material_recipes_","")
		current_list = replacetext(current_list,".txt","")
		if (fexists(F3) && findtext(i,"material_recipes"))
			var/list/craftlist_temp = file2list(F3,"\n")
			craftlist_lists[current_list] = list()
			for (var/j in craftlist_temp)
				if (findtext(j, ",") && findtext(j,"RECIPE: ") && !(findtext(j,"//")))
					var/tmpj = replacetext(j, "RECIPE: ", "")
					var/list/current = splittext(tmpj, ",")
					craftlist_lists[current_list] += list(current)
					if (current.len != 13)
						world.log << "Error! Recipe [current[2]] has a length of [current.len] (should be 13)."
		else
			admin_notice("<span class='danger'>Failed to load crafting recipes!</span>", R_DEBUG)
	if (map)
		map.load_new_recipes()
	world.log << "Finished loading recipes."
/datum/admins/proc/toggle_ores()
	set category = "Special"
	set desc = "Toggle ore spawners on and off"
	set name = "Toggle Ore Spawners"

	if (map)
		if (map.orespawners == 1)
			map.orespawners = 0
			world.log << "usr] toggled the ore spawners OFF."
			for (var/obj/effect/spawner/orespawner/O in world)
				O.active = 0
				O.do_spawn()
			return
		else
			map.orespawners = 1
			world.log << "[usr] toggled the ore spawners ON."
			for (var/obj/effect/spawner/orespawner/O in world)
				O.active = 1
				O.do_spawn()
			return

/proc/load_bans()
	var/removed = 0
	var/kept = 0
	var/checkingfile = "SQL/bans.txt"
	if (fexists(checkingfile))
		var/details = file2text(checkingfile)
		var/list/details_lines = splittext(details, "|||\n")
		if (details_lines.len)
			for(var/i=1,i<=details_lines.len,i++)
				if (findtext(details_lines[i], ";"))
					var/list/details2 = splittext(details_lines[i], ";")
					if (text2num(details2[7])<=world.realtime)
						details_lines -= details_lines[i]
						removed++
		fdel(checkingfile)
		if (details_lines.len)
			for(var/L in details_lines)
				if (L && L != "")
					text2file("[L]|||", checkingfile)
					kept++

	world.log << "Finished cleaning ban list. [removed] bans removed, [kept] bans kept."
	return TRUE

//Radiation/Pollution stuff
/datum/admins/proc/get_world_values()
	set category = "Debug"
	set desc = "Display some of the global vars."
	set name = "Display Worldvars"

	src << "<b>World Variables:</b>"
	src << "Radiation: [get_global_radiation()]"
	src << "Pollution: [get_global_pollution()]"
	src << "Chickens: [chicken_count.len]"
	src << "Turkeys: [turkey_count.len]"
	src << "Cows: [cow_count.len]"
	src << "Goats: [goat_count.len]"
	src << "Sheep: [sheep_count.len]"
	src << "Pigs: [pig_count.len]"
	src << "Deer: [deer_count.len]"
	src << "Wolves: [wolf_count.len]"
	src << "Bears: [bear_count.len]"


/datum/admins/proc/set_radiation()
	set category = "Fun"
	set desc = "Set the radiation level of the world."
	set name = "Set World Radiation"

	var/num = input(usr, "Enter what you want the world's radiation to be, press cancel or leave blank if you change your mind. Numbers only please!", "Set Radiation", 0) as num
	if (!isnum(num) || num < 0)
		return
	else
		set_global_radiation(num)
		world.log << "[usr] set the worlds radiation to [num]."

/datum/admins/proc/set_pollution()
	set category = "Fun"
	set desc = "Set the pollution level of the world."
	set name = "Set World Pollution"

	var/num = input(usr, "Enter what you want the world's pollution to be, press cancel or leave blank if you change your mind. Numbers only please!", "Set Pollution", 0) as num
	if (!isnum(num) || num < 0)
		return
	else
		set_global_pollution(num)
		world.log << "[usr] set the worlds pollution to [num]."

/datum/admins/proc/zombiemechanic()
	set category = "Fun"
	set desc = "toggle zombie mechanic in the current round."
	set name = "Zombie mechanic"

	if (map && !map.is_zombie)
		map.is_zombie = TRUE
		world << "<big><b>Zombie mechanics have been enabled in the current round.</b></big>"
	else
		map.is_zombie = FALSE
		world << "<big><b>Zombie mechanics have been disabled in the current round.</b></big>"
	return

/datum/admins/proc/fantasy_races()
	set category = "Fun"
	set desc = "Enable fantasy race selection in the current round."
	set name = "Fantasy race selection"

	if (map && !map.is_fantrace)
		map.is_fantrace = TRUE
		world << "<big><b>Fantasy race selection has been enabled in the current round.</b></big>"
	else
		map.is_fantrace = FALSE
		world << "<big><b>Fantasy race selection has been disabled in the current round.</b></big>"
	return