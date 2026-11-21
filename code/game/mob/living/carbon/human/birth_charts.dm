// Birth charts.
//
// Every new Nomads or Civilizations character is born under one of twelve
// signs of the night sky, one per season of the year. The sign leans their
// starting stats a little: +10/+5/+5 to three stats and -10/-5/-5 to three
// others from a base of 100, so every sign nets to zero. It replaces the old
// independent pick(90, 100, 120) per stat, which was a wider spread than this.
//
// The sign is rolled at spawn and kept for the character's whole life. It is
// saved on the character and travels between regions with them.

// Sign id -> name, season, calling and stat offsets. Season order.
var/list/birth_chart_signs = list(
	"ox" = list("name" = "the Ox", "season" = "early spring", "calling" = "ploughman, hauler and builder",
		"stats" = list("strength" = 10, "farming" = 5, "stamina" = 5, "dexterity" = -10, "philosophy" = -5, "swimming" = -5)),
	"hearth" = list("name" = "the Hearth", "season" = "mid spring", "calling" = "keeper of a settled village",
		"stats" = list("farming" = 10, "medical" = 5, "crafting" = 5, "hunting" = -10, "swords" = -5, "bows" = -5)),
	"hare" = list("name" = "the Hare", "season" = "late spring", "calling" = "scout, runner and messenger",
		"stats" = list("dexterity" = 10, "stamina" = 5, "throwing" = 5, "strength" = -10, "swords" = -5, "crafting" = -5)),
	"heron" = list("name" = "the Heron", "season" = "early summer", "calling" = "fisher, sailor and diver",
		"stats" = list("swimming" = 10, "hunting" = 5, "dexterity" = 5, "crafting" = -10, "strength" = -5, "rifle" = -5)),
	"stag" = list("name" = "the Stag", "season" = "mid summer", "calling" = "archer and woodland hunter",
		"stats" = list("bows" = 10, "hunting" = 5, "stamina" = 5, "medical" = -10, "philosophy" = -5, "crafting" = -5)),
	"spear" = list("name" = "the Spear", "season" = "late summer", "calling" = "warrior and guard",
		"stats" = list("swords" = 10, "strength" = 5, "throwing" = 5, "philosophy" = -10, "medical" = -5, "farming" = -5)),
	"anvil" = list("name" = "the Anvil", "season" = "early autumn", "calling" = "smith, mason and toolmaker",
		"stats" = list("crafting" = 10, "strength" = 5, "philosophy" = 5, "swimming" = -10, "bows" = -5, "hunting" = -5)),
	"serpent" = list("name" = "the Serpent", "season" = "mid autumn", "calling" = "healer and herbalist",
		"stats" = list("medical" = 10, "dexterity" = 5, "philosophy" = 5, "swords" = -10, "strength" = -5, "farming" = -5)),
	"wolf" = list("name" = "the Wolf", "season" = "late autumn", "calling" = "hunter, raider and pack leader",
		"stats" = list("hunting" = 10, "dexterity" = 5, "swords" = 5, "farming" = -10, "crafting" = -5, "medical" = -5)),
	"owl" = list("name" = "the Owl", "season" = "early winter", "calling" = "scholar, researcher and teacher",
		"stats" = list("philosophy" = 10, "medical" = 5, "crafting" = 5, "strength" = -10, "stamina" = -5, "swords" = -5)),
	"bear" = list("name" = "the Bear", "season" = "mid winter", "calling" = "long marches and heavy labour",
		"stats" = list("stamina" = 10, "strength" = 5, "swimming" = 5, "dexterity" = -10, "bows" = -5, "philosophy" = -5)),
	"hawk" = list("name" = "the Hawk", "season" = "late winter", "calling" = "marksman of the gunpowder ages",
		"stats" = list("rifle" = 10, "pistol" = 5, "dexterity" = 5, "stamina" = -10, "farming" = -5, "swimming" = -5)))

// Every stat a sign may set. Stats outside this list are never touched.
var/list/birth_chart_stats = list("strength", "dexterity", "stamina", "crafting", "medical", "philosophy", "farming", "hunting", "swimming", "throwing", "swords", "bows", "rifle", "pistol")

// Saved with the character, like origin_id.
/mob/living/human/var/birth_chart = null
// Not saved: the sign a verified player chose in Character Setup, used once at spawn.
/mob/living/human/var/tmp/birth_chart_wish = null

/proc/birth_chart_valid(sign_id)
	return istext(sign_id) && islist(birth_chart_signs[sign_id])

/proc/birth_chart_roll()
	var/list/ids = list()
	for (var/sign_id in birth_chart_signs)
		ids += sign_id
	return pick(ids)

/proc/birth_chart_name(sign_id)
	if (!birth_chart_valid(sign_id))
		return null
	return birth_chart_signs[sign_id]["name"]

// "Strength +10, Farming +5" or "Dexterity -10, ..." for one side of a sign.
/proc/birth_chart_side_text(sign_id, positive)
	if (!birth_chart_valid(sign_id))
		return ""
	var/list/parts = list()
	var/list/offsets = birth_chart_signs[sign_id]["stats"]
	for (var/statname in offsets)
		var/offset = offsets[statname]
		if ((offset > 0) == !!positive)
			parts += "[capitalize(statname)] [offset > 0 ? "+" : ""][offset]"
	return jointext(parts, ", ")

/proc/birth_chart_summary(sign_id)
	if (!birth_chart_valid(sign_id))
		return null
	var/list/S = birth_chart_signs[sign_id]
	return "Born under [S["name"]], in [S["season"]]: a [S["calling"]]. Strengths: [birth_chart_side_text(sign_id, TRUE)]. Weaknesses: [birth_chart_side_text(sign_id, FALSE)]."

// Gives a new character their sign and sets their starting stats from it.
// sign_id null takes the sign chosen in Character Setup; none (or unknown)
// rolls one. Sex and age still apply through setStat.
/mob/living/human/proc/apply_birth_chart(sign_id = null)
	if (!sign_id)
		sign_id = birth_chart_wish
	birth_chart_wish = null
	if (!birth_chart_valid(sign_id))
		sign_id = birth_chart_roll()
	birth_chart = sign_id
	var/list/offsets = birth_chart_signs[sign_id]["stats"]
	for (var/statname in birth_chart_stats)
		if (!islist(stats[statname]))
			continue
		setStat(statname, STAT_NORMAL + (offsets[statname] || 0))
		var/value = clamp(stats[statname][1], BIRTH_CHART_STAT_MIN, BIRTH_CHART_STAT_MAX)
		stats[statname] = list(value, value)
	note_birth_chart()
	return sign_id

// A character from before birth charts gets a sign to know themselves by,
// with no change to the stats they already have.
/mob/living/human/proc/ensure_birth_chart()
	if (birth_chart_valid(birth_chart) || stat == DEAD)
		return
	birth_chart = birth_chart_roll()
	note_birth_chart()

// Notes live on the mind, so a body that arrives in a new region writes this
// again when its player takes it. Never written twice.
/mob/living/human/proc/note_birth_chart()
	var/summary = birth_chart_summary(birth_chart)
	if (!summary || !mind)
		return
	var/list/listed = mind.notes["Birth chart"]
	if (islist(listed) && (summary in listed))
		return
	add_note("Birth chart", summary)

// The calling: the sign's +10 stat trains a little faster and its -10 stat a
// little slower. trait_skill_gain_mult() uses it only when no trait already
// changes that stat's training, so a sign never stacks with a trait.
/mob/living/human/proc/birth_chart_gain_mult(statname)
	if (!birth_chart_valid(birth_chart))
		return 1
	var/offset = birth_chart_signs[birth_chart]["stats"][statname]
	if (offset >= 10)
		return BIRTH_CHART_CALLING_FAST
	if (offset <= -10)
		return BIRTH_CHART_CALLING_SLOW
	return 1

// Choosing a sign is for Discord-verified accounts (the soft whitelist).
// Fails closed: an unverified key, or a verified list not yet loaded, rolls.
/proc/birth_chart_choice_allowed(client/C, sign_id)
	return C && birth_chart_valid(sign_id) && !!verified_discord_id(C.ckey)

// Character Setup: "random" or a sign id. Only a verified account may save a sign.
/datum/preferences/proc/setup_birth_chart(value, mob/user)
	if (value == "random")
		birth_chart = "random"
		return
	if (!birth_chart_valid(value))
		return
	if (!user || !birth_chart_choice_allowed(user.client, value))
		setup_notice = "Verify your Discord account to choose your sign. Until then it is drawn when you are born."
		return
	birth_chart = value

/datum/preferences/proc/birth_chart_setup_data(mob/user)
	var/list/data = list()
	data["choice"] = birth_chart_valid(birth_chart) ? birth_chart : "random"
	data["verified"] = (user && user.client && verified_discord_id(user.client.ckey)) ? 1 : 0
	var/mob/living/human/H = user
	if (istype(H) && H.stat != DEAD && birth_chart_valid(H.birth_chart))
		data["current"] = H.birth_chart
	var/list/signs = list()
	for (var/sign_id in birth_chart_signs)
		var/list/S = birth_chart_signs[sign_id]
		signs += list(list("id" = sign_id, "name" = capitalize(S["name"]), "season" = capitalize(S["season"]), "calling" = capitalize(S["calling"]),
			"strengths" = birth_chart_side_text(sign_id, TRUE), "weaknesses" = birth_chart_side_text(sign_id, FALSE)))
	data["signs"] = signs
	return data

/mob/living/human/after_load()
	..()
	ensure_birth_chart()
