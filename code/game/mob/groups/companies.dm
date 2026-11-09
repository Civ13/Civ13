////////////////////////////////////////////////////////////////////////////
///////////////////////////////////Companies////////////////////////////////
////////////////////////////////////////////////////////////////////////////

#define COMPANY_NAME_MAX_CHARS 40

/mob/living/human/proc/create_company()
	set name = "Create Company"
	set category = "Faction"
	var/mob/living/human/U

	if (istype(src, /mob/living/human))
		U = src
	else
		return
	if (map.civilizations == TRUE || map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.ID == MAP_FOUR_KINGDOMS || map.ID == MAP_COLONY || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CMP)
		var/choosename = player_input(U, "Choose a name for the company:", null, null, "text", null, TRUE)
		create_company_pr(choosename)
		return
	else
		to_chat(U, "<span class='danger'>You cannot create a company in this map.</span>")
		return

/mob/living/human/proc/create_company_pr(var/newname = "none")
	if (!ishuman(src))
		return
	var/mob/living/human/H = src
	if (!newname || newname == "none")
		return
	// The name becomes an assoc key (custom_company, vending owner, stock
	// listings) and raw HTML in the stock market, so strip markup outright.
	newname = sanitize(newname, COMPANY_NAME_MAX_CHARS + 1, FALSE)
	if (!newname || newname == "" || newname == "none")
		to_chat(H, SPAN_DANGER("That name contains nothing usable. Choose another name."))
		return
	if (newname == "Global" || (newname in map.custom_company_nr))
		to_chat(H, SPAN_DANGER("That company already exists. Choose another name."))
		return
	var/choosecolor1 = "#000000"
	var/choosecolor2 = "#FFFFFF"
	choosecolor1 = WWinput(H, "Choose the main/symbol color:", "Main Color" , "#000000", "color")
	if (choosecolor1 == null || choosecolor1 == "")
		return

	choosecolor2 = WWinput(H, "Choose the secondary/background color:", "Secondary Color" , "#FFFFFF", "color")
	if (choosecolor2 == null || choosecolor2 == "")
		return

	// Re-checked: another player can claim the name while the colour prompts are open.
	if (newname in map.custom_company_nr)
		to_chat(H, SPAN_DANGER("That company already exists. Choose another name."))
		return
	map.custom_company_nr += newname
	var/list/newnamev = list("[newname]" = list(list(H,100,0)))
	map.custom_company += newnamev
	map.custom_company_colors += list("[newname]" = list(choosecolor1,choosecolor2))
	to_chat(H, "<big>You now own <b>100%</b> of the new company [newname].</big>")

/mob/living/human/proc/transfer_company_stock()
	set name = "Transfer Company Stock"
	set category = "Faction"
	var/mob/living/human/H
	if (istype(src, /mob/living/human))
		H = src
	else
		return
	if (map.civilizations == TRUE || map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.ID == MAP_FOUR_KINGDOMS || map.ID == MAP_COLONY || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CMP)
		var/found = FALSE
		var/list/currlist = list()
		var/list/currlist_ind = list("Cancel")
		for (var/cname in map.custom_company_nr)
			for (var/i = 1, i <= map.custom_company[cname].len, i++)
				if (map.custom_company[cname][i][1] == H && map.custom_company[cname][i][2] > 0)
					currlist += list("[cname]" = list(map.custom_company[cname][i][2]))
					currlist_ind += cname
					found = TRUE
		if (!found)
			to_chat(usr, "You do not own any stocks.")
			return
		else
			var/compchoice = WWinput(H, "Which company to transfer stock ownership?", "Stock Transfer", "Cancel", currlist_ind)
			if (compchoice == "Cancel")
				return
			else
				var/compchoice_amt = player_input(H, "You own [currlist[compchoice][1]]% of [compchoice]. How much do you want to transfer? (1 to [currlist[compchoice][1]])", null, null, "num", null, TRUE)
				compchoice_amt = round(compchoice_amt)
				if (compchoice_amt > currlist[compchoice][1])
					compchoice_amt = currlist[compchoice][1]
				if (compchoice_amt <= 0)
					return
				var/list/closemobs = list("Cancel")
				for (var/mob/living/human/M in range(4,loc))
					if (M.stat != DEAD && M != H)
						closemobs += M
				var/choice2 = WWinput(usr, "Who to transfer the stocks to?", "Stock Transfer", "Cancel", closemobs)
				if (choice2 == "Cancel" || !ishuman(choice2))
					return
				var/mob/living/human/CM = choice2
				if (CM.stat == DEAD || get_dist(H, CM) > 4)
					to_chat(H, SPAN_WARNING("[CM] is no longer close enough to receive the stock."))
					return
				// The prompts above sleep, so the stake is re-checked inside the move:
				// a second open dialog or a stock-market sale cannot spend it twice.
				if (!H.transfer_stock_proc(compchoice, compchoice_amt, CM))
					to_chat(H, SPAN_WARNING("You no longer own [compchoice_amt]% of [compchoice]."))
				return
	else
		to_chat(usr, SPAN_DANGER("You cannot transfer company ownership on this map."))
		return

//searches company members for a player
/proc/find_company_member(var/mob/living/human/H, var/company)
	if (!map || !H || !company)
		return FALSE

	if (company == "Global")
		return FALSE

	var/list/company_list = map.custom_company[company]
	if (!istype(company_list) || !company_list.len)
		return FALSE

	for(var/i=1,i<=company_list.len,i++)
		var/list/member_data = company_list[i]
		if (member_data[1] == H && member_data[2] > 0)
			return TRUE

	return FALSE

// TRUE when one row held by holder covers amount%, the same test
// company_move_stake() applies.
/proc/company_has_stake(var/company, var/holder, var/amount)
	if (!map || !company || amount <= 0)
		return FALSE
	var/list/rows = map.custom_company[company]
	if (!istype(rows))
		return FALSE
	for (var/list/row in rows)
		if (row[1] == holder && row[2] >= amount)
			return TRUE
	return FALSE

// Moves amount% of company from source to target. The whole amount must come
// from ONE row the source holds, so a stale listing, a second open dialog or a
// dead seller can never create stock from nothing, and buying one estate
// listing never drains another dead holder's estate row.
/proc/company_move_stake(var/company, var/source, var/amount, var/target)
	if (!map || !company || !target || amount <= 0)
		return FALSE
	var/list/rows = map.custom_company[company]
	if (!istype(rows))
		return FALSE
	var/list/from = null
	for (var/list/row in rows)
		if (row[1] == source && row[2] >= amount)
			from = row
			break
	if (!from)
		return FALSE
	if (source == target)
		return TRUE
	from[2] -= amount
	for (var/list/row in rows)
		if (row[1] == target)
			row[2] += amount
			return TRUE
	rows += list(list(target, amount, 0))
	return TRUE

// A dead shareholder's stake goes back to the corporation: it is shared out
// among the living shareholders in proportion to what they hold, and any
// profits the holder had not withdrawn return to the company's undistributed
// pool. With no living shareholders it goes to the holder's faction leader.
// Returns FALSE only when nobody can take it (the caller then lists it).
/proc/company_return_stake(var/company, var/holder, var/civilization)
	if (!map || !company || !holder)
		return FALSE
	var/list/rows = map.custom_company[company]
	if (!istype(rows))
		return FALSE
	var/list/dead_row = null
	var/list/heirs = list()
	var/heir_total = 0
	for (var/list/row in rows)
		if (row[1] == holder)
			dead_row = row
		else if (row[1] && row[2] > 0)
			var/mob/living/M = row[1]
			if (istype(M) && M.stat != DEAD)
				heirs += list(row)
				heir_total += row[2]
	if (!dead_row || dead_row[2] <= 0)
		return TRUE
	var/stake = dead_row[2]
	if (!heirs.len)
		var/mob/living/human/leader = null
		if (civilization && civilization != "none" && map.custom_civs[civilization])
			leader = map.custom_civs[civilization][4]
		if (!istype(leader) || leader == holder || leader.stat == DEAD)
			return FALSE
		if (!company_move_stake(company, holder, stake, leader))
			return FALSE
		to_chat(leader, "<big>[stake]% of [company] passed to you as faction leader after [holder]'s death.</big>")
	else
		var/given = 0
		var/list/largest = heirs[1]
		for (var/list/row in heirs)
			var/part = round(stake * row[2] / heir_total)
			row[2] += part
			given += part
			if (row[2] > largest[2])
				largest = row
		largest[2] += stake - given
		dead_row[2] = 0
		for (var/list/row in heirs)
			to_chat(row[1], "<big>[holder]'s [stake]% of [company] returned to the company; your share is now [row[2]]%.</big>")
	// Unwithdrawn profits go back to the company for the next distribution.
	if (dead_row[3] > 0)
		map.custom_company_value[company] += dead_row[3]
		dead_row[3] = 0
	if (dead_row.len >= 4 && istype(dead_row[4], /list))
		var/list/fiat_profits = dead_row[4]
		for (var/fid in fiat_profits)
			if (fiat_profits[fid] > 0)
				if (!map.custom_company_fiat_value[company])
					map.custom_company_fiat_value[company] = list()
				map.custom_company_fiat_value[company][fid] = (map.custom_company_fiat_value[company][fid] || 0) + fiat_profits[fid]
				fiat_profits[fid] = 0
	return TRUE

//for automated transfers e.g. stock market
/mob/living/human/proc/transfer_stock_proc(var/companyname, var/stock, var/mob/living/human/target)
	if (!companyname || !stock || !target)
		return FALSE
	if (!company_move_stake(companyname, src, stock, target))
		return FALSE
	to_chat(src, "<big>Transferred [stock]% of [companyname] to [target].</big>")
	to_chat(target, "<big>You received [stock]% of [companyname] from [src].</big>")
	return TRUE

//to be used when the seller does not exist (normally if he died and there's no body)
//the stock is still for sale but "nobody" will receive the cost.
/proc/transfer_stock_nomob(var/companyname, var/stock, var/mob/living/human/target)
	if (!companyname || !stock || !target)
		return FALSE
	if (!company_move_stake(companyname, null, stock, target))
		return FALSE
	to_chat(target, "<big>You received [stock]% of [companyname] from the stock market.</big>")
	return TRUE

// Pays amount (in silver-coin value) as gold coins plus silver change and
// returns how much was paid; any fraction below one silver is not paid.
/proc/company_pay_coins(var/atom/destination, var/amount)
	amount = round(amount)
	if (!destination || amount <= 0)
		return 0
	var/gold = round(amount / 4)
	var/silver = amount - gold * 4
	if (gold > 0)
		var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(destination)
		GC.amount = gold
		GC.update_icon()
	if (silver > 0)
		var/obj/item/stack/money/silvercoin/SC = new/obj/item/stack/money/silvercoin(destination)
		SC.amount = silver
		SC.update_icon()
	return amount
