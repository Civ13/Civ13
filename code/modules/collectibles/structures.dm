/obj/structure/vending/sales/cards
	name = "Civ Cards vending machine"
	desc = "A vending machine selling packs of the 'Civ Cards' collection stickers. Gotta collect 'em all!"
	icon_state = "cards"
	owner = "Civ Cards Collection"
	products = list(
		/obj/item/sticker_pack = 25,
		/obj/item/sticker_pack/special = 25,
	)
	prices = list(
		/obj/item/sticker_pack = 10,
		/obj/item/sticker_pack/special = 25,
	)


/obj/item/sticker_album
	name = "Civ Cards sticker album"
	desc = "A binder for collecting and displaying your 'Civ Cards' stickers."
	icon = 'icons/obj/collectibles.dmi'
	icon_state = "collectible_album"
	w_class = ITEM_SIZE_NORMAL

/obj/item/sticker_album/anchored
	anchored = TRUE

/obj/item/sticker_album/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/sticker))
		var/obj/item/sticker/S = W
		if(!S.sticker_id || !GLOB.sticker_registry[S.sticker_id])
			to_chat(user, "<span class='warning'>This sticker seems blank!</span>")
			return
		var/list/player_stickers = get_player_stickers(user.ckey)
		if(S.sticker_id in player_stickers)
			to_chat(user, "<span class='notice'>You already have this sticker in your collection!</span>")
			return
		player_stickers += S.sticker_id
		user.visible_message("<span class='notice'>[user] carefully places \the [S] into \the [src].</span>")
		qdel(W)
		save_sticker_collection(user.ckey, player_stickers)
		return
	..()

/obj/item/sticker_album/attack_self(mob/user)
	ui_interact(user)

/obj/item/sticker_album/anchored/attack_hand(mob/user)
	ui_interact(user)

/obj/item/sticker_album/ui_interact(mob/user)
	var/list/player_stickers = get_player_stickers(user.ckey)
	var/list/stickers_by_rarity = new/list(4)
	stickers_by_rarity[STICKER_COMMON]    = list()
	stickers_by_rarity[STICKER_UNCOMMON]  = list()
	stickers_by_rarity[STICKER_RARE]      = list()
	stickers_by_rarity[STICKER_LEGENDARY] = list()

	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		if(S)
			stickers_by_rarity[S.rarity] += list(S)

	var/dat = {"<html><head>[common_browser_style]<style>
.rarity-title { font-size: 16px; font-weight: bold; margin-top: 16px; margin-bottom: 8px; padding: 4px; border-bottom: 2px solid; }
.sticker-slot { display: inline-block; width: 140px; height: 80px; margin: 4px; padding: 4px; text-align: center; vertical-align: top; border-radius: 4px; }
.sticker-slot.owned { background: #2a3a2a; border: 1px solid #4a6a4a; }
.sticker-slot.missing { background: #1a1a1a; border: 1px solid #333; }
.sticker-slot .rarity-tag { font-size: 10px; font-weight: bold; display: block; margin-top: 4px; }
.sticker-slot .info-tag { font-size: 9px; color: #888; display: block; }
</style></head><body>"}
	dat += "<h2>Sticker Album</h2>"
	var/collected = length(player_stickers)
	var/total = length(GLOB.sticker_registry)
	dat += "<p>Progress: <b>[collected] / [total]</b> ([round((collected / max(total, 1)) * 100)]%)</p>"

	for(var/r = STICKER_COMMON to STICKER_LEGENDARY)
		var/tier_list = stickers_by_rarity[r]
		if(!length(tier_list))
			continue
		var/first = tier_list[1]
		var/datum/sticker/FS = first
		var/color = FS.rarity_color()
		dat += "<div class='rarity-title' style='border-color: [color]; color: [color];'>[FS.rarity_name()]</div>"
		for(var/datum/sticker/S in tier_list)
			if(S.id in player_stickers) // If the sticker is collected
				dat += "<div class='sticker-slot owned'>"
				// Add a clickable link to open the card details, similar to examining a physical sticker
				dat += "<a href='byond://?src=\ref[src];open_card=[S.index]' style='text-decoration: none; color: inherit;'>"
				dat += "<b>#[S.index] [S.name]</b><br>"
				dat += "<span class='rarity-tag' style='color: [color];'>COLLECTED</span>"
				dat += "<span class='info-tag'>[S.category] - [S.age]</span>"
				dat += "</a>"
				dat += "</div>"
			else // If the sticker is missing
				dat += "<div class='sticker-slot missing'>"
				dat += "#[S.index] ???<br>"
				dat += "<span class='rarity-tag' style='color: #555;'>Not yet collected</span>"
				dat += "</div>"

	dat += "<br><br><a href='byond://?src=\ref[src];close=1' class='btn'>Close</a>"
	dat += "</body></html>"
	user << browse(dat, "window=sticker_album;size=650x550")

/obj/item/sticker_album/Topic(href, href_list)
	. = ..()
	if(href_list["close"])
		usr << browse(null, "window=sticker_album")
		return TRUE
	if(href_list["open_card"]) // Handle the new 'open_card' link
		var/card_index = href_list["open_card"]
		if(card_index)
			// Open the card details in a new browser window, just like examining a sticker
			usr << browse("<!DOCTYPE html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'><style>body,html{margin:0;padding:0;width:100%;height:100%;overflow:hidden;}iframe{width:100%;height:100%;border:none;}</style></head><body><iframe src='https://civ13.com/card/[card_index]'></iframe></body></html>", "window=sticker_card_[card_index];size=400x650")
			return TRUE
GLOBAL_LIST_EMPTY(sticker_collections)

/proc/get_player_stickers(ckey)
	if(!ckey)
		return list()
	if(!GLOB.sticker_collections[ckey])
		GLOB.sticker_collections[ckey] = load_sticker_collection(ckey)
	return GLOB.sticker_collections[ckey]

/proc/load_sticker_collection(ckey)
	if(!ckey)
		return list()
	if(!fexists("SQL/collectibles.txt"))
		return list()
	var/list/lines = file2list("SQL/collectibles.txt")
	for(var/line in lines)
		if(!line)
			continue
		var/list/parts = splittext(line, ";")
		if(length(parts) >= 2 && parts[1] == ckey)
			return parts.Copy(2)
	return list()

/proc/save_sticker_collection(ckey, list/ids)
	if(!ckey || !istype(ids))
		return
	var/list/temp = list()
	for(var/id in ids)
		temp[id] = TRUE
	ids = list()
	for(var/id in temp)
		ids += id
	var/list/new_lines = list()
	var/found = FALSE
	if(fexists("SQL/collectibles.txt"))
		var/list/lines = file2list("SQL/collectibles.txt")
		for(var/line in lines)
			var/list/parts = splittext(line, ";")
			if(length(parts) >= 1 && parts[1] == ckey)
				if(!found)
					new_lines += "[ckey];[jointext(ids, ";")]"
					found = TRUE
			else
				new_lines += line
	if(!found)
		new_lines += "[ckey];[jointext(ids, ";")]"
	if(fexists("SQL/collectibles.txt"))
		if(fexists("SQL/collectibles_backup.txt"))
			fdel("SQL/collectibles_backup.txt")
		fcopy("SQL/collectibles.txt", "SQL/collectibles_backup.txt")
		fdel("SQL/collectibles.txt")
	for(var/line in new_lines)
		if(length(line) > 0)
			text2file(line, "SQL/collectibles.txt")
	GLOB.sticker_collections[ckey] = ids

/obj/item/sticker_album/attack(mob/M, mob/user)
	if(user == M)
		return ui_interact(user)
	if(ismob(M))
		if(!M.ckey)
			to_chat(user, "<span class='notice'>You flip through \the [src] but find no collection linked to [M].</span>")
			return
		var/list/owner_stickers = get_player_stickers(M.ckey)
		var/dat = "<html><head>[common_browser_style]</head><body>"
		dat += "<h2>[M]'s Sticker Album</h2>"
		dat += "<p>Collected: [length(owner_stickers)] / [length(GLOB.sticker_registry)]</p>"
		for(var/id in GLOB.sticker_registry)
			var/datum/sticker/S = GLOB.sticker_registry[id]
			if(id in owner_stickers)
				dat += "<span style='display:inline-block;width:150px;padding:4px;margin:2px;background:#2a3a2a;border:1px solid #4a6a4a;'>"
				dat += "<b>#[S.index] [S.name]</b><br><font color='[S.rarity_color()]'>[S.rarity_name()]</font></span> "
			else
				dat += "<span style='display:inline-block;width:150px;padding:4px;margin:2px;background:#1a1a1a;border:1px solid #333;color:#555;'>"
				dat += "<b>#[S.index]</b> ???</span> "
		dat += "<br><br><a href='byond://?src=\ref[src];close=1' class='btn'>Close</a>"
		dat += "</body></html>"
		user << browse(dat, "window=[M.ckey]_album;size=550x500")
		return
	..()
