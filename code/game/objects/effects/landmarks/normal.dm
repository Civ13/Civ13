
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
	if (name != "landmark" && !istype(src,/obj/effect/landmark/npctarget/squad_spawner))
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

/obj/effect/landmark/npctarget/faction
	name = "faction target"
	icon_state = "f1"
	var/faction = "none"
	New()
		spawn(150)
			if(map && src)
				map.faction_targets += list(list(src.name,src.faction,src.loc.x,src.loc.y,src.loc.z))
			..()

/obj/effect/landmark/npctarget/faction/all
	name = "all faction target"
	faction = "all"
