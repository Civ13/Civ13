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
	for (var/datum/job/J in job_master.occupations)
		var/Jflag = J.base_type_flag()
		if (!faction_organized_occupations_separate_lists.Find(Jflag))
			faction_organized_occupations_separate_lists[Jflag] = list()
		faction_organized_occupations_separate_lists[Jflag] += J
	if (!map)
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[GERMAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[SOVIET]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[ITALIAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[UKRAINIAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[CIVILIAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[PARTISAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[POLISH_INSURGENTS]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[JAPAN]
		job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[USA]
	else
		for (var/faction in map.faction_organization)
			job_master.faction_organized_occupations |= faction_organized_occupations_separate_lists[faction]

/datum/controller/occupations
		//List of all jobs
	var/list/occupations = list()
		//List of all jobs ordered by faction: German, Soviet, Italian, Ukrainian, Civilian, Partisan
	var/list/faction_organized_occupations = list()
		//Players who need jobs
	var/list/unassigned = list()
		//Debug info
	var/list/job_debug = list()
/*
	var/soviet_count = 0
	var/german_count = 0
	var/civilian_count = 0
	var/partisan_count = 0
*/
	var/current_german_squad = 1
	var/current_soviet_squad = 1
	var/current_usa_squad = 1
	var/current_japan_squad = 1

	var/german_squad_members = 0
	var/german_squad_leaders = 0

	var/japan_squad_members = 0
	var/japan_squad_leaders = 0

	var/usa_squad_members = 0
	var/usa_squad_leaders = 0

	var/soviet_squad_members = 0
	var/soviet_squad_leaders = 0

	var/german_squad_info[4]
	var/soviet_squad_info[4]
	var/usa_squad_info[4]
	var/japan_squad_info[4]

	var/german_officer_squad_info[4]
	var/soviet_officer_squad_info[4]
	var/usa_officer_squad_info[4]
	var/japan_officer_squad_info[4]

	var/italians_were_enabled = FALSE
	var/SS_was_enabled = FALSE
	var/civilians_were_enabled = FALSE
	var/partisans_were_enabled = FALSE

	var/admin_expected_clients = 0

/datum/controller/occupations/proc/toggle_roundstart_autobalance(var/_clients = 0, var/announce = TRUE)

	if (map)
		map.faction_organization = map.initial_faction_organization.Copy()

	_clients = max(max(_clients, (map ? map.min_autobalance_players : 0)), clients.len, admin_expected_clients)

	var/autobalance_for_players = round(max(_clients, (clients.len/config.max_expected_players) * 50))

	if (announce == TRUE)
		world << "<span class = 'notice'>Setting up roundstart autobalance for [max(_clients, autobalance_for_players)] players.</span>"
	else if (announce == 2)
		if (!roundstart_time)
			world << "<span class = 'warning'>An admin has changed autobalance to be set up for [max(_clients, autobalance_for_players)] players.</span>"
		else
			world << "<span class = 'warning'>An admin has reset autobalance for [max(_clients, autobalance_for_players)] players.</span>"

	var/italiano = FALSE
	var/warcrimes = FALSE

	for (var/datum/job/J in occupations)
		if (map)
			if (J.is_SS)
				if (!map.available_subfactions.Find(SCHUTZSTAFFEL))
					J.total_positions = 0
					continue
			if (J.is_SS_TV)
				if (!map.available_subfactions.Find(SS_TV))
					J.total_positions = 0
					continue
			if (J.is_prisoner)
				if (!map.available_subfactions.Find(SOVIET_PRISONER))
					J.total_positions = 0
					continue
			if (J.is_reichstag)
				if (!map.available_subfactions.Find(GERMAN_REICHSTAG))
					J.total_positions = 0
					continue
			if (J.is_dirlewanger)
				if (!map.available_subfactions.Find(DIRLEWANGER))
					J.total_positions = 0
					continue
			if (J.is_partisan)
				if (!map.available_subfactions.Find(SOVIET_PARTISAN))
					J.total_positions = 0
					continue
			if (J.is_escort)
				if (!map.available_subfactions.Find(ESCORT))
					J.total_positions = 0
					continue
			else if (J.base_type_flag() == ITALIAN)
				if (!map.available_subfactions.Find(ITALIAN))
					J.total_positions = 0
					continue

		if (autobalance_for_players >= J.player_threshold && J.title != "N/A" && J.title != "generic job")
			var/positions = round((autobalance_for_players/J.scale_to_players) * J.max_positions)
			positions = max(positions, J.min_positions)
			positions = min(positions, J.max_positions)
			J.total_positions = positions
			if (!italiano)
				if (istype(J, /datum/job/italian/soldier))
					italiano = TRUE
			if (!warcrimes)
				if (istype(J, /datum/job/german/soldier_ss))
					warcrimes = TRUE
		else
			J.total_positions = 0

	if (map && map.subfaction_is_main_faction)
		announce = FALSE

	if (italiano)
		if (announce)
			world << "<font size = 3><span class = 'notice'>The Wehrmacht has the assistance of the Italian Army for this battle.</span></font>"
		italians_were_enabled = TRUE
		for (var/obj/structure/vending/italian/apparel/pizzeria in vending_machine_list)
			pizzeria.invisibility = 0
			pizzeria.density = TRUE
		for (var/obj/structure/vending/italian/equipment/meatballshooter in vending_machine_list)
			meatballshooter.invisibility = 0
			meatballshooter.density = TRUE
	else
		for (var/obj/structure/vending/italian/apparel/pizzeria in vending_machine_list)
			pizzeria.invisibility = 101
			pizzeria.density = FALSE
		for (var/obj/structure/vending/italian/equipment/meatballshooter in vending_machine_list)
			meatballshooter.invisibility = 101
			meatballshooter.density = FALSE
		if (map)
			map.faction_organization -= ITALIAN

	if (warcrimes)
		if (announce)
			world << "<font size = 3><span class = 'notice'>The Wehrmacht has the assistance of the Waffen-SS for this battle.</span></font>"
		SS_was_enabled = TRUE

	if (!is_side_locked(CIVILIAN) && map && map.faction_organization.Find(CIVILIAN) && map.faction_organization.Find(PARTISAN))
		if (italiano || warcrimes || autobalance_for_players >= PLAYER_THRESHOLD_HIGHEST-10)
			if (announce)
				world << "<font size = 3><span class = 'notice'>Civilian and Partisan factions are enabled.</span></font>"
			civilians_were_enabled = TRUE
			partisans_were_enabled = TRUE
		else
			if (map)
				map.faction_organization -= list(CIVILIAN, PARTISAN)

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

// full squads, not counting SLs
/datum/controller/occupations/proc/full_squads(var/team)
	switch (team)
		if (GERMAN)
			return round(german_squad_members/MEMBERS_PER_SQUAD)
		if (SOVIET)
			return round(soviet_squad_members/MEMBERS_PER_SQUAD)
		if (USA)
			return round(usa_squad_members/MEMBERS_PER_SQUAD)
		if (JAPAN)
			return round(japan_squad_members/MEMBERS_PER_SQUAD)
	return FALSE

/datum/controller/occupations/proc/must_have_squad_leader(var/team)
	switch (team)
		if (GERMAN)
			if (full_squads(team) > german_squad_leaders && !(german_squad_leaders == 4))
				return TRUE
		if (SOVIET)
			if (full_squads(team) > soviet_squad_leaders && !(soviet_squad_leaders == 4))
				return TRUE
		if (USA)
			if (full_squads(team) > usa_squad_leaders && !(usa_squad_leaders == 4))
				return TRUE
		if (JAPAN)
			if (full_squads(team) > japan_squad_leaders && !(japan_squad_leaders == 4))
				return TRUE
	return FALSE // not relevant for other teams

/datum/controller/occupations/proc/must_not_have_squad_leader(var/team)
	switch (team)
		if (GERMAN)
			if (german_squad_leaders > full_squads(team))
				return TRUE
		if (SOVIET)
			if (soviet_squad_leaders > full_squads(team))
				return TRUE
		if (JAPAN)
			if (japan_squad_leaders > full_squads(team))
				return TRUE
		if (USA)
			if (usa_squad_leaders > full_squads(team))
				return TRUE
	return FALSE // not relevant for other teams


// too many people joined as a soldier and not enough as SL
// return FALSE if j is anything but a squad leader or special roles
/datum/controller/occupations/proc/squad_leader_check(var/mob/new_player/np, var/datum/job/j)
	var/current_squad = istype(j, /datum/job/german) ? current_german_squad : current_soviet_squad
	if (!j.is_commander && !j.is_nonmilitary && !j.is_SS && !j.is_paratrooper)
		// we're trying to join as a soldier or officer
		if (j.is_officer) // handle officer
			if (must_have_squad_leader(j.base_type_flag())) // only accept SLs
				if (!j.SL_check_independent)
					np << "<span class = 'danger'>Squad #[current_squad] needs a Squad Leader! You can't join as anything else until it has one. You can still spawn in through reinforcements, though.</span>"
					return FALSE
				else // we're joining as the SL or another allowed role
					return TRUE
		else
			if (must_have_squad_leader(j.base_type_flag())) // only accept SLs
				if (!j.SL_check_independent)
					np << "<span class = 'danger'>Squad #[current_squad] needs a Squad Leader! You can't join as anything else until it has one. You can still spawn in through reinforcements, though.</span>"
					return FALSE
	else
		if (must_have_squad_leader(j.base_type_flag()))
			if (!j.SL_check_independent)
				np << "<span class = 'danger'>Squad #[current_german_squad] needs a Squad Leader! You can't join as anything else until it has one. You can still spawn in through reinforcements, though.</span>"
				return FALSE
	return TRUE

// too many people joined as a SL and not enough as soldier
// return FALSE if j is a squad leader
/datum/controller/occupations/proc/squad_member_check(var/mob/new_player/np, var/datum/job/j)
	if (!j.is_commander && !j.is_nonmilitary && !j.is_SS && !j.is_paratrooper)
		// we're trying to join as a soldier or officer
		if (j.is_officer) // handle officer
			if (must_not_have_squad_leader(j.base_type_flag())) // don't accept SLs
				if (istype(j, /datum/job/german/squad_leader) || istype(j, /datum/job/soviet/squad_leader))
					np << "<span class = 'danger'>Squad #[current_german_squad] already has a Squad Leader! You can't join as one yet.</span>"
					return FALSE
				else
					return TRUE
	else
		if (must_have_squad_leader(j.base_type_flag()))
			if (!j.SL_check_independent)
				np << "<span class = 'danger'>Squad #[current_german_squad] needs a Squad Leader! You can't join as anything else until it has one.</span>"
				return FALSE
	return TRUE

/datum/controller/occupations/proc/relocate(var/mob/living/carbon/human/H)

	if (!H)
		return

	var/spawn_location = H.job_spawn_location

	if (!spawn_location && H.original_job)
		spawn_location = H.original_job.spawn_location

	#ifdef SPAWNLOC_DEBUG
	world << "[H]([H.original_job.title]) job spawn location = [H.job_spawn_location]"
	world << "[H]([H.original_job.title]) original job spawn location = [H.original_job.spawn_location]"
	world << "[H]([H.original_job.title]) spawn location = [spawn_location]"
	#endif

	var/list/turfs = latejoin_turfs[spawn_location]

	for (var/spawnpoint in turfs)
		if (!locate(/mob) in spawnpoint && !locate(/obj/structure) in spawnpoint)
			H.loc = spawnpoint
			break

	// make sure we have the right ambience for our new location
	spawn (1)
		var/area/H_area = get_area(H)
		if (H_area)
			H_area.play_ambience(H)

/datum/controller/occupations/proc/SetupOccupations(var/faction = "Station")
	occupations = list()
	var/list/all_jobs = typesof(/datum/job)
	if (!all_jobs.len)
		world << "<span class = 'red'>\b Error setting up jobs, no job datums found</span>"
		return FALSE
	for (var/J in all_jobs)
		var/datum/job/job = new J()
		if (!job)	continue
		if (job.faction != faction)	continue
		occupations += job
	occupations += new/datum/job/german/oberstleutnant
	return TRUE


/datum/controller/occupations/proc/Debug(var/text)
	if (!Debug2)	return FALSE
	job_debug.Add(text)
	return TRUE


/datum/controller/occupations/proc/GetJob(var/rank)
	if (!rank)	return null
	for (var/datum/job/J in occupations)
		if (!J)	continue
		if (J.title == rank)	return J
	return null

/datum/controller/occupations/proc/GetPlayerAltTitle(var/mob/new_player/player, rank)
	return player.original_job.title

/datum/controller/occupations/proc/AssignRole(var/mob/new_player/player, var/rank, var/latejoin = FALSE, var/reinforcements = FALSE)
	Debug("Running AR, Player: [player], Rank: [rank], LJ: [latejoin]")
	if (player && rank)
		var/datum/job/job = GetJob(rank)
		if (!job)	return FALSE
		if (!job.player_old_enough(player.client)) return FALSE
		var/position_limit = job.total_positions
		if ((job.current_positions < position_limit) || position_limit == -1 || reinforcements)
			Debug("Player: [player] is now Rank: [rank], JCP:[job.current_positions], JPL:[position_limit]")
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
	Debug("AR has failed, Player: [player], Rank: [rank]")
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

/datum/controller/occupations/proc/EquipRank(var/mob/living/carbon/human/H, var/rank, var/joined_late = FALSE)
	if (!H)	return null

	var/datum/job/job = GetJob(rank)

	if (job)

		//Equip job items.

		H.wipe_notes()

		job.equip(H)

		// civs and partisans
		if (istype(job, /datum/job/partisan))
			H.equip_coat(/obj/item/clothing/suit/storage/coat/civilian)
		else if (istype(job, /datum/job/german))
			if (job.is_officer)
				H.equip_coat(/obj/item/clothing/suit/storage/coat/german/officer)
			else if (job.is_SS)
				H.equip_coat(/obj/item/clothing/suit/storage/coat/german/SS)
			else
				H.equip_coat(/obj/item/clothing/suit/storage/coat/german)
		else if (istype(job, /datum/job/soviet))
			if (job.is_officer)
				H.equip_coat(/obj/item/clothing/suit/storage/coat/soviet/officer)
			else if (job.is_partisan)
				H.equip_coat(/obj/item/clothing/suit/polcoat1)
			else
				H.equip_coat(/obj/item/clothing/suit/storage/coat/soviet)
		else if (istype(job, /datum/job/italian))
			H.equip_coat(/obj/item/clothing/suit/storage/coat/italian)

		#define SAFE_SPAWN_TIME 4
		// Add loadout items. spawn(SAFE_SPAWN_TIME) so it happens after our pockets are filled with default job items
		spawn (SAFE_SPAWN_TIME)
			if (map.custom_loadout && !findtext("[H.original_job.type]", "doctor"))
				if (!list(CIVILIAN).Find(H.original_job.base_type_flag()))
					for (var/v in 1 to 2)
						var/slot = (v == 1 ? slot_l_store : slot_r_store)
						// short circuit if pockets are already full
						switch (slot)
							if (slot_l_store)
								if (H.l_store)
									continue
							if (slot_r_store)
								if (H.r_store)
									continue
						var/other_slot_num = (v == 1 ? 2 : 1)
						if (H.client && H.client.prefs.pockets.len >= v)
							switch (lowertext(H.client.prefs.pockets[v]))
								if (null, "Magazine")
									continue
								if ("water")
									H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/water/filled(H), slot)
/*								if ("booze")
									var/probs = list()
									switch (H.original_job.base_type_flag())
										if (GERMAN)
											probs["beer"] = 75
											probs["vodka"] = 15
											probs["wine"] = 10
										if (ITALIAN)
											probs["beer"] = 50
											probs["vodka"] = 10
											probs["wine"] = 40
										if (SOVIET, PARTISAN)
											probs["beer"] = 40
											probs["vodka"] = 60
											probs["wine"] = 0

									tryagain
									if (prob(probs["beer"]))
										H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer(H), slot)
									else if (prob(probs["vodka"]))
										H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/vodka(H), slot)
									else if (prob(probs["wine"]))
										H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/wine(H), slot)
									else goto tryagain
*/
								if ("grenade")
									switch (H.original_job.base_type_flag())
										if (GERMAN, ITALIAN)
											if (prob(50))
												H.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive/stgnade(H), slot)
											else
												H.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive/l2a2(H), slot)
										if (SOVIET, PARTISAN)
											if (prob(50))
												H.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive/rgd(H), slot)
											else
												H.equip_to_slot_or_del(new /obj/item/weapon/grenade/explosive/f1(H), slot)
								if ("smoke grenade")
									switch (H.original_job.base_type_flag())
										if (GERMAN, ITALIAN)
											H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/german(H), slot)
										if (SOVIET, PARTISAN)
											H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/soviet(H), slot)
								if ("stolen gun") // hackcode to equip ammo after the gun always
									var/ammo_check = (H.client.prefs.pockets[other_slot_num] == "Stolen gun ammo")
									H.original_job.equip_random_enemy_gun(H, slot, ammo_check)
									if (ammo_check)
										break // if we're slot #1, we know what went in the other slot already
								if ("stolen gun ammo")
									continue // see "stolen gun" just above
								if ("flare")
									H.equip_to_slot_or_del(new /obj/item/flashlight/flare(H), slot)
								if ("knife")
									H.equip_to_slot_or_del(new /obj/item/weapon/material/knife(H), slot)
								if ("cigarettes")
									H.equip_to_slot(new /obj/item/weapon/storage/fancy/cigarettes(H), slot)
								if ("lighter")
									H.equip_to_slot(new /obj/item/weapon/flame/lighter(H), slot)
								if ("crowbar")
									H.equip_to_slot(new /obj/item/weapon/crowbar(H), slot)
								if ("wrench")
									H.equip_to_slot(new /obj/item/weapon/wrench(H), slot)
								if ("screwdriver")
									H.equip_to_slot(new /obj/item/weapon/screwdriver(H), slot)

		// Give the guy some ammo for his gun: spawn(SAFE_SPAWN_TIME*2) so it happens after custom loadout
		spawn (SAFE_SPAWN_TIME*2)
			for (var/obj/item/weapon/gun/projectile/gun in H.contents)
				if (gun.w_class == 5 && gun.gun_type == GUN_TYPE_MG) // MG
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
			job.rank_abbreviation = capitalize(lowertext(job.rank_abbreviation))
			H.real_name = "[job.rank_abbreviation]. [H.real_name]"
			H.name = H.real_name

		job.apply_fingerprints(H)
		job.assign_faction(H)

		if (!game_started)
			if (!job.try_make_initial_spy(H))
				job.try_make_jew(H)
		else
			job.try_make_latejoin_spy(H)

		// removed /mob/living/job since it was confusing; it wasn't a job, but a job title
		H.original_job = job
		H.original_job_title = H.original_job.title

		// add us to the list of players for our job for quick player calculations
		if (!processes.job_data.job2players[H.original_job.title])
			processes.job_data.job2players[H.original_job.title] = list()
		processes.job_data.job2players[H.original_job.title] += H

		#ifdef SPAWNLOC_DEBUG
		if (H.original_job)
			world << "[H]'s original job: [H.original_job]"
		else
			world << "<span class = 'danger'>WARNING: [H] has no original job!!</span>"
		#endif

		var/spawn_location = H.original_job.spawn_location
		H.job_spawn_location = spawn_location

		#ifdef SPAWNLOC_DEBUG
		world << "[H] ([rank]) spawn location = [spawn_location]"
		#endif

		if (!spawn_location)
			switch (H.original_job.base_type_flag())
				if (GERMAN)
					spawn_location = "JoinLateHeer"
				if (SOVIET)
					spawn_location = "JoinLateRA"
				if (USA)
					spawn_location = "JoinLateUSA"
				if (JAPAN)
					spawn_location = "JoinLateHeer"
				if ((PARTISAN) || (POLISH_INSURGENTS))
					spawn_location = "JoinLatePartisan"
				if (PIRATES)
					spawn_location = "JoinLateHeer"
				if (BRITISH)
					spawn_location = "JoinLateRA"

		// fixes spawning at 1,1,1

		if (!spawn_location)
			if (findtext(H.original_job.spawn_location, "JoinLateHeer"))
				spawn_location = "JoinLateHeer"
			else if (findtext(H.original_job.spawn_location, "JoinLateSS"))
				spawn_location = "JoinLateSS"
			else if (findtext(H.original_job.spawn_location, "JoinLateRA"))
				spawn_location = "JoinLateRA"

		H.job_spawn_location = spawn_location

		#ifdef SPAWNLOC_DEBUG
		world << "got to squadsetting code"
		#endif

		if (H.original_job.base_type_flag() == GERMAN)
			current_german_squad = max(current_german_squad, H.squad_faction ? H.squad_faction.actual_number : current_german_squad)
		else if (H.original_job.base_type_flag() == SOVIET)
			current_soviet_squad = max(current_soviet_squad, H.squad_faction ? H.squad_faction.actual_number : current_soviet_squad)

		#ifdef SPAWNLOC_DEBUG
		world << "got past squadsetting code"
		#endif

		if ((!map || map.squad_spawn_locations) && H.squad_faction)
			switch (spawn_location)
				// German
				if ("JoinLateHeer")
					spawn_location = "JoinLateHeer-S[current_german_squad]"
				if ("JoinLateHeerSL")
					spawn_location = "JoinLateHeer-S[current_german_squad]-Leader"
				// Soviet
				if ("JoinLateRA")
					spawn_location = "JoinLateRA-S[current_soviet_squad]"
				if ("JoinLateRASL")
					spawn_location = "JoinLateRA-S[current_soviet_squad]-Leader"

		H.job_spawn_location = spawn_location

		if (isgermansquadmember_or_leader(H))
			if (isgermansquadleader(H))
				++german_squad_leaders
				german_squad_info[current_german_squad] = "<b>The leader of your squad (#[current_german_squad]) is [H.real_name]. He has a golden HUD.</b>"
				if (!istype(get_area(H), /area/prishtina/admin) && ticker.current_state != GAME_STATE_PREGAME) // first check fails due to bad location, fix
					world << "<b>The leader of Wehrmacht Squad #[current_german_squad] is [H.real_name]!</b>"
				german_officer_squad_info[current_german_squad] = "<b><i>The leader of squad #[current_german_squad] is [H.real_name].</i></b>"
			else
				if (!job.is_officer && !job.is_SS && !job.is_paratrooper && !job.is_nonmilitary)
					++german_squad_members
					if (german_squad_info[current_german_squad])
						spawn (0)
							H << german_squad_info[current_german_squad]
							H.add_memory(german_squad_info[current_german_squad])
					else
						spawn (2)
							H << "<i>Your squad, #[current_german_squad], does not have a Squad Leader yet. Consider waiting for one before deploying.</i>"

		else if (issovietsquadmember_or_leader(H))
			if (issovietsquadleader(H))
				soviet_squad_info[current_soviet_squad] = "<b>The leader of your squad (#[current_soviet_squad]) is [H.real_name]. He has a golden HUD.</b>"
				if (!istype(get_area(H), /area/prishtina/admin) && ticker.current_state != GAME_STATE_PREGAME) // first check fails due to bad location, fix
					world << "<b>The leader of Soviet Squad #[current_soviet_squad] is [H.real_name]!</b>"
				soviet_officer_squad_info[current_soviet_squad] = "<b><i>The leader of squad #[current_soviet_squad] is [H.real_name].</i></b>"
				++soviet_squad_leaders
			else
				if (!job.is_officer)
					++soviet_squad_members
					if (soviet_squad_info[current_soviet_squad])
						spawn (0)
							H << soviet_squad_info[current_soviet_squad]
							H.add_memory(soviet_squad_info[current_soviet_squad])
					else
						spawn (2)
							H << "<i>Your squad, #[current_soviet_squad], does not have a Squad Leader yet. Consider waiting for one before deploying.</i>"
		else if (isusasquadmember_or_leader(H))
			if (isusasquadleader(H))
				usa_squad_info[current_usa_squad] = "<b>The leader of your squad (#[current_usa_squad]) is [H.real_name]. He has a golden HUD.</b>"
				if (!istype(get_area(H), /area/prishtina/admin) && ticker.current_state != GAME_STATE_PREGAME) // first check fails due to bad location, fix
					world << "<b>The leader of American Squad #[current_usa_squad] is [H.real_name]!</b>"
				usa_officer_squad_info[current_usa_squad] = "<b><i>The leader of squad #[current_usa_squad] is [H.real_name].</i></b>"
				++usa_squad_leaders
			else
				if (!job.is_officer)
					++usa_squad_members
					if (usa_squad_info[current_usa_squad])
						spawn (0)
							H << usa_squad_info[current_usa_squad]
							H.add_memory(usa_squad_info[current_usa_squad])
					else
						spawn (2)
							H << "<i>Your squad, #[current_usa_squad], does not have a Squad Leader yet. Consider waiting for one before deploying.</i>"
		else if (isjapansquadmember_or_leader(H))
			if (isjapansquadleader(H))
				japan_squad_info[current_japan_squad] = "<b>The leader of your squad (#[current_japan_squad]) is [H.real_name]. He has a golden HUD.</b>"
				if (!istype(get_area(H), /area/prishtina/admin) && ticker.current_state != GAME_STATE_PREGAME) // first check fails due to bad location, fix
					world << "<b>The leader of Japanese Squad #[current_japan_squad] is [H.real_name]!</b>"
				japan_officer_squad_info[current_japan_squad] = "<b><i>The leader of squad #[current_japan_squad] is [H.real_name].</i></b>"
				++japan_squad_leaders
			else
				if (!job.is_officer)
					++japan_squad_members
					if (japan_squad_info[current_japan_squad])
						spawn (0)
							H << japan_squad_info[current_japan_squad]
							H.add_memory(japan_squad_info[current_japan_squad])
					else
						spawn (2)
							H << "<i>Your squad, #[current_japan_squad], does not have a Squad Leader yet. Consider waiting for one before deploying.</i>"

		else if (H.original_job.is_officer && H.original_job.base_type_flag() == SOVIET)
			spawn (5)
				for (var/i in 1 to soviet_officer_squad_info.len)
					if (soviet_officer_squad_info[i])
				//		H << "<br>[soviet_officer_squad_info[i]]"
						H.add_memory(soviet_officer_squad_info[i])

		else if (H.original_job.is_officer && H.original_job.base_type_flag() == GERMAN)
			spawn (5)
				for (var/i in 1 to german_officer_squad_info.len)
					if (german_officer_squad_info[i])
				//		H << "<br>[german_officer_squad_info[i]]"
						H.add_memory(german_officer_squad_info[i])

		else if (H.original_job.is_officer && H.original_job.base_type_flag() == USA)
			spawn (5)
				for (var/i in 1 to usa_officer_squad_info.len)
					if (usa_officer_squad_info[i])
				//		H << "<br>[german_officer_squad_info[i]]"
						H.add_memory(usa_officer_squad_info[i])
		else if (H.original_job.is_officer && H.original_job.base_type_flag() == JAPAN)
			spawn (5)
				for (var/i in 1 to japan_officer_squad_info.len)
					if (japan_officer_squad_info[i])
				//		H << "<br>[german_officer_squad_info[i]]"
						H.add_memory(japan_officer_squad_info[i])

		if (H.original_job.is_officer)
			if (H.original_job.base_type_flag() == GERMAN)
		//		H << "The passcode for radios and phones is <b>[supply_codes[GERMAN]].</b>"
				H.add_memory("The passcode for radios and phones is [processes.supply.codes[GERMAN]].")

			else if (H.original_job.base_type_flag() == SOVIET)
		//		H << "The passcode for radios and phones is <b>[supply_codes[SOVIET]].</b>"
				H.add_memory("The passcode for radios and phones is [processes.supply.codes[SOVIET]].")
			else if (H.original_job.base_type_flag() == USA)
		//		H << "The passcode for radios and phones is <b>[supply_codes[SOVIET]].</b>"
				H.add_memory("The passcode for radios and phones is [processes.supply.codes[USA]].")
			else if (H.original_job.base_type_flag() == JAPAN)
		//		H << "The passcode for radios and phones is <b>[supply_codes[SOVIET]].</b>"
				H.add_memory("The passcode for radios and phones is [processes.supply.codes[JAPAN]].")

		#ifdef SPAWNLOC_DEBUG
		world << "[H] ([rank]) GOT TO job spawn location = [H.job_spawn_location]"
		#endif

		var/alt_title = null
		if (H.mind)
			H.mind.assigned_role = rank
			alt_title = H.mind.role_alt_title

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


		#ifdef SPAWNLOC_DEBUG
		world << "[H] ([rank]) GOT TO before spawnID()"
		#endif

		spawnKeys(H, rank, alt_title)

		#ifdef SPAWNLOC_DEBUG
		world << "[H] ([rank]) GOT TO after spawnID()"
		#endif

		if (job.req_admin_notify)
			H << "<b>You are playing a job that is important for Game Progression. If you have to disconnect, please notify the admins via adminhelp.</b>"
		//Gives glasses to the vision impaired
		if (H.disabilities & NEARSIGHTED)
			var/equipped = H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular(H), slot_glasses)
			if (equipped != TRUE)
				var/obj/item/clothing/glasses/G = H.glasses
				G.prescription = TRUE

		if (!istype(H, /mob/living/carbon/human/corpse))
			relocate(H)
			if (H.client)
				H.client.remove_gun_icons()

		spawn (50)
			H.stopDumbDamage = FALSE

		H.memory()

		return H

/datum/controller/occupations/proc/spawnKeys(var/mob/living/carbon/human/H, rank, title)

	if (!H)	return FALSE

	var/datum/job/job = null
	for (var/datum/job/J in occupations)
		if (J.title == rank)
			job = J
			break

	if (job.uses_keys)
		spawn_keys(H, rank, job)
//		H << "<i>Click on a door with your <b>keychain</b> to open it. It will select the right key for you. To put the keychain in your hand, <b>drag</b> it.</i>"

	return TRUE

/datum/controller/occupations/proc/spawn_keys(var/mob/living/carbon/human/H, rank, var/datum/job/job)

	var/list/_keys = job.get_keys()
	if (!_keys.len)
		return

	var/obj/item/weapon/storage/belt/keychain/keychain = new/obj/item/weapon/storage/belt/keychain()

	if (!H.wear_id) // first, try to equip it to their ID slot
		H.equip_to_slot_or_del(keychain, slot_wear_id)
	else if (!H.belt) // first, try to equip it as their belt
		H.equip_to_slot_or_del(keychain, slot_belt)

	var/list/keys = job.get_keys()

	for (var/obj/item/weapon/key in keys)
		if (keychain.can_be_inserted(key))
			keychain.handle_item_insertion(key)
			keychain.keys += key
			keychain.update_icon_state()

/datum/controller/occupations/proc/is_side_locked(side)
	if (!ticker)
		return TRUE
	if (side == SOVIET)
		if (soviets_forceEnabled)
			return FALSE
		if (side_is_hardlocked(side))
			return 2
		return !ticker.can_latejoin_ruforce
	else if (side == GERMAN || side == ITALIAN)
		if (germans_forceEnabled)
			return FALSE
		if (side_is_hardlocked(side))
			return 2
		return !ticker.can_latejoin_geforce
	else if (side == CIVILIAN)
		if (civilians_forceEnabled)
			return FALSE
		return map.game_really_started()
	else if (side == PARTISAN)
		if (partisans_forceEnabled)
			return FALSE
		return map.game_really_started()
	return FALSE

// this is a solution to 5 germans and 1 soviet on lowpop.
/datum/controller/occupations/proc/side_is_hardlocked(side)

	// count number of each side
	var/germans = alive_n_of_side(GERMAN)
	var/soviets = alive_n_of_side(SOVIET)
	var/italians = alive_n_of_side(ITALIAN)
	var/civilians = alive_n_of_side(CIVILIAN)
	var/partisans = alive_n_of_side(PARTISAN)
//	var/poles = alive_n_of_side(POLISH_INSURGENTS)
//	var/americans = alive_n_of_side(USA)
//	var/japanese = alive_n_of_side(JAPAN)

	// by default no sides are hardlocked
	var/max_germans = INFINITY
	var/max_soviets = INFINITY
	var/max_civilians = INFINITY
	var/max_partisans = INFINITY
//	var/max_americans = INFINITY
//	var/max_poles = INFINITY
//	var/max_japanese = INFINITY

	// see job_data.dm
	var/relevant_clients = clients.len

	if (map && !map.faction_distribution_coeffs.Find(INFINITY))
		if (map.faction_distribution_coeffs.Find(GERMAN))
			max_germans = ceil(relevant_clients * map.faction_distribution_coeffs[GERMAN])

		// Italians are disabled/enabled whenever Germans are

		if (map.faction_distribution_coeffs.Find(SOVIET))
			max_soviets = ceil(relevant_clients * map.faction_distribution_coeffs[SOVIET])

		if (map.faction_distribution_coeffs.Find(CIVILIAN))
			max_civilians = ceil(relevant_clients * map.faction_distribution_coeffs[CIVILIAN])

		if (map.faction_distribution_coeffs.Find(PARTISAN))
			max_partisans = ceil(relevant_clients * map.faction_distribution_coeffs[PARTISAN])

//		if (map.faction_distribution_coeffs.Find(POLISH_INSURGENTS))
//			max_poles = ceil(relevant_clients * map.faction_distribution_coeffs[POLISH_INSURGENTS])

//		if (map.faction_distribution_coeffs.Find(USA))
//			max_americans = ceil(relevant_clients * map.faction_distribution_coeffs[USA])

//		if (map.faction_distribution_coeffs.Find(JAPAN))
//			max_japanese = ceil(relevant_clients * map.faction_distribution_coeffs[JAPAN])

	// fixes soviet-biased autobalance on verylow pop - Kachnov
	if (map && relevant_clients <= 7)
		if (map.faction_distribution_coeffs[SOVIET] > map.faction_distribution_coeffs[GERMAN])
			max_soviets = max_germans
		else if (map.faction_distribution_coeffs[GERMAN] > map.faction_distribution_coeffs[SOVIET])
			max_germans = max_soviets
		while ((max_germans+max_soviets) < relevant_clients)
			++max_soviets

	switch (side)
		if (PARTISAN)
			if (partisans_forceEnabled)
				return FALSE
			if (partisans >= max_partisans)
				return TRUE
			return FALSE
		if (CIVILIAN)
			if (civilians_forceEnabled)
				return FALSE
			if (civilians >= max_civilians)
				return TRUE
			return FALSE
		if (GERMAN, ITALIAN)
			if (germans_forceEnabled)
				return FALSE
			if ((germans+italians) >= max_germans)
				return TRUE
		if (SOVIET)
			if (soviets_forceEnabled)
				return FALSE
			if (soviets >= max_soviets)
				return TRUE
		if (UKRAINIAN)
			return TRUE

	return FALSE