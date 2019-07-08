/obj/structure/noticeboard
	name = "notice board"
	desc = "A board for pinning important notices upon."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard00"
	density = FALSE
	anchored = TRUE
	var/notices = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/noticeboard/initialize()
	for (var/obj/item/I in loc)
		if (notices > 4) break
		if (istype(I, /obj/item/weapon/paper))
			I.loc = src
			notices++
	icon_state = "nboard0[notices]"

//attaching papers!!
/obj/structure/noticeboard/attackby(var/obj/item/weapon/O as obj, var/mob/user as mob)
	if (istype(O, /obj/item/weapon/paper))
		if (notices < 5)
			O.add_fingerprint(user)
			add_fingerprint(user)
			user.drop_from_inventory(O)
			O.loc = src
			notices++
			icon_state = "nboard0[notices]"	//update sprite
			user << "<span class='notice'>You pin the paper to the noticeboard.</span>"
		else
			user << "<span class='notice'>You reach to pin your paper to the board but hesitate. You are certain your paper will not be seen among the many others already attached.</span>"

/obj/structure/noticeboard/attack_hand(var/mob/user)
	examine(user)

// Since Topic() never seems to interact with usr on more than a superficial
// level, it should be fine to let anyone mess with the board other than ghosts.
/obj/structure/noticeboard/examine(var/mob/user)
	if (!user)
		user = usr
	if (user.Adjacent(src))
		var/dat = "<b>Noticeboard</b><BR>"
		for (var/obj/item/weapon/paper/P in src)
			dat += "<A href='?src=\ref[src];read=\ref[P]'>[P.name]</A> <A href='?src=\ref[src];write=\ref[P]'>Write</A> <A href='?src=\ref[src];remove=\ref[P]'>Remove</A><BR>"
		user << browse("<HEAD><TITLE>Notices</TITLE></HEAD>[dat]","window=noticeboard")
		onclose(user, "noticeboard")
	else
		..()

/obj/structure/noticeboard/Topic(href, href_list)
	..()
	usr.set_using_object(src)
	if (href_list["remove"])
		if ((usr.stat || usr.restrained()))	//For when a player is handcuffed while they have the notice window open
			return
		var/obj/item/P = locate(href_list["remove"])
		if (P && P.loc == src)
			P.loc = get_turf(src)	//dump paper on the floor because you're a clumsy fuck
			P.add_fingerprint(usr)
			add_fingerprint(usr)
			notices--
			icon_state = "nboard0[notices]"
	if (href_list["write"])
		if ((usr.stat || usr.restrained())) //For when a player is handcuffed while they have the notice window open
			return
		var/obj/item/P = locate(href_list["write"])
		if ((P && P.loc == src)) //ifthe paper's on the board
			if (istype(usr.r_hand, /obj/item/weapon/pen)) //and you're holding a pen
				add_fingerprint(usr)
				P.attackby(usr.r_hand, usr) //then do ittttt
			else
				if (istype(usr.l_hand, /obj/item/weapon/pen)) //check other hand for pen
					add_fingerprint(usr)
					P.attackby(usr.l_hand, usr)
				else
					usr << "<span class='notice'>You'll need something to write with!</span>"
	if (href_list["read"])
		var/obj/item/weapon/paper/P = locate(href_list["read"])
		if ((P && P.loc == src))
			usr << browse("<HTML><HEAD><TITLE>[P.name]</TITLE></HEAD><BODY><TT>[P.info]</TT></BODY></HTML>", "window=[P.name]")
			onclose(usr, "[P.name]")
	return
////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////MAIL//SYSTEM/////////////////////////////////
/obj/structure/mailbox
	name = "mail bag"
	desc = "A bag of mail, to be distributed to other colonial administrations."
	icon = 'icons/obj/storage.dmi'
	icon_state = "mailbag"
	density = FALSE
	anchored = TRUE
	var/faction = FALSE
	var/receive_only = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/mailbox/processor
	invisibility = 101

/obj/structure/mailbox/received
	name = "received mail bag"
	desc = "A bag of mail, with received objects from other colonies."
	icon = 'icons/obj/storage.dmi'
	icon_state = "mailbag"
	density = FALSE
	anchored = TRUE
	receive_only = TRUE

/obj/structure/mailbox/spanish
	name = "Spanish mail bag"
	desc = "A bag of mail, to be delivered to the Spanish colonial administration."
	faction = "spanish"

/obj/structure/mailbox/dutch
	name = "Dutch mail bag"
	desc = "A bag of mail, to be delivered to the Dutch colonial administration."
	faction = "dutch"

/obj/structure/mailbox/portuguese
	name = "Portuguese mail bag"
	desc = "A bag of mail, to be delivered to the Dutch colonial administration."
	faction = "portuguese"

/obj/structure/mailbox/french
	name = "French mail bag"
	desc = "A bag of mail, to be delivered to the French colonial administration."
	faction = "french"

/obj/structure/mailbox/british
	name = "British mail bag"
	desc = "A bag of mail, to be delivered to the British colonial administration."
	faction = "british"

/obj/structure/mailbox/attackby(var/obj/item/weapon/paper/W as obj, var/mob/living/carbon/human/H as mob)
	if (receive_only == TRUE)
		H << "This is only for received letters! It wont be delivered if you put it here!"
		return
	else
		if (istype(W, /obj/item/weapon/paper))
			for (var/obj/structure/mailbox/received/B)
				if (B.faction == faction)
					var/obj/item/weapon/paper/NP = new/obj/item/weapon/paper(B.loc)

					if(W.info)
						NP.info = W.info
					if(W.name)
						NP.name = W.name
					if(W.stamps)
						NP.stamps = W.stamps
					if(W.fields)
						NP.fields = W.fields
					if(W.stamped)
						NP.stamped = W.stamped
					if(W.ico)
						NP.ico = W.ico
					qdel(W)
					H << "Your message has been sent and will be delivered soon."
			return
		else
			H << "You cannot send this by mail. Only paper is accepted."
			return

	..()

/obj/structure/gladiator_ledger
	name = "gladiatorial ledger"
	desc = "A board showing the victories of all gladiators."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard00"
	density = FALSE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/arena_name = "Arena I"
	var/timer = 0
/obj/structure/gladiator_ledger/attack_hand(mob/user as mob)
	if (map.ID == MAP_GLADIATORS)
		var/obj/map_metadata/gladiators/GD = map
		if (istype(user, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = user
			if (H.original_job == "Imperator" && timer <= world.time)
				var/vlist = list("Cancel")
				var/area/A = get_area_name("[arena_name]")
				if (!A)
					return
				for(var/mob/living/carbon/human/GLAD in A)
					if (GLAD.original_job == "Gladiator" && GLAD.stat != DEAD && GLAD.client)
						vlist += "[GLAD.name], [GLAD.client.ckey]"
				var/choice = WWinput(H, "Who to assign a victory point to?", "Match Results", "Cancel", vlist)
				if (choice == "Cancel")
					var/list/toplist = list()
					for (var/i = 1, i <= GD.gladiator_stats.len, i++)
						toplist += list(list(GD.gladiator_stats[i][1], GD.gladiator_stats[i][2], GD.gladiator_stats[i][4], GD.gladiator_stats[i][5]))

					var/body = "<html><head><title>GLADIATORIAL LEDGER</title></head><b>GLADIATORIAL LEDGER</b><br><br>"
					for (var/i = 1, i <= toplist.len, i++)
						if (toplist[i][4]>0)
							if (toplist[i][3] == 0)
								body += "<b>[toplist[i][2]]</b> ([toplist[i][1]])</b>: [toplist[i][4]] victories.</br>"
							else
								body += "<b>[toplist[i][2]]</b> ([toplist[i][1]]) <font color='red'><i>DECEASED</i></font>: [toplist[i][4]] victories.</br>"
					body += {"<br>
						</body></html>
					"}

					usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
				else
					var/list/splitdata = splittext(choice, ", ")
					var/done = FALSE
					for (var/i = 1, i <= GD.gladiator_stats.len, i++)
						if (GD.gladiator_stats[i][1] == splitdata[1] && GD.gladiator_stats[i][2] == splitdata[2] && GD.gladiator_stats[i][4] == 0)
							GD.gladiator_stats[i][5]++
							done = TRUE
							continue
					if (!done)
						GD.gladiator_stats += list(list(splitdata[1],splitdata[2],"0,0,0,0,0,0,0,0,0,0",0,1))
					timer = world.time + 600
			else
				var/list/toplist = list()
				for (var/i = 1, i <= GD.gladiator_stats.len, i++)
					toplist += list(list(GD.gladiator_stats[i][1], GD.gladiator_stats[i][2], GD.gladiator_stats[i][4], GD.gladiator_stats[i][5]))

				var/body = "<html><head><title>GLADIATORIAL LEDGER</title></head><b>GLADIATORIAL LEDGER</b><br><br>"
				for (var/i = 1, i <= toplist.len, i++)
					if (toplist[i][4]>0)
						if (toplist[i][3] == 0)
							body += "<b>[toplist[i][2]]</b> ([toplist[i][1]])</b>: [toplist[i][4]] victories.</br>"
						else
							body += "<b>[toplist[i][2]]</b> ([toplist[i][1]]) <font color='red'><i>DECEASED</i></font>: [toplist[i][4]] victories.</br>"
				body += {"<br>
					</body></html>
				"}

				usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
		else
			var/list/toplist = list()
			for (var/i = 1, i <= GD.gladiator_stats.len, i++)
				toplist += list(list(GD.gladiator_stats[i][1], GD.gladiator_stats[i][2], GD.gladiator_stats[i][4], GD.gladiator_stats[i][5]))

			var/body = "<html><head><title>GLADIATORIAL LEDGER</title></head><b>GLADIATORIAL LEDGER</b><br><br>"
			for (var/i = 1, i <= toplist.len, i++)
				if (toplist[i][4]>0)
					if (toplist[i][3] == 0)
						body += "<b>[toplist[i][2]]</b> ([toplist[i][1]])</b>: [toplist[i][4]] victories.</br>"
					else
						body += "<b>[toplist[i][2]]</b> ([toplist[i][1]]) <font color='red'><i>DECEASED</i></font>: [toplist[i][4]] victories.</br>"
			body += {"<br>
				</body></html>
			"}

			usr << browse(body,"window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
	else
		return