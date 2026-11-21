// Armor families (padded, leather, lamellar, mail, plate) on a synthetic 6x4x1 world.
/obj/map_metadata/armor_family_fixture/New()
	return
/proc/family_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "armor_family_result.txt")
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
	return "Armor family fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "armor_family_result.txt")
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
	makeDatumRefLists()
	map = new /obj/map_metadata/armor_family_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)

	// Worked examples from the armor rework plan: cut, pierce, blunt, arrow.
	var/list/examples = list(
		/obj/item/clothing/suit/armor/ancient/linen = list(30, 21, 39, 30),
		/obj/item/clothing/suit/armor/medieval/leather = list(36, 21, 21, 27),
		/obj/item/clothing/suit/armor/samurai = list(42, 28, 32, 46),
		/obj/item/clothing/suit/armor/ancient/bronze_lamellar = list(54, 36, 41, 59),
		/obj/item/clothing/suit/armor/medieval/chainmail = list(77, 44, 28, 50),
		/obj/item/clothing/suit/armor/medieval = list(85, 85, 65, 91))
	var/list/kinds = list(HIT_CUT, HIT_PIERCE, HIT_BLUNT, "arrow")
	for(var/path in examples)
		var/obj/item/clothing/C = new path(locate(1,1,1))
		var/list/want = examples[path]
		for(var/i in 1 to kinds.len)
			family_check(C.armor_value(kinds[i]) == want[i], "[path] [kinds[i]] is [C.armor_value(kinds[i])], want [want[i]]")
		var/mean = round((want[1] + want[2] + want[3]) / 3, 1)
		family_check(C.armor_value("melee") == mean, "[path] melee is the mean of the three kinds ([C.armor_value("melee")], want [mean])")
		family_check(C.armor_value("gun") == C.armor["gun"], "[path] keeps its own gun value")
		family_check(C.armor_value("bomb") == C.armor["bomb"], "[path] keeps its own bomb value")

	// Each family's matchup: mail turns blades but not blows, padding the reverse.
	var/obj/item/clothing/mail = new /obj/item/clothing/suit/armor/medieval/hauberk(locate(1,1,1))
	family_check(mail.armor_value(HIT_CUT) > mail.armor_value(HIT_BLUNT), "mail stops cuts better than blows")
	var/obj/item/clothing/padded = new /obj/item/clothing/suit/armor/ancient/linen(locate(1,1,1))
	family_check(padded.armor_value(HIT_BLUNT) > padded.armor_value(HIT_PIERCE), "padding stops blows better than thrusts")
	var/obj/item/clothing/lamellar = new /obj/item/clothing/suit/armor/medieval/varangian(locate(1,1,1))
	family_check(lamellar.armor_value("arrow") > mail.armor_value("arrow"), "lamellar stops arrows better than mail of the same metal")

	// Every look in a family and tier protects the same, whatever culture it comes from.
	var/list/looks = list(
		list(/obj/item/clothing/suit/armor/samurai, /obj/item/clothing/suit/armor/samurai/red, /obj/item/clothing/suit/armor/samurai/blue, /obj/item/clothing/suit/armor/samurai/black),
		list(/obj/item/clothing/suit/armor/samurai/warrior, /obj/item/clothing/suit/armor/samurai/warrior/red, /obj/item/clothing/suit/armor/medieval/varangian, /obj/item/clothing/suit/armor/medieval/imperial_chinese, /obj/item/clothing/suit/armor/ancient/scale),
		list(/obj/item/clothing/suit/armor/ancient/bronze_lamellar, /obj/item/clothing/suit/armor/ancient/bronze_lamellar/chinese, /obj/item/clothing/suit/armor/ancient/scaled),
		list(/obj/item/clothing/suit/armor/medieval/chainmail, /obj/item/clothing/suit/armor/ancient/chainmail, /obj/item/clothing/suit/armor/medieval/hauberk, /obj/item/clothing/suit/armor/medieval/emirate),
		list(/obj/item/clothing/suit/armor/medieval, /obj/item/clothing/suit/armor/medieval/red, /obj/item/clothing/suit/armor/samurai/lord, /obj/item/clothing/suit/armor/samurai/lord/black))
	for(var/list/group in looks)
		var/first_path = group[1]
		var/obj/item/clothing/first = new first_path(locate(1,1,1))
		for(var/path in group)
			var/obj/item/clothing/other = new path(locate(1,1,1))
			family_check(other.slowdown == first.slowdown, "[path] is as heavy as [first.type]")
			for(var/kind in kinds)
				family_check(other.armor_value(kind) == first.armor_value(kind), "[path] [kind] matches [first.type]")

	// A worn family piece protects its wearer by kind.
	var/mob/living/human/wearer = new(locate(2,2,1))
	var/obj/item/clothing/worn = new /obj/item/clothing/suit/armor/medieval/chainmail(locate(2,2,1))
	wearer.equip_to_slot_or_del(worn, slot_wear_suit)
	family_check(wearer.wear_suit == worn, "wearer puts on chainmail")
	family_check(wearer.getarmor("chest", HIT_CUT) == 77 && wearer.getarmor("chest", HIT_BLUNT) == 28, "worn chainmail gives cut [wearer.getarmor("chest", HIT_CUT)], blunt [wearer.getarmor("chest", HIT_BLUNT)]")

	// Armor without a family reads its own list as before.
	var/obj/item/clothing/ork = new /obj/item/clothing/suit/armor/ork_grunt(locate(1,1,1))
	family_check(!ork.armor_family && ork.armor_value(HIT_CUT) == ork.armor["melee"], "unfamilied armor keeps its melee value")

	// Forging takes the tier from the metal, and a better grade lifts it.
	var/obj/item/stack/material/iron/iron = new(locate(1,1,1))
	var/obj/item/stack/material/steel/steel = new(locate(1,1,1))
	var/obj/item/clothing/iron_plate = new /obj/item/clothing/suit/armor/medieval(locate(1,1,1))
	grade_forged_armor(iron_plate, iron)
	family_check(iron_plate.armor_tier == ARMOR_TIER_IRON && iron_plate.armor_value(HIT_CUT) == 72, "plate forged from iron is iron tier (cut [iron_plate.armor_value(HIT_CUT)])")
	var/obj/item/clothing/steel_plate = new /obj/item/clothing/suit/armor/medieval(locate(1,1,1))
	grade_forged_armor(steel_plate, steel)
	family_check(steel_plate.armor_tier == ARMOR_TIER_STEEL && steel_plate.armor_value(HIT_CUT) == 85, "plate forged from steel is steel tier")
	steel_plate.armor_blow_grade = 1.1
	family_check(steel_plate.armor_value(HIT_BLUNT) == 72 && steel_plate.armor_value(HIT_CUT) == 90 && steel_plate.armor_value("arrow") == 91, "a grade lifts values up to 90 and leaves arrows to their own grade ([steel_plate.armor_value(HIT_BLUNT)]/[steel_plate.armor_value(HIT_CUT)])")

	// A padded jack under armor cushions blows and arrows only.
	var/obj/item/clothing/jack = new /obj/item/clothing/accessory/armor/padded_jack(locate(2,2,1))
	family_check(jack.armor_value(HIT_CUT) == 0 && jack.armor_value(HIT_PIERCE) == 0, "a padded jack gives nothing against cuts and thrusts")
	family_check(jack.armor_value(HIT_BLUNT) == 39 && jack.armor_value("arrow") == 15 && jack.armor_value("melee") == 13, "a padded jack gives blunt 39, arrow 15, melee 13 ([jack.armor_value(HIT_BLUNT)]/[jack.armor_value("arrow")]/[jack.armor_value("melee")])")
	var/mob/living/human/layered = new(locate(2,3,1))
	var/obj/item/clothing/under/tunic = new /obj/item/clothing/under/roman(locate(2,3,1))
	layered.equip_to_slot_or_del(tunic, slot_w_uniform)
	family_check(layered.w_uniform == tunic, "the layered wearer puts on a tunic")
	family_check(tunic.can_attach_accessory(jack), "a padded jack goes on the tunic's armor slot")
	tunic.accessories += jack
	var/obj/item/clothing/mail_over = new /obj/item/clothing/suit/armor/medieval/chainmail(locate(2,3,1))
	layered.equip_to_slot_or_del(mail_over, slot_wear_suit)
	family_check(layered.getarmor("chest", HIT_BLUNT) == 28 + 39 && layered.getarmor("chest", HIT_CUT) == 77, "mail over a padded jack gives blunt [layered.getarmor("chest", HIT_BLUNT)], cut [layered.getarmor("chest", HIT_CUT)]")
	family_check(layered.getarmor("chest", "arrow") == 50 + 15, "mail over a padded jack gives arrow [layered.getarmor("chest", "arrow")]")
	family_check(layered.armor_gap_penetration("chest", HIT_PIERCE) == ARMOR_GAP_PENETRATION, "a thrust still finds the gaps in mail over padding")
	layered.drop_from_inventory(mail_over)
	family_check(layered.armor_gap_penetration("chest", HIT_PIERCE) == 0, "padding alone has no gaps")
	// Mail on the armor slot protects as mail; plate over it closes the gaps.
	tunic.accessories -= jack
	var/obj/item/clothing/mail_under = new /obj/item/clothing/accessory/armor/chainmail(locate(2,3,1))
	tunic.accessories += mail_under
	family_check(layered.getarmor("chest", HIT_CUT) == 77, "accessory mail protects as mail (cut [layered.getarmor("chest", HIT_CUT)])")
	family_check(layered.armor_gap_penetration("chest", HIT_PIERCE) == ARMOR_GAP_PENETRATION, "a thrust finds the gaps in accessory mail")
	var/obj/item/clothing/plate_over = new /obj/item/clothing/suit/armor/medieval(locate(2,3,1))
	layered.equip_to_slot_or_del(plate_over, slot_wear_suit)
	family_check(layered.armor_gap_penetration("chest", HIT_PIERCE) == 0, "plate over mail leaves no gap")

	// Examine tells players what a piece is good and bad against.
	var/obj/item/clothing/told_mail = new /obj/item/clothing/suit/armor/medieval/chainmail(locate(1,1,1))
	var/mail_text = told_mail.armor_family_strengths()
	family_check(findtext(mail_text, "Mail:") && findtext(mail_text, "blows go through") && findtext(mail_text, "made of iron"), "chainmail examine: [mail_text]")
	var/plate_text = steel_plate.armor_family_strengths()
	family_check(findtext(plate_text, "Plate armor:") && findtext(plate_text, "made of steel"), "steel plate examine: [plate_text]")
	family_check(findtext(jack.armor_family_strengths(), "Worn under armor"), "padded jack examine: [jack.armor_family_strengths()]")
	var/obj/item/clothing/told_ork = new /obj/item/clothing/suit/armor/ork_grunt(locate(1,1,1))
	family_check(isnull(told_ork.armor_family_strengths()), "armor without a family says nothing extra")

	// Armor never goes out of date: anvil armor stays on offer in later eras.
	var/obj/structure/anvil/anvil = new(locate(3,3,1))
	var/mob/living/human/smith = new(locate(3,2,1))
	var/list/plate_row = anvil_recipes["Plated Armor"]
	var/list/lord_row = anvil_recipes["(Iron) Metal Samurai Lord Armor"]
	for(var/age in 2 to 9)
		map.ordinal_age = age
		family_check(anvil_recipe_offered(plate_row, "armor", plate_row[6]), "iron plated armor is offered in age [age]")
		family_check(anvil_recipe_offered(lord_row, "japanese armor", lord_row[6]), "iron samurai lord armor is offered in age [age]")
		family_check("armor" in anvil.stack_categories(iron, smith), "iron offers armor in age [age]")
		family_check("japanese armor" in anvil.stack_categories(steel, smith), "steel offers japanese armor in age [age]")
		family_check("armor" in anvil.stack_categories(steel, smith), "steel offers plated armor in age [age]")
	for(var/key in anvil_recipes)
		var/list/row = anvil_recipes[key]
		if(row && (row[2] in list("armor", "japanese armor", "other armor", "helmets", "other helmets", "japanese helmets", "sallet helmets")))
			family_check(row[4] >= RECIPE_OPEN_ENDED_AGE, "[key] stays craftable to the end (last age [row[4]])")

	text2file("PASS: armor families protect by construction and material and never go out of date", "armor_family_result.txt")
	del(world)
