//BEDROLL
/obj/item/weapon/bedroll
	name = "bedroll"
	desc = "A portable bed, made of leather and fur."
	icon = 'icons/obj/items.dmi'
	icon_state = "bedroll_r"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = 3.0
	matter = list(DEFAULT_WALL_MATERIAL = 150)
	attack_verb = list("battered","whacked")

/obj/structure/bed/bedroll
	name = "bedroll"
	desc = "A portable bed, made of leather and fur."
	icon = 'icons/obj/items.dmi'
	icon_state = "bedroll_o"
	anchored = TRUE
	layer = MOB_LAYER - 0.01
	var/used = FALSE
	var/running = FALSE //to prevent exploits of unbuckling/bucking etc
	can_buckle = TRUE
	buckle_dir = SOUTH
	buckle_lying = TRUE
	var/image/cover_overlay = null

/obj/structure/bed/bedroll/New()
	..()
	cover_overlay = image('icons/obj/items.dmi', "bedroll_w")
	cover_overlay.layer = MOB_LAYER + 1.1

/obj/item/weapon/bedroll/attack_self(mob/user as mob)
	user << "You open the bedroll, extending it."
	new/obj/structure/bed/bedroll(user.loc)
	qdel(src)
	return

/obj/structure/bed/bedroll/verb/fold()
	set category = null
	set src in view(1)
	set name = "Fold Bedroll"
	if (used == FALSE)
		usr << "You fold the bedroll."
		running = FALSE
		new/obj/item/weapon/bedroll(src.loc)
		qdel(src)
		return

/obj/structure/bed/bedroll/proc/check_use(var/mob/living/carbon/human/H)
	if ((H in src.loc) && buckled_mob == H && used == TRUE && running == FALSE)
		running = TRUE
		spawn(300)
		if ((H in src.loc) && buckled_mob == H && used == TRUE && running == TRUE)
			if (H.getBruteLoss() >= 40)
				H.adjustBruteLoss(-1)
				overlays += cover_overlay
				running = FALSE
				check_use(H)
	else
		used = FALSE
		icon_state = "bedroll_o"
		overlays -= cover_overlay
		return
/obj/structure/bed/bedroll/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		var/mob/living/affecting = G.affecting
		user.visible_message("<span class='notice'>[user] attempts to buckle [affecting] into \the [src]!</span>")
		if (do_after(user, 20, src))
			affecting.loc = loc
			spawn(0)
				if (buckle_mob(affecting))
					affecting.visible_message(\
						"<span class='danger'>[affecting.name] is buckled to [src] by [user.name]!</span>",\
						"<span class='danger'>You are buckled to [src] by [user.name]!</span>",\
						"<span class='notice'>You hear metal clanking.</span>")
			qdel(W)
	else
		..()

//TENT
/obj/item/weapon/tent
	name = "foldable canopy"
	desc = "A foldable canopy."
	icon = 'icons/obj/items.dmi'
	icon_state = "tent_r"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = 4.0
	matter = list(DEFAULT_WALL_MATERIAL = 150)
	attack_verb = list("battered","whacked")

/obj/structure/tent
	name = "canopy"
	desc = "A portable cloth canopy, assembled here."
	icon = 'icons/obj/structures.dmi'
	icon_state = "tent_o"
	layer = 5
	anchored = TRUE
	can_buckle = FALSE
	var/oldname = ""
/obj/structure/tent/New()
	..()
	var/area/caribbean/CURRENTAREA = get_area(src)
	if (CURRENTAREA.location == AREA_OUTSIDE)
		var/area/caribbean/NEWAREA = new/area/caribbean(src.loc)
		oldname = CURRENTAREA.name
		NEWAREA.base_turf = CURRENTAREA.base_turf
		NEWAREA.location = AREA_INSIDE
		NEWAREA.update_light()
		for(var/obj/structure/tent/T in range(1,src))
			T.update_icon()
		update_icon()

/obj/item/weapon/tent/attack_self(mob/user as mob)
	for (var/obj/O in src.loc)
		if (istype(O, /obj/structure/tent))
			user << "There is already a structure here."
			return
	var/area/caribbean/CURRENTAREA = get_area(src)
	if (CURRENTAREA.location == AREA_INSIDE)
		user << "This location is covered already, you can't set up a tent here."
		return
	visible_message("[user] starts unfolding the tent...","You open the tent and start unfolding it...")
	if (do_after(user, 35, src))
		visible_message("[user] finishes unfolding the tent.","You finish unfolding the tent.")
		new/obj/structure/tent(user.loc)
		qdel(src)
		return

/obj/structure/tent/verb/fold()
	set category = null
	set src in view(1)
	set name = "Fold Canopy"
	visible_message("[usr] starts folding the tent...","You start folding the tent...")
	if (do_after(usr, 35, src))
		visible_message("[usr] finishes folding the tent.","You finish folding the tent.")
		new/obj/item/weapon/tent(src.loc)
		var/area/caribbean/CURRENTAREA = get_area(src)
		if (CURRENTAREA.location == AREA_INSIDE)
			var/area/caribbean/NEWAREA = new/area/caribbean(src.loc)
			NEWAREA.name = oldname
			NEWAREA.base_turf = CURRENTAREA.base_turf
			NEWAREA.location = AREA_OUTSIDE
			NEWAREA.update_light()
		for(var/obj/structure/tent/T in range(1,src))
			T.update_icon()
		qdel(src)
		return

/obj/structure/tent/update_icon()
	..()

	for (var/obj/structure/tent/TTT in locate(x,y-1,z))
		icon_state = "tent_s"


	for (var/obj/structure/tent/T in locate(x,y+1,z))
		icon_state = "tent_n"

		for (var/obj/structure/tent/TT in locate(x,y-1,z))
			icon_state = "tent_ns"



	for (var/obj/structure/tent/T in locate(x+1,y,z))
		icon_state = "tent_e"

		for (var/obj/structure/tent/TT in locate(x,y-1,z))
			icon_state = "tent_es"

		for (var/obj/structure/tent/TT in locate(x,y+1,z))
			icon_state = "tent_en"

			for (var/obj/structure/tent/TTT in locate(x,y-1,z))
				icon_state = "tent_esn"




	for (var/obj/structure/tent/T1 in locate(x-1,y,z))
		icon_state = "tent_w"

		for (var/obj/structure/tent/T2 in locate(x,y-1,z))
			icon_state = "tent_sw"

			for (var/obj/structure/tent/TT in locate(x+1,y,z))
				icon_state = "tent_swe"

		for (var/obj/structure/tent/T3 in locate(x,y+1,z))
			icon_state = "tent_nw"

			for (var/obj/structure/tent/TT in locate(x,y-1,z))
				icon_state = "tent_nws"

		for (var/obj/structure/tent/TT in locate(x+1,y,z))
			icon_state = "tent_ew"

			for (var/obj/structure/tent/TTT in locate(x,y+1,z))
				icon_state = "tent_enw"

				for (var/obj/structure/tent/TTTT in locate(x,y-1,z))
					icon_state = "tent_c"