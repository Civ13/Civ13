/obj/structure/supplybook
	name = "supply orders book"
	desc = "Use this to request supplies to be delivered to the colony."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	var/money = 0
	var/marketval = 0

/obj/structure/exportbook
	name = "exporting book"
	desc = "Use this to export colony products and exchange money. Only merchants have access to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook2"
	var/money = 0
	var/marketval = 0
	var/moneyin = 0

/obj/structure/supplybook/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (W.amount && istype(W, /obj/item/stack/money))
		money += W.value*W.amount
		qdel(W)
		return
	else
		H << "You need to use either money or other form of currency (gold, pearls, valuable items)."
		return

/obj/structure/exportbook/attackby(var/obj/item/W as obj, var/mob/living/carbon/human/H as mob)
	if (H.original_job_title != "Merchant")
		H << "Only the merchants have access to the international shipping companies. Sell it to one."
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