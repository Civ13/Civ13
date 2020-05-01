/*
AWARDS:
"wounded" = receive 50 damage
"wounded silver" = receive 100 damage
"wounded gold" = receive 150 damage
"long service" = survive for 20 minutes
"tank destroyer silver" = destroy 2 tank
"tank destroyer gold" = destroy 4 tanks
"assault badge" = deal > 100 damage to 2 enemies
"iron cross 2nd class" = deal > 100 damage to 5 enemies
"iron cross 1st class" = deal > 100 damage to 8 enemies
*/

/mob/living/carbon/human
	var/list/awards = list(list("wounded"=0,"service"=0,"tank"=0,"kills"=list("",0,0)), "kill_count"=0)
	var/list/awarded = list()
/mob/living/carbon/human/proc/process_awards()
	if (!client)
		return FALSE
	if (map.gamemode == "Hardcore")
		if (map.ordinal_age>=5)
			awards["service"]++
			if (awards["service"]>=12000 && client && !("long service" in awarded))
				map.give_award(client.ckey, name, "long service", capitalize(faction_text),src)

			if (awards["tank"]>=2 && !("tank destroyer silver" in awarded))
				map.give_award(client.ckey, name, "tank destroyer silver", capitalize(faction_text),src)
			else if (awards["tank"]>=4 && !("tank destroyer gold" in awarded))
				map.give_award(client.ckey, name, "tank destroyer gold", capitalize(faction_text),src)

			if (awards["wounded"]>=150 && !("wounded gold" in awarded))
				map.give_award(client.ckey, name, "wounded gold", capitalize(faction_text),src)
				map.remove_award(client.ckey, name, "wounded silver", capitalize(faction_text),src)
				map.remove_award(client.ckey, name, "wounded", capitalize(faction_text))
			else if (awards["wounded"]>=100 && !("wounded silver" in awarded))
				map.give_award(client.ckey, name, "wounded silver", capitalize(faction_text),src)
				map.remove_award(client.ckey, name, "wounded", capitalize(faction_text))
			else if (awards["wounded"]>=50 && !("wounded" in awarded))
				map.give_award(client.ckey, name,"wounded", capitalize(faction_text),src)

			for(var/list/i in awards["kills"])
				if (islist(i) && i[1] != "" && i[2] >= 100 && i[3]==0)
					i[3]=1
					awards["kill_count"]++
			if (awards["kill_count"]>= 8 && !("iron cross 1st class" in awarded))
				map.give_award(client.ckey, name,"iron cross 1st class", capitalize(faction_text),src)
				map.remove_award(client.ckey, name, "iron cross 2nd class", capitalize(faction_text))
			else if (awards["kill_count"]>= 5 && !("iron cross 2nd class" in awarded))
				map.give_award(client.ckey, name,"iron cross 2nd class", capitalize(faction_text),src)
			else if (awards["kill_count"]>= 2 && !("assault badge" in awarded))
				map.give_award(client.ckey, name,"assault badge", capitalize(faction_text),src)
			return TRUE
	return FALSE
/obj/map_metadata/proc/save_awards()
	var/F = file("SQL/awards.txt")
	if (!awards.len)
		return
	if (fexists(F))
		fcopy("SQL/awards.txt","SQL/awards_backup.txt")
		fdel(F)
	for (var/i = 1, i <= awards.len, i++)
		var/txtexport = list2text(awards[i])
		text2file(txtexport,F)
	return TRUE

/obj/map_metadata/proc/give_award(var/_ckey, var/charname, var/awardtype, var/faction, var/mob/living/carbon/human/L = null)
	//ckey,charname,award,faction,map,date
	var/parsed_title = splittext(title, " (")
	awards += list(list(_ckey,charname,awardtype,faction,parsed_title[1],time2text(world.realtime, "YYYY/MM-Month/DD-Day")))
	if (L)
		L << "<font size=3 color='yellow'>You have received a [awardtype] medal!</font>"
	if (!(awardtype in L.awarded))
		L.awarded += list(awardtype)
	return

/obj/map_metadata/proc/remove_award(var/_ckey, var/charname, var/awardtype, var/faction)
	for (var/list/i in awards)
		if (i[1] == _ckey && i[2] == charname && i[3] == awardtype && i[4] == faction)
			awards -= i
	return
