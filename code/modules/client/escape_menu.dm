// Escape menu, adapted from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0)
// modules/escape_menu. Reimplemented for Civ13 as a plain browser window:
// Esc opens it, and F11 now toggles fullscreen (Esc's old job).

/datum/escape_menu
	var/client/owner

/datum/escape_menu/New(client/C)
	owner = C

/client/var/tmp/datum/escape_menu/escape_menu = null

// Each entry: action id = list(label, hint). Built per viewer so it only offers
// what that player can actually do right now.
/datum/escape_menu/proc/entries()
	var/list/L = list()
	L["resume"] = list("Resume", "Close this menu.")
	L["fullscreen"] = list(owner.fullscreen ? "Leave fullscreen" : "Fullscreen", "Also on F11.")
	L["fit"] = list("Fit viewport", "Resize the map to fill the window.")
	L["settings"] = list("Character and settings", "Character setup and game preferences.")
	L["hotkeys"] = list("Hotkeys", "List the default keys.")
	L["help"] = list("Ask for help", "Ask a gameplay question.")
	L["mentorhelp"] = list("Mentorhelp", "Ask a mentor.")
	L["adminhelp"] = list("Adminhelp", "Contact an admin.")
	L["bug"] = list("Report bug", "Send a bug report.")
	if (shard_group && shard_group.enabled)
		L["regions"] = list("Regions", "See the other worlds in this group and how to travel.")
	var/mob/living/human/H = owner.mob
	if (escape_menu_persistent() && istype(H) && H.stat != DEAD && !H.sleeping)
		L["sleep"] = list("Sleep in this bed", "Assigns the bed you stand on as your return point.")
	L["disconnect"] = list("Disconnect", "Close the game.")
	return L

/proc/escape_menu_persistent()
	return persistence_bed_return_enabled()

/datum/escape_menu/proc/html()
	var/list/rows = list()
	var/list/L = entries()
	for (var/id in L)
		var/list/E = L[id]
		rows += "<a href='byond://?src=\ref[src];esc=[id]' style='display:block;margin:4px 0;padding:6px 10px;border:1px solid #777;text-decoration:none;color:#ddd;background:#2a2a2a'><b>[E[1]]</b><br><span style='font-size:10px;color:#aaa'>[E[2]]</span></a>"
	var/note = ""
	if (escape_menu_persistent())
		note = "<p style='color:#cfc;font-size:11px'>This world is persistent. When you disconnect your character stays where you left it, asleep and vulnerable. Sleep in a bed first so you wake up there.</p>"
	return "<html><head><title>Menu</title></head><body style='font-family:Verdana;font-size:12px;background:#1b1b1b;color:#ddd;margin:8px'>[note][jointext(rows, "")]</body></html>"

/datum/escape_menu/proc/show()
	owner << browse(html(), "window=escape_menu;size=300x560;can_resize=0")

/datum/escape_menu/proc/hide()
	owner << browse(null, "window=escape_menu")

/datum/escape_menu/Topic(href, list/href_list)
	if (!owner || usr != owner.mob)
		return
	var/action = href_list["esc"]
	if (!(action in entries()))
		return
	if (action != "fullscreen" && action != "fit")
		hide()
	switch (action)
		if ("fullscreen")
			owner.updateFullscreen()
			show()
		if ("fit")
			owner.fit_viewport()
		if ("settings")
			owner.character_setup()
		if ("hotkeys")
			owner.hotkeys_help()
		if ("help")
			owner.ask_player_help()
		if ("mentorhelp")
			owner.mentorhelp()
		if ("adminhelp")
			owner.adminhelp()
		if ("bug")
			owner.report_bug()
		if ("regions")
			owner.view_regions()
		if ("sleep")
			var/mob/living/human/H = owner.mob
			if (istype(H))
				H.mob_sleep()
		if ("disconnect")
			winset(owner, null, "command=.quit")

/client/verb/open_escape_menu()
	set name = "Game Menu"
	set desc = "Resume, settings, help and disconnect. Also opens with Esc."
	set category = "OOC"
	if (!escape_menu || escape_menu.owner != src)
		escape_menu = new(src)
	// A second Esc closes the menu again.
	if (winget(src, "escape_menu", "is-visible") == "true")
		escape_menu.hide()
		return
	escape_menu.show()
