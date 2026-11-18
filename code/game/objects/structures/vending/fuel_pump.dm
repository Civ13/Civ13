
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
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/obj/item/stack/money/MN = W
		var/valp = MN.amount*MN.value
		if (price > 0 && (valp/price) <= vol)
			ui_interact(user, "buy")
			return
		else
			to_chat(user, "<span class = 'notice'>The fuelpump doesn't have that much fuel inside! Try with a smaller amount. This pump has [vol] units of [fueltype] inside.</span>")

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

	if (find_company_member(user, owner))
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

/obj/structure/fuelpump/proc/money_in_hand(mob/living/human/user)
	if (!istype(user))
		return null
	if (istype(user.l_hand, /obj/item/stack/money))
		return user.l_hand
	if (istype(user.r_hand, /obj/item/stack/money))
		return user.r_hand
	return null

// Every button sends "action" with the name of what it does.
/obj/structure/fuelpump/ui_actions(ui_key)
	return list("action")

// Three small windows: "buy" and "confirm" ask before a sale starts or ends,
// "manage" is the owner's settings.
/obj/structure/fuelpump/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	var/list/sections
	var/height = 240
	switch (ui_key)
		if ("buy")
			var/obj/item/stack/money/MN = money_in_hand(user)
			if (!MN || unlocked || price <= 0)
				GLOB.nanomanager.close_user_uis(user, src, ui_key)
				return
			sections = list(panel_section("Buy fuel",
				notes = list("You can buy [round(MN.amount * MN.value / price, 0.1)] units of [fueltype] with this amount. Confirm?"),
				buttons = list(panel_button("Yes", "action", "buy_yes"), panel_button("No", "action", "buy_no"))))
		if ("confirm")
			if (!unlocked || unlockedvol <= 0)
				GLOB.nanomanager.close_user_uis(user, src, ui_key)
				return
			sections = list(panel_section("Finish the sale",
				notes = list("This pump still has [unlockedvol] units of [fueltype] inside! Are you sure you want to finish?"),
				buttons = list(panel_button("Yes", "action", "finish_yes"), panel_button("No", "action", "finish_no"))))
		if ("manage")
			if (!find_company_member(user, owner))
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
	open_panel(user, name, 400, height, sections, ui_key = ui_key, ui = ui, force_open = force_open)

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

/obj/structure/fuelpump/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/human/user = usr
	if (!istype(user) || user.stat || get_dist(src, user) > 2)
		return

	// Purchase confirmation
	if (href_list["action"] == "buy_yes")
		GLOB.nanomanager.close_user_uis(user, src, "buy")
		var/obj/item/stack/money/MN = money_in_hand(user)
		if (!MN)
			to_chat(user, "You no longer have the money in your hand.")
			return
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/valp = MN.amount*MN.value
		if (price > 0 && (valp/price) <= vol)
			user.drop_from_inventory(MN)
			storedval += MN
			MN.forceMove(locate(0,0,0))
			unlockedvol = (valp/price)
			to_chat(user, "<span class = 'notice'>You can now withdraw [unlockedvol] units of [fueltype] from this pump.</span>")
			unlocked = 1
			return
		else
			to_chat(user, "<span class = 'notice'>The fuelpump doesn't have that much fuel inside! Try with a smaller amount.</span>")
			return

	if (href_list["action"] == "buy_no")
		GLOB.nanomanager.close_user_uis(user, src, "buy")
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
	if (!find_company_member(user, owner))
		return

	if (href_list["action"] == "change_name_direct")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/custn = player_input(user, "Choose a name for this pump:", null, null, "text", null, TRUE)
		if (custn == "" || custn == null)
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
		update_management_price(user, custp)
		return

	show_manage_ui(user)
