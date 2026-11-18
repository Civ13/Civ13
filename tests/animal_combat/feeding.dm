// Wild feeding (code/modules/ecology/wild_feeding.dm): grazing grows back,
// seed eaters and desert grazers forage in the wild, and deaths are tallied by cause.

/proc/feeding_clear()
	for (var/mob/living/M in world)
		M.loc = null
	for (var/obj/structure/wild/W in world)
		qdel(W)
	for (var/turf/T in block(locate(1, 1, 1), locate(8, 8, 1)))
		T.ChangeTurf(/turf/floor/plating)

// Runs check_food until the animal eats or the tries run out (eating is a dice roll).
/proc/feeding_until_fed(mob/living/simple_animal/A, start_hunger = 100)
	A.simplehunger = start_hunger
	for (var/i = 1, i <= 60, i++)
		A.check_food()
		if (A.simplehunger > start_hunger)
			return TRUE
	return FALSE

/proc/combat_feeding_checks()
	// A grazer eats grass; the tile stays grass and grows back.
	feeding_clear()
	var/turf/floor/G = locate(4, 4, 1)
	G = G.ChangeTurf(/turf/floor/grass)
	var/mob/living/simple_animal/sheep/S = new(locate(3, 4, 1))
	S.stop_automated_movement = TRUE
	combat_assert(feeding_until_fed(S), "Sheep did not graze beside grass")
	G = locate(4, 4, 1)
	combat_assert(istype(G, /turf/floor/grass), "Grazing turned grass into [G.type]")
	combat_assert(!G.pasture_ready() && G.grazed_until > world.time, "Grazed grass was ready again at once")
	combat_assert(!feeding_until_fed(S), "Sheep grazed the same grass twice")
	G.grazed_until = world.time
	combat_assert(G.pasture_ready(), "Grazed grass did not grow back")

	// Winter grass is pasture too.
	feeding_clear()
	var/turf/floor/WG = locate(4, 4, 1)
	WG = WG.ChangeTurf(/turf/floor/winter/grass)
	var/mob/living/simple_animal/deer/D = new(locate(3, 4, 1))
	D.stop_automated_movement = TRUE
	combat_assert(feeding_until_fed(D), "Deer did not graze winter grass")

	// Seed eaters forage seeds in the grass with no crops anywhere.
	feeding_clear()
	G = locate(4, 4, 1)
	G = G.ChangeTurf(/turf/floor/grass)
	var/mob/living/simple_animal/rabbit/R = new(locate(3, 4, 1))
	R.stop_automated_movement = TRUE
	combat_assert(feeding_until_fed(R), "Rabbit found nothing to eat in the grass")
	G = locate(4, 4, 1)
	combat_assert(istype(G, /turf/floor/grass) && !G.pasture_ready(), "Rabbit foraging did not graze the grass down")

	// Wild plants feed seed eaters and grazers; berry bushes and dead plants do not.
	feeding_clear()
	var/obj/structure/wild/smallbush/B = new(locate(4, 4, 1))
	R = new(locate(3, 4, 1))
	R.stop_automated_movement = TRUE
	combat_assert(feeding_until_fed(R), "Rabbit did not browse a bush")
	qdel(B)
	new /obj/structure/wild/tree/cactus(locate(4, 4, 1))
	var/mob/living/simple_animal/camel/C = new(locate(3, 4, 1))
	C.stop_automated_movement = TRUE
	combat_assert(feeding_until_fed(C), "Camel did not browse a desert cactus")
	combat_assert(!wild_browse_plant(new /obj/structure/wild/berrybush(locate(6, 6, 1))), "Animals would strip a berry bush")
	combat_assert(!wild_browse_plant(new /obj/structure/wild/jungle/acacia/dead(locate(6, 7, 1))), "Animals would browse a dead tree")
	// Meat eaters do not browse.
	var/mob/living/simple_animal/hostile/wolf/W = new(locate(5, 4, 1))
	combat_assert(!W.forage_wild(), "A wolf browsed a plant")

	// Deaths are tallied by cause.
	feeding_clear()
	wildlife_deaths.causes = list()
	wildlife_deaths.starved = list()
	var/mob/living/simple_animal/sheep/starving = new(locate(2, 2, 1))
	starving.simplehunger = 0
	starving.adjustBruteLoss(starving.maxHealth - 1)
	starving.Life()
	combat_assert(starving.stat == DEAD, "Starving sheep did not die")
	var/mob/living/simple_animal/deer/prey = new(locate(4, 2, 1))
	var/mob/living/simple_animal/hostile/wolf/hunter = new(locate(5, 2, 1))
	hunter.melee_damage_lower = 500
	hunter.melee_damage_upper = 500
	hunter.npc_set_combat_target(prey)
	hunter.AttackingTarget()
	combat_assert(prey.stat == DEAD, "Wolf did not kill the prey")
	var/mob/living/human/H = new(locate(7, 7, 1))
	var/mob/living/simple_animal/rabbit/hunted = new(locate(6, 2, 1))
	hunted.lastattacker = H
	hunted.adjustBruteLoss(500)
	var/mob/living/simple_animal/rabbit/other = new(locate(7, 2, 1))
	other.adjustBruteLoss(500)
	combat_assert(wildlife_deaths.causes["starvation"] == 1 && wildlife_deaths.causes["predators"] == 1 && wildlife_deaths.causes["people"] == 1 && wildlife_deaths.causes["other"] == 1, "Death causes were miscounted: [json_encode(wildlife_deaths.causes)]")
	combat_assert(wildlife_deaths.starved.len == 1, "Starved species were miscounted: [json_encode(wildlife_deaths.starved)]")
	combat_assert(findtext(wildlife_deaths.summary(), "4 animal deaths"), "Summary left deaths out: [wildlife_deaths.summary()]")
	// The hourly report writes the tally and starts a new hour.
	wildlife_deaths.period_start = world.time - 36001
	combat_assert(wildlife_deaths.tick() && findtext(wildlife_deaths.last_report, "4 animal deaths") && !wildlife_deaths.causes.len, "Hourly report did not write and reset the tally")
	combat_assert(!wildlife_deaths.tick(), "Report repeated within the hour")
	feeding_clear()
