// Wall and floor finishes: limewash, limewash tinted with a painting pigment,
// and wood stain on wooden floors. Quicklime slaked in water makes limewash
// (the paint reagent in lime white); a pigment used on the container tints it;
// the container used on a built wall or a floor coats it. A coat fades after
// FINISH_LIFE of real time and wants a fresh one: a faded wall no longer counts
// as finished for home comfort (home_comfort.dm). See docs/home-finishes.md.

#define FINISH_LIME "#efe9da"            // warm off-white of slaked lime
#define FINISH_COAT 5                    // units of paint per wall or floor tile
#define FINISH_SLAKE 20                  // water slaked by one lump of quicklime
#define FINISH_LIFE (14 * 24 * 36000)    // a coat lasts two weeks of real time
#define FINISH_TIME 30                   // deciseconds to coat one tile

/obj/covers
	var/finish_color = null   // "#rrggbb" of the coat, or null when bare
	var/finish_applied = 0    // world.realtime the coat went on

/obj/covers/proc/finish_faded()
	return finish_color && world.realtime - finish_applied > FINISH_LIFE

/obj/covers/home_finished()
	return finish_color && !finish_faded()

// Which covers take a coat: every built wall, and laid floors that are not
// roads, bridges, carpets, thatch or mats.
/obj/covers/proc/finish_accepts()
	if (wall)
		return TRUE
	if (!is_floor_cover())
		return FALSE
	if (istype(src, /obj/covers/roads) || istype(src, /obj/covers/road) || istype(src, /obj/covers/romanroad) || istype(src, /obj/covers/bridge) || istype(src, /obj/covers/carpet) || istype(src, /obj/covers/thatch) || istype(src, /obj/covers/tatami) || istype(src, /obj/covers/tatami_vertical) || istype(src, /obj/covers/tatami_dark) || istype(src, /obj/covers/tatami_dark_vertical))
		return FALSE
	return TRUE

/obj/covers/proc/finish_name()
	if (!finish_color)
		return null
	if (finish_color == FINISH_LIME)
		return (wood && !wall) ? "limed" : "limewashed"
	return (wood && !wall) ? "stained" : "painted"

/obj/covers/examine(mob/user)
	..()
	if (finish_color)
		if (finish_faded())
			to_chat(user, "<span class='notice'>Its [finish_name()] coat has faded and wants a fresh one.</span>")
		else
			to_chat(user, "<span class='notice'>It is [finish_name()].</span>")

// The colour of the paint in a container, or null if it holds too little.
/proc/finish_container_color(obj/item/weapon/reagent_containers/C, amount = FINISH_COAT)
	if (!C || !C.reagents || !C.reagents.has_reagent("paint", amount))
		return null
	for (var/datum/reagent/paint/P in C.reagents.reagent_list)
		return P.color || FINISH_LIME
	return null

/obj/covers/proc/try_finish(obj/item/weapon/reagent_containers/C, mob/user)
	if (!finish_accepts())
		return FALSE
	var/colour = finish_container_color(C)
	if (!colour)
		return FALSE
	if (!C.is_open_container())
		to_chat(user, "<span class='warning'>Open \the [C] first.</span>")
		return TRUE
	user.visible_message("[user] starts coating \the [src].", "You start coating \the [src].")
	if (!do_after(user, FINISH_TIME, src))
		return TRUE
	colour = finish_container_color(C)
	if (!colour)
		return TRUE
	C.reagents.remove_reagent("paint", FINISH_COAT)
	finish_color = colour
	finish_applied = world.realtime
	update_icon()
	to_chat(user, "<span class='notice'>\The [src] is [finish_name()].</span>")
	return TRUE

/obj/covers/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers) && try_finish(W, user))
		return TRUE
	return ..()

/obj/covers/after_load()
	..()
	if (finish_color)
		update_icon()

// Quicklime slaked in water makes limewash.
/obj/item/stack/ore/quicklime/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !istype(target, /obj/item/weapon/reagent_containers))
		return ..()
	var/obj/item/weapon/reagent_containers/C = target
	if (!C.reagents || !C.is_open_container() || !C.reagents.has_reagent("water", FINISH_SLAKE))
		to_chat(user, "<span class='warning'>Slake the quicklime in an open container holding at least [FINISH_SLAKE] units of water.</span>")
		return TRUE
	C.reagents.remove_reagent("water", FINISH_SLAKE)
	C.reagents.add_reagent("paint", FINISH_SLAKE, FINISH_LIME)
	use(1)
	to_chat(user, "<span class='notice'>The quicklime hisses and slakes into limewash.</span>")
	return TRUE

// A pigment stirred into limewash tints all of it.
/obj/item/pigment/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !istype(target, /obj/item/weapon/reagent_containers) || !finish_container_color(target, 1))
		return ..()
	if (pigment_uses <= 0 || !pigment_colors.len)
		to_chat(user, "<span class='warning'>\The [src] is used up.</span>")
		return TRUE
	var/colour = pigment_colors[1]
	if (pigment_colors.len > 1)
		colour = WWinput(user, "Which colour do you stir in?", "Tint", pigment_colors[1], pigment_colors)
		if (!colour || loc != user || !finish_container_color(target, 1))
			return TRUE
	var/obj/item/weapon/reagent_containers/C = target
	for (var/datum/reagent/paint/P in C.reagents.reagent_list)
		P.color = colour
	pigment_uses--
	to_chat(user, "<span class='notice'>You stir \the [src] into \the [C].</span>")
	return TRUE


/obj/covers/proc/finish_overlay(finish_color, faded)
	if (!icon || !icon_state)
		return null
	if (!finish_color)
		finish_color = FINISH_LIME
	// wood floors take a stain (thin, darker, all grain); everything else a wash
	var/stain = (wood && !wall) ? TRUE : FALSE

	var/static/list/matrix_cache = list()
	var/key = "[finish_color]-[faded ? 1 : 0]-[stain]"
	var/list/M = matrix_cache[key]
	if (!M)
		var/list/C = rgb2num(finish_color)
		var/list/L = rgb2num(FINISH_LIME)
		var/cr = C[1] / 255
		var/cg = C[2] / 255
		var/cb = C[3] / 255
		var/strength	// how much of the original colour is replaced
		var/body		// flat coat colour, independent of the texture (opacity of the paint)
		var/gain		// how strongly the original luminance modulates the coat (texture)
		if (stain)
			strength = 0.62
			body = 0
			gain = 2.3
		else
			// pigment is carried in lime: pull every colour 22% toward lime white
			cr = cr * 0.78 + (L[1] / 255) * 0.22
			cg = cg * 0.78 + (L[2] / 255) * 0.22
			cb = cb * 0.78 + (L[3] / 255) * 0.22
			strength = 0.84
			body = 0.40
			gain = 0.80
		if (faded)
			strength *= 0.72
		// out = (1 - strength) * original + strength * coat * (body + gain * luminance)
		var/keep = 1 - strength
		var/lr = strength * gain * 0.299
		var/lg = strength * gain * 0.587
		var/lb = strength * gain * 0.114
		var/k = strength * body
		M = list(
			lr * cr + keep, lr * cg, lr * cb, 0,
			lg * cr, lg * cg + keep, lg * cb, 0,
			lb * cr, lb * cg, lb * cb + keep, 0,
			0, 0, 0, 1,
			k * cr, k * cg, k * cb, 0)
		matrix_cache[key] = M

	// below cracks (+0.01), bullet holes (+0.01) and mold (+0.02)
	var/image/I = image(icon = icon, icon_state = icon_state, dir = dir, layer = layer + 0.005)
	I.color = M

	if (faded)
		// Wear, from existing states used as alpha masks (their rgb is discarded
		// and replaced by a dark bare-wall tone). FLOAT_LAYER keeps them directly
		// on top of the coat and under the weathering overlays.
		// 1. faint streaky grain over the whole tile so the thin coat looks uneven
		var/image/grain = image(icon = 'icons/effects/effects.dmi', icon_state = "dirt", layer = FLOAT_LAYER)
		grain.color = list(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0.9, 0.11,0.095,0.08,-0.07)
		I.overlays += grain
		// 2. two soft worn-through patches, placed by one of four layouts picked
		//    from the position so neighbouring tiles do not repeat. All layouts
		//    stay inside the 32x32 tile.
		var/static/list/worn_color = list(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0.42, 0.11,0.095,0.08,0)
		// per layout: big patch (turn, x, y) then small patch (turn, x, y)
		var/static/list/layouts = list(
			list(0, -4, -4, 90, 8, 7),
			list(90, 4, -3, 180, -8, -8),
			list(180, 3, 4, 270, -7, 8),
			list(270, -3, 3, 0, 8, -7))
		var/list/P = layouts[((x + y * 2) % 4) + 1]
		for (var/i in 0 to 1)
			var/image/worn = image(icon = 'icons/turf/flooring/decals.dmi', icon_state = "asteroid_dug_overlay", layer = FLOAT_LAYER)
			worn.color = worn_color
			var/matrix/T = matrix()
			T.Scale(i ? 0.5 : 0.85)
			T.Turn(P[i * 3 + 1])
			T.Translate(P[i * 3 + 2], P[i * 3 + 3])
			worn.transform = T
			I.overlays += worn
	return I

#undef FINISH_LIME
#undef FINISH_COAT
#undef FINISH_SLAKE
#undef FINISH_LIFE
#undef FINISH_TIME
