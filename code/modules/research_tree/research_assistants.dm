// ============================================================
// Research Tree - hired research assistants (Persistence redesign, Val 2026-11-10)
// ------------------------------------------------------------
// A scholar can hire an assistant to keep a second bench going. The
// assistant is an ordinary NPC body, not a player: it works for coin wages,
// with its employer's scholarship (it follows their methods), at a pace set
// by its rank, and only while its employer is alive and in this region, so a
// bench still never runs for someone who has logged off. It knows the
// groundwork its employer knows or that the bench's books hold. It never
// learns anything itself and gains no skill.
// ============================================================

#define ASSISTANT_TICKS_PER_MINUTE 6 // the research process fires every 10 seconds
#define ASSISTANT_MIN_PREPAID_MINUTES 10

// Rank => list(research pace, copper coins per minute of research)
var/global/list/research_assistant_ranks = list(
	"Clerk" = list(0.5, 1),
	"Scholar" = list(0.75, 2),
	"Master" = list(1, 4))

/mob/living/human/research_assistant
	var/employer_id = null   // the employer's scholar_identity()
	var/employer_name = null
	var/assistant_rank = "Clerk"
	var/wage_balance = 0     // copper coins left to pay for work
	var/tmp/unpaid_warned = FALSE

/mob/living/human/research_assistant/persistence_runtime_var(key)
	return key == "unpaid_warned" || ..(key)

/mob/living/human/research_assistant/proc/rank_pace()
	var/list/rank = research_assistant_ranks[assistant_rank]
	return rank ? rank[1] : 0

/mob/living/human/research_assistant/proc/rank_wage()
	var/list/rank = research_assistant_ranks[assistant_rank]
	return rank ? rank[2] : 0

// The employer, if they are alive, connected and in this region.
/mob/living/human/research_assistant/proc/employer_mob()
	if (!istext(employer_id))
		return null
	for (var/mob/living/human/H in human_clients_mob_list)
		if (H != src && H.client && H.stat != DEAD && H.scholar_identity() == employer_id)
			return H
	return null

// Works only while paid and while the employer is around.
/mob/living/human/research_assistant/research_presence()
	return wage_balance > 0 && employer_mob()

// The employer's methods: their scholarship, not the assistant's own.
/mob/living/human/research_assistant/scholar_level(discipline)
	var/mob/living/human/E = employer_mob()
	return E ? E.scholar_level(discipline) : 0

/mob/living/human/research_assistant/gain_scholarship(node_id, amount)
	return

/mob/living/human/research_assistant/research_tool_rate()
	return ..() * rank_pace()

// Groundwork the employer knows, or that a book on a bench beside it holds.
/mob/living/human/research_assistant/knows_research_prereqs(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N)
		return FALSE
	var/mob/living/human/E = employer_mob()
	for (var/req in N.prereqs)
		if (E && E.knows_recipe_node(req))
			continue
		var/found = FALSE
		for (var/obj/structure/research_bench/B in range(BOOK_RESEARCH_REACH, src))
			for (var/obj/item/weapon/book/book in B.placed_books())
				if (book.has_research_chapter(req))
					found = TRUE
					break
			if (found)
				break
		if (!found)
			return FALSE
	return TRUE

// Called by the bench for each tick of research this assistant did.
/mob/living/human/proc/paid_for_research_tick()
	return

/mob/living/human/research_assistant/paid_for_research_tick()
	wage_balance = max(0, round(wage_balance - rank_wage() / ASSISTANT_TICKS_PER_MINUTE, 0.001))
	if (wage_balance <= 0 && !unpaid_warned)
		unpaid_warned = TRUE
		say("I've worked off my wages. Pay me if you want me to go on.")

// They buy their own food and water out of their wages.
/mob/living/human/research_assistant/Life()
	. = ..()
	if (stat != DEAD)
		nutrition = max(nutrition, max_nutrition * 0.5)
		water = max(water, max_water * 0.5)

/mob/living/human/research_assistant/examine(mob/user)
	. = ..()
	if (stat == DEAD)
		return
	var/minutes = rank_wage() ? round(wage_balance / rank_wage()) : 0
	var/status = "working"
	if (wage_balance <= 0)
		status = "waiting to be paid"
	else if (!employer_mob())
		status = "waiting for [employer_name ? employer_name : "their employer"]"
	to_chat(user, SPAN_NOTICE("A hired research assistant ([assistant_rank]) working for [employer_name ? employer_name : "someone"]. Wages left: about [minutes] minute\s of research. Now [status]."))

// Anyone can pay an assistant's wages with coins.
/mob/living/human/research_assistant/attackby(obj/item/W, mob/user)
	if (stat != DEAD && istype(W, /obj/item/stack/money) && specialist_trader_coin_units(W.type))
		pay_wages(W, user)
		return
	return ..()

/mob/living/human/research_assistant/proc/pay_wages(obj/item/stack/money/coins, mob/user)
	var/units = specialist_trader_coin_units(coins.type) * coins.amount
	if (units <= 0)
		return FALSE
	user.remove_from_mob(coins)
	qdel(coins)
	wage_balance += units
	unpaid_warned = FALSE
	to_chat(user, SPAN_NOTICE("You pay [src] [units] copper in wages. That covers about [round(wage_balance / max(1, rank_wage()))] minutes of research."))
	return TRUE

// Hands back unspent wages as coins.
/proc/research_assistant_refund(turf/T, copper)
	copper = round(copper)
	if (!T || copper <= 0)
		return
	var/gold = round(copper / 40)
	copper -= gold * 40
	var/silver = round(copper / 10)
	copper -= silver * 10
	research_assistant_coin_pile(T, /obj/item/stack/money/goldcoin, gold)
	research_assistant_coin_pile(T, /obj/item/stack/money/silvercoin, silver)
	research_assistant_coin_pile(T, /obj/item/stack/money/coppercoin, copper)

/proc/research_assistant_coin_pile(turf/T, path, count)
	var/obj/item/stack/money/proto = path
	var/each = max(1, initial(proto.max_amount))
	while (count > 0)
		var/n = min(each, count)
		new path(T, n, FALSE)
		count -= n

/mob/living/human/research_assistant/verb/dismiss_assistant()
	set name = "Dismiss assistant"
	set category = null
	set src in oview(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || stat == DEAD)
		return
	if (H.scholar_identity() != employer_id)
		to_chat(H, SPAN_WARNING("[src] doesn't work for you."))
		return
	dismiss(H)

/mob/living/human/research_assistant/proc/dismiss(mob/living/human/H)
	var/turf/T = get_turf(src)
	research_assistant_refund(T, wage_balance)
	wage_balance = 0
	visible_message(SPAN_NOTICE("[src] gathers their things and leaves."))
	qdel(src)
	return TRUE

// ------------------------------------------------------------
// Hiring
// ------------------------------------------------------------

/mob/living/human/proc/hired_research_assistant()
	var/id = scholar_identity()
	for (var/mob/living/human/research_assistant/A in human_mob_list)
		if (A.stat != DEAD && A.employer_id == id)
			return A
	return null

// Returns a reason src can't hire for rank with coins at bench, or null.
// With no rank, only checks what doesn't depend on the rank and payment.
/mob/living/human/proc/research_assistant_hire_problem(obj/structure/research_bench/bench, rank = null, obj/item/stack/money/coins = null)
	if (!map || !map.book_research_enabled())
		return "Research assistants aren't for hire here."
	if (istype(src, /mob/living/human/research_assistant))
		return "Assistants don't hire assistants."
	if (!istype(bench) || get_dist(src, bench) > 1)
		return "Stand beside the research bench the assistant will work at."
	if (hired_research_assistant())
		return "You already have a research assistant."
	if (isnull(rank))
		return null
	if (!(rank in research_assistant_ranks))
		return "Choose a rank."
	var/list/terms = research_assistant_ranks[rank]
	var/needed = terms[2] * ASSISTANT_MIN_PREPAID_MINUTES
	if (!istype(coins) || coins.loc != src || specialist_trader_coin_units(coins.type) * coins.amount < needed)
		return "Hold at least [needed] copper in coins: a [lowertext(rank)] wants [ASSISTANT_MIN_PREPAID_MINUTES] minutes of wages up front."
	return null

// A free tile beside the bench for the assistant to stand on.
/proc/research_assistant_spot(obj/structure/research_bench/bench)
	for (var/turf/T in orange(1, bench))
		if (T.density)
			continue
		var/blocked = FALSE
		for (var/atom/movable/AM in T)
			if (AM.density)
				blocked = TRUE
				break
		if (!blocked)
			return T
	return null

// Creates the assistant, paid from coins. Returns it, or null.
/mob/living/human/proc/hire_research_assistant(obj/structure/research_bench/bench, rank, obj/item/stack/money/coins)
	if (research_assistant_hire_problem(bench, rank, coins))
		return null
	var/turf/T = research_assistant_spot(bench)
	if (!T)
		return null
	var/mob/living/human/research_assistant/A = new(T)
	A.employer_id = scholar_identity()
	A.employer_name = real_name
	A.assistant_rank = rank
	A.civilization = "none"
	A.put_in_hands(new /obj/item/weapon/pen/pencil(T))
	A.pay_wages(coins, src)
	A.dir = get_dir(A, bench)
	return A

/mob/living/human/verb/hire_research_assistant_verb()
	set name = "Hire a research assistant"
	set category = "IC"
	var/obj/structure/research_bench/bench = locate() in range(1, src)
	var/problem = research_assistant_hire_problem(bench)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/list/choices = list()
	for (var/rank in research_assistant_ranks)
		var/list/terms = research_assistant_ranks[rank]
		choices["[rank]: researches at [terms[1] * 100]% of your pace for [terms[2]] copper a minute"] = rank
	var/pick = player_input(src, "An assistant researches with your scholarship while you're in the region, so you can keep a second bench going. They need wages paid in coins; hold at least [ASSISTANT_MIN_PREPAID_MINUTES] minutes' worth.", "Hire a research assistant", null, "anything", choices, TRUE)
	if (!pick || !(pick in choices))
		return
	var/rank = choices[pick]
	var/obj/item/stack/money/coins = get_active_hand()
	problem = research_assistant_hire_problem(bench, rank, coins)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	var/mob/living/human/research_assistant/A = hire_research_assistant(bench, rank, coins)
	if (!A)
		to_chat(src, SPAN_WARNING("There's no room beside the bench for an assistant."))
		return
	to_chat(src, SPAN_NOTICE("You hire [A] as a [lowertext(rank)]. They research at this bench with your scholarship while you're in the region and their wages last. Pay them with coins; use Dismiss assistant to let them go and get the unspent wages back."))

#undef ASSISTANT_MIN_PREPAID_MINUTES
#undef ASSISTANT_TICKS_PER_MINUTE
