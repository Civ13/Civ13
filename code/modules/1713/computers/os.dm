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

	var/action = href_list["action"]
	if(action == "textreceived")
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
	if (operatingsystem == "unga OS 94" || operatingsystem == "unga OS 94 Law Enforcement Edition")
		var/subt = ""
		if (operatingsystem == "unga OS 94 Law Enforcement Edition")
			subt = "<br><font color='blue'>Law Enforcement</font>&nbsp;<font color='red'>EDITION</font>"
		mainmenu = {"
		<i><h1><img src='uos94.png'></img>[subt]</h1></i>
		<hr>
		"}
		if (programs.len)
			for(var/i=1, i<=programs.len, i++)
				if (programs[i] && istype(programs[i],/datum/program/))
					var/datum/program/P = programs[i]
					mainmenu += "&nbsp;<a href='?src=\ref[src];program=[i]'>[P.name]</a>"
					if (i % 3 == 0) // 3 items per line
						mainmenu += "<br>"
		mainbody = "System initialized."

	else if (operatingsystem == "unga OS")
		mainmenu = "<i><h1><img src='uos.png'></img></h1></i>"
		mainbody = {"<head>
				<script type="text/javascript">
					typeFunction() {
						if (e.keyCode == 13) {
							byond://?src=\ref[src]&action=textenter&value=document.getElementById('input').value
						}
						byond://?src=\ref[src]&action=textreceived&value=document.getElementById('input').value
					}
				</head><font color='yellow'>test</font><div class="vertical-center">
				<textarea id="display" name="display" rows="25" cols="60" readonly="true" style="resize: none; background-color: black; color: lime; border-style: inset inset inset inset; border-color: #161610; overflow: hidden;">
				:_"}
		mainbody+=display
		mainbody+={"</textarea>
				<input type="text" id="input" name="input" style="resize: none; background-color: black; color: lime; border-style: none inset inset inset; border-color: #161610; overflow: hidden;" onkeypress="typeFunction()"></input>
				</div>
				</html>
				"}