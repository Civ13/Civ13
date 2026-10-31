/mob
	var/list/traits = list()
	// assoc cache so find_trait() is a hash lookup instead of a list scan;
	// anything that changes 'traits' after spawn must set traits_dirty = TRUE
	var/tmp/list/trait_cache = null
	var/tmp/traits_dirty = TRUE
//name = cost, exclusions, description

/mob/proc/find_trait(var/tt = null)
	if (!tt)
		return FALSE
	if (traits_dirty || !trait_cache)
		trait_cache = list()
		for (var/t in traits)
			trait_cache[t] = TRUE
		traits_dirty = FALSE
	if (tt in trait_cache)
		return TRUE
var/global/list/trait_list = list(
//	"Lactose Intolerance" = list(-1,list(),"You have the inability to digest dairy products and will get sick when you ingest them. (Get food poisoning from anytype of milk product)"),
//	"Skilled Archer" = list(3,list("Skilled Fighter"),"You are better at fighting with ranged weapons and running away. (Start with better Dexterity, and bow skills)"),
//	"Skilled Fighter" = list(3,list("Skilled Archer"),"You are better at fighting with your fists and melee weapons. (Start with better Strength, and sword skills)"),
	"Blind" = list(-6,list(),"You can not see, you may require aid."),
//	"Partial Blindness" = list(-2,list(),"You can barely see, you may require aid or sometype of instrument"),
	"Introverted" = list(1,list("Extroverted"),"In hunger-enabled modes, your mood improves without other living humans within 3 tiles, and falls near them."),
	"Extroverted" = list(-1,list("Introverted"),"In hunger-enabled modes, your mood improves near other living humans within 3 tiles, and falls when alone."),
//	"Down Syndrome" = list(-5,list(),"You are very backward in your mental and physical developement, you are no scolar. (Can't get Philo past 1.4, and has errors in speach and speach comes out slow)"),
//	"Sickle Celled Anemia" = list(-1,list(),"Your blood cells are not normal, and you have a higher chance of having Heart failure. (Random Heart attacks and pains in the chest and other parts in the body)"),
	"Hemophilia" = list(-2,list(),"Your blood does not clot normally. (Affected blood-loss paths remove 25% more blood)"),
//	"Spinal Paralysis" = list(-3,list(),"Your spine has been damaged long ago and aches (Your back hurts a lot and you'll soon become unable to walk)"),
//	"Schizophrenia" = list(-4,list(),"You hear things and see horrible images in your head later in your life (PTSD and voices in your head)"),
	"Dwarfism" = list(0,list("Gigantism","Tall","Short"),"Strength x0.7, crafting x1.5, food use x0.8 where hunger applies; size x0.8 on Nomads maps."),
	"Short" = list(-1,list("Gigantism","Tall","Dwarfism"),"Strength x0.85 and crafting x1.15; size x0.9 on Nomads maps."),
//	"Hyperpigmentation" = list(5,list(),"Your skin is covered in Darkened patches or spots on your skin. (You gain heat resistance a bit)"),
	"Tall" = list(1,list("Dwarfism","Short","Gigantism"),"Strength x1.15 and dexterity x0.85; size x1.1 on Nomads maps."),
	"Gigantism" = list(3,list("Dwarfism","Short","Tall"),"Strength x1.5, dexterity x0.7, movement speed multiplier x0.9, food use x1.4 where hunger applies; size x1.3 on Nomads maps."),
//	"Sixth Sense" = list(3,list(),"You can hear voices of people who are not even near you."),
	"Agile" = list(3,list("Slowness"),"Your movement speed multiplier is increased by 15%."),
	"Weak Immune System" = list(-3,list("Strong Immune System"),"You are more likely to get sick."),
	"Strong Immune System" = list(3,list("Weak Immune System"),"Reduces infection risk from several contaminated-water and environmental exposures; does not protect against every transmission route."),
	"Vegan" = list(-1,list("Carnivore","Cannibal"),"You refuse non-vegetarian snacks when eating them yourself; this does not prevent force-feeding."),
	"Carnivore" = list(-1,list("Vegan"),"You refuse vegetarian snacks when eating them yourself; this does not prevent force-feeding."),
	"Slowness" = list(-2,list("Agile"),"Your movement speed multiplier is reduced by 15%."),
//	"Bubonic Immunity" = list(5,list("Weak Immune System"),"Your body can survive the bubonic plague, unlike most people."),
//	"Cannibal" = list(4,list("Vegan"),"You can only eat human meat."),
//	"Tough Liver" = list(5,list(),"You have a higher tolerance when drinking Alcohol or when Poisoned."),
	"Flat Footed" = list(-1,list(),"Running uses twice the normal stamina per movement step."),
//	"Diabetes"= list(-3,list(),"You cannot eat a lot of sugery things. (Possibly to lose a limb due to insulin levels)"),
	"Baldness"= list(0,list(),"Cosmetic: bald hairstyle with no scalp hair growth; does not prevent facial hair."),
//	"Demi-God"= list(15,list(),"You are superior in many ways, but there are things still stronger than you. (Beyond max Strength, Dexterity or Philisophy, Crafting/ Speed Increase aswell"),
	"Empathetic" = list(1,list(),"You can notice what type of mood someone is in when you look at them."),
	"Deaf" = list(-3,list(),"You cannot hear at all."),
	"Mute" = list(-2,list("Stutter"),"You cannot speak at all."),
	"Heat Tolerance" = list(2,list("Heat Sensitivity"),"Heat-discomfort damage multiplier x0.3; not immunity to fire or all heat damage. Nomad starting climate may replace this choice."),
	"Heat Sensitivity" = list(-2,list("Heat Tolerance"),"Heat-discomfort damage multiplier x2. Nomad starting climate may replace this choice."),
	"Cold Tolerance" = list(2,list("Cold Sensitivity"),"Cold-discomfort damage multiplier x0.3; not blanket cold immunity. Nomad starting climate may replace this choice."),
	"Cold Sensitivity" = list(-2,list("Cold Tolerance"),"Cold-discomfort damage multiplier x2. Nomad starting climate may replace this choice."),
	"Stutter"= list(-1,list("Mute"),"You have a permanent stutter."),

)

// Validate player choices, not runtime traits added by climate/background logic.
// Never mutate legacy choices: the player must explicitly correct them in setup.
/proc/get_trait_selection_error(trait_choices, check_budget = TRUE)
	if (!islist(trait_choices))
		return "Invalid trait data. Use Remove in character setup to clear it."
	var/list/seen = list()
	for (var/choice in trait_choices)
		if (!istext(choice) || !(choice in trait_list))
			return "Unknown trait. Remove the unrecognized entry in character setup."
		if (choice in seen)
			return "Duplicate trait: [choice]. Remove the repeated entry in character setup."
		seen += choice
	for (var/choice in trait_choices)
		var/list/exclusions = trait_list[choice][2]
		for (var/excluded in exclusions)
			if (excluded in trait_choices)
				return "Incompatible traits: [choice] and [excluded]. Remove one in character setup."
	if (check_budget && check_trait_points(trait_choices) > 0)
		return "Your traits are not balanced. The sum must be 0 or less."
	return null

// Injectable for deterministic fixtures; production uses BYOND's RNG.
/datum/trait_random_source/proc/roll(upper)
	return rand(1, upper)

// Bounded, biased sampling of valid prefixes, not uniform sampling of all sets.
// The current catalog has 24 entries. Refuse oversized future catalogs rather
// than silently truncating eligibility or letting a click do unbounded work.
/proc/random_zero_point_traits(datum/trait_random_source/random_source = null)
	if (!islist(trait_list) || trait_list.len > 64)
		return null
	if (!random_source)
		random_source = new /datum/trait_random_source
	var/list/choices = list()
	var/list/result = null
	var/matches = 0
	for (var/choice in trait_list)
		var/list/singleton = list(choice)
		if (get_trait_selection_error(singleton, FALSE))
			continue
		choices += choice
		// Always consider eligible zero-cost traits, even if every trial skips.
		if (check_trait_points(singleton) == 0)
			matches++
			if (random_source.roll(matches) == 1)
				result = singleton.Copy()
	for (var/attempt = 1, attempt <= 64, attempt++)
		var/list/order = choices.Copy()
		for (var/i = order.len, i > 1, i--)
			order.Swap(i, random_source.roll(i))
		var/list/selected = list()
		for (var/choice in order)
			if (random_source.roll(2) == 1)
				continue
			var/list/candidate = selected.Copy()
			candidate += choice
			// Allow intermediate positive totals so later drawbacks can balance them.
			if (get_trait_selection_error(candidate, FALSE))
				continue
			selected = candidate
			if (check_trait_points(selected) == 0)
				matches++
				if (random_source.roll(matches) == 1)
					result = selected.Copy()
	// Null means exhausted/no nonempty result; callers must preserve old choices.
	if (!islist(result) || !result.len || get_trait_selection_error(result) || check_trait_points(result) != 0)
		return null
	return result
