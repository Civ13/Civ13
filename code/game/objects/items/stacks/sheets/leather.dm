// Pocket Stronghold-inspired stages, implemented with Civ13 stacks/chemistry.
// Every piece is one eventual leather sheet: split/merge needs no hidden yield.
/obj/item/stack/material
	var/tmp/preparing_hide = FALSE

/obj/item/stack/material/persistence_runtime_var(key)
	return key == "preparing_hide" || ..()

/mob/proc/hide_worker_connected()
	return client != null || agent_character_for(src)

// Hide work needs Basic Tools; fixtures override this hook.
/mob/proc/hide_research_allowed(warn = FALSE)
	return warn ? crafting_node_allowed_or_warn(src, "basic_tools") : crafting_node_allowed(src, "basic_tools")

/mob/proc/hide_preparation_wait(atom/target)
	return do_after(src, 50, target)

/proc/hide_worker_can_reach(mob/living/user, obj/item/source)
	return istype(user) && !QDELETED(user) && user.hide_worker_connected() && user.stat == CONSCIOUS && !QDELETED(source) && (source.loc == user || isturf(source.loc)) && user.Adjacent(source)

/obj/item/stack/material/proc/hide_preparation_valid(mob/living/user, obj/item/tool, atom/source_loc, turf/site)
	return user.hide_research_allowed() && hide_worker_can_reach(user, src) && loc == source_loc && get_turf(src) == site && amount >= 1 && !QDELETED(tool) && tool.loc == user && user.item_is_in_hands(tool) && tool.sharp && !istype(tool, /obj/item/weapon/reagent_containers) && !istype(tool, /obj/item/weapon/macuahuitl)

/obj/item/stack/material/proc/prepare_hide(mob/living/user, obj/item/tool)
	if (!istype(src, /obj/item/stack/material/pelt) && !istype(src, /obj/item/stack/material/rawhide))
		return FALSE
	if (!user.hide_research_allowed(TRUE))
		return FALSE
	var/atom/source_loc = loc
	var/turf/site = get_turf(src)
	if (preparing_hide || !hide_preparation_valid(user, tool, source_loc, site))
		return FALSE
	preparing_hide = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts scraping [src]."))
	var/completed = user.hide_preparation_wait(src)
	if (QDELETED(src))
		return FALSE
	preparing_hide = FALSE
	if (!completed || !hide_preparation_valid(user, tool, source_loc, site))
		return FALSE
	// Pay once, then construct with the final count. New() may merge the output.
	if (!use(1))
		return FALSE
	new /obj/item/stack/material/hairlesshide(site, 1)
	to_chat(user, SPAN_NOTICE("You scrape a hide clean. Wash it in open water or with a vessel of water next."))
	return TRUE

// Keep scraping piece after piece until the stack is done or the work stops.
// Every piece still pays its own wait; nothing is batched for free.
/obj/item/stack/material/proc/prepare_hide_stack(mob/living/user, obj/item/tool)
	var/done = 0
	while (!QDELETED(src) && amount >= 1 && prepare_hide(user, tool))
		done++
	return done

/obj/item/stack/material/pelt/attackby(obj/item/W, mob/user)
	if (W.sharp)
		prepare_hide_stack(user, W)
		return TRUE
	return ..()

// Pelts and leather share the hide piece unit: about 60 cm square (4 sq ft).
/obj/item/stack/material/pelt/update_strings()
	..()
	desc += " Each piece is about 60 cm square."

/obj/item/stack/material/leather/update_strings()
	..()
	desc += " Each sheet is about 60 cm square, one piece of tanned hide."

/obj/item/stack/material/rawhide
	name = "raw hide"
	icon_state = "sheet-hide"
	default_type = "rawhide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/rawhide/update_strings()
	..()
	desc = "Untanned animal skin; each piece is about 60 cm square. Scrape it with a held sharp tool, wash it, dry it on a tanning rack, then apply tannin."

/obj/item/stack/material/rawhide/attackby(obj/item/W, mob/user)
	if (W.sharp)
		prepare_hide_stack(user, W)
		return TRUE
	return ..()

// Retain this legacy type/material identity for already saved prepared hides.
/obj/item/stack/material/hairlesshide
	name = "hairless hide"
	icon_state = "sheet-hairlesshide"
	default_type = "hairlesshide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/hairlesshide/update_strings()
	..()
	desc = "A scraped hide. Hold the stack and click a river, lake, shallows or puddle to wash every piece in turn, or wash one piece at a time with an open vessel holding 5 water."

/obj/item/stack/material/wethide
	name = "wet hide"
	icon_state = "sheet-hairlesshide"
	color = "#89796D"
	default_type = "wethide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/wethide/update_strings()
	..()
	desc = "A washed wet hide. Put it on a tanning rack to dry; each piece will yield one leather sheet after tanning."

/obj/item/stack/material/dryhide
	name = "dry hide"
	icon_state = "sheet-hairlesshide"
	color = "#C9AA84"
	default_type = "dryhide"
	flammable = TRUE
	value = 0

/obj/item/stack/material/dryhide/update_strings()
	..()
	desc = "A dried hide. Use an open liquid container with 5 bark tannin to tan one piece. For a nearby stationary vessel, hold this hide and click the vessel."

/obj/proc/tanning_liquid_accessible()
	return is_open_container()

// Barrels expose a controlled spout rather than OPENCONTAINER. Never bypass locks.
/obj/structure/reagent_dispensers/tanning_liquid_accessible()
	return !locked

/obj/structure/pot/tanning_liquid_accessible()
	return is_open_container() && !meal_cooking && !meal_portions

/proc/hide_liquid_valid(mob/living/user, obj/item/source, obj/vessel, reagent_id, cost)
	return hide_worker_can_reach(user, source) && !QDELETED(vessel) && vessel.tanning_liquid_accessible() && ((vessel.loc == user && user.item_is_in_hands(vessel)) || (isturf(vessel.loc) && user.Adjacent(vessel) && source.loc == user && user.item_is_in_hands(source))) && vessel.reagents && vessel.reagents.has_reagent(reagent_id, cost)

/obj/item/stack/material/proc/apply_hide_liquid(mob/living/user, obj/vessel, reagent_id, output_type)
	// Explicit paid interactions avoid touch_obj's whole-holder-volume semantics.
	if (!user.hide_research_allowed() || !istype(vessel) || amount < 1 || !hide_liquid_valid(user, src, vessel, reagent_id, 5))
		return FALSE
	var/turf/site = get_turf(src)
	if (!use(1))
		return FALSE
	vessel.reagents.remove_reagent(reagent_id, 5)
	new output_type(site, 1)
	return TRUE

/obj/item/stack/material/hairlesshide/attackby(obj/W, mob/user)
	if (W.reagents)
		if (!user.hide_research_allowed(TRUE))
			return TRUE
		if (!apply_hide_liquid(user, W, "water", /obj/item/stack/material/wethide))
			to_chat(user, SPAN_WARNING("Use an accessible open vessel with at least 5 units of water. Hold the hide when using a vessel on the ground."))
		return TRUE
	return ..()

/obj/item/stack/material/hairlesshide/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (hide_wash_water(A) || istype(A, /turf/floor/beach/water/ice))
		wash_in_water(user, A)
		return TRUE
	if (isobj(A) && A.reagents)
		return attackby(A, user) // Resolve before pot insertion, pouring or splashing.
	return ..()

// ---- Washing in open water ----
// A river, lake, the sea shallows, a flooded trench, an ice hole or a puddle: hold the
// stack and click the water to rinse it piece after piece. Open water is never
// used up; a puddle pays 5 units for each hide, like a vessel would.
#define HIDE_WASH_PUDDLE_COST 5

/proc/hide_wash_water(atom/A)
	if (istype(A, /obj/structure/sink/puddle))
		var/obj/structure/sink/puddle/P = A
		return !P.heat_dried() && P.volume >= HIDE_WASH_PUDDLE_COST
	if (istype(A, /obj/structure/ice_hole))
		var/obj/structure/ice_hole/hole = A
		return hole.open()
	if (istype(A, /turf/floor/beach/water/ice))
		var/obj/structure/ice_hole/hole = locate() in A
		return hole && hole.open()
	return isturf(A) && is_open_water(A)

/mob/proc/hide_wash_wait(atom/water)
	return do_after(src, 30, water)

/obj/item/stack/material/hairlesshide/proc/water_wash_valid(mob/living/user, atom/water)
	return user.hide_research_allowed() && hide_worker_can_reach(user, src) && loc == user && user.item_is_in_hands(src) && amount >= 1 && !QDELETED(water) && user.Adjacent(water) && hide_wash_water(water)

// The washed pieces gather in the free hand, so a river cannot carry them off.
/obj/item/stack/material/hairlesshide/proc/water_wash_output(mob/living/user, turf/site)
	var/obj/item/stack/material/wethide/held = user.get_inactive_hand()
	if (istype(held) && held.amount < held.max_amount)
		held.amount++
		held.update_icon()
		held.update_strings()
		return
	var/obj/item/stack/material/wethide/made = new /obj/item/stack/material/wethide(site, 1)
	if (!QDELETED(made) && made.loc == site && !user.get_inactive_hand())
		user.put_in_inactive_hand(made)

/obj/item/stack/material/hairlesshide/proc/wash_in_water(mob/living/user, atom/water)
	if (!istype(user) || !user.hide_research_allowed(TRUE))
		return 0
	if (istype(water, /turf/floor/beach/water/ice) && !hide_wash_water(water))
		to_chat(user, SPAN_WARNING("The water is frozen. Cut a hole in the ice or find open water."))
		return 0
	if (preparing_hide)
		return 0
	if (!water_wash_valid(user, water))
		to_chat(user, SPAN_WARNING("Hold the hides in your hand and stand beside open water or a puddle with water in it."))
		return 0
	preparing_hide = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts washing [src] in \the [water]."), SPAN_NOTICE("You start washing the hides in \the [water], one at a time."))
	var/done = 0
	// Every piece pays its own wait; nothing is batched for free. An ice
	// hole that freezes over, or a puddle that runs dry, stops the work.
	while (water_wash_valid(user, water))
		if (!user.hide_wash_wait(water) || QDELETED(src) || !water_wash_valid(user, water))
			break
		var/turf/site = get_turf(user)
		if (istype(water, /obj/structure/sink/puddle))
			var/obj/structure/sink/puddle/P = water
			P.volume -= HIDE_WASH_PUDDLE_COST
			P.update_icon()
		if (!use(1))
			break
		water_wash_output(user, site)
		done++
	if (!QDELETED(src))
		preparing_hide = FALSE
	if (done)
		playsound(get_turf(user), 'sound/effects/slosh.ogg', 25, TRUE)
		to_chat(user, SPAN_NOTICE("You wash [done] hide[done == 1 ? "" : "s"]. Dry them on a tanning rack next."))
	return done

#undef HIDE_WASH_PUDDLE_COST

/obj/item/stack/material/dryhide/attackby(obj/W, mob/user)
	if (W.reagents)
		if (!user.hide_research_allowed(TRUE))
			return TRUE
		if (!apply_hide_liquid(user, W, "tannin", /obj/item/stack/material/leather))
			to_chat(user, SPAN_WARNING("Use an accessible open vessel with at least 5 units of tannin. Hold the hide when using a vessel on the ground."))
		return TRUE
	return ..()

/obj/item/stack/material/dryhide/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (isobj(A) && A.reagents)
		return attackby(A, user)
	return ..()

/obj/item/stack/bark
	name = "tree bark"
	desc = "Bark from cutting logs into planks. Use an open liquid container with 10 water to extract 10 tannin from one piece. For a nearby stationary vessel, hold the bark and click the vessel."
	icon = 'icons/obj/bark.dmi'
	icon_state = "bark"
	singular_name = "piece of bark"
	max_amount = 50
	can_stack = TRUE
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/bark/attackby(obj/W, mob/user)
	if (W.reagents)
		var/obj/vessel = W
		if (!user.hide_research_allowed(TRUE))
			return TRUE
		if (amount < 1 || !hide_liquid_valid(user, src, vessel, "water", 10))
			to_chat(user, SPAN_WARNING("Use an accessible open vessel with at least 10 units of water. Hold the bark when using a vessel on the ground."))
			return TRUE
		if (!use(1))
			return TRUE
		// Equal liquid volumes fit even when the vessel started full.
		vessel.reagents.remove_reagent("water", 10)
		vessel.reagents.add_reagent("tannin", 10)
		to_chat(user, SPAN_NOTICE("You soak the bark to extract tannin."))
		return TRUE
	return ..()

/obj/item/stack/bark/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (isobj(A) && A.reagents)
		return attackby(A, user)
	return ..()

/datum/reagent/tannin
	name = "Tannin"
	id = "tannin"
	description = "A bark-derived tanning solution used to turn dried hides into leather."
	reagent_state = LIQUID
	color = "#571D06"
	taste_description = "astringent bark"
