// large amount of fields creates a heavy load on the server, see updateinfolinks() and legacy_field_offset()
#define MAX_FIELDS 50

/*
 * Paper
 * also scraps of paper
 */

/obj/item/weapon/paper
	name = "sheet of paper"
	gender = NEUTER
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	item_state = "paper"
	var/base_icon = "paper"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	throw_range = TRUE
	throw_speed = TRUE
	layer = 4
	slot_flags = SLOT_HEAD
	body_parts_covered = HEAD
	attack_verb = list("bapped")
	flammable = TRUE
	flags = FALSE
	var/info		//What's actually written on the paper.
	var/info_links	//A different version of the paper which includes html links at fields and EOF
	var/stamps		//The (text for the) stamps on the paper.
	var/fields		//Amount of user created fields
	var/free_space = MAX_PAPER_MESSAGE_LEN
	var/list/stamped
	var/list/ico[0]	  //Icons and
	var/list/offset_x[0] //offsets stored for later
	var/list/offset_y[0] //usage by the photocopier
	var/rigged = FALSE
	var/spam_flag = FALSE

	var/const/deffont = "Verdana"
	var/const/signfont = "Times New Roman"
	var/const/crayonfont = "Comic Sans MS"

	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;info;info_links;stamped"
	safe_list_vars = "stamped"

/obj/item/weapon/paper/official
	base_icon = "official"
	name = "official paper"
	icon_state = "Decree_empty"
	var/faction = ""
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"

/obj/item/weapon/paper/official/fna
	base_icon = "official"
	name = "official fna document"
	icon_state = "Decree_empty"
	faction = ""
	color1 = "#000000"
	color2 = "#FFFFFF"

/obj/item/weapon/paper/official/fna/document
	name = "Official FNA Document"
	desc = "An official document printed by the Foreign Nations Alliance (FNA)."
	icon_state = "fna_doc"

/obj/item/weapon/official/fna/document_stamped
	name = "Official FNA Document"
	desc = "An official document printed by the Foreign nations Alliance (FNA), which also appears to be stamped."
	icon_state = "fna_doc_stamped"

/obj/item/weapon/official/fna/document_stamped2
	name = "Official FNA Document"
	desc = "An official document printed by the Foreign nations Alliance (FNA), which also appears to be stamped."
	icon_state = "fna_doc_stamped2"

/obj/item/weapon/official/fna/document_stamped3
	name = "Official FNA Document"
	desc = "An official document printed by the Foreign nations Alliance (FNA), which also appears to be stamped."
	icon_state = "fna_doc_stamped3"

/obj/item/weapon/official/fna/document_denied
	name = "Official FNA Document"
	desc = "An official document printed by the Foreign nations Alliance (FNA), which also appears to be stamped for denial."
	icon_state = "fna_doc_denied"

/obj/item/weapon/official/fna/document_approved
	name = "Official FNA Document"
	desc = "An official document printed by the Foreign nations Alliance (FNA), which also appears to be stamped for approval."
	icon_state = "fna_doc_approved"

/obj/item/weapon/official/fna/document_warrant
	name = "Official FNA Document"
	desc = "An official warrant printed by the Foreign nations Alliance (FNA), which also appears to be stamped and contains details and a photograph of the targeted individual."
	icon_state = "fna_warrant"

/obj/item/weapon/paper/entry_permit
	name = "entry permit"
	desc = "A permit granting right of entry to a specified country"
	icon_state = "entry_permit"

/obj/item/weapon/paper/asylum
	name = "asylum grant"
	desc = "an official document granting political asylum to the recipient in a specified country"
	icon_state = "asylum_grant"

/obj/item/weapon/paper/id_supp
	name = "id supplement"
	desc = "A small document supplement detailing physical appearance"
	icon_state = "id_supp"

/obj/item/weapon/paper/vaccine
	name = "vaccine certificate"
	desc = "an official medical certificate confirming that a person has been vaccinated against certain disease(s)"
	icon_state = "vaccine_cert"

/obj/item/weapon/paper/diplomatic_auth
	name = "diplomatic authorisation"
	desc = "an official document from an international organisation confirming the diplomatic status and diplomatic right to travel of the recipient"
	icon_state = "diplomatic_auth"

/obj/item/weapon/paper/entry_ticket
	name = "entry ticket"
	desc = "A simple small ticket granting right of entry"
	icon_state = "entry_ticket"

/obj/item/weapon/paper/official/New()
	..()
	spawn(30)
		name = "official [faction] paper"

/obj/item/weapon/paper/official/update_icon()
	..()
	overlays.Cut()
	var/image/i1 = image(icon=src.icon, icon_state="Decree_Overlay_1")
	var/image/i2 = image(icon=src.icon, icon_state="Decree_Overlay_2")
	i1.color = color1
	i2.color = color2
	overlays += i1
	overlays += i2
	paper_stamp_refresh_overlays(src)

//lipstick wiping is in code/game/objects/items/weapons/cosmetics.dm!

/obj/item/weapon/paper/New(var/newloc, var/copy_skip_space = FALSE)
	..()
	pixel_y = rand(-8, 8)
	pixel_x = rand(-9, 9)
	stamps = ""

	if (name != "paper")
		desc = "This is a paper titled '" + name + "'."

	if (info != initial(info))
		info = html_encode(info)
		info = replacetext(info, "\n", "<BR>")
		info = parsepencode(info)

	spawn(2)
		if (gc_destroyed)
			return
		update_icon()
		// Copies already carry exact capacity; imported classified records own
		// theirs too. The local constructor argument is never persisted.
		if (!copy_skip_space && isnull(document_record))
			update_space(info)
		document_capacity_ready = TRUE
		updateinfolinks()

	// Only a plain blank sheet takes its era's name. Parchment and printed
	// forms keep their own names, so players can tell them apart.
	if (map && type == /obj/item/weapon/paper && !length(info))
		if (map.ordinal_age <= 1)
			name = "papyrus"
			icon_state = "scrollpaper"
			desc = "A blank papyrus scroll. It can be written on like paper."
		else if (map.ordinal_age <= 3)
			name = "paper"
			icon_state = "Colonial_Paper_Empty"
			desc = "A blank paper sheet."

/obj/item/weapon/paper/verb/airplane()
	var/done = FALSE
	if (!done)
		set name = "Make Paper Airplane"
		set category = null
		set src in usr
		var/list/fold_edit = null
		if (!isnull(document_record))
			fold_edit = paper_document_prepare_edit(src)
			if (!fold_edit)
				return
		if (!paper_document_set_name(src, "paper airplane - \"[src.name]\"", fold_edit))
			return
		src.icon_state = "paper_plane"
		src.throw_range = 14
		done = TRUE
		add_fingerprint(usr)

// A classified section marks the sheet as written without exposing its text.
/obj/item/weapon/paper/proc/has_document_writing()
	if (info)
		return TRUE
	if (!islist(document_record))
		return FALSE
	var/list/sections = document_record["sections"]
	return islist(sections) && length(sections)

/obj/item/weapon/paper/update_icon()
	paper_stamp_refresh_overlays(src)
	if (base_icon == "paper")
		if (map && map.ordinal_age <= 1)
			if (has_document_writing())
				icon_state = "scrollpaper1"
			else
				icon_state = "scrollpaper0"
		else if (map && map.ordinal_age <= 3)
			if (has_document_writing())
				icon_state = "Colonial_Paper"
			else
				icon_state = "Colonial_Paper_Empty"
		else
			if (icon_state == "paper_talisman")
				return
			if (has_document_writing())
				icon_state = "paper_words"
				return
			icon_state = "paper"
	else if (base_icon == "official")
		if (has_document_writing())
			icon_state = "Decree"
		else
			icon_state = "Decree_empty"

/obj/item/weapon/paper/proc/update_space(var/new_text)
	if (!new_text)
		return

	free_space -= length(strip_html_properly(new_text))
	paper_authoring_notify(src, "physical")

/obj/item/weapon/paper/proc/document_copy_legacy_valid(list/legacy)
	if (!paper_document_keys(legacy, list("name", "info", "stamps", "fields", "free_space", "stamped", "ico", "offset_x", "offset_y")))
		return FALSE
	if ((!isnull(legacy["name"]) && !istext(legacy["name"])) || (!isnull(legacy["info"]) && !istext(legacy["info"])) || (!isnull(legacy["stamps"]) && !istext(legacy["stamps"])))
		return FALSE
	var/count = legacy["fields"]
	if (!isnull(count) && (!isnum(count) || count != round(count) || count < 0 || count > MAX_FIELDS))
		return FALSE
	var/space = legacy["free_space"]
	// Retain bounded negative capacity of old overfull documents verbatim.
	if (!isnum(space) || space != round(space) || space < -131072 || space > MAX_PAPER_MESSAGE_LEN)
		return FALSE
	for (var/key in list("stamped", "ico", "offset_x", "offset_y"))
		if (!isnull(legacy[key]) && !islist(legacy[key]))
			return FALSE
	return TRUE

/obj/item/weapon/paper/examine(mob/user)
	..()
	if (in_range(user, src) || isghost(user))
		if (!farsight_can_read(user, src))
			return
		show_content(user)
		paper_study_examine_hint(user, src)
	else
		to_chat(user, SPAN_NOTICE("You have to go closer if you want to read it."))
	return

/obj/item/weapon/paper/proc/show_content(var/mob/user, var/forceshow=0)
	return show_document(user, forceshow)

/obj/item/weapon/paper/verb/rename()
	set name = "Rename paper"
	set category = null
	set src in usr
	playsound(src,'sound/effects/pen.ogg',40,1)

	var/mob/renamer = usr
	var/client/rename_client = renamer ? renamer.client : null
	var/list/rename_record = document_record
	var/list/rename_edit = null
	var/list/rename_legacy = paper_document_legacy_snapshot(src)
	if (!rename_client || !rename_legacy)
		return
	var/rename_legacy_json = json_encode(rename_legacy)
	if (!isnull(rename_record))
		rename_edit = paper_document_prepare_edit(src)
		if (!rename_edit)
			return
	var/n_name = sanitizeSafe(player_input(renamer, "What would you like to label the paper?", "Paper Labelling", null, "text", null, FALSE), MAX_NAME_LEN)

	// Retain the existing one-level label admission, including held containers.
	// Bind the original body/client and reject a concurrent edit after input().
	if (!gc_destroyed && usr == renamer && renamer.client == rename_client && rename_client.mob == renamer && (loc == renamer || loc && loc.loc == renamer) && renamer.stat == FALSE && n_name && document_record == rename_record && json_encode(paper_document_legacy_snapshot(src)) == rename_legacy_json)
		if (!paper_document_set_name(src, n_name, rename_edit))
			return
		if (n_name != "paper")
			desc = "This is a paper titled '" + name + "'."

		add_fingerprint(usr)
	return

/obj/item/weapon/paper/attack_self(mob/living/user as mob)
	if (user.a_intent == I_HARM)
		if (icon_state == "scrap")
			user.show_message("<span class='warning'>\The [src] is already crumpled.</span>")
			return
		//crumple dat paper
		if (!paper_document_crumple(src))
			return
		user.visible_message("\The [user] crumples \the [src] into a ball!")
		if (map.ordinal_age <= 1)
			if (info)
				icon_state = "scrollpaper1_scrap"
			else
				icon_state = "scrollpaper0_scrap"
		else
			icon_state = "scrap"
		return
	user.examinate(src)
	return


/obj/item/weapon/paper/attack(mob/living/human/M as mob, mob/living/human/user as mob)
	if (user.targeted_organ == "eyes")
		user.visible_message(SPAN_NOTICE("You shoe the paper to [M]."))
		visible_message(SPAN_NOTICE("[user] holds up a paper and shows it to [M]."))
		M.examinate(src)

	else if (user.targeted_organ == "mouth") // lipstick wiping
		if (ishuman(M))
			var/mob/living/human/H = M
			if (H == user)
				to_chat(user, SPAN_NOTICE("You wipe off the lipstick with [src]."))
				H.lip_style = null
				H.update_body()
			else
				visible_message(SPAN_WARNING("[user] begins to wipe [H]'s lipstick off with the [src]."))
				user.visible_message(SPAN_NOTICE("You begin to wipe off [H]'s lipstick."))
				if (do_after(user, 10, H) && do_after(H, 10, needhand = FALSE))    //user needs to keep their active hand, H does not.
					visible_message(SPAN_NOTICE("[user] wipes [H]'s lipstick off with the [src]."))
					user.visible_message(SPAN_NOTICE("You wipe off [H]'s lipstick."))
					H.lip_style = null
					H.update_body()

/obj/item/weapon/paper/proc/legacy_field_offset(field_text, id)
	if (!isnum(id) || id != round(id) || id < 1 || id > MAX_FIELDS)
		return 0
	var/start = 0
	for (var/index = 1, index <= id, index++)
		start = findtext(field_text, "<span class=\"paper_field\">", start + 1)
		if (!start)
			return 0
	return findtext(field_text, "</span>", start)

/obj/item/weapon/paper/proc/updateinfolinks()
	info_links = info
	var/i = FALSE
	for (i=1,i<=fields,i++)
		var/text_index = legacy_field_offset(info_links, i)
		if (text_index)
			var/link = "<font face=\"[deffont]\"><A href='?src=\ref[src];write=[i]'>write</A></font>"
			info_links = copytext(info_links, 1, text_index) + link + copytext(info_links, text_index)
	info_links = info_links + "<font face=\"[deffont]\"><A href='?src=\ref[src];write=end'>write</A></font>"


/obj/item/weapon/paper/proc/clearpaper()
	if (!isnull(document_record))
		// Trusted physical erasure (acetone/ethanol), not an actor/UI edit grant.
		// Keep document identity/sequence, erase every classified run atomically.
		var/list/edit = paper_document_prepare_edit(src)
		if (!edit)
			return FALSE
		var/list/next = edit["record"]
		var/list/legacy = next["legacy"]
		legacy["info"] = null
		legacy["stamps"] = null
		legacy["free_space"] = MAX_PAPER_MESSAGE_LEN
		legacy["stamped"] = list()
		next["sections"] = list()
		next["revision"]++
		if (!paper_document_commit_edit(src, edit))
			return FALSE
	else
		info = null
		stamps = null
		free_space = MAX_PAPER_MESSAGE_LEN
		stamped = list()
		paper_authoring_notify(src, "physical")
	overlays.Cut()
	updateinfolinks()
	update_icon()
	return TRUE

/obj/item/weapon/paper/proc/get_signature(var/obj/item/weapon/pen/P, mob/user as mob)
	if (P && istype(P, /obj/item/weapon/pen))
		return P.get_signature(user)
	return (user && user.real_name) ? user.real_name : "Anonymous"

/obj/item/weapon/paper/proc/parsepencode(var/t, var/obj/item/weapon/pen/P, mob/user as mob, var/iscrayon = FALSE, var/count_fields = TRUE)

	t = replacetext(t, "\[center\]", "<center>")
	t = replacetext(t, "\[/center\]", "</center>")
	t = replacetext(t, "\[br\]", "<BR>")
	t = replacetext(t, "\[b\]", "<b>")
	t = replacetext(t, "\[/b\]", "</b>")
	t = replacetext(t, "\[i\]", "<I>")
	t = replacetext(t, "\[/i\]", "</I>")
	t = replacetext(t, "\[u\]", "<U>")
	t = replacetext(t, "\[/u\]", "</U>")
	t = replacetext(t, "\[time\]", "[stationtime2text()]")
	t = replacetext(t, "\[date\]", "[stationdate2text()]")
	t = replacetext(t, "\[large\]", "<font size=\"4\">")
	t = replacetext(t, "\[/large\]", "</font>")
	t = replacetext(t, "\[sign\]", "<font face=\"[signfont]\"><i>[get_signature(P, user)]</i></font>")
	t = replacetext(t, "\[field\]", "<span class=\"paper_field\"></span>")

	t = replacetext(t, "\[h1\]", "<H1>")
	t = replacetext(t, "\[/h1\]", "</H1>")
	t = replacetext(t, "\[h2\]", "<H2>")
	t = replacetext(t, "\[/h2\]", "</H2>")
	t = replacetext(t, "\[h3\]", "<H3>")
	t = replacetext(t, "\[/h3\]", "</H3>")

	if (!iscrayon)
		t = replacetext(t, "\[*\]", "<li>")
		t = replacetext(t, "\[hr\]", "<HR>")
		t = replacetext(t, "\[small\]", "<font size = \"1\">")
		t = replacetext(t, "\[/small\]", "</font>")
		t = replacetext(t, "\[list\]", "<ul>")
		t = replacetext(t, "\[/list\]", "</ul>")
		t = replacetext(t, "\[table\]", "<table border=1 cellspacing=0 cellpadding=3 style='border: TRUEpx solid black;'>")
		t = replacetext(t, "\[/table\]", "</td></tr></table>")
		t = replacetext(t, "\[grid\]", "<table>")
		t = replacetext(t, "\[/grid\]", "</td></tr></table>")
		t = replacetext(t, "\[row\]", "</td><tr>")
		t = replacetext(t, "\[cell\]", "<td>")

		t = "<font face=\"[deffont]\" color=[P ? P.colour : "black"]>[t]</font>"
	else // If it is a crayon, and he still tries to use these, make them empty!
		t = replacetext(t, "\[*\]", "")
		t = replacetext(t, "\[hr\]", "")
		t = replacetext(t, "\[small\]", "")
		t = replacetext(t, "\[/small\]", "")
		t = replacetext(t, "\[list\]", "")
		t = replacetext(t, "\[/list\]", "")
		t = replacetext(t, "\[table\]", "")
		t = replacetext(t, "\[/table\]", "")
		t = replacetext(t, "\[row\]", "")
		t = replacetext(t, "\[cell\]", "")
		t = replacetext(t, "\[logo\]", "")

		t = "<font face=\"[crayonfont]\" color=[P ? P.colour : "black"]><b>[t]</b></font>"


//	t = replacetext(t, "#", "") // Junk converted to nothing!

	if (count_fields)
		var/new_fields = legacy_new_fields(t, MAX_FIELDS - fields)
		if (new_fields)
			fields += new_fields
	return t

/obj/item/weapon/paper/proc/legacy_new_fields(text, limit)
	var/count = 0
	var/start = 0
	while (count < limit)
		start = findtext(text, "<span class=\"paper_field\">", start + 1)
		if (!start)
			break
		count++
	return count

/obj/item/weapon/paper/proc/burnpaper(obj/item/weapon/flame/P, mob/user)
	var/class = "warning"

	if (P.lit && !user.restrained())
		if (istype(P, /obj/item/weapon/flame/lighter/zippo))
			class = "rose"

		user.visible_message("<span class='[class]'>[user] holds \the [P] up to \the [src], it looks like \he's trying to burn it!</span>", \
		"<span class='[class]'>You hold \the [P] up to \the [src], burning it slowly.</span>")

		spawn(20)
			if (get_dist(src, user) < 2 && user.get_active_hand() == P && P.lit)
				user.visible_message("<span class='[class]'>[user] burns right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap.</span>", \
				"<span class='[class]'>You burn right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap.</span>")

				if (user.get_inactive_hand() == src)
					user.drop_from_inventory(src)

				new /obj/effect/decal/cleanable/ash(loc)
				qdel(src)

			else
				to_chat(user, SPAN_RED("You must hold \the [P] steady to burn \the [src]."))


/obj/item/weapon/paper/Topic(href, href_list)
	..()
	if (!usr || (usr.stat || usr.restrained()))
		return

	if (href_list["write"])
		var/mob/writer = usr
		var/client/writer_client = writer.client
		var/obj/item/weapon/pen/writing_pen = writer.get_active_hand()
		if (!paper_document_legacy_edit_allowed(src, writer, writer_client, writing_pen))
			return
		var/id = href_list["write"]
		var/append_at_end = id == "end"
		var/field_id = append_at_end ? null : text2num(id)
		var/field_offset = 0
		if (!append_at_end)
			if ("[field_id]" != id || field_id > fields)
				return
			field_offset = legacy_field_offset(info, field_id)
			if (!field_offset)
				return

		if (free_space <= 0)
			to_chat(writer, SPAN_INFO("There isn't enough space left on \the [src] to write anything."))
			return

		var/expected_info = info
		var/expected_fields = fields
		var/expected_space = free_space
		var/atom/expected_loc = loc
		var/raw = input(writer, "Enter what you want to write:", "Write", null, null) as null|message
		if (!raw || usr != writer || !paper_document_legacy_edit_allowed(src, writer, writer_client, writing_pen))
			return
		// Preserve the original classic route's range policy.
		if (loc != writer && !Adjacent(writer) && !((istype(loc, /obj/item/weapon/clipboard) || istype(loc, /obj/item/weapon/folder)) && (loc.loc == writer || loc.Adjacent(writer))))
			return
		if (loc != expected_loc || info != expected_info || fields != expected_fields || free_space != expected_space)
			to_chat(writer, SPAN_INFO("The paper changed while you were writing. Open it again to continue."))
			return
		var/t = sanitize(raw, free_space, extra = FALSE)
		if (!t)
			return
		t = replacetext(t, "\n", "<BR>")
		t = parsepencode(t, writing_pen, writer, istype(writing_pen, /obj/item/weapon/pen/crayon), FALSE)
		var/cost = length(strip_html_properly(t))
		var/new_fields = legacy_new_fields(t, MAX_FIELDS - fields + 1)
		if (cost > free_space)
			to_chat(writer, SPAN_INFO("There isn't enough space left on \the [src] for that text."))
			return
		if (fields + new_fields > MAX_FIELDS)
			to_chat(writer, SPAN_WARNING("Too many fields. Sorry, You cannot do this."))
			return

		// Commit text, field count and capacity together before any listeners run.
		if (append_at_end)
			info += t
		else
			info = copytext(info, 1, field_offset) + t + copytext(info, field_offset)
		fields += new_fields
		free_space -= cost
		updateinfolinks()
		paper_authoring_notify(src, "physical")
		playsound(src,'sound/effects/pen.ogg',40,1)
		show_document(usr, FALSE, "editor") // Project the legacy editor refresh.
		update_icon()


/obj/item/weapon/paper/attackby(obj/item/weapon/P as obj, mob/user as mob)
	..()
	if (istype(P, /obj/item/weapon/paper))
		var/obj/item/weapon/paper_bundle/B = new(loc)
		if (name != "paper")
			B.name = name
		else if (P.name != "paper" && P.name != "photo")
			B.name = P.name
		user.drop_from_inventory(P)
		if (istype(user, /mob/living/human))
			var/mob/living/human/h_user = user
			if (h_user.r_hand == src)
				h_user.drop_from_inventory(src)
				h_user.put_in_r_hand(B)
			else if (h_user.l_hand == src)
				h_user.drop_from_inventory(src)
				h_user.put_in_l_hand(B)
			else if (h_user.l_store == src)
				h_user.drop_from_inventory(src)
				B.loc = h_user
				B.layer = 20
				h_user.l_store = B
				h_user.update_inv_pockets()
			else if (h_user.r_store == src)
				h_user.drop_from_inventory(src)
				B.loc = h_user
				B.layer = 20
				h_user.r_store = B
				h_user.update_inv_pockets()
			else if (h_user.head == src)
				h_user.u_equip(src)
				h_user.put_in_hands(B)
			else if (!istype(loc, /turf))
				loc = get_turf(h_user)
				if (h_user.client)	h_user.client.screen -= src
				h_user.put_in_hands(B)
		to_chat(user, "<span class='notice'>You clip the [P.name] to [(name == "paper") ? "the paper" : name].</span>")
		pile_reveal() // raw move out of a ground pile skips turf exit
		loc = B
		P.loc = B

		B.pages.Add(src)
		B.pages.Add(P)
		B.update_icon()
		paper_authoring_notify(src, "physical")
		paper_authoring_notify(P, "physical")

	else if (istype(P, /obj/item/weapon/pen))
		if (icon_state == "scrap")
			to_chat(usr, SPAN_WARNING("\The [src] is too crumpled to write on."))
			return
/*
		var/obj/item/weapon/pen/robopen/RP = P
		if ( istype(RP) && RP.mode == 2 )
			RP.RenamePaper(user,src)
		else*/
		if (paper_editor_try_entrypoint(src, user, P))
			return
		show_document(user, FALSE, "editor")
		return

	else if (istype(P, /obj/item/weapon/stamp))
		// Ink stamps and wax seals both leave a saved impression (stamps.dm).
		var/stamp_result = paper_document_apply_stamp(src, P, user)
		if (stamp_result == "crumpled")
			to_chat(user, SPAN_WARNING("\The [src] is too crumpled to stamp."))
			return
		if (stamp_result == "full")
			to_chat(user, SPAN_WARNING("There is no room left on \the [src] for another stamp."))
			return
		if (stamp_result != "stamped")
			to_chat(user, SPAN_WARNING("You cannot stamp \the [src] right now."))
			return
		playsound(src,'sound/effects/stamp_down.ogg', 70, TRUE)
		to_chat(user, SPAN_NOTICE("You stamp the paper with the [P.name]."))

	else if (istype(P, /obj/item/weapon/flame))
		burnpaper(P, user)

	add_fingerprint(user)
	return

/*
 * Premade paper
 */
/obj/item/weapon/paper/Court/british
	name = "Crown Court Judgement"
	info = "For crimes against the crown, the offender is sentenced to:<BR>\n<BR>\n"

/obj/item/weapon/paper/Court/pirates
	name = "Ship Judgement"
	info = "For crimes against the crew, the offender is sentenced to:<BR>\n<BR>\n"

/obj/item/weapon/paper/crumpled
	name = "paper scrap"
	icon_state = "scrap"

/obj/item/weapon/paper/crumpled/update_icon()
	return

/obj/item/weapon/paper/crumpled/bloody
	icon_state = "scrap_bloodied"
