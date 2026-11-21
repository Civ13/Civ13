// Starting clothes on lands with peoples (origins.dm).
//
// A new nomad is dressed like the people of their birthplace, in what that
// people wore in the world's current era. Every outfit is plain everyday
// clothing made of hide, leaves or cloth: no armour, tools or storage, so the
// starting kit never hands out technology the world has not reached.
//
// Each people has a dress style. A style maps eras to an outfit with the keys
// of era_pick() ("N" for exactly era N, "N+" for era N and later). Eras a style
// does not cover use the common styles at the bottom of the table. An outfit
// maps a slot to a type or to a list to pick from (null entries mean "nothing
// in that slot" some of the time). "under_f", "head_f" and "shoes_f" replace
// "under", "head" and "shoes" for women.
//
// Coats, fur boots and the desert sun robe come from the climate in
// give_clothes(), so shoes here are skipped in cold places.

// People (origin id) -> dress style.
/proc/origin_dress_styles()
	var/static/list/styles = list(
		"northmen" = "northern", "fjordfolk" = "northern",
		"hearthlanders" = "mediterranean", "isleborn" = "mediterranean",
		"dunefolk" = "desert", "grasslanders" = "east_african", "mistwood" = "japanese",
		"gaels" = "celtic",
		"latins" = "mediterranean", "hellenes" = "mediterranean",
		"egyptians" = "desert", "arabs" = "desert", "persians" = "desert",
		"swahili" = "east_african",
		"zulu" = "southern_african",
		"han" = "chinese", "koreans" = "chinese",
		"yamato" = "japanese",
		"viet" = "vietnamese",
		"mongols" = "steppe",
		"inuit" = "arctic",
		"cherokee" = "north_american", "sioux" = "north_american", "navajo" = "north_american",
		"aztecs" = "mesoamerican", "maya" = "mesoamerican",
		"inca" = "andean",
		"tupi" = "rainforest", "caribs" = "rainforest")
	return styles

// Dress style -> era -> outfit.
/proc/spawn_outfit_table()
	var/static/list/table = null
	if (!table)
		// Stone Age hides and leaves, shared by several styles.
		var/list/hide = list("under" = /obj/item/clothing/under/loinleather)
		var/list/leaves = list("under" = /obj/item/clothing/under/leaves_skirt, "under_f" = /obj/item/clothing/under/leaves_skirt/long)
		var/list/buckskin = list("under" = /obj/item/clothing/under/indian1, "under_f" = /obj/item/clothing/under/indian3)
		// Medieval Europe: plain tunic, or a dress and kerchief.
		var/list/medieval_tunic = list(
			"under" = list(/obj/item/clothing/under/medieval/red, /obj/item/clothing/under/medieval/green, /obj/item/clothing/under/medieval/blue, /obj/item/clothing/under/medieval/yellow),
			"under_f" = /obj/item/clothing/under/civf3, "head_f" = /obj/item/clothing/head/kerchief,
			"shoes" = /obj/item/clothing/shoes/leather)
		var/list/desert_robes = list(
			"under" = list(/obj/item/clothing/under/medieval/arab1, /obj/item/clothing/under/medieval/arab2, /obj/item/clothing/under/medieval/arab3),
			"head" = list(null, /obj/item/clothing/head/keffiyeh, /obj/item/clothing/head/turban),
			"shoes" = /obj/item/clothing/shoes/sandal/leather)
		var/list/hanfu = list(
			"under" = list(/obj/item/clothing/under/hanfu, /obj/item/clothing/under/hanfu/light),
			"shoes" = /obj/item/clothing/shoes/sandal)
		var/list/mesoamerican = list(
			"under" = list(/obj/item/clothing/under/mayan_loincloth, /obj/item/clothing/under/aztec_loincloth),
			"under_f" = list(/obj/item/clothing/under/halfhuipil, /obj/item/clothing/under/huipil),
			"shoes" = /obj/item/clothing/shoes/sandal)
		table = list(
			"northern" = list(
				"0" = hide,
				"1" = list("under" = /obj/item/clothing/under/celtic_long_braccae, "shoes" = /obj/item/clothing/shoes/leather),
				"2" = list("under" = /obj/item/clothing/under/medieval/leather, "under_f" = /obj/item/clothing/under/civf3, "head_f" = /obj/item/clothing/head/kerchief, "shoes" = /obj/item/clothing/shoes/leather)),
			"celtic" = list(
				"0" = hide,
				"1" = list("under" = list(/obj/item/clothing/under/celtic_short_braccae, /obj/item/clothing/under/celtic_red, /obj/item/clothing/under/celtic_green, /obj/item/clothing/under/celtic_blue), "shoes" = /obj/item/clothing/shoes/leather),
				"2" = list("under" = /obj/item/clothing/under/medieval/kilt, "under_f" = /obj/item/clothing/under/civf3, "head_f" = /obj/item/clothing/head/kerchief, "shoes" = /obj/item/clothing/shoes/leather)),
			"mediterranean" = list(
				"0" = hide,
				"1" = list("under" = list(/obj/item/clothing/under/medieval/lighttunic, /obj/item/clothing/under/toga2), "shoes" = /obj/item/clothing/shoes/sandal),
				"2" = medieval_tunic),
			"desert" = list(
				"0" = hide,
				"1" = list("under" = list(/obj/item/clothing/under/loincotton, /obj/item/clothing/under/medieval/lighttunic), "under_f" = /obj/item/clothing/under/medieval/lighttunic, "shoes" = /obj/item/clothing/shoes/sandal),
				"2" = desert_robes, "3" = desert_robes, "4" = desert_robes),
			"east_african" = list(
				"0" = leaves,
				"1" = list("under" = /obj/item/clothing/under/loincotton, "under_f" = /obj/item/clothing/under/medieval/lighttunic, "shoes" = /obj/item/clothing/shoes/sandal),
				"2" = list("under" = list(/obj/item/clothing/under/medieval/arab2, /obj/item/clothing/under/medieval/lighttunic), "shoes" = /obj/item/clothing/shoes/sandal)),
			"southern_african" = list(
				"0" = list("under" = /obj/item/clothing/under/zulu_slene),
				"1" = list("under" = /obj/item/clothing/under/zulu_slene),
				"2" = list("under" = /obj/item/clothing/under/zulu_slene, "shoes" = /obj/item/clothing/shoes/sandal)),
			"chinese" = list(
				"0" = hide,
				"1" = list("under" = /obj/item/clothing/under/hanfu/light, "shoes" = /obj/item/clothing/shoes/sandal),
				"2" = hanfu, "3" = hanfu, "4" = hanfu),
			"japanese" = list(
				"0" = hide,
				"1" = list("under" = /obj/item/clothing/under/kimono, "shoes" = /obj/item/clothing/shoes/geta),
				"2" = list("under" = list(/obj/item/clothing/under/haori, /obj/item/clothing/under/haori/blue, /obj/item/clothing/under/haori/red), "under_f" = /obj/item/clothing/under/kimono, "shoes" = /obj/item/clothing/shoes/geta),
				"3" = list("under" = list(/obj/item/clothing/under/haori, /obj/item/clothing/under/haori/blue, /obj/item/clothing/under/haori/red), "under_f" = /obj/item/clothing/under/kimono, "shoes" = /obj/item/clothing/shoes/geta)),
			"vietnamese" = list(
				"0" = leaves,
				"1" = list("under" = /obj/item/clothing/under/loincotton, "head" = /obj/item/clothing/head/rice_hat),
				"2" = list("under" = /obj/item/clothing/under/hanfu/light, "head" = /obj/item/clothing/head/rice_hat, "shoes" = /obj/item/clothing/shoes/sandal),
				"3" = list("under" = /obj/item/clothing/under/hanfu/light, "head" = /obj/item/clothing/head/rice_hat, "shoes" = /obj/item/clothing/shoes/sandal)),
			"steppe" = list(
				"0" = hide,
				"1" = list("under" = /obj/item/clothing/under/medieval/steppe_tunic, "shoes" = /obj/item/clothing/shoes/leather),
				"2" = list("under" = /obj/item/clothing/under/medieval/steppe_tunic, "head" = list(null, /obj/item/clothing/head/furcap), "shoes" = /obj/item/clothing/shoes/leather),
				"3" = list("under" = /obj/item/clothing/under/medieval/steppe_tunic, "head" = list(null, /obj/item/clothing/head/furcap), "shoes" = /obj/item/clothing/shoes/leather)),
			"arctic" = list(
				"0" = list("under" = /obj/item/clothing/under/indian3),
				"1" = list("under" = /obj/item/clothing/under/indian3, "head" = /obj/item/clothing/head/furcap),
				"2" = list("under" = /obj/item/clothing/under/indian3, "head" = /obj/item/clothing/head/furcap),
				"3" = list("under" = /obj/item/clothing/under/indian3, "head" = /obj/item/clothing/head/furcap)),
			"north_american" = list(
				"0" = buckskin,
				"1" = list("under" = /obj/item/clothing/under/indian2, "under_f" = /obj/item/clothing/under/indian3, "shoes" = /obj/item/clothing/shoes/leather),
				"2" = list("under" = /obj/item/clothing/under/indian2, "under_f" = /obj/item/clothing/under/indian3, "shoes" = /obj/item/clothing/shoes/leather),
				"3" = list("under" = /obj/item/clothing/under/indian2, "under_f" = /obj/item/clothing/under/indian3, "shoes" = /obj/item/clothing/shoes/leather)),
			"mesoamerican" = list(
				"0" = buckskin,
				"1" = mesoamerican, "2" = mesoamerican, "3" = mesoamerican),
			"andean" = list(
				"0" = buckskin,
				"1" = list("under" = /obj/item/clothing/under/medieval/lighttunic, "shoes" = /obj/item/clothing/shoes/sandal),
				"2" = list("under" = /obj/item/clothing/under/medieval/lighttunic, "shoes" = /obj/item/clothing/shoes/sandal),
				"3" = list("under" = /obj/item/clothing/under/medieval/lighttunic, "shoes" = /obj/item/clothing/shoes/sandal)),
			"rainforest" = list(
				"0" = leaves, "1" = leaves,
				"2" = list("under" = /obj/item/clothing/under/loincotton, "under_f" = /obj/item/clothing/under/leaves_skirt/long),
				"3" = list("under" = /obj/item/clothing/under/loincotton, "under_f" = /obj/item/clothing/under/halfhuipil)),
			// Everyone, for eras their own style does not cover.
			"common" = list(
				"0" = hide,
				"1" = list("under" = /obj/item/clothing/under/medieval/lighttunic, "shoes" = /obj/item/clothing/shoes/sandal),
				"2" = medieval_tunic,
				"3" = list("under" = /obj/item/clothing/under/civ2, "head" = list(null, null, null, null, /obj/item/clothing/head/tricorne_black),
					"under_f" = /obj/item/clothing/under/civf1, "head_f" = /obj/item/clothing/head/kerchief, "shoes" = /obj/item/clothing/shoes/leatherboots),
				"4" = list("under" = /obj/item/clothing/under/industrial3, "under_f" = /obj/item/clothing/under/civf1, "head_f" = /obj/item/clothing/head/kerchief,
					"shoes" = /obj/item/clothing/shoes/leatherboots),
				"5+" = list("under" = /obj/item/clothing/under/modern4, "under_f" = /obj/item/clothing/under/civf1,
					"shoes" = /obj/item/clothing/shoes/leatherboots, "shoes_f" = /obj/item/clothing/shoes/sandal),
				"8+" = list("under" = /obj/item/clothing/under/modern7, "under_f" = /obj/item/clothing/under/civf1,
					"shoes" = /obj/item/clothing/shoes/leatherboots, "shoes_f" = /obj/item/clothing/shoes/sandal)))
	return table

// The outfit for a people in the current era: their own style, else the common one.
/proc/spawn_outfit_for(origin_id)
	var/list/table = spawn_outfit_table()
	var/list/styles = origin_dress_styles()
	// A people that formed in play dresses like its root people (peoples.dm).
	var/datum/origin/root = origin_root(origin_by_id(origin_id))
	var/list/style = table[styles[root ? root.id : origin_id]]
	var/list/outfit = style ? era_pick(style) : null
	if (!outfit)
		outfit = era_pick(table["common"], table["common"]["0"])
	return outfit

// The places where give_clothes() hands out a coat and fur boots.
/proc/spawn_area_is_cold(area/A)
	if (map && map.ID == MAP_NOMADS_ICE_AGE)
		return TRUE
	if (!A)
		return FALSE
	return A.climate == "tundra" || A.climate == "taiga" || (A.climate == "temperate" && season == SEASON_WINTER)

// Dress a new nomad on a land with peoples, by the people of the place they
// stand on (the player may still pick another people afterwards).
/mob/living/human/proc/give_land_clothes(area/A)
	var/datum/origin/O = get_origin()
	if (!O && map)
		O = land_origin_for(map.ID, A ? A.climate : null)
	var/list/outfit = spawn_outfit_for(O ? O.id : null)
	if (!outfit)
		return FALSE
	var/female = (gender == "female")
	var/list/slots = list("under" = slot_w_uniform, "head" = slot_head, "shoes" = slot_shoes)
	for (var/key in slots)
		var/choice = (female && ("[key]_f" in outfit)) ? outfit["[key]_f"] : outfit[key]
		if (islist(choice))
			var/list/options = choice
			choice = options.len ? pick(options) : null
		if (!ispath(choice, /obj/item/clothing))
			continue
		// Fur boots come with the coat in cold places.
		if (key == "shoes" && spawn_area_is_cold(A))
			continue
		equip_to_slot_or_del(new choice(src), slots[key])
	// Coins as before: from the first era on, except the medieval one.
	if (map && map.ordinal_age >= 1 && map.ordinal_age != 2)
		give_starting_copper_coins()
	update_icons(1)
	return TRUE
