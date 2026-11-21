// Melee hit kinds (cut, pierce, blunt) on a synthetic 6x4x1 world.
/obj/map_metadata/hit_kind_fixture/New()
	return
/obj/item/clothing/suit/armor/hit_kind_fixture
	name = "fixture cuirass"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 0, arrow = 0, gun = 0, energy = 0, bomb = 0, bio = 0, rad = 0)
/proc/kind_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "hit_kind_result.txt")
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
	return "Hit kind fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "hit_kind_result.txt")
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
	map = new /obj/map_metadata/hit_kind_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)

	// Kind from flags: edge cuts, a point pierces, the rest is blunt.
	kind_check(hit_kind_for(TRUE, TRUE) == HIT_CUT, "sharp and edged is a cut")
	kind_check(hit_kind_for(FALSE, TRUE) == HIT_CUT, "edged is a cut")
	kind_check(hit_kind_for(TRUE, FALSE) == HIT_PIERCE, "pointed is a pierce")
	kind_check(hit_kind_for(FALSE, FALSE) == HIT_BLUNT, "neither is blunt")

	// Real weapons, including the overrides for wrong flags.
	var/list/expected = list(
		/obj/item/weapon/material/sword = HIT_CUT,
		/obj/item/weapon/material/sword/longsword = HIT_CUT,
		/obj/item/weapon/material/sword/rapier = HIT_PIERCE,
		/obj/item/weapon/material/spear = HIT_PIERCE,
		/obj/item/weapon/material/spear/sarissa/pike = HIT_PIERCE,
		/obj/item/weapon/material/spear/halberd = HIT_CUT,
		/obj/item/weapon/material/spear/naginata = HIT_CUT,
		/obj/item/weapon/material/pike = HIT_PIERCE,
		/obj/item/weapon/material/javelin = HIT_PIERCE,
		/obj/item/weapon/attachment/bayonet = HIT_PIERCE,
		/obj/item/weapon/attachment/bayonet/flag = HIT_BLUNT,
		/obj/item/weapon/melee/mace = HIT_BLUNT,
		/obj/item/weapon/melee/classic_baton/club = HIT_BLUNT,
		/obj/item/weapon/material/tes13/mace = HIT_BLUNT)
	var/list/weapons = list()
	for(var/path in expected)
		var/obj/item/W = new path(locate(1,1,1))
		weapons[path] = W
		kind_check(W.get_hit_kind() == expected[path], "[path] hits as [expected[path]], got [W.get_hit_kind()]")

	// Armor without per-kind values protects as its melee value; a kind value wins.
	kind_check(armor_rating(list(melee = 40), HIT_CUT) == 40, "cut falls back to melee")
	kind_check(armor_rating(list(melee = 40), HIT_PIERCE) == 40, "pierce falls back to melee")
	kind_check(armor_rating(list(melee = 40), HIT_BLUNT) == 40, "blunt falls back to melee")
	kind_check(armor_rating(list(melee = 40, blunt = 10), HIT_BLUNT) == 10, "a blunt value wins over melee")
	kind_check(armor_rating(list(melee = 40, blunt = 10), HIT_CUT) == 40, "a blunt value leaves cut on melee")
	kind_check(armor_rating(list(melee = 40), "arrow") == 0, "other keys never fall back to melee")
	kind_check(armor_rating(null, HIT_CUT) == 0, "no armor list protects nothing")

	// Worn armor without a family protects as its melee value against every kind.
	var/list/worn = list(/obj/item/clothing/suit/armor/ork_grunt, /obj/item/clothing/suit/armor/darkplate,
		/obj/item/clothing/suit/armor/scrap, /obj/item/clothing/suit/armor/creed)
	var/mob/living/human/wearer = new(locate(2,2,1))
	for(var/path in worn)
		var/obj/item/clothing/suit = new path(locate(2,2,1))
		wearer.equip_to_slot_or_del(suit, slot_wear_suit)
		kind_check(wearer.wear_suit == suit, "wearer puts on [path]")
		var/old = wearer.getarmor("chest", "melee")
		kind_check(old > 0, "[path] has melee armor on the chest")
		for(var/kind in list(HIT_CUT, HIT_PIERCE, HIT_BLUNT))
			kind_check(wearer.getarmor("chest", kind) == old, "[path] gives [kind] [wearer.getarmor("chest", kind)], melee [old]")
		kind_check(wearer.getarmor(null, HIT_BLUNT) == wearer.getarmor(null, "melee"), "[path] whole-body blunt equals melee")
		wearer.drop_from_inventory(suit)
		qdel(suit)

	// A weapon hit is resisted by the armor value for its own kind.
	var/mob/living/human/target = new(locate(4,2,1))
	var/mob/living/human/attacker = new(locate(3,2,1))
	var/obj/item/clothing/suit/armor/hit_kind_fixture/cuirass = new(locate(4,2,1))
	target.equip_to_slot_or_del(cuirass, slot_wear_suit)
	kind_check(target.wear_suit == cuirass, "target wears the fixture cuirass")
	var/list/attacks = list(/obj/item/weapon/material/sword = HIT_CUT, /obj/item/weapon/material/spear = HIT_PIERCE,
		/obj/item/weapon/melee/mace = HIT_BLUNT)
	for(var/stop_kind in attacks)
		var/blocked_kind = attacks[stop_kind]
		cuirass.armor = list(melee = 0, cut = 0, pierce = 0, blunt = 0, arrow = 0, gun = 0, energy = 0, bomb = 0, bio = 0, rad = 0)
		cuirass.armor[blocked_kind] = 100
		for(var/path in attacks)
			var/obj/item/W = weapons[path]
			var/stopped = attacks[path] == blocked_kind
			for(var/i in 1 to 5)
				target.rejuvenate()
				var/before = target.getBruteLoss()
				var/blocked = target.hit_with_weapon(W, attacker, 10, "chest")
				if(stopped)
					kind_check(blocked == 2, "[blocked_kind] armor stops [path] (blocked [blocked])")
					kind_check(target.getBruteLoss() == before, "[path] does no damage through [blocked_kind] armor")
				else
					kind_check(blocked == 0, "[blocked_kind] armor does not stop [path] (blocked [blocked])")

	text2file("PASS: hits have a kind, armor resists each kind and falls back to its melee value", "hit_kind_result.txt")
	del(world)
