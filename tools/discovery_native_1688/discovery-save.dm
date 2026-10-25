// Actual generic mind/list graph export and import, not a surrogate serializer.
// Current/original are detached deliberately: this does not accept saved-player
// physiology, full-world metadata, account reclaim or a real reconnect.
/proc/discovery_mind_writer()
	var/mob/living/human/H = discovery_actor(locate(2,3,1))
	var/datum/mind/M = H.mind
	M.memory = "persisted private memory"
	M.add_note("Private", "persisted role note")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/berries/tinto/B = new(get_turf(H))
	B.name = "saved sample"
	B.smell_for(H)
	discovery_check(discovery_count(M) == 1, "writer learns through the production berry smell action")
	var/list/learned = discovery_first(M)
	var/expected_observation = learned["observation"]
	H.mind = null
	M.current = null
	M.original = null
	var/datum/mind/legacy = new
	legacy.memory = "legacy private memory"
	var/savefile/F = new("discovery-mind.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/entry = map_storage.BuildVarDirectory(F, M, 1)
	var/legacy_entry = map_storage.BuildVarDirectory(F, legacy, 1)
	discovery_check(entry && legacy_entry && entry != legacy_entry, "writer exports two separate generic mind graphs")
	F.Flush()
	F = null
	text2file(json_encode(list("mind"=entry, "legacy"=legacy_entry, "observation"=expected_observation, "context"=berry_discovery_context())), "discovery-mind-entries.json")
	world.log << "DISCOVERY MIND WRITER: actual generic mind graphs flushed; body/reclaim not tested"

/proc/discovery_mind_reader()
	var/list/entries = json_decode(file2text("discovery-mind-entries.json"))
	discovery_check(islist(entries) && entries["mind"] && entries["legacy"], "reader receives the writer entry identities")
	var/savefile/F = new("discovery-mind.sav")
	map_storage.clear_bookkeeping()
	var/datum/mind/M = map_storage.Load_Entry(F, entries["mind"])
	var/datum/mind/legacy = map_storage.Load_Entry(F, entries["legacy"])
	discovery_check(istype(M, /datum/mind) && istype(legacy, /datum/mind) && M != legacy, "reader restores separate production mind datums")
	discovery_check(discovery_count(M) == 1, "reader preserves the production-saved learned discovery")
	var/list/record = discovery_first(M)
	discovery_check(record["observation"] == entries["observation"] && record["context"] == entries["context"] && record["label"] == "saved sample", "reader preserves exact learned text context and first label")
	discovery_check(M.memory == "persisted private memory" && json_encode(M.notes) == json_encode(list("Private"=list("persisted role note"))), "reader preserves private notes independently of discoveries")
	discovery_check(!discovery_count(legacy) && legacy.memory == "legacy private memory", "legacy mind without discovery field remains empty")
	discovery_check(!M.learn_discovery(record["category"], record["identity"], record["context"], "renamed after load", record["observation"]) && discovery_count(M) == 1 && record["label"] == "saved sample", "restored discovery still deduplicates renames without losing the first label")
	var/mob/living/human/H = new /mob/living/human/discovery_tester(locate(3,3,1))
	M.transfer_to(H)
	discovery_check(H.mind == M && M.current == H && discovery_count(H.mind) == 1, "restored mind can transfer to the same character body without losing knowledge")
	var/mob/living/human/fresh = discovery_actor(locate(4,3,1))
	discovery_check(!discovery_count(fresh.mind) && fresh.mind != M, "fresh character remains empty beside a restored learned mind")
	world.log << "DISCOVERY MIND READER: actual graph restored; real client/reclaim and body reconstruction not tested"

/proc/discovery_mind_roundtrip()
	discovery_mind_writer()
	discovery_mind_reader()
