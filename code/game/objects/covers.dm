/obj/covers
	name = "floor covers"
	desc = ""
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/base_icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_covered = FALSE
	var/origin_water_level = 0
	var/afloat = FALSE // Part of a commissioned hull (craft/built_body.dm): it rides the deep sea instead of sinking.
	var/not_movable = FALSE //if it can be removed by wrenches
	var/health = 100
	var/maxhealth = 100
	is_cover = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 2.1
	level = 2
	var/amount = FALSE
	var/wall = FALSE
	var/wood = TRUE
	var/onfire = FALSE
	flammable = TRUE
	var/current_area_type = /area/caribbean
	var/incomplete = FALSE
	explosion_resistance = TRUE
	var/list/bullethole_count = list()
	var/list/bullethole_overlays = list()
//	invisibility = 101 //starts invisible
	var/material = "Wood" //Depending on mat, depending on what harms it.
	var/buildstackamount = 8
	var/buildstack = /obj/item/stack/material/wood
	var/adjusts = FALSE //if it adjusts acording to neighbouring sprites

	var/hardness = 50 //for projectile penetration


//for mapmaking purposes
/obj/covers/invisible
	wood = FALSE
	opacity = FALSE
	flammable = FALSE
	density = TRUE
	invisibility = 101

/obj/covers/proc/run_decay()
	if (!src || !wall)
		return
	decay()
	spawn(24000)
		if (src && wall)
			run_decay()
			return
		else
			return

/obj/covers/ex_act(severity)
	// A ship's belt armour takes the worst of a blast (naval/hull_armour.dm).
	severity = hull_armour_soften(src, severity)
	switch(severity)
		if (1.0)
			Destroy(src)
			return
		if (2.0)
			health -= initial(health)/2
			try_destroy()
			return
		if (3.0)
			health -= initial(health)/10
			try_destroy()
			return
		else
	return

/obj/covers/New()
	..()
	register_seasonal_construction()
	initial_opacity = opacity
	maxhealth = health
	spawn(5)
		updateturf()
		if (opacity)
			for(var/obj/roof/R in range(1,src))
				R.update_transparency(0)
	return TRUE

/obj/covers/updateturf()
	..()
	var/turf/T = get_turf(src)
	if (T)
		// A second update (New() runs one after whoever laid it) finds the
		// water already drained by the first: keep the level it found then.
		if (T.water_level || !origin_water_level)
			origin_water_level = T.water_level
		T.water_level = 0
		T.move_delay = 0
		// A floor over open air lights the cells around it (building_lighting.dm).
		if (istype(T, /turf/sky/building))
			var/wake = text2path("/proc/building_wake_cells")
			if (wake)
				call(wake)(T)
	return TRUE

// A cover taken down or destroyed gives back its material on its tile, never
// more than its cheapest recipe cost (dismantle_refund.dm). Mapped covers with
// no recipe give nothing, and nothing is made while the world is being saved,
// loaded or recovered. Paths that already salvage it set amount to 0 first.
/obj/covers/proc/drop_dismantle_refund()
	if (amount <= 0)
		return null
	var/units = min(amount, crafted_refund_units(type))
	amount = 0
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return null
	var/turf/drop_turf = get_turf(src)
	var/refund = crafted_refund_stack(type, null)
	if (!drop_turf || !ispath(refund, /obj/item/stack) || units <= 0)
		return null
	return new refund(drop_turf, units)

/obj/covers/Destroy()			
	unregister_seasonal_construction()
	var/area/caribbean/CURRENTAREA = get_area(src)
	if (!istype(CURRENTAREA, /area/caribbean/void/caves))
		if (wall && !incomplete)
			if (!map.ID == MAP_BATTLE_SHIPS)
				new current_area_type(get_turf(src))
		var/turf/floor/T = get_turf(loc)
		if (T)
			T.water_level = origin_water_level
			T.move_delay = initial(T.move_delay)
	drop_dismantle_refund()
	if (wall == TRUE)
		for(var/obj/roof/R in range(2,src))
			R.collapse_check()
	building_remove_roof()
	..()
	spawn(1)
		if (opacity)
			for(var/obj/roof/R in range(1,src))
				R.update_transparency(0)
	return TRUE

/obj/item/weapon/covers/attack_self(mob/user)
	if (!building_item_usable(src, user))
		return
	var/turf/target = get_step(user, user.dir)
	var/turf/start = get_turf(user)
	if (!target || istype(target, /turf/wall) || istype(target, /turf/floor/beach/water/deep/saltwater))
		to_chat(user, SPAN_WARNING("You cannot build a floor here."))
		return
	var/error = building_floor_error(target) || tile_build_refusal(target, /obj/covers/repairedfloor)
	if (error)
		to_chat(user, SPAN_WARNING(error))
		return
	var/covers_time = 80
	if (ishuman(user))
		var/mob/living/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= H.getStatCoeff("crafting") ** 2
	if (WWinput(user, "Build a floor [dir2text(user.dir)] of you?", "Floor Construction", "Continue", list("Continue", "Stop")) != "Continue")
		return
	if (get_turf(user) != start || !do_after(user, covers_time, start) || !building_item_usable(src, user) || get_turf(user) != start)
		return
	error = building_floor_error(target) || tile_build_refusal(target, /obj/covers/repairedfloor)
	if (error)
		to_chat(user, SPAN_WARNING(error))
		return
	var/obj/covers/repairedfloor/C = new(target)
	if (!C.building_finish_floor())
		qdel(C)
		return
	if (building_open_turf(target))
		C.building_take_upper_face(C.building_roof())
	visible_message(SPAN_NOTICE("[user] finishes placing the floor."))
	if (ishuman(user))
		var/mob/living/human/H = user
		H.adaptStat("crafting", 3)
	qdel(src)

/obj/item/weapon/covers/ship/attack_self(mob/user)
	var/covers_time = 80
	if (ishuman(user))
		var/turf/targetfloor = get_turf(get_step(user, user.dir))
		if (istype(targetfloor, /turf/wall))
			visible_message("<span class='notice'>You can't build here!</span>")
			return
		var/mob/living/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
	if (WWinput(user, "This will start building a new ship floor [dir2text(user.dir)] of you.", "Ship Floor Repair", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the new floor.</span>", "<span class='danger'>You start constructing the new floor.</span>")
		if (do_after(user, covers_time, user.loc) && src)
			var/floor_refusal = tile_build_refusal(get_step(user, user.dir), /obj/covers/repairedfloor/ship)
			if (floor_refusal)
				to_chat(user, SPAN_WARNING(floor_refusal))
				return
			qdel(src)
			new/obj/covers/repairedfloor/ship(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the new floor.</span>")
			if (ishuman(user))
				var/mob/living/human/H = user
				H.adaptStat("crafting", 3)
		return

/obj/covers/fire_act(temperature)
	if (prob(20) && flammable)
		visible_message("<span class = 'warning'>\The [src] is burned away.</span>")
		// A finished floor upstairs burns down to the slab under it; only a
		// burning plain upper floor opens the hole (a stone slab does not burn).
		if (!wall && !is_subfloor() && building_slab_face() && revert_to_subfloor())
			return
		qdel(src)

/obj/covers/CanPass(var/atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (istype(mover,/obj/item/projectile/shell))
			var/obj/item/projectile/shell/S = mover
			if(prob(18) && S.atype == "cannonball")
				visible_message("<span class = 'warning'>\The [mover.name] hits \the [src]!</span>")
				return FALSE
		if (prob(75) && density)
			visible_message("<span class = 'warning'>\The [mover.name] hits \the [src]!</span>")
			return FALSE
		else
			return TRUE
	else
		return ..()

/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	// Cables and pipes through a wall (building_services.dm).
	if (building_service_attackby(W, user))
		return
	if (is_tool(W, TOOL_WRENCH) && not_movable == TRUE)
		return
	if (is_tool(W, TOOL_HAMMER))
		if (!wall)
			// Upstairs a finished floor comes up to the plain upper floor and
			// the ceiling below stays (tile_occupancy.dm). Only the plain floor
			// itself opens a hole, and the player is asked first.
			var/keeps_slab = building_slab_face() && !is_subfloor()
			if (!keeps_slab && building_slab_face() && !building_slab_removal_confirmed(user, src))
				return
			to_chat(user, "You start removing \the [src]...")
			if (do_after(user, 50, src) && !QDELETED(src))
				if (keeps_slab && building_slab_face())
					if (revert_to_subfloor())
						to_chat(user, "You take up \the [src]. The plain upper floor under it stays.")
					return
				to_chat(user, "You removed \the [src] from the floor.")
				qdel(src)
				return
		// A wall that holds nothing up comes down (building_dismantle.dm).
		else if (wall_dismantle_tool(W, user))
			wall_dismantle(W, user)
			return
	if (wall)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (istype(W, /obj/item/weapon/poster/religious))
			to_chat(user, "You start placing the [W] on the [src]...")
			if (do_after(user, 70, src))
				visible_message("[user] places the [W] on the [src].")
				var/obj/structure/poster/religious/RP = new/obj/structure/poster/religious(get_turf(src))
				var/obj/item/weapon/poster/religious/P = W
				RP.religion = P.religion
				RP.symbol = P.symbol
				RP.color1 = P.color1
				RP.color2 = P.color2
				user.drop_from_inventory(W)
				qdel(W)
				return
		if (istype(W, /obj/item/weapon/poster/faction))
			to_chat(user, "You start placing the [W] on the [src]...")
			if (do_after(user, 70, src))
				visible_message("[user] places the [W] on the [src].")
				var/obj/structure/poster/faction/RP = new/obj/structure/poster/faction(get_turf(src))
				var/obj/item/weapon/poster/faction/P = W
				RP.faction = P.faction
				RP.bstyle = P.bstyle
				RP.color1 = P.color1
				RP.color2 = P.color2
				user.drop_from_inventory(W)
				qdel(W)
				return
		if (istype(W, /obj/item/flashlight/torch) && wood == TRUE)
			var/obj/item/flashlight/torch/T = W
			if (prob(33) && T.on)
				onfire = TRUE
				visible_message("<span class='danger'>\The [src] catches fire!</span>")
				start_fire()
				message_admins("[user.name] ([user.ckey]) started a fire with a torch at [src.name] ([src.x],[src.y],[src.z]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)", user.ckey)
				log_game("[user.name] ([user.ckey]) started a fire with a torch at [src.name] ([src.x],[src.y],[src.z])")
		// Stacks, and piles of the wall's own bricks or blocks, repair it.
		if (istype(W, /obj/item/stack) || (W.loose_pile_max && istype(W, buildstack)))
			if (W.amount <= 0)
				qdel(W)
			else
				repair(W, user)
				playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
				user.do_attack_animation(src)
				return
		else
			switch(W.damtype)
				if ("fire")
					health -= W.force * 0.7
				if ("brute")
					health -= W.force * 0.2

		playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
		..()
	else
		return

/obj/covers/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
		// A wall with a refund gives it on deletion instead (Destroy above).
		if (material == "Wood" && amount <= 0)
			// Splinters: one unit of the wood it was built from, never more
			// than it cost. Carpets and other non-wood floors give none.
			var/refund = crafted_refund_stack(type, /obj/item/stack/material/wood)
			if (ispath(refund, /obj/item/stack/material/wood) || ispath(refund, /obj/item/stack/material/woodplank))
				new refund(get_turf(src))
		qdel(src)
		return

/obj/covers/bullet_act(var/obj/item/projectile/proj)
	if (istype(proj, /obj/item/projectile/arrow/arrow/fire) && wood == TRUE)
		health -= proj.damage * 0.25
		if (prob(25))
			onfire = TRUE
			visible_message("<span class='danger'>\The [src] catches fire!</span>")
			start_fire()
		try_destroy()
	else
		if (istype(proj, /obj/item/projectile/shell))
			var/obj/item/projectile/shell/S = proj
			if (S.atype == "HE" || S.atype == "cannonball")
				visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
				qdel(src)
				return
			else
				if (prob(60))
					visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
					qdel(src)
		else
			if (wall)
				if (istype(proj, /obj/item/projectile/bullet) && bullethole_count.len < 13)
					new_bullethole()
				health -= proj.damage * 0.01
				try_destroy()
		return

/obj/covers/proc/start_fire()
	if (onfire && wood)
		var/obj/effect/fire/NF = new/obj/effect/fire(src.loc)
		start_fire_dmg(NF)

/obj/covers/proc/start_fire_dmg(var/obj/effect/fire/SF)
	spawn(80)
		if (!SF)
			return
		if (health > 0)
			health -= 10
			start_fire_dmg(SF)
			return
		else
			try_destroy()
			qdel(SF)
			return

// Scraping a spoon, fork or chopsticks on a hard wall or bars. Ten scrapes turn
// it into a shank of shank_type.
/obj/covers/proc/sharpen_utensil(obj/item/weapon/material/kitchen/utensil/I, mob/living/human/user, shank_type = /obj/item/weapon/material/kitchen/utensil/knife/shank)
	if (I.shiv >= 10)
		return
	I.shiv++
	visible_message(SPAN_WARNING("[user] sharpens \the [I] on \the [src]!"))
	if (I.shiv >= 10)
		user.drop_from_inventory(I)
		user.put_in_hands(new shank_type(user, I.material.name))
		to_chat(user, "\The [I] turns into a shank.")
		qdel(I)
