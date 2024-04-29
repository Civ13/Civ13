/mob/living/simple_animal
	var/image/cover_overlay = null //riding (over mob)
	var/icon_riding = "" // to be applied to cover_overlay

	var/can_ride = FALSE
	var/ride = FALSE
	var/ride_pixel_x = 0
	var/ride_pixel_y = 0
	var/mob/living/human/rider = null

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

/mob/living/simple_animal/MouseDrop_T(mob/living/M, mob/living/human/user)
	if (can_ride && isnull(rider) && M == user && !user.lying && !user.prone && (!user.werewolf || user.body_build.name == "Default"))
		var/mob/living/human/MM = M
		M.visible_message("<span class='notice'>[M] starts trying to get on \the [src]'s back...</span>","<span class='notice'>You start trying to get on \the [src]'s back...</span>")
		if (do_after(MM, 40, src))
			M.plane = GAME_PLANE
			M.visible_message("<span class='notice'>[M] manages to successfully climb into \the [src]'s back.</span>","<span class='notice'>You manage to successfully climb into \the [src]'s back.</span>")
			ride = TRUE
			rider = MM
			MM.forceMove(src.loc)
			MM.riding = TRUE
			MM.riding_mob = src
			src.pixel_x = src.ride_pixel_x
			src.pixel_y = src.ride_pixel_y
			update_icons()
			stop_automated_movement = TRUE
			return
	else
		..()

/mob/living/simple_animal/attack_hand(mob/living/human/M as mob)
	if (can_ride && ride == TRUE && !isnull(rider))
		if (rider == M)
			M.visible_message("<span class='notice'>[M] starts to get off \the [src]...</span>","<span class='notice'>You start to get off \the [src]...</span>")
			if (do_after(M, 40, src))
				M.visible_message("<span class='danger'>[M] gets off \the [src].</span>","<span class='danger'>You get off \the [src].</span>")
				M.riding = FALSE
				M.riding_mob = null
				ride = FALSE
				rider = null
				M.pixel_x = 0
				M.pixel_y = 0
				update_icons()
				stop_automated_movement = FALSE
				return
		else
			M.visible_message("<span class='danger'>[M] tries to pull [rider] off from \the [src]!</span>","<span class='danger'>You try to pull [rider] off from \the [src]!</span>")
			if (do_after(M, 40, src))
				M.visible_message("<span class='danger'>[M] pulls [rider] off from \the [src]!</span>","<span class='danger'>You pull [rider] off from \the [src]!</span>")
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
		rider.visible_message("<span class='danger'>[rider] falls off from \the [src]!</span>", "<span class='danger'>You fall off from \the [src]!</span>")
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
		visible_message("<span class='danger'>\The [src] tramples [tmob]!</span>")
		playsound(tmob.loc, 'sound/effects/gore/fallsmash.ogg', 35, TRUE)
		tmob.adjustBruteLoss(rand(6,7))
		if (prob(35))
			tmob.Weaken(7)
		return