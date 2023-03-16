/obj/roof
	name = "wood roof"
	desc = "A wooden roof."
	icon = 'icons/turf/roofs.dmi'
	icon_state = "wood_dm"
	var/overlay_state = "wood"
	var/passable = TRUE
	var/origin_density = FALSE
	var/not_movable = TRUE //if it can be removed by wrenches
	var/health = 100
	is_cover = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 10.1
	level = 2
	var/amount = FALSE
	var/wall = FALSE
	var/wood = TRUE
	var/onfire = FALSE
//	invisibility = 101
	flammable = TRUE
	var/current_area_type = /area/caribbean
	var/image/roof_overlay

/obj/roof/attackby(obj/item/weapon/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	user.do_attack_animation(src)
	playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
	if (flammable)
		if (istype(W, /obj/item/flashlight/torch))
			var/obj/item/flashlight/torch/T = W
			if (T.on)
				health -= 15
				if (prob(30))
					new/obj/effect/fire(loc)
					visible_message("<span class='danger'>The roof catches fire!<span>")
			return
	if (istype(W, /obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "You start removing \the [src]..."
		if (do_after(user, 60, src) && src)
			user << "You removed \the [src]."
			qdel(src)
			return
	else
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.20
		return
	..()

/obj/roof/canopy
	name = ""
	icon_state = ""
	overlay_state = ""

/obj/roof/wood
	name = "wood roof"
	icon_state = "wood_dm"
	overlay_state = "wood"

/obj/roof/clay
	name = "clay roof"
	desc = "A clay tile roof."
	flammable = FALSE
	overlay_state = "clay"
	icon_state = "clay_dm"

/obj/roof/clay/blue
	name = "clay roof"
	desc = "A black clay tile roof."
	flammable = FALSE
	overlay_state = "blueclay"
	icon_state = "blueclay_dm"

/obj/roof/clay/black
	name = "black clay roof"
	desc = "A black clay tile roof."
	flammable = FALSE
	overlay_state = "blackclay"
	icon_state = "blackclay_dm"

/obj/roof/clay/kerawa
	name = "kerawa roof"
	desc = "A clay tile roof."
	flammable = FALSE
	overlay_state = "black_slateroof"
	icon_state = "black_slateroof_dm"

/obj/roof/concrete
	name = "concrete roof"
	desc = "A concrete roof."
	flammable = FALSE
	overlay_state = "cement"
	icon_state = "cement_dm"

/obj/roof/thatch
	name = "thatch roof"
	desc = "A thatch roof."
	overlay_state = "thatch"
	icon_state = "thatch_dm"

/obj/roof/palm
	name = "palm leaves roof"
	desc = "a roof made of layered palm leaves."
	overlay_state = "palm"
	icon_state = "palm_dm"

/obj/roof/sandstone
	name = "sandstone roof"
	desc = "An egyptian-style sandstone roof."
	overlay_state = "sandstone"
	flammable = FALSE
	icon_state = "sandstone_dm"

/obj/roof/mayan
	name = "mayan roof"
	desc = "A mayan-style stone roof."
	overlay_state = "mayan"
	flammable = FALSE
	icon_state = "mayan_dm"

/obj/roof/proc/update_transparency(var/on = TRUE) //to see through windows and stuff
	roof_overlay.alpha = 255
	spawn(1)
		if (on)
			var/turf/T = get_turf(src)
			T.recalc_atom_opacity()
			if (T.has_opaque_atom)
				roof_overlay.alpha = 255
			else
				roof_overlay.alpha = 127
		else
			roof_overlay.alpha = 255
		/*
		var/area/AA = get_area(get_turf())
		if (AA.
		for(var/turf/T in range(1,src))
			T.recalc_atom_opacity()
			if (!T.has_opaque_atom)
				var/area/A = get_area(T)
				if (A.location == AREA_INSIDE)
					roof_overlay.alpha = 127
					return FALSE
		roof_overlay.alpha = 255
		return TRUE
		*/

/obj/roof/proc/recalculate_borders(var/recalculate_others = FALSE)
	var/founddir = 0
	for (var/drr in list(NORTH,SOUTH,EAST,WEST))
		for (var/obj/roof/RF in get_step(src, drr))
			founddir+=drr
	roof_overlay.icon_state = "[overlay_state]_[founddir]"
	if (recalculate_others)
		for (var/obj/roof/R in range(1,src))
			R.recalculate_borders(FALSE)

/obj/roof/New()
	..()
	icon_state = "roof"
	roof_overlay = image(icon='icons/turf/roofs.dmi', loc = src, icon_state=overlay_state,layer=11.1)
	recalculate_borders(TRUE)
	var/area/caribbean/CURRENTAREA = get_area(src)
	var/oldclimate = CURRENTAREA.climate

	if (CURRENTAREA.type)
		current_area_type = CURRENTAREA.type
		switch(oldclimate)
			if ("tundra")
				new/area/caribbean/roofed/tundra(get_turf(src))
			if ("taiga")
				new/area/caribbean/roofed/taiga(get_turf(src))
			if ("temperate")
				new/area/caribbean/roofed/temperate(get_turf(src))
			if ("sea")
				new/area/caribbean/roofed/sea(get_turf(src))
			if ("semiarid")
				new/area/caribbean/roofed/semiarid(get_turf(src))
			if ("desert")
				new/area/caribbean/roofed/desert(get_turf(src))
			if ("savanna")
				new/area/caribbean/roofed/savanna(get_turf(src))
			if ("jungle")
				new/area/caribbean/roofed/jungle(get_turf(src))

	for (var/atom/movable/lighting_overlay/LO in get_turf(src))
		LO.update_overlay()
	collapse_check()
	/*
	for(var/obj/covers/CV in loc)
		CV.opacity = FALSE
	*/
	var/turf/T = loc
	T.recalc_atom_opacity()
	if (T.has_opaque_atom)
		update_transparency(0)
	else
		for(var/obj/structure/S in range(1,src))
			var/turf/TT = get_turf(S)
			TT.recalc_atom_opacity()
			if (TT.has_opaque_atom)
				update_transparency(0)
			else if (istype(S, /obj/structure/simple_door) || istype(S, /obj/structure/curtain))
				if (S.opacity)
					update_transparency(0)
				else
					update_transparency(1)
			else if ((istype(S, /obj/structure/window) && !(istype(S, /obj/structure/window/barrier) || istype(S, /obj/structure/window/barrier/snowwall)))  || istype(S, /obj/structure/window_frame))
				var/found = FALSE
				for(var/obj/structure/SS in S.loc)
					if (istype(SS, /obj/structure/simple_door) || istype(SS, /obj/structure/curtain))
						if (SS.opacity)
							update_transparency(0)
						else
							update_transparency(1)
						found = TRUE
				if (!found)
					update_transparency(1)


	roofs_list += roof_overlay

/obj/roof/Destroy()
	new current_area_type(get_turf(src))
	for (var/atom/movable/lighting_overlay/LO in get_turf(src))
		LO.update_overlay()
	for (var/obj/roof/R in range(1,src))
		R.recalculate_borders(FALSE)
	/*
	for(var/obj/covers/CV in loc)
		CV.opacity = CV.initial_opacity
	*/
	roofs_list -= roof_overlay
	..()

/obj/roof/proc/collapse_check()
	spawn(50)
		var/supportfound = FALSE
		if (istype(src, /obj/roof/canopy))
			for (var/obj/structure/tent/TT in loc)
				supportfound = TRUE
		for (var/obj/structure/roof_support/RS in range(2, src))
			supportfound = TRUE
		for (var/obj/structure/mine_support/stone/SS in range(2, src))
			supportfound = TRUE
		for (var/turf/wall/W in range(1, src))
			supportfound = TRUE
		for (var/obj/structure/simple_door/SD in loc)
			supportfound = TRUE
		for (var/obj/covers/C in range(1, src))
			if (C.wall == TRUE)
				supportfound = TRUE
	//if no support >> roof falls down
		if (!supportfound)
			playsound(src,'sound/effects/rocksfalling.ogg',100,0,6)
			for (var/mob/living/human/M in range(1, src))
				M.adjustBruteLoss(rand(17,27))
				M.Weaken(15)
				M << "The roof collapses!"
			Destroy()
			qdel(src)

/obj/item/weapon/roofbuilder
	name = "roof builder"
	desc = "Use this to build roofs."
	icon = 'icons/turf/roofs.dmi'
	icon_state = "roof_builder"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	var/done = FALSE
	var/target_type = /obj/roof/wood

/obj/item/weapon/roofbuilder/clay
	name = "clay roofing"
	desc = "Use this to build roofs."
	icon_state = "clay_roof_builder"
	flammable = FALSE
	target_type = /obj/roof/clay

/obj/item/weapon/roofbuilder/clay/blue
	name = "blue clay roofing"
	icon_state = "blueclay_roof_builder"
	target_type = /obj/roof/clay/blue

/obj/item/weapon/roofbuilder/clay/black
	name = "black clay roofing"
	icon_state = "blackclay_roof_builder"
	target_type = /obj/roof/clay/black

/obj/item/weapon/roofbuilder/clay/kerawa
	name = "black clay roofing"
	desc = "Use this to build roofs."
	icon_state = "black_slateroof_builder"
	flammable = FALSE
	target_type = /obj/roof/clay/kerawa

/obj/item/weapon/roofbuilder/leaves
	name = "thatch roofing"
	desc = "Use this to build roofs."
	icon_state = "thatch_roof_builder"
	flammable = TRUE
	target_type = /obj/roof/thatch

/obj/item/weapon/roofbuilder/palm
	name = "palm roofing"
	desc = "Use this to build roofs."
	icon_state = "palm_roof_builder"
	flammable = TRUE
	target_type = /obj/roof/palm

/obj/item/weapon/roofbuilder/concrete
	name = "concrete roofing"
	desc = "Use this to build roofs."
	icon_state = "concrete_roof_builder"
	flammable = FALSE
	target_type = /obj/roof/concrete

/obj/item/weapon/roofbuilder/sandstone
	name = "sandstone roofing"
	desc = "Use this to build roofs."
	icon_state = "sandstone_roof_builder"
	flammable = FALSE
	target_type = /obj/roof/sandstone

/obj/item/weapon/roofbuilder/mayan
	name = "mayan roofing"
	desc = "Use this to build roofs."
	icon_state = "mayan_roof_builder"
	flammable = FALSE
	target_type = /obj/roof/mayan

/obj/item/weapon/roofbuilder/attack_self(mob/user)
	var/your_dir = "NORTH"

	switch (user.dir)
		if (NORTH)
			your_dir = "NORTH"
		if (SOUTH)
			your_dir = "SOUTH"
		if (EAST)
			your_dir = "EAST"
		if (WEST)
			your_dir = "WEST"

	var/covers_time = 80

	if (ishuman(user))
		var/mob/living/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
	var/area/currentarea = get_area(get_step(user, user.dir))
	if (istype(currentarea, /area/caribbean/no_mans_land/invisible_wall))
		user << "You cannot build a roof here."
		return
	for (var/obj/roof/RF in get_step(user, user.dir))
		user << "That area is already roofed!"
		return
	var/confirm = FALSE
	for(var/obj/structure/roof_support/RS in range(2, get_step(user, user.dir)))
		confirm = TRUE
	for(var/obj/structure/mine_support/stone/SS in range(2, get_step(user, user.dir)))
		confirm = TRUE
	for(var/obj/covers/CV in range(1, get_step(user, user.dir)))
		if (CV.wall)
			confirm = TRUE
	if (!confirm)
		user << "This area doesn't have a support for the roof! Build one first!"
		return
	if (WWinput(user, "This will start building a roof [your_dir] of you.", "Roof Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts building the roof.</span>", "<span class='danger'>You start building the roof.</span>")
		if (do_after(user, covers_time, user.loc) && src && !done)
			for (var/obj/roof/RF in get_step(user, user.dir))
				user << "That area is already roofed!"
				return
			done = TRUE
			new target_type(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes building the roof.</span>")
			if (ishuman(user))
				var/mob/living/human/H = user
				H.adaptStat("crafting", 1)
			qdel(src)
		return

/obj/structure/roof_support
	name = "roof support"
	desc = "A thick wood beam, used to support roofs in large buildings."
	icon_state = "support_h"
	flammable = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	var/health = 100
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/roof_support/admin
	name = "roof support"
	desc = ""
	icon = 'icons/turf/roofs.dmi'
	icon_state = "roof2"
	flammable = FALSE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

	New()
		..()
		icon_state = "roof"

/obj/structure/roof_support/nordic
	name = "nordic pillar"
	desc = "A thick wood beam, in nordic style. Used to support roofs in large buildings."
	icon_state = "nordic_pillar"

/obj/structure/roof_support/bamboo
	name = "bamboo pillar"
	desc = "A thick bamboo beam, in nordic style. Used to support roofs in large buildings."
	icon_state = "bamboo_support"

/obj/structure/mine_support
	name = "mine support"
	desc = "A set of wood beams placed to support the mine shaft. Prevents cave-ins."
	icon_state = "support_v"
	flammable = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	var/health = 100
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/mine_support/stone
	name = "stone pillar"
	desc = "A stone pillar that can support roofs and mine shafts."
	icon_state = "support_st1"
	flammable = FALSE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	health = 180
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/mine_support/stone/concrete
	name = "concrete pillar"
	desc = "A concrete pillar that can support roofs and mine shafts."
	icon_state = "concrete_pillar"
	flammable = FALSE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	health = 220
	not_movable = TRUE
	not_disassemblable = TRUE

/* Stone Pillar Subtypes*/

/obj/structure/mine_support/stone/marble
	name = "marble pillar"
	desc = "A marble pillar that can support roofs and mine shafts."
	icon_state = "marble_support_st1"

/obj/structure/mine_support/stone/sandstone
	name = "sandstone pillar"
	desc = "A sandstone pillar that can support roofs and mine shafts."
	icon_state = "sandstone_support_st1"

/obj/structure/mine_support/stone/obsidian
	name = "obsidian pillar"
	desc = "A obsidian pillar that can support roofs and mine shafts."
	icon_state = "obsidian_support_st1"

/* Ionic Pillars*/

/obj/structure/mine_support/stone/ionic
	name = "ionic column"
	desc = "An marble ionic-style column that can support roofs and mine shafts."
	icon_state = "column_ionic"

/obj/structure/mine_support/stone/ionic/rock
	name = "stone ionic column"
	desc = "An stone ionic-style column that can support roofs and mine shafts."
	icon_state = "stone_column_ionic"

/obj/structure/mine_support/stone/ionic/sandstone
	name = "sandstone ionic column"
	desc = "An sandstone ionic-style column that can support roofs and mine shafts."
	icon_state = "sandstone_column_ionic"

/obj/structure/mine_support/stone/ionic/obsidian
	name = "obsidian ionic column"
	desc = "An obsidian ionic-style column that can support roofs and mine shafts."
	icon_state = "obsidian_column_ionic"

/* Solomonic Pillars*/

/obj/structure/mine_support/stone/solomonic
	name = "solomonic column"
	desc = "An solomonic-style column that can support roofs and mine shafts."
	icon_state = "column_solomonic1"

/obj/structure/mine_support/stone/solomonic/rock
	name = "stone solomonic column"
	desc = "An stone solomonic-style column that can support roofs and mine shafts."
	icon_state = "stone_column_solomonic1"

/obj/structure/mine_support/stone/solomonic/sandstone
	name = "sandstone solomonic column"
	desc = "An sandstone solomonic-style column that can support roofs and mine shafts."
	icon_state = "sandstone_column_solomonic1"

/obj/structure/mine_support/stone/solomonic/obsidian
	name = "obsidian solomonic column"
	desc = "An obsidian solomonic-style column that can support roofs and mine shafts."
	icon_state = "obsidian_column_solomonic1"

/obj/structure/mine_support/stone/solomonic/thick
	name = "solomonic column"
	desc = "An solomonic-style column that can support roofs and mine shafts."
	icon_state = "column_solomonic2"

/obj/structure/mine_support/stone/solomonic/thick/rock
	name = "stone solomonic column"
	desc = "An stone solomonic-style column that can support roofs and mine shafts."
	icon_state = "stone_column_solomonic2"

/obj/structure/mine_support/stone/solomonic/thick/sandstone
	name = "sandstone solomonic column"
	desc = "An sandstone solomonic-style column that can support roofs and mine shafts."
	icon_state = "sandstone_column_solomonic2"

/obj/structure/mine_support/stone/solomonic/thick/obsidian
	name = "obsidian solomonic column"
	desc = "An obsidian solomonic-style column that can support roofs and mine shafts."
	icon_state = "obsidian_column_solomonic2"

/* Cultural Pillars*/

/obj/structure/mine_support/stone/aztec
	name = "aztec column"
	desc = "An aztec-style column that can support roofs and mine shafts."
	icon_state = "aztec_pillar"

/obj/structure/mine_support/stone/aztec/marble
	name = "marble aztec column"
	desc = "An marble aztec-style column that can support roofs and mine shafts."
	icon_state = "marble_aztec_pillar"

/obj/structure/mine_support/stone/aztec/sandstone
	name = "sandstone aztec column"
	desc = "An sandstone aztec-style column that can support roofs and mine shafts."
	icon_state = "sandstone_aztec_pillar"

/obj/structure/mine_support/stone/aztec/obsidian
	name = "obsidian aztec column"
	desc = "An obsidian aztec-style column that can support roofs and mine shafts."
	icon_state = "obsidian_aztec_pillar"

/obj/structure/mine_support/stone/egyptian
	name = "egyptian column"
	desc = "An egyptian-style column that can support roofs and mine shafts."
	icon_state = "egyptian_pillar"

/obj/structure/mine_support/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.20
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
	..()

/obj/structure/mine_support/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		Destroy()
		return

/obj/structure/roof_support/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.20
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
	..()

/obj/structure/roof_support/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		Destroy()
		return

/obj/structure/roof_support/Destroy()
	for(var/obj/roof/R in range(3,get_turf(src)))
		R.collapse_check()
	..()

/obj/structure/mine_support/Destroy()
	if (istype(get_turf(src), /turf/floor))
		for(var/turf/floor/T in range(3,get_turf(src)))
			T.collapse_check()
	..()