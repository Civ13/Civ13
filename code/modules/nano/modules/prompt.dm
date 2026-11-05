// Modern, non-modal prompt for WWinput. The calling proc still sleeps until the
// prompt ends, but the player's client is not held in a Dream Seeker modal: the
// window opens without focus, movement continues and the server keeps ticking.
// Only plain notices ("Continue") are routed here so far; typed and list prompts
// keep the classic input() path. Never saved: a prompt only lives for one call.

// A notice nobody answers still ends, as if dismissed, so a caller never sleeps forever.
#define PROMPT_WAIT_LIMIT 6000

// Per-session browser capability: set by any modern UI's acknowledgement, and by
// a prompt whose window had to fall back. Clients are never saved.
/client/var/modern_ui_acknowledged = FALSE
/client/var/modern_ui_failed = FALSE

/var/global/datum/topic_state/prompt/prompt_state = new()

/datum/topic_state/prompt
	should_save = FALSE

/datum/topic_state/prompt/can_use_topic(src_object, mob/user)
	var/datum/nano_module/prompt/prompt = src_object
	if (!istype(prompt) || prompt.finished || !user || user != prompt.owner || !user.client)
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/datum/nano_module/prompt
	name = "Prompt"
	should_save = FALSE
	var/mob/owner
	var/message = ""
	var/title = "Civilization 13"
	var/list/choices
	var/answer
	var/finished = FALSE
	// The browser could not run the modern frontend: the caller shows the classic dialog.
	var/fell_back = FALSE
	var/datum/nanoui/tgui/prompt/ui

/datum/nano_module/prompt/New(mob/_owner, _message, _title, list/_choices)
	..(null)
	owner = _owner
	message = "[_message]"
	if (_title)
		title = "[_title]"
	choices = islist(_choices) && length(_choices) ? _choices.Copy() : list("Continue")

/datum/nano_module/prompt/Destroy()
	finish(null)
	owner = null
	return ..()

/datum/nano_module/prompt/proc/prompt_data()
	var/list/shown = list()
	for (var/choice in choices)
		shown += html_encode("[choice]")
	return list("message" = html_encode(message), "choices" = shown)

/datum/nano_module/prompt/proc/open()
	if (finished || !owner || !owner.client)
		return FALSE
	ui = new /datum/nanoui/tgui/prompt(owner, src, "prompt", "prompt.tmpl", title, 420, 240, _state = prompt_state)
	ui.prompt = src
	ui.set_initial_data(prompt_data())
	ui.set_auto_update(FALSE)
	ui.use_on_close_logic(FALSE)
	ui.open()
	return TRUE

// Sleeps the caller until an answer, a close, a fallback or the time limit.
/datum/nano_module/prompt/proc/wait(limit = PROMPT_WAIT_LIMIT)
	var/deadline = world.time + limit
	while (!finished)
		if (world.time >= deadline || !owner || !owner.client || !ui || !ui.state)
			finish(null)
			break
		sleep(1)
	return answer

// Records the outcome once and closes the window. Later calls change nothing.
/datum/nano_module/prompt/proc/finish(value)
	if (finished)
		return
	finished = TRUE
	answer = value
	var/datum/nanoui/tgui/prompt/old_ui = ui
	ui = null
	if (old_ui)
		old_ui.prompt = null
		if (old_ui.state)
			old_ui.close()

/datum/nano_module/prompt/proc/choose(index)
	if (finished || !isnum(index) || index != round(index) || index < 1 || index > length(choices))
		return FALSE
	finish(choices[index])
	return TRUE

/datum/nanoui/tgui/prompt
	should_save = FALSE
	on_close_logic = FALSE
	window_options = "focus=0;can_close=1;can_minimize=0;can_maximize=0;can_resize=1;titlebar=1;"
	var/datum/nano_module/prompt/prompt

/datum/nanoui/tgui/prompt/allowed_actions()
	return list("answer")

/datum/nanoui/tgui/prompt/update(force_open = FALSE)
	if (prompt && !prompt.finished)
		push_data(prompt.prompt_data(), TRUE)

// There is no classic template for a prompt: a browser that cannot run the
// modern frontend ends the prompt and the caller shows BYOND's own dialog.
/datum/nanoui/tgui/prompt/use_legacy_renderer()
	if (legacy_renderer)
		return
	legacy_renderer = TRUE
	if (user && user.client)
		user.client.modern_ui_failed = TRUE
	var/datum/nano_module/prompt/old_prompt = prompt
	if (old_prompt && !old_prompt.finished)
		old_prompt.fell_back = TRUE
		old_prompt.finish(null)
	else if (state)
		close()

// A prompt belongs to the body that was asked; moving to another body ends it.
/datum/nanoui/tgui/prompt/prepare_user_transfer(client/expected_client)
	close()

/datum/nanoui/tgui/prompt/close()
	var/datum/nano_module/prompt/old_prompt = prompt
	prompt = null
	. = ..()
	if (old_prompt && !old_prompt.finished)
		old_prompt.finish(null)

// The parent Topic has already checked owner, window, generation, status and
// the one allowed action before this runs.
/datum/nanoui/tgui/prompt/consume_topic(href, list/href_list)
	if (!prompt || prompt.finished || legacy_renderer || !frontend_ready || !frontend_acknowledged || status != STATUS_INTERACTIVE || usr != user)
		return TRUE
	prompt.choose(text2num(href_list["answer"]))
	return TRUE

// Routes a plain WWinput notice to the modern prompt when this client's browser
// has already run the modern frontend. FALSE means the caller shows alert().
/proc/wwinput_prompt_notice(client/C, message, title)
	if (!C || !C.mob || !C.modern_ui_acknowledged || C.modern_ui_failed)
		return FALSE
	var/datum/nano_module/prompt/prompt = new(C.mob, message, title, list("Continue"))
	prompt.open()
	prompt.wait()
	var/shown = !prompt.fell_back
	qdel(prompt)
	return shown

#undef PROMPT_WAIT_LIMIT
