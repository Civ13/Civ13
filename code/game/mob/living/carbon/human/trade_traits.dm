// ============================================================
// Trades (Val, 2026-11-16)
// ------------------------------------------------------------
// Optional hands-on specializations, the workshop counterpart of the fields
// of study (research_tree/study_fields.dm). A trade shortens the waits of its
// own kind of work and lengthens the waits of the other trades a little. It
// never touches the crafting skill, which also gates recipes, so a trade
// can't unlock or lock anything. At most one trade, independent of a field of
// study (Val chose separate groups), taken in setup or with Choose trade in
// play, droppable, with its own 7 real-day re-pick wait.
//
// Balance (Fable review): the boost shrinks with how common the work is.
// Vehicle work is rare, so a Mechanic gets the biggest boost and pays x1.1 on
// everyday crafting; Carpentry is most of what people make, so a Carpenter's
// boost is small. An all-rounder is about even or a little slower with any
// trade; only someone who mostly works one trade comes out ahead.
//
// Labour trades (Val, 2026-11-19): Navvy, Miner and Woodcutter shorten the
// matching work_delay() kind (materials/work_speed.dm). Digging and felling
// are everyday work, so their boost is small; mining is rarer.
// ============================================================

var/global/list/trade_traits = list(
	"Mechanic" = "mechanic",
	"Gunsmith" = "gunsmith",
	"Smith" = "smith",
	"Tailor" = "tailor",
	"Carpenter" = "carpenter",
	"Navvy" = "navvy",
	"Miner" = "miner",
	"Woodcutter" = "woodcutter")

// Wait time for a trade's own work.
var/global/list/trade_focus_time = list(
	"mechanic" = 0.6,
	"gunsmith" = 0.7,
	"smith" = 0.75,
	"tailor" = 0.75,
	"carpenter" = 0.92,
	"navvy" = 0.8,
	"miner" = 0.75,
	"woodcutter" = 0.8)

var/global/list/trade_work_names = list(
	"mechanic" = "vehicle, aircraft, engine and submarine work",
	"gunsmith" = "gunsmithing, black powder guns and fletching",
	"smith" = "anvil and metal workbench work",
	"tailor" = "dressmaking and crafting from cloth, hides and leather",
	"carpenter" = "crafting from wood and stone, and woodworking",
	"navvy" = "digging, trenching and raising or lowering ground",
	"miner" = "mining of rock, seams and cave roofs",
	"woodcutter" = "tree felling")

#define TRADE_OTHER_TIME 1.1
#define TRADE_LOCK (7 * 24 * 36000)

/mob/living/human
	var/trade_lock = 0 // world.realtime before which a new trade can't be picked in play

/mob/living/human/proc/trade()
	for (var/name in trade_traits)
		if (find_trait(name))
			return trade_traits[name]
	return null

/mob/living/human/proc/trade_trait()
	for (var/name in trade_traits)
		if (find_trait(name))
			return name
	return null

// Wait multiplier for work of kind trade; 1 for untagged work or no trade.
/mob/living/human/proc/trade_time_mult(kind)
	var/own = trade()
	if (!own || !(kind in trade_focus_time))
		return 1
	return kind == own ? trade_focus_time[own] : TRADE_OTHER_TIME

// A do_after delay for work of kind trade done by user.
/proc/trade_time(mob/user, delay, kind)
	var/mob/living/human/H = user
	if (!istype(H))
		return delay
	return max(1, round(delay * H.trade_time_mult(kind)))

// Which trade crafting from this stack belongs to, by its material.
/obj/item/stack/proc/stack_trade()
	if (istype(src, /obj/item/stack/material/wood) || istype(src, /obj/item/stack/material/woodplank) || istype(src, /obj/item/stack/material/bamboo) || istype(src, /obj/item/stack/material/wood_piece) || istype(src, /obj/item/stack/material/crude_plank) || istype(src, /obj/item/stack/material/stone) || istype(src, /obj/item/stack/material/sandstone) || istype(src, /obj/item/stack/material/stonebrick) || istype(src, /obj/item/stack/material/marble) || istype(src, /obj/item/stack/material/marblebrick) || istype(src, /obj/item/stack/material/terracotta))
		return "carpenter"
	if (istype(src, /obj/item/stack/material/cloth) || istype(src, /obj/item/stack/material/cotton) || istype(src, /obj/item/stack/material/rettedfabric) || istype(src, /obj/item/stack/material/wool) || istype(src, /obj/item/stack/material/woolcloth) || istype(src, /obj/item/stack/material/rags) || istype(src, /obj/item/stack/material/leather) || istype(src, /obj/item/stack/material/pelt) || istype(src, /obj/item/stack/material/rawhide) || istype(src, /obj/item/stack/material/hairlesshide) || istype(src, /obj/item/stack/material/wethide) || istype(src, /obj/item/stack/material/dryhide) || istype(src, /obj/item/stack/material/kevlar) || istype(src, /obj/item/stack/material/preparedkevlar) || istype(src, /obj/item/stack/material/rawkevlar))
		return "tailor"
	return null

/proc/trade_summary(name)
	var/kind = trade_traits[name]
	if (!kind)
		return ""
	return "Your [trade_work_names[kind]] takes [round((1 - trade_focus_time[kind]) * 100)]% less time. Work of the other trades takes 10% longer. Crafting skill and recipes are not affected."

// ------------------------------------------------------------
// Picking a trade in play
// ------------------------------------------------------------

/mob/living/human/proc/trade_wait_text()
	var/left = trade_lock - world.realtime
	if (left <= 0)
		return null
	var/hours = round(left / 36000)
	if (hours >= 24)
		return "[round(hours / 24)] day\s and [hours % 24] hour\s"
	return hours >= 1 ? "[hours] hour\s" : "less than an hour"

/mob/living/human/proc/set_trade(name)
	traits -= trade_traits
	if (name)
		traits += name
	traits_dirty = TRUE
	trade_lock = world.realtime + TRADE_LOCK

/mob/living/human/verb/choose_trade()
	set name = "Choose trade"
	set category = "IC"
	set desc = "Optionally specialize in one trade, at a cost to the others."
	if (stat == DEAD)
		return
	var/current = trade_trait()
	var/wait = trade_wait_text()
	var/list/options = list()
	if (current)
		options["Drop [current] (no trade)"] = "none"
	if (!wait)
		for (var/name in trade_traits)
			if (name != current)
				options["[name] ([trade_work_names[trade_traits[name]]])"] = name
	if (!options.len)
		to_chat(src, SPAN_WARNING("You changed your trade recently. You can pick a new one in [wait]."))
		return
	options["Cancel"] = null
	var/list/intro = list("A trade is optional. It speeds one kind of hands-on work and slows the other trades a little. After any change you must wait 7 real days before picking again.")
	if (current)
		intro += "You are a [current] now."
	if (wait)
		intro += "You can drop your trade now and pick again in [wait]."
	var/choice = player_input(src, jointext(intro, " "), "Trade", null, "anything", options, TRUE)
	if (!choice || !options[choice] || stat == DEAD)
		return
	var/picked = options[choice]
	if (picked == "none")
		if (trade_trait() != current)
			return
		set_trade(null)
		to_chat(src, SPAN_NOTICE("You no longer specialize in a trade. You can pick again in 7 real days."))
		return
	if (trade_wait_text() || !(picked in trade_traits))
		return
	if (player_alert(src, trade_summary(picked), "Become a [picked]?", list("Yes", "No")) != "Yes" || trade_wait_text())
		return
	set_trade(picked)
	to_chat(src, SPAN_NOTICE("You now work as a <b>[picked]</b>."))
