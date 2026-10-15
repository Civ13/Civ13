// Actual production decisions with injected parent Login and HUD screen effects.
// No native client, rendered HUD, or movement acceptance is claimed.
var/list/human_clients_mob_list = list()
/proc/log_debug(message)
	world.log << message
/datum/ui_fixture_preferences
	var/UI_style = "1713Style"
	var/UI_style_color = "#FFFFFF"
	var/UI_style_alpha = 255
	var/cursor = "fixture cursor"
/datum/ui_fixture_client
	var/datum/ui_fixture_preferences/prefs = new
	var/mouse_pointer_icon
	var/list/screen = list()
/mob/living/human
	var/datum/ui_fixture_client/fixture_client
	var/defaultHUD = "1713Style"
	var/ui_creates = 0
	var/ui_shows = 0
	var/ui_parent_calls = 0
/mob/living/human/proc/fixture_ui_parent()
	ui_parent_calls++
	return TRUE
/mob/living/human/proc/check_HUDdatum()
	return fixture_client.prefs.UI_style in list("1713Style", "other")
/mob/living/human/proc/check_HUD_style()
	return TRUE
/mob/living/human/proc/destroy_HUD()
	HUDneed.Cut()
	HUDinventory.Cut()
/mob/living/human/proc/create_HUD()
	ui_creates++
	HUDneed["fixture"] = TRUE
	HUDinventory += TRUE
/mob/living/human/proc/show_HUD()
	ui_shows++
/mob/living/human/proc/recolor_HUD(style_color, style_alpha)
	return
/proc/check_player_ui()
	var/mob/living/human/H = new(locate(4,2,1))
	H.fixture_client = new
	var/obj/item/item = new(H)
	H.fixture_ui_login()
	check(H in human_clients_mob_list, "human Login omitted playing registry")
	check(H.ui_creates == 1 && H.HUDneed.len && H.HUDinventory.len && H.ui_shows == 1, "same-style empty HUD not rebuilt")
	check((item in H.fixture_client.screen) && H.fixture_client.mouse_pointer_icon == H.fixture_client.prefs.cursor, "human Login lost inventory screen or cursor restoration")
	H.fixture_ui_login()
	check(human_clients_mob_list.len == 1 && H.ui_creates == 1 && H.ui_shows == 2, "human reconnect duplicated registry or HUD")
	H.fixture_client.prefs.UI_style = "other"
	H.fixture_ui_login()
	check(H.defaultHUD == "other" && H.ui_creates == 2, "changed HUD style not rebuilt")
	H.fixture_client.prefs.UI_style = "invalid"
	H.fixture_ui_login()
	check(H.defaultHUD == "1713Style" && H.ui_creates == 3, "invalid HUD fallback lost")
	check(H.fixture_ui_logout() && !(H in human_clients_mob_list), "human Logout retained playing registry")
	check(H.ui_parent_calls == 5, "parent Login or Logout skipped")
	qdel(H.fixture_client.prefs)
	qdel(H.fixture_client)
	qdel(item)
	qdel(H)
