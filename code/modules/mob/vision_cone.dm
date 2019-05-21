/////////////VISION CONE///////////////
//Vision cone code by Matt and Honkertron. This vision cone code allows for mobs and/or items to blocked out from a players field of vision.
//This code makes use of the "cone of effect" proc created by Lummox, contributed by Jtgibson. More info on that here:
//http://www.byond.com/forum/?post=195138
///////////////////////////////////////

//"Made specially for Otuska"
// - Honker



//Defines.
#define OPPOSITE_DIR(D) turn(D, 180)

client/
	var/list/hidden_atoms = list()
	var/list/hidden_mobs = list()

atom/proc/InCone(atom/center = usr, dir = NORTH)
	if (get_dist(center, src) == FALSE || src == center) return FALSE
	var/d = get_dir(center, src)
	if (global_hud.fov.icon_state == "combat") //300 degrees
		if (!d || d == dir) return TRUE
		if (dir & (dir-1))
			return (d & ~dir) ? FALSE : TRUE
		if (!(d & dir)) return FALSE
		var/dx = abs(x - center.x)
		var/dy = abs(y - center.y)
		if (dx == dy) return TRUE
		if (dy > dx)
			return (dir & (NORTH|SOUTH)) ? TRUE : FALSE
		return (dir & (EAST|WEST)) ? TRUE : FALSE

	else if (global_hud.fov.icon_state == "helmet") //180 degrees
		if (!d) return TRUE
		switch(center.dir)
			if (WEST)
				if (x <= center.x)
					return FALSE
			if (EAST)
				if (x >= center.x)
					return FALSE
			if (NORTH)
				if (y >= center.y)
					return FALSE
			if (SOUTH)
				if (y <= center.y)
					return FALSE
		return TRUE

	else if (global_hud.fov.icon_state == "narrow") //60 degrees
		//first remove anything 180 degrees behind, and authorize anything right in front
		var/dx = abs(x - center.x)
		var/dy = abs(y - center.y)
		switch(center.dir)
			if (WEST)
				if (x > center.x)
					return TRUE
				if (get_dir(center, src) == center.dir)
					return FALSE
				if (get_dist(center, src) >= dx)
					return FALSE
			if (EAST)
				if (x < center.x)
					return TRUE
				if (get_dir(center, src) == center.dir)
					return FALSE
				if (get_dist(center, src) >= dx)
					return FALSE
			if (NORTH)
				if (y < center.y)
					return TRUE
				if (get_dir(center, src) == center.dir)
					return FALSE
				if (get_dist(center, src) >= dy)
					return FALSE
			if (SOUTH)
				if (y > center.y)
					return TRUE
				if (get_dir(center, src) == center.dir)
					return FALSE
				if (get_dist(center,src) >= dy)
					return FALSE

		return TRUE
mob/dead/InCone(mob/center = usr, dir = NORTH)
	return

mob/living/InCone(mob/center = usr, dir = NORTH)
	. = ..()
	for (var/obj/item/weapon/grab/G in center)//TG doesn't have the grab item. But if you're porting it and you do then uncomment this.
		if (src == G.affecting)
			return FALSE
		else
			return .


proc/cone(atom/center = usr, dir = NORTH, list/list = oview(center))
    for (var/atom/O in list) if (!O.InCone(center, dir)) list -= O
    return list

/mob/proc/update_vision_cone()
	return

/mob/living/carbon/human/update_vision_cone()
	var/delay = 10
	if (client && HUDtech["fov"] && !config.disable_fov)
//delete these lines when activating "normal" update vision cone
//		rest_cone_act()
//		HUDtech["fov"].dir = dir

		var/obj/screen/fov/fov = HUDtech["fov"]
		var/image/I = null
		for (I in client.hidden_atoms)
			I.override = FALSE
			spawn(delay)
				qdel(I)
			delay += 10
		rest_cone_act()
		client.hidden_atoms = list()
		client.hidden_mobs = list()
		fov.dir = dir
		if (fov.alpha != FALSE)
			var/mob/living/M
			for (M in cone(src, OPPOSITE_DIR(dir), view(10, src)))
				if (!(M in range(1,src)))
					I = image("split", M)
					I.override = TRUE
					client.images += I
					client.hidden_atoms += I
					client.hidden_mobs += M
					if (pulling == M)//If we're pulling them we don't want them to be invisible, too hard to play like that.
						I.override = FALSE
/*
			//Optional items can be made invisible too. Uncomment this part if you wish to items to be invisible.
			var/obj/item/O
			for (O in cone(src, OPPOSITE_DIR(dir), oview(src)))
				if (!O.anchored && !(O in range(1,src)))
					I = image("split", O)
					I.override = TRUE
					client.images += I
					client.hidden_atoms += I
*/
	else
		return

mob/living/carbon/human/proc/rest_cone_act()//For showing and hiding the cone when you rest or lie down.
	if (resting || lying || prone)
		hide_cone()
	else
		show_cone()

//Making these generic procs so you can call them anywhere.
mob/living/carbon/human/proc/show_cone()
	if (HUDtech["fov"])
		HUDtech["fov"].alpha = 255

mob/living/carbon/human/proc/hide_cone()
	if (HUDtech["fov"])
		HUDtech["fov"].alpha = 0