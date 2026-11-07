// Native check for /datum/reagents/proc/remove_reagent("ethanol"), compiled
// against the proc extracted from code/modules/reagents/Chemistry-Holder.dm.
#define MINIMUM_CHEMICAL_VOLUME 0.01

/atom/proc/on_reagent_change()
	return
/mob/living/human
	var/nutrition = 0
	var/max_nutrition = 0
/proc/ishuman(A)
	return istype(A, /mob/living/human)

/world
	maxx = 1
	maxy = 1
	maxz = 1

/datum/reagent
	var/id = "reagent"
	var/volume = 0
/datum/reagent/carbon
	id = "carbon"
/datum/reagent/ethanol
	id = "ethanol"
/datum/reagent/ethanol/beer
	id = "beer"

/datum/reagents
	var/list/reagent_list = list()
	var/total_volume = 0
	var/atom/my_atom = null
	var/reactions = 0

/datum/reagents/proc/update_total()
	total_volume = 0
	for (var/datum/reagent/R in reagent_list)
		if (R.volume < MINIMUM_CHEMICAL_VOLUME)
			reagent_list -= R
		else
			total_volume += R.volume

/datum/reagents/proc/handle_reactions()
	reactions++

/datum/reagents/proc/put(path, amount)
	var/datum/reagent/R = new path()
	R.volume = amount
	reagent_list += R
	update_total()
	return R

/datum/reagents/proc/amount_of(id)
	for (var/datum/reagent/R in reagent_list)
		if (R.id == id)
			return R.volume
	return 0

var/probe_failed = FALSE
/proc/probe_assert(condition, text)
	if (!condition)
		probe_failed = TRUE
		world.log << "FAIL [text]"

/world/New()
	// Another reagent added before the ethanol: the ethanol is still spent.
	var/datum/reagents/H = new()
	H.put(/datum/reagent/carbon, 10)
	H.put(/datum/reagent/ethanol, 10)
	probe_assert(H.remove_reagent("ethanol", 4, TRUE), "remove reports success")
	probe_assert(H.amount_of("ethanol") == 6, "ethanol after carbon is spent ([H.amount_of("ethanol")])")
	probe_assert(H.amount_of("carbon") == 10, "carbon untouched")
	// A draw larger than the first alcohol takes the rest from the next one.
	var/datum/reagents/M = new()
	M.put(/datum/reagent/ethanol, 10)
	M.put(/datum/reagent/ethanol/beer, 10)
	M.remove_reagent("ethanol", 15, TRUE)
	probe_assert(M.amount_of("ethanol") == 0 && M.amount_of("beer") == 5, "mixed alcohols drawn in turn ([M.amount_of("ethanol")], [M.amount_of("beer")])")
	probe_assert(M.reactions == 0, "safety skips reactions")
	// No alcohol at all: nothing removed, reported as not removed.
	var/datum/reagents/N = new()
	N.put(/datum/reagent/carbon, 5)
	probe_assert(!N.remove_reagent("ethanol", 2, TRUE), "no alcohol reports failure")
	probe_assert(N.amount_of("carbon") == 5, "no alcohol leaves others")
	// Other ids keep their old behaviour.
	N.remove_reagent("carbon", 2)
	probe_assert(N.amount_of("carbon") == 3 && N.reactions == 1, "plain removal")
	if (!probe_failed)
		world.log << "PASS gameplay audit ethanol"
	shutdown()
