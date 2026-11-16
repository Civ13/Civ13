// Log walls are raised in steps (Val, 2026-11-16). The crafting menu lays
// only the sill log; logs added by hand stack the courses and the top plate,
// an axe notches and fits the corners, and clay, hay or straw chinks the gaps.
// At 4 logs a tile a 20'x24' cabin (6x7 tiles) comes to about 88 logs with
// its roof supports. Until it is chinked a log wall lets warmth out
// (building_insulation.dm); a finished wall can be carved in Nordic or Aztec
// style with a chisel.

#define LOG_WALL_LOGS 4 // sill, two courses, top plate
#define LOG_WALL_STEP_TIME 50
#define LOG_WALL_CHINK_CLAY 1
#define LOG_WALL_CHINK_FIBRE 2 // hay or straw
#define LOG_WALL_UNFITTED_HEALTH 350 // full height, corners not yet notched
#define LOG_WALL_NOTCH_BONUS 100

// Health of a half-built wall by the logs laid so far.
/proc/log_wall_stage_health(stage)
	switch (stage)
		if (1)
			return 60
		if (2)
			return 150
	return 250

/proc/log_wall_step_time(mob/living/human/H)
	var/coeff = istype(H) ? H.getStatCoeff("strength") : 1
	return LOG_WALL_STEP_TIME / max(0.5, coeff)

/obj/covers/wood_wall/log_build
	name = "log wall sill"
	desc = "The bottom log of a log wall. Add logs to raise it."
	icon = 'icons/obj/log_wall_build.dmi' // drawn by tests/sprites/create_log_wall_build.py
	icon_state = "sill"
	passable = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	health = 60
	adjusts = FALSE
	var/stage = 1 // logs laid
	var/tmp/log_wall_busy = FALSE
	var/finished_type = /obj/covers/wood_wall/log
	var/state_suffix = "" // "_corner" for the corner states

/obj/covers/wood_wall/log_build/corner
	name = "log wall corner sill"
	icon_state = "sill_corner"
	finished_type = /obj/covers/wood_wall/log/corner
	state_suffix = "_corner"

/obj/covers/wood_wall/log_build/New()
	..()
	update_stage()

// One sprite for each log laid: the sill, two courses, the upper courses.
/obj/covers/wood_wall/log_build/proc/update_stage()
	var/stage_state = "upper"
	switch (stage)
		if (1)
			stage_state = "sill"
		if (2)
			stage_state = "courses"
	icon_state = "[stage_state][state_suffix]"
	opacity = stage >= LOG_WALL_LOGS - 1
	switch (stage)
		if (1)
			name = initial(name)
		if (2)
			name = "waist-high log wall"
		else
			name = "unfinished log wall"
	desc = "A log wall being raised, [stage] of [LOG_WALL_LOGS] logs laid. Add logs to raise it, or take it down with a hammer."

/obj/covers/wood_wall/log_build/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/structure/drone))
		var/obj/structure/drone/D = mover
		if (D.flying)
			return TRUE
	if (istype(mover, /obj/item/projectile) && stage < LOG_WALL_LOGS - 1)
		var/obj/item/projectile/P = mover
		return prob(40 - stage * 10 + P.penetrating * 2)
	return !density

/obj/covers/wood_wall/log_build/proc/log_worker_valid(mob/living/human/H, obj/item/W)
	return !QDELETED(src) && !QDELETED(H) && !QDELETED(W) && W.loc == H && H.Adjacent(src) && !onfire

/obj/covers/wood_wall/log_build/attackby(obj/item/W as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (istype(H) && istype(W, /obj/item/stack/material/wood))
		add_log(W, H)
		return
	if (istype(H) && is_tool(W, TOOL_HAMMER))
		take_down(W, H)
		return
	..()

/obj/covers/wood_wall/log_build/proc/add_log(obj/item/stack/material/wood/L, mob/living/human/H)
	if (log_wall_busy || stage >= LOG_WALL_LOGS)
		return FALSE
	log_wall_busy = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts heaving a log onto \the [src]."), SPAN_NOTICE("You start heaving a log onto \the [src]."))
	var/done = do_after(H, log_wall_step_time(H), src)
	log_wall_busy = FALSE
	if (!done || !log_worker_valid(H, L) || stage >= LOG_WALL_LOGS || !L.use(1))
		return FALSE
	stage++
	playsound(get_turf(src), 'sound/effects/woodfile.ogg', 60, TRUE)
	if (stage >= LOG_WALL_LOGS)
		var/obj/covers/wood_wall/log/W = new finished_type(loc)
		W.dir = dir
		W.notched = FALSE
		W.chinked = FALSE
		W.health = LOG_WALL_UNFITTED_HEALTH
		W.update_icon()
		to_chat(H, SPAN_NOTICE("You lay the top plate. Notch the corners with an axe and chink the gaps with clay, hay or straw to finish it."))
		qdel(src)
		return TRUE
	health = log_wall_stage_health(stage)
	update_stage()
	to_chat(H, SPAN_NOTICE("You lay another course ([stage] of [LOG_WALL_LOGS] logs)."))
	return TRUE

/obj/covers/wood_wall/log_build/proc/take_down(obj/item/W, mob/living/human/H)
	if (log_wall_busy)
		return FALSE
	log_wall_busy = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts taking \the [src] apart."), SPAN_NOTICE("You start taking \the [src] apart."))
	var/done = do_after(H, log_wall_step_time(H), src)
	log_wall_busy = FALSE
	if (!done || !log_worker_valid(H, W))
		return FALSE
	var/turf/T = get_turf(src)
	new /obj/item/stack/material/wood(T, stage)
	to_chat(H, SPAN_NOTICE("You take \the [src] apart and get back [stage] log\s."))
	qdel(src)
	return TRUE

// ---- the finished wall: notching, chinking and carving ----------------------

/obj/covers/wood_wall/log
	var/notched = TRUE // map walls and old saves are finished walls
	var/chinked = TRUE
	var/tmp/log_wall_busy = FALSE
	var/unchinked_state = "unchinked"

/obj/covers/wood_wall/log/corner
	unchinked_state = "unchinked_corner"

// Until it is chinked the wall shows daylight between its logs; a chinked or
// mapped wall keeps its own sprite from walls.dmi.
/obj/covers/wood_wall/log/proc/log_wall_appearance()
	if (chinked)
		icon = initial(icon)
		icon_state = initial(icon_state)
	else
		icon = 'icons/obj/log_wall_build.dmi'
		icon_state = unchinked_state

/obj/covers/wood_wall/log/update_icon()
	log_wall_appearance()
	..()

/obj/covers/wood_wall/log/examine(mob/user)
	..()
	if (!notched)
		to_chat(user, SPAN_NOTICE("Its corners are not notched yet. Use an axe or hatchet on it to fit them."))
	if (!chinked)
		to_chat(user, SPAN_NOTICE("The wind blows through the gaps between the logs. Chink them with [LOG_WALL_CHINK_CLAY] clay, or [LOG_WALL_CHINK_FIBRE] hay or straw."))

/obj/covers/wood_wall/log/proc/chinking_cost(obj/item/W)
	if (istype(W, /obj/item/stack/material/clay))
		return LOG_WALL_CHINK_CLAY
	if (istype(W, /obj/item/stack/hay) || istype(W, /obj/item/stack/material/straw))
		return LOG_WALL_CHINK_FIBRE
	return 0

/obj/covers/wood_wall/log/attackby(obj/item/W as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (istype(H))
		if (!notched && is_tool(W, TOOL_HATCHET))
			notch(W, H)
			return
		if (!chinked && chinking_cost(W))
			chink(W, H)
			return
		if (notched && chinked && is_tool(W, TOOL_CHISEL) && type == /obj/covers/wood_wall/log)
			carve(W, H)
			return
	..()

/obj/covers/wood_wall/log/proc/log_worker_valid(mob/living/human/H, obj/item/W)
	return !QDELETED(src) && !QDELETED(H) && !QDELETED(W) && W.loc == H && H.Adjacent(src) && !onfire

/obj/covers/wood_wall/log/proc/notch(obj/item/W, mob/living/human/H)
	if (log_wall_busy)
		return FALSE
	log_wall_busy = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts notching the logs of \the [src]."), SPAN_NOTICE("You start notching and fitting the logs."))
	var/done = do_after(H, log_wall_step_time(H), src)
	log_wall_busy = FALSE
	if (!done || !log_worker_valid(H, W) || notched)
		return FALSE
	notched = TRUE
	health = min(initial(health), health + LOG_WALL_NOTCH_BONUS)
	playsound(get_turf(src), 'sound/effects/woodfile.ogg', 60, TRUE)
	to_chat(H, SPAN_NOTICE("The logs lock together at the corners."))
	return TRUE

/obj/covers/wood_wall/log/proc/chink(obj/item/stack/S, mob/living/human/H)
	if (log_wall_busy)
		return FALSE
	var/cost = chinking_cost(S)
	if (S.amount < cost)
		to_chat(H, SPAN_WARNING("You need [cost] [S.name] to chink the wall."))
		return FALSE
	log_wall_busy = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts packing the gaps of \the [src]."), SPAN_NOTICE("You start packing the gaps between the logs."))
	var/done = do_after(H, log_wall_step_time(H), src)
	log_wall_busy = FALSE
	if (!done || !log_worker_valid(H, S) || chinked || !S.use(cost))
		return FALSE
	chinked = TRUE
	log_wall_appearance()
	to_chat(H, SPAN_NOTICE("You chink the gaps. The wall will keep the warmth in now."))
	return TRUE

/obj/covers/wood_wall/log/proc/carve(obj/item/W, mob/living/human/H)
	if (log_wall_busy)
		return FALSE
	var/list/styles = list()
	if (crafting_recipe_allowed(H, "/obj/covers/wood_wall/nordic"))
		styles["Nordic"] = /obj/covers/wood_wall/nordic
	if (crafting_recipe_allowed(H, "/obj/covers/wood_wall/aztec"))
		styles["Aztec"] = /obj/covers/wood_wall/aztec
	if (!styles.len)
		to_chat(H, SPAN_WARNING("You don't know any carving style for a log wall yet."))
		return FALSE
	var/choice = WWinput(H, "Which style do you want to carve into the wall?", "Carving", "Cancel", styles + "Cancel")
	if (!(choice in styles))
		return FALSE
	log_wall_busy = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts carving \the [src]."), SPAN_NOTICE("You start carving the logs in [lowertext(choice)] style."))
	var/done = do_after(H, LOG_WALL_STEP_TIME * 2, src)
	log_wall_busy = FALSE
	if (!done || !log_worker_valid(H, W))
		return FALSE
	var/path = styles[choice]
	var/obj/covers/C = new path(loc)
	C.health = min(initial(C.health), health)
	C.insulation_lining = insulation_lining
	insulation_lining = null
	to_chat(H, SPAN_NOTICE("You finish carving the wall."))
	qdel(src)
	return TRUE
