// Shy spawning: wild spawns and births skip a spot that already holds a crowd
// of animals of any species, so herds spread out instead of piling up. Each
// breeding animal still has its own same-species limit and global cap.
#define ANIMAL_SHY_RANGE 7 // a 15x15 square around the spot
#define ANIMAL_SHY_LIMIT 8 // living animals allowed in that square

// TRUE when the square around T would hold more than ANIMAL_SHY_LIMIT living
// animals after `adding` more arrive. Human NPCs (raiders, soldiers) and
// player-controlled animals do not count.
/proc/animal_spot_crowded(turf/T, adding = 1)
	T = get_turf(T)
	if (!T)
		return FALSE
	var/count = adding
	for (var/mob/living/simple_animal/A in range(ANIMAL_SHY_RANGE, T))
		if (A.stat == DEAD || A.client || istype(A, /mob/living/simple_animal/hostile/human))
			continue
		count++
		if (count > ANIMAL_SHY_LIMIT)
			return TRUE
	return FALSE

#undef ANIMAL_SHY_RANGE
#undef ANIMAL_SHY_LIMIT
