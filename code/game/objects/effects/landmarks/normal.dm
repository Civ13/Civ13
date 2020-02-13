
/obj/effect/landmark
	name = "landmark"
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "x2"
	anchored = 1.0

	simulated = FALSE
	invisibility = 101
	layer = 100
	var/delete_me = FALSE

/obj/effect/landmark/New()
	..()
	tag = text("landmark*[]", name)

	switch(name)			//some of these are probably obsolete
		if ("supplydrop")
			supplydrop_turfs += get_turf(src)
			qdel(src)
		if ("start")
			newplayer_start += loc
			delete_me = TRUE
			return
		if ("JoinLate")
			latejoin += loc
			delete_me = TRUE
			return
		if ("JoinLateGhost")
			if (!latejoin_turfs["Ghost"])
				latejoin_turfs["Ghost"] = list()
			latejoin_turfs["Ghost"] += loc
			qdel(src)
			return

		if ("JoinLate")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("treasure-mark")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("Observer-Start")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateFR")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRO")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateROM")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateROG")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateGR")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateAR")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		// TREASURY LANDMARKS
		if ("TreasuryFR")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("TreasuryRN")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("TreasurySP")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("TreasuryPT")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("TreasuryNL")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		// SUPPLY LANDMARKS
		if ("SupplyFR")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("SupplyRN")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("SupplySP")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("SupplyPT")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("SupplyNL")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		// CIVILIAN LANDMARKS
		if ("JoinLateCiv")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateCivA")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateCivB")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateCivC")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateCivD")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateCivE")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateCivF")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		// PIRATE LANDMARKS
		if ("JoinLateDM")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirate")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateCap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateQM")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateBoatswain")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateMaster")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateMidshipman")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateSurgeon")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateCarpenter")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePirateCook")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		// ROYAL NAVY LANDMARKS
		if ("JoinLateRN")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNNavy")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNCap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNQM")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNBoatswain")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNMaster")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNMidshipman")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNSurgeon")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNCarpenter")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRNCook")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return


		// SPANISH NAVY LANDMARKS
		if ("JoinLateSP")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPCap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPQM")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPBoatswain")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPMaster")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPMidshipman")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPSurgeon")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPCarpenter")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateSPCook")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		// DUTCH NAVY LANDMARKS
		if ("JoinLateNL")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLCap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLQM")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLBoatswain")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLMaster")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLMidshipman")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLSurgeon")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLCarpenter")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateNLCook")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		// PORTUGUESE NAVY LANDMARKS
		if ("JoinLatePT")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTCap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTQM")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTBoatswain")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTMaster")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTMidshipman")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTSurgeon")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTCarpenter")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLatePTCook")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		// NATIVE LANDMARKS
		if ("JoinLateIND")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateIND1")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateIND2")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateIND3")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateIND4")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateIND5")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateIND6")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
/////////////////
/////japanese//////

		if ("JoinLateJPCap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateJP")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateJPDoc")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateJPMP")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateJPLT")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
/////////////////
////russian/////
		if ("JoinLateRUCap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateRU")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateRU2")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateRU3")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateRUDoc")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateRUSap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
/////////////////
////german/////
		if ("JoinLateGECap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateGE")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

		if ("JoinLateGEDoc")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return
		if ("JoinLateGESap")
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			return

	landmarks_list += src
	return TRUE

/obj/effect/landmark/proc/delete()
	delete_me = TRUE

/obj/effect/landmark/initialize()
	..()
	if (delete_me)
		qdel(src)

/obj/effect/landmark/Destroy()
	landmarks_list -= src
	return ..()

/obj/effect/landmark/start
	name = "start"
	icon_state = "x"
	anchored = 1.0
	invisibility = 101

/obj/effect/landmark/start/New()
	..()
	tag = "start*[name]"
	return TRUE

/obj/effect/landmark/npctarget
	name = "npc target"
	icon_state = "x"
	anchored = 1.0
	invisibility = 101

var/global/list/faction_targets = list()

/obj/effect/landmark/npctarget/faction
	name = "faction target"
	icon_state = "f1"
	anchored = 1.0
	invisibility = 101
	var/faction = "none"
	New()
		..()
		spawn(200) //so you have time to edit
			faction_targets += list(list(src.name,src.faction,src.x,src.y,src.z))
			qdel(src)

//spawns a squad of soldiers + medic + squad leader
var/global/faction1_npcs = 0

var/global/faction2_npcs = 0
/obj/effect/landmark/npctarget/squad_spawner
	name = "squad spawner"
	icon_state = "squad_red"
	anchored = 1.0
	invisibility = 101
	var/list/members = list()
	var/timer = 3000
	var/active = TRUE
	var/faction = null
	New()
		..()
		spawning()

	proc/spawning()
		spawn(1500)
			spawning()
		if (!active)
			return
		if (faction == "faction1" && faction1_npcs>=150)
			return
		if (faction == "faction2" && faction2_npcs>=150)
			return
		if (map.faction1_can_cross_blocks() || map.faction2_can_cross_blocks())
			for(var/list/L in members)
				for(var/i=1, i<=L[1], i++)
					var/pt = L[2]
					new pt (loc)
			spawn(200)
				for(var/mob/living/simple_animal/hostile/human/HM in range(3,src))
					HM.charge()
			return
/obj/effect/landmark/npctarget/squad_spawner/american
	name = "american squad spawner"
	icon_state = "squad_blue"
	faction = "faction1"
	members = list(
		list(5,/mob/living/simple_animal/hostile/human/ww2_american),
		list(1,/mob/living/simple_animal/hostile/human/ww2_american/medic),
		list(1,/mob/living/simple_animal/hostile/human/ww2_american/mg),
		list(1,/mob/living/simple_animal/hostile/human/ww2_american/squad_leader),
	)

/obj/effect/landmark/npctarget/squad_spawner/japanese
	name = "japanese squad spawner"
	icon_state = "squad_red"
	faction = "faction2"
	members = list(
		list(2,/mob/living/simple_animal/hostile/human/ww2_jap),
		list(3,/mob/living/simple_animal/hostile/human/ww2_jap/summer),
		list(1,/mob/living/simple_animal/hostile/human/ww2_jap/summer/medic),
		list(1,/mob/living/simple_animal/hostile/human/ww2_jap/mg),
		list(1,/mob/living/simple_animal/hostile/human/ww2_jap/squad_leader),
	)
