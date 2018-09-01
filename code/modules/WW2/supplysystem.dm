/obj/structure/supplybook
	name = "supply orders book"
	desc = "Use this to request supplies to be delivered to the colony."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	var/money = 0
	var/marketval = 0

/obj/structure/exportbook
	name = "exporting book"
	desc = "Use this to export colony products. Only merchants have access to it."
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
	if (H.original_job != "Merchant")
		H << "Only the merchants have access to the international shipping companies. Sell it to one."
		return
	else
		if (W.value == 0)
			H << "This has no value and can't be sold."
			return
		else
			if (istype(W, /obj/item/stack))
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				moneyin = marketval*W.amount
				money += moneyin
				qdel(W)
				return
			else
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				if (WWinput(H, "Sell this for [marketval]?", "Exporting", "Yes", list("Yes", "No")) == "Yes")
					money += marketval
					qdel(W)
					if (marketval <= 50)
						new/obj/item/stack/money/real(src, marketval)
			//				amount = marketval
					return
				else
					marketval = 0

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