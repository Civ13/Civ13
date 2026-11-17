// One-time survival hints (chat feedback, 2026-11-17): the first time an
// account's character is cold, soaked, starving, parched, stuck in a dug
// hole, knocked down or holding a crafting material, one chat line says what
// to do about it. Each hint is shown once per account (prefs), follows the
// "Show tips" setting and is skipped in the lobby Practice Room.

/datum/preferences
	var/list/survival_hints_seen = list()

// id => the line. Ids are plain words: they are saved in the prefs list.
var/global/list/survival_hint_texts = list(
	"cold" = "You are getting dangerously cold. Stand next to a lit campfire or brazier, get under a roof and put on warmer clothes such as a fur coat. The temperature icon on your HUD shows how you are doing.",
	"soaked" = "Wet clothes chill you much faster. Get out of the rain or water and stand by a lit fire or under a roof until you dry off.",
	"starving" = "You are running low on food. Pick berries from a bush on Grab intent, or hunt a small animal and roast its meat on a lit campfire. Click yourself with food in your hand to eat it.",
	"parched" = "You are running low on water. Click a river, lake or well with an empty hand on Grab intent to drink. Never drink salt water, and boil water in a pot when you can.",
	"pit" = "You are at the bottom of a dug hole. Face one of its walls and use Climb Up in the IC tab, or click the wall with an empty hand on Grab intent. Keep one hand free.",
	"knocked_down" = "You have been knocked down. You get back up by yourself after a few seconds. If you lay down on purpose, use Rest in the IC tab to stand up.",
	"stack" = "You are holding a crafting material. Use it in your hand (press Z, or click it) to open the Crafting window and see what it makes.")

#define SURVIVAL_HINT_EVERY 5 // life ticks between checks
// A quarter of the starting 600 food and 500 water.
#define SURVIVAL_HINT_FOOD 150
#define SURVIVAL_HINT_WATER 125

// The hint this character's situation calls for that `seen` lacks, or null.
/mob/living/human/proc/survival_hint_due(list/seen)
	if (stat != CONSCIOUS)
		return null
	if (weakened > 0 && !("knocked_down" in seen))
		return "knocked_down"
	if (!("cold" in seen) && species && bodytemperature < species.cold_level_1)
		return "cold"
	if (!("soaked" in seen) && cold_wetness >= 1)
		return "soaked"
	if (!("starving" in seen) && nutrition <= SURVIVAL_HINT_FOOD)
		return "starving"
	if (!("parched" in seen) && water <= SURVIVAL_HINT_WATER)
		return "parched"
	if (!("pit" in seen) && ledge_under_shaft(src))
		return "pit"
	if (!("stack" in seen))
		var/obj/item/stack/S = get_active_hand()
		if (istype(S) && S.recipes && S.recipes.len)
			return "stack"
	return null

/mob/living/human/proc/handle_survival_hints()
	if (!client || (life_tick % SURVIVAL_HINT_EVERY) || istype(src, /mob/living/human/practice))
		return
	var/datum/preferences/P = client.prefs
	if (!P || !client.is_preference_enabled(/datum/client_preference/show_tips))
		return
	if (!islist(P.survival_hints_seen))
		P.survival_hints_seen = list()
	if (P.survival_hints_seen.len >= survival_hint_texts.len)
		return
	var/id = survival_hint_due(P.survival_hints_seen)
	if (!id)
		return
	P.survival_hints_seen += id
	P.save_preferences()
	to_chat(src, "<font color='#5194BB'><b>Tip:</b> [survival_hint_texts[id]]</font>")

#undef SURVIVAL_HINT_EVERY
#undef SURVIVAL_HINT_FOOD
#undef SURVIVAL_HINT_WATER
