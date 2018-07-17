/mob/living/carbon/human/test

/mob/living/carbon/human/test/New()
	..()
	spawn while (1)
		sleep(12)
		step(src, pick(NORTH,EAST,SOUTH,WEST))

/mob/living/carbon/human/test/lastMovedRecently()
	return 1