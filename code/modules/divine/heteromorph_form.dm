// ============================================================
// Heteromorph true forms (phase 2 of the Dragonoid plan). Hidden mechanic:
// keep it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// Taking the true form puts the human body, with everything it carries,
// inside a large form mob and moves the player into it. Returning, a forced
// return at low health, or a world save always puts the human back first,
// so the world only ever saves the human. Numbers live in
// config/heteromorph_balance.json (heteromorph_balance_num()).
// Art: icons/mob/heteromorph_dragon.dmi, drawn by Fable 5.2
// (tests/sprites/create_heteromorph_dragon.py).
// ============================================================

/datum/heteromorph
	var/form_type = null // the /mob/living/simple_animal/heteromorph_form subtype

/datum/heteromorph/dragonoid
	form_type = /mob/living/simple_animal/heteromorph_form/dragon

// ---------- balance ----------

var/global/list/heteromorph_balance_cache = null

/proc/heteromorph_balance_num(kind_id, key, fallback)
	if (!islist(heteromorph_balance_cache))
		heteromorph_balance_cache = list()
		if (fexists("config/heteromorph_balance.json"))
			try
				var/list/L = json_decode(file2text("config/heteromorph_balance.json"))
				if (islist(L))
					heteromorph_balance_cache = L
			catch(var/exception/e)
				log_debug("heteromorph_balance.json ignored: [e]")
	var/list/row = heteromorph_balance_cache[kind_id]
	if (!islist(row))
		return fallback
	var/v = row[key]
	return isnum(v) ? v : fallback

// Every form mob now in the world, so a save can put all bodies back.
var/global/list/heteromorph_forms_live = list()

// ---------- the form mob ----------

/mob/living/simple_animal/heteromorph_form
	name = "great beast"
	desc = "Something vast."
	density = TRUE
	mob_size = MOB_HUGE
	wander = FALSE
	starves = FALSE
	has_fat = FALSE
	meat_amount = FALSE
	behaviour = "defends"
	stop_automated_movement_when_pulled = FALSE
	minbodytemp = 0
	maxbodytemp = 2000
	speak_emote = list("rumbles")
	response_help  = "touches"
	response_disarm = "shoves"
	response_harm   = "strikes"
	var/tmp/mob/living/human/heteromorph_body = null // held inside src.contents
	var/tmp/heteromorph_started = 0                   // world.time the form was taken
	var/tmp/heteromorph_leaving = FALSE               // revert in progress

/mob/living/simple_animal/heteromorph_form/New(loc, mob/living/human/H)
	..()
	heteromorph_forms_live += src
	verbs += /mob/living/simple_animal/heteromorph_form/proc/heteromorph_return_verb
	if (heteromorph_can_fly)
		verbs += /mob/living/simple_animal/heteromorph_form/proc/heteromorph_takeoff_verb // heteromorph_flight.dm

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_kind_id()
	if (heteromorph_body)
		return heteromorph_body.heteromorph_id
	return null

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_setup(mob/living/human/H)
	var/kind = H.heteromorph_id
	maxHealth = heteromorph_balance_num(kind, "health", maxHealth)
	health = maxHealth
	melee_damage_lower = heteromorph_balance_num(kind, "melee_lower", melee_damage_lower)
	melee_damage_upper = heteromorph_balance_num(kind, "melee_upper", melee_damage_upper)
	if (H.heteromorph_colour)
		icon_state = H.heteromorph_colour
		icon_living = icon_state
		icon_dead = icon_state
	heteromorph_body = H
	heteromorph_started = world.time
	var/datum/heteromorph/K = heteromorph_kind(kind)
	if (K && ("fire" in K.breaths))
		verbs += /mob/living/simple_animal/heteromorph_form/proc/heteromorph_breathe_fire // heteromorph_breath.dm
	if (K && ("haze" in K.breaths))
		verbs += /mob/living/simple_animal/heteromorph_form/proc/heteromorph_breathe_haze

/mob/living/simple_animal/heteromorph_form/Life()
	if (heteromorph_leaving)
		return
	if (!heteromorph_body || QDELETED(heteromorph_body) || heteromorph_body.loc != src)
		heteromorph_return(TRUE, "Your true form cannot hold without its body.")
		return
	..()
	var/kind = heteromorph_kind_id()
	// Holding the form wears on the body: hunger and thirst while it lasts.
	var/wear = heteromorph_flying ? heteromorph_balance_num(kind, "fly_nutrition_multiplier", 2) : 1
	heteromorph_body.nutrition = max(0, heteromorph_body.nutrition - heteromorph_balance_num(kind, "nutrition_per_life", 0.5) * wear)
	heteromorph_body.water = max(0, heteromorph_body.water - heteromorph_balance_num(kind, "water_per_life", 0.25) * wear)
	if (world.time >= heteromorph_started + heteromorph_balance_num(kind, "max_minutes", 20) * 600)
		heteromorph_return(FALSE, "You cannot hold your true form any longer.")
	else if (heteromorph_body.nutrition <= 0 || heteromorph_body.water <= 0)
		heteromorph_return(TRUE, "Hunger drags you back into your human shape.")

// Low health forces the return instead of killing the form.
/mob/living/simple_animal/heteromorph_form/updatehealth()
	if (heteromorph_leaving)
		return
	health = maxHealth - getOxyLoss() - getToxLoss() - getBurnLoss() - getBruteLoss() - getCloneLoss() - halloss
	if (health <= maxHealth * heteromorph_balance_num(heteromorph_kind_id(), "revert_fraction", 0.15))
		heteromorph_return(TRUE, "Your true form breaks and you fall back into your human shape.")

/mob/living/simple_animal/heteromorph_form/death(gibbed, deathmessage)
	heteromorph_return(TRUE, "Your true form breaks and you fall back into your human shape.")
	return FALSE

/mob/living/simple_animal/heteromorph_form/gib()
	heteromorph_return(TRUE, "Your true form breaks and you fall back into your human shape.")

/mob/living/simple_animal/heteromorph_form/Destroy()
	heteromorph_forms_live -= src
	if (heteromorph_body && heteromorph_body.loc == src)
		heteromorph_body.forceMove(get_turf(src))
	heteromorph_body = null
	return ..()

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_return_verb()
	set name = "Return to Human Form"
	set category = "IC"
	set desc = "Fold your true form away and stand as a human again."
	if (usr != src || heteromorph_leaving)
		return
	heteromorph_return(FALSE, null)

// Put the human back where the form stands and move the player into it. Never
// sleeps, so a save can call it for every form in one pass.
/mob/living/simple_animal/heteromorph_form/proc/heteromorph_return(forced, reason)
	if (heteromorph_leaving)
		return FALSE
	heteromorph_leaving = TRUE
	var/mob/living/human/H = heteromorph_body
	var/turf/T = get_turf(src)
	var/kind = heteromorph_kind_id()
	var/was_flying = heteromorph_flying
	if (was_flying)
		T = heteromorph_landing_turf(T) // heteromorph_flight.dm: never set a body down inside a wall
	if (T)
		heteromorph_flash(T, TRUE)
	if (H && !QDELETED(H))
		H.forceMove(T)
		if (mind)
			mind.transfer_to(H)
		else if (key)
			H.key = key
		H.heteromorph_cooldown_until = world.realtime + heteromorph_balance_num(kind, "cooldown_minutes", 30) * 600
		if (forced)
			H.adjustBruteLoss(heteromorph_balance_num(kind, "revert_brute", 25) + (was_flying ? heteromorph_balance_num(kind, "fall_brute", 30) : 0))
			H.Weaken(heteromorph_balance_num(kind, "revert_weaken", 8))
		if (reason)
			to_chat(H, forced ? SPAN_WARNING(reason) : SPAN_NOTICE(reason))
		H.visible_message(SPAN_WARNING("The light fades, and [H] stands where \the [src] was."))
		heteromorph_log("[key_name(H)] returned to human form[forced ? " (forced: [reason])" : ""] at [T ? "[T.x],[T.y],[T.z]" : "nowhere"].")
		H.heteromorph_refresh_verbs()
	heteromorph_body = null
	qdel(src)
	return TRUE

/mob/living/simple_animal/heteromorph_form/dragon
	name = "golden dragon"
	desc = "A dragon of gleaming gold scales, vast enough to blot out the sun."
	icon = 'icons/mob/heteromorph_dragon.dmi'
	icon_state = "gold"
	icon_living = "gold"
	icon_dead = "gold"
	pixel_x = -16
	bound_width = 64
	bound_height = 64
	health = 1500
	maxHealth = 1500
	melee_damage_lower = 30
	melee_damage_upper = 45
	attacktext = "rakes"
	speak_emote = list("rumbles", "roars")
	move_to_delay = 3

/mob/living/simple_animal/heteromorph_form/Move(NewLoc, Dir)
	if (heteromorph_flying)
		return heteromorph_fly_step(NewLoc, Dir) // heteromorph_flight.dm
	. = ..()
	if (. && icon_living && !heteromorph_leaving)
		flick("[icon_living]_walk", src)

/mob/living/simple_animal/heteromorph_form/UnarmedAttack(var/atom/A, var/proximity)
	if (icon_living && isliving(A))
		flick("[icon_living]_attack", src)
	return ..()

// ---------- the flash of light while changing ----------

/obj/effect/heteromorph_flash
	name = "blinding light"
	icon = 'icons/mob/heteromorph_dragon.dmi'
	icon_state = "transform_flash"
	pixel_x = -32
	pixel_y = -32
	layer = 5
	mouse_opacity = FALSE
	anchored = TRUE

// Centred on one human tile, or with over_form on a 2x2 form standing on T.
/proc/heteromorph_flash(turf/T, over_form = FALSE)
	var/obj/effect/heteromorph_flash/F = new(T)
	if (over_form)
		F.pixel_x = -16
		F.pixel_y = -16
	spawn(9)
		if (F && !QDELETED(F))
			qdel(F)

// ---------- taking the form ----------

/mob/living/human/proc/heteromorph_refresh_verbs()
	var/datum/heteromorph/K = heteromorph_active()
	if (K && K.form_type)
		verbs |= /mob/living/human/proc/heteromorph_take_form
	else
		verbs -= /mob/living/human/proc/heteromorph_take_form

// Why the form cannot be taken here and now, or null.
/mob/living/human/proc/heteromorph_form_problem(datum/heteromorph/K)
	if (!K || !K.form_type)
		return "You have no other shape."
	if (stat != CONSCIOUS || restrained() || buckled)
		return "You cannot change like this."
	if (!isturf(loc))
		return "There is no room to change here."
	if (world.realtime < heteromorph_cooldown_until && heteromorph_cooldown_until - world.realtime < 24 * 36000)
		return "Your true form is not ready to return yet."
	// The form fills two tiles by two, from this tile east and north.
	var/turf/T = loc
	for (var/dx in 0 to 1)
		for (var/dy in 0 to 1)
			var/turf/S = locate(T.x + dx, T.y + dy, T.z)
			if (!S || S.density)
				return "There is no room to change here."
			for (var/atom/movable/A in S)
				if (A != src && A.density)
					return "There is no room to change here."
	return null

/mob/living/human/proc/heteromorph_take_form()
	set name = "Take Your True Form"
	set category = "IC"
	set desc = "Shed your human shape."
	if (usr != src || !client || client.mob != src)
		return
	var/datum/heteromorph/K = heteromorph_active()
	var/problem = heteromorph_form_problem(K)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	visible_message(SPAN_WARNING("Light begins to pour from [src]'s skin."), SPAN_NOTICE("You let your human shape go."))
	heteromorph_flash(loc)
	if (!do_after(src, heteromorph_balance_num(K.id, "transform_seconds", 10) * 10, src, needhand = FALSE))
		to_chat(src, SPAN_NOTICE("You hold on to your human shape."))
		return
	K = heteromorph_active()
	problem = heteromorph_form_problem(K)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	heteromorph_become_form(K)

// The change itself, after the channel. Never sleeps.
/mob/living/human/proc/heteromorph_become_form(datum/heteromorph/K)
	var/turf/T = loc
	var/form_path = K.form_type
	var/mob/living/simple_animal/heteromorph_form/F = new form_path(T, src)
	F.heteromorph_setup(src)
	F.name = initial(F.name)
	F.real_name = F.name
	F.dir = dir
	divine_break_covenant("Your shape changes and the prayer breaks.") // covenant.dm
	forceMove(F)
	if (mind)
		mind.transfer_to(F)
	else
		F.key = key
	heteromorph_flash(T, TRUE)
	F.visible_message(SPAN_DANGER("In a blaze of light, \a [F] rises where [real_name] stood!"))
	heteromorph_log("[key_name(F)] ([real_name]) took the [K.name] true form at [T.x],[T.y],[T.z].")

// Before a world save, put every body back (saving.dm calls this). A save
// must never record the player as a form mob holding a hidden human.
/proc/heteromorph_return_all(reason)
	for (var/mob/living/simple_animal/heteromorph_form/F in heteromorph_forms_live.Copy())
		if (!QDELETED(F))
			F.heteromorph_return(FALSE, reason)
