/*
 * Product datum
 */
/datum/product_import
	var/title = "ERROR"
	var/result_type = null
	var/cratevalue = 1
	var/nr = 1

	New(_title, _result_type, _cratevalue = 1, _nr)
		title = _title
		result_type = _result_type
		cratevalue = _cratevalue
		nr = _nr


////////////////////////////////////////////////////////////////////////////////////



/obj/structure/supplybook
	name = "supply orders book"
	desc = "Use this to request supplies to be delivered to the colony. Only merchants have access to it and only the governor can order ammunition."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	var/money = 0
	var/marketval = 0
	var/list/itemstobuy = list(
		new/datum/product_import("wood crate","/obj/structure/closet/crate/wood", 120, 1),
		new/datum/product_import("iron crate","/obj/structure/closet/crate/iron", 330, 2),
		new/datum/product_import("glass crate","/obj/structure/closet/crate/glass", 330, 3),
		new/datum/product_import("vegetables crate","/obj/structure/closet/crate/rations/vegetables", 60, 4),
		new/datum/product_import("fruits crate","/obj/structure/closet/crate/rations/fruits", 66, 5),
		new/datum/product_import("biscuits crate","/obj/structure/closet/crate/rations/biscuits", 50, 6),
		new/datum/product_import("beer crate","/obj/structure/closet/crate/rations/beer", 60, 7),
		new/datum/product_import("ale crate","/obj/structure/closet/crate/rations/ale", 70, 8),
		new/datum/product_import("meat crate","/obj/structure/closet/crate/rations/meat", 70, 9),
		new/datum/product_import("tree seeds crate","/obj/structure/closet/crate/rations/seeds/trees", 20, 10),
		new/datum/product_import("vegetable seeds crate","/obj/structure/closet/crate/rations/seeds/vegetables", 30, 11),
		new/datum/product_import("cereal seeds crate","/obj/structure/closet/crate/rations/seeds/cereals", 20, 12),
		new/datum/product_import("cash crops crate","/obj/structure/closet/crate/rations/seeds/cashcrops", 40, 13),
		new/datum/product_import("musket ammo crate (25)","/obj/structure/closet/crate/musketball",100, 14),
		new/datum/product_import("pistol ammo crate (25)","/obj/structure/closet/crate/musketball_pistol",60, 15),
		new/datum/product_import("blunderbuss crate (15)","/obj/structure/closet/crate/blunderbuss_ammo",60, 16),
		new/datum/product_import("grenade crate (10)","/obj/structure/closet/crate/grenades",110, 17),
		new/datum/product_import("cannonball crate (10)","/obj/structure/closet/crate/cannonball",175, 18),)


/obj/structure/exportbook
	name = "exporting book"
	desc = "Use this to export colony products and exchange money. Only merchants and governors have access to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook2"
	var/money = 0
	var/marketval = 0
	var/moneyin = 0

/obj/structure/supplybook/attack_hand(var/mob/living/carbon/human/user as mob)
	if (user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor" && user.original_job_title != "British Merchant"  && user.original_job_title != "Merchant" && user.original_job_title != "Mercador" && user.original_job_title != "Comerciante" && user.original_job_title != "Marchand")
		user << "Only the merchants have access to the international shipping companies. Negotiate with one."
		return

	var/list/display //The products to be displayed, includes name of crate and price
	for (var/i=1;i<=itemstobuy.len,i++)
		display += "[itemstobuy[i].nr]: [itemstobuy[i].title] - [itemstobuy[i].cratevalue] reales" //Simplicity so the crate's name can be shown in the list
	var/choice = input(user, "What do you want to purchase?") in display + "Cancel"
	if(choice == "Cancel")
		return
	else
		var/list/choicename = splittext(choice, ":")
		var/finalnr = text2num(choicename[1])

		if ((user.original_job_title != "Gobernador" && user.original_job_title != "Governador" && user.original_job_title != "Governeur" && user.original_job_title != "Governor" && user.original_job_title != "British Governor") && finalnr > 13)
			user << "Only Governors can order military supplies!"
			return
		if(itemstobuy[finalnr].cratevalue < money)
			user << "You don't have enough money to buy that crate!"
// giving change back
			if (money <= 50 && money > 0)
				new/obj/item/stack/money/real(loc, money)
				money = 0
				return
			else if (money > 50 && money <= 400)
				new/obj/item/stack/money/dollar(loc, money/8)
				money = 0
				return
			else if (money > 400 && money <= 800)
				new/obj/item/stack/money/escudo(loc, money/16)
				money = 0
				return
			else if (money > 800 && money <= 1600)
				new/obj/item/stack/money/doubloon(loc, money/32)
				money = 0
				return
			else if (money == 0)
				return
			else if (money > 1600)
				user << "Too much money to pay you back! Buy something else to reduce the money deposited."
				return
		else
			money -= itemstobuy[finalnr].cratevalue
			user << "You have successfully purchased the crate. It will arrive soon."
			spawn(600)
				var/keypath = text2path("[itemstobuy[finalnr].result_type]")
				new keypath()
// giving change back
			if (money <= 50 && money > 0)
				new/obj/item/stack/money/real(loc, money)
				money = 0
				return
			else if (money > 50 && money <= 400)
				new/obj/item/stack/money/dollar(loc, money/8)
				money = 0
				return
			else if (money > 400 && money <= 800)
				new/obj/item/stack/money/escudo(loc, money/16)
				money = 0
				return
			else if (money > 800 && money <= 1600)
				new/obj/item/stack/money/doubloon(loc, money/32)
				money = 0
				return
			else if (money == 0)
				return
			else if (money > 1600)
				user << "Too much money to pay you back! Buy something else to reduce the money deposited."
				return

/obj/structure/supplybook/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (W.amount && istype(W, /obj/item/stack/money))
		money += W.value*W.amount
		qdel(W)
		return
	else
		H << "You need to use either money or another form of currency (gold, pearls, valuable items)."
		return

/obj/structure/exportbook/attackby(var/obj/item/W as obj, var/mob/living/carbon/human/H as mob)
	if (H.original_job_title != "British Merchant"  && H.original_job_title != "Merchant" && H.original_job_title != "Mercador" && H.original_job_title != "Comerciante" && H.original_job_title != "Marchand")

		H << "Only the merchants have access to the international shipping companies. Negotiate with one."
		return
	else
		if (W.value == 0)
			H << "There is no demand for this item."
			return
		else
			if (istype(W, /obj/item/stack/money))
				marketval = W.value
				moneyin = marketval*W.amount
				if (WWinput(H, "Exchange this amount into other coins?", "Exporting", "Yes", list("Yes", "No")) == "Yes")
					if (moneyin <= 50)
						new/obj/item/stack/money/real(loc, moneyin)
						qdel(W)
						return
					else if (moneyin > 50 && moneyin <= 400)
						new/obj/item/stack/money/dollar(loc, moneyin/8)
						qdel(W)
						return
					else if (moneyin > 400 && moneyin <= 800)
						new/obj/item/stack/money/escudo(loc, moneyin/16)
						qdel(W)
						return
					else if (moneyin > 800 && moneyin <= 1600)
						new/obj/item/stack/money/doubloon(loc, moneyin/32)
						qdel(W)
						return
					else if (moneyin > 1600)
						H << "Too much money! Split it into smaller stacks first."
						return
				else
					marketval = 0
					return
			if (istype(W, /obj/item/stack))
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				moneyin = marketval*W.amount
				if (WWinput(H, "Sell the whole stack for [moneyin] reales?", "Exporting", "Yes", list("Yes", "No")) == "Yes")
					if (moneyin <= 50)
						new/obj/item/stack/money/real(loc, moneyin)
						qdel(W)
						return
					else if (moneyin > 50 && moneyin <= 400)
						new/obj/item/stack/money/dollar(loc, moneyin/8)
						qdel(W)
						return
					else if (moneyin > 400 && moneyin <= 800)
						new/obj/item/stack/money/escudo(loc, moneyin/16)
						qdel(W)
						return
					else if (moneyin > 800 && moneyin <= 1600)
						new/obj/item/stack/money/doubloon(loc, moneyin/32)
						qdel(W)
						return
					else if (moneyin > 1600)
						H << "This item is too expensive! You can't find a buyer for it."
						return
				else
					marketval = 0
					return
			else
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				if (WWinput(H, "Sell this for [marketval] reales?", "Exporting", "Yes", list("Yes", "No")) == "Yes")
					if (marketval <= 50)
						new/obj/item/stack/money/real(loc, marketval)
						qdel(W)
						return
					else if (marketval > 50 && marketval <= 400)
						new/obj/item/stack/money/dollar(loc, marketval/8)
						qdel(W)
						return
					else if (marketval > 400 && marketval <= 800)
						new/obj/item/stack/money/escudo(loc, marketval/16)
						qdel(W)
						return
					else if (marketval > 800 && marketval <= 1600)
						new/obj/item/stack/money/doubloon(loc, marketval/32)
						qdel(W)
						return
					else if (marketval > 1600)
						H << "This item is too expensive! You can't find a buyer for it."
						return
				else
					marketval = 0
					return

/* For reference
/obj/item/stack/money/real
	value = 1

/obj/item/stack/money/dollar
	value = 8

/obj/item/stack/money/escudo
	value = 16

/obj/item/stack/money/doubloon
	value = 32

/obj/item/stack/money/goldnugget
	value = 96

/obj/item/stack/money/goldvaluables
	value = 48

/obj/item/stack/money/gems
	value = 35

/obj/item/stack/money/pearls
	value = 45
*/
