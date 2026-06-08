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
	var/orderfiat_id = null

	var/moneyin = 0
	var/accepted_currency = "standard"
	var/owner = "Global"

	var/image/overlay_primary = null
	var/image/overlay_secondary = null

/** Initializes the supplier stall and sets up company-colored visual overlays. */
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

/** Refreshes the visual overlays based on the current company colors of the owner. */
/obj/structure/supplier/update_icon()
	overlays.Cut()
	if (overlay_primary && overlay_secondary)
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary.color = map.custom_company_colors[owner][2]
		overlays += overlay_primary
		overlays += overlay_secondary

/** Logic for stall maintenance, adding operating funds, configuring new buy orders, or selling items to the stall. */
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
				to_chat(user, "<span class='notice'>You [anchored? "un" : ""]secured \the [src]!</span>")
				anchored = !anchored
			return
	else if (find_company_member(user,owner))
		if (istype(W, /obj/item/stack/money))
			var/can_buy = FALSE
			if (istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/F = W
				if (F.fiat_id != accepted_currency)
					can_buy = TRUE
			else
				if (accepted_currency != "standard")
					can_buy = TRUE

			if (!ordertype && can_buy)
				var/choice = alert(user, "Do you want to add a buying order for [W]?", "Stall Management", "Yes", "No")
				if (choice == "Yes")
					var/price_unit_label = accepted_currency == "standard" ? "standard coins" : fiat.currency_list[accepted_currency][1]
					var/choice2 = input(user,"What price per unit, in [price_unit_label]?", "Stall Management", 1) as num
					if (choice2 <= 0)
						return
					if (choice2 > 100000)
						choice2 = 100000
					var/choice3 = input(user,"How many units do you want to buy?", "Stall Management", 1) as num
					if (choice3 <= 0)
						return
					orderprice = choice2
					orderamount = round(choice3)
					if (istype(W, /obj/item/stack/money/fiat))
						var/obj/item/stack/money/fiat/F = W
						ordertype = /obj/item/stack/money/fiat
						ordername = F.name
						orderfiat_id = F.fiat_id
					else
						ordertype = /obj/item/stack/money
						ordername = "standard coins"
						orderfiat_id = null
					to_chat(user, "<span class='notice'>Buy order created: buying [orderamount] [ordername] at [orderprice] [price_unit_label] each.</span>")
					return

			if (accepted_currency == "standard" && istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/FI = W
				user.drop_from_inventory(FI)
				FI.forceMove(src)
				to_chat(user, "<span class='notice'>You store the [FI] in the stall's inventory.</span>")
				return
			else if (accepted_currency != "standard" && istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/FI = W
				if (FI.fiat_id != accepted_currency)
					user.drop_from_inventory(FI)
					FI.forceMove(src)
					to_chat(user, "<span class='notice'>You store the [FI] in the stall's inventory.</span>")
					return
			else if (accepted_currency != "standard" && !istype(W, /obj/item/stack/money/fiat))
				to_chat(user, "<span class='warning'>This stall only accepts [fiat.currency_list[accepted_currency][1]] as operating funds. Use standard coins to stock inventory.</span>")
				return

			var/obj/item/stack/money/M = W
			if (accepted_currency == "standard")
				moneyin += M.value * M.amount
				to_chat(user, "You add the money to the stall. It now has [moneyin] in standard coin value to fulfill orders.")
			else
				moneyin += M.amount
				to_chat(user, "You add the money to the stall. It now has [moneyin] [fiat.currency_list[accepted_currency][1]] to fulfill orders.")
			qdel(W)
			return
		else if (!ordertype)
			var/choice = alert(user, "Do you want to add a buying order for [W]?", "Stall Management", "Yes", "No")
			if (choice == "No")
				return
			else
				var/price_unit_label = accepted_currency == "standard" ? "standard coins" : fiat.currency_list[accepted_currency][1]
				var/choice2 = input(user,"What price per unit, in [price_unit_label]? This stall will keep accepting orders until it runs out of money.", "Stall Management", orderprice) as num
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
		if (W.type == ordertype || (orderfiat_id == null && ordertype == /obj/item/stack/money && istype(W, /obj/item/stack/money) && !istype(W, /obj/item/stack/money/fiat)))
			if (istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/WF = W
				if (WF.fiat_id != orderfiat_id)
					to_chat(user, "<span class='warning'>The [src] is buying [ordername], not [WF.name].</span>")
					return
			if (istype(W, /obj/item/stack))
				if (orderamount < 1)
					to_chat(user, "<span class='warning'>The [src] is not currently buying.</span>")
					return
				var/obj/item/stack/WS = W
				var/max_affordable = orderprice > 0 ? floor(moneyin / orderprice) : orderamount
				var/limit_qty = min(orderamount, max_affordable)
				if (limit_qty < 1)
					if (moneyin < orderprice)
						to_chat(user, "<span class='warning'>The [src] has no money left to buy from you!</span>")
					else
						to_chat(user, "<span class='warning'>The [src] is not currently buying.</span>")
					return

				var/buy_qty = min(WS.amount, limit_qty)
				if (buy_qty < 1)
					return

				var/payment = orderprice * buy_qty
				if (buy_qty == WS.amount)
					user.drop_from_inventory(WS)
					WS.forceMove(src)
				else
					var/obj/item/stack/NST = WS.split(buy_qty)
					if (NST)
						NST.forceMove(src)
					else
						user.drop_from_inventory(WS)
						WS.forceMove(src)

				if (accepted_currency == "standard")
					if (payment > 0 && payment <= 3)
						var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
						NM.amount = floor(payment/NM.value)
					else if (payment > 3 && payment <= 40)
						var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
						NM.amount = floor(payment/NM.value)
					else if (payment > 40)
						var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
						NM.amount = floor(payment/NM.value)
				else
					new/obj/item/stack/money/fiat(loc, payment, accepted_currency)

				moneyin -= payment
				orderamount -= buy_qty
				to_chat(user, "<span class='notice'>You sell [buy_qty] [ordername].</span>")
				return
			else
				if (orderamount < 1)
					to_chat(user, "<span class='warning'>The [src] is not currently buying.</span>")
					return
				if (moneyin >= orderprice)
					user.drop_from_inventory(W)
					W.forceMove(src)
					if (accepted_currency == "standard")
						if (orderprice > 0 && orderprice <= 3)
							var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
							NM.amount = orderprice/NM.value
						else if (orderprice > 3 && orderprice <= 40)
							var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
							NM.amount = orderprice/NM.value
						else
							var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
							NM.amount = orderprice/NM.value
					else
						new/obj/item/stack/money/fiat(loc, orderprice, accepted_currency)
					moneyin -= orderprice
					orderamount -= 1
					to_chat(user, "<span class='notice'>You sell the [W].</span>")
					return
				else
					to_chat(user, "<span class='warning'>The [src] has no money left to buy from you!</span>")
					return
	return

/** Management interface for company members to configure buy orders, name, currency, and withdraw operating funds. */
/obj/structure/supplier/attack_hand(mob/living/human/H as mob)
	if (find_company_member(H,owner))
		show_ui(H)
	else
		var/currency_name = accepted_currency == "standard" ? "sc" : fiat.currency_list[accepted_currency][1]
		to_chat(H, "<big>This company is currently buying [orderamount] of [ordername] for [orderprice] [currency_name] per unit.</big>")

/obj/structure/supplier/proc/show_ui(mob/living/human/H)
	if (!H || !H.client)
		return

	var/currency_name = accepted_currency == "standard" ? "standard coins" : fiat.currency_list[accepted_currency][1]

	// Build currency dropdown
	var/cur_opts = "<option value='standard'>Standard Coins</option>"
	for (var/fid in fiat.currency_list)
		if (fiat.currency_list[fid][5])
			var/sel = (accepted_currency == fid) ? " selected" : ""
			cur_opts += "<option value='[fid]'[sel]>[fiat.currency_list[fid][1]]</option>"

	var/has_order = (ordertype != null && orderamount > 0)

	var/dat = "<html><head><style>"
	dat += "body{font-family:'Segoe UI',monospace;background:#2b1e0e;color:#f0e0c0;margin:0;padding:20px;}"
	dat += "h2{color:#ffd700;border-bottom:2px solid #5a3a1a;padding-bottom:8px;margin-top:0;}"
	dat += ".section{background:#3d2b14;border:1px solid #5a3a1a;border-radius:4px;padding:12px;margin-bottom:12px;}"
	dat += ".section h3{color:#ffd700;margin:0 0 8px 0;font-size:14px;}"
	dat += ".info{font-size:13px;padding:4px 0;}"
	dat += ".info b{color:#b09070;}"
	dat += ".item{background:#2b1e0e;border:1px solid #5a3a1a;border-radius:3px;padding:8px 10px;margin:4px 0;font-size:13px;}"
	dat += ".num{width:80px;background:#2b1e0e;color:#f0e0c0;border:1px solid #5a3a1a;border-radius:2px;padding:3px 5px;font-family:monospace;font-size:12px;}"
	dat += "select{background:#2b1e0e;color:#f0e0c0;border:1px solid #5a3a1a;border-radius:2px;padding:3px 5px;font-family:monospace;font-size:12px;}"
	dat += ".btn{background:#5a3a1a;color:#ffd700;border:1px solid #5a3a1a;border-radius:3px;padding:4px 10px;cursor:pointer;font-size:12px;text-decoration:none;}"
	dat += ".btn:hover{background:#8a6a3a;}"
	dat += ".btn-danger{background:#5e2a2a;color:#ff7070;border:1px solid #8a3a3a;}"
	dat += ".btn-danger:hover{background:#8a3a3a;}"
	dat += "</style></head><body>"
	dat += "<h2>Supply Stall — [name]</h2>"

	// Current order info
	dat += "<div class='section'><h3>Current Buy Order</h3>"
	if (has_order)
		dat += "<div class='info'><b>Buying:</b> [orderamount]x [ordername] at [orderprice] [currency_name] each</div>"
	else
		dat += "<div class='info' style='color:#707090;font-style:italic;'>No active buy order.</div>"
	dat += "<div class='info'><b>Available funds:</b> [moneyin] [currency_name]</div></div>"

	// Name
	dat += "<div class='section'><h3>Name</h3>"
	dat += "<div class='item'><input type='text' id='new_name' class='num' style='width:200px;' value='[name]' placeholder='Enter new name...'> "
	dat += "<button class='btn' onclick=\"var v=document.getElementById('new_name').value;if(v)window.location='byond://?src=\ref[src];rename='+encodeURIComponent(v)\">Change Name</button></div></div>"

	// Order settings
	dat += "<div class='section'><h3>Order Settings</h3>"
	dat += "<div class='item'><b>Price per unit:</b> [orderprice] [currency_name] "
	dat += "<button class='btn' onclick=\"var v=prompt('Price per unit in [currency_name]:','[orderprice]');if(v!==null&&!isNaN(v)&&Number(v)>=0&&Number(v)<=100000)window.location='byond://?src=\ref[src];changeprice='+v\">Change</button></div>"
	dat += "<div class='item'><b>Amount to buy:</b> [orderamount] "
	dat += "<button class='btn' onclick=\"var v=prompt('How many units to buy?','[orderamount]');if(v!==null&&!isNaN(v)&&Number(v)>=0)window.location='byond://?src=\ref[src];changeamount='+v\">Change</button></div>"
	dat += "<div class='item'><b>Currency:</b> <select id='cur_select'>[cur_opts]</select> "
	dat += "<button class='btn' onclick=\"window.location='byond://?src=\ref[src];changecurrency='+document.getElementById('cur_select').value\">Apply</button></div>"
	dat += "<div class='item'><button class='btn btn-danger' onclick=\"window.location='byond://?src=\ref[src];removeorder'\">Remove Order</button>"
	if (has_order)
		dat += " <span style='color:#707090;font-size:11px;'>Clears the buy order.</span>"
	dat += "</div></div>"

	// Actions
	dat += "<div class='section'><h3>Actions</h3>"
	dat += "<div class='item'><button class='btn btn-danger' onclick=\"window.location='byond://?src=\ref[src];removeproducts'\">Remove Products Inside</button>"
	dat += " <span style='color:#707090;font-size:11px;'>Ejects all items stored in the stall.</span></div>"
	dat += "<div class='item'><button class='btn' onclick=\"window.location='byond://?src=\ref[src];removemoney'\">Remove Money</button>"
	if (moneyin > 0)
		dat += " <span style='color:#a0a0c0;font-size:11px;'>[moneyin] [currency_name] will be ejected.</span>"
	else
		dat += " <span style='color:#707090;font-size:11px;'>No funds to remove.</span>"
	dat += "</div></div>"

	dat += "<div class='section'><button class='btn' onclick=\"window.location='byond://?src=\ref[src];close'\">Close</button></div>"
	dat += "</body></html>"

	H << browse(dat, "window=supplystall;size=500x500")

/obj/structure/supplier/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || get_dist(src, H) > 2)
		return
	if (!find_company_member(H, owner))
		return

	if (href_list["close"])
		return

	if (href_list["rename"])
		var/new_name = href_list["rename"]
		if (new_name && new_name != "")
			name = new_name
		return

	if (href_list["changeprice"])
		var/val = text2num(href_list["changeprice"])
		if (isnull(val))
			return
		if (val < 0) val = 0
		if (val > 100000) val = 100000
		orderprice = val
		return

	if (href_list["changeamount"])
		var/val = text2num(href_list["changeamount"])
		if (isnull(val) || val < 0)
			return
		orderamount = round(val)
		return

	if (href_list["changecurrency"])
		var/new_cur = href_list["changecurrency"]
		if (!new_cur)
			return
		if (moneyin > 0)
			to_chat(H, "<span class='warning'>You must remove all money from the stall before changing the accepted currency!</span>")
			return
		accepted_currency = new_cur
		return

	if (href_list["removeorder"])
		ordertype = null
		ordername = ""
		orderprice = 0
		orderamount = 0
		orderfiat_id = null
		to_chat(H, "<span class='notice'>Buy order removed.</span>")
		return

	if (href_list["removeproducts"])
		for (var/obj/item/I in src)
			I.forceMove(loc)
		to_chat(H, "<span class='notice'>You empty the stall.</span>")
		return

	if (href_list["removemoney"])
		if (moneyin <= 0)
			return
		if (accepted_currency == "standard")
			if (moneyin > 0 && moneyin <= 3)
				var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
				NM.amount = moneyin/NM.value
			else if (moneyin > 3 && moneyin <= 40)
				var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
				NM.amount = moneyin/NM.value
			else
				var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
				NM.amount = moneyin/NM.value
		else
			new/obj/item/stack/money/fiat(loc, moneyin, accepted_currency)
		moneyin = 0
		to_chat(H, "<span class='notice'>Money removed from stall.</span>")
		return
