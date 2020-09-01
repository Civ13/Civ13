/obj/structure/window
	name = "window"
	desc = "A window."
	icon = 'icons/obj/windows.dmi'
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
	var/glassed = FALSE
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
		new/obj/item/weapon/material/shard/glass(loc)
	if (glassed)
		if (istype(src, /obj/structure/window/classic/shoji))
			new/obj/structure/window_frame/shoji(loc)
		else if (istype(src, /obj/structure/window/classic/metal))
			new/obj/structure/window_frame/metal(loc)
		else if (istype(src, /obj/structure/window/classic/portholefull))
			new/obj/structure/window_frame/portholefull(loc)
		else if (istype(src, /obj/structure/window/classic/medieval))
			new/obj/structure/window_frame/medieval(loc)
		else if (istype(src, /obj/structure/window/classic/oriental))
			new/obj/structure/window_frame/oriental(loc)
		else if (istype(src, /obj/structure/window/classic/bamboo))
			new/obj/structure/window_frame/bamboo(loc)
		else if (istype(src, /obj/structure/window/classic/clay))
			new/obj/structure/window_frame/clay(loc)
		else if (istype(src, /obj/structure/window/classic/redearth))
			new/obj/structure/window_frame/redearth(loc)
		else if (istype(src, /obj/structure/window/classic/villa))
			new/obj/structure/window_frame/villa(loc)
		else if (istype(src, /obj/structure/window/classic/villafull))
			new/obj/structure/window_frame/villafull(loc)
		else if (istype(src, /obj/structure/window/classic/brick))
			new/obj/structure/window_frame/brick(loc)
		else if (istype(src, /obj/structure/window/classic/brickfull))
			new/obj/structure/window_frame/brickfull(loc)
		else if (istype(src, /obj/structure/window/classic/stone))
			new/obj/structure/window_frame/stone(loc)
		else if (istype(src, /obj/structure/window/classic/stonefull))
			new/obj/structure/window_frame/stonefull(loc)
		else if (istype(src, /obj/structure/window/classic/sandstone))
			new/obj/structure/window_frame/sandstone(loc)
		else if (istype(src, /obj/structure/window/classic/sandstonefull))
			new/obj/structure/window_frame/sandstonefull(loc)
		else if (istype(src, /obj/structure/window/classic/sumerian))
			new/obj/structure/window_frame/sumerian(loc)
		else
			new/obj/structure/window_frame(loc)
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

/obj/structure/window/attack_hand(mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

	if (usr.a_intent == I_HARM)

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


/obj/structure/window/kick_act(var/mob/living/human/user)
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

	set_dir(turn(dir, 90))
	updateSilicate()
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


	set_dir(turn(dir, 270))
	updateSilicate()

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


	update_nearby_icons()

/obj/structure/window/Destroy()
	density = FALSE
	loc = null
	..()


/obj/structure/window/Move()
	var/ini_dir = dir

	..()
	set_dir(ini_dir)


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

//This proc is used to update the icons of nearby windows.
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
	var/windowglass
	var/stucco_window = TRUE
	icon = 'icons/obj/windows.dmi'

/obj/structure/window_frame/shoji
	icon_state = "shoji_windownew_frame"
	name = "shoji window frame"
	desc = "A good old window frame, only japanese-style."
	stucco_window = FALSE

/obj/structure/window_frame/metal
	icon_state = "windowmetal_frame"
	health = 500
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/portholefull
	icon_state = "metal_porthole_fullframe"
	name = "full metal porthole frame"
	desc = "A large metal porthole with a empty space for glass."
	health = 500
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/medieval
	icon_state = "medieval_windownew_frame"
	name = "medieval window frame"
	desc = "A dark ages window, minus the window."
	stucco_window = FALSE

/obj/structure/window_frame/oriental
	icon_state = "oriental_windownew_frame"
	name = "oriental window frame"
	desc = "A east-oriental style window, minus the window."
	stucco_window = FALSE

/obj/structure/window_frame/bamboo
	icon_state = "bamboo_windownew_frame"
	name = "bamboo window frame"
	desc = "A frame for a window, made of bamboo."
	stucco_window = FALSE

/obj/structure/window_frame/clay
	icon_state = "clay_windownew_frame"
	name = "clay window frame"
	desc = "A empty hole within the clay wall with no glass."
	health = 80
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/redearth
	icon_state = "red_earthwindownew_frame"
	name = "red earthen window frame"
	desc = "A empty three panelled red earthen window frame with no glass."
	health = 120
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/villa
	icon_state = "villa_windownew_frame"
	name = "villa window frame"
	desc = "A elegant roman villa window frame."
	health = 250
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/villafull
	icon_state = "villa_windownew_fullframe"
	name = "villa full window frame"
	desc = "A elegant large roman villa window frame."
	health = 250
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/brick
	icon_state = "brick_windownew_frame"
	name = "brick window frame"
	desc = "A frame for a window, made of bricks."
	health = 200
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/brickfull
	icon_state = "brick_windownew_fullframe"
	name = "full brick window frame"
	desc = "A frame for a full window, made of bricks."
	health = 200
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/stone
	icon_state = "stone_windownew_frame"
	name = "stone window frame"
	desc = "Stone carved to support a few panes of glass."
	health = 250
	flammable = FALSE
	stucco_window = TRUE

/obj/structure/window_frame/stonefull
	icon_state = "stone_windownew_fullframe"
	name = "full stone window frame"
	desc = "Stone carved to support a large window's worth of glass."
	health = 250
	flammable = FALSE
	stucco_window = TRUE

/obj/structure/window_frame/sandstone
	icon_state = "sandstone_windownew_frame"
	name = "sandstone window frame"
	desc = "Sandstone carved to support some glass.."
	health = 250
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/sandstonefull
	icon_state = "sandstone_windownew_fullframe"
	name = "sandstone window frame"
	desc = "Sandstone carved to support a large window's worth of glass.."
	health = 250
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/sumerian
	icon_state = "sumerian_windownew_frame"
	name = "sumerian window frame"
	desc = "A sumerian window made of clay, can hold glass."
	health = 150
	flammable = FALSE
	stucco_window = FALSE

/obj/structure/window_frame/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/generic) && (stucco_window))
		if (!istype(src, /obj/structure/window_frame/stonefull) && !istype(src, /obj/structure/window_frame/stone))
			user << "You start adding stucco to the wood window frame..."
			if (do_after(user, 20, src))
				user << "You finish adding stucco to the wood window frame, rendering over it."
				new /obj/structure/window_frame/redearth(loc)
				qdel(W)
				qdel(src)
	if (istype(W, /obj/item/weapon/stucco/roman) && (stucco_window))
		if (istype(src, /obj/structure/window_frame/stone))
			user << "You start adding roman stucco to the stone window..."
			if (do_after(user, 20, src))
				user << "You finish adding roman stucco to the stone window, rendering over it."
				new /obj/structure/window_frame/villa(loc)
				qdel(W)
				qdel(src)
		if (istype(src, /obj/structure/window_frame/stonefull))
			user << "You start adding roman stucco to the full stone window..."
			if (do_after(user, 20, src))
				user << "You finish adding roman stucco to the full stone window, rendering over it."
				new /obj/structure/window_frame/villafull(loc)
				qdel(W)
				qdel(src)
	if (istype(W, /obj/item/stack/material/glass))
		var/obj/item/stack/S = W
		if (S.amount >= 3)
			visible_message("<span class = 'notice'>[user] starts to add glass to the window frame...</span>")
			if (do_after(user, 50, src))
				if (istype(src, /obj/structure/window_frame/shoji))
					new/obj/structure/window/classic/shoji(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/metal))
					new/obj/structure/window/classic/metal(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/portholefull))
					new/obj/structure/window/classic/portholefull(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/medieval))
					new/obj/structure/window/classic/medieval(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/oriental))
					new/obj/structure/window/classic/oriental(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/bamboo))
					new/obj/structure/window/classic/bamboo(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/clay))
					new/obj/structure/window/classic/clay(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/redearth))
					new/obj/structure/window/classic/redearth(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/villa))
					new/obj/structure/window/classic/villa(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/villafull))
					new/obj/structure/window/classic/villafull(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/brick))
					new/obj/structure/window/classic/brick(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/brickfull))
					new/obj/structure/window/classic/brickfull(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/stone))
					new/obj/structure/window/classic/stone(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/stonefull))
					new/obj/structure/window/classic/stonefull(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/sandstone))
					new/obj/structure/window/classic/sandstone(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/sandstonefull))
					new/obj/structure/window/classic/sandstonefull(get_turf(src))
				else if (istype(src, /obj/structure/window_frame/sumerian))
					new/obj/structure/window/classic/sumerian(get_turf(src))
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
	glassed = TRUE

/obj/structure/window/clean
	desc = "A good old window."
	icon_state = "window_clear"
	basestate = "window_clear"
	glasstype = /obj/item/stack/material/glass
	maximal_heat = T0C + 100
	damage_per_fire_tick = 5.0
	maxhealth = 20.0
	layer = MOB_LAYER + 0.02
	density = FALSE // so we can touch curtains from any direction
	flammable = TRUE

/obj/structure/window/classic/shoji
	icon_state = "shoji_windownew"
	basestate = "shoji_windownew"
	name = "shoji window"
	desc = "A good old window, only japanese-style."

/obj/structure/window/classic/metal
	icon_state = "windowmetal"
	basestate = "windowmetal"
	flammable = FALSE
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	maxhealth = 300.0

/obj/structure/window/classic/portholefull
	icon_state = "metal_porthole_full"
	name = "full metal porthole"
	desc = "A large metal porthole, with a large stretched sheet of glass."
	flammable = FALSE
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	maxhealth = 300.0

/obj/structure/window/classic/medieval
	icon_state = "medieval_windownew"
	basestate = "medieval_windownew"
	name = "medieval window"
	desc = "A dark ages window."

/obj/structure/window/classic/oriental
	icon_state = "oriental_windownew"
	basestate = "oriental_windownew"
	name = "oriental window"
	desc = "A east-oriental style window."

/obj/structure/window/classic/bamboo
	icon_state = "bamboo_windownew"
	basestate = "bamboo_windownew"
	name = "bamboo window"
	desc = "A bamboo window, made of bamboo."

/obj/structure/window/classic/clay
	icon_state = "clay_windownew"
	icon_state = "clay_windownew"
	name = "clay window"
	desc = "A crude empty hole within the clay wall with glass."
	flammable = FALSE
	maximal_heat = T0C + 1400
	damage_per_fire_tick = 1.5
	maxhealth = 150.0

/obj/structure/window/classic/redearth
	icon_state = "red_earthwindownew"
	basestate = "red_earthwindownew"
	name = "red earthen window"
	desc = "A three panelled red earthen window."
	flammable = FALSE
	maximal_heat = T0C + 1400
	damage_per_fire_tick = 1.0
	maxhealth = 200.0

/obj/structure/window/classic/villa
	icon_state = "villa_windownew"
	basestate = "villa_windownew"
	name = "villa window"
	desc = "A elegant roman villa window."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 200
	flammable = FALSE

/obj/structure/window/classic/villafull
	icon_state = "villa_windownew_full"
	basestate = "villa_windownew_full"
	name = "full villa window"
	desc = "A elegant large roman villa full-window."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 200
	flammable = FALSE

/obj/structure/window/classic/brick
	icon_state = "brick_windownew"
	name = "brick window"
	desc = "A brick window, made of bricks."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 200
	flammable = FALSE

/obj/structure/window/classic/brickfull
	icon_state = "brick_windownew_full"
	name = "full brick window"
	desc = "A full brick window, made of bricks."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 200
	flammable = FALSE

/obj/structure/window/classic/stone
	icon_state = "stone_windownew"
	name = "stone window"
	desc = "A stone window with glass-covered holes."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 250
	flammable = FALSE

/obj/structure/window/classic/stonefull
	icon_state = "stone_windownew_full"
	name = "full stone window"
	desc = "A stone window with large glass-covered holes."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 250
	flammable = FALSE

/obj/structure/window/classic/sandstone
	icon_state = "sandstone_windownew"
	name = "sandstone window"
	desc = "Sandstone with glass windows."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 250
	flammable = FALSE

/obj/structure/window/classic/sandstonefull
	icon_state = "sandstone_windownew_full"
	name = "full sandstone window"
	desc = "Sandstone with large glass windows."
	maximal_heat = T0C + 1600
	damage_per_fire_tick = 1.0
	health = 250
	flammable = FALSE

/obj/structure/window/classic/sumerian
	icon_state = "sumerian_windownew"
	name = "sumerian window"
	desc = "Sumerian clay wall with some glass in it."
	flammable = FALSE
	maximal_heat = T0C + 1400
	damage_per_fire_tick = 1.0
	maxhealth = 200.0

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


/obj/structure/window/classic/update_icon()
	return

/obj/structure/window/classic/update_nearby_icons()
	return

/obj/structure/window/classic/metal/shatter(var/display_message = TRUE)
	var/myturf = get_turf(src)
	spawn (1)
		new/obj/structure/window_frame/metal(myturf)
	..(display_message)

/obj/structure/window/New(Loc, constructed=0)
	..()

	//player-constructed windows
	if (constructed)
		state = FALSE
