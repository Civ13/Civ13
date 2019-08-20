/mob/living/simple_animal
	var/image/cover_overlay = null //riding (over mob)
	var/icon_riding = "" // to be applied to cover_overlay

	var/can_ride = FALSE
	var/ride = FALSE
	var/mob/living/carbon/human/rider = null

/mob/living/simple_animal/New()
	..()
	icon_riding = "[icon_living]_riding"
	if (can_ride)
		layer = MOB_LAYER - 0.01
	cover_overlay = image("icon" = icon, "icon_state" = icon_riding, "layer" = 4.15)
	overlays.Cut()
/mob/living/simple_animal/update_icons()
	..()
	overlays.Cut()
	if (stat == DEAD)
		icon_state = icon_dead
		layer = 3.3
	else
		if (can_ride && ride && !(cover_overlay in overlays))
			overlays += cover_overlay
		else
			overlays -= cover_overlay

/mob/living/simple_animal/MouseDrop_T(mob/living/M, mob/living/carbon/human/user)
	if (can_ride && isnull(rider) && M == user && !user.lying && !user.prone && (!user.werewolf || user.body_build.name == "Default"))
		var/mob/living/carbon/human/MM = M
		visible_message("<div class='notice'>[M] starts getting on the [src]'s back...</div>","<div class='notice'>You start going on \the [src]'s back...</div>")
		if (do_after(MM, 40, src))
			visible_message("<div class='notice'>[M] sucessfully climbs into the [src]'s back.</div>","<div class='notice'>You sucessfully climb into \the [src]'s back.</div>")
			ride = TRUE
			rider = MM
			MM.forceMove(locate(x+1,y+1,z))
			MM.riding = TRUE
			MM.riding_mob = src
			MM.pixel_x = -19
			MM.pixel_y = -11
			update_icons()
			stop_automated_movement = TRUE
			return
	else
		..()

/mob/living/simple_animal/attack_hand(mob/living/carbon/human/M as mob)
	if (can_ride && ride == TRUE && !isnull(rider))
		if (rider == M)
			visible_message("<div class='notice'>[M] starts to get off \the [src]...</div>","<div class='notice'>You start to get off \the [src]...</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='danger'>[M] gets out of \the [src].</div>","<div class='danger'>You get out of \the [src].</div>")
				M.riding = FALSE
				M.riding_mob = null
				M.forceMove(locate(x+1,y,z))
				ride = FALSE
				rider = null
				M.pixel_x = 0
				M.pixel_y = 0
				update_icons()
				stop_automated_movement = FALSE
				return
		else
			visible_message("<div class='danger'>[M] tries to pull [rider] from \the [src]!</div>","<div class='danger'>You try to pull [rider] from \the [src]!</div>")
			if (do_after(M, 40, src))
				visible_message("<div class='danger'>[M] pulls [rider] from \the [src]!</div>","<div class='danger'>You pull [rider] from \the [src]!</div>")
				rider.riding = FALSE
				rider.riding_mob = null
				rider.forceMove(locate(x+1,y,z))
				rider.SpinAnimation(5,1)
				rider.Weaken(5)
				ride = FALSE
				rider.pixel_x = 0
				rider.pixel_y = 0
				rider = null
				update_icons()
				stop_automated_movement = FALSE
				return
	else
		..()

/mob/living/simple_animal/death()
	..()
	if (can_ride && !isnull(rider))
		visible_message("<div class='danger'>[rider] falls from \the [src]!</div>","<div class='danger'>You fall from \the [src]!</div>")
		rider.riding = FALSE
		rider.SpinAnimation(5,1)
		rider.forceMove(locate(x+1,y,z))
		rider.Weaken(5)
		ride = FALSE
		rider.pixel_x = 0
		rider.pixel_y = 0
		rider = null
		overlays.Cut()

/mob/living/simple_animal/proc/trample(var/mob/living/tmob)
	if (can_ride && tmob.stat != DEAD)
		visible_message("<div class='danger'>\The [src] tramples [tmob]!</div>")
		playsound(tmob.loc, 'sound/effects/gore/fallsmash.ogg', 35, TRUE)
		tmob.adjustBruteLoss(rand(6,7))
		if (prob(35))
			tmob.Weaken(7)
		return