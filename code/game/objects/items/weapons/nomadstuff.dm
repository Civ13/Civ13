//BEDROLL
/obj/item/weapon/bedroll
	name = "bedroll"
	desc = "A portable bed, made of leather and fur."
	icon = 'icons/obj/items.dmi'
	icon_state = "bedroll_r"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_NORMAL
	flags = FALSE

	attack_verb = list("battered","whacked")
	flammable = TRUE

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
	flammable = TRUE

/obj/structure/bed/bedroll/New()
	..()
	cover_overlay = image("icon" = 'icons/obj/items.dmi', "icon_state" = "bedroll_w", "layer" = MOB_LAYER + 2.1)

/obj/item/weapon/bedroll/attack_self(mob/user as mob)
	user << "You open the bedroll, extending it."
	new/obj/structure/bed/bedroll(user.loc)
	qdel(src)
	return
/obj/structure/bed/bedroll/update_icon()
	if (used)
		overlays.Cut()
		overlays  += cover_overlay
		overlays  += image("icon" = 'icons/obj/items.dmi', "icon_state" = "bedroll_o")
	else
		overlays.Cut()
		overlays  += image("icon" = 'icons/obj/items.dmi', "icon_state" = "bedroll_o")
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

/obj/structure/bed/bedroll/proc/check_use(var/mob/living/human/H)
	if ((H in src.loc) && buckled_mob == H && used == TRUE && running == FALSE)
		running = TRUE
		update_icon()
		spawn(300)
		if ((H in src.loc) && buckled_mob == H && used == TRUE && running == TRUE)
			running = FALSE
			check_use(H)
	else
		used = FALSE
		update_icon()
		return
/obj/structure/bed/bedroll/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		var/mob/living/affecting = G.affecting
		user.visible_message("<span class='notice'>[user] attempts to tuck [affecting] into \the [src]!</span>")
		if (do_after(user, 20, src))
			affecting.loc = loc
			spawn(0)
				if (buckle_mob(affecting))
					affecting.visible_message(\
						"<span class='danger'>[affecting.name] is tucked inside 1the [src] by [user.name]!</span>",\
						"<span class='danger'>You are tucked inside 1the [src] by [user.name]!</span>",\
						"<span class='notice'>You hear the rustling of leather.</span>")
			qdel(W)
	else
		..()
	update_icon()

//TENT
/obj/item/weapon/tent
	name = "folded canopy"
	desc = "A foldable canopy."
	icon = 'icons/obj/items.dmi'
	icon_state = "tent_r"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_LARGE
	flags = FALSE

	attack_verb = list("battered","whacked")
	flammable = TRUE

/obj/structure/tent
	name = "canopy"
	desc = "A portable cloth canopy, assembled here."
	icon = 'icons/obj/structures.dmi'
	icon_state = "tent_o"
	layer = 5
	anchored = TRUE
	can_buckle = FALSE
	var/area/oldarea
	var/area/newarea
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/tent/New()
	..()
	oldarea = get_area(src)
	if (oldarea.location == AREA_OUTSIDE)
		for(var/obj/structure/tent/T in range(1,src))
			T.update_icon()
		update_icon()
		new/obj/roof/canopy(loc)

/obj/item/weapon/tent/attack_self(mob/user as mob)
	for (var/obj/O in src.loc)
		if (istype(O, /obj/structure/tent))
			user << "There is already a structure here."
			return
	var/area/caribbean/oldarea = get_area(src)
	if (oldarea.location == AREA_INSIDE)
		user << "This location is covered already, you can't set up a tent here."
		return
	visible_message("[user] starts unfolding the [src]...","You open the [src] and start unfolding it...")
	if (do_after(user, 35, src))
		visible_message("[user] finishes unfolding the [src].","You finish unfolding the [src].")
		new/obj/structure/tent(user.loc)
		qdel(src)
		return

/obj/structure/tent/verb/fold()
	set category = null
	set src in view(1)
	set name = "Fold Canopy"

	if (!oldarea)
		return
	visible_message("[usr] starts folding the [src]...","You start folding the [src]...")
	if (do_after(usr, 35, src))
		visible_message("[usr] finishes folding the [src].","You finish folding the [src].")
		new/obj/item/weapon/tent(get_turf(src))
		for(var/obj/structure/tent/T in range(1,src))
			T.update_icon()
		for (var/obj/roof/RF in loc)
			qdel(RF)
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

/obj/item/weapon/leash
	name = "rope leash"
	desc = "A rope leash, used to tie animals together."
	icon = 'icons/obj/items.dmi'
	icon_state = "leash"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = ITEM_SIZE_SMALL
	flags = FALSE

	attack_verb = list("whipped")
	var/mob/living/simple_animal/S1 = null
	var/mob/living/simple_animal/S2 = null
	var/onedefined = FALSE
	flammable = TRUE