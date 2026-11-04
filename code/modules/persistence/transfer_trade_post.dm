// Trade post: ships allowlisted goods to a peer region through the transfer
// agent (transfer_bridge.dm) and holds goods that arrive for players.
// Admin-placed only and inert while the bridge is off.
//
// Goods travel as amounts of a fixed kind, never as the original object, so a
// stack's other fields cannot cross regions. What arrives waits in the post
// under the recipient's key; collecting it is an ordinary world change.

#define TRADE_POST_MAX_AMOUNT 2000

var/global/list/transfer_trade_goods = list(
	"wood" = /obj/item/stack/material/wood,
	"stone" = /obj/item/stack/material/stone,
	"clay" = /obj/item/stack/material/clay,
	"rope" = /obj/item/stack/material/rope,
	"cloth" = /obj/item/stack/material/cloth,
	"leather" = /obj/item/stack/material/leather,
	"copper" = /obj/item/stack/material/copper,
	"tin" = /obj/item/stack/material/tin,
	"bronze" = /obj/item/stack/material/bronze,
	"iron" = /obj/item/stack/material/iron,
	"steel" = /obj/item/stack/material/steel,
	"silver" = /obj/item/stack/material/silver,
	"gold" = /obj/item/stack/material/gold)

var/global/list/transfer_trade_posts = list()

// Exact types only: a subtype may carry different properties.
/proc/transfer_trade_kind(obj/item/stack/S)
	if(!istype(S)) return null
	for(var/kind in transfer_trade_goods)
		if(S.type == transfer_trade_goods[kind]) return kind
	return null

/proc/transfer_trade_max(kind)
	var/obj/item/stack/path = transfer_trade_goods[kind]
	if(!path) return 0
	return min(TRADE_POST_MAX_AMOUNT, initial(path.max_amount))

/proc/transfer_trade_payload(kind, amount, sender, recipient)
	return json_encode(list("v" = 1, "kind" = kind, "amount" = amount, "from" = sender, "to" = recipient))

// Returns the decoded payload, or null when any field is out of bounds.
/proc/transfer_trade_decode(payload)
	if(!istext(payload) || length(payload) > 512) return null
	var/list/P
	try
		P = json_decode(payload)
	catch
		return null
	if(!islist(P) || P.len != 5 || P["v"] != 1 || !istext(P["kind"]) || !(P["kind"] in transfer_trade_goods)) return null
	var/amount = P["amount"]
	if(!isnum(amount) || amount < 1 || amount != round(amount) || amount > transfer_trade_max(P["kind"])) return null
	for(var/field in list("from", "to"))
		var/key = P[field]
		if(!istext(key) || !length(key) || length(key) > 32 || ckey(key) != key) return null
	return P

/proc/transfer_trade_arrival_post()
	for(var/obj/structure/transfer_trade_post/post in transfer_trade_posts)
		if(!QDELETED(post)) return post
	return null

// Credits recorded goods into the post: imports to the recipient, returns to
// the sender. Callers have already recorded the effect, so this never refuses.
/proc/transfer_trade_credit(obj/structure/transfer_trade_post/post, list/payloads, incoming)
	if(!islist(payloads)) return
	for(var/payload in payloads)
		var/list/P = transfer_trade_decode(payload)
		if(!P)
			message_admins("Trade post: an unreadable [incoming ? "arriving" : "returned"] payload was dropped.")
			continue
		var/key = "[incoming ? P["to"] : P["from"]]|[P["kind"]]"
		post.holdings[key] = (isnum(post.holdings[key]) ? post.holdings[key] : 0) + P["amount"]

/obj/structure/transfer_trade_post
	name = "trade post"
	desc = "Ships goods to traders in a distant land and holds what they send back."
	icon = 'icons/obj/structures.dmi'
	icon_state = "propstall1"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;holdings"
	// "ckey|kind" = amount waiting for that player.
	var/list/holdings = list()
	var/busy = FALSE

/obj/structure/transfer_trade_post/New()
	..()
	transfer_trade_posts |= src

/obj/structure/transfer_trade_post/Destroy()
	transfer_trade_posts -= src
	return ..()

/obj/structure/transfer_trade_post/examine(mob/user)
	..()
	if(!transfer_bridge.ready() || !transfer_bridge.peers.len)
		to_chat(user, "<span class='notice'>The post is closed. No traders are expected.</span>")
	else
		to_chat(user, "<span class='notice'>Hand it a stack of [english_list(transfer_trade_goods)] to ship it. Use it empty-handed to collect what was sent to you.</span>")

/obj/structure/transfer_trade_post/attackby(obj/item/W, mob/user)
	if(!istype(W, /obj/item/stack) || !ishuman(user)) return ..()
	send_goods(W, user)

/obj/structure/transfer_trade_post/proc/send_goods(obj/item/stack/S, mob/user)
	var/kind = transfer_trade_kind(S)
	if(!kind)
		to_chat(user, "<span class='warning'>The traders won't ship that.</span>")
		return
	if(!user.ckey || !transfer_bridge.ready() || !transfer_bridge.peers.len)
		to_chat(user, "<span class='warning'>The post is closed.</span>")
		return
	if(busy || persistence_save_active())
		to_chat(user, "<span class='warning'>The post is busy. Try again in a moment.</span>")
		return
	var/peer = transfer_bridge.peers.len == 1 ? transfer_bridge.peers[1] : input(user, "Ship to which land?", "Trade post") as null|anything in transfer_bridge.peers
	if(!peer) return
	var/recipient = input(user, "Whose key should receive it?", "Trade post", user.ckey) as null|text
	recipient = ckey(recipient)
	if(!recipient || length(recipient) > 32) return
	// The prompts slept: check everything again.
	if(busy || QDELETED(src) || QDELETED(S) || user.get_active_hand() != S || !Adjacent(user) || transfer_trade_kind(S) != kind)
		return
	var/amount = S.amount
	if(amount < 1 || amount > transfer_trade_max(kind))
		to_chat(user, "<span class='warning'>The traders take at most [transfer_trade_max(kind)] at once.</span>")
		return
	// Hold the stack while the agent records the escrow, so it can't change.
	busy = TRUE
	user.remove_from_mob(S)
	S.forceMove(src)
	var/list/result = transfer_bridge.begin_escrow(peer, list(transfer_trade_payload(kind, amount, user.ckey, recipient)))
	busy = FALSE
	if(result)
		// Recorded: remove it now, without sleeping.
		qdel(S)
		to_chat(user, "<span class='notice'>The traders pack up [amount] [kind] for [recipient] in [peer].</span>")
		return
	if(!QDELETED(S))
		S.forceMove(get_turf(src))
	to_chat(user, "<span class='warning'>The traders can't take a shipment right now.</span>")

/obj/structure/transfer_trade_post/attack_hand(mob/user)
	if(!ishuman(user) || !user.ckey) return ..()
	var/prefix = "[user.ckey]|"
	var/list/mine = list()
	for(var/key in holdings)
		if(copytext(key, 1, length(prefix) + 1) == prefix)
			var/kind = copytext(key, length(prefix) + 1)
			mine["[kind] ([holdings[key]])"] = kind
	if(!mine.len)
		to_chat(user, "<span class='notice'>Nothing is waiting for you here.</span>")
		return
	var/choice = input(user, "Collect which goods?", "Trade post") as null|anything in mine
	if(!choice || QDELETED(src) || !Adjacent(user)) return
	var/kind = mine[choice]
	var/key = "[prefix][kind]"
	var/have = holdings[key]
	var/obj/item/stack/path = transfer_trade_goods[kind]
	if(!path || !isnum(have) || have < 1) return
	var/take = min(have, transfer_trade_max(kind))
	if(have - take > 0)
		holdings[key] = have - take
	else
		holdings -= key
	new path(get_turf(src), take)
	to_chat(user, "<span class='notice'>You collect [take] [kind].</span>")

#undef TRADE_POST_MAX_AMOUNT
