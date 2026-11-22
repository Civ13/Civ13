// How character setup groups trait_list. trait_list stays the single source
// of costs, exclusions and descriptions; this file only says where each
// trait is shown. A trait missing from every list below shows under "Other".

// Categories in display order. pick_one: its traits exclude one another, so
// the picker offers them as one choice and swaps instead of refusing.
var/global/list/trait_categories = trait_categories_table()
/proc/trait_categories_table()
	return list(
	list("id" = "playstyle", "title" = "Playstyle", "note" = "A way of playing. Each has its own strength and its own price.", "pick_one" = TRUE),
	list("id" = "study", "title" = "Field of study", "note" = "Optional. Faster research in one discipline, a little slower in the others. Basic Mathematics is never affected.", "pick_one" = TRUE),
	list("id" = "trade", "title" = "Trade", "note" = "Optional. Your own kind of hands-on work goes faster, other trades a little slower. Can be held with a field of study.", "pick_one" = TRUE),
	list("id" = "body", "title" = "Body and build", "note" = "", "pick_one" = FALSE),
	list("id" = "health", "title" = "Health and diet", "note" = "", "pick_one" = FALSE),
	list("id" = "senses", "title" = "Senses and speech", "note" = "", "pick_one" = FALSE),
	list("id" = "mind", "title" = "Mind and learning", "note" = "", "pick_one" = FALSE),
	list("id" = "temper", "title" = "Temperament", "note" = "", "pick_one" = FALSE),
	list("id" = "other", "title" = "Other", "note" = "", "pick_one" = FALSE))

// Names may be listed before their trait exists; only traits in trait_list are shown.
var/global/list/trait_category_members = trait_category_members_table()
/proc/trait_category_members_table()
	return list(
	"playstyle" = list("Recluse Scholar", "Menacing", "Hardened Fighter", "Quartermaster", "Green Thumb", "Tinkerer", "Wanderer", "Rallying Voice"),
	"study" = list("Engineer", "Strategist", "Naturalist", "Agronomist", "Physician"),
	"trade" = list("Mechanic", "Gunsmith", "Smith", "Tailor", "Carpenter", "Navvy", "Miner", "Woodcutter"),
	"body" = list("Dwarfism", "Short", "Tall", "Gigantism", "Agile", "Slowness", "Flat Footed", "Deep Lungs", "Asthmatic", "Strong Back", "Bad Back", "Steady Hands", "Butterfingers", "Baldness"),
	"health" = list("Strong Immune System", "Weak Immune System", "Hemophilia", "Thick Skinned", "Low Pain Tolerance", "Heat Tolerance", "Heat Sensitivity", "Cold Tolerance", "Cold Sensitivity", "Light Eater", "Glutton", "Vegan", "Carnivore", "Bee Sting Allergy", "Sting Resistant", "Hay Fever", "Shellfish Allergy"),
	"senses" = list("Blind", "Nearsighted", "Farsighted", "Deaf", "Mute", "Stutter"),
	"mind" = list("Quick Learner", "Slow Learner", "Bookworm", "Dyslexic", "Autistic", "ADHD"),
	"temper" = list("Introverted", "Extroverted", "Empathetic", "Squeamish"))

// One extra line under a trait in the picker, such as how long a choice lasts.
var/global/list/trait_notes = list()

var/global/list/trait_category_lookup = null

/proc/trait_category_id(trait_name)
	if (!trait_category_lookup)
		trait_category_lookup = list()
		for (var/category in trait_category_members)
			for (var/member in trait_category_members[category])
				trait_category_lookup[member] = category
	var/found = trait_category_lookup[trait_name]
	return found ? found : "other"

// Why character setup may not add (adding = TRUE) or drop this trait right
// now, as a short line for the player, or null when it may. A trait with a
// waiting time between changes overrides this.
/datum/preferences/proc/trait_change_block(trait_name, adding)
	return null
