// A source that gives a few things and grows them back over time: flint in a
// rock, glass in an obsidian outcrop. (Fish have their own stock, which
// regrows by how much is left: code/modules/1713/fishing_grounds.dm.)
//
// The stock is lazy: nothing ticks. available() works out what grew back since
// it was last asked, so a source nobody visits costs nothing. Hold it in a tmp
// var (or a global table); world.time restarts with the server, so a stock
// restarts full with it.
//
// - regrow_all FALSE: one comes back every `period` after the stock dropped
//   below full (flint).
// - regrow_all TRUE: the stock refills completely `period` after it ran out
//   (an outcrop that has to weather before more shows).

/datum/resource_stock
	var/left = 0
	var/max = 1
	var/period = 1
	var/regrow_all = FALSE
	var/since = 0

/datum/resource_stock/New(_max = 1, _period = 1, _regrow_all = FALSE)
	..()
	max = _max
	period = max(1, _period)
	regrow_all = _regrow_all
	left = max
	since = world.time

/datum/resource_stock/proc/available()
	if (left < max)
		if (regrow_all)
			if (left <= 0 && world.time >= since + period)
				left = max
		else
			var/regained = round((world.time - since) / period)
			if (regained > 0)
				left = min(max, left + regained)
				since += regained * period
	if (left >= max && !regrow_all)
		since = world.time // a full stretch does not bank regrowth
	return left

// Take n if that many are there. A stock that runs out starts its regrowth now.
/datum/resource_stock/proc/take(n = 1)
	if (available() < n)
		return FALSE
	var/was_full = left >= max
	left -= n
	if (regrow_all ? left <= 0 : was_full)
		since = world.time
	return TRUE
