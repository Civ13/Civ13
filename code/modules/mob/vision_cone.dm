/////////////VISION CONE///////////////
//Vision cone code by Matt and Honkertron. This vision cone code allows for mobs and/or items to blocked out from a players field of vision.
//This code makes use of the "cone of effect" proc created by Lummox, contributed by Jtgibson. More info on that here:
//http://www.byond.com/forum/?post=195138
///////////////////////////////////////

//"Made specially for Otuska"
// - Honker



//Defines.
#define OPPOSITE_DIR(D) turn(D, 180)

/mob
	var/obj/screen/fov = null//The screen object because I can't figure out how the hell TG does their screen objects so I'm just using legacy code.

client/
	var/list/hidden_atoms = list()
	var/list/hidden_mobs = list()

atom/proc/InCone(atom/center = usr, dir = NORTH)
	if (get_dist(center, src) == FALSE || src == center) return FALSE
	var/d = get_dir(center, src)

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

/mob/living/update_vision_cone()
	var/delay = 10
	if (client && fov)
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
				I = image("split", M)
				I.override = TRUE
				client.images += I
				client.hidden_atoms += I
				client.hidden_mobs += M
				if (pulling == M)//If we're pulling them we don't want them to be invisible, too hard to play like that.
					I.override = FALSE

			//Optional items can be made invisible too. Uncomment this part if you wish to items to be invisible.
			//var/obj/item/O
			//for (O in cone(src, OPPOSITE_DIR(dir), oview(src)))
			//	I = image("split", O)
			//	I.override = TRUE
			//	client.images += I
			//	client.hidden_atoms += I

	else
		return

mob/proc/rest_cone_act()//For showing and hiding the cone when you rest or lie down.
	if (resting || lying)
		hide_cone()
	else
		show_cone()

//Making these generic procs so you can call them anywhere.
mob/proc/show_cone()
	if (fov)
		fov.alpha = 255

mob/proc/hide_cone()
	if (fov)
		fov.alpha = 0