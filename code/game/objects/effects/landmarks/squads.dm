
//spawns a squad of soldiers + medic + squad leader
var/global/faction1_npcs = 0
var/global/faction1_npc_limit = 25
var/global/faction2_npcs = 0
var/global/faction2_npc_limit = 25
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
		if (faction == "faction1" && faction1_npcs>=faction1_npc_limit)
			return
		if (faction == "faction2" && faction2_npcs>=faction2_npc_limit)
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
		list(3,/mob/living/simple_animal/hostile/human/ww2_american),
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
		list(1,/mob/living/simple_animal/hostile/human/ww2_jap/summer),
		list(1,/mob/living/simple_animal/hostile/human/ww2_jap/summer/medic),
		list(1,/mob/living/simple_animal/hostile/human/ww2_jap/mg),
		list(1,/mob/living/simple_animal/hostile/human/ww2_jap/squad_leader),
	)

/obj/effect/landmark/npctarget/squad_spawner/soviet
	name = "soviet squad spawner"
	icon_state = "squad_red"
	faction = "faction1"
	members = list(
		list(3,/mob/living/simple_animal/hostile/human/ww2_soviet),
		list(1,/mob/living/simple_animal/hostile/human/ww2_soviet/medic),
		list(1,/mob/living/simple_animal/hostile/human/ww2_soviet/mg),
		list(1,/mob/living/simple_animal/hostile/human/ww2_soviet/squad_leader),
	)

/obj/effect/landmark/npctarget/squad_spawner/german
	name = "german squad spawner"
	icon_state = "squad_blue"
	faction = "faction2"
	members = list(
		list(3,/mob/living/simple_animal/hostile/human/ww2_german),
		list(1,/mob/living/simple_animal/hostile/human/ww2_german/medic),
		list(1,/mob/living/simple_animal/hostile/human/ww2_german/mg),
		list(1,/mob/living/simple_animal/hostile/human/ww2_german/squad_leader),
	)
