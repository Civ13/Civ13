/obj/train_track
	name = "train track"
	icon = 'icons/obj/structures.dmi'
	icon_state = "traintrack"
	density = FALSE
	anchored = 1.0
	w_class = 3
	layer = 2.01 //just above floors
	//	flags = CONDUCT

/obj/train_track/New()
	..()
	#ifdef USE_TRAIN_LIGHTS
	set_light(2, 3, "#a0a080") // range, power, color
	#endif

/obj/train_track/ex_act(severity)
	switch (severity)
		if (1.0)
			qdel(src)
		if (2.0)
			if (prob(75))
				qdel(src)
		if (3.0)
			if (prob(25))
				qdel(src)