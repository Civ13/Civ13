// Menu windows for agent characters (docs/agent-control.md#windows).
//
// Players reach research, trade posts, suppliers, faction and recruitment
// menus, books and the like through HTML windows whose links call an object's
// Topic. An agent character has no client to show them to, so browse_to keeps
// a copy of what the character was shown, character_observe lists it (plain
// text plus numbered links), and the topic action presses one of those links
// as the player's client would. Only links the character was actually shown can
// be pressed, so an agent cannot reach any Topic a player could not.

#define AGENT_WINDOWS_MAX 6 // open windows remembered per character
#define AGENT_WINDOW_LINKS 60 // links kept per window
#define AGENT_WINDOW_TEXT 1500 // characters of plain window text kept

/datum/agent_character/var/list/windows = list() // window id -> list(id, window, title, text, links)
/datum/agent_character/var/window_serial = 0

// show_browse: use instead of "target << browse(html, options)": the same window for a
// player, and a readable copy for an agent character (which has no client).
/proc/show_browse(target, html, options)
	target << browse(html, options)
	if (!agent_characters.len)
		return
	var/mob/M = target
	if (!istype(M) || M.client)
		return
	var/datum/agent_character/C = agent_character_for(M)
	if (C)
		C.note_window(html, options)

/proc/agent_window_name(options)
	var/list/opts = params2list("[options]")
	var/window = opts["window"]
	return istext(window) && length(window) ? copytext(window, 1, 65) : "browser"

/datum/agent_character/proc/note_window(html, options)
	var/window = agent_window_name(options)
	if (isnull(html))
		windows -= window // browse(null) closes it
		return
	if (!istext(html))
		html = "[html]"
	var/static/regex/scripts = regex(@"<script\b[\s\S]*?</script>", "gi")
	var/static/regex/styles = regex(@"<style\b[\s\S]*?</style>", "gi")
	html = styles.Replace(scripts.Replace(html, ""), "")
	var/static/regex/title_rx = regex(@"<title>([\s\S]*?)</title>", "i")
	var/title = title_rx.Find(html) ? trim(agent_plain_text(title_rx.group[1])) : window
	var/list/links = list()
	var/static/regex/link_rx = regex(@{"<a\b[^>]*?href\s*=\s*['"]([^'"]*)['"][^>]*>([\s\S]*?)</a>"}, "gi")
	var/pos = 1
	while (links.len < AGENT_WINDOW_LINKS && link_rx.Find(html, pos))
		pos = link_rx.next
		var/href = html_decode(link_rx.group[1])
		if (!agent_window_href_query(href))
			continue // web links and anchors are not game actions
		var/label = trim(agent_plain_text(link_rx.group[2]))
		if (!length(label))
			label = "link"
		links += list(list("link" = links.len + 1, "label" = copytext(label, 1, 81), "href" = href))
	// Block tags become line breaks so the plain text keeps its rows apart.
	var/static/regex/breaks = regex(@"<(br|/p|/tr|/li|/h\d|/div|hr)\b[^>]*>", "gi")
	var/static/regex/tags = regex(@"<[^>]*>", "g")
	var/text = html_decode(tags.Replace(breaks.Replace(html, "\n"), ""))
	var/static/regex/blank_lines = regex(@"\n\s*\n+", "g")
	text = trim(blank_lines.Replace(text, "\n"))
	if (length(text) > AGENT_WINDOW_TEXT)
		text = copytext(text, 1, AGENT_WINDOW_TEXT + 1)
	window_serial++
	windows -= window
	windows[window] = list("id" = window_serial, "window" = window, "title" = copytext(title, 1, 81), "text" = text, "links" = links)
	while (windows.len > AGENT_WINDOWS_MAX)
		windows.Cut(1, 2)

// The query part of a game link ("?src=...;x=y" or "byond://?src=..."), or null.
/proc/agent_window_href_query(href)
	if (!istext(href))
		return null
	if (copytext(href, 1, 2) == "?")
		return copytext(href, 2)
	if (lowertext(copytext(href, 1, 10)) == "byond://?")
		return copytext(href, 10)
	return null

// Open windows for character_observe, links without their raw hrefs.
/datum/agent_character/proc/window_rows(since = 0)
	. = list()
	for (var/window in windows)
		var/list/W = windows[window]
		if (W["id"] <= since)
			continue
		var/list/links = list()
		for (var/list/L in W["links"])
			links += list(list("link" = L["link"], "label" = L["label"]))
		. += list(list("id" = W["id"], "window" = W["window"], "title" = W["title"], "text" = W["text"], "links" = links))

// The object a link's Topic goes to, as /client/Topic would route it, or null
// for links only a client or an admin could follow.
/proc/agent_window_target(list/href_list, mob/M)
	if (href_list["_src_"])
		return href_list["_src_"] == "usr" ? M : null // holder, prefs and vars are client and admin routes
	if (!istext(href_list["src"]))
		return null
	var/datum/D = locate(href_list["src"])
	if (!istype(D) || QDELETED(D) || isclient(D) || agent_protected_target(D) || istype(D, /datum/admins))
		return null
	return D

/datum/agent_control/proc/agent_window_topic(datum/agent_character/C, list/req, from_queue)
	agent_queue_only("topic", from_queue) // a Topic may start timed work or open a prompt
	var/mob/living/M = C.body
	if (M.stat == DEAD)
		agent_fail("cannot_act", "the character is dead")
	var/window = agent_text_arg(req, "window", 64)
	var/list/W = C.windows[window]
	if (!W)
		agent_fail("not_found", "no open window [window]; see windows in character_observe")
	var/list/chosen = null
	var/wanted_link = text2num("[req["link"]]")
	var/wanted_label = istext(req["label"]) ? lowertext(trim(req["label"])) : null
	for (var/list/L in W["links"])
		if ((wanted_link && L["link"] == wanted_link) || (!wanted_link && wanted_label && lowertext(L["label"]) == wanted_label))
			chosen = L
			break
	if (!chosen)
		agent_fail("not_found", "window [window] has no such link; give link (a number) or label")
	var/href = agent_window_href_query(chosen["href"])
	var/list/href_list = params2list(href)
	var/datum/hsrc = agent_window_target(href_list, M)
	if (!hsrc)
		agent_fail("unsupported", "that link is handled by the player's client, not by a game object")
	C.next_action = world.time + 2
	usr = M
	hsrc.Topic(href, href_list)
	return "[W["title"]]: [chosen["label"]]"

// Closing a window: forget it, as a player closing it does.
/datum/agent_control/proc/agent_window_close(datum/agent_character/C, list/req)
	var/window = agent_text_arg(req, "window", 64)
	if (!C.windows[window])
		agent_fail("not_found", "no open window [window]")
	C.windows -= window
	return window

#undef AGENT_WINDOWS_MAX
#undef AGENT_WINDOW_LINKS
#undef AGENT_WINDOW_TEXT
