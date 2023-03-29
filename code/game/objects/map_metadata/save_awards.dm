/*
AWARDS:
"wounded" = receive 100 damage
"wounded silver" = receive 150 damage
"wounded gold" = receive 250 damage
"long service" = survive for 20 minutes
"tank destroyer silver" = destroy 2 tanks
"tank destroyer gold" = destroy 4 tanks
"assault badge" = deal > 100 damage to 2 different enemies
"iron cross 2nd class" = deal > 100 damage to 5 different enemies
"iron cross 1st class" = deal > 100 damage to 8 different enemies
*/

/mob/living/human
	var/list/awards = list("medic"=0,"wounded"=0,"service"=0,"tank"=0,"kills"=list("",0,0), "kill_count"=0)
	var/list/awarded = list()
/mob/living/human/proc/process_awards()
	if (!client)
		return FALSE
	if (map.ID == MAP_ALLEYWAY && stat != DEAD)
		if (original_job && (original_job.title == "Yama Wakagashira" || original_job.title ==  "Ichi Wakagashira"))
			awards["service"]++
			if (awards["service"]>=60)
				if (original_job && original_job.title == "Yama Wakagashira")
					map.scores["Yamaguchi-Gumi"] += 1
					awards["service"]=0
				else if (original_job && original_job.title == "Ichi Wakagashira")
					map.scores["Ichiwa-Kai"] += 1
					awards["service"]=0
	if (map.ID == MAP_SEKIGAHARA && stat != DEAD)
		if (original_job && (original_job.title == "Azuma no Daimyo" || original_job.title ==  "Sei no Daimyo"))
			awards["service"]++
			if (awards["service"]>=60)
				if (original_job && original_job.title == "Azuma no Daimyo")
					map.scores["Eastern Army"] += 1
					awards["service"]=0
				else if (original_job && original_job.title == "Sei no Daimyo")
					map.scores["Western Army"] += 1
					awards["service"]=0

	if (map.gamemode == "Hardcore")
		if (map.ID == MAP_BANK_ROBBERY || map.ID == MAP_DRUG_BUST) //Prevents farming medals until a medal for arrests is made
			return FALSE
		else
			if (map.ordinal_age>=5)
				awards["service"]++
				if (awards["service"]>=1200 && client && !("long service medal" in awarded))
					map.give_award(client.ckey, name, "long service medal", capitalize(faction_text),src)

				if (awards["medic"]>=200 && client && !("medical medal" in awarded))
					map.give_award(client.ckey, name, "medical medal", capitalize(faction_text),src)

				if (awards["tank"]>=2 && !("tank destroyer silver badge" in awarded))
					map.give_award(client.ckey, name, "tank destroyer silver badge", capitalize(faction_text),src)
				else if (awards["tank"]>=4 && !("tank destroyer gold badge" in awarded))
					map.give_award(client.ckey, name, "tank destroyer gold badge", capitalize(faction_text),src)
					map.remove_award(client.ckey, name, "tank destroyer silver badge")
	/**
				if (awards["wounded"]>=300 && !("wounded gold badge" in awarded))
					map.give_award(client.ckey, name, "wounded gold badge", capitalize(faction_text),src)
					map.remove_award(client.ckey, name, "wounded silver badge")
					map.remove_award(client.ckey, name, "wounded badge")
				else if (awards["wounded"]>=200 && !("wounded silver badge" in awarded))
					map.give_award(client.ckey, name, "wounded silver badge", capitalize(faction_text),src)
					map.remove_award(client.ckey, name, "wounded badge")
				else if (awards["wounded"]>=150 && !("wounded badge" in awarded))
					map.give_award(client.ckey, name,"wounded badge", capitalize(faction_text),src)
	**/
				for(var/list/i in awards["kills"])
					if (islist(i) && i[1] != "" && i[2] >= 100 && i[3]==0)
						i[3]=1
						awards["kill_count"]++
				for(var/list/i in awards["melee_kills"])
					if (islist(i) && i[1] != "" && i[2] >= 100 && i[3]==0)
						i[3]=1
						awards["melee_kill_count"]++
				if (awards["kill_count"]>= 10 && !("iron cross 1st class" in awarded))
					map.give_award(client.ckey, name,"iron cross 1st class", capitalize(faction_text),src)
					map.remove_award(client.ckey, name, "iron cross 2nd class")
				else if (awards["kill_count"]>= 7 && !("iron cross 2nd class" in awarded))
					map.give_award(client.ckey, name,"iron cross 2nd class", capitalize(faction_text),src)
				else if (awards["kill_count"]>= 3 && !("assault badge" in awarded))
					map.give_award(client.ckey, name,"assault badge", capitalize(faction_text),src)
				if (awards["melee_kill_count"]>= 5 && !("order of the rising sun" in awarded))
					map.give_award(client.ckey, name,"order of the rising sun", capitalize(faction_text),src)
				return TRUE
	return FALSE
/obj/map_metadata/proc/save_awards()
	var/F = file("SQL/awards.txt")
	if (!awards.len)
		return
	for (var/i = 1, i <= awards.len, i++)
		if (awards[i][1]!="")
			var/txtexport = list2text(awards[i])
			text2file(txtexport,F)
			world << SPAN_NOTICE("<font size=2>[awards[i][2]] ([awards[i][1]]) has received a <b>[awards[i][3]]</b></font>!")
	return TRUE

/obj/map_metadata/proc/give_award(var/_ckey, var/charname, var/awardtype, var/faction, var/mob/living/human/L = null)
	//ckey,charname,award,faction,map,date
	var/parsed_title = splittext(title, " (")
	awards += list(list(_ckey,charname,awardtype,faction,parsed_title[1],time2text(world.realtime, "YYYY/MM/DD")))
	if (L)
		L << "<font size=3 color='yellow'>You have received a [awardtype] medal!</font>"
		if (!(awardtype in L.awarded))
			L.awarded += list(awardtype)
		var/obj/item/clothing/accessory/medal/MEDAL = null
		if (L.w_uniform && istype(L.w_uniform, /obj/item/clothing))
			switch(awardtype)
				if ("wounded badge")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/wound(get_turf(L))

				if ("wounded silver badge")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/wound_silver(get_turf(L))

				if ("wounded gold badge")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/wound_gold(get_turf(L))

				if ("long service medal")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/long_service(get_turf(L))

				if ("tank destroyer silver badge")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/tank_destruction(get_turf(L))

				if ("tank destroyer gold badge")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/tank_destruction_gold(get_turf(L))

				if ("assault badge")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/assault_badge(get_turf(L))

				if ("iron cross 2nd class")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/iron_cross_2nd(get_turf(L))

				if ("iron cross 1st class")
					MEDAL = new /obj/item/clothing/accessory/medal/german/ww2/iron_cross_1st(get_turf(L))
				if ("order of the rising sun")
					MEDAL = new /obj/item/clothing/accessory/medal/japanese/ww2/rising_sun(get_turf(L))

			if (MEDAL)
				var/obj/item/clothing/CL = L.w_uniform
				CL.attackby(MEDAL, L)
				if (CL.can_attach_accessory(MEDAL))
					CL.accessories += MEDAL
					MEDAL.on_attached(CL, L)
					verbs |= /obj/item/clothing/proc/removetie_verb
					L.update_inv_w_uniform()
	return

/obj/map_metadata/proc/remove_award(var/_ckey, var/charname, var/awardtype)
	for (var/i=1, i<=awards.len, i++)
		if (awards[i][1] == _ckey && awards[i][2] == charname && awards[i][3] == awardtype)
			awards[i][1] = ""
			awards[i][2] = ""
			awards[i][3] = ""
	return
