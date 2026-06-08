
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
	fueltype = pick("gasoline","diesel","biodiesel","pethanol","petroleum")
	vol = maxvol
	name = "[brand] [fueltype] pump"
	price = 0.4
	do_color()
	updatedesc()

/obj/structure/fuelpump/premade/gasoline/New()
	..()
	fueltype = "gasoline"
	name = "[brand] [fueltype] pump"
	updatedesc()

/obj/structure/fuelpump/premade/diesel/New()
	..()
	fueltype = "diesel"
	name = "[brand] [fueltype] pump"
	updatedesc()

/obj/structure/fuelpump/premade/yamaha
	brand = "Yamaha Gas"
	icon_state = "oilpump1"
	customcolor = "#7F0000"

/obj/structure/fuelpump/premade/yamaha/gasoline/New()
	..()
	fueltype = "gasoline"
	name = "[brand] [fueltype] pump"
	updatedesc()

/obj/structure/fuelpump/premade/yamaha/diesel/New()
	..()
	fueltype = "diesel"
	name = "[brand] [fueltype] pump"
	updatedesc()

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
			var/dat = {"<html><head>
[common_browser_style]
</head><body>
<h2>[name]</h2>
<p>This pump still has [unlockedvol] units of [fueltype] inside! Are you sure you want to finish?</p>
<a href='?src=\ref[src];action=finish_yes'>Yes</a>
<a href='?src=\ref[src];action=finish_no'>No</a>
</body></html>"}
			user << browse(dat, "window=fuelpump_confirm;size=350x200")
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
			var/dat = {"<html><head>
[common_browser_style]
</head><body>
<h2>[name]</h2>
<p>You can buy [round(valp/price, 0.1)] units of [fueltype] with this amount. Confirm?</p>
<a href='?src=\ref[src];action=buy_yes'>Yes</a>
<a href='?src=\ref[src];action=buy_no'>No</a>
</body></html>"}
			user << browse(dat, "window=fuelpump_buy;size=350x200")
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
				to_chat(user, "You fill the [GC] completely. There are [unlockedvol] units remanining in the pump.")
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
						to_chat(user, "You fill \the [src] completly with \the [W].")
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
	set src in range(1, usr)

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
	var/dat = {"<html><head>
[common_browser_style]
<script language="javascript">
function changeName() {
	var n = prompt('Choose a name for this pump:');
	if (n && n.trim()!='') window.location='byond://?src=\ref[src];action=change_name&name='+encodeURIComponent(n.trim());
}
function changePrice() {
	var p = prompt('Enter price in silver coins (0-50):', '0.3');
	var n = parseFloat(p);
	if (!isNaN(n) && n>=0 && n<=50) window.location='byond://?src=\ref[src];action=change_price&price='+n;
}
</script>
</head><body>
<h2>[name] Management</h2>
<p>Current fuel: [fueltype] &mdash; Price: [price] silver/unit</p>
<p><a href='?src=\ref[src];action=change_name_direct'>Change Name</a></p>
<p><a href='?src=\ref[src];action=change_fuel'>Change Fuel Type</a></p>
<p><a href='?src=\ref[src];action=change_price_direct'>Change Price</a></p>
<p><a href='?src=\ref[src];action=close_manage'>Close</a></p>
</body></html>"}
	user << browse(dat, "window=fuelpump_manage;size=350x300")

/obj/structure/fuelpump/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/human/user = usr
	if (!istype(user) || user.stat || get_dist(src, user) > 2)
		return

	// Purchase confirmation
	if (href_list["action"] == "buy_yes")
		user << browse(null, "window=fuelpump_buy")
		var/obj/item/stack/money/MN = null
		if (istype(user.l_hand, /obj/item/stack/money))
			MN = user.l_hand
		else if (istype(user.r_hand, /obj/item/stack/money))
			MN = user.r_hand
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
		user << browse(null, "window=fuelpump_buy")
		return

	// Finish confirmation
	if (href_list["action"] == "finish_yes")
		user << browse(null, "window=fuelpump_confirm")
		unlocked = 0
		unlockedvol = 0
		return

	if (href_list["action"] == "finish_no")
		user << browse(null, "window=fuelpump_confirm")
		return

	// Management
	if (href_list["action"] == "close_manage")
		user << browse(null, "window=fuelpump_manage")
		return

	if (href_list["action"] == "change_name_direct")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/custn = input(user, "Choose a name for this pump:") as text|null
		if (custn == "" || custn == null)
			return
		name = custn
		updatedesc()
		show_manage_ui(user)
		return

	if (href_list["action"] == "change_name")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/custn = href_list["name"]
		if (custn && custn != "")
			name = custn
			updatedesc()
		show_manage_ui(user)
		return

	if (href_list["action"] == "change_fuel")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		if (vol > 0)
			to_chat(user, "<span class = 'notice'>The [src] still has fuel inside! Empty it before changing!</span>")
			return
		var/dat = {"<html><head>
[common_browser_style]
</head><body>
<h2>Choose Fuel Type</h2>
<a href='?src=\ref[src];action=set_fuel&fuel=gasoline'>Gasoline</a><br>
<a href='?src=\ref[src];action=set_fuel&fuel=diesel'>Diesel</a><br>
<a href='?src=\ref[src];action=set_fuel&fuel=biodiesel'>Biodiesel</a><br>
<a href='?src=\ref[src];action=set_fuel&fuel=pethanol'>Pethanol</a><br>
<a href='?src=\ref[src];action=set_fuel&fuel=petroleum'>Petroleum</a><br>
<br><a href='?src=\ref[src];action=close_manage'>Cancel</a>
</body></html>"}
		user << browse(dat, "window=fuelpump_fuel;size=300x300")
		return

	if (href_list["action"] == "set_fuel")
		var/fuel = href_list["fuel"]
		if (fuel && vol <= 0)
			fueltype = fuel
			updatedesc()
		user << browse(null, "window=fuelpump_fuel")
		show_manage_ui(user)
		return

	if (href_list["action"] == "change_price_direct")
		if (unlocked)
			to_chat(user, "The pump is being used! Finish it first.")
			return
		var/custp = input(user, "What should the price be, in silver coins? (Min: 0, Max: 50):") as num|null
		if (!isnum(custp))
			return
		if (custp < 0)
			custp = 0
		else if (custp > 50)
			custp = 50
		price = custp
		updatedesc()
		show_manage_ui(user)
		return

	if (href_list["action"] == "change_price")
		var/custp = text2num(href_list["price"])
		if (!isnum(custp))
			return
		if (custp < 0)
			custp = 0
		else if (custp > 50)
			custp = 50
		price = custp
		updatedesc()
		show_manage_ui(user)
		return

	show_manage_ui(user)