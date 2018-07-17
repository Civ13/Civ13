/mob/living/carbon/human/proc/selfheal()
	set category = "Tester"
	set name = "Heal Self"
	src << "<span class = 'good'>Please wait <b>5</b> seconds.</span>"
	if (do_after(src, 50, get_turf(src)))
		src << "<span class = 'good'>You've been fully healed.</span>"
		revive()

/mob/living/carbon/human/proc/selfrevive()
	set category = "Tester"
	set name = "Revive Self"
	src << "<span class = 'good'>Please wait <b>30</b> seconds.</span>"
	spawn (300)
		if (src)
			src << "<span class = 'good'>You've been fully healed/revived.</span>"
			revive()