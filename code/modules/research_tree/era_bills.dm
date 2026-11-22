// ============================================================
// Research Tree - era bills (Val, 2026-11-22)
// ------------------------------------------------------------
// On book-research worlds the late era capstones also need a bill of
// materials, delivered to the bench while their book is on it. The bills lean
// on the resources only some continents hold in quantity (continent_resources.dm,
// rubber_tapping.dm), so sourcing them is the hard part. Anyone may deliver:
// there is no faction, membership or signature check, and any faction can do
// every part itself. Cooperation comes from need, not from a rule.
// - Deliveries are written into the book (research_bills), so they travel with
//   it. Copying or printing a book never copies deliveries.
// - A capstone with no demonstration (the World War II pair) takes its bill in
//   place of the old bench prototype (a small fuel tank, a shell casing).
// - The chapter is finished once its study, demonstration or prototype and
//   bill are all in. Writing a lost capstone again from memory needs no bill.
// Doc: docs/era-bills.md. Nothing here sleeps.
// ============================================================

// node id => list(material key => amount). Starting sizes, to tune from play.
/proc/capstone_bills()
	var/static/list/bills
	if (!bills)
		bills = list(
			"steam_power" = list("coal" = 60, "iron" = 40, "copper" = 10),
			"powered_flight" = list("steel" = 120, "rubber" = 40, "brass" = 30, "cloth" = 40),
			"mechanized_war" = list("steel" = 200, "rubber" = 40, "lead" = 40, "sulphur" = 30, "saltpeter" = 30))
	return bills

// material key => list(what to call it, the stack type it takes)
/proc/bill_materials()
	var/static/list/materials
	if (!materials)
		materials = list(
			"coal" = list("coal", /obj/item/stack/ore/coal),
			"iron" = list("iron ingots", /obj/item/stack/material/iron),
			"copper" = list("copper ingots", /obj/item/stack/material/copper),
			"steel" = list("steel sheets", /obj/item/stack/material/steel),
			"rubber" = list("rubber sheets", /obj/item/stack/material/rubber),
			"brass" = list("brass ingots", /obj/item/stack/material/brass),
			"cloth" = list("cloth", /obj/item/stack/material/cloth),
			"lead" = list("lead ingots", /obj/item/stack/material/lead),
			"sulphur" = list("sulphur", /obj/item/stack/ore/sulphur),
			"saltpeter" = list("saltpeter", /obj/item/stack/ore/saltpeter))
	return materials

// The bill node_id needs here, or null.
/proc/node_bill(node_id)
	if (!map || !map.book_research_enabled() || !istext(node_id))
		return null
	var/list/bills = capstone_bills()
	return bills[node_id]

/proc/node_has_bill(node_id)
	return node_bill(node_id) ? TRUE : FALSE

// A capstone with no demonstration takes its bill in place of the prototype.
/proc/capstone_bill_replaces_prototype(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	return N && N.mode == RESEARCH_MODE_PROTOTYPE && node_has_bill(node_id) && !node_needs_demonstration(node_id)

/proc/bill_material_name(key)
	var/list/M = bill_materials()[key]
	return M ? M[1] : key

// The bill's material key a stack counts as, or null.
/proc/bill_material_key(obj/item/I, list/bill)
	if (!istype(I, /obj/item/stack) || !islist(bill))
		return null
	var/list/materials = bill_materials()
	for (var/key in bill)
		var/list/M = materials[key]
		if (M && istype(I, M[2]))
			return key
	return null

/obj/item/weapon/book
	var/research_bills = "" // "node=key:amount,key:amount;node2=..."

// node id => list(key => delivered), damaged entries dropped.
/obj/item/weapon/book/proc/research_bill_map()
	var/list/out = list()
	if (!istext(research_bills) || !length(research_bills))
		return out
	var/list/bills = capstone_bills()
	for (var/entry in splittext(research_bills, ";"))
		var/at = findtext(entry, "=")
		if (!at)
			continue
		var/node_id = copytext(entry, 1, at)
		var/list/bill = bills[node_id]
		if (!islist(bill))
			continue
		var/list/got = list()
		for (var/part in splittext(copytext(entry, at + 1), ","))
			var/list/kv = splittext(part, ":")
			if (kv.len != 2 || !(kv[1] in bill))
				continue
			var/amount = text2num(kv[2])
			if (isnum(amount) && amount > 0)
				got[kv[1]] = min(bill[kv[1]], round(amount))
		if (got.len)
			out[node_id] = got
	return out

/obj/item/weapon/book/proc/set_research_bill_map(list/map_in)
	var/list/entries = list()
	for (var/node_id in map_in)
		var/list/got = map_in[node_id]
		var/list/parts = list()
		for (var/key in got)
			if (got[key] > 0)
				parts += "[key]:[got[key]]"
		if (parts.len)
			entries += "[node_id]=[jointext(parts, ",")]"
	research_bills = jointext(entries, ";")

/obj/item/weapon/book/proc/bill_delivered(node_id, key)
	var/list/got = research_bill_map()[node_id]
	return islist(got) ? (got[key] || 0) : 0

// key => amount still to deliver for node_id (empty when paid or no bill).
/obj/item/weapon/book/proc/bill_left(node_id)
	var/list/left = list()
	var/list/bill = node_bill(node_id)
	if (!bill || has_research_chapter(node_id))
		return left
	var/list/got = research_bill_map()[node_id]
	for (var/key in bill)
		var/need = bill[key] - (islist(got) ? (got[key] || 0) : 0)
		if (need > 0)
			left[key] = need
	return left

/obj/item/weapon/book/proc/bill_complete(node_id)
	var/list/left = bill_left(node_id)
	return !left.len

/obj/item/weapon/book/proc/clear_research_bill(node_id)
	var/list/M = research_bill_map()
	if (!(node_id in M))
		return
	M -= node_id
	set_research_bill_map(M)

// Puts up to amount of key toward node_id's bill; returns how much it took.
/obj/item/weapon/book/proc/deliver_bill(node_id, key, amount)
	var/list/left = bill_left(node_id)
	var/take = min(max(0, round(amount)), left[key] || 0)
	if (take <= 0)
		return 0
	var/list/M = research_bill_map()
	var/list/got = M[node_id]
	if (!islist(got))
		got = list()
		M[node_id] = got
	got[key] = (got[key] || 0) + take
	set_research_bill_map(M)
	return take

// ---------- At the bench ----------

// Takes W toward the bill of the subject on the bench. TRUE when it was used
// (or refused with a message); FALSE when W is no part of this bill.
/obj/structure/research_bench/proc/take_bill_delivery(obj/item/W, mob/living/human/user, obj/item/weapon/book/B, datum/research_node/N)
	if (!B || !N)
		return FALSE
	var/list/bill = node_bill(N.id)
	var/key = bill_material_key(W, bill)
	if (!key)
		return FALSE
	var/list/left = B.bill_left(N.id)
	if (!left[key])
		if (B.bill_complete(N.id))
			return FALSE // nothing left to pay: let the stack feed supplies as usual
		to_chat(user, SPAN_WARNING("[B] already records all the [bill_material_name(key)] that <b>[N.name]</b> needs."))
		return TRUE
	var/obj/item/stack/S = W
	var/taken = B.deliver_bill(N.id, key, S.amount)
	if (taken <= 0)
		return FALSE
	S.use(taken)
	var/list/still = B.bill_left(N.id)
	if (!still.len)
		var/done = B.add_research_work(N.id, 0, capstone_bill_replaces_prototype(N.id), user)
		to_chat(user, SPAN_NOTICE("You deliver [taken] [bill_material_name(key)]. The bill for <b>[N.name]</b> is paid in full[done ? " and the chapter is finished" : ""]."))
	else
		to_chat(user, SPAN_NOTICE("You deliver [taken] [bill_material_name(key)] toward <b>[N.name]</b>. Still needed: [bill_left_text(still)]."))
	log_game("Era bill: [key_name(user)] delivered [taken] [key] toward [N.id].")
	book_refresh_ui()
	return TRUE

/proc/bill_left_text(list/left)
	var/list/parts = list()
	for (var/key in left)
		parts += "[left[key]] [bill_material_name(key)]"
	return english_list(parts)

// Rows for the research windows: one per material, ticked when delivered.
/proc/bill_rows(obj/item/weapon/book/B, node_id)
	var/list/rows = list()
	var/list/bill = node_bill(node_id)
	if (!bill)
		return rows
	for (var/key in bill)
		var/got = B ? B.bill_delivered(node_id, key) : 0
		rows += list(list("label" = "Bill: [bill[key]] [bill_material_name(key)] delivered to the bench ([got]/[bill[key]])", "ok" = got >= bill[key] ? 1 : 0))
	return rows

// One line for the bench's plain text status.
/proc/bill_status_text(obj/item/weapon/book/B, node_id)
	var/list/bill = node_bill(node_id)
	if (!bill)
		return ""
	var/list/left = B ? B.bill_left(node_id) : bill.Copy()
	if (!left.len)
		return " Its bill of materials is paid."
	return " It also needs a bill of materials delivered to the bench with its book: [bill_left_text(left)] still to go."
