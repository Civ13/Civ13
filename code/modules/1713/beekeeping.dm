/obj/structure/beehive
	name = "beehive"
	desc = "A wooden box where beehives are kept for honey production and bee breeding."
	icon = 'icons/farming/beekeeping.dmi'
	icon_state = "apiary"
	density = 1
	anchored = 1

	var/closed = 0
	var/bee_count = 0 // Percent
	var/smoked = 0 // Timer
	var/honeycombs = 0 // Percent
	var/frames = 0
	var/maxFrames = 5

/obj/structure/beehive/update_icon()
	overlays.Cut()
	icon_state = "beehive"
	if (closed)
		overlays += "lid"
	if (!smoked)
		switch (bee_count)
			if (1 to 20)
				overlays += "bees1"
			if (21 to 40)
				overlays += "bees2"
			if (41 to 60)
				overlays += "bees3"
			if (61 to 80)
				overlays += "bees4"
			if (81 to 100)
				overlays += "bees5"

/obj/structure/beehive/examine(var/mob/user)
	..()
	if (!closed)
		to_chat(user, "The lid is open.")
	var/mob/living/human/H = user
	if (H.getStatCoeff("farming")>= 1.6)
		to_chat(user, "\The [src] is [bee_count ? "[round(bee_count)]% full" : "empty"].[bee_count > 90 ? " Colony is ready to split." : ""]")
		if (frames)
			to_chat(user, "[frames] frames installed, [round(honeycombs / 100)] filled.")
			if (honeycombs < frames * 100)
				to_chat(user, "Next frame is [round(honeycombs % 100)]% full.")
		else
			to_chat(user, "No frames installed.")
		if (smoked)
			to_chat(user, "The hive is smoked.")
		return

/obj/structure/beehive/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/crowbar))
		closed = !closed
		user.visible_message(SPAN_NOTICE("[user] [closed ? "closes" : "opens"] \the [src]."), SPAN_NOTICE("You [closed ? "close" : "open"] \the [src]."))
		update_icon()
		return

	else if (istype(I, /obj/item/weapon/wrench))
		anchored = !anchored
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		user.visible_message(SPAN_NOTICE("[user] [anchored ? "wrenches" : "unwrenches"] \the [src]."), SPAN_NOTICE("You [anchored ? "wrench" : "unwrench"] \the [src]."))
		return

	else if (istype(I, /obj/item/bee_smoker))
		if (closed)
			to_chat(user, SPAN_NOTICE("You need to open \the [src] with a crowbar before smoking the bees."))
			return
		user.visible_message(SPAN_NOTICE("\The [user] smokes the bees in \the [src]."), SPAN_NOTICE("You smoke the bees in \the [src]."))
		smoked = 30
		update_icon()
		return

	else if (istype(I, /obj/item/honey_frame))
		if (closed)
			to_chat(user, SPAN_NOTICE("You need to open \the [src] with a crowbar before inserting \the [I]."))
			return
		if (frames >= maxFrames)
			to_chat(user, SPAN_WARNING("There is no place for an another frame."))
			return
		var/obj/item/honey_frame/HF = I
		if (HF.honey)
			to_chat(user, SPAN_NOTICE("\The [I] is full with beeswax and honey, empty it in the extractor first."))
			return
		++frames
		user.visible_message(SPAN_NOTICE("\The [user] loads \the [I] into \the [src]."), SPAN_NOTICE("You load \the [I] into \the [src]."))
		update_icon()
		user.drop_from_inventory(I)
		qdel(I)
		return

	else if(istype(I, /obj/item/bee_jar))
		var/obj/item/bee_jar/B = I
		if (B.full && bee_count)
			to_chat(user, SPAN_NOTICE("\The [src] already has bees inside."))
			return
		if (!B.full && bee_count < 90)
			to_chat(user, SPAN_NOTICE("\The [src] is not ready to split."))
			return
		if (!B.full && !smoked)
			to_chat(user, SPAN_NOTICE("Smoke \the [src] first!"))
			return
		if (closed)
			to_chat(user, SPAN_NOTICE("You need to open \the [src] with a crowbar before moving the bees."))
			return
		if (B.full)
			user.visible_message(SPAN_NOTICE("\The [user] puts the queen and the bees from \the [I] into \the [src]."), SPAN_NOTICE("You put the queen and the bees from \the [I] into \the [src]."))
			bee_count = 20
			B.empty()
		else
			user.visible_message(SPAN_NOTICE("\The [user] puts bees and larvae from \the [src] into \the [I]."), SPAN_NOTICE("You put bees and larvae from \the [src] into \the [I]."))
			bee_count /= 2
			B.fill()
		update_icon()
		return

	else if (istype(I, /obj/item/weapon/hammer) || istype(I, /obj/item/weapon/screwdriver))
		if (bee_count)
			to_chat(user, SPAN_NOTICE("You can't dismantle \the [src] with these bees inside."))
			return
		to_chat(user, SPAN_NOTICE("You start dismantling \the [src]..."))
		playsound(loc, 'sound/items/Screwdriver.ogg', 50, 1)
		if(do_after(user, 30))
			user.visible_message(SPAN_NOTICE("\The [user] dismantles \the [src]."), SPAN_NOTICE("You dismantle \the [src]."))
			for (var/i=1, i<=6, i++)
				new /obj/item/stack/material/wood(loc)
			qdel(src)
		return

/obj/structure/beehive/attack_hand(var/mob/user)
	if(!closed)
		if(honeycombs < 100)
			to_chat(user, SPAN_NOTICE("There are no filled honeycombs."))
			return
		if(!smoked && bee_count)
			to_chat(user, SPAN_NOTICE("The bees won't let you take the honeycombs out like this, smoke them first."))
			return
		user.visible_message(SPAN_NOTICE("\The [user] starts taking the honeycombs out of \the [src]."), SPAN_NOTICE("You start taking the honeycombs out of \the [src]..."))
		while (honeycombs >= 100 && do_after(user, 30))
			new /obj/item/honey_frame/filled(loc)
			honeycombs -= 100
			--frames
			update_icon()
		if (honeycombs < 100)
			to_chat(user, SPAN_NOTICE("You take all filled honeycombs out."))
		return

/obj/structure/beehive/Process() // All processes seem to be a lie
	spawn(30)
		visible_message(SPAN_NOTICE("DEBUG: Process is working."))
	if(closed && !smoked && bee_count)
		pollinate_flowers()
		update_icon()
	smoked = max(0, smoked - 1)
	if(!smoked && bee_count)
		bee_count = min(bee_count * 1.005, 100)
		update_icon()

/obj/structure/beehive/proc/pollinate_flowers()
	var/coef = bee_count / 100
	var/trays = 0
	for(var/obj/structure/farming/plant/P in view(7, src))
		if(P.stage != 8)
			P.plant_nutrition += 0.05 * coef
			++trays
	honeycombs = min(honeycombs + 0.1 * coef * min(trays, 5), frames * 100)

/obj/item/bee_smoker
	name = "bee smoker"
	desc = "A device used to calm down bees before harvesting honey."
	icon = 'icons/farming/beekeeping.dmi'
	icon_state = "beesmoker"
	w_class = ITEM_SIZE_SMALL

/obj/item/honey_frame
	name = "beehive frame"
	desc = "A frame for the beehive that the bees will fill with honeycombs."
	icon = 'icons/farming/beekeeping.dmi'
	icon_state = "honeyframe"
	w_class = ITEM_SIZE_SMALL

	var/honey = 0

/obj/item/honey_frame/filled/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/material/kitchen/utensil/knife/))
		user.visible_message(SPAN_NOTICE("\The [user] starts taking the honeycombs out of \the [src]."), SPAN_NOTICE("You start taking the honeycombs out of \the [src]..."))
		if(!do_after(user, 90))
			return
		to_chat(user, SPAN_NOTICE("You take all filled honeycombs out."))
		new /obj/item/weapon/reagent_containers/food/snacks/honeycomb(loc)
		new /obj/item/honey_frame(loc)
		qdel(src)
		return

/obj/item/honey_frame/filled
	name = "filled beehive frame"
	desc = "A frame for the beehive that the bees have filled with honeycombs."
	honey = 20

/obj/item/honey_frame/filled/New()
	..()
	overlays += "honeycomb"

/obj/item/bee_jar
	name = "bee jar"
	desc = "Contains a queen bee and some worker bees. Everything you'll need to start a hive!"
	icon = 'icons/farming/beekeeping.dmi'
	icon_state = "beejar"
	var/full = 1

/obj/item/bee_jar/New()
	..()
	overlays += "beejar-full"

/obj/item/bee_jar/proc/empty()
	full = 0
	name = "empty bee pack"
	desc = "A jar for moving bees. It's empty."
	overlays.Cut()

/obj/item/bee_jar/proc/fill()
	full = initial(full)
	name = initial(name)
	desc = initial(desc)
	overlays.Cut()
	overlays += "beejar-full"