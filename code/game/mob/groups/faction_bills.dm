// Bills of exchange and treasury notes (docs/faction-bills.md). Someone with
// a faction's treasury power (faction_offices.dm) draws a bill on the
// faction's strongbox: a sealed paper promising its bearer a sum in silver.
// Whoever brings the bill to the strongbox is paid from the coin actually in
// it, so merchants can carry paper instead of sacks of coin. Notes are bills
// of one value printed in a batch at a printing press. Nothing checks that a
// faction holds coin for the paper it issues: if more is drawn than the box
// holds, the first to redeem are paid and the rest wait until the box is
// refilled (a run on the treasury). A paid bill is torn up. Bills are only
// good while the register knows their serial, so a copied bill is worthless.
//
// The register lives in map.faction_recruitment["bills"] (durable, renamed
// with the faction):
//   faction -> list("seq" = last serial, "open" = list(serial text ->
//                   list(silver still owed, drawn by, time)))
// Nothing sleeps except the prompts, which recheck after.

#define BILL_MAX 500 // silver on one bill
#define BILLS_OPEN_MAX 200
#define BILL_NOTES_MAX 20

var/global/list/faction_bill_items = list()

// --- Register ------------------------------------------------------------------

/obj/map_metadata/proc/bill_state()
	var/list/S = recruitment_state()
	if (!islist(S["bills"]))
		S["bills"] = list()
	return S["bills"]

/obj/map_metadata/proc/bill_record(faction)
	var/list/S = bill_state()
	var/list/R = S[faction]
	if (!islist(R))
		R = list()
		S[faction] = R
	if (!isnum(R["seq"]) || R["seq"] < 0 || R["seq"] != round(R["seq"]))
		R["seq"] = 0
	if (!islist(R["open"]))
		R["open"] = list()
	return R

/obj/map_metadata/proc/bill_normalize()
	var/list/S = bill_state()
	for (var/faction in S.Copy())
		if (!istext(faction) || !islist(S[faction]))
			S -= faction
			continue
		var/list/R = bill_record(faction)
		var/list/open = R["open"]
		for (var/serial in open.Copy())
			var/list/row = open[serial]
			if (!istext(serial) || !islist(row) || row.len != 3 || !isnum(row[1]) || row[1] <= 0 || !istext(row[2]) || !isnum(row[3]))
				open -= serial

/obj/map_metadata/proc/bill_rename(old_name, new_name)
	faction_rename_assoc_key(bill_state(), old_name, new_name)
	for (var/obj/item/faction_bill/B in faction_bill_items)
		if (B.faction == old_name)
			B.faction = new_name
			B.update_bill_name()

// Registers a bill and returns its serial, or null when the register is full.
/obj/map_metadata/proc/bill_draw(faction, silver, drawer)
	var/list/R = bill_record(faction)
	var/list/open = R["open"]
	if (open.len >= BILLS_OPEN_MAX)
		return null
	R["seq"]++
	var/serial = "[R["seq"]]"
	open[serial] = list(clamp(round(silver), 1, BILL_MAX), drawer, recruitment_now())
	return serial

/obj/map_metadata/proc/bill_row(faction, serial)
	var/list/R = bill_record(faction)
	var/list/row = R["open"][serial]
	return islist(row) && row.len == 3 ? row : null

// Silver owed on all the faction's open bills.
/obj/map_metadata/proc/bills_outstanding(faction)
	var/total = 0
	var/list/R = bill_record(faction)
	for (var/serial in R["open"])
		var/list/row = R["open"][serial]
		if (islist(row) && isnum(row[1]))
			total += row[1]
	return total

// Records a payment on a bill. Returns what is still owed (0 closes it).
/obj/map_metadata/proc/bill_settle(faction, serial, paid)
	var/list/row = bill_row(faction, serial)
	if (!row)
		return 0
	row[1] = round(max(0, row[1] - paid), 0.1)
	if (row[1] <= 0)
		var/list/R = bill_record(faction)
		R["open"] -= serial
		return 0
	return row[1]

// --- The bill ------------------------------------------------------------------------

/obj/item/faction_bill
	name = "bill of exchange"
	desc = "A sealed promise of payment from a faction's treasury."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper_seal-latin"
	w_class = ITEM_SIZE_TINY
	var/faction = ""
	var/serial = ""
	var/face = 0 // silver written on it when drawn
	var/note = FALSE // printed treasury note rather than a written bill

/obj/item/faction_bill/New()
	..()
	faction_bill_items |= src

/obj/item/faction_bill/Destroy()
	faction_bill_items -= src
	return ..()

/obj/item/faction_bill/after_load()
	..()
	update_bill_name()

/obj/item/faction_bill/proc/update_bill_name()
	if (!length(faction))
		name = initial(name)
		desc = initial(desc)
		return
	name = note ? "[faction] note for [face] silver" : "bill of exchange on [faction] for [face] silver"
	desc = "The treasury of [faction] promises to pay the bearer [face] silver at its strongbox. No. [serial]."

/obj/item/faction_bill/proc/owed()
	var/list/row = map ? map.bill_row(faction, serial) : null
	return row ? row[1] : 0

/obj/item/faction_bill/examine(mob/user, distance = -1)
	..()
	if (!length(faction))
		return
	var/owed = owed()
	if (owed <= 0)
		to_chat(user, SPAN_WARNING("The register of [faction] knows no open bill with this number: it is paid, or false."))
	else if (owed < face)
		to_chat(user, SPAN_NOTICE("It has been part paid: [owed] silver is still owed on it."))

/obj/item/faction_bill/attack_self(mob/user)
	examine(user)
	to_chat(user, SPAN_NOTICE("Bring it to the strongbox of [faction] and use it on the box to be paid."))

/obj/map_metadata/proc/bill_make(faction, serial, silver, atom/where, note = FALSE)
	var/obj/item/faction_bill/B = new(where)
	B.faction = faction
	B.serial = serial
	B.face = silver
	B.note = note
	B.update_bill_name()
	return B

// --- Paper to write on -------------------------------------------------------------

/proc/bill_blank_paper(obj/item/I)
	if (!istype(I) || I.type != /obj/item/weapon/paper || QDELETED(I))
		return FALSE
	var/obj/item/weapon/paper/P = I
	// The blank sheet is papyrus or parchment in early ages; a crumpled one is scrap.
	return !length(P.info) && isnull(P.document_record) && !length(P.stamps) && !findtext(P.icon_state, "scrap")

// Blank sheets in the user's hands and at their feet.
/proc/bill_blank_supply(mob/user)
	var/list/found = list()
	var/turf/T = get_turf(user)
	var/list/places = list(user.get_active_hand(), user.get_inactive_hand())
	if (T)
		places += T.contents
	for (var/obj/item/weapon/paper/P in places)
		if (bill_blank_paper(P))
			found |= P
	return found

// --- At the strongbox --------------------------------------------------------------

/obj/structure/closet/crate/faction_strongbox/proc/draw_bills(mob/living/human/user)
	var/choice = WWinput(user, "The box holds coin worth [weighed_silver_text(coin_worth())]; [map.bills_outstanding(faction)] silver is already promised on open bills.", "Draw on the treasury", "Cancel", list("Write a bill of exchange", "Print treasury notes", "Cancel"))
	if (!choice || choice == "Cancel")
		return
	var/notes = choice == "Print treasury notes"
	if (notes && !(locate(/obj/structure/printingpress) in range(1, user)))
		to_chat(user, SPAN_WARNING("Treasury notes are printed. Stand beside a printing press."))
		return
	var/silver = player_input(user, "Silver on each [notes ? "note" : "bill"] (1 to [BILL_MAX]):", "Draw on the treasury", notes ? 1 : 10, "num", null, TRUE)
	if (!isnum(silver) || silver < 1)
		return
	var/count = 1
	if (notes)
		count = player_input(user, "How many notes (1 to [BILL_NOTES_MAX])? Each needs a blank sheet of paper in your hands or at your feet.", "Treasury notes", 5, "num", null, TRUE)
		if (!isnum(count) || count < 1)
			return
		count = min(round(count), BILL_NOTES_MAX)
	silver = clamp(round(silver), 1, BILL_MAX)
	// Everything is checked again after the prompts.
	if (QDELETED(src) || !user.Adjacent(src) || !holds_key(user) || (notes && !(locate(/obj/structure/printingpress) in range(1, user))))
		return
	var/list/paper = bill_blank_supply(user)
	if (paper.len < count)
		to_chat(user, SPAN_WARNING("You need [count] blank sheet[count == 1 ? "" : "s"] of paper in your hands or at your feet."))
		return
	var/made = 0
	for (var/i in 1 to count)
		var/serial = map.bill_draw(faction, silver, user.real_name)
		if (!serial)
			to_chat(user, SPAN_WARNING("The register of [faction] holds no more open bills. Redeem some first."))
			break
		var/obj/item/weapon/paper/P = paper[i]
		user.drop_from_inventory(P)
		qdel(P)
		var/obj/item/faction_bill/B = map.bill_make(faction, serial, silver, get_turf(user), notes)
		user.put_in_hands(B)
		made++
	if (!made)
		return
	var/what = notes ? "[made] note[made == 1 ? "" : "s"] of [silver] silver" : "a bill of exchange for [silver] silver"
	map.treasury_log(faction, "[user.real_name] drew [what] on the treasury.")
	to_chat(user, SPAN_NOTICE("You [notes ? "print" : "write and seal"] [what] on the treasury of [faction]."))
	log_game("[key_name(user)] drew [what] on the treasury of [faction].")

/obj/structure/closet/crate/faction_strongbox/proc/redeem_bill(obj/item/faction_bill/B, mob/living/human/user)
	if (!istype(B) || !istype(user) || B.faction != faction)
		return FALSE
	var/owed = B.owed()
	if (owed <= 0)
		to_chat(user, SPAN_WARNING("The register of [faction] knows no open bill with this number. It is worthless."))
		return TRUE
	var/paid = pay_out(owed, user)
	if (paid <= 0)
		to_chat(user, SPAN_WARNING("The strongbox has no coin to pay [owed] silver. The bill stays good until it is refilled."))
		return TRUE
	var/left = map.bill_settle(faction, B.serial, paid)
	map.treasury_log(faction, "[user.real_name] redeemed bill no. [B.serial] for [weighed_silver_text(paid)].")
	if (left <= 0)
		user.drop_from_inventory(B)
		qdel(B)
		to_chat(user, SPAN_NOTICE("The strongbox pays the bill: [weighed_silver_text(paid)]. The paid bill is torn up."))
	else
		to_chat(user, SPAN_NOTICE("The strongbox pays [weighed_silver_text(paid)]; it cannot pay the rest. [left] silver is still owed on the bill."))
	return TRUE

// Anyone may present a bill, member or not, open or locked.
/obj/structure/closet/crate/faction_strongbox/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/faction_bill) && length(faction))
		var/obj/item/faction_bill/B = W
		if (B.faction != faction)
			to_chat(user, SPAN_WARNING("This bill is drawn on [B.faction], not on [faction]."))
			return TRUE
		return redeem_bill(B, user)
	return ..()

#undef BILL_MAX
#undef BILLS_OPEN_MAX
#undef BILL_NOTES_MAX
