// Dyed custom clothing across a whole-world save/load on a synthetic 6x4x1 world.
/obj/map_metadata/clothing_fixture/New()
	return
/proc/clothing_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "clothing_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Clothing fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "clothing_result.txt")
	del(world)
	sleep(1)
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/clothing_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	// Single-colour garment dyed by the player.
	var/obj/item/clothing/under/custom/toga/toga = new(locate(1,1,1))
	// Three-part dress dyed by the player.
	var/obj/item/clothing/under/customdress/dress = new(locate(2,1,1))
	// A dress an older restore already flipped back to "undyed" while it kept its colours.
	var/obj/item/clothing/under/customdress/flipped = new(locate(3,1,1))
	// A dress nobody has dyed yet.
	var/obj/item/clothing/under/customdress/blank = new(locate(4,1,1))
	// A multi-colour hat.
	var/obj/item/clothing/head/custom_off_cap/cap = new(locate(5,1,1))
	// A garment with accessories attached (verbs are not saved).
	var/obj/item/clothing/under/custom/tunic/tunic = new(locate(6,1,1))
	var/obj/item/clothing/accessory/custom/scarf/scarf = new(locate(6,1,1))
	var/obj/item/clothing/accessory/holster/holster = new(locate(6,1,1))
	for(var/obj/item/clothing/accessory/A in list(scarf, holster))
		tunic.accessories += A
		A.on_attached(tunic, null)
	tunic.verbs |= /obj/item/clothing/proc/removetie_verb
	sleep(10)
	clothing_check(toga.uncolored && dress.uncolored && blank.uncolored && cap.uncolored1, "new garments are ready to dye")
	toga.color = "#aa2200"
	toga.uncolored = FALSE
	dress.topcolor = "#112233"
	dress.undercolor = "#445566"
	dress.overcolor = "#778899"
	dress.attack_self(null)
	clothing_check(!dress.uncolored && dress.overlays.len == 3, "dress dyes with three layers ([dress.overlays.len])")
	flipped.topcolor = "#AA0000"
	flipped.undercolor = "#00AA00"
	flipped.overcolor = "#0000AA"
	flipped.attack_self(null)
	flipped.uncolored = TRUE
	cap.capcolor = "#101010"
	cap.bandcolor = "#202020"
	cap.symbolcolor = "#303030"
	cap.attack_self(null)
	clothing_check(!cap.uncolored1 && cap.overlays.len == 3, "cap dyes with three layers ([cap.overlays.len])")
	clothing_check(map_storage.Save_World(), "production whole-world export succeeds")
	clothing_check(map_storage.validate_world_save(), "production preflight accepts the save: [map_storage.last_error]")
	map_storage.ClearMap()
	clothing_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	sleep(20)
	toga = locate(/obj/item/clothing/under/custom/toga) in locate(1,1,1)
	dress = locate(/obj/item/clothing/under/customdress) in locate(2,1,1)
	flipped = locate(/obj/item/clothing/under/customdress) in locate(3,1,1)
	blank = locate(/obj/item/clothing/under/customdress) in locate(4,1,1)
	cap = locate(/obj/item/clothing/head/custom_off_cap) in locate(5,1,1)
	tunic = locate(/obj/item/clothing/under/custom/tunic) in locate(6,1,1)
	clothing_check(tunic && tunic.accessories.len == 2, "tunic keeps its two accessories")
	clothing_check((/obj/item/clothing/proc/removetie_verb in tunic.verbs), "tunic keeps Remove Accessory")
	clothing_check((/obj/item/clothing/accessory/holster/verb/holster_verb in tunic.verbs), "tunic keeps the holster verb")
	scarf = locate(/obj/item/clothing/accessory/custom/scarf) in tunic.accessories
	tunic.remove_accessory(null, scarf)
	clothing_check(scarf && !(scarf in tunic.accessories) && scarf.loc == locate(6,1,1), "a restored accessory can be removed")
	clothing_check(toga && dress && flipped && blank && cap, "garments are restored")
	clothing_check(toga.color == "#aa2200" && !toga.uncolored, "toga keeps its dye ([toga.color], uncolored=[toga.uncolored])")
	clothing_check(dress.topcolor == "#112233" && dress.undercolor == "#445566" && dress.overcolor == "#778899", "dress keeps its colours")
	clothing_check(!dress.uncolored, "dress stays dyed, so the worn sprite keeps its colours (uncolored=[dress.uncolored])")
	clothing_check(dress.overlays.len == 3, "dress keeps its coloured layers on the ground ([dress.overlays.len])")
	clothing_check(!flipped.uncolored && flipped.overlays.len == 3, "dress an older restore flipped is repaired (uncolored=[flipped.uncolored], [flipped.overlays.len] layers)")
	clothing_check(blank.uncolored && !blank.overlays.len, "undyed dress can still be dyed (uncolored=[blank.uncolored], [blank.overlays.len] layers, color [blank.color])")
	clothing_check(!cap.uncolored1 && cap.overlays.len == 3, "cap stays dyed (uncolored1=[cap.uncolored1], [cap.overlays.len] layers)")
	text2file("PASS: dyed custom clothing keeps its colours across save/load", "clothing_result.txt")
	del(world)
