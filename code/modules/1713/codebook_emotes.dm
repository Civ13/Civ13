// Codebook and emote panel, adapted from CM-SS13 (cmss13-devs/cmss13,
// AGPL-3.0): codebook.dm and the emote panel. Reimplemented for Civ13.

//////////////////////////////////////////////////////////////////////////////
// CODEBOOK: each side gets ten call-and-response pairs per round, so a voice on
// the radio can prove it is a friend. Leaders get one at spawn in team rounds.
//////////////////////////////////////////////////////////////////////////////

var/global/list/codebook_codes = list() // faction text -> list of list(call, response)
var/global/list/codebook_words = list("Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima", "Mike", "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra", "Tango", "Uniform", "Victor", "Whiskey", "Xray", "Yankee", "Zulu")

/proc/codebook_pairs(faction)
	if (!faction)
		faction = "none"
	var/list/pairs = codebook_codes[faction]
	if (!pairs)
		pairs = list()
		var/list/used = list()
		while (pairs.len < 10)
			var/call_code = "[pick(codebook_words)]-[rand(100, 999)]"
			var/response = "[pick(codebook_words)]-[rand(100, 999)]"
			if ((call_code in used) || (response in used) || call_code == response)
				continue
			used += call_code
			used += response
			pairs += list(list(call_code, response))
		codebook_codes[faction] = pairs
	return pairs

/obj/item/weapon/paper/codebook
	name = "codebook"
	desc = "This round's radio challenge codes. Ask with a call; a friend answers with its response."
	var/code_faction = null

/obj/item/weapon/paper/codebook/New(newloc, faction)
	..(newloc)
	if (faction)
		code_faction = faction
	if (code_faction && !info)
		name = "[code_faction] codebook"
		var/list/rows = list()
		for (var/list/pair in codebook_pairs(code_faction))
			rows += "<tr><td>[pair[1]]</td><td>[pair[2]]</td></tr>"
		info = "<b>[code_faction] radio codes</b><br>Challenge with a call; a friend answers with the matching response. Do not read these out in the open.<br><table border=1 cellpadding=3><tr><th>Call</th><th>Response</th></tr>[jointext(rows, "")]</table>"
		update_icon()

// Leaders in team rounds spawn with their side's codebook.
/mob/living/human/proc/give_codebook()
	if (!map || map.civilizations || !faction_text || !original_job)
		return null
	if (!(original_job.is_officer || original_job.is_commander || original_job.is_squad_leader || original_job.is_radioman))
		return null
	var/obj/item/weapon/paper/codebook/C = new(get_turf(src), faction_text)
	if (!equip_to_storage(C))
		put_in_hands(C)
	return C

//////////////////////////////////////////////////////////////////////////////
// EMOTE PANEL: IC > Emotes lists every simple emote as a button.
//////////////////////////////////////////////////////////////////////////////

/proc/emote_panel_acts()
	return list("blink", "blush", "bow", "burp", "chuckle", "clap", "collapse", "cough", "cry", "dance", "drool", "eyebrow", "faint", "frown", "gasp", "giggle", "glare", "grin", "groan", "grumble", "laugh", "look", "moan", "mumble", "nod", "pale", "raise", "salute", "scream", "shake", "shiver", "shrug", "sigh", "smile", "sneeze", "sniff", "snore", "stare", "surrender", "tremble", "twitch", "wave", "whimper", "wink", "yawn", "charge", "medic")

/datum/emote_panel
	var/mob/living/human/owner

/datum/emote_panel/New(mob/living/human/H)
	owner = H

/datum/emote_panel/proc/html()
	var/list/buttons = list()
	for (var/act in emote_panel_acts())
		buttons += "<a href='byond://?src=\ref[src];emote=[act]' style='display:inline-block;min-width:80px;margin:2px;padding:3px;border:1px solid #888;text-align:center;text-decoration:none'>[act]</a>"
	return "<html><head><title>Emotes</title></head><body style='font-family:Verdana;font-size:11px'><p>Click an emote to perform it. Type <b>*name</b> in Say for emotes that need a target, such as *point, *hug or *handshake.</p>[jointext(buttons, "")]</body></html>"

/datum/emote_panel/Topic(href, list/href_list)
	if (!owner || usr != owner || owner.stat != CONSCIOUS)
		return
	var/act = href_list["emote"]
	if (act in emote_panel_acts())
		owner.emote(act)

/mob/living/human/var/tmp/datum/emote_panel/emote_panel = null

/mob/living/human/persistence_runtime_var(key)
	return key == "emote_panel" || ..()

/mob/living/human/verb/open_emote_panel()
	set name = "Emotes"
	set desc = "Show a list of emotes you can click."
	set category = "IC"
	if (!emote_panel || emote_panel.owner != src)
		emote_panel = new(src)
	src << browse(emote_panel.html(), "window=emote_panel;size=460x380")
