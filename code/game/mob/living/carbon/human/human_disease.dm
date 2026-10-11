/mob/living/human/proc/handle_disease()
	if (stat == DEAD)
		return
	if (droid || (disease_type in disease_immunity))
		clear_disease()
		return
	if (is_severe_disease())
		handle_severe_disease()
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
			mood -= 0.1
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease_progression += 2
			// first 2 minutes
			if (disease_progression == 25)
				to_chat(src, "You feel a little feverish.")
				disease_treatment = 0
				apply_effect(10, DROWSY, FALSE)
				bodytemperature = 311.35
			//4 more minutes
			if (prob(1))
				emote("sniff")
				apply_effect(5, DROWSY, FALSE)
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 312.15 && prob(10))
				to_chat(src, "You feel like your fever is getting worse!")
				apply_effect(5, AGONY, FALSE)
				apply_effect(5, DROWSY, FALSE)
				emote(pick("cough","sneeze"))
				bodytemperature = 312.15
			else if (disease_progression >= 60 && disease_progression < 180 && bodytemperature < 313.15 && prob(1))
				adjustBrainLoss(rand(7,10))
				to_chat(src, "You feel your body burning up from fever!")
				apply_effect(10, AGONY, FALSE)
				apply_effect(5, DROWSY, FALSE)
				emote(pick("cough","sneeze"))
				Weaken(5)
				bodytemperature = 313.15
			// 2 more minutes
			else if (disease_progression >= 180 && disease_progression < 240 && bodytemperature >= 313.15 && prob(8))
				to_chat(src, "You feel your fever going down.")
				apply_effect(5, DROWSY, FALSE)
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
				to_chat(src, "You feel much better now! The disease is finally gone!")
				disease_treatment = 0
				if (prob(25))
					disease_immunity += "flu"

		else if (disease_type == "zombie")
			mood -= 0.15
			if (!disease_treatment)
				disease_progression += 0.5
			else
				disease = 0
				disease_type = "none"
				disease_progression = 0
				bodytemperature = 310.055
				to_chat(src, "You feel much better now! The disease is finally gone!")
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
