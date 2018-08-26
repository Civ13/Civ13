
var/list/dreams = list(
	"Eggs", "Home", "Homeland",
	)

/mob/living/carbon/proc/dream()
	dreaming = TRUE

	spawn(0)
		for (var/i = rand(1,4),i > 0, i--)
			src << "<span class = 'notice'><i>... [pick(dreams)] ...</i></span>"
			sleep(rand(40,70))
			if (paralysis <= 0)
				dreaming = FALSE
				return FALSE
		dreaming = FALSE
		return TRUE

/mob/living/carbon/proc/handle_dreams()
	if (client && !dreaming && prob(5))
		dream()

/mob/living/carbon/var/dreaming = FALSE
