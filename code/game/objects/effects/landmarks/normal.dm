
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
/////////////////
////russian/////
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
//////////////////////////////////////////////

		if ("endgame_exit")
			endgame_safespawns += loc
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

//Costume spawner landmarks
/obj/effect/landmark/costume/New() //costume spawner, selects a random subclass and disappears

	var/list/options = typesof(/obj/effect/landmark/costume)
	var/pick = options[rand(1,options.len)]
	new pick(loc)
	delete_me = TRUE