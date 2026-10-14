/proc/check_player_reclaim()
	var/savefile/F = new("player-owner.sav")
	F["/format_version"] << 2
	var/mob/living/human/H = new(locate(4,2,1))
	H.name = "saved character"
	H.stat = UNCONSCIOUS
	H.persistence_owner_ckey = "testaccount"
	var/obj/item/test/I = new(H)
	I.number = 813
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, H, 1)
	map_storage.clear_bookkeeping()
	var/mob/living/human/restored = map_storage.Load_Entry(F, ref, starting_loc = locate(4,2,1))
	check(restored.persistence_owner_ckey == "testaccount", "saved player owner lost")
	check(restored.stat == UNCONSCIOUS && !restored.rejuvenate_calls, "owned saved medical state changed")
	var/obj/item/test/restored_item = locate(/obj/item/test) in restored
	check(restored_item && restored_item.number == 813, "owned saved inventory changed")
	map_storage.reset_player_restoration()
	map_storage.register_restored_player(restored)
	check(!map_storage.find_restored_player("testaccount"), "player restored before load completed")
	persistence_player_restore_ready = TRUE
	check(map_storage.find_restored_player("testaccount") == restored, "unique player owner not restored")
	check(!map_storage.find_restored_player("otheraccount"), "different account received saved body")
	check(!map_storage.find_restored_player("Test Account"), "noncanonical account received saved body")
	persistence_save_in_progress = TRUE
	check(!map_storage.find_restored_player("testaccount"), "player restored during persistence operation")
	persistence_save_in_progress = FALSE
	map_storage.last_error = "failed generation"
	check(!map_storage.find_restored_player("testaccount"), "player restored after failed generation")
	map_storage.last_error = null
	restored.stat = DEAD
	check(!map_storage.find_restored_player("testaccount"), "dead player body reclaimed")
	restored.stat = UNCONSCIOUS
	restored.key = "OccupiedFixtureAccount"
	check(restored.key, "native key occupancy unavailable")
	check(!map_storage.find_restored_player("testaccount"), "occupied player body reclaimed")
	restored.key = null
	var/mob/living/human/duplicate = new(locate(5,2,1))
	duplicate.persistence_owner_ckey = "testaccount"
	map_storage.register_restored_player(duplicate)
	check(!map_storage.find_restored_player("testaccount"), "duplicate player owner accepted")
	var/list/owners = list()
	map_storage.validate_saved_player_owner(F, ref, owners)
	var/rejected = FALSE
	try
		map_storage.validate_saved_player_owner(F, ref, owners)
	catch(var/exception/e)
		rejected = TRUE
	check(rejected, "duplicate saved player ownership not rejected")
	F["[entry_path(F, ref)]/persistence_owner_ckey"] << list("kind" = "value", "value" = "Test Account")
	rejected = FALSE
	try
		map_storage.validate_saved_player_owner(F, ref, list())
	catch(var/exception/e)
		rejected = TRUE
	check(rejected, "malformed saved ownership not rejected")
	map_storage.reset_player_restoration()
	check(!map_storage.find_restored_player("testaccount"), "reset retained player body claim")
	map_storage.clear_bookkeeping()
	qdel(I)
	qdel(H)
	qdel(restored_item)
	qdel(restored)
	qdel(duplicate)
