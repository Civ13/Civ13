// New-player tutorial: short guided steps on the player's real character the
// first time they play (moving, the HUD bars, hands, pockets, intents, the
// Crafting Atlas, eating, chat and, where research lives in books, books).
// Each step is shown in chat and on a line at the top of the screen; most
// finish by themselves when the player does the thing, the rest after a short
// read or the "Got it" link. Progress is kept in the player's preferences, so
// it carries over between rounds and characters, and can be reset from the
// Game Menu (Esc) or the Settings page of character setup.
//
// The lobby Practice Room (practice_rooms.dm) is the separate, safe sandbox;
// this tutorial only watches what a real character does and never changes it.

// prefs.tutorial_state
#define TUTORIAL_UNSET 0    // preferences saved before the tutorial existed
#define TUTORIAL_ACTIVE 1   // new players start here
#define TUTORIAL_FINISHED 2 // finished or stopped
#define TUTORIAL_OFFERED 3  // a returning player was told once that it exists

#define TUTORIAL_TICK (2 SECONDS)
#define TUTORIAL_START_DELAY (6 SECONDS)
#define TUTORIAL_READ_TIME (25 SECONDS) // reading steps finish after this
#define TUTORIAL_REMIND_AFTER (3 MINUTES)
#define TUTORIAL_MAX_REMINDERS 2

/datum/preferences
	var/tutorial_state = TUTORIAL_UNSET
	var/list/tutorial_done = list()

/client/var/tmp/datum/player_tutorial/tutorial

// Every step in order. Ids are plain words: they are saved in the prefs list.
/proc/tutorial_step_ids()
	return list("move", "hud", "pick_up", "swap", "stow", "intent", "atlas", "eat", "chat", "research", "help")

// Steps that are read rather than done finish after TUTORIAL_READ_TIME.
/proc/tutorial_reading_step(id)
	return id in list("hud", "chat", "help")

// Steps that finish only through tutorial_event() (or "Got it").
/proc/tutorial_event_step(id)
	return id in list("atlas", "research")

/proc/tutorial_step_applies(id)
	if (id == "research")
		return map && map.book_research_enabled()
	return TRUE

/proc/tutorial_active_steps()
	var/list/L = list()
	for (var/id in tutorial_step_ids())
		if (tutorial_step_applies(id))
			L += id
	return L

// One line for the top of the screen.
/proc/tutorial_step_short(id)
	switch (id)
		if ("move")
			return "Walk around: hold W, A, S or D (or the arrow keys)."
		if ("hud")
			return "Watch your health, food, water and stamina on the HUD."
		if ("pick_up")
			return "Pick something up: click it with an empty hand."
		if ("swap")
			return "Swap hands: press X or click your other hand."
		if ("stow")
			return "Put an item in a pocket, belt or bag, or wear it."
		if ("intent")
			return "Change your intent: press 1-4 or click the intent box."
		if ("atlas")
			return "Open the Crafting Atlas (IC tab) to see what you can make."
		if ("eat")
			return "Eat or drink something: click yourself with it."
		if ("chat")
			return "Talk: T to speak in character, O for out-of-character."
		if ("research")
			return "Put a book on a research bench, or study a chapter from one."
		if ("help")
			return "Stuck? Use Ask for help in the Game Menu (Esc)."
	return ""

// The full chat text. client decides HUD-specific wording.
/proc/tutorial_step_text(id, client/C)
	switch (id)
		if ("move")
			return "Hold <b>W, A, S or D</b> (or the arrow keys) to walk. You glide freely while a key is held; the <b>Toggle Tap To Step</b> verb (OOC tab) makes a quick tap move exactly one tile. Press <b>M</b> to switch between walking and running."
		if ("hud")
			if (C && C.prefs && C.prefs.UI_style == "ConsoleStyle")
				return "The console at the bottom of the screen holds your hands and carried items. Its three bars show <b>food, water and stamina</b>: running and fighting use stamina, and you must eat and drink to keep going. The figure beside it shows your health."
			return "Your HUD shows your hands, carried items, health and needs. Keep an eye on hunger, thirst and stamina: running and fighting use stamina, and you must eat and drink to keep going."
		if ("pick_up")
			return "Click an item on the ground while your active hand is empty to pick it up. Your active hand is highlighted on the HUD."
		if ("swap")
			return "Press <b>X</b>, or click your other hand on the HUD, to switch which hand you use."
		if ("stow")
			return "Keep your hands free: with an item in your hand, click an empty pocket, belt, back or bag slot, or press <b>E</b> to put it away quickly. Clothing can be worn by clicking its slot."
		if ("intent")
			return "Your intent decides what clicking on someone does: <b>1</b> help, <b>2</b> disarm, <b>3</b> grab, <b>4</b> harm. Help is the safe default; use harm to fight or to chop and break things."
		if ("atlas")
			return "Almost everything is made by hand. Use <b>Crafting Atlas</b> (IC tab) to search recipes, see what each one needs and where it is made, and look up raw materials."
		if ("eat")
			return "Hold some food or a drink and click yourself with it to eat or drink. Water can be drunk from rivers and wells with a container. Food spoils over time."
		if ("chat")
			return "Press <b>T</b> to speak in character and <b>O</b> for out-of-character chat. The tabs on the chat window (All, IC, Radio, OOC) filter messages; these tutorial steps appear under All."
		if ("research")
			return "Knowledge is kept in books. Place a book on a research bench and research there is written into it; anyone can then learn a finished chapter by using the book in hand and choosing <b>Study</b>. Pencil and paper are enough to start."
		if ("help")
			return "If you get stuck, open the <b>Game Menu</b> with <b>Esc</b> and choose <b>Ask for help</b>, or ask other players. The lobby also has a <b>Practice Room</b> for trying the basics safely."
	return ""

/datum/player_tutorial
	var/client/owner
	var/mob/living/human/body
	var/step_id
	var/step_started = 0
	var/reminders = 0
	var/timer
	var/ended = FALSE
	// Baselines taken when a step begins.
	var/turf/start_turf
	var/start_hand
	var/start_intent
	var/list/start_held
	var/start_stowed = 0
	var/last_nutrition
	var/last_water
	var/event_seen
	var/obj/screen/tutorial_hint/hint

/datum/player_tutorial/New(client/C)
	..()
	owner = C

/datum/player_tutorial/Destroy()
	stop_timer()
	remove_hint()
	if (owner && owner.tutorial == src)
		owner.tutorial = null
	owner = null
	body = null
	return ..()

/datum/player_tutorial/proc/stop_timer()
	if (timer)
		deltimer(timer)
		timer = null

/datum/player_tutorial/proc/done_list()
	if (!owner || !owner.prefs)
		return list()
	if (!islist(owner.prefs.tutorial_done))
		owner.prefs.tutorial_done = list()
	return owner.prefs.tutorial_done

// The first applicable step not yet done, or null when all are done.
/datum/player_tutorial/proc/next_step()
	var/list/done = done_list()
	for (var/id in tutorial_active_steps())
		if (!(id in done))
			return id
	return null

/datum/player_tutorial/proc/step_number(id)
	return tutorial_active_steps().Find(id)

/datum/player_tutorial/proc/bind(mob/living/human/H)
	body = H
	if (step_id)
		begin_step(step_id, FALSE)
	show_hint()

/datum/player_tutorial/proc/start(mob/living/human/H)
	bind(H)
	stop_timer()
	timer = addtimer(CALLBACK(src, PROC_REF(first_step)), TUTORIAL_START_DELAY, TIMER_STOPPABLE)

/datum/player_tutorial/proc/first_step()
	timer = null
	if (ended || !owner)
		return
	var/id = next_step()
	if (!id)
		finish()
		return
	to_chat(owner, "<span class='notice'><b>Welcome!</b> A few short steps will show you the basics. They finish as you play. [action_link("stop", "Stop the tutorial")]</span>")
	begin_step(id, TRUE)
	timer = addtimer(CALLBACK(src, PROC_REF(tick)), TUTORIAL_TICK, TIMER_LOOP | TIMER_STOPPABLE)

/datum/player_tutorial/proc/action_link(action, label)
	return "<a href='byond://?src=\ref[src];tutorial=[action]'>[label]</a>"

/datum/player_tutorial/proc/stowed_count()
	if (!body)
		return 0
	. = 0
	for (var/obj/item/I in body.contents)
		if (I == body.l_hand || I == body.r_hand || istype(I, /obj/item/organ))
			continue
		.++
		if (istype(I, /obj/item/weapon/storage))
			. += I.contents.len

// Takes the baselines the step's check compares against.
/datum/player_tutorial/proc/begin_step(id, announce = TRUE)
	step_id = id
	if (announce)
		step_started = world.time
		reminders = 0
		event_seen = FALSE
	if (body)
		start_turf = get_turf(body)
		start_hand = body.hand
		start_intent = body.a_intent
		start_held = list(body.l_hand, body.r_hand)
		start_stowed = stowed_count()
		last_nutrition = body.nutrition
		last_water = body.water
	if (announce)
		show_step()
	show_hint()

/datum/player_tutorial/proc/show_step()
	if (!owner || !step_id)
		return
	var/n = step_number(step_id)
	var/total = tutorial_active_steps().len
	var/action = tutorial_reading_step(step_id) ? action_link("next", "Got it") : action_link("next", "Skip")
	to_chat(owner, "<span class='notice'><b>Tutorial [n] of [total]:</b> [tutorial_step_text(step_id, owner)] [action]</span>")

// Whether the current step is satisfied by what the body did since it began.
/datum/player_tutorial/proc/step_done(id)
	if (event_seen)
		return TRUE
	if (tutorial_reading_step(id))
		return world.time - step_started >= TUTORIAL_READ_TIME
	if (!body)
		return FALSE
	switch (id)
		if ("move")
			var/turf/T = get_turf(body)
			return T && start_turf && (T.z != start_turf.z || get_dist(T, start_turf) >= 3)
		if ("pick_up")
			for (var/obj/item/I in list(body.l_hand, body.r_hand))
				if (!(I in start_held))
					return TRUE
			return FALSE
		if ("swap")
			return body.hand != start_hand
		if ("stow")
			return stowed_count() > start_stowed
		if ("intent")
			return body.a_intent != start_intent
		if ("eat")
			// Compared tick to tick, so hunger falling in between does not hide a meal.
			. = body.nutrition > last_nutrition || body.water > last_water
			last_nutrition = body.nutrition
			last_water = body.water
			return .
	return FALSE

/datum/player_tutorial/proc/tick()
	if (ended)
		return
	if (!owner || !owner.prefs || owner.prefs.tutorial_state != TUTORIAL_ACTIVE)
		qdel(src)
		return
	if (owner.mob != body)
		// A new character (or one taken back after death) picks the tutorial up.
		var/mob/living/human/H = owner.mob
		if (istype(H) && !istype(H, /mob/living/human/practice))
			bind(H)
		else
			body = null
			remove_hint()
		return
	if (!body || body.stat != CONSCIOUS)
		return
	if (!step_id)
		return
	if (step_done(step_id))
		complete_step()
		return
	if (reminders < TUTORIAL_MAX_REMINDERS && world.time - step_started >= TUTORIAL_REMIND_AFTER * (reminders + 1))
		reminders++
		show_step()

/datum/player_tutorial/proc/complete_step()
	if (!owner || !step_id)
		return
	var/list/done = done_list()
	done |= step_id
	owner.prefs.save_preferences()
	owner << sound('sound/effects/pop.ogg', volume = 40)
	var/id = next_step()
	if (!id)
		finish()
		return
	begin_step(id, TRUE)

/datum/player_tutorial/proc/finish()
	if (owner && owner.prefs)
		owner.prefs.tutorial_state = TUTORIAL_FINISHED
		owner.prefs.save_preferences()
		to_chat(owner, "<span class='good'><b>Tutorial complete.</b> You can go through it again from the Game Menu (Esc), Tutorial.</span>")
	end()

/datum/player_tutorial/proc/end()
	if (ended)
		return
	ended = TRUE
	qdel(src)

// Called by the actions a step watches for (the atlas, books, the help verb).
/datum/player_tutorial/proc/note_event(id)
	if (id == step_id)
		event_seen = TRUE

/datum/player_tutorial/proc/show_hint()
	if (!owner || !step_id || !body)
		remove_hint()
		return
	if (!hint)
		hint = new
		hint.tutorial = src
	hint.set_text("Tutorial [step_number(step_id)]/[tutorial_active_steps().len]: [tutorial_step_short(step_id)]")
	owner.screen |= hint

/datum/player_tutorial/proc/remove_hint()
	if (!hint)
		return
	if (owner)
		owner.screen -= hint
	hint.tutorial = null
	qdel(hint)
	hint = null

/datum/player_tutorial/Topic(href, list/href_list)
	if (!owner || usr != owner.mob || ended)
		return
	switch (href_list["tutorial"])
		if ("next")
			if (step_id && body && owner.mob == body)
				complete_step()
		if ("stop")
			owner.prefs.tutorial_state = TUTORIAL_FINISHED
			owner.prefs.save_preferences()
			to_chat(owner, SPAN_NOTICE("Tutorial stopped. You can start it again from the Game Menu (Esc), Tutorial."))
			end()

// ---- Screen line ----

/obj/screen/tutorial_hint
	name = "tutorial"
	icon = null
	screen_loc = "CENTER-6,NORTH-1"
	layer = 30
	maptext_width = 416
	maptext_height = 48
	should_save = FALSE
	var/tmp/datum/player_tutorial/tutorial

/obj/screen/tutorial_hint/proc/set_text(text)
	maptext = "<span style='font-family:Verdana;font-size:8pt;text-align:center;vertical-align:top;color:#f2e6c8;-dm-text-outline:1px #1b140c'>[html_encode(text)]</span>"

/obj/screen/tutorial_hint/Click()
	if (tutorial && usr && tutorial.owner && usr == tutorial.owner.mob)
		tutorial.show_step()

/obj/screen/tutorial_hint/Destroy()
	tutorial = null
	return ..()

// ---- Client hooks ----

/mob/living/human/Login()
	. = ..()
	if (client)
		client.tutorial_login(src)

/client/proc/tutorial_login(mob/living/human/H)
	if (!prefs || !istype(H) || istype(H, /mob/living/human/practice))
		return
	switch (prefs.tutorial_state)
		if (TUTORIAL_UNSET)
			// Players from before the tutorial are told once instead of being walked through it.
			prefs.tutorial_state = TUTORIAL_OFFERED
			prefs.save_preferences()
			to_chat(src, "<span class='notice'>A short tutorial for new players is available from the Game Menu (Esc), Tutorial.</span>")
		if (TUTORIAL_ACTIVE)
			if (tutorial && !tutorial.ended)
				tutorial.bind(H)
			else
				tutorial = new(src)
				tutorial.start(H)

/client/proc/tutorial_event(id)
	if (tutorial && !tutorial.ended)
		tutorial.note_event(id)

/proc/tutorial_event_for(mob/M, id)
	if (M && M.client)
		M.client.tutorial_event(id)

/client/proc/tutorial_status_text()
	if (!prefs)
		return "unknown"
	switch (prefs.tutorial_state)
		if (TUTORIAL_ACTIVE)
			var/total = tutorial_active_steps().len
			var/done = 0
			for (var/id in tutorial_active_steps())
				if (islist(prefs.tutorial_done) && (id in prefs.tutorial_done))
					done++
			return "in progress ([done] of [total] steps done)"
		if (TUTORIAL_FINISHED)
			return "finished"
	return "not started"

// Clears the saved progress and starts again from the first step.
/client/proc/reset_tutorial()
	if (!prefs)
		return
	if (tutorial)
		tutorial.end()
	prefs.tutorial_done = list()
	prefs.tutorial_state = TUTORIAL_ACTIVE
	prefs.save_preferences()
	var/mob/living/human/H = mob
	if (istype(H) && !istype(H, /mob/living/human/practice))
		to_chat(src, SPAN_NOTICE("Tutorial progress reset. The first step follows shortly."))
		tutorial = new(src)
		tutorial.start(H)
	else
		to_chat(src, SPAN_NOTICE("Tutorial progress reset. It starts when you next join as a character."))

/client/proc/tutorial_menu()
	if (!prefs)
		return
	var/list/choices = list()
	if (prefs.tutorial_state == TUTORIAL_ACTIVE && tutorial && !tutorial.ended && tutorial.step_id)
		choices += "Show the current step"
		choices += "Stop the tutorial"
	if (prefs.tutorial_state != TUTORIAL_ACTIVE)
		choices += "Start the tutorial"
	choices += "Reset tutorial progress"
	var/pick = player_input(src, "The tutorial is [tutorial_status_text()].", "Tutorial", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices))
		return
	switch (pick)
		if ("Show the current step")
			if (tutorial)
				tutorial.show_step()
		if ("Stop the tutorial")
			prefs.tutorial_state = TUTORIAL_FINISHED
			prefs.save_preferences()
			if (tutorial)
				tutorial.end()
			to_chat(src, SPAN_NOTICE("Tutorial stopped. Your progress is kept."))
		if ("Start the tutorial")
			var/list/done = prefs.tutorial_done
			if (islist(done) && done.len >= tutorial_active_steps().len)
				reset_tutorial()
				return
			prefs.tutorial_state = TUTORIAL_ACTIVE
			prefs.save_preferences()
			var/mob/living/human/H = mob
			if (istype(H) && !istype(H, /mob/living/human/practice))
				tutorial_login(H)
			else
				to_chat(src, SPAN_NOTICE("The tutorial starts when you next join as a character."))
		if ("Reset tutorial progress")
			reset_tutorial()

/client/verb/tutorial_verb()
	set name = "Tutorial"
	set category = "OOC"
	set desc = "Show, start, stop or reset the new-player tutorial."
	tutorial_menu()
