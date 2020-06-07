///////////////////////////////////////////////////////////////////
/obj/structure/computer/var/list/tmp_comp_vars = list(
	"mail_rec" = "Recipient",
	"mail_snd" = "Sender",
	"mail_subj" = "Subject",
	"mail_msg" = "Message",
)
/obj/structure/computer/proc/reset_tmp_vars()
	tmp_comp_vars = list(
		"mail_rec" = "Recipient",
		"mail_snd" = "Sender",
		"mail_subj" = "Subject",
		"mail_msg" = "Message",
	)
/obj/structure/computer/proc/do_html(mob/user)
	var/os = {"
			<!DOCTYPE html>
			<html>
			<head>[computer_browser_style]<title>[operatingsystem]</title></head>
			<body>
			<center>[mainmenu]</center>
			<hr style="height:4px;border-width:0;color:gray;background-color:gray">
			[mainbody]
			</body>
			</html>
			"}
	usr << browse(os,"window=opsys;border=1;can_close=1;can_resize=0;can_minimize=0;titlebar=1;size=800x600")
/obj/structure/computer/interact(var/mob/m)
	if (user)
		if (get_dist(src, user) > 1)
			user = null
	restart
	if (user && user != m)
		if (user.client)
			return
		else
			user = null
			goto restart
	else
		user = m
		do_html(user)
/obj/structure/computer/Topic(href, href_list, hsrc)

	var/mob/living/human/user = usr

	if (!user || user.lying || !ishuman(user))
		return

	user.face_atom(src)

	if (!locate(user) in range(1,src))
		user << "<span class = 'danger'>Get next to \the [src] to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE
	var/datum/program/loadedprogram
	if (href_list["program"])
		var/keyn = text2num(href_list["program"])
		if (programs.len && programs[keyn] && istype(programs[keyn], /datum/program))
			loadedprogram = programs[keyn]
			loadedprogram.origin = src
			loadedprogram.user = user
			loadedprogram.do_html(user)
			return

////Police
	if (href_list["squads"])
		mainbody = "<h2>SQUAD STATUS</h2><br>"
		if (user.civilization != "Police" && user.civilization != "Paramedics")
			mainbody += "<font color ='red'><b>ACCESS DENIED</b></font>"
			sleep(0.5)
			do_html(user)
			return
		else
			for(var/mob/living/human/H in player_list)
				if (H.civilization == user.civilization)
					var/tst = ""
					if (H.stat == UNCONSCIOUS)
						tst = "(Unresponsive)"
					else if (H.stat == DEAD)
						tst = "(Dead)"
					mainbody += "<b>[H.name]</b> at <b>[H.get_coded_loc()]</b> ([H.x],[H.y]) <b><i>[tst]</i></b><br>"

	if (href_list["plates"])
		mainbody = "<h2>LICENSE PLATE DATABASE</h2><br>"
		if (user.civilization != "Police")
			mainbody += "<font color ='red'><b>ACCESS DENIED</b></font>"
			sleep(0.5)
			do_html(user)
			return
		else
			for(var/list/L in map.vehicle_registations)
				mainbody += "<b>[L[1]]</b> - <b>[L[4]] [L[3]]</b> - registered to <b>[L[2]]</b><br>"
	if (href_list["permits"])
		mainbody = "<h2>GUN PERMITS</h2><br>"
		if (user.civilization == "Police" || user.civilization == "Paramedics")
			mainbody += "<font color='yellow'>This service is intended for civilians.</font>"
			sleep(0.5)
			do_html(user)
			return
		else if (user.gun_permit)
			mainbody += "<font color='yellow'>You are already licenced.</font>"
			sleep(0.5)
			do_html(user)
			return
		else if  (user.real_name in map.warrants)
			mainbody += "<font color='red'>You have, or had, a warrant in your name, so your request was <b>denied</b>.</font>"
			sleep(0.5)
			do_html(user)
			return
		else
			if (istype(user.get_active_hand(),/obj/item/stack/money) || istype(user.get_inactive_hand(),/obj/item/stack/money))
				var/obj/item/stack/money/M
				if (istype(user.get_active_hand(),/obj/item/stack/money))
					M = user.get_active_hand()
				else if (istype(user.get_inactive_hand(),/obj/item/stack/money))
					M = user.get_inactive_hand()
				if (M && M.value*M.amount >= 100*4)
					M.amount-=100/5
					if (M.amount <= 0)
						qdel(M)
				else
					mainbody += "<font color='red'>Not enough money! You need to have 100 dollars in your hands to pay for the permit.</font>"
					sleep(0.5)
					do_html(user)
					return
				user.gun_permit = TRUE
				mainbody += "<font color='green'>Your licence was <b>approved</b>.</span>"
				map.scores["Police"] += 100
			else
				mainbody += "<font color='red'>You need to have 100 dollars in your hands to pay for the permit.</span>"
				sleep(0.5)
				do_html(user)
				return
	if (href_list["warrants"])
		mainbody = "<h2>WARRANT TERMINAL</h2><br>"
		mainbody += "<a href='?src=\ref[src];warrants=2'>List Warrants</a>&nbsp;<a href='?src=\ref[src];warrants=3'>Register Suspect</a><hr><br>"
		if (href_list["warrants"] == "2")
			for(var/obj/item/weapon/paper/police/warrant/SW in map.pending_warrants)
				mainbody += "[SW.arn]: [SW.tgt], working for [SW.tgtcmp] <a href='?src=\ref[src];warrants=w[SW.arn]'>(print)</a><br>"

		if (findtext(href_list["warrants"],"w"))
			if (user.civilization != "Police")
				mainbody += "<font color ='red'><b>ACCESS DENIED</b></font>"
				sleep(0.5)
				do_html(user)
				return
			else
				var/tcode = replacetext(href_list["warrants"],"w","")
				for(var/obj/item/weapon/paper/police/warrant/SW in map.pending_warrants)
					if (SW.arn == text2num(tcode))
						var/obj/item/weapon/paper/police/warrant/NW = new/obj/item/weapon/paper/police/warrant(loc)
						NW.tgt_mob = SW.tgt_mob
						NW.tgt = SW.tgt
						NW.tgtcmp = SW.tgtcmp
						NW.reason = SW.reason
						NW.arn = SW.arn
						playsound(loc, 'sound/machines/printer.ogg', 100, TRUE)
						mainbody += "Sucessfully printed warrant number [tcode]."
						sleep(0.5)
						do_html(user)
						return
		if (href_list["warrants"] == "3")
			if (user.civilization != "Police" && user.civilization != "Paramedics")
				var/done = FALSE
				var/found = FALSE
				for (var/mob/living/human/S in range(2,src))
					if (S.civilization != user.civilization && S.handcuffed && S != user)
						found = TRUE
						for(var/obj/item/weapon/paper/police/warrant/SW in map.pending_warrants)
							if (SW.tgt_mob == S)
								map.scores["Police"] += 100
								var/obj/item/stack/money/dollar/DLR = new/obj/item/stack/money/dollar(loc)
								DLR.amount = 20
								DLR.update_icon()
								done = TRUE
								mainbody += "<font color='green'>Processed warrant no. <b>[SW.arn]</b> for <b>[SW.tgt]</b>, as a citizens arrest. Thank you for your service.</font>"
								map.pending_warrants -= SW
								SW.forceMove(null)
								qdel(SW)
								for(var/mob/living/human/HP in player_list)
									if (HP.civilization == "Police")
										HP << "<big><font color='yellow'>A suspect with a pending warrant has been dropped off at the Police station by a citizens arrest.</font></big>"
					if (!done && found)
						mainbody += "<font color='yellow'>There are no outstanding warrants for any of the suspects.</font>"
					else if (!done && !found)
						mainbody += "<font color='yellow'>There are no suspects present.</font>"
					else
						mainbody += "<font color='yellow'>There are no outstanding warrants for any of the suspects.</font>"
					sleep(0.5)
					do_html(user)
					return
			else
				var/done = FALSE
				var/found = FALSE
				for (var/mob/living/human/S in range(2,src))
					found = TRUE
					for(var/obj/item/weapon/paper/police/warrant/SW in map.pending_warrants)
						if (SW.tgt_mob == S)
							map.scores["Police"] += 300
							done = TRUE
							mainbody += "<font color='green'>Processed warrant no. <b>[SW.arn]</b> for <b>[SW.tgt]</b>.</font>"
							map.pending_warrants -= SW
							SW.forceMove(null)
							qdel(SW)
				if (!done && found)
					mainbody += "<font color='yellow'>There are no outstanding warrants for any of the suspects.</font>"
				else if (!done && !found)
					mainbody += "<font color='yellow'>There are no suspects present.</font>"
				else
					mainbody += "<font color='yellow'>There are no outstanding warrants for any of the suspects.</font>"
				sleep(0.5)
				do_html(user)

	var/action = href_list["action"]
	if(action == "textrecieved")
		var/typenoise = pick('sound/machines/computer/key_1.ogg',
							 'sound/machines/computer/key_2.ogg',
							 'sound/machines/computer/key_3.ogg',
							 'sound/machines/computer/key_4.ogg',
							 'sound/machines/computer/key_5.ogg',
							 'sound/machines/computer/key_6.ogg',
							 'sound/machines/computer/key_7.ogg',
							 'sound/machines/computer/key_8.ogg')
		playsound(loc, typenoise, 10, TRUE)
	if(action == "textenter")
		playsound(loc, 'sound/machines/computer/key_enter.ogg', 10, TRUE)
		display+=href_list["value"]

	sleep(0.5)
	do_html(user)

/obj/structure/computer/proc/boot(operatingsystem = "none")
	if (operatingsystem == "unga OS 94")
		mainmenu = {"
		<i><h1><img src='uos94.png'></img></h1></i>
		<hr>
		"}
		if (programs.len)
			for(var/i=1, i<=programs.len, i++)
				if (programs[i] && istype(programs[i],/datum/program/))
					var/datum/program/P = programs[i]
					mainmenu += "&nbsp;<a href='?src=\ref[src];program=[i]'>[P.name]</a>"
		mainbody = "System initialized."
	else if (operatingsystem == "unga OS 94 Police Edition")
		mainmenu = {"
		<i><h1><img src='uos94.png'></img><br><font color='blue'>POLICE</font> <font color='red'>EDITION</font></h1></i>
		<hr>
		<a href='?src=\ref[src];warrants=1'>Warrants</a>&nbsp;<a href='?src=\ref[src];permits=1'>Gun Permits</a>&nbsp;<a href='?src=\ref[src];squads=1'>Squad Status</a>&nbsp;<a href='?src=\ref[src];plates=1'>Licence Plate Registry</a>
		"}
		mainbody = "System initialized."

	else if (operatingsystem == "unga OS")
		mainmenu = "<i><h1><img src='uos.png'></img></h1></i>"
		mainbody = {"
				<script type="text/javascript">
					typeFunction() {
						if (e.keyCode == 13) {
							byond://?src=\ref[src]&action=textenter&value=document.getElementById('input').value
						}
						byond://?src=\ref[src]&action=textrecieved&value=document.getElementById('input').value
					}
				<div class="vertical-center">
				<textarea id="display" name="display" rows="25" cols="60" readonly="true" style="resize: none; background-color: black; color: lime; border-style: inset inset inset inset; border-color: #161610; overflow: hidden;">
				"}
		mainbody+=display
		mainbody+={"</textarea>
				: <input type="text" id="input" name="input" style="resize: none; background-color: black; color: lime; border-style: none inset inset inset; border-color: #161610; overflow: hidden;" onkeypress="typeFunction()"></input>
				</div>
				</html>
				"}