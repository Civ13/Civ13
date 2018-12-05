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
		return