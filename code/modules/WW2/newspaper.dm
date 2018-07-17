/obj/item/weapon/newspaper
	name = "newspaper"
	desc = "An issue of The Griffon, the newspaper circulating aboard most stations."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "newspaper"
	w_class = 2	//Let's make it fit in trashbags!
	attack_verb = list("bapped")
	var/screen = FALSE
	var/pages = FALSE
	var/curr_page = FALSE
	var/list/datum/feed_channel/news_content = list()
	var/datum/feed_message/important_message = null
	var/scribble=""
	var/scribble_page = null

/obj/item/weapon/newspaper/attack_self(mob/user as mob)
	return ..(user)
	/*if (ishuman(user))
		var/mob/living/carbon/human/human_user = user
		var/dat
		pages = FALSE
		switch(screen)
			if (0) //Cover
				dat+="<DIV ALIGN='center'><b><FONT SIZE=6>The Griffon</FONT></b></div>"
				dat+="<DIV ALIGN='center'><FONT SIZE=2>[company_name]-standard newspaper, for use on [company_name]© Space Facilities</FONT></div><HR>"
				if (isemptylist(news_content))
					if (important_message)
						dat+="Contents:<BR><ul><b><FONT COLOR='red'>**</FONT>Important Security Announcement<FONT COLOR='red'>**</FONT></b> <FONT SIZE=2>\[page [pages+2]\]</FONT><BR></ul>"
					else
						dat+="<I>Other than the title, the rest of the newspaper is unprinted...</I>"
				else
					dat+="Contents:<BR><ul>"
					for (var/datum/feed_channel/NP in news_content)
						pages++
					if (important_message)
						dat+="<b><FONT COLOR='red'>**</FONT>Important Security Announcement<FONT COLOR='red'>**</FONT></b> <FONT SIZE=2>\[page [pages+2]\]</FONT><BR>"
					var/temp_page=0
					for (var/datum/feed_channel/NP in news_content)
						temp_page++
						dat+="<b>[NP.channel_name]</b> <FONT SIZE=2>\[page [temp_page+1]\]</FONT><BR>"
					dat+="</ul>"
				if (scribble_page==curr_page)
					dat+="<BR><I>There is a small scribble near the end of this page... It reads: \"[scribble]\"</I>"
				dat+= "<HR><DIV STYLE='float:right;'><A href='?src=\ref[src];next_page=1'>Next Page</A></DIV> <div style='float:left;'><A href='?src=\ref[human_user];mach_close=newspaper_main'>Done reading</A></DIV>"
			if (1) // X channel pages inbetween.
				for (var/datum/feed_channel/NP in news_content)
					pages++ //Let's get it right again.
				var/datum/feed_channel/C = news_content[curr_page]
				dat+="<FONT SIZE=4><b>[C.channel_name]</b></FONT><FONT SIZE=1> \[created by: <FONT COLOR='maroon'>[C.author]</FONT>\]</FONT><BR><BR>"
				if (C.censored)
					dat+="This channel was deemed dangerous to the general welfare of the station and therefore marked with a <b><FONT COLOR='red'>D-Notice</b></FONT>. Its contents were not transferred to the newspaper at the time of printing."
				else
					if (isemptylist(C.messages))
						dat+="No Feed stories stem from this channel..."
					else
						dat+="<ul>"
						var/i = FALSE
						for (var/datum/feed_message/MESSAGE in C.messages)
							++i
							dat+="-[MESSAGE.body] <BR>"
							if (MESSAGE.img)
								var/resourc_name = "newscaster_photo_[sanitize(C.channel_name)]_[i].png"
								send_asset(user.client, resourc_name)
								dat+="<img src='[resourc_name]' width = '180'><BR>"
							dat+="<FONT SIZE=1>\[[MESSAGE.message_type] by <FONT COLOR='maroon'>[MESSAGE.author]</FONT>\]</FONT><BR><BR>"
						dat+="</ul>"
				if (scribble_page==curr_page)
					dat+="<BR><I>There is a small scribble near the end of this page... It reads: \"[scribble]\"</I>"
				dat+= "<BR><HR><DIV STYLE='float:left;'><A href='?src=\ref[src];prev_page=1'>Previous Page</A></DIV> <DIV STYLE='float:right;'><A href='?src=\ref[src];next_page=1'>Next Page</A></DIV>"
			if (2) //Last page
				for (var/datum/feed_channel/NP in news_content)
					pages++
				if (important_message!=null)
					dat+="<DIV STYLE='float:center;'><FONT SIZE=4><b>Wanted Issue:</b></FONT SIZE></DIV><BR><BR>"
					dat+="<b>Criminal name</b>: <FONT COLOR='maroon'>[important_message.author]</FONT><BR>"
					dat+="<b>Description</b>: [important_message.body]<BR>"
					dat+="<b>Photo:</b>: "
					if (important_message.img)
						user << browse_rsc(important_message.img, "tmp_photow.png")
						dat+="<BR><img src='tmp_photow.png' width = '180'>"
					else
						dat+="None"
				else
					dat+="<I>Apart from some uninteresting Classified ads, there's nothing on this page...</I>"
				if (scribble_page==curr_page)
					dat+="<BR><I>There is a small scribble near the end of this page... It reads: \"[scribble]\"</I>"
				dat+= "<HR><DIV STYLE='float:left;'><A href='?src=\ref[src];prev_page=1'>Previous Page</A></DIV>"
			else
				dat+="I'm sorry to break your immersion. This shit's bugged. Report this bug to Agouri, polyxenitopalidou@gmail.com"

		dat+="<BR><HR><div align='center'>[curr_page+1]</div>"
		human_user << browse(dat, "window=newspaper_main;size=300x400")
		onclose(human_user, "newspaper_main")
	else
		user << "The paper is full of intelligible symbols!"

*/
/obj/item/weapon/newspaper/Topic(href, href_list)
	var/mob/living/U = usr
	..()
	if ((src in U.contents) || ( istype(loc, /turf) && in_range(src, U) ))
		U.set_using_object(src)
		if (href_list["next_page"])
			if (curr_page==pages+1)
				return //Don't need that at all, but anyway.
			if (curr_page == pages) //We're at the middle, get to the end
				screen = 2
			else
				if (curr_page == FALSE) //We're at the start, get to the middle
					screen=1
			curr_page++
			playsound(loc, "pageturn", 50, TRUE)

		else if (href_list["prev_page"])
			if (curr_page == FALSE)
				return
			if (curr_page == TRUE)
				screen = FALSE

			else
				if (curr_page == pages+1) //we're at the end, let's go back to the middle.
					screen = TRUE
			curr_page--
			playsound(loc, "pageturn", 50, TRUE)

		if (istype(loc, /mob))
			attack_self(loc)


obj/item/weapon/newspaper/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/pen))
		if (scribble_page == curr_page)
			user << "<span class = 'notice'>There's already a scribble in this page... You wouldn't want to make things too cluttered, would you?</span>"
		else
			var/s = cp1251_to_utf8(sanitize(input(user, "Write something", "Newspaper", "")))
			s = sanitize(s)
			if (!s)
				return
			if (!in_range(src, usr) && loc != usr)
				return
			scribble_page = curr_page
			scribble = s
			attack_self(user)
		return
