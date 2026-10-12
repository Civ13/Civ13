// Opt-in disposable full-game adapter. Never included by production civ13.dme.
var/global/datum/extraction_playable_area/extraction_playable_area = new

/world/OpenPort(port)
	if (!world.params["visual"] && port != "none") return FALSE
	return ..()

/world/Export()
	// A local capture has no authorization for outbound service traffic.
	return null

/datum/extraction_playable_area
	var/ready = FALSE
	New()
		if (!world.params["visual"]) world.OpenPort("none")
		if (config)
			config.webhook_can_fire = FALSE
			config.ToRban = FALSE
		spawn(200)
			prepare()
	proc/prepare()
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(M) || !M.ensure_round())
			world.log << "EXTRACTION PLAYABLE AREA FAILED: map or journal unavailable"
			return
		ready = TRUE
		text2file(json_encode(list("commit" = world.params["tested_commit"], "byond" = "[world.byond_version].[world.byond_build]", "map" = M.ID, "dimensions" = list(world.maxx, world.maxy, world.maxz), "houses" = extraction_house_markers.len, "network_port" = world.port, "storage" = M.accounts.store.root, "outbound_export" = "disabled", "fixture" = "native connected actions; optional labeled setup supplies")), "extraction-area-ready.json")
		if (!world.params["visual"]) del(world)

/client/verb/enter_extraction_playable_area()
	set category = "Local Verification"
	set name = "Enter extraction test world"
	if (!extraction_playable_area.ready || findtext(ckey, "guest") == 1) return
	var/obj/map_metadata/extraction_survival/M = map
	var/mob/living/human/current = mob
	if (istype(current) && current.extraction_session) return
	src << browse(null, "window=playersetup")
	var/mob/living/human/H = new(locate(48,48,3))
	H.name = "Local tester [ckey]"
	H.real_name = H.name
	mob = H
	if (!M.admit(H))
		to_chat(H, "Local admission failed; inspect the isolated runtime logs.")
		return
	to_chat(H, "DISPOSABLE LOCAL TEST: commit [world.params["tested_commit"]]. Your actual connected account owns this room. House interactions, payment, action waits and account storage use production procedures. Optional fixture supplies are explicitly labeled test setup.")

/client/verb/extraction_fixture_supplies()
	set category = "Local Verification"
	set name = "Add labeled fixture workshop parts"
	var/mob/living/human/H = mob
	var/obj/map_metadata/extraction_survival/M = map
	if (!extraction_playable_area.ready || !istype(H) || !M.owned(H) || H.extraction_session.profile["state"] != "home") return
	if (!H.Adjacent(H.extraction_session.house)) return
	var/answer = alert(H, "Test setup only: place 10 workshop parts in this private room? These are injected supplies, not gameplay-earned loot.", "Disposable fixture", "Cancel", "Add fixture parts")
	if (answer != "Add fixture parts" || !M.owned(H) || H.extraction_session.profile["state"] != "home" || !H.Adjacent(H.extraction_session.house)) return
	for (var/i in 1 to 10)
		var/obj/item/extraction_salvage/I = new(get_turf(H.extraction_session.house))
		I.desc = "Injected disposable fixture workshop part. Not gameplay-earned loot."
	to_chat(H, "TEST SETUP: injected 10 workshop parts. Native upgrade and supply payment remain unchanged.")
