// Flu never puts a character to sleep or leaves them paralysed: its
// drowsiness only blurs the eyes, and the fever drops them to the ground at
// most FLU_MAX_DOWNS time(s) per illness, for a couple of seconds
// (chat feedback 2026-11-17: sick players spent minutes unable to act).
#define FLU_MAX_DOWNS 1
#define FLU_DOWN_TIME 2

/mob/living/human/var/tmp/flu_downs = 0

/mob/living/human/proc/flu_haze(amount)
	eye_blurry = max(eye_blurry, amount)

/mob/living/human/proc/flu_knockdown()
	if (flu_downs >= FLU_MAX_DOWNS)
		return FALSE
	flu_downs++
	Weaken(FLU_DOWN_TIME)
	to_chat(src, SPAN_WARNING("The fever drops you to the ground. You will be back on your feet in a moment; rest in a bed to get over the flu sooner."))
	return TRUE

/mob/living/human/proc/handle_disease()
	if (stat == DEAD)
		return
	handle_death_weakness()
	if (handle_immunity())
		return
	if (droid || (disease_type in disease_immunity))
		clear_disease()
		return
	if (is_severe_disease())
		handle_severe_disease()
		return
	if (disease && disease_type == "worms")
		handle_worms()
		return
	if (!disease)
		disease_course = 0
		acquire_nearby_disease()
	if (inducedSSD && disease && disease_progression <= 15)
		disease = 0
		disease_type = "none"
		disease_progression = 0
		bodytemperature = 310.055
		disease_treatment = 0

	if (disease == TRUE)
		if (disease_type == "none")
			disease = FALSE
		else if (disease_type == "flu")
			var/flu_step = 2
			if (!disease_treatment)
				flu_step = resting_in_bed() ? 1 : 0.5 // bed rest halves the illness
			disease_progression += flu_step
			// first 2 minutes
			if (disease_progression >= 25 && disease_progression - flu_step < 25)
				to_chat(src, "You feel a little feverish.")
				flu_downs = 0
				disease_treatment = 0
				flu_haze(10)
				bodytemperature = 311.35
			//4 more minutes
			if (prob(1))
				emote("sniff")
				flu_haze(5)
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 312.15 && prob(10))
				to_chat(src, "You feel like your fever is getting worse!")
				apply_effect(5, AGONY, FALSE)
				flu_haze(5)
				emote(pick("cough","sneeze"))
				bodytemperature = 312.15
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 313.15 && prob(1))
				to_chat(src, "You feel your body burning up from fever!")
				apply_effect(10, AGONY, FALSE)
				flu_haze(5)
				emote(pick("cough","sneeze"))
				flu_knockdown()
				bodytemperature = 313.15
			// 2 more minutes
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 313.15 && prob(8))
				to_chat(src, "You feel your fever going down.")
				flu_haze(5)
				emote(pick("cough","sneeze"))
				bodytemperature = 312.35
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 312.15 && prob(2))
				to_chat(src, "You feel your fever going down.")
				emote(pick("cough","sneeze"))
				bodytemperature = 310.055
			else if (disease_progression >= 240 && prob(35))
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				to_chat(src, "<big><font color='#3d9e3d'><b>You feel much better now! The illness is gone.</b></font></big>")
				disease_treatment = 0
				flu_downs = 0
				disease_resistance["flu"] = 100 // Riding it out protects for a while.
				if (prob(25))
					disease_immunity += "flu"

		else if (disease_type == "zombie")
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				to_chat(src, "<big><font color='#3d9e3d'><b>You feel much better now! The illness is gone.</b></font></big>")
				disease_treatment = 0

			if (disease_progression == 25)
				to_chat(src, "You feel your temperature rising.")
				apply_effect(10, DROWSY, FALSE)
				bodytemperature = 311.35
			if (prob(1))
				apply_effect(7, DROWSY, FALSE)
			else if (disease_progression >= 60 && disease_progression < 140 && prob(10))
				to_chat(src, pick("You feel like your fever is getting worse!","Your head hurts so much!"))
				adjustBrainLoss(rand(2,3))
				apply_effect(8, AGONY, FALSE)
				bodytemperature = 313.15
			else if (disease_progression >= 140 && disease_progression < 200 && prob(1) && !disease_treatment)
				adjustBrainLoss(rand(7,10))
				to_chat(src, "<big>[pick("You feel your body burning up!","Your head is pounding!")]</big>")
				apply_effect(12, AGONY, FALSE)
				bodytemperature = 314.15

			else if (disease_progression >= 200 && disease_progression < 240 && prob(8) && !disease_treatment)
				to_chat(src, "You feel your fever going down.")
				adjustBrainLoss(rand(4,6))
				apply_effect(6, DROWSY, FALSE)
				bodytemperature = 313.35
			else if (disease_progression >= 240 && prob(50) && !istype(get_area(src), /area/caribbean/admin))
				adjustBrainLoss(200)
				var/mob/living/simple_animal/hostile/human/zombie/playerzombie //make a var for the zombie
				playerzombie = new /mob/living/simple_animal/hostile/human/zombie/ //make a zombie!
				visible_message("<big>[src] turns into a zombie!</big>")
				//transferring vars.
				playerzombie.loc = loc
				playerzombie.name = "[real_name]'s zombie"
				strip()
