var/global/datum/controller/occupations/job_master

#define RETURN_TO_LOBBY 0
#define MEMBERS_PER_SQUAD 6
#define LEADERS_PER_SQUAD 1
#define SL_LIMIT 4

/proc/setup_autobalance(var/announce = TRUE)

	spawn (0)
		if (job_master)
			job_master.toggle_roundstart_autobalance(0, announce)

	var/list/faction_organized_occupations_separate_lists = list()
	if (job_master)
		for (var/datum/job/J in job_master.occupations)
			var/Jflag = J.base_type_flag()
			if (!faction_organized_occupations_separate_lists.Find(Jflag))
				faction_organized_occupations_separate_lists[Jflag] = list()
			faction_organized_occupations_separate_lists[Jflag] += J
	if (!map)
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[CIVILIAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[BRITISH]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[PIRATES]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[SPANISH]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[PORTUGUESE]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[FRENCH]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[INDIANS]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[DUTCH]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[ITALIAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[ROMAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[GERMAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[GREEK]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[ARAB]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[JAPANESE]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[RUSSIAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[CHECHEN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[FINNISH]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[NORWEGIAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[SWEDISH]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[DANISH]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[VIETNAMESE]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[CHINESE]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[AMERICAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[FILIPINO]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[POLISH]
	else
		for (var/faction in map.faction_organization)
			if (job_master)
				job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[faction]

/datum/controller/occupations
		//List of all jobs
	var/list/occupations = list()
		//List of all jobs ordered by faction
	var/list/faction_organized_occupations = list()
		//Players who need jobs
	var/list/unassigned = list()
		//Debug info
	var/list/job_debug = list()

/datum/controller/occupations/proc/set_factions(var/autobalance_nr = 0)
	map.availablefactions = list("Human tribesman", "Crustacean tribesman", "Orc tribesman", "Lizard tribesman")
/*
//	var/list/randomfaction = list("Red Goose Tribesman","Blue Turkey Tribesman","Green Monkey Tribesman","Yellow Mouse Tribesman","White Wolf Tribesman","Black Bear Tribesman")
//	var/randomfaction_spawn = "Red Goose Tribesman"
//	//sets 2 factions for >=10ppl, 3 factions for >=15, 4 factions for >=20, 5 factions for >=25 and 6 factions for >=30
	var/list/randomfaction = list("Orc tribesman", "Ant tribesman", "Human tribesman", "Gorilla tribesman", "Lizard tribesman", "Wolf tribesman", "Crustacean tribesman")
	if (map.availablefactions_run == TRUE)
		if (autobalance_nr < 16)
			var/a = pick(randomfaction)
			var/b = pick(randomfaction-a)
			var/c = pick(randomfaction-a-b)
			map.availablefactions = list(a,b,c)
//			world << "Three tribes are enabled: <b>[replacetext(a, " tribesman", "")], [replacetext(b, " tribesman", "")], [replacetext(c, " tribesman", "")]</b>."
		else
			var/a = pick(randomfaction)
			var/b = pick(randomfaction-a)
			var/c = pick(randomfaction-a-b)
			var/d = pick(randomfaction-a-b-c)
			map.availablefactions = list(a,b,c,d)
//			world << "Four tribes are enabled: <b>[replacetext(a, " tribesman", "")], [replacetext(b, " tribesman", "")], [replacetext(c, " tribesman", "")], [replacetext(d, " tribesman", "")]</b>."
*/
	map.availablefactions_run = FALSE
	return

/datum/controller/occupations/proc/set_factions2(var/autobalance_nr = 0)
	var/list/randomfaction = list("Civilization A Citizen","Civilization B Citizen","Civilization C Citizen","Civilization D Citizen","Civilization E Citizen","Civilization F Citizen")
	if (map.availablefactions_run == TRUE)
		if (autobalance_nr <= 8)
			map.availablefactions = list("Civilization A Citizen")
			world << "Only one civilization is enabled: <b>[civname_a]</b>."
		else if (autobalance_nr > 8 && autobalance_nr <= 16)
			map.availablefactions = list("Civilization A Citizen","Civilization B Citizen")
			world << "Two civilizations are enabled: <b>[civname_a], [civname_b]</b>."
		else if (autobalance_nr > 16 && autobalance_nr <= 24)
			map.availablefactions = list("Civilization A Citizen","Civilization B Citizen","Civilization C Citizen")
			world << "Three civilizations are enabled: <b>[civname_a], [civname_b], [civname_c]</b>."
		else if (autobalance_nr > 24 && autobalance_nr <= 30)
			map.availablefactions = list("Civilization A Citizen","Civilization B Citizen","Civilization C Citizen","Civilization D Citizen")
			world << "Four civilizations are enabled: <b>[civname_a], [civname_b], [civname_c], [civname_d]</b>."
		else if (autobalance_nr > 30 && autobalance_nr <= 36)
			map.availablefactions = list("Civilization A Citizen","Civilization B Citizen","Civilization C Citizen","Civilization D Citizen","Civilization E Citizen")
			world << "Five civilizations are enabled: <b>[civname_a], [civname_b], [civname_c], [civname_d], [civname_e]</b>."
		else if (autobalance_nr > 36)
			map.availablefactions = randomfaction
			world << "All the 6 civilizations are enabled: <b>[civname_a], [civname_b], [civname_c], [civname_d], [civname_e], [civname_f]</b>."

	map.availablefactions_run = FALSE
	return

/datum/controller/occupations/proc/set_factions3(var/autobalance_nr = 0)
	map.availablefactions = list("Human tribesman", "Gorilla tribesman", "Crustacean tribesman")
	map.availablefactions_run = FALSE
	return

/datum/controller/occupations/proc/toggle_roundstart_autobalance(var/_clients = 0)

	if (map)
		map.faction_organization = map.initial_faction_organization.Copy()
	switch(clients.len)
		if (0 to 12)
			map.squads = 1
		if (13 to 24)
			map.squads = 2
		if (25 to 36)
			map.squads = 3
		if (37 to 48)
			map.squads = 4
		if (49 to 60)
			map.squads = 5
		if (61 to 1000)
			map.squads = 6
	_clients = max(_clients, clients.len)

	var/autobalance_for_players = round(max(_clients, clients.len))

	if (map && map.civilizations && map.ID != MAP_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID != MAP_THREE_TRIBES)
		if (map.ID == MAP_CIVILIZATIONS || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR)
			set_factions2(16)
		else if (map.ID == MAP_NATIONSRP_TRIPLE)
			set_factions2(24)
		else
			set_factions2(autobalance_for_players)
	spawn(10)
		if (map && map.ID == MAP_TRIBES)
			set_factions(autobalance_for_players)
		if (map &&  map.ID == MAP_FOUR_KINGDOMS)
			set_factions(autobalance_for_players)
		if (map && map.ID == MAP_THREE_TRIBES)
			set_factions3(autobalance_for_players)
	for (var/datum/job/J in occupations)
		if (J.title != "N/A" && J.title != "generic job")
			var/positions = J.max_positions
			positions = max(positions, J.min_positions)
			positions = min(positions, J.max_positions)
			J.total_positions = positions
		else
			J.total_positions = 0

	if (map && (map.ID == MAP_LITTLE_CREEK || map.ID == MAP_LITTLE_CREEK_TDM))
		civilians_forceEnabled = TRUE

	if (map && map.faction_organization.Find(INDIANS) && (map.ID == MAP_COLONY || map.ID == MAP_JUNGLE_COLONY))
		world << "<font size = 3><span class = 'notice'><i>All factions besides <b>Colonists</b> start disabled by default. Admins can enable them.</i></span></font>"
		indians_toggled = FALSE
		pirates_toggled = FALSE
		spanish_toggled = FALSE
		civilians_forceEnabled = TRUE
	if (map && map.faction_organization.Find(INDIANS) && (map.ID == MAP_PIONEERS || map.ID == MAP_PIONEERS_WASTELAND_2))
		world << "<font size = 3><span class = 'notice'><i>All factions besides <b>Pioneers</b> start disabled by default. Admins can enable them.</i></span></font>"
		indians_toggled = FALSE
		civilians_forceEnabled = TRUE
	if (map && map.faction_organization.Find(CIVILIAN) && (map.ID == MAP_FOREST))
		world << "<font size = 3><span class = 'notice'><i>All factions besides <b>UPA</b> start enabled by default. Admins can enable the UPA.</i></span></font>"
		civilians_toggled = FALSE
	if (map.civilizations)
		civilians_forceEnabled = TRUE

/datum/controller/occupations/proc/spawn_with_delay(var/mob/new_player/np, var/datum/job/j)
	// for delayed spawning, wait the spawn_delay of the job
	// and lock up one job position while np is spawning
	if (!j.spawn_delay)
		return

	if (j.delayed_spawn_message)
		np << j.delayed_spawn_message

	np.delayed_spawning_as_job = j

	// occupy a position slot

	j.total_positions -= 1

	spawn (j.spawn_delay)
		if (np && np.delayed_spawning_as_job == j) // if np hasn't already spawned
			// if np did spawn, unoccupy the position slot
			np.AttemptLateSpawn(j.title)
			return


/datum/controller/occupations/proc/relocate(var/mob/living/human/H)

	if (!H)
		return
	
	if (H.original_job && H.original_job.uses_squads && !map.fob_spawns)
		var/mob/living/human/HSL = null
		if(H.original_job.is_squad_leader)
			spawn (10)
			for(var/mob/living/human/HM in world)
				if(HM && HM.original_job && (HM.original_job.is_officer || HM.original_job.is_commander) && HM.stat == CONSCIOUS && HM.faction_text == H.faction_text)
					HSL = HM
					break
		else if (H.squad && H.faction_text == map.faction1)
			if (H.original_job.is_tanker)
				for(var/mob/living/human/HM in world)
					if (HM && HM.original_job && HM.original_job.is_tankcom && HM.stat == CONSCIOUS && HM.faction_text == H.faction_text)
						HSL = HM
			else if (map.faction1_squad_leaders[H.squad] && !map.faction1_squad_leaders[H.squad].original_job.is_tankcom)
				HSL = map.faction1_squad_leaders[H.squad]
		else if (H.squad && H.faction_text == map.faction2)
			if (H.original_job.is_tanker)
				for(var/mob/living/human/HM in world)
					if (HM && HM.original_job && HM.original_job.is_tankcom && HM.stat == CONSCIOUS && HM.faction_text == H.faction_text)
						HSL = HM
			else if (map.faction2_squad_leaders[H.squad] && !map.faction2_squad_leaders[H.squad].original_job.is_tankcom)
				HSL = map.faction2_squad_leaders[H.squad]
		if (HSL && HSL.stat == CONSCIOUS)
			var/found = FALSE
			for(var/mob/living/human/EN in range(6,HSL))
				if (EN.stat == CONSCIOUS && EN.faction_text != H.faction_text)
					found = TRUE
					continue
			if (!found)
				var/turf/spawnloc = get_turf(HSL)
				if (HSL.dir == NORTH && get_turf(locate(HSL.x, HSL.y-1, HSL.z)))
					spawnloc = get_turf(locate(HSL.x, HSL.y-1, HSL.z))
				else if (HSL.dir == EAST && get_turf(locate(HSL.x-1, HSL.y, HSL.z)))
					spawnloc = get_turf(locate(HSL.x-1, HSL.y, HSL.z))
				else if (HSL.dir == SOUTH && get_turf(locate(HSL.x, HSL.y+1, HSL.z)))
					spawnloc = get_turf(locate(HSL.x, HSL.y+1, HSL.z))
				else if (HSL.dir == WEST && get_turf(locate(HSL.x+1, HSL.y, HSL.z)))
					spawnloc = get_turf(locate(HSL.x+1, HSL.y, HSL.z))
				if (spawnloc.density)
					spawnloc = get_turf(HSL)
				else
					for(var/obj/O in spawnloc)
						if (O.density)
							spawnloc = get_turf(HSL)
							break
				H.forceMove(spawnloc)
				HSL << "<big><font color='green'>[H] has arrived at your squad.</font></big>"
				// make sure we have the right ambience for our new location
				spawn (1)
					var/area/H_area = get_area(H)
					if (H_area)
						H_area.play_ambience(H)
				return

	var/spawn_location = H.job_spawn_location

	if (map.fob_spawns)
		SpawnAtFob(H)
	if (!H.spawned_at_fob)
		if (map.ID == MAP_GULAG13)
			if(H.nationality == "German")
				spawn_location = "JoinLateCivG"
			else if(H.nationality == "Polish")
				spawn_location = "JoinLateCivP"
			else if(H.nationality == "Ukrainian")
				spawn_location = "JoinLateCivU"
		if (!spawn_location && H.original_job)
			spawn_location = H.original_job.spawn_location
		if (map.ID == MAP_TRIBES || map.ID == MAP_FOUR_KINGDOMS || map.ID == MAP_THREE_TRIBES)
			if (H.original_job_title in map.availablefactions)
				if (H.original_job_title == "Human tribesman")
					spawn_location = "JoinLateIND1"
				else if (H.original_job_title == "Crustacean tribesman")
					spawn_location = "JoinLateIND2"
				else if (H.original_job_title == "Orc tribesman")
					spawn_location = "JoinLateIND3"
				else if (H.original_job_title == "Lizard tribesman")
					spawn_location = "JoinLateIND4"
			else
				spawn_location = "JoinLateIND5"

		if(map && map.ID == MAP_CAMPAIGN && istype(map, /obj/map_metadata/campaign/campaign5))
			if (findtext(H.original_job_title,"RDF"))
				spawn_location = "JoinLateRedN"
				if(findtext(H.original_job_title,"Squad 2"))
					spawn_location = "JoinLateRedS"
				else if(findtext(H.original_job_title,"Engineer"))
					spawn_location = "JoinLateRedS"
				else if(findtext(H.original_job_title,"Anti-Tank"))
					spawn_location = "JoinLateRedS"
				else if(findtext(H.original_job_title,"Recon"))
					spawn_location = "JoinLateRedS"
				else if(findtext(H.original_job_title,"Armored"))
					spawn_location = "JoinLateRedS"

		var/turf/spawnpoint = null
		var/list/turfs = latejoin_turfs[spawn_location]
		if (!latejoin_turfs[spawn_location] || !latejoin_turfs[spawn_location].len)
			spawnpoint = locate(48,50,1)
		else
			spawnpoint = pick(turfs)
		if (!locate(/mob) in spawnpoint && !locate(/obj/structure) in spawnpoint)
			H.loc = spawnpoint
			if (map.battleroyale) // if its the DM map, remove the "used" spawnpoint from the list
				latejoin_turfs[spawn_location] -= spawnpoint
					
		// make sure we have the right ambience for our new location
		spawn (1)
			var/area/H_area = get_area(H)
			if (H_area)
				H_area.play_ambience(H)
		/*
		if (map.ID == MAP_NOMADS_PERSISTENCE_BETA)
			new /obj/structure/vehicle/boat/rhib/premade/arrival(H.loc)
			var/spawned = 0
			for (var/obj/structure/vehicle/boat/rhib/premade/arrival/rhib in range(1,H))
				if (spawned < 1)
					if (H.faction_text == "PIRATES")
						rhib.dir = EAST
					else if (H.faction_text == "CIVILIAN")
						rhib.dir = WEST
					rhib.faststart(H)
					spawned++
				else
					qdel(rhib)
		*/

/datum/controller/occupations/proc/SpawnAtFob(var/mob/living/human/H)
	var/list/spawnable_points = list()
	spawnable_points += "Base"

	for(var/obj/structure/fob_spawnpoint/fob in world)
		if (fob.faction_text == H.faction_text)
			spawnable_points += fob
	H.loc = null
	var/input = WWinput(H, "Spawn where?", "Spawnpoint Selection", "Base", spawnable_points)
	if (!(input == "Base"))
		var/turf/fob_loc = get_turf(input)
		var/list/valid_spawns = list()
		var/blocked = FALSE // Is the spawn blocked because there is an enemy nearby?
		for (var/turf/T in circlerangeturfs(3, fob_loc))
			var/spawnable_turf = TRUE // Is the turf we're checking spawnable? (Nothing on it that would block us like walls)
			for (var/obj/O in T.contents)
				if (O.density)
					spawnable_turf = FALSE
					continue
			for (var/mob/living/human/M in T.contents)
				if (M.stat == CONSCIOUS && M.faction_text != H.faction_text)
					blocked = TRUE
				spawnable_turf = FALSE
				continue
			if (T.density)
				spawnable_turf = FALSE
			if (spawnable_turf && !blocked)
				valid_spawns += T

		if (blocked)
			H << SPAN_WARNING("<big>Cannot spawn at FOB because enemy is closeby.</big>")
			SpawnAtFob(H)
			return

		if (valid_spawns.len)
			H.spawned_at_fob = TRUE
			H.forceMove(pick(valid_spawns))
			spawn (1)
				var/area/H_area = get_area(H)
				if (H_area)
					H_area.play_ambience(H)
			return
		else
			H << SPAN_WARNING("<big>No valid spawnpoints were found at this FOB.</big>")
			SpawnAtFob(H)
			return

/datum/controller/occupations/proc/SetupOccupations(var/faction = "Human")
	occupations = list()
	var/list/all_jobs = typesof(/datum/job)
	if (!all_jobs.len)
		world << SPAN_DANGER("Error setting up jobs, no job datums found.")
		return FALSE
	for (var/J in all_jobs)
		var/datum/job/job = new J()
		if (!job)	continue
		if (job.faction != faction)	continue
		occupations += job
	return TRUE

/datum/controller/occupations/proc/GetJob(var/rank)
	if (!rank)	return null
	for (var/datum/job/J in occupations)
		if (!J)	continue
		if (J.title == rank)	return J
	return null

/datum/controller/occupations/proc/GetPlayerAltTitle(var/mob/new_player/player, rank)
	return player.original_job.title

/datum/controller/occupations/proc/AssignRole(var/mob/new_player/player, var/rank, var/latejoin = FALSE)
	if (player && rank)
		var/datum/job/job = GetJob(rank)
		if (!job)	return FALSE
		var/position_limit = job.total_positions
		if ((job.current_positions < position_limit) || position_limit == -1)
			if (player.mind)
				player.mind.assigned_role = rank
				player.mind.assigned_job = job
			player.original_job = job
			player.original_job_title = player.original_job.title
			if (player.mind)
				player.mind.role_alt_title = GetPlayerAltTitle(player, rank)
			unassigned -= player
			job.current_positions++
			return TRUE
	return FALSE

/datum/controller/occupations/proc/FreeRole(var/rank)	//making additional slot on the fly
	var/datum/job/job = GetJob(rank)
	if (job && job.current_positions >= job.total_positions && job.total_positions != -1)
		--job.current_positions
		return TRUE
	return FALSE

/datum/controller/occupations/proc/ResetOccupations()

	for (var/mob/new_player/player in player_list)
		if ((player) && (player.mind))
			player.mind.assigned_role = null
			player.mind.special_role = null
	SetupOccupations()
	unassigned = list()
	return

/datum/controller/occupations/proc/EquipRank(var/mob/living/human/H, var/rank, var/joined_late = FALSE)
	if (!H)	return null

	var/datum/job/job = GetJob(rank)

	if (job)

		//Equip job items.

		H.wipe_notes()

		job.equip(H)

		#define SAFE_SPAWN_TIME 4
		// Add loadout items. spawn(SAFE_SPAWN_TIME) so it happens after our pockets are filled with default job item
		spawn (SAFE_SPAWN_TIME*2)
			for (var/obj/item/weapon/gun/projectile/gun in H.contents)
				if (gun.w_class == ITEM_SIZE_HUGE && gun.gun_type == GUN_TYPE_MG) // MG
					if (H.back && istype(H.back, /obj/item/weapon/storage/backpack))
						for (var/v in 1 to 3)
							H.back.contents += new gun.magazine_type(H)
					else if (H.l_hand && istype(H.l_hand, /obj/item/weapon/storage/backpack))
						for (var/v in 1 to 3)
							H.l_hand.contents += new gun.magazine_type(H)
					else if (H.r_hand && istype(H.r_hand, /obj/item/weapon/storage/backpack))
						for (var/v in 1 to 3)
							H.r_hand.contents += new gun.magazine_type(H)
				else if (gun.magazine_type)
					if (!H.r_store)
						H.equip_to_slot_or_del(new gun.magazine_type(H), slot_r_store)
					if (!H.l_store)
						H.equip_to_slot_or_del(new gun.magazine_type(H), slot_l_store)
					if (!H.belt)
						H.equip_to_slot_or_del(new gun.magazine_type(H), slot_belt)
				break // but only the first gun we find
			for (var/obj/item/weapon/gun/projectile/gun in H.contents)
				if (gun == H.belt)
					if (gun.w_class != 5 || gun.gun_type != GUN_TYPE_MG) // MG
						if (gun.magazine_type)
							if (!H.r_store)
								H.equip_to_slot_or_del(new gun.magazine_type(H), slot_r_store)
							if (!H.l_store)
								H.equip_to_slot_or_del(new gun.magazine_type(H), slot_l_store)
						break // but only the first gun we find
		#undef SAFE_SPAWN_TIME

		// get our new real name based on jobspecific language ( and more
		job.update_character(H)

		if (names_used[H.real_name])
			job.give_random_name(H)

		names_used[H.real_name] = TRUE

		if (job.rank_abbreviation)
			H.real_name = "[job.rank_abbreviation] [H.real_name]"
			H.name = H.real_name
		if (map.battleroyale && H.ckey)
			H.real_name = H.ckey
			H.name = H.ckey

		job.apply_fingerprints(H)
		job.assign_faction(H)

		if(map.ID == MAP_CAMPAIGN || map.ID == MAP_ROTSTADT)
			if(istype(job, /datum/job/pirates/redfaction))
				H.remove_language("English")
				H.add_language("Redmenian",FALSE)
				for (var/datum/language/redmenian/A in H.languages)
					H.default_language = A

			else if (istype(job, /datum/job/civilian/bluefaction))
				H.remove_language("English")
				H.add_language("Blugoslavian",FALSE)
				for (var/datum/language/blugoslavian/A in H.languages)
					H.default_language = A
		if(map.ID == MAP_FOOTBALL_CAMPAIGN)
			if(istype(job, /datum/job/civilian/football_red_campaign) || istype(job, /datum/job/civilian/football_red_campaign/goalkeeper))
				H.remove_language("English")
				H.add_language("Redmenian",FALSE)
				for (var/datum/language/redmenian/A in H.languages)
					H.default_language = A
			else if (istype(job, /datum/job/civilian/football_blue_campaign) || istype(job, /datum/job/civilian/football_blue_campaign/goalkeeper))
				H.remove_language("English")
				H.add_language("Blugoslavian",FALSE)
				for (var/datum/language/blugoslavian/A in H.languages)
					H.default_language = A
					
		// removed /mob/living/job since it was confusing; it wasn't a job, but a job title
		H.original_job = job
		H.original_job_title = H.original_job.title

		// add us to the list of players for our job for quick player calculations
		if (!processes.job_data.job2players[H.original_job.title])
			processes.job_data.job2players[H.original_job.title] = list()
		processes.job_data.job2players[H.original_job.title] += H

		if (map && H && (H.faction_text in map.orc))
			H.orc = 1
		if (map && H && (H.faction_text in map.gorilla))
			H.gorillaman = 1
		if (map && H && (H.faction_text in map.ant))
			H.ant = 1
		if (map && H && (H.faction_text in map.lizard))
			H.lizard = 1
		if (map && H && (H.faction_text in map.wolfman))
			H.wolfman = 1
		if (map && H && (H.faction_text in map.crab))
			H.crab = 1
		var/spawn_location = H.original_job.spawn_location
		H.job_spawn_location = spawn_location

		if (!spawn_location)
			switch (H.original_job.base_type_flag())
				if (PIRATES)
					spawn_location = "JoinLatePirate"
				if (BRITISH)
					spawn_location = "JoinLateRN"
				if (INDIANS)
					spawn_location = "JoinLateIND"
				if (PORTUGUESE)
					spawn_location = "JoinLatePT"
				if (FRENCH)
					spawn_location = "JoinLateFR"
				if (SPANISH)
					spawn_location = "JoinLateSP"
				if (DUTCH)
					spawn_location = "JoinLateNL"
				if (ITALIAN)
					spawn_location = "JoinLateIT"
				if (JAPANESE)
					spawn_location = "JoinLateJP"
				if (RUSSIAN)
					spawn_location = "JoinLateRU"
				if (FINNISH)
					spawn_location = "JoinLateFI"
				if (NORWEGIAN)
					spawn_location = "JoinLateNO"
				if (SWEDISH)
					spawn_location = "JoinLateSE"
				if (DANISH)
					spawn_location = "JoinLateDK"
				if (CHECHEN)
					spawn_location = "JoinLateCC"
				if (GERMAN)
					spawn_location = "JoinLateGE"
				if (ROMAN)
					spawn_location = "JoinLateRO"
				if (GREEK)
					spawn_location = "JoinLateGR"
				if (ARAB)
					spawn_location = "JoinLateAR"
				if (GERMAN)
					spawn_location = "JoinLateGE"
				if (VIETNAMESE)
					spawn_location = "JoinLateJP"
				if (CHINESE)
					spawn_location = "JoinLateRU"
				if (AMERICAN)
					spawn_location = "JoinLateRN"
				if (FILIPINO)
					spawn_location = "JoinLateFP"
				if (POLISH)
					spawn_location = "JoinLatePOL"
		// fixes spawning at 1,1,1

		if (!spawn_location)
			if (findtext(H.original_job.spawn_location, "JoinLatePirate"))
				spawn_location = "JoinLatePirate"
			else if (findtext(H.original_job.spawn_location, "JoinLateRN"))
				spawn_location = "JoinLateRN"
			else if (findtext(H.original_job.spawn_location, "JoinLateIND"))
				spawn_location = "JoinLateIND"
			else if (findtext(H.original_job.spawn_location, "JoinLatePT"))
				spawn_location = "JoinLatePT"
			else if (findtext(H.original_job.spawn_location, "JoinLateSP"))
				spawn_location = "JoinLateSP"
			else if (findtext(H.original_job.spawn_location, "JoinLateFR"))
				spawn_location = "JoinLateFR"
			else if (findtext(H.original_job.spawn_location, "JoinLateNL"))
				spawn_location = "JoinLateNL"
			else if (findtext(H.original_job.spawn_location, "JoinLateRO"))
				spawn_location = "JoinLateRO"
			else if (findtext(H.original_job.spawn_location, "JoinLateGR"))
				spawn_location = "JoinLateGR"
			else if (findtext(H.original_job.spawn_location, "JoinLateAR"))
				spawn_location = "JoinLateAR"
			else if (findtext(H.original_job.spawn_location, "JoinLatePOL"))
				spawn_location = "JoinLatePOL"
		H.job_spawn_location = spawn_location

		if (H.mind)
			H.mind.assigned_role = rank

		if (istype(H)) //give humans wheelchairs, if they need them.
			var/obj/item/organ/external/l_foot = H.get_organ("l_foot")
			var/obj/item/organ/external/r_foot = H.get_organ("r_foot")
			if ((!l_foot || l_foot.status & ORGAN_DESTROYED) && (!r_foot || r_foot.status & ORGAN_DESTROYED))
				var/obj/structure/bed/chair/wheelchair/W = new /obj/structure/bed/chair/wheelchair(H.loc)
				H.buckled = W
				H.update_canmove()
				W.set_dir(H.dir)
				W.buckled_mob = H
				W.add_fingerprint(H)

		if (!istype(H, /mob/living/human/corpse))
			relocate(H)
			if (H.client)
				H.client.remove_gun_icons()
		if (H)
			spawn (50)
				if (H)
					H.stopDumbDamage = FALSE

			spawn(12)
				if(map.ID != MAP_CAMPAIGN)
					H.memory()

			return H

// this is a solution to 5 british and 1 pirates on lowpop.
/datum/controller/occupations/proc/side_is_hardlocked(side)

	// count number of each side
	var/pirates = alive_n_of_side(PIRATES)
	var/british = alive_n_of_side(BRITISH)
	var/civilians = alive_n_of_side(CIVILIAN)
	var/portuguese = alive_n_of_side(PORTUGUESE)
	var/french = alive_n_of_side(FRENCH)
	var/german = alive_n_of_side(GERMAN)
	var/indians = alive_n_of_side(INDIANS)
	var/spanish = alive_n_of_side(SPANISH)
	var/dutch = alive_n_of_side(DUTCH)
	var/italian = alive_n_of_side(ITALIAN)
	var/roman = alive_n_of_side(ROMAN)
	var/greek = alive_n_of_side(GREEK)
	var/arab = alive_n_of_side(ARAB)
	var/japanese = alive_n_of_side(JAPANESE)
	var/russian = alive_n_of_side(RUSSIAN)
	var/chechen = alive_n_of_side(CHECHEN)
	var/finnish = alive_n_of_side(FINNISH)
	var/norwegian = alive_n_of_side(NORWEGIAN)
	var/swedish = alive_n_of_side(SWEDISH)
	var/danish = alive_n_of_side(DANISH)
	var/american = alive_n_of_side(AMERICAN)
	var/vietnamese = alive_n_of_side(VIETNAMESE)
	var/chinese = alive_n_of_side(CHINESE)
	var/filipino = alive_n_of_side(FILIPINO)
	var/polish = alive_n_of_side(POLISH)

	// by default no sides are hardlocked
	var/max_british = INFINITY
	var/max_pirates = INFINITY
	var/max_civilians = INFINITY
	var/max_spanish = INFINITY
	var/max_french = INFINITY
	var/max_portuguese = INFINITY
	var/max_indians = INFINITY
	var/max_dutch = INFINITY
	var/max_italian = INFINITY
	var/max_roman = INFINITY
	var/max_greek = INFINITY
	var/max_arab = INFINITY
	var/max_japanese = INFINITY
	var/max_russian = INFINITY
	var/max_chechen = INFINITY
	var/max_finnish = INFINITY
	var/max_norwegian = INFINITY
	var/max_swedish = INFINITY
	var/max_danish = INFINITY
	var/max_german = INFINITY
	var/max_american = INFINITY
	var/max_vietnamese = INFINITY
	var/max_chinese = INFINITY
	var/max_filipino = INFINITY
	var/max_polish = INFINITY

	// see job_data.dm
	var/relevant_clients = clients.len

	if (map && !map.faction_distribution_coeffs.Find(INFINITY))

		if (map.faction_distribution_coeffs.Find(CIVILIAN))
			max_civilians = ceil(relevant_clients * map.faction_distribution_coeffs[CIVILIAN])


		if (map.faction_distribution_coeffs.Find(PIRATES))
			max_pirates = ceil(relevant_clients * map.faction_distribution_coeffs[PIRATES])

		if (map.faction_distribution_coeffs.Find(BRITISH))
			max_british = ceil(relevant_clients * map.faction_distribution_coeffs[BRITISH])

		if (map.faction_distribution_coeffs.Find(SPANISH))
			max_spanish = ceil(relevant_clients * map.faction_distribution_coeffs[SPANISH])

		if (map.faction_distribution_coeffs.Find(PORTUGUESE))
			max_portuguese = ceil(relevant_clients * map.faction_distribution_coeffs[PORTUGUESE])

		if (map.faction_distribution_coeffs.Find(FRENCH))
			max_french = ceil(relevant_clients * map.faction_distribution_coeffs[FRENCH])

		if (map.faction_distribution_coeffs.Find(INDIANS))
			max_indians = ceil(relevant_clients * map.faction_distribution_coeffs[INDIANS])

		if (map.faction_distribution_coeffs.Find(DUTCH))
			max_dutch = ceil(relevant_clients * map.faction_distribution_coeffs[DUTCH])
		
		if (map.faction_distribution_coeffs.Find(ITALIAN))
			max_dutch = ceil(relevant_clients * map.faction_distribution_coeffs[ITALIAN])

		if (map.faction_distribution_coeffs.Find(JAPANESE))
			max_japanese = ceil(relevant_clients * map.faction_distribution_coeffs[JAPANESE])

		if (map.faction_distribution_coeffs.Find(RUSSIAN))
			max_russian = ceil(relevant_clients * map.faction_distribution_coeffs[RUSSIAN])

		if (map.faction_distribution_coeffs.Find(FINNISH))
			max_finnish = ceil(relevant_clients * map.faction_distribution_coeffs[FINNISH])

		if (map.faction_distribution_coeffs.Find(NORWEGIAN))
			max_norwegian = ceil(relevant_clients * map.faction_distribution_coeffs[NORWEGIAN])

		if (map.faction_distribution_coeffs.Find(SWEDISH))
			max_swedish = ceil(relevant_clients * map.faction_distribution_coeffs[SWEDISH])

		if (map.faction_distribution_coeffs.Find(DANISH))
			max_danish = ceil(relevant_clients * map.faction_distribution_coeffs[DANISH])

		if (map.faction_distribution_coeffs.Find(CHECHEN))
			max_chechen = ceil(relevant_clients * map.faction_distribution_coeffs[CHECHEN])

		if (map.faction_distribution_coeffs.Find(GERMAN))
			max_german = ceil(relevant_clients * map.faction_distribution_coeffs[GERMAN])

		if (map.faction_distribution_coeffs.Find(ROMAN))
			max_roman = ceil(relevant_clients * map.faction_distribution_coeffs[ROMAN])

		if (map.faction_distribution_coeffs.Find(GREEK))
			max_greek = ceil(relevant_clients * map.faction_distribution_coeffs[GREEK])

		if (map.faction_distribution_coeffs.Find(ARAB))
			max_arab = ceil(relevant_clients * map.faction_distribution_coeffs[ARAB])

		if (map.faction_distribution_coeffs.Find(AMERICAN))
			max_american = ceil(relevant_clients * map.faction_distribution_coeffs[AMERICAN])

		if (map.faction_distribution_coeffs.Find(VIETNAMESE))
			max_vietnamese = ceil(relevant_clients * map.faction_distribution_coeffs[VIETNAMESE])
		if (map.faction_distribution_coeffs.Find(CHINESE))
			max_chinese = ceil(relevant_clients * map.faction_distribution_coeffs[CHINESE])
		if (map.faction_distribution_coeffs.Find(FILIPINO))
			max_filipino = ceil(relevant_clients * map.faction_distribution_coeffs[FILIPINO])
		if (map.faction_distribution_coeffs.Find(POLISH))
			max_polish = ceil(relevant_clients * map.faction_distribution_coeffs[POLISH])
	switch (side)
		if (CIVILIAN)
			if (civilians_forceEnabled)
				return FALSE
			if (civilians >= max_civilians)
				return TRUE
			return FALSE
		if (BRITISH)
			if (british_forceEnabled)
				return FALSE
			if ((british) >= max_british)
				return TRUE
		if (PIRATES)
			if (pirates_forceEnabled)
				return FALSE
			if (pirates >= max_pirates)
				return TRUE

		if (INDIANS)
			if (indians_forceEnabled)
				return FALSE
			if (indians >= max_indians)
				return TRUE

		if (FRENCH)
			if (french_forceEnabled)
				return FALSE
			if (french >= max_french)
				return TRUE

		if (SPANISH)
			if (spanish_forceEnabled)
				return FALSE
			if (spanish >= max_spanish)
				return TRUE

		if (PORTUGUESE)
			if (portuguese_forceEnabled)
				return FALSE
			if (portuguese >= max_portuguese)
				return TRUE

		if (DUTCH)
			if (dutch_forceEnabled)
				return FALSE
			if (dutch >= max_dutch)
				return TRUE
		
		if (ITALIAN)
			if (italian_forceEnabled)
				return FALSE
			if (italian >= max_italian)
				return TRUE

		if (JAPANESE)
			if (japanese_forceEnabled)
				return FALSE
			if (japanese >= max_japanese)
				return TRUE

		if (RUSSIAN)
			if (russian_forceEnabled)
				return FALSE
			if (russian >= max_russian)
				return TRUE

		if (CHECHEN)
			if (chechen_forceEnabled)
				return FALSE
			if (chechen >= max_chechen)
				return TRUE

		if (FINNISH)
			if (finnish_forceEnabled)
				return FALSE
			if (finnish >= max_finnish)
				return TRUE

		if (NORWEGIAN)
			if (norwegian_forceEnabled)
				return FALSE
			if (norwegian >= max_norwegian)
				return TRUE

		if (SWEDISH)
			if (swedish_forceEnabled)
				return FALSE
			if (swedish >= max_swedish)
				return TRUE

		if (DANISH)
			if (danish_forceEnabled)
				return FALSE
			if (danish >= max_danish)
				return TRUE

		if (GERMAN)
			if (german_forceEnabled)
				return FALSE
			if (german >= max_german)
				return TRUE

		if (ROMAN)
			if (roman_forceEnabled)
				return FALSE
			if (roman >= max_roman)
				return TRUE

		if (GREEK)
			if (greek_forceEnabled)
				return FALSE
			if (greek >= max_greek)
				return TRUE

		if (ARAB)
			if (arab_forceEnabled)
				return FALSE
			if (arab >= max_arab)
				return TRUE

		if (AMERICAN)
			if (american_forceEnabled)
				return FALSE
			if (american >= max_american)
				return TRUE

		if (VIETNAMESE)
			if (vietnamese_forceEnabled)
				return FALSE
			if (vietnamese >= max_vietnamese)
				return TRUE
		if (CHINESE)
			if (chinese_forceEnabled)
				return FALSE
			if (chinese >= max_chinese)
				return TRUE
		if (FILIPINO)
			if (filipino_forceEnabled)
				return FALSE
			if (filipino >= max_filipino)
				return TRUE

		if (POLISH)
			if (polish_forceEnabled)
				return FALSE
			if (polish >= max_polish)
				return TRUE
	return FALSE
