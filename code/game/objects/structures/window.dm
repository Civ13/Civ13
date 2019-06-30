/obj/structure/window
	name = "window"
	desc = "A window."
	icon = 'icons/obj/structures.dmi'
	density = TRUE
	w_class = 3

	layer = 3.2//Just above doors
	anchored = 1.0
	flags = ON_BORDER
	var/maxhealth = 14.0
	var/maximal_heat = T0C + 100 		// Maximal heat before this window begins taking damage from fire
	var/damage_per_fire_tick = 2.0 		// Amount of damage per fire tick. Regular windows are not fireproof so they might as well break quickly.
	var/health
	var/ini_dir = null
	var/state = 2
	var/reinf = FALSE
	var/basestate
	var/shardtype = /obj/item/weapon/material/shard
	var/glasstype = null // Set this in subtypes. Null is assumed strange or otherwise impossible to dismantle, such as for shuttle glass.
	var/silicate = FALSE // number of units of silicate
	not_movable = FALSE
	not_disassemblable = FALSE
/obj/structure/window/examine(mob/user)
	. = ..(user)

	if (health == maxhealth)
		user << "<span class='notice'>It looks fully intact.</span>"
	else
		var/perc = health / maxhealth
		if (perc > 0.75)
			user << "<span class='notice'>It has a few cracks.</span>"
		else if (perc > 0.5)
			user << "<span class='warning'>It looks slightly damaged.</span>"
		else if (perc > 0.25)
			user << "<span class='warning'>It looks moderately damaged.</span>"
		else
			user << "<span class='danger'>It looks heavily damaged.</span>"
	if (silicate)
		if (silicate < 30)
			user << "<span class='notice'>It has a thin layer of silicate.</span>"
		else if (silicate < 70)
			user << "<span class='notice'>It is covered in silicate.</span>"
		else
			user << "<span class='notice'>There is a thick layer of silicate covering it.</span>"

/obj/structure/window/proc/take_damage(var/damage = 0,  var/sound_effect = TRUE)
	var/initialhealth = health

	if (silicate)
		damage = damage * (1 - silicate / 200)

	health = max(0, health - damage)

	if (health <= 0)
		shatter()
	else
		if (sound_effect)
			playsound(loc, 'sound/effects/Glasshit.ogg', 100, TRUE)
		if (health < maxhealth / 4 && initialhealth >= maxhealth / 4)
			visible_message("[src] looks like it's about to shatter!" )
		else if (health < maxhealth / 2 && initialhealth >= maxhealth / 2)
			visible_message("[src] looks seriously damaged!" )
		else if (health < maxhealth * 3/4 && initialhealth >= maxhealth * 3/4)
			visible_message("Cracks begin to appear in [src]!" )
	return

/obj/structure/window/proc/apply_silicate(var/amount)
	if (health < maxhealth) // Mend the damage
		health = min(health + amount * 3, maxhealth)
		if (health == maxhealth)
			visible_message("[src] looks fully repaired." )
	else // Reinforce
		silicate = min(silicate + amount, 100)
		updateSilicate()

/obj/structure/window/proc/updateSilicate()
	if (overlays)
		overlays.Cut()

	var/image/img = image(icon, icon_state)
	img.color = "#ffffff"
	img.alpha = silicate * 255 / 100
	overlays += img

/obj/structure/window/proc/shatter(var/display_message = TRUE)
	playsound(get_turf(src), "shatter", 70, TRUE)
	if (display_message)
		visible_message("<span class = 'warning'>[src] shatters!</span>")
	if (dir == SOUTHWEST)
		var/index = null
		index = FALSE
		while (index < 2)
			new shardtype(loc) //todo pooling?
			if (reinf) PoolOrNew(/obj/item/stack/rods, loc)
			index++
	else
		new shardtype(loc) //todo pooling?
		if (reinf) PoolOrNew(/obj/item/stack/rods, loc)
	qdel(src)
	return


/obj/structure/window/bullet_act(var/obj/item/projectile/Proj)

	var/proj_damage = Proj.get_structure_damage()
	if (!proj_damage) return

	..()
	take_damage(proj_damage)
	return


/obj/structure/window/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			shatter(0)
			return
		if (3.0)
			if (prob(50))
				shatter(0)
				return

//TODO: Make full windows a separate type of window.
//Once a full window, it will always be a full window, so there's no point
//having the same type for both.
/obj/structure/window/proc/is_full_window()
	return (dir == SOUTHWEST || dir == SOUTHEAST || dir == NORTHWEST || dir == NORTHEAST)

/obj/structure/window/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover) && mover.checkpass(PASSGLASS))
		return TRUE
	if (is_full_window())
		return FALSE	//full tile window, you can't move into it!
	if (get_dir(loc, target) & dir)
		return !density
	else
		return TRUE

/obj/structure/window/CheckExit(atom/movable/O as mob|obj, target as turf)
	if (istype(O) && O.checkpass(PASSGLASS))
		return TRUE
	if (get_dir(O.loc, target) == dir)
		return FALSE
	return TRUE

/obj/structure/window/hitby(AM as mob|obj)
	..()
	visible_message("<span class='danger'>[src] was hit by [AM].</span>")
	var/tforce = FALSE
	if (ismob(AM))
		tforce = 40
	else if (isobj(AM))
		var/obj/item/I = AM
		tforce = I.throwforce
	if (reinf) tforce *= 0.25
	if (health - tforce <= 7 && !reinf)
		set_anchored(FALSE)
		step(src, get_dir(AM, src))
	take_damage(tforce)
/*
/obj/structure/window/attack_tk(mob/user as mob)
	user.visible_message("<span class='notice'>Something knocks on [src].</span>")
	playsound(loc, 'sound/effects/Glasshit.ogg', 50, TRUE)
*/
/obj/structure/window/attack_hand(mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

	if (usr.a_intent == I_HURT)

		if (istype(usr,/mob/living/carbon/human))
			var/mob/living/carbon/human/H = usr
			if (H.species.can_shred(H))
				attack_generic(H,25)
				return

		playsound(loc, 'sound/effects/glassknock.ogg', 80, TRUE)
		user.do_attack_animation(src)
		usr.visible_message("<span class='danger'>\The [usr] bangs against \the [src]!</span>",
							"<span class='danger'>You bang against \the [src]!</span>",
							"You hear a banging sound.")
	else
		playsound(loc, 'sound/effects/glassknock.ogg', 80, TRUE)
		usr.visible_message("[usr.name] knocks on the [name].",
							"You knock on the [name].",
							"You hear a knocking sound.")
	return

/obj/structure/window/attack_generic(var/mob/user, var/damage)
	if (istype(user))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		user.do_attack_animation(src)
	if (!damage)
		return
	if (damage >= 10)
		visible_message("<span class='danger'>[user] smashes into [src]!</span>")
		take_damage(damage)
	else
		visible_message("<span class='notice'>\The [user] bonks \the [src] harmlessly.</span>")
	return TRUE


/obj/structure/window/kick_act(var/mob/living/carbon/human/user)
	if(!..())
		return
	user.stats["stamina"][1] = max(user.stats["stamina"][1] - rand(10,15), 0)
	visible_message("<span class='danger'>[user] kicks the [src]!</span>")
	take_damage(rand(5,10))

/obj/structure/window/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really wish I did not need this
	if (istype(W, /obj/item/weapon/grab) && get_dist(src,user)<2)
		var/obj/item/weapon/grab/G = W
		if (istype(G.affecting,/mob/living))
			var/mob/living/M = G.affecting
			var/state = G.state
			qdel(W)	//gotta delete it here because if window breaks, it won't get deleted
			switch (state)
				if (1)
					M.visible_message("<span class='warning'>[user] slams [M] against \the [src]!</span>")
					M.apply_damage(7)
					hit(10)
				if (2)
					M.visible_message("<span class='danger'>[user] bashes [M] against \the [src]!</span>")
					if (prob(50))
						M.Weaken(1)
					M.apply_damage(10)
					hit(25)
				if (3)
					M.visible_message("<span class='danger'><big>[user] crushes [M] against \the [src]!</big></span>")
					M.Weaken(5)
					M.apply_damage(20)
					hit(50)
			return

	if (W.flags & NOBLUDGEON) return

	if (istype(W, /obj/item/weapon/wrench))
		if (reinf && state >= 1)
			state = 3 - state
			update_nearby_icons()
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
			user << (state == TRUE ? "<span class='notice'>You have unfastened the window from the frame.</span>" : "<span class='notice'>You have fastened the window to the frame.</span>")
		else if (reinf && state == FALSE)
			set_anchored(!anchored)
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
			user << (anchored ? "<span class='notice'>You have fastened the frame to the floor.</span>" : "<span class='notice'>You have unfastened the frame from the floor.</span>")
		else if (!reinf)
			set_anchored(!anchored)
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
			user << (anchored ? "<span class='notice'>You have fastened the window to the floor.</span>" : "<span class='notice'>You have unfastened the window.</span>")
	else if (istype(W, /obj/item/weapon/crowbar) && reinf && state <= 1)
		state = TRUE - state
		playsound(loc, 'sound/items/Crowbar.ogg', 75, TRUE)
		user << (state ? "<span class='notice'>You have pried the window into the frame.</span>" : "<span class='notice'>You have pried the window out of the frame.</span>")
	else if (istype(W, /obj/item/weapon/hammer) && !anchored && (!state || !reinf))
		if (!glasstype)
			user << "<span class='notice'>You're not sure how to dismantle \the [src] properly.</span>"
		else
			playsound(loc, 'sound/items/Ratchet.ogg', 75, TRUE)
			visible_message("<span class='notice'>[user] dismantles \the [src].</span>")
			if (dir == SOUTHWEST)
				var/obj/item/stack/material/mats = new glasstype(loc)
				mats.amount = is_fulltile() ? 4 : 2
			else
				new glasstype(loc)
			qdel(src)
	else
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (W.damtype == BRUTE || W.damtype == BURN)
			user.do_attack_animation(src)
			hit(W.force)
			if (health <= 7)
				set_anchored(FALSE)
				step(src, get_dir(user, src))
		else
			playsound(loc, 'sound/effects/Glasshit.ogg', 75, TRUE)
		..()
	return

/obj/structure/window/proc/hit(var/damage, var/sound_effect = TRUE)
	if (reinf) damage *= 0.5
	take_damage(damage)
	return


/obj/structure/window/proc/rotate()
	set name = "Rotate Window Counter-Clockwise"
	set category = null
	set src in oview(1)

	if (usr.incapacitated())
		return FALSE

	if (anchored)
		usr << "It is fastened to the floor therefore you can't rotate it!"
		return FALSE

	update_nearby_tiles(need_rebuild=1) //Compel updates before
	set_dir(turn(dir, 90))
	updateSilicate()
	update_nearby_tiles(need_rebuild=1)
	return


/obj/structure/window/proc/revrotate()
	set name = "Rotate Window Clockwise"
	set category = null
	set src in oview(1)

	if (usr.incapacitated())
		return FALSE

	if (anchored)
		usr << "It is fastened to the floor therefore you can't rotate it!"
		return FALSE

	update_nearby_tiles(need_rebuild=1) //Compel updates before
	set_dir(turn(dir, 270))
	updateSilicate()
	update_nearby_tiles(need_rebuild=1)
	return

/obj/structure/window/New(Loc, start_dir=null, constructed=0)
	..()

	//player-constructed windows
	if (constructed)
		set_anchored(FALSE)

	if (start_dir)
		set_dir(start_dir)

	health = maxhealth

	ini_dir = dir

	update_nearby_tiles(need_rebuild=1)
	update_nearby_icons()


/obj/structure/window/Destroy()
	density = FALSE
	update_nearby_tiles()
	var/turf/location = loc
	loc = null
	for (var/obj/structure/window/W in orange(location, TRUE))
		W.update_icon()
	loc = location
	..()


/obj/structure/window/Move()
	var/ini_dir = dir
	update_nearby_tiles(need_rebuild=1)
	..()
	set_dir(ini_dir)
	update_nearby_tiles(need_rebuild=1)

//checks if this window is a full-tile one
/obj/structure/window/proc/is_fulltile()
	if (dir & (dir - 1))
		return TRUE
	return FALSE

/obj/structure/window/proc/set_anchored(var/new_anchored)
	if (anchored == new_anchored)
		return
	anchored = new_anchored
	update_verbs()
	update_nearby_icons()

//This proc is used to update the icons of nearby windows. It should not be confused with update_nearby_tiles(), which is an atmos proc!
/obj/structure/window/proc/update_nearby_icons()
	update_icon()
	for (var/obj/structure/window/W in orange(src, TRUE))
		W.update_icon()

//Updates the availabiliy of the rotation verbs
/obj/structure/window/proc/update_verbs()
	if (anchored)
		verbs -= /obj/structure/window/proc/rotate
		verbs -= /obj/structure/window/proc/revrotate
	else
		verbs += /obj/structure/window/proc/rotate
		verbs += /obj/structure/window/proc/revrotate

//merges adjacent full-tile windows into one (blatant ripoff from game/smoothwall.dm)
/obj/structure/window/update_icon()
	//A little cludge here, since I don't know how it will work with slim windows. Most likely VERY wrong.
	//this way it will only update full-tile ones
	overlays.Cut()
	if (!is_fulltile())
		icon_state = "[basestate]"
		return
	var/list/dirs = list()
	if (anchored)
		for (var/obj/structure/window/W in orange(src,1))
			if (W.anchored && W.density && W.type == type && W.is_fulltile()) //Only counts anchored, not-destroyed fill-tile windows.
				dirs += get_dir(src, W)

/*	var/list/connections = dirs_to_corner_states(dirs)

	icon_state = ""
	for (var/i = TRUE to 4)
		var/image/I = image(icon, "[basestate][connections[i]]", dir = TRUE<<(i-1))
		overlays += I
*/
	return

/obj/structure/window/fire_act(temperature)
	if (prob((temperature/500) * 70))
		shatter()

/obj/structure/window_frame
	desc = "A good old window frame."
	icon_state = "windownew_frame"
	layer = MOB_LAYER + 0.01
	anchored = TRUE
	var/health = 20
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/window_frame/metal
	icon_state = "windowmetal_frame"

/obj/structure/window_frame/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/material/glass))
		var/obj/item/stack/S = W
		if (S.amount >= 3)
			visible_message("<span class = 'notice'>[user] starts to add glass to the window frame...</span>")
			if (do_after(user, 50, src))
				if (istype(src, /obj/structure/window_frame/shoji))
					new/obj/structure/window/classic/shoji(get_turf(src))
				else
					new/obj/structure/window/classic(get_turf(src))
				visible_message("<span class = 'notice'>[user] adds glass to the window frame.</span>")
				S.use(3)
				qdel(src)
		else
			user << "<span class = 'warning'>You need at least 3 sheets of glass.</span>"
	else
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (W.damtype == BRUTE || W.damtype == BURN)
			user.do_attack_animation(src)
			health -= (W.force * 0.2)
	if (health <= 0)
		visible_message("<span class = 'notice'>The window is broken by [user]!</span>")
		qdel(src)
		return

/obj/structure/window_frame/shoji
	icon_state = "shoji_windownewframe"
	name = "shoji window frame"
	desc = "A good old window frame, only Japanese-style."

/obj/structure/window/classic
	desc = "A good old window."
	icon_state = "windownew"
	basestate = "windownew"
	glasstype = /obj/item/stack/material/glass
	maximal_heat = T0C + 100
	damage_per_fire_tick = 5.0
	maxhealth = 20.0
	layer = MOB_LAYER + 0.02
	density = FALSE // so we can touch curtains from any direction
	flammable = TRUE

/obj/structure/window/classic/metal
	icon_state = "windowmetal"
	basestate = "windowmetal"
	flammable = FALSE
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	maxhealth = 80.0

/obj/structure/window/classic/reinforced
	reinf = TRUE

/obj/structure/window/classic/is_full_window()
	return TRUE

/obj/structure/window/classic/take_damage(damage)
	if (damage > 12 || (damage > 5 && prob(damage * 5)))
		if (!reinf || (reinf && prob(20)))
			shatter()
	else return

/obj/structure/window/classic/hitby(AM as mob|obj)
	..()
	visible_message("<span class='danger'>[src] was hit by [AM].</span>")
	var/tforce = FALSE
	if (ismob(AM))
		tforce = 40
	else if (isobj(AM))
		var/obj/item/I = AM
		tforce = I.throwforce
	if (reinf) tforce *= 0.25
	take_damage(tforce)

/obj/structure/window/classic/bullet_act(var/obj/item/projectile/P)
	if (!P || !P.nodamage)
		shatter()
		return PROJECTILE_CONTINUE

/obj/structure/window/classic/shatter(var/display_message = TRUE)
	var/myturf = get_turf(src)
	spawn (1)
		if (istype(src, /obj/structure/window/classic/shoji))
			new/obj/structure/window_frame/shoji(myturf)
		else
			new/obj/structure/window_frame(myturf)
	..(display_message)


/obj/structure/window/classic/update_icon()
	return

/obj/structure/window/classic/update_nearby_icons()
	return

/obj/structure/window/classic/metal/shatter(var/display_message = TRUE)
	var/myturf = get_turf(src)
	spawn (1)
		new/obj/structure/window_frame/metal(myturf)
	..(display_message)

/obj/structure/window/classic/shoji
	icon_state = "shoji_windownew"
	basestate = "shoji_windownew"
	name = "shoji window"
	desc = "A good old window, only Japanese-style."



/obj/structure/window/New(Loc, constructed=0)
	..()

	//player-constructed windows
	if (constructed)
		state = FALSE
