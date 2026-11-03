#define TRUE 1
#define FALSE 0
#define SPAN_WARNING(T) T
#define SPAN_NOTICE(T) T
#define DEFAULT_CLIENT_FPS 100
/world
	maxx = 1
	maxy = 1
	maxz = 1
	visibility = 0
	hub = ""
	hub_password = ""
var/list/keybinding_failures = list()
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return 0
/world/IsBanned(key, address, computer_id, type, real_bans_only)
	return TRUE
/world/Error(exception/e)
	world.log << "FAIL runtime: [e] [e.file]:[e.line]"
	del(world)
/proc/isemptylist(list/L)
	return !islist(L) || !L.len
/proc/dd_hassuffix(text, suffix)
	return copytext(text, length(text) - length(suffix) + 1) == suffix
/proc/sanitize_client_fps(value)
	return value
/proc/get_trait_selection_error(list/traits)
	return null
/proc/to_chat(target, text)
	return
/proc/capitalize(text)
	return text
/proc/random_name(gender, species)
	return "Tester"
/datum/preferences
	var/datum/keybinding_client/client
	var/client_ckey = "keybinding_test"
	var/real_name = "Tester"
	var/client_fps = 100
	var/list/traits = list()
	var/list/preferences_disabled = list()
	var/list/preferences_enabled = list()
	var/gender
	var/species
/datum/preferences/proc/update_setup()
	return
/datum/keybinding_client
	var/key = "keybinding_test"
	var/datum/preferences/prefs
	var/list/controls = list()
/datum/keybinding_client/proc/apply_client_fps_preference()
	return
/proc/record_winset(datum/keybinding_client/C, id, list/params)
	var/list/old = C.controls[id]
	if (!old)
		old = list()
		C.controls[id] = old
	for (var/key in params)
		old[key] = params[key]
/proc/check(value, message)
	if (!value)
		keybinding_failures += message
/world/New()
	OpenPort("none")
	check(port == 0 && byond_version == 516 && byond_build == 1688, "pin and closed port")
	var/datum/preferences/P = new
	var/datum/keybinding_client/C = new
	P.client = C
	C.prefs = P
	var/list/defaults = P.action_keybinding_map(list())
	check(defaults && defaults.len == 26, "all defaults")
	check(!P.set_action_keybinding("hotkeymode", "prone", "J"), "conflict rejected")
	check(!P.action_keybindings.len, "rejected edit preserves preferences")
	check(P.set_action_keybinding("hotkeymode", "prone", "K"), "prone rebind")
	check(P.set_action_keybinding("hotkeymode", "aim", "NONE"), "unbind aliases")
	check(P.set_action_keybinding("macro", "aim", "CTRL+K"), "typing mode independent")
	check(!P.set_action_keybinding("macro", "prone", "K"), "typing text reserved")
	check(!P.set_action_keybinding("macro", "prone", "SHIFT+K"), "uppercase typing reserved")
	check(!P.set_action_keybinding("hotkeymode", "prone", "CTRL+W"), "movement family reserved")
	check(!P.set_action_keybinding("hotkeymode", "prone", "CTRL+Z"), "held family reserved")
	check(!P.set_action_keybinding("hotkeymode", "prone", "CTRL+F"), "fixed macro reserved")
	check(!P.set_action_keybinding("hotkeymode", "prone", "K;command=.quit"), "command injection rejected")
	C.apply_action_keybindings()
	check(C.controls.len == 52, "bounded skin slots")
	check(C.controls["hotkeymode.action_prone_1"]["name"] == "K", "rebound skin name")
	check(C.controls["hotkeymode.action_prone_2"]["is-disabled"] == "true", "unused alias disabled")
	check(C.controls["hotkeymode.action_aim_1"]["is-disabled"] == "true" && C.controls["hotkeymode.action_aim_2"]["is-disabled"] == "true", "all unbound aliases disabled")
	check(C.controls["macro.action_aim_1"]["name"] == "CTRL+K", "typing skin name")
	P.save_preferences()
	var/datum/preferences/Q = new
	var/datum/keybinding_client/D = new
	Q.client = D
	D.prefs = Q
	check(Q.load_preferences(), "production text save round trip")
	check(jointext(P.action_keybindings, "|") == jointext(Q.action_keybindings, "|"), "saved overrides round trip")
	check(D.controls["hotkeymode.action_prone_1"]["name"] == "K", "loaded skin installation")
	check(Q.set_action_keybinding("hotkeymode", "aim", "J"), "rebind after load")
	check(Q.set_action_keybinding("hotkeymode", "prone", "NONE"), "free assigned key")
	check(Q.set_action_keybinding("hotkeymode", "aim", ","), "assign freed default")
	check(!Q.set_action_keybinding("hotkeymode", "prone", null), "restore conflict rejected")
	check(Q.set_action_keybinding("hotkeymode", "aim", null), "restore aim aliases")
	check(Q.set_action_keybinding("hotkeymode", "prone", null), "restore prone default")
	for (var/bad in list(list("unknown/prone/K"), list("macro/unknown/K"), list("macro/aim/W"), list("macro/aim/CTRL+K", "macro/aim/CTRL+L"), list("hotkeymode/prone/J"), list(12), list("macro/aim/CTRL+K/extra")))
		Q.action_keybindings = bad
		Q.sanitize_action_keybindings()
		check(!Q.action_keybindings.len, "malformed save resets defaults: [jointext(bad, ",")]")
	Q.action_keybindings = list()
	D.apply_action_keybindings()
	check(D.controls["hotkeymode.action_aim_1"]["name"] == "J" && D.controls["hotkeymode.action_aim_2"]["name"] == "CTRL+J", "restore alias skin names")
	check(D.controls["hotkeymode.action_prone_1"]["name"] == ",", "restore original prone skin")
	check(D.controls["macro.action_aim_1"]["is-disabled"] == "true", "restore empty mode")
	if (keybinding_failures.len)
		world.log << "FAIL action keybindings: [jointext(keybinding_failures, "; ")]"
		del(world)
		return
	world.log << "PASS action keybindings: defaults, conflicts, rebinding, unbinding, aliases, mode isolation, skin updates, production text save/load, malformed saves"
	del(world)
	return
