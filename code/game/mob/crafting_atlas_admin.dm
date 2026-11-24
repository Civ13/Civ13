// Admin-only section of the Crafting Atlas: things staff deliberately leave
// out of every public reference (the generated UI/crafting-atlas.json, the
// published web atlas and the wiki). Entries are built at runtime from the type
// itself, so nothing listed here is ever written to a generated or published file.
// scripts/atlas/admin_only.py reads this list and fails the atlas build if any
// listed type, or a subtype of one, reaches the public catalog.
//
// Add a type here on purpose, with a short note for other staff. Keep the
// note about why it stays out of the public atlas, not how to find or use it.
// An entry covers the type and every named subtype; the nearest listed
// ancestor's note applies.
var/global/list/crafting_atlas_admin_only = list(
	/obj/structure/practice_lesson_board = "Dedicated tutorial region lesson fixture; not available as a Nomads buildable.",
	/obj/structure/practice_workshop_desk = "Dedicated tutorial region workshop fixture; not available as a Nomads buildable.",
	/obj/structure/practice_stores = "Dedicated tutorial region materials store; not available as a Nomads buildable.",
	/obj/item/weapon/book/divine = "A god's own book. Hidden divine mechanic; only an admin verb writes the original.",
	/obj/item/cursedtreasure = "Cursed loot. Its effect is a discovery for players.",
	/obj/item/weapon/moldy_ritual = "Event summoning scroll. Its effect is a discovery for players.",
	// Integrated circuits, code/modules/wiremod/: the circuit and compact remote are crafted
	// from electronics; components exist only inside a circuit's editor.
	/obj/item/circuit_component = "Made in a circuit's editor, not crafted on its own.",
	// Magic, code/modules/magic/: anything not available on Nomads stays out of the public atlas.
	// The atlas build fails if a magic type is not covered here.
	/mob/living/simple_animal/golden_gnat = "Wizard Boy map only; not available on Nomads.",
	/mob/living/simple_animal/hostile/wizard = "Wizard Boy map only; not available on Nomads.",
	/mob/living/simple_animal/wizard = "Wizard Boy map only; not available on Nomads.",
	/obj/item/clothing/head/custodian_helmet = "Wizard Boy map only; not available on Nomads.",
	/obj/item/clothing/head/wizard = "Wizard Boy map only; not available on Nomads.",
	/obj/item/clothing/suit/chameleon_mac = "Wizard Boy map only; not available on Nomads.",
	/obj/item/clothing/suit/storage/jacket/wizard = "Wizard Boy map only; not available on Nomads.",
	/obj/item/clothing/under/civ2/wizard = "Wizard Boy map only; not available on Nomads.",
	/obj/item/vehicleparts/wheel/handle/mop_handle = "Wizard Boy map only; not available on Nomads.",
	/obj/item/wand_part = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/basketball/mopball = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/book/manual/dark_arts = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/book/manual/potions = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/book/manual/student_handbook = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/book/manual/wand_components = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/book/manual/wand_crafting = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/dead_zone_battery = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/magic_id = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/material/magic = "Magic wands: Wizard Boy and a few other maps; not available on Nomads.",
	/obj/item/weapon/material/sword/magic = "Magic blades: a few other maps and roles; not available on Nomads.",
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/green_goop = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/not_butter_beer = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/reagent_containers/food/drinks/bottle/welsh_rum = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/reagent_containers/food/snacks/chocotoad = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/reagent_containers/food/snacks/ditch_weed = "Wizard Boy map only; not available on Nomads.",
	/obj/item/weapon/storage/tesco_bag = "Wizard Boy map only; not available on Nomads.",
	/obj/structure/magic = "Wizard Boy map only; not available on Nomads.",
	/obj/structure/moldymen_lever = "Wizard Boy map only; not available on Nomads.",
	/obj/structure/sign/crest = "Wizard Boy map only; not available on Nomads.",
	/obj/structure/sign/house_points = "Wizard Boy map only; not available on Nomads.",
	/obj/structure/vehicle/magic = "Wizard Boy map only; not available on Nomads.",
	/obj/structure/vending/sales/wands = "Wizard Boy map only; not available on Nomads.",
	/obj/structure/vending/sales/wizards = "Wizard Boy map only; not available on Nomads.",
	/obj/effect/magic_light_effect = "Spell effect; Wizard Boy map only.",
	/obj/effect/null_zone = "Spell effect; Wizard Boy map only.",
	/datum/chemical_reaction/wizard_boy_recipe = "Wizard Boy reaction; reacts only on that map.",
	/datum/reagent/drink/not_butter_beer = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/drink/green_goop = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/drink/welsh_rum = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/skele_bones = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/darkness_powder = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/toad_mixture = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/liquid_gamble = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/heartthrob_syrup = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/polysoup_paste = "Wizard Boy map only; not available on Nomads.",
	/datum/reagent/pepup_juice = "Wizard Boy map only; not available on Nomads.")

/proc/crafting_atlas_admin_reader(mob/viewer)
	return viewer && viewer.client && check_rights(R_ADMIN, FALSE, viewer)

// The nearest listed ancestor (or the type itself) covering a type; null if none.
/proc/crafting_atlas_admin_root(typepath)
	var/root
	for (var/listed in crafting_atlas_admin_only)
		if (ispath(typepath, listed) && (!root || ispath(listed, root)))
			root = listed
	return root

// The covered type a reader may open; null for every non-admin reader or unknown id.
/proc/crafting_atlas_admin_type(mob/viewer, resource_id)
	if (!istext(resource_id) || !crafting_atlas_admin_reader(viewer))
		return null
	var/typepath = text2path(resource_id)
	if (!typepath || !crafting_atlas_admin_root(typepath))
		return null
	return typepath

// Every named type the list covers, in list order without repeats.
/proc/crafting_atlas_admin_types()
	var/static/list/covered
	if (!covered)
		covered = list()
		for (var/listed in crafting_atlas_admin_only)
			for (var/typepath in typesof(listed))
				if (crafting_atlas_admin_name(typepath) && !(typepath in covered))
					covered += typepath
	return covered

// Things, reagents and reactions keep their own name and examine text.
/proc/crafting_atlas_admin_name(typepath)
	if (ispath(typepath, /atom))
		var/atom/thing = typepath
		return initial(thing.name)
	if (ispath(typepath, /datum/reagent))
		var/datum/reagent/reagent = typepath
		return initial(reagent.name)
	if (ispath(typepath, /datum/chemical_reaction))
		var/datum/chemical_reaction/reaction = typepath
		return initial(reaction.name)
	return null

/proc/crafting_atlas_admin_desc(typepath)
	if (ispath(typepath, /atom))
		var/atom/thing = typepath
		return initial(thing.desc)
	if (ispath(typepath, /datum/reagent))
		var/datum/reagent/reagent = typepath
		return initial(reagent.description)
	if (ispath(typepath, /datum/chemical_reaction))
		var/datum/chemical_reaction/reaction = typepath
		return "Chemistry reaction. Result: [initial(reaction.result)]."
	return null

/datum/crafting_atlas_presenter/tgui/proc/admin_view(mob/viewer, typepath)
	var/id = "[typepath]"
	var/client/reader = viewer.client
	// Same per-reader sprite cache as public entries: send each preview once.
	var/image_file = reader && islist(reader.atlas_icon_cache) && islist(reader.atlas_icon_cache[id]) ? reader.atlas_icon_cache[id][1] : null
	if (isnull(image_file))
		image_file = ""
		var/icon_file
		var/state
		if (ispath(typepath, /atom))
			var/atom/prototype = typepath
			icon_file = initial(prototype.icon)
			state = initial(prototype.icon_state)
		if (icon_file && (state in icon_states(icon_file)))
			image_file = "atlas_[md5(id)].png"
			viewer << browse_rsc(icon(icon_file, state, SOUTH, 1), image_file)
		if (reader)
			if (!islist(reader.atlas_icon_cache))
				reader.atlas_icon_cache = list()
			reader.atlas_icon_cache[id] = list(image_file, "")
	var/name = crafting_atlas_admin_name(typepath)
	return list("id" = id, "name" = html_encode(name ? "[name]" : id), "image" = image_file, "note" = html_encode("[crafting_atlas_admin_only[crafting_atlas_admin_root(typepath)]]"))

// Listed entries matching every search word; all of them for an empty search.
/datum/crafting_atlas_presenter/tgui/proc/admin_entries(datum/crafting_atlas_reference/reference, mob/viewer, list/words)
	var/list/rows = list()
	if (!crafting_atlas_admin_reader(viewer))
		return rows
	for (var/typepath in crafting_atlas_admin_types())
		if (rows.len >= 150)
			break
		if (words.len && !all_words(reference.search_text("[crafting_atlas_admin_name(typepath)] [typepath]"), words))
			continue
		rows += list(admin_view(viewer, typepath))
	return rows

// The page of one listed type: its own name, examine text and the staff note.
/datum/crafting_atlas_presenter/tgui/proc/admin_resource_model(mob/viewer, list/data, typepath)
	var/list/view = admin_view(viewer, typepath)
	var/desc = crafting_atlas_admin_desc(typepath)
	data["guidance"] = list("id" = view["id"], "name" = view["name"], "image" = view["image"], "admin_note" = view["note"], "admin_only" = TRUE,
		"kind" = "Admin only", "desc" = html_encode(desc ? "[desc]" : ""), "stats" = list(), "entity" = FALSE, "heading" = "Staff note on", "routes" = list(), "more" = FALSE,
		"found_in" = list(), "made_by" = list(), "used_in" = list(), "made_here" = list(), "made_by_count" = 0, "used_in_count" = 0, "made_here_count" = 0)
	data["query"] = ""
	return data
