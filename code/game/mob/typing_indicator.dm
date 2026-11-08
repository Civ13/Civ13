// Typing indicator: a bubble over a mob while its player writes a Say or Me
// message in the popup (T and F3). Ideas from CM-SS13's typing indicators
// (cmss13-devs/cmss13, AGPL-3.0), reimplemented for Civ13:
// - separate bubbles for speech and emotes;
// - the bubble does not turn sideways when its owner lies down;
// - it survives the human icon rebuilds that clear overlays;
// - it always clears, including when the owner dies or logs out mid-message;
// - nothing about it is saved with the world.

#define TYPING_INDICATOR_LIFETIME 30 * 10	//grace period after which typing indicator disappears regardless of text in chatbar

mob/var/tmp/hud_typing = FALSE //set when typing in an input window instead of chatline
mob/var/tmp/typing = null // null, "say" or "emote"
mob/var/tmp/last_typed
mob/var/tmp/last_typed_time
mob/var/tmp/image/typing_indicator

/mob/persistence_runtime_var(key)
	return (key in list("hud_typing", "typing", "last_typed", "last_typed_time", "typing_indicator")) || ..()

/proc/typing_indicator_state(kind)
	return kind == "emote" ? "typing_emote" : "typing"

/mob/proc/typing_indicator_allowed()
	return client && stat == CONSCIOUS && is_preference_enabled(/datum/client_preference/show_typing_indicator)

/mob/proc/make_typing_indicator(kind)
	var/image/I = image('icons/mob/talk.dmi', icon_state = typing_indicator_state(kind))
	// Stay upright and unscaled whatever the owner's transform.
	I.appearance_flags = RESET_TRANSFORM | KEEP_APART
	I.layer = FLY_LAYER
	return I

/mob/proc/clear_typing_indicator()
	if (typing_indicator)
		overlays -= typing_indicator
	typing_indicator = null
	typing = null

// state: FALSE clears; TRUE or "say" shows the speech bubble; "emote" shows the emote bubble.
/mob/proc/set_typing_indicator(var/state)
	if (!state)
		clear_typing_indicator()
		return FALSE
	var/kind = state == "emote" ? "emote" : "say"
	if (!typing_indicator_allowed())
		clear_typing_indicator()
		return FALSE
	if (typing == kind && typing_indicator)
		overlays |= typing_indicator
		return kind
	clear_typing_indicator()
	typing_indicator = make_typing_indicator(kind)
	typing_indicator.invisibility = invisibility
	overlays += typing_indicator
	typing = kind
	return kind

// Called after anything that rebuilds a mob's overlays from scratch.
/mob/proc/reapply_typing_indicator()
	if (!typing_indicator)
		return
	if (!typing_indicator_allowed())
		clear_typing_indicator()
		return
	overlays |= typing_indicator

/mob/living/human/update_icons()
	. = ..()
	reapply_typing_indicator()

/mob/Logout()
	clear_typing_indicator()
	return ..()

/hook/death/proc/clear_typing_on_death(mob/living/human/H, gibbed)
	if (H)
		H.clear_typing_indicator()
	return TRUE

/mob/verb/say_wrapper()
	set name = ".Say"
	set hidden = TRUE

	set_typing_indicator("say")
	hud_typing = TRUE
	var/message = input("","say (text)") as text
	hud_typing = FALSE
	set_typing_indicator(FALSE)
	if (message)
		say_verb(message)

/mob/verb/me_wrapper()
	set name = ".Me"
	set hidden = TRUE

	set_typing_indicator("emote")
	hud_typing = TRUE
	var/message = input("","me (text)") as text
	hud_typing = FALSE
	set_typing_indicator(FALSE)
	if (message)
		me_verb(message)

/mob/proc/handle_typing_indicator()
	if (is_preference_enabled(/datum/client_preference/show_typing_indicator) && !hud_typing)
		var/temp = winget(client, "input", "text")

		if (temp != last_typed)
			last_typed = temp
			last_typed_time = world.time

		if (world.time > last_typed_time + TYPING_INDICATOR_LIFETIME)
			set_typing_indicator(FALSE)
			return
		if (length(temp) > 5 && findtext(temp, "Say \"", TRUE, 7))
			set_typing_indicator("say")
		else if (length(temp) > 3 && findtext(temp, "Me ", TRUE, 5))
			set_typing_indicator("emote")

		else
			set_typing_indicator(FALSE)

#undef TYPING_INDICATOR_LIFETIME
