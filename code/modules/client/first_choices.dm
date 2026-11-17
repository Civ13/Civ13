// First-join choices (chat feedback, 2026-11-17): the first time an account
// plays a character it is asked three quick questions - how movement should
// feel, where the name under the mouse is shown, and which HUD style to use -
// before the tutorial starts. Players from before this see it once too, with
// their current choices preselected. Cancelling a question keeps the current
// choice. Everything asked here can be changed later in Settings.

/datum/preferences
	var/first_choices_done = FALSE

/client/var/tmp/first_choices_open = FALSE

var/global/list/first_choice_movement = list(
	"A quick tap moves one whole tile (recommended)" = TRUE,
	"I stop exactly where I let go of the key" = FALSE)

var/global/list/first_choice_hover = list(
	"Next to the mouse pointer" = 1,
	"In a line at the bottom of the screen" = 2,
	"Hidden" = 0)

// HUD style label => its all_ui_styles name.
var/global/list/first_choice_hud = list(
	"Console (the standard HUD)" = "ConsoleStyle",
	"1713 (the classic HUD)" = "1713Style",
	"New" = "NewStyle",
	"Lite Web" = "LiteWebStyle",
	"FoF" = "FoFStyle")

// The label in choices whose value is current, or the first label.
/proc/first_choice_current(list/choices, current)
	for (var/label in choices)
		if (choices[label] == current)
			return label
	return choices[1]

/client/proc/first_choices_due(mob/living/human/H)
	return prefs && !prefs.first_choices_done && !first_choices_open && istype(H) && !istype(H, /mob/living/human/practice)

/client/proc/set_ui_style(style)
	if (!prefs || !(style in all_ui_styles) || style == prefs.UI_style)
		return FALSE
	prefs.UI_style = style
	var/datum/hud/currhud = global.HUDdatums[style]
	if (currhud)
		prefs.UI_file = currhud.icon
	prefs.save_preferences()
	if (ishuman(mob))
		var/mob/living/human/H = mob
		H.regenerate_icons()
	return TRUE

// Asks the three questions when they are due, then starts the tutorial.
/client/proc/first_choices_login(mob/living/human/H)
	set waitfor = FALSE
	if (first_choices_due(H))
		first_choices_open = TRUE
		ask_first_choices()
		first_choices_open = FALSE
		if (prefs)
			prefs.first_choices_done = TRUE
			prefs.save_preferences()
			to_chat(src, SPAN_NOTICE("You can change these at any time in Settings, under Controls and HUD."))
	if (ishuman(mob))
		tutorial_login(mob)

/client/proc/ask_first_choices()
	var/intro = "Three quick choices before you start (1 of 3). You can change them later in Settings.\n\n"
	var/pick = player_input(src, "[intro]How should movement feel?", "Movement", first_choice_current(first_choice_movement, prefs.tap_step ? TRUE : FALSE), "anything", first_choice_movement, TRUE)
	if (!prefs)
		return
	if (pick && (pick in first_choice_movement) && first_choice_movement[pick] != (prefs.tap_step ? TRUE : FALSE))
		set_tap_step(first_choice_movement[pick])
	pick = player_input(src, "(2 of 3) Where should the name of the thing under your mouse be shown?", "Hover text", first_choice_current(first_choice_hover, hover_text_mode()), "anything", first_choice_hover, TRUE)
	if (!prefs)
		return
	if (pick && (pick in first_choice_hover) && first_choice_hover[pick] != hover_text_mode())
		set_hover_text_mode(first_choice_hover[pick])
	pick = player_input(src, "(3 of 3) Which HUD style do you want?", "HUD style", first_choice_current(first_choice_hud, prefs.UI_style), "anything", first_choice_hud, TRUE)
	if (!prefs)
		return
	if (pick && (pick in first_choice_hud))
		set_ui_style(first_choice_hud[pick])
