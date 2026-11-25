
////////////////////////FUEL PUMP//////////////////////////////////
/obj/structure/fuelpump
	name = "fuel pump"
	desc = "A fuel pump. You need to pay to use it."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "oilpump1"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

	var/price = 0 //price per unit
	var/fueltype = "none"

	var/maxvol = 300 //maximum fuel inside
	var/vol = 0 //current fuel inside
	var/unlockedvol = 0 //fuel that can be withdrown, after purchase
	var/list/storedval = list() //money inside
	var/unlocked = 0

	var/customcolor = 0
	var/owner = "Global"

/obj/structure/fuelpump/bullet_act(var/obj/item/projectile/proj, def_zone)
	if (!vol)
		return ..(proj, def_zone)
	if (vol >= 10)
		if (prob(20))
			visible_message("<span class = 'warning'>\The [src] explodes!</span>")
			explosion(loc, 1, 2, 2, 0)
			qdel(src)
		else
			return FALSE
	return TRUE

/obj/structure/fuelpump/premade
	name = "fuel pump"
	price = 3
	owner = "Global"
	var/brand = "UngOil"
	icon_state = "oilpump3"
	customcolor = "#3cb44b"
	maxvol = 1000
/obj/structure/fuelpump/premade/New()
	..()
	// A load restores the saved fuel and stock. Re-rolled here, a pump saved
	// with the default fuel came back selling another one, refilled to the top.
	if (!restoring)
		fueltype = pick("gasoline","diesel","biodiesel","pethanol","petroleum")
		vol = maxvol
		name = "[brand] [fueltype] pump"
		price = 0.4
	do_color()
	if (!restoring)
		updatedesc()

/obj/structure/fuelpump/premade/gasoline/New()
	..()
	set_premade_fuel("gasoline")

/obj/structure/fuelpump/premade/diesel/New()
	..()
	set_premade_fuel("diesel")

/obj/structure/fuelpump/premade/proc/set_premade_fuel(new_fuel)
	fueltype = new_fuel
	name = "[brand] [fueltype] pump"
	updatedesc()

/obj/structure/fuelpump/premade/yamaha
	brand = "Yamaha Gas"
	icon_state = "oilpump1"
	customcolor = "#7F0000"

/obj/structure/fuelpump/premade/yamaha/gasoline/New()
	..()
	set_premade_fuel("gasoline")

/obj/structure/fuelpump/premade/yamaha/diesel/New()
	..()
	set_premade_fuel("diesel")

/obj/structure/fuelpump/n
	icon_state = "oilpump3"

/obj/structure/fuelpump/s
	icon_state = "oilpump4"

/obj/structure/fuelpump/small
	icon_state = "oilpump2"

/obj/structure/fuelpump/star
	icon_state = "oilpump1"

/obj/structure/fuelpump/proc/updatedesc()
	if (map.ID == MAP_THE_ART_OF_THE_DEAL)
		desc = "This pump has [vol] units of [fueltype] available. Price: [price/4] dollars per unit."
	else
		desc = "This pump has [vol] units of [fueltype] available. Price: [price] silver coins per unit. Copper and Gold accepted too."

/obj/structure/fuelpump/proc/do_color()
	if (customcolor)
		var/image/colorov = image("icon" = icon, "icon_state" = "[icon_state]mask")
		colorov.color = customcolor
		overlays += colorov

/obj/structure/fuelpump/attack_hand(var/mob/living/human/user)
	if (unlocked)
		if (unlockedvol>0)
			ui_interact(user, "confirm")
			return
		else
			to_chat(user, "You lock the pump, finishing the transaction.")
			unlocked = 0
			unlockedvol = 0
			return
	else
		to_chat(user, "Put money on the pump to use it.")
		return

/obj/structure/fuelpump/attackby(obj/item/weapon/W as obj, mob/user as mob)

	if (istype(W, /obj/item/stack/money))
		show_purchase_quote(user, W)
		return

	else if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/GC = W
		if (fueltype == "none")
			to_chat(user, "This fuel pump has no associated fuel type.")
			return
		if (unlocked && unlockedvol<=0)
			unlockedvol = 0
			to_chat(user, "All the paid for fuel has been used. Finish the transaction.")
			updatedesc()
			return
		if (unlocked && unlockedvol>0)
			var/avvol = GC.reagents.maximum_volume-GC.reagents.total_volume
			if (unlockedvol <= avvol)
				vol -= unlockedvol
				GC.reagents.add_reagent(fueltype,unlockedvol)
				to_chat(user, "You fill the [GC] with all the purchased [fueltype].")
				unlockedvol = 0
				updatedesc()
				return
			else if (unlockedvol > avvol)
				unlockedvol -= avvol
				vol -= avvol
				GC.reagents.add_reagent(fueltype,avvol)
				to_chat(user, "You fill the [GC] completely. There are [unlockedvol] units remaining in the pump.")
				updatedesc()
				return

		if (!unlocked)
			if (vol < maxvol)
				if (GC.reagents.has_reagent(fueltype))
					if (GC.reagents.get_reagent_amount(fueltype)<= maxvol-vol)
						vol += (GC.reagents.get_reagent_amount(fueltype))
						GC.reagents.del_reagent(fueltype)
						to_chat(user, "You empty \the [W] into \the [src].")
						updatedesc()
						return
					else
						var/amttransf = maxvol-vol
						vol += amttransf
						GC.reagents.remove_reagent(fueltype,amttransf)
						to_chat(user, "You fill \the [src] completely with \the [W].")
						updatedesc()
						return
				else
					to_chat(user, "\The [W] has no [fueltype] in it.")
					return
			else
				to_chat(user, "\The [src] is already full.")
				return
	else
		..()


/obj/structure/fuelpump/verb/Manage()
	set category = null
	set src in range(1)

	var/mob/living/human/user

	if (ishuman(usr))
		user = usr
	else
		return

	if (company_may_operate(user, owner))
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		show_manage_ui(user)
	else
		to_chat(user, "<span class = 'notice'>You are not part of [owner]!</span>")
		return

/obj/structure/fuelpump/proc/show_manage_ui(mob/user)
	ui_interact(user, "manage")

// The fuels a pump can be set to sell.
/obj/structure/fuelpump/proc/fuel_choices()
	return list("gasoline", "diesel", "biodiesel", "pethanol", "petroleum")

// Quote state belongs to one UI. Closing it drops the only reference to the quote.
/datum/topic_state/default/fuel_pump_purchase
	var/mob/living/human/buyer
	var/obj/item/stack/money/payment
	var/payment_count
	var/payment_value
	var/unit_price
	var/fuel
	var/units

/datum/topic_state/default/fuel_pump_purchase/New(mob/living/human/user, obj/item/stack/money/money, price, fuel_type)
	..()
	buyer = user
	payment = money
	payment_count = money.amount
	payment_value = money.value
	unit_price = price
	fuel = fuel_type
	units = payment_count * payment_value / unit_price

/obj/structure/fuelpump/proc/show_purchase_quote(mob/living/human/user, obj/item/stack/money/money)
	if (!istype(user) || user.stat || QDELETED(money) || money.loc != user || !user.item_is_in_hands(money))
		return
	// Reopening with another stack must not reinitialise the old quote state.
	GLOB.nanomanager.close_user_uis(user, src, "buy")
	if (unlocked)
		to_chat(user, "The pump is being used! Finish it first.")
		return
	if (price <= 0 || fueltype == "none" || money.amount <= 0 || money.value <= 0)
		to_chat(user, SPAN_NOTICE("This pump cannot accept that payment or is not set up to sell fuel."))
		return
	var/datum/topic_state/default/fuel_pump_purchase/quote = new(user, money, price, fueltype)
	if (quote.units > vol)
		to_chat(user, SPAN_NOTICE("The fuel pump cannot provide that much fuel. It has [vol] units of [fueltype]."))
		return
	ui_interact(user, "buy", quote = quote)

/obj/structure/fuelpump/proc/complete_purchase(mob/living/human/user, datum/topic_state/default/fuel_pump_purchase/quote)
	if (!istype(quote) || quote.buyer != user)
		return
	if (unlocked)
		to_chat(user, "The pump is being used! Finish it first.")
		return
	var/obj/item/stack/money/money = quote.payment
	if (QDELETED(money) || money.loc != user || !user.item_is_in_hands(money))
		to_chat(user, SPAN_NOTICE("You no longer have the quoted payment in your hands. Start a new purchase."))
		return
	if (price != quote.unit_price || fueltype != quote.fuel || money.amount != quote.payment_count || money.value != quote.payment_value || vol < quote.units)
		to_chat(user, SPAN_NOTICE("The fuel quote has changed. Start a new purchase before paying."))
		return
	if (!user.transfer_held_item_to(money, src))
		to_chat(user, SPAN_NOTICE("The pump could not accept your payment."))
		return
	money.forceMove(null)
	storedval += money
	unlockedvol = quote.units
	unlocked = TRUE
	to_chat(user, SPAN_NOTICE("You can now withdraw [unlockedvol] units of [fueltype] from this pump."))

// Every button sends "action" with the name of what it does.
/obj/structure/fuelpump/ui_actions(ui_key)
	return list("action")

// Three small windows: "buy" and "confirm" ask before a sale starts or ends,
// "manage" is the owner's settings.
/obj/structure/fuelpump/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/topic_state/default/fuel_pump_purchase/quote = null)
	var/list/sections
	var/height = 240
	switch (ui_key)
		if ("buy")
			if (!quote)
				if (!ui)
					ui = GLOB.nanomanager.get_open_ui(user, src, ui_key)
				quote = ui?.state
			if (!istype(quote) || quote.buyer != user)
				GLOB.nanomanager.close_user_uis(user, src, ui_key)
				return
			sections = list(panel_section("Buy fuel",
				notes = list("You can buy [quote.units] units of [quote.fuel] with this amount. Confirm?"),
				buttons = list(panel_button("Yes", "action", "buy_yes"), panel_button("No", "action", "buy_no"))))
		if ("confirm")
			if (!unlocked || unlockedvol <= 0)
				GLOB.nanomanager.close_user_uis(user, src, ui_key)
				return
			sections = list(panel_section("Finish the sale",
				notes = list("This pump still has [unlockedvol] units of [fueltype] inside! Are you sure you want to finish?"),
				buttons = list(panel_button("Yes", "action", "finish_yes"), panel_button("No", "action", "finish_no"))))
		if ("manage")
			if (!company_may_operate(user, owner))
				GLOB.nanomanager.close_user_uis(user, src, ui_key)
				return
			var/list/fuels = list()
			for (var/fuel in fuel_choices())
				fuels += list(panel_button(capitalize(fuel), "action", "fuel_[fuel]", vol > 0, fueltype == fuel))
			sections = list(
				panel_section("Management", rows = list(
					panel_row("Name", name, buttons = list(panel_button("Change", "action", "change_name_direct"))),
					panel_row("Price", "[price] silver a unit", buttons = list(panel_button("Change", "action", "change_price_direct"))))),
				panel_section("Fuel sold", notes = vol > 0 ? list("Empty the pump before changing its fuel.") : null, buttons = fuels))
			height = 340
		else
			return
	open_panel(user, name, 400, height, sections, ui_key = ui_key, ui = ui, force_open = force_open, state = quote)

/obj/structure/fuelpump/proc/update_management_price(mob/user, custp)
	if (!isnum(custp))
		return
	if (custp < 0)
		custp = 0
	else if (custp > 50)
		custp = 50
	price = custp
	updatedesc()
	show_manage_ui(user)

/obj/structure/fuelpump/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if (action != "action" || !ui || ui.src_object != src || ui.ui_key != "buy")
		return FALSE
	var/mob/living/human/buyer = user
	if (!istype(buyer) || buyer.stat || get_dist(src, buyer) > 2)
		return TRUE
	var/datum/topic_state/default/fuel_pump_purchase/quote = ui.state
	if (params["value"] == "buy_yes")
		ui.close()
		complete_purchase(buyer, quote)
	else if (params["value"] == "buy_no")
		ui.close()
	return TRUE

/obj/structure/fuelpump/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/human/user = usr
	if (!istype(user) || user.stat || get_dist(src, user) > 2)
		return

	// Purchase actions must carry their original window state through ui_act().
	if (href_list["action"] in list("buy_yes", "buy_no"))
		return

	// Finish confirmation
	if (href_list["action"] == "finish_yes")
		GLOB.nanomanager.close_user_uis(user, src, "confirm")
		unlocked = 0
		unlockedvol = 0
		return

	if (href_list["action"] == "finish_no")
		GLOB.nanomanager.close_user_uis(user, src, "confirm")
		return

	// Management
	if (!company_may_operate(user, owner))
		return

	if (href_list["action"] == "change_name_direct")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/custn = player_input(user, "Choose a name for this pump:", null, null, "text", null, TRUE)
		if (custn == "" || custn == null || QDELETED(src) || !in_range(src, user) || !company_may_operate(user, owner))
			return
		name = custn
		updatedesc()
		show_manage_ui(user)
		return

	if (copytext(href_list["action"], 1, 6) == "fuel_")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/fuel = copytext(href_list["action"], 6)
		if (!(fuel in fuel_choices()))
			return
		if (vol > 0)
			to_chat(user, "<span class = 'notice'>The [src] still has fuel inside! Empty it before changing!</span>")
			return
		fueltype = fuel
		updatedesc()
		show_manage_ui(user)
		return

	if (href_list["action"] == "change_price_direct")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/custp = player_input(user, "What should the price be, in silver coins? (Min: 0, Max: 50):", null, null, "num", null, TRUE)
		if (QDELETED(src) || unlocked || !in_range(src, user) || !company_may_operate(user, owner))
			return
		update_management_price(user, custp)
		return

	show_manage_ui(user)
