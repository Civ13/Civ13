/mob/living/human/gib()
	if (client)
		client.movement_busy = FALSE
	ghostize() // preserve our body's icon before it explodes

	for (var/obj/item/organ/I in internal_organs)
		I.removed()
		if (istype(loc,/turf))
			I.throw_at(get_edge_target_turf(src,pick(alldirs)),rand(1,3),30)

	for (var/obj/item/organ/external/E in organs)
		E.droplimb(0,DROPLIMB_EDGE,1)

	sleep(1)

	for (var/obj/item/I in src)
		drop_from_inventory(I)
		I.throw_at(get_edge_target_turf(src,pick(alldirs)), rand(1,3), round(30/I.w_class))

	..(species.gibbed_anim)
	gibs(loc, null, species.flesh_color, species.blood_color)
	for(var/mob/living/human/NB in view(6,src))
		if (!NB.orc)
			NB.mood -= 15
			//NB.ptsd += 3

/mob/living/human/crush()

	sleep(1)

	for (var/obj/item/I in contents)
		if (!istype(I, /obj/item/organ))
			drop_from_inventory(I)
	if (client)
		client.movement_busy = FALSE
	..(species.gibbed_anim)
	gibs(loc, null, species.flesh_color, species.blood_color)
	for(var/mob/living/human/NB in view(6,src))
		if (!NB.orc)
			NB.mood -= 15
			//NB.ptsd += 3

/mob/living/human/maim()
	next_emote["vocal"] = world.time + 50
	..()
	next_emote["vocal"] = world.time - 1
	emote("painscream")

/mob/living/human/death(gibbed = FALSE)
	plane = 1 //for water overlays
	water_overlay = FALSE
	update_fire(1)
	if (stat == DEAD) return
	if (map && map.battleroyale && alive_n_of_side(PIRATES) > 1)
		var/obj/map_metadata/battleroyale/BR = map
		BR.give_award(client.ckey, real_name, alive_n_of_side(PIRATES))
		var/obj/map_metadata/hunger_games/HG = map
		HG.give_award(client.ckey, real_name, alive_n_of_side(PIRATES))
	if (map && map.ID == MAP_GLADIATORS && client)
		var/obj/map_metadata/gladiators/GD = map
		for (var/i = 1, i <= GD.gladiator_stats.len, i++)
			if (GD.gladiator_stats[i][1] == client.ckey && GD.gladiator_stats[i][2] == name)
				GD.gladiator_stats[i][4] = 1
				GD.save_gladiators()
		src << "<big><b>[name]'s life fades away into history...</b></big>"
	else if (map && map.ID == MAP_GULAG13 && client)
		var/obj/map_metadata/gulag13/GD = map
		if (original_job && istype(original_job, /datum/job/civilian/prisoner))
			var/mob/living/human/H = src
			for(var/i in GD.points)
				if (i[1]==H.nationality)
					i[3]-=50
	else if (map && map.ID == MAP_ABASHIRI && client)
		var/obj/map_metadata/abashiri/GD = map
		if (original_job && istype(original_job, /datum/job/civilian/abashiri))
			var/mob/living/human/H = src
			for(var/i in GD.points)
				if (i[1]==H.nationality)
					i[3]-=50
	else if (map && map.ID == MAP_ALLEYWAY)
		if (civilization && civilization in map.scores)
			if (civilization == "Yamaguchi-Gumi")
				if (original_job && original_job.title == "Yama Wakagashira")
					map.scores["Ichiwa-Kai"] += 10
					world << "<font color='red' size=3>The <b>Yamaguchi-Gumi</b> underboss has been killed!</font>"
				else
					map.scores["Ichiwa-Kai"] += 1
			else
				if (original_job && original_job.title == "Ichi Wakagashira")
					map.scores["Yamaguchi-Gumi"] += 10
					world << "<font color='red' size=3>The <b>Ichiwa-Kai</b> underboss has been killed!</font>"
				else
					map.scores["Yamaguchi-Gumi"] += 1

	else if (map && map.ID == MAP_YELTSIN)
		if (civilization && civilization in map.scores)
			if (civilization == "Russian Army")
				if (original_job && original_job.title == "Russian Army Sergeant")
					map.scores["Militia"] += 5
					world << "<font color='red' size=3>A <b>Russian Army</b> Sergeant has been killed!</font>"
				else if (original_job && original_job.title == "Russian Army Lieutenant")
					map.scores["Militia"] += 10
					world << "<font color='red' size=3>The <b>Russian Army</b> Lieutenant has been killed!</font>"
				else
					map.scores["Militia"] += 1
			else
				map.scores["Russian Army"] += 1

	else if (map && map.ID == MAP_CAPITOL_HILL)
		if (civilization && civilization in map.scores)
			if (civilization == "National Guard")
				map.scores["Militia"] += 1
			else
				map.scores["National Guard"] += 1
		if(original_job && original_job.title == "President of the USA")
			world << "<font color='red' size=3>The <b>President</b> has been killed!</font>"
		else if(original_job && original_job.title == "Vice-President of the USA")
			world << "<font color='red' size=3>The <b>Vice-President</b> has been killed!</font>"
		else if(original_job && original_job.title == "Speaker of the House")
			world << "<font color='red' size=3>The <b>Speaker of the House</b> has been killed!</font>"


	else if (map && map.ID == MAP_SOVAFGHAN)
		var/obj/map_metadata/sovafghan/MP = map
		if (faction_text == RUSSIAN && original_job.title == "Soviet Army Captain")
			MP.muj_points += 15
			world << "<font color='red' size=3>A <b>Soviet Army Lieutenant</b> has been killed!</font>"
		if (faction_text == RUSSIAN && original_job.title == "Soviet Army Lieutenant")
			MP.muj_points += 12
			world << "<font color='red' size=3>A <b>Soviet Army Lieutenant</b> has been killed!</font>"
		else if (faction_text == RUSSIAN && original_job.title == "Soviet Army Sergeant")
			MP.muj_points += 5
		else if (faction_text == RUSSIAN && original_job.title == "Soviet Army Radio Operator")
			MP.muj_points += 3
		else if (faction_text == CIVILIAN && original_job.title == "DRA Governor")
			MP.muj_points += 15
			world << "<font color='red' size=3>The <b>DRA Governor</b> has been killed!</font>"
		else if (faction_text == CIVILIAN && original_job.title == "DRA Lieutenant")
			world << "<font color='red' size=3>A <b>DRA Lieutenant</b> has been killed!</font>"
			MP.muj_points += 10
		else if (faction_text == CIVILIAN && original_job.title == "DRA Sergeant")
			world << "<font color='red' size=3>A <b>DRA Sergeant</b> has been killed!</font>"
			MP.muj_points += 5
		else if (faction_text == ARAB && original_job.title == "Mujahideen Leader")
			MP.sov_points += 10
			world << "<font color='red' size=3>A <b>Mujahideen Leader</b> has been killed!</font>"

	else if (map && map.ID == MAP_SEKIGAHARA)
		if (civilization && civilization in map.scores)
			if (civilization == "Eastern Army")
				if (original_job && original_job.title == "Azuma no Daimyo")
					map.scores["Western Army"] += 10
					world << "<font color='red' size=3>The <b>Eastern Army</b> daimyo has been killed!</font>"
				else if (original_job && original_job.title == "Tobu no Samurai")
					map.scores["Western Army"] += 5
				else
					map.scores["Western Army"] += 1
			else
				if (original_job && original_job.title == "Sei no Daimyo")
					map.scores["Eastern Army"] += 10
					world << "<font color='red' size=3>The <b>Western Army</b> daimyo has been killed!</font>"
				else if (original_job && original_job.title == "Sei no Samurai")
					map.scores["Eastern Army"] += 5
				else
					map.scores["Eastern Army"] += 1
/*
	else if (map && map.ID == MAP_AFRICAN_WARLORDS)
		if (faction_text == CIVILIAN && original_job_title == "United Nations Doctor")
			var/mob/living/human/killer = last_harmed
			if (ishuman(killer))
				map.scores[killer.nationality] -= 12
				world << "<b><big>A United Nations Doctor has been killed! The elders are furious and have put a bounty on [killer.real_name], a [killer.original_job_title]! Bring his head to your altar for a generous reward!</big></b>"
				killer.nationality = "Exiled"
		if (faction_text == CIVILIAN && original_job_title == "United Nations Engineer")
			var/mob/living/human/killer = last_harmed
			if (ishuman(killer))
				map.scores[killer.nationality] -= 10
				killer.nationality = "Exiled"
				world << "<b><big>A United Nations Engineer has been killed! The elders are furious and have put a bounty on [killer.real_name], a [killer.original_job_title]! Bring his head to your altar for a generous reward!</big></b>"
		if (faction_text == CIVILIAN && original_job_title == "United Nations Soldier")
			map.scores["Blugisi"] -= 4
			map.scores["Yellowagwana"] -= 4
			map.scores["Redkantu"] -= 4
			world << "<b><big>A United Nations Soldier has been killed. The United Nations have lowered their financial support in the region. The local population is paying the consequences!</b></big>"
		if (faction_text == CIVILIAN && original_job_title == "Local Policeman")
			map.scores["Blugisi"] -= 4
			map.scores["Yellowagwana"] -= 4
			map.scores["Redkantu"] -= 4
			world << "<b><big>A Local Policeman has been killed! The local population is in shock and lowered their support for the warbands!</b></big>"
*/
	else if (map && map.ID == MAP_THE_ART_OF_THE_DEAL)
		if (civilization && civilization in map.scores)
			if (civilization == "Paramedics")
				map.scores[last_harmed.civilization] -= 500
			else if (civilization == "Government")
				map.scores[last_harmed.civilization] -= 500
			else if (civilization == "Sheriff Office")
				map.scores[civilization] -= 250
				if (ishuman(last_harmed))
					map.scores[last_harmed.civilization] -= 100
					global_broadcast(FREQP,"<big>10-9: Officer down! All available units proceed to [get_coded_loc()] ([x],[y])!</big>")
					var/comp_to_warrant = last_harmed.civilization
					var/mob/living/human/Huser = last_harmed
					spawn(rand(300,500))
						if (comp_to_warrant != "Sheriff Office" && comp_to_warrant != "Government")
							var/obj/item/weapon/paper_bin/police/PAR = null
							for(var/obj/item/weapon/paper_bin/police/PAR2 in world)
								PAR = PAR2
								break
							if (PAR)
								var/obj/item/weapon/paper/police/searchwarrant/SW = new /obj/item/weapon/paper/police/searchwarrant(PAR.loc)
								SW.cmp = comp_to_warrant
								SW.spawntimer = 18000
								var/obj/item/weapon/paper/police/warrant/AW = new /obj/item/weapon/paper/police/warrant(PAR.loc)
								AW.tgt_mob = Huser
								AW.tgt = Huser.real_name
								AW.tgtcmp = Huser.civilization
								AW.reason = "Murder of a Law Enforcement Officer"
								AW.spawntimer = 12000
							var/obj/item/weapon/paper/police/warrant/AW2 = new /obj/item/weapon/paper/police/warrant(null)
							AW2.tgt_mob = Huser
							AW2.tgt = Huser.real_name
							AW2.tgtcmp = Huser.civilization
							AW2.reason = "Murder of a Law Enforcement Officer"
							map.pending_warrants += AW2
							AW2.forceMove(null)
							map.warrants += comp_to_warrant
							map.warrants += Huser.real_name
							Huser.gun_permit = 0
							global_broadcast(FREQP,"<big>Attention, search warrant issued for <b>[comp_to_warrant] HQ</b>, please search the premises as soon as possible.</big>")
							spawn(300)
								if (Huser.original_job_title != "Legal Business")
									global_broadcast(FREQP,"<big>Attention, a warrant has been issued for [AW2.tgt], working for [AW2.tgtcmp], please detain the suspect as soon as possible.</big>")
								else
									global_broadcast(FREQP,"<big>Attention, a warrant has been issued for [AW2.tgt], please detain the suspect as soon as possible.</big>")
							spawn(30)
								for(var/mob/living/human/HMN in player_list)
									if (HMN.civilization == comp_to_warrant)
										HMN.gun_permit = FALSE
			else
				map.scores[civilization] -= 200
				if (ishuman(last_harmed))
					var/mob/living/human/Huser = last_harmed
					var/probtogetcaught = rand(50,70)
					if (Huser.wear_mask)
						probtogetcaught = rand(0,50)
					if (Huser.civilization != "Sheriff Office" && Huser.civilization != "Paramedics" && Huser.civilization != "Government")
						if (prob(probtogetcaught))
							spawn (rand(300,500))
								var/reason = "Murder"
								if (prob(30))
									reason = "Murder of [src.real_name]"
								map.warrants += Huser.real_name
								Huser.gun_permit = 0
								var/obj/item/weapon/paper_bin/police/PAR = null
								for(var/obj/item/weapon/paper_bin/police/PAR2 in world)
									PAR = PAR2
									break
								if (PAR)
									var/obj/item/weapon/paper/police/warrant/AW = new /obj/item/weapon/paper/police/warrant(PAR.loc)
									AW.tgt_mob = Huser
									AW.tgt = Huser.real_name
									AW.tgtcmp = Huser.civilization
									AW.reason = reason
									AW.spawntimer = 12000
								var/obj/item/weapon/paper/police/warrant/AW2 = new /obj/item/weapon/paper/police/warrant(null)
								AW2.tgt_mob = Huser
								AW2.tgt = Huser.real_name
								AW2.tgtcmp = Huser.civilization
								AW2.reason = reason
								map.pending_warrants += AW2
								AW2.forceMove(null)
								if (Huser.original_job_title != "Legitimate Business")
									global_broadcast(FREQP,"<big>Attention, a warrant has been issued for [AW2.tgt], working for [AW2.tgtcmp], please detain the suspect as soon as possible.</big>")
								else
									global_broadcast(FREQP,"<big>Attention, a warrant has been issued for [AW2.tgt], please detain the suspect as soon as possible.</big>")

	else if (map && map.ID == MAP_OCCUPATION && client)
		var/obj/map_metadata/occupation/GD = map
		var/mob/living/human/H = src
		if (original_job && istype(original_job, /datum/job/civilian/occupation))
			for(var/i in GD.points)
				if (i[1]==H.nationality)
					i[3]-=50
		if (civilization)
			if (H.civilization == "SS")
				for(var/i in GD.points)
					if (H.faction_text == GERMAN && H.original_job.is_squad_leader == TRUE)
						if (i[1]=="UPA")
							i[2]+= 15
					else if (H.faction_text == GERMAN && H.original_job.is_officer == TRUE)
						if (i[1]=="UPA")
							i[2]+= 50
					else if (H.faction_text == GERMAN)
						if (i[1]=="UPA")
							i[2]+=  5
					else
						if (i[1]=="UPA")
							i[2]-= 50
			else
				for(var/i in GD.points)
					if (H.civilization == "UPA" && H.original_job.is_squad_leader == TRUE)
						if (i[1]=="SS")
							i[2]+= 20
					else if (H.civilization == "UPA" && H.original_job.is_officer == TRUE)
						if (i[1]=="SS")
							i[2]+= 50
					else if (H.civilization == "UPA")
						if (i[1]=="SS")
							i[2]+= 5
					else if (H.civilization == "Killer")
						if (i[1]=="SS")
							i[2]+= 5
						if (i[1]=="UPA")
							i[2]+= 5
					else if (H.faction_text == GERMAN && H.original_job.is_squad_leader == TRUE)
						if (i[1]=="UPA")
							i[2]+= 15
					else if (H.faction_text == GERMAN && H.original_job.is_officer == TRUE)
						if (i[1]=="UPA")
							i[2]+= 50
					else if (H.faction_text == GERMAN)
						if (i[1]=="UPA")
							i[2]+=  5
					else
						if (i[1]=="UPA")
							i[2]-= 50

		for(var/i in GD.points)
			if (H.nationality == "Polish")
				if (i[1]=="UPA")
					i[2]+= 5
			else if (H.original_job == "Auxillary Police")
				if (i[1]=="UPA")
					i[2]+= 5
				if (i[1]=="SS")
					i[2]-= 1
/*			else
				if (i[1]=="SS")
					i[2]-= 10
				if (i[1]=="UPA")
					i[2]-= 10*/

	handle_piss()
	handle_shit()
	if (squad > 0 && original_job && original_job.uses_squads)
		if (map && faction_text == map.faction1)
			map.faction1_squads[squad] -= src
			if (map.faction1_squad_leaders[squad] == src)
				map.faction1_squad_leaders[squad] = null
				for(var/mob/living/human/HSM in map.faction1_squads[squad])
					if (HSM != src)
						HSM << "<big><b><font color='red'>Your squad leader has been killed!</font></b></big>"
						if (HSM.original_job.is_squad_leader && (!map.faction1_squad_leaders[squad] || map.faction1_squad_leaders[squad] == src))
							HSM << "<big><b><font color='green'>You are the new squad leader!</font></b></big>"
							map.faction1_squad_leaders[squad] = HSM
							for(var/mob/living/human/HSM2 in map.faction2_squads[squad])
								if (HSM2 != HSM)
									HSM2 << "<big><b>[HSM] is your new squad leader.</b></big>"
		else if (faction_text == map.faction2)
			map.faction2_squads[squad] -= src
			if (map.faction2_squad_leaders[squad] == src)
				map.faction2_squad_leaders[squad] = null
				for(var/mob/living/human/HSM in map.faction2_squads[squad])
					if (HSM != src)
						HSM << "<big><b><font color='red'>Your squad leader has been killed!</font></b></big>"
						if (HSM.original_job.is_squad_leader && (!map.faction2_squad_leaders[squad] || map.faction2_squad_leaders[squad] == src))
							HSM << "<big><b><font color='green'>You are the new squad leader!</font></b></big>"
							map.faction2_squad_leaders[squad] = HSM
							for(var/mob/living/human/HSM2 in map.faction2_squads[squad])
								if (HSM2 != HSM)
									HSM2 << "<big><b>[HSM] is your new squad leader.</b></big>"
	handle_hud_list()
	var/list/poss_list = list()
	if (map)
		for(var/cmp in map.custom_company_nr)
			if (find_company_member(src,cmp))
				poss_list += cmp
		if (!isemptylist(poss_list))
			for(var/stocky in poss_list)
				for(var/list/lx in map.custom_company[stocky])
					if (lx[1] == src)
						map.sales_registry += list(list(stocky,lx[2],map.custom_company_value[stocky]*(lx[2]/100)*2,null,1))
				for(var/l=1, l <= map.custom_company[stocky].len, l++)
					if (map.custom_company[stocky][l][1] == src)
						map.custom_company[stocky][l][1] = null
	src << browse(null, "window=memory")

	if (client)
		client.movement_busy = FALSE

	//Handle species-specific deaths.
	species.handle_death(src)


	callHook("death", list(src, gibbed))

	if (l_hand) unEquip(l_hand)
	if (r_hand) unEquip(r_hand)
/*
	if (ticker && ticker.mode)

		ticker.mode.check_win()*/

	if (client)
		if (map.gamemode == "Hardcore")
			client.next_normal_respawn = world.realtime+999999
		else
			if (map.ID == MAP_CAMPAIGN)
				client.next_normal_respawn = world.realtime + 1800 + (client.respawn_count * 600)
				client.respawn_count++
			else
				client.next_normal_respawn = world.realtime + (map ? map.respawn_delay : 3000)
			client << RESPAWN_MESSAGE


	. = ..(gibbed)//,species.death_message)
	if (!gibbed)
		handle_organs()
		if (species.death_sound)
			playsound(loc, species.death_sound, 80, TRUE, TRUE)
	handle_hud_list()
