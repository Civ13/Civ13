// Fake transport records channel requests; no audible/native-client acceptance.
var/list/music_fixture_clients = list()
var/datum/music_fixture_client/music_test_client
/datum/music_fixture_preferences
	var/lobby_music_volume = 85
/datum/client_preference/play_lobby_music
/datum/music_fixture_client
	var/mob/mob
	var/datum/music_fixture_preferences/prefs = new
	var/list/sound_channels = list("778" = "unrelated ambience")
/datum/music_fixture_client/proc/is_preference_enabled(kind)
	return TRUE
/datum/music_fixture_client/proc/fixture_sound(file_value, repeat, wait, volume, channel)
	sound_channels["[channel]"] = file_value
/datum/lobby_music_player/proc/announce(datum/target)
	return
/datum/music_fixture_mind
	var/active = FALSE
/mob/living
	var/datum/music_fixture_client/music_fixture_client
	var/datum/music_fixture_mind/mind
/mob/living/proc/fixture_music_parent()
	return
/mob/living/proc/mind_initialize()
	if(!mind) mind = new
/proc/prepare_music_fixture()
	ticker = new
	ticker.login_music = "fixture song"
	ticker.current_state = GAME_STATE_PREGAME
	if(!lobby_music_player) lobby_music_player = new
	music_test_client = new
	music_fixture_clients += music_test_client
	var/mob/new_player/lobby = new
	music_test_client.mob = lobby
	music_test_client.playtitlemusic()
	check(music_test_client.sound_channels["1"] == "fixture song", "active lobby music did not play")
	for(var/restored in list(FALSE, TRUE))
		var/mob/living/human/H = new(locate(2,2,1))
		H.persistence_restored = restored
		H.music_fixture_client = music_test_client
		music_test_client.mob = H
		music_test_client.sound_channels["1"] = "fixture song"
		H.fixture_music_login()
		check(!music_test_client.sound_channels["1"], "body control retained lobby music")
		check(music_test_client.sound_channels["778"] == "unrelated ambience", "body control stopped unrelated sound")
		qdel(H.mind)
		qdel(H)
	music_test_client.mob = lobby
	ticker.current_state = GAME_STATE_PLAYING
	music_test_client.playtitlemusic()
	check(!music_test_client.sound_channels["1"], "active round replayed lobby music")
	ticker.current_state = GAME_STATE_PREGAME
	music_test_client.sound_channels["1"] = "fixture song"
/proc/check_fresh_round_music(datum/controller/gameticker/T)
	map_storage.round_restored = FALSE
	fixture_round_setup_visits = 0
	T.current_state = GAME_STATE_PREGAME
	music_test_client.sound_channels["1"] = "fixture song"
	check(T.setup(), "fresh round setup failed")
	check(!music_test_client.sound_channels["1"] && music_test_client.sound_channels["778"] == "unrelated ambience", "fresh round retained lobby music")
	qdel(music_test_client.mob)
	qdel(music_test_client.prefs)
	qdel(music_test_client)
	music_fixture_clients.Cut()
	qdel(ticker)
	ticker = null
