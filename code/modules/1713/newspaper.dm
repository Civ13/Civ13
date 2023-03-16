/obj/item/weapon/newspaper
	name = "newspaper"
	desc = "An issue of a local Newspaper."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "newspaper"
	w_class = ITEM_SIZE_SMALL	//Let's make it fit in trashbags!
	attack_verb = list("bapped")
	var/screen = FALSE
	var/pages = FALSE
	var/curr_page = FALSE
	var/list/datum/feed_channel/news_content = list()
	var/datum/feed_message/important_message = null
	var/scribble=""
	var/scribble_page = null
	flammable = TRUE
	flags = FALSE
/obj/item/weapon/newspaper/attack_self(mob/user as mob)
	return ..(user)

/*	if (ishuman(user))
		var/mob/living/human/human_user = user
		var/dat
		pages = FALSE
		switch(screen)
			if (0) //Cover
				dat+="<DIV ALIGN='center'><b><FONT SIZE=6>The Local News</FONT></b></div>"
				dat+="<DIV ALIGN='center'><FONT SIZE=2>a standard newspaper, for reading about the local events</FONT></div><HR>"
				if (isemptylist(news_content))
					if (important_message)
						dat+="Contents:<BR><ul><b><FONT COLOR='red'>**</FONT>Important National Announcement<FONT COLOR='red'>**</FONT></b> <FONT SIZE=2>\[page [pages+2]\]</FONT><BR></ul>"
					else
						dat+="<I>Other than the title, the rest of the newspaper is unprinted...</I>"
				else
					dat+="Contents:<BR><ul>"
					for (var/datum/feed_channel/NP in news_content)
						pages++
					if (important_message)
						dat+="<b><FONT COLOR='red'>**</FONT>Important National Announcement<FONT COLOR='red'>**</FONT></b> <FONT SIZE=2>\[page [pages+2]\]</FONT><BR>"
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
					dat+="This article was deemed dangerous to the general welfare of the people and therefore marked with a <b><FONT COLOR='red'>D-Notice</b></FONT>. Its contents were not transferred to the newspaper at the time of printing."
				else
					if (isemptylist(C.messages))
						dat+="No Feed stories stem from this channel..."
					else
						dat+="<ul>"
						var/i = FALSE
						for (var/datum/feed_message/MESSAGE in C.messages)
							++i
							dat+="-[MESSAGE.body] <BR>"
							dat+="<FONT SIZE=1>\[[MESSAGE.message_type] by [MESSAGE.author]\]</FONT><BR><BR>"
						dat+="</ul>"
				if (scribble_page==curr_page)
					dat+="<BR><I>There is a small scribble near the end of this page... It reads: \"[scribble]\"</I>"
				dat+= "<BR><HR><DIV STYLE='float:left;'><A href='?src=\ref[src];prev_page=1'>Previous Page</A></DIV> <DIV STYLE='float:right;'><A href='?src=\ref[src];next_page=1'>Next Page</A></DIV>"
			if (2) //Last page
				for (var/datum/feed_channel/NP in news_content)
					pages++
				if (important_message!=null)
					dat+="<DIV STYLE='float:center;'><FONT SIZE=4><b>National Emergency:</b></FONT SIZE></DIV><BR><BR>"
					dat+="<b>Global tensions rise!</b><BR>"
					dat+="A new era is about to begin through the next conflict!<BR>"
				else if (important_message != null && ordinal_age = 7)
					dat+="<DIV STYLE='float:center;'><FONT SIZE=4><b>WAR IN VIETNAM!!:</b></FONT SIZE></DIV><BR><BR>"
					dat+="<b>Global tensions rise with the conflict in vietnam!</b><BR>"
					dat+="The questionable actions in communist support of the North Vietnamese Army has lead to increasing tensions between the United States of America and their old ally Russia. The outcome of the conflict is very questionable, however it's known that the cost will be much higher than the reward.<BR>"
				else if (important_message != null && ordinal_age = 6)
					dat+="<DIV STYLE='float:center;'><FONT SIZE=4><b>WAR IN EUROPE!!:</b></FONT SIZE></DIV><BR><BR>"
					dat+="<b>Global tensions rise with the global conflict in europe!</b><BR>"
					dat+="The Communist Red Army is beginning a counter attack against the germans and pushing them back out of occupied territories! After the german blitzkrieg was stopped at Moscow and had a devestating loss at Stalingrad, the germans are being pushed back out of russia. With the current pace, the war may be over in a year!.<BR>"
				else if (important_message != null && ordinal_age = 5)
					dat+="<DIV STYLE='float:center;'><FONT SIZE=4><b>THE WAR IS OVER!!:</b></FONT SIZE></DIV><BR><BR>"
					dat+="<b>The war between Russia and Japan is over!</b><BR>"
					dat+="The war resulted in a Japanese victory, althought losses are high and the russian's won't have to pay repairations due to President Roosevelt's mediating of the surrender negotiations. With the signing of the Treaty of Portsmouth on September 5th, 1905. The just cause fought hard with many losses by the japanese has now ended in their victory, the first time an asian power has ever defeated a european power. Japan's future is uncertain, will they continue to expand? Or hold what they have?.<BR>"
				else
					dat+="<I>Apart from some uninteresting ads, there's nothing on this page...</I>"
				if (scribble_page==curr_page)
					dat+="<BR><I>There is a small scribble near the end of this page... It reads: \"[scribble]\"</I>"
				dat+= "<HR><DIV STYLE='float:left;'><A href='?src=\ref[src];prev_page=1'>Previous Page</A></DIV>"
			else
				dat+="I'm sorry to break your immersion. This shit's bugged. Report this bug to shinobi"

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
			var/s = sanitize(input(user, "Write something", "Newspaper", ""))
			s = sanitize(s)
			if (!s)
				return
			if (!in_range(src, usr) && loc != usr)
				return
			scribble_page = curr_page
			scribble = s
			attack_self(user)
		return