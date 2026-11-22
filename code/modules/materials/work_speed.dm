// Labour speed (Val, 2026-11-19): how long digging, mining, chopping and
// tilling take, from the tool, the worker's stats and their trade.
//
//   wait = base x trade / (tool x stats), kept within WORK_MIN_MULT and
//   WORK_MAX_MULT of base.
//
// base is the wait for an average worker (every stat 100, no trade) with the
// reference tool of that kind of work, so an iron tool and an average worker
// keep the wait each action always had:
//   dig  - iron shovel, usespeed 1.5
//   mine - iron pickaxe, usespeed 2
//   chop - iron hatchet, chopping_speed 1.7 (lower is faster)
//   till - plain hoe, usespeed 1
//   shift - iron shovel again, for moving loose earth (piles, backfill); a
//           tool's shifting_mult scales it, so a mattock breaks ground well
//           but is poor at shovelling
// A better tool, a stronger worker or a matching trade shortens the wait; a
// bone shovel, a weak worker or bare hands lengthen it.

var/global/list/work_reference_tool_speed = list(
	WORK_DIG = 1.5,
	WORK_MINE = 2,
	WORK_CHOP = 1.7,
	WORK_TILL = 1,
	WORK_SHIFT = 1.5)

// The stats each kind of work draws on, by weight (weights add up to 1).
var/global/list/work_stat_weights = list(
	WORK_DIG = list("strength" = 0.7, "stamina" = 0.3),
	WORK_MINE = list("strength" = 0.8, "stamina" = 0.2),
	WORK_CHOP = list("strength" = 0.7, "dexterity" = 0.3),
	WORK_TILL = list("farming" = 0.6, "strength" = 0.4),
	WORK_SHIFT = list("strength" = 0.7, "stamina" = 0.3))

// The trade (trade_traits.dm) whose own work each kind is.
var/global/list/work_trade_kind = list(
	WORK_DIG = "navvy",
	WORK_MINE = "miner",
	WORK_CHOP = "woodcutter",
	WORK_SHIFT = "navvy")

// How much faster this tool works than the reference tool: 1 for the
// reference tool or no tool.
/proc/work_tool_factor(obj/item/tool, kind)
	var/reference = work_reference_tool_speed[kind]
	if (!reference || !isitem(tool))
		return 1
	if (kind == WORK_CHOP)
		var/obj/item/weapon/material/M = tool
		if (!istype(M) || M.chopping_speed <= 0)
			return 1
		return reference / M.chopping_speed
	if (!("usespeed" in tool.vars))
		return 1
	var/speed = tool.vars["usespeed"]
	if (!isnum(speed) || speed <= 0)
		return 1
	if (kind == WORK_SHIFT && ("shifting_mult" in tool.vars) && isnum(tool.vars["shifting_mult"]))
		speed *= tool.vars["shifting_mult"]
	return speed / reference

// How much faster this worker's stats make the work: 1 for an average
// worker, never below 0.5.
/proc/work_stat_factor(mob/user, kind)
	var/mob/living/human/H = user
	var/list/weights = work_stat_weights[kind]
	if (!istype(H) || !weights)
		return 1
	var/total = 0
	for (var/stat in weights)
		var/coeff = H.getStatCoeff(stat)
		total += weights[stat] * (coeff ? coeff : 1)
	return max(0.5, total)

// The trade multiplier on this kind of work: below 1 for its own trade,
// above 1 for another trade, 1 with no trade.
/proc/work_trade_factor(mob/user, kind)
	var/mob/living/human/H = user
	var/trade_kind = work_trade_kind[kind]
	if (!istype(H) || !trade_kind)
		return 1
	return H.trade_time_mult(trade_kind)

// The do_after wait for labour of this kind with this tool, from a base wait
// for an average worker with the reference tool.
/proc/work_delay(mob/user, base, kind, obj/item/tool)
	var/mult = work_trade_factor(user, kind) / (work_tool_factor(tool, kind) * work_stat_factor(user, kind) * arcane_bless_speed(tool))
	mult = max(WORK_MIN_MULT, min(WORK_MAX_MULT, mult))
	return max(1, round(base * mult, 1))

// The same, for a job written as time_per_speed / (strength x usespeed): its
// base is the wait at the reference tool's speed.
/proc/work_delay_per_speed(mob/user, time_per_speed, kind, obj/item/tool)
	var/reference = work_reference_tool_speed[kind]
	return work_delay(user, reference ? time_per_speed / reference : time_per_speed, kind, tool)
