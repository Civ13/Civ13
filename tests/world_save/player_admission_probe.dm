// Generated-source external-effect adapters for real production reclaim flow.
// This proves admission/claim mutation, not a real BYOND client or HUD Login.
/mob/new_player/var/datum/reclaim_client_fixture/claim_client
/datum/reclaim_client_fixture
	var/key = "FixtureAccount"
	var/ckey = "fixtureaccount"
	var/mob/mob
	var/playing_banned = FALSE
	var/server_banned = FALSE
	var/transfers = 0
/datum/reclaim_client_fixture/proc/quickBan_isbanned(kind)
	return kind == "Playing" ? playing_banned : server_banned
/proc/fixture_player_transfer(datum/reclaim_client_fixture/C, mob/living/human/H)
	C.transfers++
	C.mob = H

/proc/check_player_admission()
	map_storage.reset_player_restoration()
	persistence_player_restore_ready = TRUE
	var/mob/living/human/H = new(locate(4,2,1))
	H.persistence_owner_ckey = "fixtureaccount"
	var/obj/item/test/item = new(H)
	item.number = 914
	map_storage.register_restored_player(H)
	var/mob/new_player/lobby = new
	var/datum/reclaim_client_fixture/C = new
	C.mob = lobby
	lobby.claim_client = C
	C.playing_banned = TRUE
	check(!map_storage.reclaim_saved_player(lobby), "playing ban bypassed by reclaim")
	check(C.mob == lobby && !C.transfers && !lobby.spawning && map_storage.find_restored_player(C.ckey) == H, "playing ban changed lobby or saved claim")
	C.playing_banned = FALSE
	C.server_banned = TRUE
	check(!map_storage.reclaim_saved_player(lobby), "server ban bypassed by reclaim")
	check(C.mob == lobby && !C.transfers && map_storage.find_restored_player(C.ckey) == H, "server ban changed saved claim")
	C.server_banned = FALSE
	C.key = "Guest-123"
	check(!map_storage.reclaim_saved_player(lobby), "guest client reclaimed registered body")
	check(C.mob == lobby && !C.transfers && map_storage.find_restored_player(C.ckey) == H, "guest rejection consumed saved claim")
	C.key = "FixtureAccount"
	check(map_storage.reclaim_saved_player(lobby), "eligible client did not reclaim body")
	check(C.mob == H && C.transfers == 1 && !map_storage.find_restored_player(C.ckey), "reclaim did not reserve and transfer exactly once")
	check(item.loc == H && item.number == 914, "reclaim transfer changed physical inventory")
	map_storage.reset_player_restoration()
	qdel(item)
	qdel(H)
	qdel(C)
