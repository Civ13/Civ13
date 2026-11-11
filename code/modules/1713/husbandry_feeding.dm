// Fed animals produce more (docs/husbandry-feed-and-products.md, issue #3051).
// Milk and eggs follow the same hunger thresholds animals already use to look
// for food: a well-fed animal produces at the full rate, a hungry one (looking
// for food) at half the rate, and a starving one (always looking) not at all.

#define ANIMAL_FED_HUNGER 500
#define ANIMAL_STARVING_HUNGER 180

/proc/animal_product_factor(mob/living/simple_animal/A)
	if (!istype(A))
		return 1
	if (A.simplehunger >= ANIMAL_FED_HUNGER)
		return 1
	if (A.simplehunger >= ANIMAL_STARVING_HUNGER)
		return 0.5
	return 0

// One production chance (an egg cycle): TRUE at the animal's current rate.
/proc/animal_product_roll(mob/living/simple_animal/A)
	var/factor = animal_product_factor(A)
	return factor >= 1 || (factor > 0 && prob(factor * 100))

// Udders scale every milk refill by how well the animal is fed. Milking takes
// milk out with trans_id_to, which is not affected.
/datum/reagents/udder

/datum/reagents/udder/add_reagent(var/id, var/amount, var/data = null, var/safety = FALSE, var/list/accepted_amount = null)
	if (id == "milk" && isnum(amount))
		amount = round(amount * animal_product_factor(my_atom))
		if (amount <= 0)
			if (accepted_amount)
				accepted_amount["amount"] = 0
			return FALSE
	return ..(id, amount, data, safety, accepted_amount)

#undef ANIMAL_FED_HUNGER
#undef ANIMAL_STARVING_HUNGER
