
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
	if (name != "landmark")
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
		else if ("Paradrop")
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
