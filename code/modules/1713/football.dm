
//with ball, pressing C (previously Z)
/mob/living/human/proc/football_pass()
	var/mob/living/human/NEAR = null
	for (var/mob/living/human/PNEAR in range(1,src))
		if (!NEAR && PNEAR != src && PNEAR.civilization == src.civilization)
			NEAR = PNEAR
			break
	if (!NEAR)
		for (var/mob/living/human/PNEAR in range(2,src))
			if (!NEAR && PNEAR != src && PNEAR.civilization == src.civilization)
				NEAR = PNEAR
				break
		if (!NEAR)
			for (var/mob/living/human/PNEAR in range(3,src))
				if (!NEAR && PNEAR != src && PNEAR.civilization == src.civilization)
					NEAR = PNEAR
					break
			if (!NEAR)
				for (var/mob/living/human/PNEAR in range(3,src))
					if (!NEAR && PNEAR != src && PNEAR.civilization == src.civilization)
						NEAR = PNEAR
						break
	if (NEAR)
		var/obj/item/football/FB = src.football
		src.do_attack_animation(src.football)
		src.football = null
		FB.owner = null
		FB.last_owner = src
		FB.throw_at(NEAR, FB.throw_range, FB.throw_speed, src)
		src.do_attack_animation(get_step(src,src.dir))
		playsound(loc, 'sound/effects/football_kick.ogg', 100, 1)
		visible_message("[src] passes \the [FB] to [NEAR].")
		return
//with ball, pressing Z (targeted at mouse position)
/mob/living/human/proc/football_shoot(atom/A = null)
	if (istype(shoes, /obj/item/clothing/shoes/football))
		if (football)
			var/obj/item/football/FB = football
			src.do_attack_animation(football)
			FB.last_owner = src
			if (A)
				FB.throw_at(A, FB.throw_range, FB.throw_speed, src)
			else
				football_shoot_target(FB)
			FB.owner = null
			football = null
			do_attack_animation(get_step(src,src.dir))
			playsound(loc, 'sound/effects/football_kick.ogg', 100, 1)
			visible_message("[src] kicks \the [FB.name].")
			return
/mob/living/human/proc/football_shoot_target(obj/item/football/FB)
	if (!FB)
		return
	var/turf/tgt = null
	if(src.client && src.client.mouse_screen_x && src.client.mouse_screen_y)
		var/atom/eye = src.client.eye
		var/view_radius = isnum(src.client.view) ? src.client.view : 7 // 7 is standard for 15x15 view
		var/tgt_x = eye.x + (src.client.mouse_screen_x - (view_radius + 1))
		var/tgt_y = eye.y + (src.client.mouse_screen_y - (view_radius + 1))
		tgt = locate(tgt_x, tgt_y, eye.z)

	if (tgt && FB && src.football)
		FB.throw_at(tgt, FB.throw_range, FB.throw_speed, src)

//no ball, pressing Z
/mob/living/human/proc/football_tackle()
	if (!football && shoes && istype(shoes, /obj/item/clothing/shoes/football) && src.stats["stamina"][1] >= 15) //proceed to tackle whoever is in front
		stats["stamina"][1] = max(stats["stamina"][1] - 15, 0)
		src.do_attack_animation(get_step(src,dir))
		Weaken(1)
		for (var/mob/living/human/HM in range(1,src))
			if (HM.civilization != src.civilization) //no tackling on same team
				if (prob(60))
					visible_message("<font color='red'>[src] tackles [HM]!</font>")
					playsound(loc, 'sound/weapons/punch1.ogg', 50, 1)
					do_attack_animation(get_step(src,src.dir))
					HM.Weaken(1)
					if (HM.football)
						HM.football.last_owner = HM
						HM.football.owner = null
						HM.football.throw_at(get_step(HM.loc,HM.dir), 1, 1, HM)
						HM.football = null
					return
				else
					visible_message("<font color='yellow'>[src] tries to tackle [HM] but fails!</font>")
					playsound(loc, 'sound/weapons/punchmiss.ogg', 50, 1)
				return
//no ball, pressing C
/mob/living/human/proc/football_pressure(mob/living/human/A = null)
	if (!A)
		var/mob/living/human/NEAR = null
		for (var/mob/living/human/PNEAR in range(1,src))
			if (!NEAR && PNEAR != src && PNEAR.civilization == src.civilization)
				if (NEAR.football)
					NEAR = PNEAR
					break
		if (NEAR)
			A = NEAR
		else
			return
	if (istype(shoes, /obj/item/clothing/shoes/football))
		if (!football && ishuman(A) && get_dist(src,A) <= 1) //if we dont have the ball, try to apply pressure and take the ball without tackling
			if (A.civilization != src.civilization && src.stats["stamina"][1] >= 7) //no pressure on same team
				src.setClickCooldown(10)
				src.stats["stamina"][1] = max(src.stats["stamina"][1] - 7, 0)
				src.do_attack_animation(A)
				var/obj/item/football/opponent_has_ball = null
				if (A.football)
					opponent_has_ball = A.football
				if (prob(35) && opponent_has_ball)
					src.visible_message("<font color='red'>[src] takes the ball from [A]!</font>")
					playsound(src.loc, 'sound/weapons/punch1.ogg', 50, 1)
					A.football = null
					opponent_has_ball.last_owner = src
					opponent_has_ball.owner = src
					src.football = opponent_has_ball
					opponent_has_ball.forceMove(src.loc)
				else
					src.visible_message("<font color='yellow'>[src] pressures [A]!</font>")
					src.do_attack_animation(A)
					playsound(src.loc, 'sound/weapons/punchmiss.ogg', 50, 1)
				return

//no ball, goalkeeper, pressing Z
/mob/living/human/proc/football_gk_pickup()
	if (!src.football && src.shoes && istype(src.shoes, /obj/item/clothing/shoes/football) && src.stats["stamina"][1] >= 15) //proceed
		var/area/A = get_area(src.loc)
		if (istype(A, /area/caribbean/football/blue/goalkeeper) || istype(A, /area/caribbean/football/red/goalkeeper))
			for(var/obj/item/football/FB in range(1,src))
				if ((!FB.owner || FB.owner == src || src.football == FB) && isturf(FB.loc))
					src.put_in_active_hand(FB)
					FB.pickup(src)
					src.football = null
					FB.owner = null
					visible_message("<font color='yellow'>[src] picks up the ball!</font>")
					return

//handle hit by ball
/mob/living/human/proc/football_hitby(obj/item/football/FB)
	if (istype(FB, /obj/item/football))
		if (!src.football)
			if (gloves && istype(gloves, /obj/item/clothing/gloves/goalkeeper))
				var/area/A = get_area(src.loc)
				if (istype(A, /area/caribbean/football/blue/goalkeeper) || istype(A, /area/caribbean/football/red/goalkeeper))
					visible_message("<font color='yellow'>[src] blocks and picks up the ball!</font>")
					src.put_in_active_hand(FB)
					if (FB.owner)
						FB.owner.football = null
						FB.owner = null
					FB.last_owner = src
					FB.pickup(src)
					src.do_attack_animation(get_step(loc,src.dir))
					return
			else
				src.football = FB
				FB.owner = src
				FB.last_owner = src
				FB.update_movement()

//bumping into people in football mode
/mob/living/human/proc/football_bump(atom/movable/AM)
	if (istype(AM, /obj/item/football))
		var/obj/item/football/FB = AM
		if (!FB.owner && !src.football)
			FB.owner = src
			FB.last_owner = src
			src.football = FB
			FB.update_movement()
	else if (istype(AM, /mob/living/human))
		var/mob/living/human/HM = AM
		if (HM.civilization != src.civilization && (HM.dir == OPPOSITE_DIR(src.dir) || findtext(HM.original_job_title, "goalkeeper") || findtext(src.original_job_title, "goalkeeper")))
			if (src.football)
				src.football.last_owner = src
				src.football.owner = null
				src.football = null
				visible_message("[src] bumps into [HM] and loses control of the ball!")
			else if (HM.football)
				HM.football.last_owner = HM
				HM.football.owner = null
				HM.football = null
				visible_message("[HM] bumps into [src] and loses control of the ball!")