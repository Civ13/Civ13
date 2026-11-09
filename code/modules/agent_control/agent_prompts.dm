// Typed prompts for players and agent characters (docs/agent-control.md#prompts).
//
// player_input and player_alert stand in for BYOND's input() and alert() in
// gameplay code. A player gets exactly the same prompt. An agent character has
// no client, so input() would answer nothing; it answers from its step's
// choose instead, and a prompt it could not answer is listed in
// character_observe so the step can be repeated with choose.

// kind: "text", "message", "num", "color" or "anything" (pick one of choices).
// can_cancel: the prompt offers Cancel (as text|null, as null|anything in ...).
/proc/player_input(target, message, title, default, kind = "text", list/choices = null, can_cancel = FALSE)
	if (agent_characters.len && ismob(target))
		var/mob/M = target
		if (!M.client)
			var/datum/agent_character/A = agent_character_for(M)
			if (A)
				return A.answer_prompt(message, title, default, kind, choices, can_cancel)
	if (can_cancel)
		switch (kind)
			if ("text")
				return input(target, message, title, default) as null|text
			if ("message")
				return input(target, message, title, default) as null|message
			if ("num")
				return input(target, message, title, default) as null|num
			if ("color")
				return input(target, message, title, default) as null|color
			else
				return input(target, message, title, default) as null|anything in choices
	switch (kind)
		if ("text")
			return input(target, message, title, default) as text
		if ("message")
			return input(target, message, title, default) as message
		if ("num")
			return input(target, message, title, default) as num
		if ("color")
			return input(target, message, title, default) as color
		else
			return input(target, message, title, default) in choices

// alert() with two or three buttons; returns the pressed button's text.
/proc/player_alert(target, message, title, list/buttons)
	if (agent_characters.len && ismob(target))
		var/mob/M = target
		if (!M.client)
			var/datum/agent_character/A = agent_character_for(M)
			if (A)
				return A.answer_prompt(message, title, null, "anything", buttons, TRUE)
	switch (buttons.len)
		if (2)
			return alert(target, message, title, buttons[1], buttons[2])
		else
			return alert(target, message, title, buttons[1], buttons[2], buttons[3])

// The step's choose answer when it fits the prompt; otherwise the prompt is
// recorded and the default is taken (null for an unanswered choice whose
// default is not one of the options), as a player pressing Enter or Cancel.
/datum/agent_character/proc/answer_prompt(message, title, default, kind, list/choices, can_cancel)
	if (pending_choice && world.time > pending_choice_until)
		pending_choice = null // a stale answer never reaches a later, unrelated prompt
	if (pending_choice)
		var/answer = pending_choice
		var/found = FALSE
		var/value = null
		switch (kind)
			if ("num")
				value = text2num(answer)
				found = isnum(value)
			if ("color")
				var/static/regex/hex = regex(@"^#[0-9a-fA-F]{6}$")
				found = hex.Find(answer) ? TRUE : FALSE
				value = answer
			if ("anything")
				for (var/choice in choices)
					if (lowertext("[choice]") == lowertext(answer))
						value = choice
						found = TRUE
						break
			else
				value = answer
				found = TRUE
		if (found)
			pending_choice = null // one answer per step
			return value
	var/taken = default
	if (kind == "anything" && !(default in choices))
		taken = null
	note_prompt(message, title, kind == "anything" ? choices : null, kind, isnull(taken) ? FALSE : taken)
	return taken
