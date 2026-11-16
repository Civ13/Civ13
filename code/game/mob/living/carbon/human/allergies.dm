// Allergy traits (traits.dm). Bee Sting Allergy and Sting Resistant change
// bee stings (wild_bees.dm); the two here react to pollen and to shellfish.

/mob/living/human
	var/tmp/next_hay_fever = 0

/mob/living/human/persistence_runtime_var(key)
	return key == "next_hay_fever" || ..()

// Pollen season: spring on four-season maps, the wet season elsewhere.
/proc/pollen_season()
	return season_is_temperate() ? season == SEASON_SPRING : season == SEASON_WET

// Called from Life (handle_playstyle_traits): at most one sneezing fit every
// few minutes, outdoors in pollen season.
/mob/living/human/proc/handle_allergy_traits()
	if (!find_trait("Hay Fever") || stat != CONSCIOUS || world.time < next_hay_fever)
		return
	next_hay_fever = world.time + rand(3 MINUTES, 6 MINUTES)
	if (!pollen_season())
		return
	var/turf/T = get_turf(src)
	if (!T || !ecology_outdoor_climate(T))
		return
	emote("sneeze")
	eye_blurry = max(eye_blurry, 3)
	to_chat(src, SPAN_WARNING("Pollen tickles your nose and your eyes water."))

/proc/is_shellfish(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawcrab) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawlobster)

/mob/living/human/proc/shellfish_reaction()
	to_chat(src, SPAN_DANGER("Your skin breaks out in itchy welts and your stomach heaves!"))
	adjustHalLoss(10)
	addtimer(CALLBACK(src, PROC_REF(vomit)), rand(20, 50))
