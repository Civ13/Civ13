// Fine placement: nudge furniture, wall pictures and things on the floor a few
// pixels so a room can be laid out rather than gridded. The offset is kept
// within NUDGE_LIMIT of the object's own snap point (a wall sign keeps its 32
// pixel step onto the wall) and saves with the object's pixel_x and pixel_y.

#define NUDGE_LIMIT 8
#define NUDGE_STEP 2

/proc/nudge_allowed(obj/O)
	if (!O || !isturf(O.loc))
		return FALSE
	if (istype(O, /obj/item))
		return TRUE
	return istype(O, /obj/structure/bed) || istype(O, /obj/structure/plant_pot) || istype(O, /obj/structure/sign) || istype(O, /obj/structure/painting_frame) || istype(O, /obj/structure/religious) || istype(O, /obj/structure/closet) || istype(O, /obj/structure/bookcase) || istype(O, /obj/structure/lamp) || istype(O, /obj/structure/curtain) || istype(O, /obj/structure/banner) || istype(O, /obj/structure/poster) || istype(O, /obj/structure/brazier) || istype(O, /obj/structure/torch_stand) || istype(O, /obj/structure/mirror) || istype(O, /obj/structure/noticeboard)

// The nearest 32 pixel step: where the object snaps on its tile or wall.
/proc/nudge_base(offset)
	return round((offset + 16) / 32) * 32

/proc/nudge_offset(offset, delta)
	var/base = nudge_base(offset)
	return clamp(offset + delta, base - NUDGE_LIMIT, base + NUDGE_LIMIT)

/mob/living/human/verb/nudge_object(obj/O as obj in view(1))
	set name = "Nudge Object"
	set category = "IC"
	set desc = "Move a piece of furniture, a picture or a thing on the floor a few pixels."
	if (stat != CONSCIOUS || restrained() || !Adjacent(O))
		return
	if (!nudge_allowed(O))
		to_chat(src, "<span class='warning'>You can't nudge \the [O].</span>")
		return
	while (TRUE)
		var/choice = WWinput(src, "Nudge \the [O] by [NUDGE_STEP] pixels, up to [NUDGE_LIMIT] from where it sits on the grid.", "Nudge", "Done", list("Up", "Down", "Left", "Right", "Reset", "Done"))
		if (!choice || choice == "Done" || stat != CONSCIOUS || !Adjacent(O) || !nudge_allowed(O))
			return
		switch (choice)
			if ("Up")
				O.pixel_y = nudge_offset(O.pixel_y, NUDGE_STEP)
			if ("Down")
				O.pixel_y = nudge_offset(O.pixel_y, -NUDGE_STEP)
			if ("Right")
				O.pixel_x = nudge_offset(O.pixel_x, NUDGE_STEP)
			if ("Left")
				O.pixel_x = nudge_offset(O.pixel_x, -NUDGE_STEP)
			if ("Reset")
				O.pixel_x = nudge_base(O.pixel_x)
				O.pixel_y = nudge_base(O.pixel_y)

#undef NUDGE_LIMIT
#undef NUDGE_STEP
