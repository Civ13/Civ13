// Native probe for agent menu windows (code/modules/agent_control/agent_windows.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/agent_control/windows_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/window_probe/New()
	return
/mob/living/human/window_probe/update_icons()
	return
/obj/window_probe_menu
	name = "probe menu"
	var/pressed
	var/mob/presser
/obj/window_probe_menu/Topic(href, href_list)
	pressed = href_list["pick"]
	presser = usr

var/window_failures = 0
var/window_runtime_error = FALSE
/proc/window_check(condition, label)
	if (!condition)
		window_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	window_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		window_checks()
	catch(var/exception/e)
		window_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = window_failures, "runtime_error" = window_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/window_fail_code(datum/agent_character/C, list/req)
	try
		agent_control.agent_window_topic(C, req, TRUE)
	catch(var/exception/e)
		return e.desc
	return null

/proc/window_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/window_probe/H = new(T)
	var/obj/window_probe_menu/menu = new(T)
	var/datum/agent_character/C = new
	C.body = H
	agent_characters[H] = C
	var/html = {"<html><head><title>Trade &amp; Barter</title><script>var x = "<a href='?src=bad'>no</a>";</script></head><body>
		<h2>Wares</h2>Bread costs 2 coins<br>
		<a href='?src=\ref[menu];pick=bread'>Buy <b>bread</b></a>
		<a href="byond://?src=\ref[menu];pick=salt">Buy salt</a>
		<a href='https://example.com/'>Wiki</a>
		<a href='?_src_=holder;adminplayeropts=1'>Admin</a>
		<a href='#top'>Top</a>
		</body></html>"}
	show_browse(H, html, "window=trade;size=400x400")
	var/list/rows = C.window_rows()
	window_check(rows.len == 1, "an agent character keeps the window it was shown")
	var/list/W = rows[1]
	window_check(W["window"] == "trade", "the window keeps its name")
	window_check(W["title"] == "Trade & Barter", "the title is read and decoded")
	window_check(findtext(W["text"], "Bread costs 2 coins"), "the plain text is kept")
	window_check(!findtext(W["text"], "<"), "tags are stripped from the text")
	var/list/links = W["links"]
	window_check(links.len == 3, "game links are kept; web links, anchors and script text are not")
	window_check(links[1]["label"] == "Buy bread" && links[2]["label"] == "Buy salt", "link labels are plain text in page order")
	window_check(isnull(links[1]["href"]), "observed links do not expose raw hrefs")

	window_check(isnull(window_fail_code(C, list("window" = "trade", "link" = 1))), "pressing a shown link succeeds")
	window_check(menu.pressed == "bread" && menu.presser == H, "the link's Topic runs with the character as usr")
	window_check(isnull(window_fail_code(C, list("window" = "trade", "label" = "buy salt"))), "a link can be pressed by its label")
	window_check(menu.pressed == "salt", "byond:// links reach the same Topic")
	window_check(findtext(window_fail_code(C, list("window" = "trade", "link" = 3)), "unsupported:") == 1, "client and admin routes are refused")
	window_check(findtext(window_fail_code(C, list("window" = "trade", "link" = 9)), "not_found:") == 1, "a link that was not shown is refused")
	window_check(findtext(window_fail_code(C, list("window" = "shop", "link" = 1)), "not_found:") == 1, "a window that is not open is refused")

	qdel(menu)
	window_check(findtext(window_fail_code(C, list("window" = "trade", "link" = 1)), "unsupported:") == 1, "a link to a deleted object is refused")

	show_browse(H, null, "window=trade")
	window_check(!C.window_rows().len, "browse(null) closes the window")
	for (var/i in 1 to 8)
		show_browse(H, "<a href='?src=1;n=[i]'>n[i]</a>", "window=w[i]")
	rows = C.window_rows()
	window_check(rows.len == 6 && rows[1]["window"] == "w3", "only the newest six windows are kept")
	window_check(C.window_rows(rows[6]["id"] - 1).len == 1, "window_since returns only newer windows")
	var/mob/living/human/window_probe/other = new(T)
	show_browse(other, "<a href='?src=1'>x</a>", "window=x")
	window_check(!agent_character_for(other), "players' windows are not recorded")
