// a "reverse" market stall/vending machine, where you put buy orders and people can sell to you.

/obj/structure/supplier
	name = "supply stall"
	desc = "A market stall where you can fulfill this company supply orders."
	icon = 'icons/obj/vending.dmi'
	icon_state = "supply_stall"
	layer = 2.9
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

	var/ordertype = null
	var/orderprice = 0
	var/orderamount = 0
	var/ordername = ""

	var/moneyin = 0
	var/owner = "Global"

	var/image/overlay_primary = null
	var/image/overlay_secondary = null

/obj/structure/supplier/New()
	..()
	invisibility = 101
	spawn(3)
		overlay_primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
		overlay_secondary.color = map.custom_company_colors[owner][2]
		overlays += overlay_primary
		overlays += overlay_secondary
		update_icon()
		invisibility = 0

/obj/structure/supplier/update_icon()
	overlays.Cut()
	if (overlay_primary && overlay_secondary)
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary.color = map.custom_company_colors[owner][2]
		overlays += overlay_primary
		overlays += overlay_secondary

/obj/structure/supplier/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench))
		if (owner != "Global" && find_company_member(user,owner))
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (anchored)
				user.visible_message("[user] begins unsecuring \the [src] from the floor.", "You start unsecuring \the [src] from the floor.")
			else
				user.visible_message("[user] begins securing \the [src] to the floor.", "You start securing \the [src] to the floor.")

			if (do_after(user, 20, src))
				if (!src) return
				user << "<span class='notice'>You [anchored? "un" : ""]secured \the [src]!</span>"
				anchored = !anchored
			return
	else if (find_company_member(user,owner))
		if (istype(W, /obj/item/stack/money))
			var/obj/item/stack/money/M = W
			moneyin += M.value*M.amount
			qdel(W)
			user << "You add the money to the stall. It now has [moneyin] silver coins to fulfill orders."
			return
		else if (!ordertype)
			var/choice = WWinput(user,"Do you want to add a buying order for [W]?", "Stall Management", "Yes", list("Yes","No"))
			if (choice == "No")
				return
			else
				var/choice2 = input(user,"What price per unit, in silver coins? This stall will keep accepting orders until it runs out of money.", "Stall Management", orderprice) as num
				if (choice2 < 0)
					choice2 = 0
				else if (choice2 > 100000)
					choice2 = 100000
				orderprice = choice2
				var/choice3 = input(user,"How much do you want to buy? This stall will keep accepting orders until it runs out of money.", "Stall Management", moneyin) as num
				if (choice3 < 0)
					choice3 = 0
				else if (moneyin < orderamount*choice3)
					orderamount = round(moneyin/choice3)
				else
					orderamount = choice3
				ordertype = W.type
				ordername = W.name
				return
	else
		if (W.type == ordertype)
			if (istype(W, /obj/item/stack))
				if (orderamount < 1)
					user << "<span class='warning'>The [src] is not currently buying.</span>"
					return
				var/obj/item/stack/WS = W
				if (moneyin >= orderprice*WS.amount)
					user.drop_from_inventory(WS)
					if (orderamount >= WS.amount)
						var/obj/item/stack/NST = WS.split(orderamount)
						if (NST)
							NST.forceMove(src)
					else
						WS.forceMove(src)
					if (orderprice*WS.amount > 0 && orderprice*WS.amount <= 3)
						var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
						NM.amount = (orderprice*WS.amount)/NM.value
					else if (orderprice*WS.amount > 3 && orderprice*WS.amount <= 40)
						var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
						NM.amount = (orderprice*WS.amount)/NM.value
					else
						var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
						NM.amount = (orderprice*WS.amount)/NM.value
					moneyin -= orderprice*WS.amount
					orderamount -= WS.amount
					user << "<span class='notice'>You sell the [W].</span>"
					return
				else
					user << "<span class='warning'>The [src] has no money left to buy from you!</span>"
					return
			else
				if (orderamount < 1)
					user << "<span class='warning'>The [src] is not currently buying.</span>"
					return
				if (moneyin >= orderprice)
					user.drop_from_inventory(W)
					W.forceMove(src)
					if (orderprice > 0 && orderprice <= 3)
						var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
						NM.amount = orderprice/NM.value
					else if (orderprice > 3 && orderprice <= 40)
						var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
						NM.amount = orderprice/NM.value
					else
						var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
						NM.amount = orderprice/NM.value
					moneyin -= orderprice
					orderamount -= 1
					user << "<span class='notice'>You sell the [W].</span>"
					return
				else
					user << "<span class='warning'>The [src] has no money left to buy from you!</span>"
					return
	return
/obj/structure/supplier/attack_hand(mob/living/human/H as mob)
	if (find_company_member(H,owner))
		var/choice = WWinput(H,"What do you want to do?", "Stall Management", "Cancel", list("Change Name", "Remove Products Inside", "Change Amount", "Change Price", "Remove Order", "Remove Money", "Cancel"))
		if (choice == "Cancel")
			H << "<big>This company is currently buying [orderamount] of [ordername] for [orderprice] per unit. It has [moneyin] silver coins inside.</big>"
			return
		else if (choice == "Remove Products Inside")
			for(var/obj/item/I in src)
				I.forceMove(loc)
			H << "<span class='notice'>You empty the stall.</span>"
			return
		else if (choice == "Change Name")
			var/input1 = input(H,"What name do you want to give to this vendor?", "Vendor Name", name) as text
			if (input1 == null || input1 == "")
				return FALSE
			else
				name = input1
				return TRUE
		else if (choice == "Remove Money")
			if (moneyin > 0 && moneyin <= 3)
				var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
				NM.amount = moneyin/NM.value
			else if (moneyin > 3 && moneyin <= 40)
				var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
				NM.amount = moneyin/NM.value
			else
				var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
				NM.amount = moneyin/NM.value
			moneyin = 0
			return
		else if (choice == "Remove Order")
			ordertype = null
			ordername = ""
			orderprice = 0
			orderamount = 0
		else if (choice == "Change Price")
			var/choice2 = input(H,"What price per unit, in silver coins? This stall will keep accepting orders until it runs out of money.", "Stall Management", orderprice) as num
			if (choice2 < 0)
				choice2 = 0
			else if (choice2 > 100000)
				choice2 = 100000
			orderprice = choice2
			return
		else if (choice == "Change Amount")
			var/choice3 = input(H,"How much do you want to buy? This stall will keep accepting orders until it runs out of money.", "Stall Management", moneyin) as num
			if (choice3 < 0)
				choice3 = 0
			else if (moneyin < orderamount*choice3)
				orderamount = round(moneyin/choice3)
			else
				orderamount = choice3
			return
	H << "<big>This company is currently buying [orderamount] of [ordername] for [orderprice] sc per unit.</big>"
	return
