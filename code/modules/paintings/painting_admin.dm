// Admin > Player Art: every finished painting in this world with its painter,
// a thumbnail drawn by the admin's browser, and Jump, View and Remove links.

var/global/datum/painting_admin/painting_admin = new

/datum/painting_admin

/datum/admins/proc/player_art()
	set category = "Admin"
	set name = "Player Art"
	set desc = "See every finished player painting in this world, who painted it, and remove offensive ones."
	if (!check_rights(R_ADMIN))
		return
	painting_admin.show(usr)

/datum/painting_admin/proc/painting_place(atom/C)
	var/turf/T = get_turf(C)
	if (!T)
		return "nowhere"
	var/where = "[T.loc ? T.loc.name : "?"] ([T.x],[T.y],[T.z])"
	var/atom/holder = C.loc
	while (holder && !isturf(holder))
		if (ismob(holder))
			return "carried by [key_name(holder)], [where]"
		holder = holder.loc
	return where

/datum/painting_admin/proc/show(mob/user)
	if (!user || !user.client)
		return
	var/list/html = list("<html><head><meta charset='utf-8'><title>Player Art</title><style>body{background:#222;color:#ddd;font-family:Verdana;font-size:12px}table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #444;padding:3px 6px;text-align:left;vertical-align:middle}canvas{image-rendering:pixelated;border:1px solid #555}a{color:#9cf}</style></head><body>")
	html += "<p>[painting_registry.len] finished paintings, using [painting_weight_total()] of [PAINTING_REGION_CAP] places (small ones count a quarter).</p>"
	html += "<table><tr><th></th><th>Title</th><th>Painter</th><th>Format</th><th>Painted</th><th>Where</th><th></th></tr>"
	var/list/thumbs = list()
	var/i = 0
	for (var/obj/item/canvas/C in painting_registry)
		i++
		var/turf/T = get_turf(C)
		html += "<tr><td><canvas id='p[i]'></canvas></td><td>[html_encode(C.title || "Untitled")]</td><td>[html_encode(C.author_name)] ([html_encode(C.author_ckey)])</td><td>[C.format] [C.canvas_w]x[C.canvas_h][C.imported_design ? " (from a design code)" : ""]</td><td>[C.painted_at]</td><td>[html_encode(painting_place(C))]</td>"
		html += "<td><a href='?src=\ref[src];view=\ref[C]'>View</a> "
		if (T)
			html += "<a href='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>Jump</a> "
		html += "<a href='?src=\ref[src];remove=\ref[C]'>Remove</a></td></tr>"
		thumbs += "\['p[i]',[C.art_w],[C.art_h],'[C.small]'\]"
	html += "</table>"
	drawing_holders_refresh()
	var/list/drawn = list()
	for (var/atom/A in drawing_holders)
		var/list/items = drawing_list(A)
		for (var/n = 1, n <= items.len, n++)
			var/list/D = items[n]
			if (!drawing_valid(D))
				continue
			i++
			drawn += "<tr><td><canvas id='p[i]'></canvas></td><td>[html_encode(D["title"])]</td><td>[html_encode(D["by"])] ([html_encode(D["ckey"])])</td><td>[html_encode(A.name)][D["imported"] ? " (from a design code)" : ""]</td><td>[D["date"]]</td><td>[html_encode(painting_place(A))]</td><td><a href='?src=\ref[src];remove_drawing=\ref[A];n=[n]'>Remove</a></td></tr>"
			thumbs += "\['p[i]',[D["w"]],[D["h"]],'',\[[json_encode(painting_palette_list(D["palette"]))],'[painting_unpack(D["data"], D["w"] * D["h"])]'\]\]"
	if (drawn.len)
		html += "<h3>Drawings on paper and in books</h3><table><tr><th></th><th>Title</th><th>Drawn by</th><th>On</th><th>Drawn</th><th>Where</th><th></th></tr>[jointext(drawn, "")]</table>"
	html += painting_import_log_html()
	html += "<script>var T=\[[jointext(thumbs, ",")]\];"
	html += {"for(var i=0;i<T.length;i++){var t=T\[i],cv=document.getElementById(t\[0]),k=Math.max(1,Math.floor(48/Math.max(t\[1],t\[2])));cv.width=t\[1]*k;cv.height=t\[2]*k;var g=cv.getContext('2d'),s=t\[3];if(t\[4]){for(var j=0;j<t\[1]*t\[2];j++){g.fillStyle=t\[4]\[0]\[parseInt(t\[4]\[1].charAt(j),16)];g.fillRect((j%t\[1])*k,Math.floor(j/t\[1])*k,k,k);}continue;}for(var j=0;j<t\[1]*t\[2]&&j*3<s.length;j++){var c=s.substr(j*3,3);g.fillStyle='#'+c;g.fillRect((j%t\[1])*k,Math.floor(j/t\[1])*k,k,k);}}"}
	html += "</script></body></html>"
	show_browse(user, jointext(html, ""), "window=player_art;size=900x600")

/datum/painting_admin/Topic(href, list/href_list)
	if (!check_rights(R_ADMIN))
		return
	var/mob/user = usr
	if (href_list["view"])
		var/obj/item/canvas/C = locate(href_list["view"])
		if (istype(C) && (C in painting_registry))
			painting_show_full(user, C)
		return
	if (href_list["remove_drawing"])
		var/atom/A = locate(href_list["remove_drawing"])
		var/n = text2num(href_list["n"])
		var/list/items = A ? drawing_list(A) : null
		if (!items || !isnum(n) || n < 1 || n > items.len)
			return
		var/list/D = items[n]
		if (WWinput(user, "Remove the drawing \"[D["title"]]\" by [D["by"]] ([D["ckey"]])?", "Player Art", "Cancel", list("Remove", "Cancel")) != "Remove")
			return
		items = drawing_list(A)
		if (!check_rights(R_ADMIN) || QDELETED(A) || !items || n > items.len || items[n] != D)
			return
		log_admin("[key_name(user)] removed the drawing \"[D["title"]]\" by [D["by"]] ([D["ckey"]]) from [A] at [painting_place(A)].")
		message_admins("[key_name_admin(user)] removed the drawing \"[html_encode(D["title"])]\" by [html_encode(D["by"])] ([D["ckey"]]).")
		var/list/kept = items.Copy()
		kept.Cut(n, n + 1)
		drawing_set_list(A, kept.len ? kept : null)
		show(user)
		return
	if (href_list["remove"])
		var/obj/item/canvas/C = locate(href_list["remove"])
		if (!istype(C) || !(C in painting_registry))
			return
		if (WWinput(user, "Remove \"[C.title || "Untitled"]\" by [C.author_name] ([C.author_ckey]) for good?", "Player Art", "Cancel", list("Remove", "Cancel")) != "Remove")
			return
		if (!check_rights(R_ADMIN) || QDELETED(C))
			return
		var/place = painting_place(C)
		log_admin("[key_name(user)] removed the painting \"[C.title]\" by [C.author_name] ([C.author_ckey]) at [place].")
		message_admins("[key_name_admin(user)] removed the painting \"[html_encode(C.title)]\" by [html_encode(C.author_name)] ([C.author_ckey]).")
		var/atom/holder = C.loc
		if (istype(holder, /obj/structure/painting_frame))
			qdel(holder) // drops the canvas, deleted next
		qdel(C)
		if (istype(holder, /obj/structure/easel) || istype(holder, /obj/item/clothing/accessory/necklace))
			var/obj/O = holder
			O.update_icon()
			var/atom/wearer = holder.loc
			while (wearer && !isturf(wearer) && !ismob(wearer))
				wearer = wearer.loc
			if (ismob(wearer))
				var/mob/M = wearer
				M.regenerate_icons()
		show(user)
