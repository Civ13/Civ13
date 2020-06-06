/datum/email
	var/subject = "no subject"
	var/sender = "unknown"
	var/receiver = "unknown"
	var/message = ""
	var/date = "0:00"

/datum/email/New(list/properties = null)
	..()
	if (!properties) return

	for (var/propname in vars)
		if (!isnull(properties[propname]))
			vars[propname] = properties[propname]
///////////////////////////////////////////////////////////////////
/obj/structure/computer/var/list/tmp_comp_vars = list(
	"mail_rec" = "Recipient",
	"mail_subj" = "Subject",
	"mail_msg" = "Message",
)
/obj/structure/computer/proc/reset_tmp_vars()
	tmp_comp_vars = list(
		"mail_rec" = "Recipient",
		"mail_subj" = "Subject",
		"mail_msg" = "Message",
	)
/obj/structure/computer/proc/do_html(mob/user)
	if(operatingsystem == "ungaOS")
		var/os = {"
				<!DOCTYPE html>
				<html>
				<head>
				<title>Unga OS V 0.1</title>
				[computer_browser_style]
				<script type="text/javascript">
					typeFunction() {
						if (e.keyCode == 13) {
							byond://?src=\ref[src]&action=textenter&value=document.getElementById('input').value
						}
						byond://?src=\ref[src]&action=textrecieved&value=document.getElementById('input').value
					}
				</head>
				<div class="vertical-center">
				<textarea id="display" name="display" rows="25" cols="60" readonly="true" style="resize: none; background-color: black; color: lime; border-style: inset inset inset inset; border-color: #161610; overflow: hidden;">
				"}
		os+=display
		os+={"</textarea>
				<input type="text" id="input" name="input" style="resize: none; background-color: black; color: lime; border-style: none inset inset inset; border-color: #161610; overflow: hidden;" onkeypress="typeFunction()"></input>
				</div>
				</html>
				"}
		usr << browse(os,"window=ungaos;border=1;can_close=1;can_resize=0;can_minimize=0;titlebar=1;size=500x500")
	else if(operatingsystem == "ungaOS 94")
		var/os = {"
				<!DOCTYPE html>
				<html>
				<head><title>Unga OS 94</title>[computer_browser_style]</head>
				<body>
				<center>[mainmenu]</center>
				<hr style="height:4px;border-width:0;color:gray;background-color:gray">
				[mainbody]
				</body>
				</html>
				"}
		usr << browse(os,"window=ungaos;border=1;can_close=1;can_resize=0;can_minimize=0;titlebar=1;size=800x600")
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

	var/mob/user = usr

	if (!user || user.lying || !ishuman(user))
		return

	user.face_atom(src)

	if (!locate(user) in range(1,src))
		user << "<span class = 'danger'>Get next to \the [src] to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE
	var/uname = "[lowertext(replacetext(user.real_name," ",""))]@monkeysoft.ug"
	if (href_list["deepnet"])
		mainbody = "<b>ERROR 404</b><br>Page not found."
	if (href_list["mail"])
		mainbody = "<h2>MONKEYSOFT E-MAIL SERVER</h2><br>"
		mainbody += "<b>Logged in as <i>[uname].</i></b><br>"
		mainbody += "<a href='?src=\ref[src];sendmail=1'>Send e-mail</a>&nbsp;<br><br>"
		if (islist(map.emails[uname]))
			for(var/datum/email/em in map.emails[uname])
				mainbody += "From: <i>[em.sender]</i><br>To: <i>[uname]</i><br><b>[em.subject]</b><br>[em.message]<br>"
				mainbody += "<br>"
	if (href_list["sendmail"])
		switch(href_list["sendmail"])
			if ("2")
				tmp_comp_vars["mail_rec"] = input(user, "Who to send the e-mail to?") as text
			if ("3")
				tmp_comp_vars["mail_subj"] = input(user, "What is the subject?") as text
			if ("4")
				tmp_comp_vars["mail_msg"] = input(user, "What is the message?") as message
		mainbody = "<h2>MONKEYSOFT E-MAIL SERVER</h2><br>"
		mainbody += "From: [uname]<br>To: <a href='?src=\ref[src];sendmail=2'>[tmp_comp_vars["mail_rec"]]</a><br>"
		mainbody += "Subject: <a href='?src=\ref[src];sendmail=3'>[tmp_comp_vars["mail_subj"]]</a><br>"
		mainbody += "Message: <a href='?src=\ref[src];sendmail=4'>[tmp_comp_vars["mail_msg"]]</a><br>"
		mainbody += "<a href='?src=\ref[src];mail_send=1'>Send</a><br>"
	if (href_list["mail_send"])
		var/datum/email/eml = new/datum/email
		eml.subject = tmp_comp_vars["mail_subj"]
		eml.sender = uname
		eml.receiver = tmp_comp_vars["mail_rec"]
		eml.message = tmp_comp_vars["mail_msg"]
		eml.date = roundduration2text()
		map.emails[uname] += list(eml)
		reset_tmp_vars()
		WWalert(user,"Mail sent successfully!","E-mail Sent")
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

/obj/structure/computer/proc/boot_ungos94()
	mainmenu = {"
	<i><h1>Unga OS 94</h1></i>
	<hr>
	<a href='?src=\ref[src];mail=1'>E-mail</a>&nbsp;<a href='?src=\ref[src];deepnet=1'>DEEPNET</a>
	"}
	mainbody = "System initialized."