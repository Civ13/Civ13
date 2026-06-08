
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
	if (name != "landmark" && !istype(src,/obj/effect/landmark/npctarget) && !istype(src,/obj/effect/landmark/npctarget/squad_spawner))
		if (name == "supplydrop")
			supplydrop_turfs += get_turf(src)
			qdel(src)
		else if (name == "start")
			newplayer_start += loc
			delete_me = TRUE
			return
		else if (name == "JoinLate")
			latejoin += loc
			delete_me = TRUE
			return
		else if (name == "Paradrop")
			paradrop_landmarks += loc
			if (!latejoin_turfs[name])
				latejoin_turfs[name] = list()
			latejoin_turfs[name] += loc
			qdel(src)
			delete_me = TRUE
			return
		else
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
	var/controller = "none"
	var/capturing = FALSE //if capturing is active or not

/obj/effect/landmark/npctarget/faction
	name = "faction target"
	icon_state = "f1"
	var/faction = "none"

/obj/effect/landmark/npctarget/faction/all
	name = "all faction target"
	faction = "all"

/obj/effect/landmark/npctarget/proc/capture()
	if(!capturing)
		return
	var/list/factions_here = list()
	for(var/mob/M in range(3, src))
		if(M.stat == DEAD)
			continue
		var/mob_faction = null
		if(ishuman(M))
			var/mob/living/human/H = M
			mob_faction = H.faction_text
		else if(istype(M, /mob/living/simple_animal/hostile/human))
			var/mob/living/simple_animal/hostile/human/SH = M
			mob_faction = SH.faction
		if(mob_faction)
			factions_here[mob_faction] = TRUE
	if(factions_here.len == 1)
		for(var/faction_key in factions_here)
			controller = faction_key
			break
	else if(factions_here.len == 0)
		controller = "none"

/obj/effect/landmark/npctarget/proc/capture_loop()
	set waitfor = FALSE
	while(src)
		capture()
		sleep(300)

/obj/effect/landmark/npctarget/faction/New()
	..()
	capturing = TRUE
	spawn(150)
		if(map && src)
			map.faction_targets += list(list(src.name, src.faction, src.loc.x, src.loc.y, src.loc.z))
		capture_loop()