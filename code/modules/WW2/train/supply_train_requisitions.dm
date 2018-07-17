/obj/item/weapon/paper/supply_train_requisitions_sheet
	name = "Supply Train Requisitions"
	desc = "You have to sign this with a pen or it won't be accepted. Only Officer signatures are valid."

	var/list/purchases = list()

	var/list/signatures = list()

	var/memo = ""

/obj/item/weapon/paper/supply_train_requisitions_sheet/New()
	..()
	regenerate_info()

/obj/item/weapon/paper/supply_train_requisitions_sheet/attack_self(mob/living/user as mob)
	user.examinate(src) // no crumpling

/obj/item/weapon/paper/supply_train_requisitions_sheet/show_content(var/mob/user, var/forceshow=0)
	regenerate_info()
	if (!(istype(user, /mob/living/carbon/human) || isghost(user) || istype(user, /mob/living/silicon)) && !forceshow)
		user << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[stars(info)]</BODY></HTML>", "window=[name]")
		onclose(user, "[name]")
	else
		user << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[info]</BODY></HTML>", "window=[name]")
		onclose(user, "[name]")

/obj/item/weapon/paper/supply_train_requisitions_sheet/attackby(obj/item/weapon/P as obj, var/mob/user as mob)
	if (istype(P, /obj/item/weapon/pen))
		if (icon_state == "scrap")
			user << "<span class='warning'>\The [src] is too crumpled to write on.</span>"
		else
			var/mob/living/carbon/human/H = user
			if (!istype(H) || !H.original_job)
				return
			var/sign = input("Sign the [name]?") in list("Yes", "No")
			if (sign == "Yes")
				if (do_after(H, 20, get_turf(H)))
					if (loc == H)
						visible_message("<span class = 'notice'>[H] signs [name].</span>")
						signatures += "<i>[H.real_name] - [H.original_job.title]</i>"
						regenerate_info()
						show_content(H)

/obj/item/weapon/paper/supply_train_requisitions_sheet/proc/regenerate_info()

	info_links = {"
	<b><big>CRATES</big></b><br><br>
	"}

	for (var/name in processes.supply.german_crate_types)
		info_links += "[make_purchase_href_link(name)]<br> - [processes.supply.crate_costs[name]] requisition points<br>"

	info_links += "<br><br><b>Purchasing:</b><br><br>"

	var/total_cost = FALSE

	for (var/purchase in purchases)
		info_links += "<i>[purchase]</i><br>"
		total_cost += processes.supply.crate_costs[purchase]

	if (purchases.len)
		info_links += "<br><b>Total Cost:</b> [total_cost]<br>"

	info_links += "[signatures()]<br><br>"

	if (memo)
		info_links += "<br>[memo]"

	info = info_links

	if (info && icon_state != "scrap")
		icon_state = "paper_words"

/obj/item/weapon/paper/supply_train_requisitions_sheet/proc/make_purchase_href_link(var/name)
	return "<A href='?src=\ref[src];purchase=[name]'>[name]</a>"

/obj/item/weapon/paper/supply_train_requisitions_sheet/proc/signatures()
	. = "<br><br><b>Signatures:</b><br>"
	if (signatures.len)
		for (var/signature in signatures)
			. += "[signature]<br>"
	else
		. += "<i>Please sign your name here.</i><br>"

/obj/item/weapon/paper/supply_train_requisitions_sheet/Topic(href, href_list)
	..()

	if (!usr || (usr.stat || usr.restrained()))
		return

	var/mob/living/carbon/human/H = usr

	if (!istype(H))
		return

	if (href_list["purchase"])
		var/purchase = href_list["purchase"]
		if (istype(H.l_hand, /obj/item/weapon/pen) || istype(H.r_hand, /obj/item/weapon/pen))
			purchases += purchase
			regenerate_info()
			show_content(H)
		else
			H << "<span class = 'warning'>You must have a pen in-hand to write down a purchase.</span>"

/obj/item/weapon/paper/supply_train_requisitions_sheet/proc/generate_memoend(var/datum/train_controller/german_supplytrain_controller/train)
	return "<br><i>As of the time this was printed, you have [train.supply_points] Supply Requisition Points remaining.</i>"

/obj/item/weapon/paper/supply_train_requisitions_sheet/proc/supplytrain_process(var/datum/train_controller/german_supplytrain_controller/train)

	if (!purchases.len)
		return

	var/list/create_crates = list()

	memo = ""

	var/SO_sig = FALSE
	var/QM_sig = FALSE
	var/CO_sig = FALSE

	for (var/signature in signatures)
		if (findtext(signature, GERMAN_QM_TITLE))
			QM_sig = TRUE
		if (findtext(signature, GERMAN_SO_TITLE) || findtext(signature, GERMAN_TO_TITLE) || findtext(signature, GERMAN_SL_TITLE) || findtext(signature, GERMAN_AO_TITLE))
			SO_sig = TRUE
		if (findtext(signature, GERMAN_CO_TITLE) || findtext(signature, GERMAN_XO_TITLE))
			CO_sig = TRUE

	if (!QM_sig && !SO_sig && !CO_sig)
		memo = "<i>We didn't find any valid signatures, so your requisition has been rejected.</span><br>"
		goto end

	for (var/purchase in purchases)
		var/cost = processes.supply.crate_costs[purchase]
		var/cratetype = processes.supply.german_crate_types[purchase]
		if (cost > train.supply_points)
			memo = "<i>Unfortunately, you did not have enough supply points left to purchase the [purchase] crate, or any of the purchases listed after it.</i><br>"
			break
		create_crates += cratetype
		train.supply_points -= cost

	for (var/a in train.reverse_train_car_centers)
		if (!a)
			train.reverse_train_car_centers -= a
			continue
		var/obj/train_car_center/tcc = a
		for (var/b in tcc.backwards_pseudoturfs)
			if (!b)
				tcc.backwards_pseudoturfs -= b
				continue
			var/obj/train_pseudoturf/tpt = b
			if (!tpt.loc)
				continue
			if (locate(/obj/train_decal/cargo/outline) in tpt.vis_contents)
				if (!locate(/obj/structure/closet/crate) in tpt.loc)
					if (create_crates.len)
						var/cratetype = pick(create_crates)
						create_crates -= cratetype

						for (var/mob/M in tpt.loc.contents)
							qdel(M)
						for (var/obj/item/I in tpt.loc.contents)
							qdel(I)
						for (var/obj/O in tpt.loc.contents)
							if (O.density)
								qdel(O)

						new cratetype(tpt.loc)

	if (create_crates.len) // we didn't have enough space to send them all
		memo = "<i><br>We didn't have enough space for the crates listed below, so you were reimbursed for their cost: </i><br><br>"
		for (var/cratetype in create_crates)
			for (var/cratename in processes.supply.german_crate_types)
				if (processes.supply.german_crate_types[cratename] == cratetype)
					var/cost = processes.supply.crate_costs[cratename]
					train.supply_points += cost
					memo += "<i>[cratename]</i><br>"

	end

	// add our unique memo ending
	memo += generate_memoend(train)

	signatures.Cut()

	purchases.Cut()

	regenerate_info()

	return TRUE