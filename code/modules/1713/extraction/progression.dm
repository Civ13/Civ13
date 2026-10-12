// Bounded game-only currency and fixed offers. Private account snapshots own
// both payment and product; external bot balances are never read or written.
/obj/map_metadata/extraction_survival/proc/supply_catalog()
	return list("Wooden handle" = list("type" = /obj/item/weapon/material/handle, "price" = 10, "level" = 1), "Iron pickaxe head" = list("type" = /obj/item/weapon/material/part/pickaxe, "material" = "iron", "price" = 20, "level" = 1), "Iron shovel head" = list("type" = /obj/item/weapon/material/part/shovel, "material" = "iron", "price" = 20, "level" = 1), "Iron hatchet head" = list("type" = /obj/item/weapon/material/part/axehead/hatchet, "material" = "iron", "price" = 20, "level" = 1), "Cloth bundle" = list("type" = /obj/item/stack/material/cloth, "amount" = 10, "price" = 20, "level" = 1), "Binding cord" = list("type" = /obj/item/stack/material/rope, "amount" = 10, "price" = 20, "level" = 1), "Steel sheets" = list("type" = /obj/item/stack/material/steel, "amount" = 10, "price" = 30, "level" = 2), "Wood bundle" = list("type" = /obj/item/stack/material/wood, "amount" = 10, "price" = 10, "level" = 1), "AKM rifle" = list("type" = /obj/item/weapon/gun/projectile/submachinegun/ak47, "price" = 120, "level" = 2), "AKM magazine" = list("type" = /obj/item/ammo_magazine/ak47, "price" = 20, "level" = 1), "M9 magazine" = list("type" = /obj/item/ammo_magazine/m9beretta, "price" = 10, "level" = 1), "PASGT helmet" = list("type" = /obj/item/clothing/head/helmet/modern/pasgt, "price" = 50, "level" = 2), "Carrier vest" = list("type" = /obj/item/clothing/accessory/armor/nomads/pcarrierblack, "price" = 80, "level" = 2), "Gasoline jerrycan" = list("type" = /obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline, "price" = 30, "level" = 2))

/obj/map_metadata/extraction_survival/proc/supply_access(mob/living/human/H)
	if (!owned(H) || H.stat != CONSCIOUS) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	return !S.transitioning && S.profile["state"] == "home" && S.house && H.z == S.house.z && H.Adjacent(S.house)

/obj/map_metadata/extraction_survival/proc/game_credits(datum/extraction_session/S)
	return isnull(S.profile["credits"]) ? 0 : S.profile["credits"]

/obj/map_metadata/extraction_survival/proc/confirm_supplies(mob/living/human/H, offer, price)
	return WWinput(H, "Buy [offer] for [price] game credits? Items arrive in your private room. These credits are separate from Discord currency.", "Safe-house supplies", "Cancel", list("Buy", "Cancel")) == "Buy"

/obj/map_metadata/extraction_survival/proc/exchange_salvage(mob/living/human/H)
	if (!supply_access(H) || !save_home(H.extraction_session)) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (game_credits(S) > 999990) return FALSE
	var/obj/item/extraction_salvage/payment
	for (var/obj/item/extraction_salvage/I in home_roots(S))
		if (!I.extraction_insurance_token && !I.contents.len)
			payment = I
			break
	if (!payment) return FALSE
	var/list/candidate = S.copy_profile()
	var/list/remaining = list()
	var/found = FALSE
	for (var/list/entry in candidate["stash"])
		if (entry["id"] == payment.extraction_item_id) found = TRUE
		else remaining += list(entry)
	if (!found) return FALSE
	candidate["stash"] = remaining
	candidate["credits"] = game_credits(S) + 10
	if (!S.commit(candidate)) return FALSE
	if (payment.loc == H) H.unEquip(payment, TRUE)
	qdel(payment)
	to_chat(H, "One workshop part exchanged. Balance: [game_credits(S)] game credits.")
	return TRUE

/obj/map_metadata/extraction_survival/proc/buy_supplies(mob/living/human/H, choice)
	if (!supply_access(H) || !save_home(H.extraction_session)) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	var/list/offer = supply_catalog()[choice]
	if (!islist(offer) || S.profile["level"] < offer["level"] || game_credits(S) < offer["price"] || S.profile["stash"].len >= S.capacity()) return FALSE
	var/digest = md5(json_encode(S.profile))
	if (!confirm_supplies(H, choice, offer["price"]) || !supply_access(H) || md5(json_encode(S.profile)) != digest || json_encode(records(home_roots(S))) != json_encode(S.profile["stash"])) return FALSE
	S.transitioning = TRUE
	var/path = offer["type"]
	var/obj/item/product = new path(null, offer["material"])
	if (istype(product, /obj/item/stack/material)) product:amount = offer["amount"]
	var/list/entry = record_item(product)
	if (!entry || !codec.validate(entry["equipment"]))
		if (product) qdel(product)
		S.transitioning = FALSE
		return FALSE
	var/list/candidate = S.copy_profile()
	candidate["credits"] = game_credits(S) - offer["price"]
	candidate["stash"] += list(entry)
	if (!S.commit(candidate))
		qdel(product)
		S.transitioning = FALSE
		return FALSE
	// The complete product graph is committed before its original atoms appear.
	product.forceMove(get_turf(S.house))
	S.transitioning = FALSE
	to_chat(H, "[choice] delivered. Balance: [game_credits(S)] game credits.")
	return TRUE

/obj/map_metadata/extraction_survival/proc/manage_supplies(mob/living/human/H)
	if (!supply_access(H)) return
	var/choice = WWinput(H, "Balance: [game_credits(H.extraction_session)] game credits. Exchange one uninsured workshop part for ten credits, or buy supplies. House level gates advanced gear and fuel.", "Safe-house supplies", "Cancel", list("Exchange one part", "Buy", "Cancel"))
	if (!supply_access(H)) return
	if (choice == "Exchange one part") exchange_salvage(H)
	else if (choice == "Buy")
		var/list/offers = supply_catalog()
		var/list/options = list()
		for (var/label in offers) options["[label] - [offers[label]["price"]] credits, house [offers[label]["level"]]"] = label
		var/selected = WWinput(H, "Choose supplies. The final price is confirmed before payment.", "Supply catalog", "Cancel", options + list("Cancel"))
		if (options[selected]) buy_supplies(H, options[selected])
