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
				<head>[computer_browser_style]<title>Unga OS 94</title></head>
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
	var/mdomain = "monkeysoft.ug"
	switch(user.civilization)
		if ("Rednikov Industries")
			mdomain = "rednikov.ug"
		if ("Giovanni Blu Stocks")
			mdomain = "blu.ug"

		if ("MacGreene Traders")
			mdomain = "greene.ug"

		if ("Goldstein Solutions")
			mdomain = "goldstein.ug"

	var/uname = "[lowertext(replacetext(user.real_name," ",""))]@[mdomain]"
	var/cname = "mail@[mdomain]"
	if (tmp_comp_vars["mail_snd"]=="Sender")
		tmp_comp_vars["mail_snd"] = uname
	if (href_list["mail"])
		mainbody = "<h2>MONKEYSOFT E-MAIL SERVER</h2><br>"
		mainbody += "<b>Logged in as <i>[uname]</i></b><br>"
		mainbody += "<a href='?src=\ref[src];sendmail=1'>Send e-mail</a>&nbsp;<a href='?src=\ref[src];mail=99999'>Inbox</a><hr><br>"
		if (href_list["mail"]=="99999")
			if (islist(map.emails[uname]))
				for(var/i, i <= map.emails[uname].len, i++)
					if (istype(map.emails[uname][i], /datum/email))
						var/datum/email/em =  map.emails[uname][i]
						mainbody += "<a href='?src=\ref[src];mail=[i]'>[em.date] ([em.sender]): <b>[em.subject]</b></a>"
			if (islist(map.emails[cname]))
				for(var/i, i <= map.emails[cname].len, i++)
					if (istype(map.emails[cname][i], /datum/email))
						var/datum/email/em =  map.emails[cname][i]
						mainbody += "<a href='?src=\ref[src];mail=c[i]'>[em.date] ([em.sender]): <b>[em.subject]</b></a>"

		else
			if (findtext(href_list["mail"],"c"))
				var/tcode = text2num(replacetext(href_list["mail"],"c",""))
				var/datum/email/chosen = map.emails[cname][tcode]
				mainbody += "---<br>From: <i>[chosen.sender]</i><br>To: <i>[chosen.receiver]</i><br><i>Received at [chosen.date]</i><br>---<br><b>[chosen.subject]</b><br>[chosen.message]<br>"
				mainbody += "<br>"
			else
				var/datum/email/chosen = map.emails[uname][text2num(href_list["mail"])]
				mainbody += "---<br>From: <i>[chosen.sender]</i><br>To: <i>[chosen.receiver]</i><br><i>Received at [chosen.date]</i><br>---<br><b>[chosen.subject]</b><br>[chosen.message]<br>"
				mainbody += "<br>"
	if (href_list["sendmail"])
		switch(href_list["sendmail"])
			if ("2")
				tmp_comp_vars["mail_rec"] = input(user, "Who to send the e-mail to?") as text
			if ("3")
				tmp_comp_vars["mail_subj"] = input(user, "What is the subject?") as text
			if ("4")
				tmp_comp_vars["mail_msg"] = input(user, "What is the message?") as message
			if ("5")
				tmp_comp_vars["mail_snd"] = WWinput(user, "Send from which e-mail account?","e-mail",tmp_comp_vars["mail_snd"],list(uname,cname))
			
		mainbody = "<h2>MONKEYSOFT E-MAIL SERVER</h2><br>"
		mainbody += "<b>Logged in as <i>[uname]</i></b><br>"
		mainbody += "<a href='?src=\ref[src];sendmail=1'>Send e-mail</a>&nbsp;<a href='?src=\ref[src];mail=99999'>Inbox</a><br><br>"
		mainbody += "From: <a href='?src=\ref[src];sendmail=5'>[tmp_comp_vars["mail_snd"]]</a><br>To: <a href='?src=\ref[src];sendmail=2'>[tmp_comp_vars["mail_rec"]]</a><br>"
		mainbody += "Subject: <a href='?src=\ref[src];sendmail=3'>[tmp_comp_vars["mail_subj"]]</a><br>"
		mainbody += "Message: <a href='?src=\ref[src];sendmail=4'>[tmp_comp_vars["mail_msg"]]</a><br>"
		mainbody += "<a href='?src=\ref[src];mail_send=1'>Send</a><br>"
	if (href_list["mail_send"])
		var/datum/email/eml = new/datum/email
		eml.subject = tmp_comp_vars["mail_subj"]
		eml.sender = tmp_comp_vars["mail_snd"]
		eml.receiver = tmp_comp_vars["mail_rec"]
		eml.message = tmp_comp_vars["mail_msg"]
		eml.date = roundduration2text()
		map.emails[uname] += list(eml)
		reset_tmp_vars()
		WWalert(user,"Mail sent successfully!","E-mail Sent")
//DEEPNET
	if (href_list["deepnet"])
		mainbody = "<h2>D.E.E.P.N.E.T.</h2><br>"
		mainbody += "<b>All deliveries in a maximum of 2 minutes!</i></b><br>"
		mainbody += "<a href='?src=\ref[src];deepnet=2'>Buy</a>&nbsp;<a href='?src=\ref[src];deepnet=3'>Sell</a>&nbsp;<a href='?src=\ref[src];deepnet=4'>Account</a><hr><br>"
		if (findtext(href_list["deepnet"],"b"))
			var/tcode = replacetext(href_list["deepnet"],"b","")
			var/cost = (map.globalmarketplace[tcode][4])
			if (!istype(user.l_hand, /obj/item/stack/money) && !istype(user.r_hand, /obj/item/stack/money))
				mainbody += "<b>You need to have money in one of your hands!</b>"
			else
				var/obj/item/stack/money/mstack = null
				if (istype(user.l_hand, /obj/item/stack/money))
					mstack = user.l_hand
				else
					mstack = user.r_hand
				if (mstack.value*mstack.amount >= cost)
					mstack.amount -= (cost/mstack.value)
					if (mstack.amount<= 0)
						qdel(mstack)
					var/obj/BO = map.globalmarketplace[tcode][2]
					if (BO)
						BO.forceMove(get_turf(src))
					map.globalmarketplace[tcode][7] = 0
					mainbody += "You fulfill the order."
					var/seller = map.globalmarketplace[tcode][1]
					map.marketplaceaccounts[seller] += cost
					map.globalmarketplace -= map.globalmarketplace[tcode]
				else
					mainbody += "<b>Not enough money!</b>"

		if (findtext(href_list["deepnet"],"ch"))
			var/tcode = replacetext(href_list["deepnet"],"ch","")
			var/cost = (map.globalmarketplace[tcode][4])
			var/newprice = input(user, "What shall the new price be, in dollars?","DEEPNET",cost/4) as num|null
			if (!isnum(newprice))
				return
			if (newprice <= 0)
				return
			map.globalmarketplace[tcode][4] = newprice*4
			mainbody += "You update the listing's price."
			return
		if (findtext(href_list["deepnet"],"cn"))
			var/tcode = replacetext(href_list["deepnet"],"cn","")
			var/obj/BO = map.globalmarketplace[tcode][2]
			BO.forceMove(get_turf(src))
			map.globalmarketplace[tcode][7] = 0
			map.globalmarketplace -= map.globalmarketplace[tcode]
			mainbody += "You cancel your sell order and get your items back."
			return
		switch(href_list["deepnet"])
			if ("2") //buy
				var/list/currlist = list()
				for (var/i in map.globalmarketplace)
					if (map.globalmarketplace[i][7]==1)
						currlist += list(list(map.globalmarketplace[i][6],"[istype(map.globalmarketplace[i][2],/obj/item/stack) ? "[map.globalmarketplace[i][3]] of " : ""] <b>[map.globalmarketplace[i][2]]</b>, for [map.globalmarketplace[i][4]/4] dollars (<i>by [map.globalmarketplace[i][1]]</i>)"))
				if (isemptylist(currlist))
					mainbody += "<b>There are no orders on the DEEPNET!</b>"
				for (var/list/k in currlist)
					mainbody += "<a href='?src=\ref[src];deepnet=b[k[1]]'>[k[2]]</a>"
			if ("3","6","7","8") //sell
				mainbody += "<a href='?src=\ref[src];deepnet=6'>Add New</a>&nbsp;<a href='?src=\ref[src];deepnet=7'>Change</a>&nbsp;<a href='?src=\ref[src];deepnet=8'>Cancel</a><br><br>"
				if (href_list["deepnet"] == "6") //add
					var/obj/item/M = user.get_active_hand()
					if (M && istype(M))
						if (istype(M, /obj/item/stack))
							var/obj/item/stack/ST = M
							if (ST.amount <= 0)
								return
							else
								var/price = input(user, "What price do you want to place the [ST.amount] [ST] for sale in the DEEPNET? (in dollars) 0 to cancel.") as num|null
								if (!isnum(price))
									return
								if (price <= 0)
									return
								else
									//owner, object, amount, price, sale/buy, fulfilled
									var/idx = rand(1,999999)
									map.globalmarketplace += list("[idx]" = list(user.civilization,ST,ST.amount,price*4,"sale","[idx]",1))
									user.drop_from_inventory(ST)
									ST.forceMove(locate(0,0,0))
									mainbody += "You place \the [ST] for sale in the <b>DEEPNET</b>."
									return
						else
							var/price = input(user, "What price do you want to place the [M] for sale in the DEEPNET? (in dollars).") as num|null
							if (!isnum(price))
								return
							if (price <= 0)
								return
							else
								//owner, object, amount, price, sale/buy, id number, fulfilled
								var/idx = rand(1,999999)
								map.globalmarketplace += list("[idx]" = list(user.civilization,M,1,price*4,"sale","[idx]",1))
								user.drop_from_inventory(M)
								M.forceMove(locate(0,0,0))
								mainbody += "You place \the [M] for sale in the <b>DEEPNET</b>."
								return
					else
						WWalert(user,"Failed to create the order! You need to have the item in your active hand.","DEEPNET")
				if (href_list["deepnet"] == "7") //change
					var/list/currlist = list()
					for (var/i in map.globalmarketplace)
						if (map.globalmarketplace[i][1] == user.civilization)
							currlist += list(list(map.globalmarketplace[i][6],"[istype(map.globalmarketplace[i][2],/obj/item/stack) ? "[map.globalmarketplace[i][3]] of " : ""] <b>[map.globalmarketplace[i][2]]</b>, for [map.globalmarketplace[i][4]/4] dollars (<i>by [map.globalmarketplace[i][1]]</i>)"))
					if (isemptylist(currlist))
						mainbody += "You have no orders on the market!"
						return
					for (var/list/k in currlist)
						mainbody += "<a href='?src=\ref[src];deepnet=ch[k[1]]'>[k[2]]</a>"
				if (href_list["deepnet"] == "8") //cancel
					var/list/currlist = list()
					for (var/i in map.globalmarketplace)
						if (map.globalmarketplace[i][1] == user.civilization)
							currlist += list(list(map.globalmarketplace[i][6],"[istype(map.globalmarketplace[i][2],/obj/item/stack) ? "[map.globalmarketplace[i][3]] of " : ""] <b>[map.globalmarketplace[i][2]]</b>, for [map.globalmarketplace[i][4]/4] dollars (<i>by [map.globalmarketplace[i][1]]</i>)"))
					if (isemptylist(currlist))
						mainbody += "You have no orders on the market!"
						return
					for (var/list/k in currlist)
						mainbody += "<a href='?src=\ref[src];deepnet=cn[k[1]]'>[k[2]]</a>"

			if ("4") //account
				mainbody += "<big>Account: <b>[user.civilization]</b></big><br><br>"
				var/accmoney = map.marketplaceaccounts[user.civilization]
				if (map.marketplaceaccounts[user.civilization])
					if (accmoney <= 0)
						mainbody += "<b>Your account is empty!</b>"
						map.marketplaceaccounts[user.civilization] = 0
					else
						mainbody += "You have [accmoney/4] dollars in your company's account.<br>"
						mainbody += "<a href='?src=\ref[src];deepnet=5'>Withdraw</a>"
				else
					mainbody += "<b>Your account is empty!</b>"
			if ("5") //withdraw
				var/accmoney = map.marketplaceaccounts[user.civilization]
				if (accmoney > 0)
					var/obj/item/stack/money/dollar/SC = new /obj/item/stack/money/dollar(get_turf(src))
					SC.amount = accmoney/20
					accmoney = 0
					map.marketplaceaccounts[user.civilization] = 0
					do_html()
/*
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
*/
	sleep(0.5)
	do_html(user)

/obj/structure/computer/proc/boot_ungos94()
	mainmenu = {"
	<i><h1><img src='uos94.png'></img></h1></i>
	<hr>
	<a href='?src=\ref[src];mail=99999'>E-mail</a>&nbsp;<a href='?src=\ref[src];deepnet=1'>DEEPNET</a>
	"}
	mainbody = "System initialized."