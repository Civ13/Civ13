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
	var/unrolled_type = /obj/structure/bed/bedroll

/obj/item/weapon/bedroll/cloth
	name = "cloth bedroll"
	desc = "A portable bundle of woven bedding. Unroll it to sleep."
	unrolled_type = /obj/structure/bed/bedroll/cloth

/obj/structure/bed/bedroll
	name = "bedroll"
	desc = "A portable bed, made of leather and fur."
	icon = 'icons/obj/items.dmi'
	icon_state = "bedroll_o"
	anchored = TRUE
	layer = MOB_LAYER - 0.06 // Why 0.06? To prevent beds from clipping above east-facing barriers (3.95).
	var/used = FALSE
	var/running = FALSE //to prevent exploits of unbuckling/bucking etc
	can_buckle = TRUE
	buckle_dir = SOUTH
	buckle_lying = TRUE
	var/image/cover_overlay = null
	flammable = TRUE
	not_disassemblable = TRUE // Textile bedding must not inherit a wooden-structure refund.
	var/rolled_type = /obj/item/weapon/bedroll
	var/bedding_material = "leather"

/obj/structure/bed/bedroll/cloth
	name = "cloth bedroll"
	desc = "A portable bundle of woven bedding. Fold it for travel."
	rolled_type = /obj/item/weapon/bedroll/cloth
	bedding_material = "cloth"

/obj/structure/bed/bedroll/New()
	..()
	cover_overlay = image("icon" = 'icons/obj/items.dmi', "icon_state" = "bedroll_w", "layer" = MOB_LAYER + 2.1)

/obj/item/weapon/bedroll/attack_self(mob/user as mob)
	to_chat(user, "You open the bedroll, extending it.")
	new unrolled_type(user.loc)
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
	fold_up(usr)

/obj/structure/bed/bedroll/proc/fold_up(mob/user)
	if (used == FALSE)
		to_chat(user, "You fold the bedroll.")
		running = FALSE
		var/obj/item/weapon/bedroll/rolled = new rolled_type(src.loc)
		qdel(src)
		return rolled

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
			if (!affecting || !affecting.persistence_set_loc(loc)) return FALSE
			spawn(0)
				if (buckle_mob(affecting))
					affecting.visible_message(\
						"<span class='danger'>[affecting.name] is tucked inside 1the [src] by [user.name]!</span>",\
						"<span class='danger'>You are tucked inside 1the [src] by [user.name]!</span>",\
						"<span class='notice'>You hear the rustling of [bedding_material].</span>")
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
	if (!isturf(loc))
		return
	oldarea = get_area(src)
	if (oldarea.location == AREA_OUTSIDE)
		for(var/obj/structure/tent/T in range(1,src))
			T.update_icon()
		update_icon()
		new/obj/roof/canopy(loc)

/proc/canopy_actor_ready(mob/user, turf/site, datum/save_epoch)
	return !QDELETED(user) && site && isturf(user.loc) && !user.incapacitated() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity

/obj/item/weapon/tent/proc/unfold_allowed(mob/user, turf/site, atom/source_loc, datum/save_epoch)
	if (QDELETED(src) || !canopy_actor_ready(user, site, save_epoch) || user.loc != site || loc != source_loc || (loc != user && loc != site))
		return FALSE
	var/area/A = get_area(site)
	if (!A || A.location != AREA_OUTSIDE)
		return FALSE
	for (var/obj/structure/tent/T in site)
		if (!QDELETED(T))
			return FALSE
	for (var/obj/roof/R in site)
		if (!QDELETED(R))
			return FALSE
	return TRUE

/obj/item/weapon/tent/attack_self(mob/user as mob)
	var/turf/site = get_turf(user)
	var/atom/source_loc = loc
	var/datum/save_epoch = persistence_admission_identity
	if (!unfold_allowed(user, site, source_loc, save_epoch))
		to_chat(user, "The canopy needs a clear, uncovered tile.")
		return
	visible_message("[user] starts unfolding the [src]...","You open the [src] and start unfolding it...")
	if (do_after(user, 35, src))
		if (!unfold_allowed(user, site, source_loc, save_epoch))
			return
		visible_message("[user] finishes unfolding the [src].","You finish unfolding the [src].")
		new /obj/structure/tent(site)
		qdel(src)
		return

/obj/structure/tent/verb/fold()
	set category = null
	set src in view(1)
	set name = "Fold Canopy"
	fold_up(usr)

/obj/structure/tent/proc/fold_allowed(mob/user, turf/site, datum/save_epoch)
	if (QDELETED(src) || !oldarea || loc != site || !canopy_actor_ready(user, site, save_epoch) || user.z != site.z || get_dist(user, site) > 1)
		return FALSE
	// A separate roof owns its own area transition. Do not remove or overwrite it.
	for (var/obj/roof/R in site)
		if (!QDELETED(R) && !istype(R, /obj/roof/canopy))
			return FALSE
	return TRUE

/obj/structure/tent/proc/fold_up(mob/user)
	var/turf/site = get_turf(src)
	var/datum/save_epoch = persistence_admission_identity
	if (!fold_allowed(user, site, save_epoch))
		to_chat(user, "The canopy cannot be folded here; remove any other roof first.")
		return null
	visible_message("[user] starts folding the [src]...","You start folding the [src]...")
	if (do_after(user, 35, src))
		if (!fold_allowed(user, site, save_epoch))
			return null
		visible_message("[user] finishes folding the [src].","You finish folding the [src].")
		var/other_canopy = FALSE
		for (var/obj/structure/tent/T in site)
			if (T != src && !QDELETED(T))
				other_canopy = TRUE
		// Retire this instance before roof callbacks or output construction can reenter.
		qdel(src)
		if (!other_canopy)
			for (var/obj/roof/canopy/RF in site)
				qdel(RF)
		var/obj/item/weapon/tent/rolled = new /obj/item/weapon/tent(site)
		for (var/obj/structure/tent/T in range(1,site))
			if (!QDELETED(T))
				T.update_icon()
		return rolled
	return null

/obj/structure/tent/update_icon()
	..()
	icon_state = initial(icon_state)

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
