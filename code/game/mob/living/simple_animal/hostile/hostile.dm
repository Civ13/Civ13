/mob/living/simple_animal/hostile
	faction = "hostile"
	stop_automated_movement_when_pulled = FALSE
	a_intent = I_HARM
	behaviour = "hunt"
	var/atom/target
	//pathfind_target inherited from /mob/living/simple_animal
//These vars are related to how mobs locate and target
	var/list/wanted_objects = list() //A list of objects that will be checked against to attack, should we have search_objects enabled
	var/stat_attack = 0 //Mobs with stat_attack to 1 will attempt to attack things that are unconscious, Mobs with stat_attack set to 2 will attempt to attack the dead.

/mob/living/simple_animal/hostile/proc/Found(var/atom/A)//This is here as a potential override to pick a specific target if available
	return