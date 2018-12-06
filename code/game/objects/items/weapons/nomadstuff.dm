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
	name = "foldable tent"
	desc = "A foldable tent."
	icon = 'icons/obj/items.dmi'
	icon_state = "tent_r"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = 4.0
	matter = list(DEFAULT_WALL_MATERIAL = 150)
	attack_verb = list("battered","whacked")

/obj/structure/tent
	name = "tent"
	desc = "A portable tent, assembled here."
	icon = 'icons/obj/obj64x64.dmi'
	icon_state = "tent_o"
	layer = 5
	anchored = TRUE
	can_buckle = FALSE


/obj/item/weapon/tent/attack_self(mob/user as mob)
	visible_message("[user] starts unfolding the tent...","You open the tent and start unfolding it...")
	if (do_after(user, 110, src))
		visible_message("[user] finishes unfolding the tent.","You finish unfolding the tent.")
		new/obj/structure/tent(user.loc)
		qdel(src)
		var/area/caribbean/CURRENTAREA1 = get_area(src)
		var/area/caribbean/CURRENTAREA2 = get_area(locate(x+1,y,z))
		var/area/caribbean/CURRENTAREA3 = get_area(locate(x,y+1,z))
		var/area/caribbean/CURRENTAREA4 = get_area(locate(x+1,y+1,z))
		if (CURRENTAREA1.location == AREA_OUTSIDE)
			var/area/caribbean/NEWAREA1 = new/area/caribbean(src.loc)
			NEWAREA1.oldname = CURRENTAREA1.name
			NEWAREA1.name = "roofed tent"
			NEWAREA1.base_turf = CURRENTAREA1.base_turf
			NEWAREA1.location = AREA_INSIDE
			NEWAREA1.update_light()
		if (CURRENTAREA2.location == AREA_OUTSIDE)
			var/area/caribbean/NEWAREA2 = new/area/caribbean(src.loc)
			NEWAREA2.oldname = CURRENTAREA2.name
			NEWAREA2.name = "roofed tent"
			NEWAREA2.base_turf = CURRENTAREA2.base_turf
			NEWAREA2.location = AREA_INSIDE
			NEWAREA2.update_light()
		if (CURRENTAREA3.location == AREA_OUTSIDE)
			var/area/caribbean/NEWAREA3 = new/area/caribbean(src.loc)
			NEWAREA3.oldname = CURRENTAREA3.name
			NEWAREA3.name = "roofed tent"
			NEWAREA3.base_turf = CURRENTAREA3.base_turf
			NEWAREA3.location = AREA_INSIDE
			NEWAREA3.update_light()
		if (CURRENTAREA4.location == AREA_OUTSIDE)
			var/area/caribbean/NEWAREA4 = new/area/caribbean(src.loc)
			NEWAREA4.oldname = CURRENTAREA4.name
			NEWAREA4.name = "roofed tent"
			NEWAREA4.base_turf = CURRENTAREA4.base_turf
			NEWAREA4.location = AREA_INSIDE
			NEWAREA4.update_light()
		return

/obj/structure/tent/verb/fold()
	set category = null
	set src in view(1)
	set name = "Fold Tent"
	visible_message("[usr] starts folding the tent...","You start folding the tent...")
	if (do_after(usr, 110, src))
		visible_message("[usr] finishes folding the tent.","You finish folding the tent.")
		new/obj/item/weapon/tent(src.loc)
		qdel(src)
		var/area/caribbean/CURRENTAREA1 = get_area(src)
		var/area/caribbean/CURRENTAREA2 = get_area(locate(x+1,y,z))
		var/area/caribbean/CURRENTAREA3 = get_area(locate(x,y+1,z))
		var/area/caribbean/CURRENTAREA4 = get_area(locate(x+1,y+1,z))
		if (CURRENTAREA1.location == AREA_INSIDE && CURRENTAREA1.name == "roofed tent")
			var/area/caribbean/NEWAREA1 = new/area/caribbean(src.loc)
			NEWAREA1.name = NEWAREA1.oldname
			NEWAREA1.base_turf = CURRENTAREA1.base_turf
			NEWAREA1.location = AREA_OUTSIDE
		if (CURRENTAREA2.location == AREA_INSIDE && CURRENTAREA2.name == "roofed tent")
			var/area/caribbean/NEWAREA2 = new/area/caribbean(src.loc)
			NEWAREA2.name = NEWAREA2.oldname
			NEWAREA2.base_turf = CURRENTAREA2.base_turf
			NEWAREA2.location = AREA_OUTSIDE
		if (CURRENTAREA3.location == AREA_INSIDE && CURRENTAREA3.name == "roofed tent")
			var/area/caribbean/NEWAREA3 = new/area/caribbean(src.loc)
			NEWAREA3.name = NEWAREA3.oldname
			NEWAREA3.base_turf = CURRENTAREA3.base_turf
			NEWAREA3.location = AREA_OUTSIDE
		if (CURRENTAREA4.location == AREA_INSIDE && CURRENTAREA4.name == "roofed tent")
			var/area/caribbean/NEWAREA4 = new/area/caribbean(src.loc)
			NEWAREA4.name = NEWAREA4.oldname
			NEWAREA4.base_turf = CURRENTAREA4.base_turf
			NEWAREA4.location = AREA_OUTSIDE
		return

