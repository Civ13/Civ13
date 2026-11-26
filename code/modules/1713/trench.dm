
/turf
	var/previous_turf = /turf/floor/dirt

/turf/floor/trench
	map_storage_saved_vars = "icon_state;name;trench_filling;trench_cut;trench_lining;trench_water_level"
	name = "trench"
	icon = 'icons/turf/trench.dmi'
	icon_state = "trench"
	base_icon_state = "trench"
	//var/image/over_OS_darkness = null
	plane = UNDERFLOOR_PLANE
	initial_flooring = /decl/flooring/trench
	var/trench_filling = 0
	// Additional cuts below the original trench bed, not changes to the terrain grid.
	var/trench_cut = 0
	var/trench_lining = null
	// Null for pre-existing/map-authored water, which keeps its legacy level.
	var/trench_water_level = null
	flooded = FALSE
	salty = FALSE
	var/message_cooldown = 0

/turf/floor/trench/New()
	if (!icon_state)
		icon_state = "trench"

	..()
	if (restoring || (persistence_active_operation && persistence_active_operation.kind == "load"))
		return
	var/datum/admission = persistence_admission_identity
	spawn(4)
		if (istype(src, /turf/floor/trench) && !persistence_admission_changed(admission))
			trench_refresh()
			for (var/direction in list(1,2,4,8,5,6,9,10))
				var/turf/floor/trench/neighbor = get_step(src, direction)
				if (istype(neighbor))
					neighbor.update_icon()

/turf/floor/trench/after_load()
	..()
	// Rebuild only appearance/movement after the complete level is loaded.
	// A restored cut must not look for a new inlet or change its saved surface.
	update_icon()
	if (istype(src, /turf/floor/trench/flooded))
		var/turf/floor/trench/flooded/water = src
		water.check_bridge()

/turf/floor/trench/proc/trench_refresh()
	update_icon()
	if (!flooded)
		trench_try_flood()
		return
	var/level = canal_flood_source_level(src)
	for (var/direction in cardinal)
		var/turf/floor/neighbor = get_step(src, direction)
		if (!istype(neighbor))
			continue
		if (istype(neighbor, /turf/floor/trench) && !isnull(level))
			var/turf/floor/trench/cut = neighbor
			cut.trench_try_flood()
		else if (!isnull(level) && !neighbor.flooded && neighbor.irrigation)
			neighbor.irrigate(salty ? "salty" : "fresh")

// Take the highest eligible adjacent surface, with saltwater winning a tie.
// A corner alone is not a navigable connection.
/turf/floor/trench/proc/trench_best_inlet(require_reach = TRUE)
	var/best_level = null
	var/turf/floor/best
	for (var/direction in cardinal)
		var/turf/floor/water = get_step(src, direction)
		var/level = canal_flood_source_level(water)
		if (isnull(level) || (require_reach && !canal_can_flood(water, src)))
			continue
		if (!istype(water, /turf/floor/trench/flooded) && (!map || !(map.civilizations || map.nomads || map.ID == MAP_COLONY || map.ID == MAP_FOUR_COLONIES || map.ID == MAP_PIONEERS || map.ID == MAP_BOHEMIA)))
			continue
		if (isnull(best_level) || level > best_level || (level == best_level && water.salty && !best.salty))
			best = water
			best_level = level
	return best

/turf/floor/trench/proc/trench_bed_level()
	return terrain_height_at(src) - trench_cut + trench_filling

/turf/floor/trench/proc/trench_try_flood()
	if (flooded || !map)
		return FALSE
	var/turf/floor/water = trench_best_inlet()
	if (!water)
		return FALSE
	return trench_take_water(canal_flood_source_level(water), water.salty)

// Keep persistent cut and fill state across the dry/wet turf subtype change.
/turf/floor/trench/proc/trench_take_water(level, salt = FALSE)
	var/obj/structure/canal_lock/dock_gate/gate = dock_basin_turfs[src]
	if (flooded || isnull(level) || level < trench_bed_level() || (gate && !QDELETED(gate) && gate.drained))
		return FALSE
	trench_change_water(salt ? /turf/floor/trench/flooded/salty : /turf/floor/trench/flooded, level)
	return TRUE

/turf/floor/trench/proc/trench_change_water(path, level)
	var/cut = trench_cut
	var/fill = trench_filling
	var/lining = trench_lining
	var/base = previous_turf
	var/turf/floor/trench/next = ChangeTurf(path)
	next.trench_cut = cut
	next.trench_filling = fill
	next.trench_lining = lining
	next.previous_turf = base
	next.trench_water_level = level
	return next

/turf/floor/trench/make_grass()
	overlays.Cut()
	if (islist(decals))
		decals.Cut()
		decals = null

	set_light(0)
	levelupdate()

	update_icon()

/turf/floor/trench/flooded
	name = "flooded trench"
	flooded = TRUE
	icon_state = "trench_flooded"
	base_icon_state = "trench_flooded"
	initial_flooring = /decl/flooring/trench/flooded
	salty = FALSE
	move_delay = 4

/turf/floor/trench/flooded/proc/check_bridge()
	if(locate(/obj/covers/repairedfloor) in contents)
		move_delay = 0
	if(locate(/obj/structure/vehicleparts/frame) in contents)
		move_delay = 0
	return

/turf/floor/trench/flooded/salty
	name = "flooded saltwater trench"
	salty = TRUE


/turf/floor/trench/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	if (!user || get_dist(src, user) > 2)
		return
	to_chat(user, SPAN_NOTICE("Depth: [1 + trench_cut] step[trench_cut ? "s" : ""]. Lining: [trench_lining ? trench_lining : "none"]."))
	if (!flooded)
		var/turf/floor/water = trench_best_inlet(FALSE)
		if (water)
			var/difference = trench_bed_level() - canal_flood_source_level(water)
			if (difference > 0)
				to_chat(user, SPAN_NOTICE("The trench bed is [difference] level[difference == 1 ? "" : "s"] above the adjacent water."))

/turf/floor/trench/proc/trench_max_cut()
	switch (trench_lining)
		if ("stone")
			return 4
		if ("timber")
			return 2
	return 1

/turf/floor/trench/proc/trench_can_work(mob/living/human/H, obj/item/tool, datum/admission)
	if (persistence_admission_changed(admission) || !istype(H) || QDELETED(H) || QDELETED(tool) || tool.loc != H || H.get_active_hand() != tool || !isturf(H.loc) || H.z != z || !H.Adjacent(src) || H.incapacitated() || H.restrained())
		return FALSE
	var/obj/structure/canal_lock/dock_gate/gate = dock_basin_turfs[src]
	if ((gate && !QDELETED(gate) && gate.busy) || craft_at(src))
		return FALSE
	for (var/obj/O in src)
		if (O.density || istype(O, /obj/covers) || istype(O, /obj/structure) || istype(O, /obj/roof))
			return FALSE
	for (var/mob/living/L in src)
		if (L != H)
			return FALSE
	return TRUE

/turf/floor/trench/proc/trench_deepen(mob/living/human/H, obj/item/tool)
	var/datum/admission = persistence_admission_identity
	if (!trench_can_work(H, tool, admission))
		to_chat(H, SPAN_WARNING("You need clear access to the trench to deepen it."))
		return
	if (!trench_filling && trench_cut >= trench_max_cut())
		to_chat(H, SPAN_WARNING(trench_lining == "stone" ? "You cannot safely dig this trench any deeper." : "You need stronger lining before you can dig any deeper."))
		return
	var/start_cut = trench_cut
	var/start_fill = trench_filling
	var/start_type = type
	H.visible_message(SPAN_NOTICE("[H] starts deepening the trench."), SPAN_NOTICE("You start deepening the trench."))
	if (!do_after(H, work_delay(H, 45, WORK_DIG, tool), src))
		return
	if (type != start_type || trench_cut != start_cut || trench_filling != start_fill || !trench_can_work(H, tool, admission) || (!trench_filling && trench_cut >= trench_max_cut()))
		return
	if (trench_filling)
		trench_filling--
	else
		trench_cut++
	excavation_spoil(get_turf(H), 1)
	to_chat(H, SPAN_NOTICE("You dig out a pile of dirt and lower the trench bed."))
	if (trench_try_flood())
		to_chat(H, SPAN_NOTICE("Water flows into the deepened trench."))

/turf/floor/trench/proc/trench_line(mob/living/human/H, obj/item/stack/S, lining)
	var/datum/admission = persistence_admission_identity
	var/cost = lining == "stone" ? 4 : 2
	if (!trench_can_work(H, S, admission) || S.amount < cost)
		to_chat(H, SPAN_WARNING("You need a clear trench and [cost] [lining == "stone" ? "stone" : "wood planks"]."))
		return
	if (trench_lining == "stone" || trench_lining == lining)
		to_chat(H, SPAN_NOTICE("This trench already has lining at least that strong."))
		return
	var/start_lining = trench_lining
	var/start_type = type
	to_chat(H, SPAN_NOTICE("You start lining the trench with [lining]."))
	if (!do_after(H, work_delay(H, 45, WORK_DIG, null), src))
		return
	if (type != start_type || trench_lining != start_lining || !trench_can_work(H, S, admission) || S.amount < cost || !S.use(cost))
		return
	trench_lining = lining
	to_chat(H, SPAN_NOTICE("You reinforce the trench with [lining]."))

/turf/floor/trench/attackby(obj/item/C as obj, mob/user as mob)
	if (ishuman(user) && is_tool(C, TOOL_SHOVEL) && user.a_intent == I_HARM)
		trench_deepen(user, C)
		return TRUE
	if (ishuman(user) && user.a_intent == I_HELP)
		if (istype(C, /obj/item/stack/material/woodplank))
			trench_line(user, C, "timber")
			return TRUE
		if (istype(C, /obj/item/stack/material/stone))
			trench_line(user, C, "stone")
			return TRUE
	if (ishuman(user) && istype(C, /obj/item/weapon/barrier) && !istype(C, /obj/item/weapon/barrier/sandbag))
		var/datum/admission = persistence_admission_identity
		if (!trench_can_work(user, C, admission))
			to_chat(user, SPAN_WARNING("You need clear access to the trench to fill it."))
			return TRUE
		var/start_type = type
		var/choice = WWinput(user, "Do you want to start filling up the trench with \the [C]?","Trench","Yes",list("Yes","No"))
		if (choice == "Yes" && type == start_type && trench_can_work(user, C, admission))
			to_chat(user, "You shove some dirt into the trench.")
			qdel(C)
			check_filling()
		return TRUE
	return ..()

/turf/floor/trench/flooded/attackby(obj/item/C as obj, mob/user as mob)
	// A hole in a built hull sailing the canal (hull_ledger.dm).
	if (hull_patch_attack(C, user, src))
		return TRUE
	if (istype(C, /obj/item/weapon/reagent_containers/glass) || istype(C, /obj/item/weapon/reagent_containers/food/drinks))
		var/obj/item/weapon/reagent_containers/RG = C
		if (istype(RG) && RG.is_open_container())
			if (do_after(user, 15, src, check_for_repeats = FALSE))
				var/sumex = 0
				if (src.salty)
					RG.reagents.add_reagent("sodiumchloride", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.04)
					sumex += min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.04
				RG.reagents.add_reagent("water", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)-sumex)
				user.visible_message("<span class='notice'>[user] fills \the [RG] with water.</span>","<span class='notice'>You fill \the [RG] with water.</span>")
				playsound(user, 'sound/effects/watersplash.ogg', 100, TRUE)
				user.setClickCooldown(5)
				return TRUE //prevent afterattack 
			else
				return TRUE //prevent afterattack 
	else if (istype(C, /obj/item/clothing) && !busy)
		var/obj/item/clothing/CL = C
		to_chat(usr, SPAN_NOTICE("You start washing \the [C]."))
		var/turf/location = user.loc

		busy = TRUE
		sleep(40)
		busy = FALSE

		if (user.loc != location) return				//User has moved
		if (!C) return 								//Item's been destroyed while washing
		if (user.get_active_hand() != C) return		//Person has switched hands or the item in their hands

		CL.hand_wash(user)
		user.visible_message( \
			"<span class='notice'>[user] washes \a [C] using \the [src].</span>", \
			"<span class='notice'>You wash \a [C] using \the [src].</span>")
	else
		..()

/turf/floor/trench/proc/check_filling()
	if (trench_cut > 0)
		trench_cut--
	else
		trench_filling++
		if (trench_filling >= 2)
			ChangeTurf(get_base_turf_by_area(src))
			return
	if (flooded && trench_bed_level() > canal_level(src))
		trench_change_water(/turf/floor/trench, null)

/decl/flooring/trench
	name = "trench"
	desc = "A knee-high trench."
	icon = 'icons/turf/trench.dmi'
	icon_base = "trench"
	flags = TURF_HAS_EDGES | SMOOTH_ONLY_WITH_ITSELF

/decl/flooring/trench/flooded
	name = "flooded trench"
	desc = "A knee-high trench, flooded with water."
	icon = 'icons/turf/trench.dmi'
	icon_base = "trench_flooded"
	flags = TURF_HAS_EDGES | SMOOTH_ONLY_WITH_ITSELF


/turf/floor/dirt
	map_storage_saved_vars = "icon_state;name;trench_stage"
	var/trench_stage = 0
	available_dirt = 2
// Ground level a climbing mob stands at on this turf: a bare trench is 1, and
// open ground, a bridge or a frame over a trench is 0. Smooth movement leaves a
// step between levels to the tile path, since the climb waits in Enter/Exit.
/turf/proc/trench_climb_level()
	return 0

/turf/floor/trench/trench_climb_level()
	if (locate(/obj/covers/repairedfloor) in contents)
		return 0
	if (locate(/obj/structure/vehicleparts/frame) in contents)
		return 0
	return 1

// A climb settles the mob squarely on its tile before moving it. Moving by loc
// keeps any smooth-movement offset, and a body still straddling the edge is
// refused by the next tile's Enter, so it would never leave the trench.
/proc/trench_climb_align(mob/living/L)
	if (!L.step_x && !L.step_y)
		return
	L.step_x = 0
	L.step_y = 0
	if (ishuman(L))
		var/mob/living/human/H = L
		H.human_subtile_offset_owned = FALSE

/proc/trench_climb_place(mob/living/L, atom/destination)
	trench_climb_align(L)
	. = L.forceMove(destination)

// A free-movement climb lands at an offset on its tile, keeping the body's
// sideways position (human_subtile_trench_climb picks a spot that fits).
/proc/trench_climb_place_offset(mob/living/human/H, turf/destination, sx, sy)
	// A body whose centre is already past the edge is filed under destination.
	if (H.loc != destination && !H.forceMove(destination))
		return FALSE
	H.step_x = sx
	H.step_y = sy
	H.human_subtile_anchor()
	H.human_subtile_offset_owned = !!(H.step_x || H.step_y)
	return TRUE

/turf/floor/trench/Enter(atom/movable/O, atom/oldloc)
	if(locate(/obj/structure/vehicleparts/frame) in contents)
		return ..()
	if(locate(/obj/structure/vehicleparts/frame/ship) in contents)
		return ..()
	for (var/obj/OB in src)
		if (OB.density == 1 && !(istype(OB, /obj/structure/window/barrier)))
			return 0
	if (isliving(O) && !ishuman(O))
		return ..()
	// No climb between tiles at the same level (along a trench, or between
	// ground and a bridge), so a smooth step crosses without snapping.
	if (isliving(O) && isturf(oldloc))
		var/turf/from_turf = oldloc
		if (from_turf.trench_climb_level() == trench_climb_level())
			return ..()
	if(isliving(O))
		var/mob/living/L = O
		if (L.mob_size <= MOB_SMALL)
			trench_climb_place(L, src)
			return 1
		if(!istype(oldloc, /turf/floor/trench))
			if(locate(/obj/covers/repairedfloor) in contents)
				trench_climb_place(L, src)
				return 1
			if(L.grabbed_by && L.grabbed_by.len)
				var/mob/living/L2 = L.grabbed_by[1].assailant
				visible_message("<span class = 'notice'>[L2] starts pulling [L] out of trench.</span>")
				if(!do_after(L2, 20, oldloc))
					return FALSE
				if(..())
					visible_message("<span class = 'notice'>[L2] pulls [L] out of trench.</span>")
					trench_climb_place(L, src)
					return TRUE
				return FALSE
			if(world.time > message_cooldown + 30)
				visible_message("<span class = 'notice'>[L] starts to enter a trench.</span>")
				message_cooldown = world.time
			if (!do_after(L, 5, src, needhand = FALSE))
				return FALSE
			if(..())
				visible_message("<span class = 'notice'>[L] enters a trench.</span>")
				trench_climb_place(L, src)
				if (L.pulling && !isliving(L.pulling))
					L.pulling.forceMove(src)
				return 1
		if(istype(oldloc, /turf/floor/trench) && locate(/obj/covers/repairedfloor, usr.loc))
			if(!locate(/obj/covers/repairedfloor) in contents)
				if(world.time > message_cooldown + 30)
					visible_message("<span class = 'notice'>[L] starts to climb down from a bridge.</span>")
					message_cooldown = world.time
				if (!do_after(L, 5, src, needhand = FALSE))
					return FALSE
				if(..())
					visible_message("<span class = 'notice'>[L] climbs down from a bridge.</span>")
					trench_climb_place(L, src)
					return TRUE
		if(istype(oldloc, /turf/floor/trench) && locate(/obj/structure/vehicleparts/frame, usr.loc))
			if(!locate(/obj/structure/vehicleparts/frame) in contents)
				if(world.time > message_cooldown + 30)
					visible_message("<span class = 'notice'>[L] starts to climb down.</span>")
					message_cooldown = world.time
				if (!do_after(L, 5, src, needhand = FALSE))
					return FALSE
				if(..())
					visible_message("<span class = 'notice'>[L] climbs down.</span>")
					trench_climb_place(L, src)
					return TRUE

	return ..()

/turf/floor/trench/Exit(atom/movable/O, atom/newloc)
	if(locate(/obj/structure/vehicleparts/frame/ship) in newloc.contents)
		return ..()
	if (isliving(O) && !ishuman(O))
		return ..()
	if (isliving(O) && isturf(newloc))
		var/turf/next_turf = newloc
		if (next_turf.trench_climb_level() == trench_climb_level())
			return ..()
	if(isliving(O))
		var/mob/living/L = O
		if (L.mob_size <= MOB_SMALL)
			trench_climb_align(L)
			var/turf/T = newloc
			if(T.Enter(O, src))
				trench_climb_place(L, newloc)
			return TRUE
		if(!istype(newloc, /turf/floor/trench))
			if(locate(/obj/covers/repairedfloor) in contents)
				trench_climb_align(L)
				var/turf/T = newloc
				if(T.Enter(O, src))
					trench_climb_place(L, newloc)
				return TRUE
			if(locate(/obj/structure/vehicleparts/frame) in contents)
				trench_climb_align(L)
				var/turf/T = newloc
				if(T.Enter(O, src))
					trench_climb_place(L, newloc)
				return TRUE
			if(L.grabbed_by && L.grabbed_by.len)
				var/mob/living/L2 = L.grabbed_by[1].assailant
				visible_message("<span class = 'notice'>[L2] starts pulling [L] out of trench.</span>")
				if(!do_after(L2, 35, src))
					return FALSE
				if(..())
					visible_message("<span class = 'notice'>[L2] pulls [L] out of trench.</span>")
					trench_climb_place(L, newloc)
					return TRUE
				return FALSE
			var/atom/newlocation = get_step(L,L.dir)
			if (newlocation.density)
				return FALSE
			for (var/atom/A in newlocation)
				// With smooth movement the climber already overlaps that tile.
				if (A.density && A != L)
					return FALSE
			if(world.time > message_cooldown + 30)
				visible_message("<span class = 'notice'>[L] starts to exit a trench.</span>")
				message_cooldown = world.time
			if (!do_after(L, 20, src, needhand = FALSE))
				return FALSE
			if(..())
				visible_message("<span class = 'notice'>[L] exits a trench.</span>")
				trench_climb_align(L)
				var/turf/T = newloc
				if(T.Enter(O, src))
					trench_climb_place(L, newloc)
					if (L.pulling && !isliving(L.pulling))
						L.pulling.forceMove(newloc)
				return TRUE
		if(istype(newloc, /turf/floor/trench) && locate(/obj/covers/repairedfloor, newloc) && !locate(/obj/covers/repairedfloor, usr.loc))
			if(world.time > message_cooldown + 30)
				visible_message("<span class = 'notice'>[L] starts to climb on a bridge.</span>")
				message_cooldown = world.time
			if (!do_after(L, 20, src, needhand = FALSE))
				return FALSE
			if(..())
				visible_message("<span class = 'notice'>[L] climbs on a bridge.</span>")
				trench_climb_align(L)
				var/turf/T = newloc
				if(T.Enter(O, src))
					trench_climb_place(L, newloc)
				return TRUE
		if(istype(newloc, /turf/floor/trench) && locate(/obj/structure/vehicleparts/frame, newloc) && !locate(/obj/structure/vehicleparts/frame, usr.loc))
			for(var/obj/structure/vehicleparts/frame/F in newloc)
				if(F.CanPass(L) == 0)
					return FALSE
			if(world.time > message_cooldown + 30)
				visible_message("<span class = 'notice'>[L] starts to climb on a frame.</span>")
				message_cooldown = world.time
			if (!do_after(L, 20, src, needhand = FALSE))
				return FALSE
			if(..())
				trench_climb_align(L)
				var/turf/T = newloc
				if(T.Enter(O, src))
					visible_message("<span class = 'notice'>[L] climbs on a frame.</span>")
					trench_climb_place(L, newloc)
				return TRUE
	return ..()

/turf/floor/beach/sand
	map_storage_saved_vars = "icon_state;name;trench_stage"
	var/trench_stage = 0
/turf/floor/beach/sand/attackby(obj/item/C as obj, mob/user as mob)
	if (is_tool(C, TOOL_SHOVEL) && user.a_intent == I_HARM)
		var/mob/living/human/HU = user
		if (map && !research_node_known(HU, "field_defenses"))
			to_chat(user, SPAN_WARNING("Your people haven't researched Field Defenses yet."))
			return
		visible_message("<span class = 'notice'>[user] starts to dig a trench.</span>")
		if (!do_after(user, work_delay(user, 30, WORK_DIG, C), src))
			return
		if (istype(src, /turf/floor/beach/sand))
			trench_stage++
			switch(trench_stage)
				if(1)
					//icon_state = ""
					visible_message("<span class = 'notice'>[user] digs.</span>")
					to_chat(user, ("<span class = 'notice'>You need to dig this tile one more time to make a trench.</span>"))
					return
				if(2)
					visible_message("<span class = 'notice'>[user] makes a trench.</span>")
					var/previous_turf_type = src.type
					ChangeTurf(/turf/floor/trench)
					previous_turf = previous_turf_type
		return
	..()

/turf/floor/dirt/attackby(obj/item/C as obj, mob/user as mob)
	if (is_tool(C, TOOL_SHOVEL) && user.a_intent == I_HARM)
		var/mob/living/human/HU = user
		if (map && !research_node_known(HU, "field_defenses"))
			to_chat(user, SPAN_WARNING("Your people haven't researched Field Defenses yet."))
			return
		visible_message("<span class = 'notice'>[user] starts to dig a trench.</span>")
		if (!do_after(user, work_delay(user, 15, WORK_DIG, C), src))
			return
		if (istype(src,/turf/floor/dirt))
			trench_stage++
			switch(trench_stage)
				if(1)
					//icon_state = ""
					visible_message("<span class = 'notice'>[user] digs.</span>")
					to_chat(user, ("<span class = 'notice'>You need to dig this tile one more time to make a trench.</span>"))
					return
				if(2)
					visible_message("<span class = 'notice'>[user] makes a trench.</span>")
					var/previous_turf_type = src.type
					ChangeTurf(/turf/floor/trench)
					previous_turf = previous_turf_type
		return
	..()


/turf/floor/grass/attackby(obj/item/C as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (is_tool(C, TOOL_SHOVEL) && weather_snow > 0 && user.a_intent != I_HARM)
		return ..() // Shovel generated snow into piles first; harm intent still removes the grass layer.
	if (is_tool(C, TOOL_SHOVEL))
		user.visible_message(SPAN_NOTICE("[user] starts to remove the grass layer."), SPAN_NOTICE("[user] starts to remove the grass layer."), "You hear something being uprooted.")
		if (!do_after(user, work_delay(H, 58, WORK_DIG, C)))
			return
		if (weather_snow > 0 && user.a_intent != I_HARM)
			return // Snow fell during the wait; the next click shovels it.
		user.visible_message(SPAN_NOTICE("[user] removes the grass layer."), SPAN_NOTICE("[user] removes the grass layer."), "You hear something being removed.")
		H.adaptStat("strength", 1)
		var/area/A = get_area(src)
		if (A.climate == "jungle" || A.climate == "savanna")
			ChangeTurf(/turf/floor/dirt/jungledirt)
		else
			ChangeTurf(/turf/floor/dirt)
		return
	..()

/turf/floor/winter/attackby(obj/item/C as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (is_tool(C, TOOL_SHOVEL))
		user.visible_message(SPAN_NOTICE("[user] starts to remove the snow layer."), SPAN_NOTICE("[user] starts to remove the snow layer."), "You hear something digging into the ground.")
		if (!do_after(user, work_delay(H, 58, WORK_DIG, C)))
			return
		user.visible_message(SPAN_NOTICE("[user] removes the snow layer."), SPAN_NOTICE("[user] removes the snow layer."), "You hear something being removed.")
		H.adaptStat("strength", 1)
		ChangeTurf(/turf/floor/dirt)
		return
	..()

/turf/floor/trench/flooded/attack_hand(var/mob/living/human/H)
	if (!ishuman(H))
		return
	if (H.a_intent == I_GRAB)
		if (salty)
			to_chat(H, SPAN_WARNING("It's probably not a good idea to drink saltwater."))
			return
		H.visible_message("[H] starts drinking some water from \the [src]...", "You start drinking some water from \the [src]...")
		if (do_after(H,50,src))
			var/watertype = "water"
			if (radiation>0)
				watertype = "irradiated_water"
			if (watertype == "irradiated_water")
				H.rad_act(5)
			else
				H.catch_dirty_water_illness(25)
			if (H.water < 0)
				H.water += rand(40,50)
			H.water += 75
			H.bladder += 75
			H.visible_message("[H] drinks some water from \the [src].", "You drink some water from \the [src].", "You hear something being drank.")
			playsound(H.loc, "drink", rand(10, 50), TRUE)
			return
		else
			return
	else
		..()
//////////////////////////////////////////////////////////////////////////
//AGRICULTURE - IRRIGATION////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

/turf/floor
	var/irrigation = FALSE
	var/flooded = FALSE
	var/salty = FALSE
	var/image/irrigation_overlay = null
	// Entry-local metadata: emitted only for active channels, not every floor.
	var/irrigation_save_version = 1

/turf/floor/get_saved_vars()
	. = ..()
	if (irrigation)
		irrigation_validate_state()
		. |= list("irrigation_save_version", "irrigation", "flooded", "salty")

/turf/floor/persistence_runtime_var(key)
	return key == "irrigation_overlay" || ..()

/turf/floor/proc/irrigation_validate_state()
	if (irrigation_save_version != 1 || !isnum(irrigation) || irrigation != TRUE || !isnum(flooded) || (flooded != FALSE && flooded != TRUE) || !isnum(salty) || (salty != FALSE && salty != TRUE) || (salty && !flooded))
		throw EXCEPTION("Invalid active irrigation state")

// ChangeTurf can reuse the same turf. Reset before payload fields decode, without
// propagating into partially loaded neighbors or drying native source subtypes.
/turf/floor/proc/irrigation_prepare_load()
	if (irrigation_overlay)
		overlays -= irrigation_overlay
	irrigation_overlay = null
	irrigation = initial(irrigation)
	flooded = initial(flooded)
	salty = initial(salty)
	irrigation_save_version = initial(irrigation_save_version)

/turf/after_load()
	..()
	if (istype(src, /turf/floor))
		var/turf/floor/F = src
		F.irrigation_after_load()

/turf/floor/proc/irrigation_after_load()
	if (irrigation)
		irrigation_validate_state()
		irrigation_restore_overlay()

// All same-level turf fields have decoded before after_load. Restore the saved
// wetness/salinity exactly; a load is not a new water-source/propagation event.
/turf/floor/proc/irrigation_restore_overlay()
	var/junction = 0
	for (var/checkdir in cardinal)
		var/turf/floor/T = get_step(src, checkdir)
		if (istype(T, /turf/floor) && T.irrigation)
			junction |= get_dir(src, T)
	var/suffix = flooded ? "_flooded" : ""
	if (irrigation_overlay)
		overlays -= irrigation_overlay
	irrigation_overlay = image(icon = 'icons/turf/trench.dmi', icon_state = "irrigation[junction][suffix]", layer = src.layer + 0.01)
	overlays += irrigation_overlay

// Read scalar envelopes only. This does not call the graph decoder or create
// objects/lists from references during preflight. Legacy strings stay strings.
/proc/irrigation_saved_scalar(savefile/F, field, version)
	var/value = F[field]
	if (version == 2)
		if (!islist(value))
			throw EXCEPTION("Invalid irrigation scalar envelope")
		var/list/scalar = value
		if (scalar.len != 2 || scalar["kind"] != "value" || !("value" in scalar))
			throw EXCEPTION("Invalid irrigation scalar envelope")
		return scalar["value"]
	// Format 3 fields are envelopes, or raw scalars under value format 2.
	value = persistence_saved_scalar(value)
	if (islist(value))
		throw EXCEPTION("Invalid irrigation scalar envelope")
	return value

/proc/validate_saved_irrigation(savefile/F, version)
	var/list/fields = F.dir
	if (!fields.Find("irrigation_save_version"))
		// Old ordinary floors never reliably saved channel flags. Do not guess
		// freshwater or salinity from a name, artwork or the live destination.
		if (fields.Find("irrigation") || fields.Find("irrigation_overlay"))
			throw EXCEPTION("Unversioned irrigation entry requires explicit review")
		// Only legacy version-2 files can hold a named channel without flags; a
		// filled-in channel in a current save keeps its name and is not one.
		if (version == 2 && fields.Find("name"))
			var/saved_name = irrigation_saved_scalar(F, "name", version)
			if (list("irrigation channel", "flooded irrigation channel", "flooded saltwater irrigation channel").Find(saved_name))
				throw EXCEPTION("Legacy named irrigation channel has no durable state")
		return TRUE
	var/schema = irrigation_saved_scalar(F, "irrigation_save_version", version)
	if (!isnum(schema) || schema != 1)
		throw EXCEPTION("Unsupported irrigation entry version")
	for (var/field in list("irrigation", "flooded", "salty"))
		if (!fields.Find(field))
			throw EXCEPTION("Incomplete irrigation entry")
		var/value = irrigation_saved_scalar(F, field, version)
		if (!isnum(value) || (value != FALSE && value != TRUE))
			throw EXCEPTION("Invalid irrigation Boolean")
	var/active = irrigation_saved_scalar(F, "irrigation", version)
	var/wet = irrigation_saved_scalar(F, "flooded", version)
	var/salt = irrigation_saved_scalar(F, "salty", version)
	if (active != TRUE || (salt && !wet))
		throw EXCEPTION("Contradictory irrigation entry")
	return TRUE

/turf/floor/update_icon()
	..()
	if (irrigation && irrigation_overlay)
		overlays.Cut()
		overlays += irrigation_overlay

/turf/floor/attackby(obj/item/C as obj, mob/user as mob)
	var/snow_tool = is_tool(C, TOOL_SHOVEL) || istype(C, /obj/item/weapon/material/kitchen/utensil/spoon)
	if (irrigation && irrigation_overlay && !(snow_tool && weather_snow > 0))
		if (istype (C, /obj/item/weapon/barrier) && !istype(C, /obj/item/weapon/barrier/sandbag))
			var/choice = WWinput(user, "Do you want to fill up the irrigation channel with \the [C]?","Irrigation Channel","Yes",list("Yes","No"))
			if (choice == "Yes")
				to_chat(user, SPAN_NOTICE("You shove some dirt into the irrigation channel."))
				irrigation = 0
				irrigation_overlay = null
				name = initial(name)
				update_icon()
				qdel(C)
				return
		else if (istype(C, /obj/item/weapon/reagent_containers/glass) || istype(C, /obj/item/weapon/reagent_containers/food/drinks))
			if (flooded)
				var/obj/item/weapon/reagent_containers/RG = C
				if (istype(RG) && RG.is_open_container())
					if (do_after(user, 15, src, check_for_repeats = FALSE))
						var/sumex = 0
						if (salty)
							RG.reagents.add_reagent("sodiumchloride", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.04)
							sumex += min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.04
						RG.reagents.add_reagent("water", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)-sumex)
						user.visible_message("<span class='notice'>[user] fills \the [RG] with water.</span>", "<span class='notice'>You fill \the [RG] with water.</span>")
						playsound(user, 'sound/effects/watersplash.ogg', 100, TRUE)
						user.setClickCooldown(5)
						return TRUE
					else
						return TRUE
	else
		..()

/turf/floor/attack_hand(var/mob/living/human/H)
	..()
	if (irrigation && irrigation_overlay)
		if (!ishuman(H))
			return
		if (H.a_intent == I_GRAB)
			if (salty)
				to_chat(H, "<span class='warning'>It's probably not a good idea to drink saltwater.</span>")
				return
			to_chat(H, "You start drinking some water from \the [src]...")
			if (do_after(H,50,src))
				var/watertype = "water"
				if (radiation>0)
					watertype = "irradiated_water"
				if (watertype == "irradiated_water")
					H.rad_act(5)
				else
					H.catch_dirty_water_illness(25)
				if (H.water < 0)
					H.water += rand(40,50)
				H.water += 75
				H.bladder += 75
				to_chat(H, "You drink some water.")
				playsound(H.loc, "drink", rand(10, 50), TRUE)
				return
			else
				return

/turf/floor/proc/irrigate(var/irrigation_type = "empty")
	switch(irrigation_type)
		if ("empty")
			name = "irrigation channel"
			flooded = FALSE
			irrigation = TRUE
			salty = FALSE
			irrigation_overlay = image(icon = 'icons/turf/trench.dmi', icon_state = "irrigation0", layer = src.layer + 0.01)
			check_relatives(1,1,irrigation_type)
		if ("fresh")
			name = "flooded irrigation channel"
			flooded = TRUE
			irrigation = TRUE
			salty = FALSE
			irrigation_overlay = image(icon = 'icons/turf/trench.dmi', icon_state = "irrigation0_flooded", layer = src.layer + 0.01)
			check_relatives(1,1,irrigation_type)
		if ("salty")
			name = "flooded saltwater irrigation channel"
			salty = TRUE
			flooded = TRUE
			irrigation = TRUE
			irrigation_overlay = image(icon = 'icons/turf/trench.dmi', icon_state = "irrigation0_flooded", layer = src.layer + 0.01)
			check_relatives(1,1,irrigation_type)

/turf/floor/check_relatives(var/update_self = FALSE, var/update_others = FALSE, watertype = "empty", var/propagate = TRUE)
	if (!irrigation)
		return
	var/junction
	if (update_self)
		junction = FALSE
	for (var/checkdir in cardinal)
		var/turf/floor/T = get_step(src, checkdir)
		if (!istype(T, /turf/floor))
			continue
		// Ordinary floors and filled-in channels are not water sources.
		if ((T.irrigation && T.flooded) || istype(T, /turf/floor/beach/water) || (istype(T, /turf/floor/trench/flooded) && T.flooded))
			flooded = TRUE
			if (T.salty)
				salty = TRUE
		if (!T.irrigation)
			continue
		if (flooded)
			T.flooded = TRUE
			if (salty)
				T.salty = TRUE
		if (update_self)
			junction |= get_dir(src,T)
		if (update_others)
			T.check_relatives(1,0,watertype,FALSE)
	if (propagate)
		expand_flood()
	if (!isnull(junction))
		var/tpicon = ""
		if (flooded)
			tpicon = "_flooded"
		irrigation_overlay = image(icon = 'icons/turf/trench.dmi', icon_state = "irrigation[junction][tpicon]", layer = src.layer + 0.01)
	update_icon()

/turf/floor/proc/expand_flood()
	if (!irrigation || !flooded)
		return
	// Visit the connected channel component once, including already-wet channels.
	// These local lists release their turf references when this call returns.
	var/list/channels = list(src)
	var/list/visited = list()
	visited[src] = TRUE
	var/contaminated = salty
	for (var/index = 1, index <= channels.len, index++)
		var/turf/floor/C = channels[index]
		if (C.salty)
			contaminated = TRUE
		for (var/checkdir in cardinal)
			var/turf/floor/T = get_step(C, checkdir)
			if (!istype(T, /turf/floor))
				continue
			if (T.salty && (istype(T, /turf/floor/beach/water) || (istype(T, /turf/floor/trench/flooded) && T.flooded)))
				contaminated = TRUE
			if (!T.irrigation || visited[T])
				continue
			visited[T] = TRUE
			channels += T
	for (var/turf/floor/C in channels)
		C.flooded = TRUE
		if (contaminated)
			C.salty = TRUE
	for (var/turf/floor/C in channels)
		C.check_relatives(1,0,"empty",FALSE)
