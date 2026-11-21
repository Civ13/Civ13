/* Piranha swarms in jungle rivers.

A swarm warns before it hurts. The first bite is a nip; bites then grow while
someone stays in the water near the swarm, and only someone who keeps wading
in open water long after the warning can lose a foot or leg. Bites stop after
PIRANHA_CALM_TIME out of reach, and anyone in the air (a jump) is never bitten.
*/

// Time between bites on one person, from any swarm (ds).
#define PIRANHA_BITE_DELAY 30
// Out of reach this long and the next bite is a warning nip again (ds).
#define PIRANHA_CALM_TIME 600
// Brute of the warning nip, then of bite n: 2 + 2n, capped.
#define PIRANHA_NIP_DAMAGE 2
#define PIRANHA_BITE_CAP 14
// A limb can go only from this bite on, in open water, once it is this hurt.
#define PIRANHA_DELIMB_BITES 6
#define PIRANHA_DELIMB_HURT 0.6
#define PIRANHA_DELIMB_CHANCE 35
// River tiles per swarm when a nomads map is seeded.
#define PIRANHA_RIVER_TILES 60

/mob/living/human
	var/tmp/piranha_bites = 0
	var/tmp/piranha_last_bite = -PIRANHA_CALM_TIME

/mob/living/human/persistence_runtime_var(key)
	return (key in list("piranha_bites", "piranha_last_bite")) || ..()

/obj/structure/piranha
	name = "piranha"
	desc = "Dangerous carnivorous fish, they look hungry!"
	icon = 'icons/mob/fish.dmi'
	icon_state = "piranhas"
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/feeding = FALSE

/obj/structure/piranha/persistence_runtime_var(key)
	return key == "feeding" || ..()

/obj/structure/piranha/New()
	..()
	invisibility = 101

// Open water: every tile around is river too, away from banks and fords.
/proc/piranha_open_water(turf/T)
	if (!is_liquid_water(T))
		return FALSE
	if (istype(T, /turf/floor/beach/water/deep))
		return TRUE
	for (var/dir in alldirs)
		var/turf/N = get_step(T, dir)
		if (!is_liquid_water(N))
			return FALSE
	return TRUE

// Places count swarms, in open water where the list has any.
/proc/seed_piranhas(list/turfs, count)
	if (!islist(turfs) || !turfs.len)
		return
	var/list/open = list()
	for (var/turf/T in turfs)
		if (piranha_open_water(T))
			open += T
	if (!open.len)
		open = turfs
	for (var/i = 1, i <= count, i++)
		var/turf/T = safepick(open)
		if (T)
			new /obj/structure/piranha(T)

/obj/structure/piranha/proc/can_bite(mob/living/human/H)
	if (!istype(H) || H.stat == DEAD)
		return FALSE
	if (H.throwing) // jumping over the river
		return FALSE
	if (H.s_tone <= -175)
		return FALSE
	if (H.driver_vehicle || (H.riding && H.riding_mob))
		return FALSE
	var/turf/T = H.loc
	if (!is_liquid_water(T))
		return FALSE
	if (T.iscovered()) // bridges, boats and rafts
		return FALSE
	return TRUE

/obj/structure/piranha/proc/bite(mob/living/human/H)
	if (world.time - H.piranha_last_bite < PIRANHA_BITE_DELAY)
		return
	if (world.time - H.piranha_last_bite >= PIRANHA_CALM_TIME)
		H.piranha_bites = 0
	var/list/zones = list()
	for (var/zone in list("l_foot", "r_foot", "l_leg", "r_leg"))
		var/obj/item/organ/external/E = H.get_organ(zone)
		if (E && !E.is_stump())
			zones += zone
	if (!zones.len)
		return
	var/obj/item/organ/external/affecting = H.get_organ(pick(zones))
	H.piranha_bites++
	H.piranha_last_bite = world.time
	invisibility = 0
	if (H.piranha_bites == 1)
		H.apply_damage(PIRANHA_NIP_DAMAGE, BRUTE, affecting, H.run_armor_check(affecting, HIT_PIERCE), sharp=1)
		to_chat(H, SPAN_DANGER("Something nips your [affecting.name]! Piranhas - get out of the water!"))
		visible_message("<span class='notice'>Piranhas flash around [H]!</span>")
		return
	if (H.piranha_bites >= PIRANHA_DELIMB_BITES && piranha_open_water(H.loc) && affecting.brute_dam >= affecting.max_damage * PIRANHA_DELIMB_HURT && prob(PIRANHA_DELIMB_CHANCE))
		affecting.droplimb(FALSE, DROPLIMB_EDGE)
		visible_message("The piranhas bite off [H]'s [affecting]!")
		qdel(affecting)
		for (var/mob/living/human/NB in view(6, src))
			NB.adjust_mood(-(10))
		return
	var/damage = min(PIRANHA_NIP_DAMAGE + 2 * H.piranha_bites, PIRANHA_BITE_CAP)
	H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, HIT_PIERCE), sharp=1, edge=1)
	if (H.piranha_bites >= 4)
		visible_message("<span class='danger'>The water churns red as the piranhas tear at [H]'s [affecting.name]!</span>")
	else
		visible_message("<span class='notice'>The piranhas bite [H]'s [affecting.name]!</span>")

// Keeps biting anyone who stays in the water within a tile of the swarm.
/obj/structure/piranha/proc/feed()
	if (feeding)
		return
	feeding = TRUE
	spawn(0)
		while (!QDELETED(src))
			var/found = FALSE
			for (var/mob/living/human/H in range(1, src))
				if (can_bite(H))
					found = TRUE
					bite(H)
			if (!found)
				break
			sleep(PIRANHA_BITE_DELAY)
		if (!QDELETED(src))
			feeding = FALSE
			spawn(300)
				if (!QDELETED(src) && !feeding)
					invisibility = 101

/obj/structure/piranha/Crossed(M as mob|obj)
	for (var/obj/covers/CV in src.loc)
		if (CV.is_cover == TRUE)
			return
	if (!istype(get_turf(src), /turf/floor/beach/water))
		return
	if (istype(M, /mob/living/human))
		if (can_bite(M))
			feed()
		return
	else if (istype(M, /mob/living/simple_animal))
		invisibility = 0
		var/mob/living/simple_animal/SA = M
		if (SA.mob_size <= 10 && !istype(SA, /mob/living/simple_animal/mosquito)) //MOB_SMALL, MOB_MINISCULE and MOB_TINY)
			visible_message("<span class='notice'>The piranhas eat the [M] whole!</span>")
			qdel(M)
			spawn(300)
				invisibility = 101
			return
		else
			invisibility = 0
			SA.health--
			spawn(300)
				invisibility = 101
			return
	else if (istype(M, /obj/item/weapon/reagent_containers/food/snacks/meat))
		invisibility = 0
		visible_message("<span class='notice'>The piranhas devour the [M]!</span>")
		qdel(M)
		spawn(300)
			invisibility = 101
		return

#undef PIRANHA_BITE_DELAY
#undef PIRANHA_CALM_TIME
#undef PIRANHA_NIP_DAMAGE
#undef PIRANHA_BITE_CAP
#undef PIRANHA_DELIMB_BITES
#undef PIRANHA_DELIMB_HURT
#undef PIRANHA_DELIMB_CHANCE
