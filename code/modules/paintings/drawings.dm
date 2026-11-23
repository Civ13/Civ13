// Drawings on paper and in books: the painting editor on a page. A drawing is
// kept on the paper or book itself (drawings, a list of small records), drawn
// by the reader's browser, copied with paper by the printing press and the
// mail, carried into a book when its page is bound, and copied with books by
// monks. They never become server icons.

#define DRAWINGS_PER_PAPER 2
#define DRAWINGS_PER_BOOK 12

/obj/item/weapon/paper/var/list/drawings = null
/obj/item/weapon/book/var/list/drawings = null

var/global/list/drawing_holders = list() // papers and books with drawings

/proc/drawing_limit(atom/A)
	return istype(A, /obj/item/weapon/book) ? DRAWINGS_PER_BOOK : DRAWINGS_PER_PAPER

/proc/drawing_list(atom/A)
	if (istype(A, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = A
		return P.drawings
	if (istype(A, /obj/item/weapon/book))
		var/obj/item/weapon/book/B = A
		return B.drawings
	return null

/proc/drawing_set_list(atom/A, list/value)
	if (istype(A, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = A
		P.drawings = value
	else if (istype(A, /obj/item/weapon/book))
		var/obj/item/weapon/book/B = A
		B.drawings = value
	if (length(value))
		drawing_holders |= A
	else
		drawing_holders -= A
	// Removing an artwork must not leave its appearance hanging in a frame.
	var/obj/structure/painting_frame/F = A?.loc
	if (istype(F) && !QDELETED(F))
		F.update_icon()

// A checked drawing record, or null.
/proc/drawing_valid(list/D)
	if (!islist(D) || !isnum(D["w"]) || !isnum(D["h"]) || !(D["w"] in list(32, 64)) || D["w"] != D["h"])
		return FALSE
	var/list/pal = painting_palette_list(D["palette"])
	return pal && painting_unpack(D["data"], D["w"] * D["h"]) && istext(D["title"])

/proc/drawings_copy(list/source)
	if (!length(source))
		return null
	var/list/out = list()
	for (var/list/D in source)
		if (drawing_valid(D))
			out += list(D.Copy())
	return out.len ? out : null

/proc/drawing_add(atom/A, list/D)
	var/list/current = drawing_list(A)
	if (!islist(current))
		current = list()
	if (current.len >= drawing_limit(A) || !drawing_valid(D))
		return FALSE
	current += list(D)
	drawing_set_list(A, current)
	return TRUE

// Every drawing on a page or book, for the reader's browser.
/proc/drawings_html(atom/A, mob/reader = null)
	var/list/items = drawing_list(A)
	if (!length(items))
		return ""
	var/list/html = list("<div style='margin-top:10px'>")
	var/list/calls = list()
	var/i = 0
	for (var/list/D in items)
		if (!drawing_valid(D))
			continue
		i++
		var/k = D["w"] >= 64 ? 4 : 6
		html += "<div style='display:inline-block;margin:6px;text-align:center;vertical-align:top'><canvas id='drawing[i]' style='image-rendering:pixelated;border:1px solid #999'></canvas><br><i>[html_encode(D["title"])]</i>[painting_code_allowed(reader, D["ckey"]) ? painting_code_box(painting_design_code(D["w"], D["h"], D["palette"], D["data"])) : ""]</div>"
		calls += "drawArt(document.getElementById('drawing[i]'),[D["w"]],[D["h"]],'[D["palette"]]'.split(','),unpackArt('[D["data"]]',[D["w"] * D["h"]]),[k]);"
	if (!i)
		return ""
	html += "</div><script>[painting_draw_script()][jointext(calls, "")]</script>"
	return jointext(html, "")

// The same artwork, reduced to the existing table-frame window. The
// original drawing record and full-resolution pixels remain on its sheet.
/proc/framed_sketch_thumbnail(obj/item/weapon/paper/P)
	if (!istype(P) || QDELETED(P) || !length(P.drawings))
		return null
	for (var/list/D in P.drawings)
		if (!drawing_valid(D))
			continue
		var/plain = painting_unpack(D["data"], D["w"] * D["h"])
		var/list/palette = painting_palette_list(D["palette"])
		if (painting_max_index(plain) >= palette.len)
			continue
		var/small = painting_shrink(plain, palette, D["w"], D["h"], 16, 16)
		return painting_build_icon(small, 16, 16, 8, 6, 'icons/obj/paintings.dmi', "canvas_table")
	return null

// Books show their pictures beside the reader.
/obj/item/weapon/book/proc/show_drawings(mob/user)
	if (!length(drawings) || !user || !user.client)
		return
	show_browse(user, "<html><head><meta charset='utf-8'><title>Pictures in [html_encode(title || name)]</title></head><body style='background:#f4efe1;font-family:Georgia,serif'>[drawings_html(src, user)]</body></html>", "window=book_pictures;size=420x[min(700, 160 + 280 * round((drawings.len + 1) / 2))]")

// The printing press and the mail copy a page's drawings with it.
/obj/item/weapon/paper/proc/copy_drawings_from(obj/item/weapon/paper/source)
	if (istype(source))
		drawing_set_list(src, drawings_copy(source.drawings))

// Binding a loose page into a book keeps its drawings.
/obj/item/weapon/book/proc/page_drawings_fit(obj/item/weapon/paper/P)
	return length(drawings) + length(P.drawings) <= DRAWINGS_PER_BOOK

/obj/item/weapon/book/proc/take_page_drawings(obj/item/weapon/paper/P)
	for (var/list/D in drawings_copy(P.drawings))
		if (!drawing_add(src, D))
			break

/////////////////////////////// Drawing ///////////////////////////////

/obj/item/weapon/paper/verb/draw_picture()
	set name = "Draw Picture"
	set category = "Object"
	set src in usr
	drawing_start(usr, src)

/obj/item/weapon/book/verb/draw_picture()
	set name = "Draw Picture"
	set category = "Object"
	set src in usr
	if (!can_hold_notes())
		to_chat(usr, SPAN_WARNING("You can't draw in \the [src]."))
		return
	drawing_start(usr, src)

// What a drawing hand holds: a pen, crayon, pencil or pigment.
/proc/drawing_tool(mob/user)
	var/obj/item/I = user.get_active_hand()
	if (istype(I, /obj/item/weapon/pen) || istype(I, /obj/item/pigment))
		return I
	return null

/proc/drawing_start(mob/user, atom/target)
	if (!user || !user.client || user.incapacitated())
		return
	if (!drawing_tool(user))
		to_chat(user, SPAN_WARNING("Hold a pen, a pencil, a crayon or some pigment to draw."))
		return
	if (length(drawing_list(target)) >= drawing_limit(target))
		to_chat(user, SPAN_WARNING("There is no room left for another picture on \the [target]."))
		return
	var/size = WWinput(user, "How big a picture?", "Draw Picture", "Small sketch", list("Small sketch", "Large drawing", "Cancel"))
	if (!size || size == "Cancel" || QDELETED(target) || !(target in user.get_contents()))
		return
	var/obj/item/canvas/sketch/S = new(null)
	S.target = target
	S.canvas_w = size == "Large drawing" ? 64 : 32
	S.canvas_h = S.canvas_w
	S.art_w = S.canvas_w
	S.art_h = S.canvas_h
	S.name = "picture on \the [target]"
	painting_open_editor(user, S)
	if (S.editing != user)
		qdel(S)

/obj/item/canvas/sketch
	name = "sketch"
	format = "sketch"
	format_weight = 0
	needs_easel = FALSE
	base_colour = "#f4efe1"
	var/tmp/atom/target = null

/obj/item/canvas/sketch/persistence_runtime_var(key)
	return key == "target" || ..()

/obj/item/canvas/sketch/refresh_small()
	small = null
	return TRUE

/obj/item/canvas/sketch/update_icon()
	return

// The held pen's or crayon's ink.
/obj/item/canvas/sketch/extra_colours(mob/user)
	var/obj/item/weapon/pen/P = user.get_active_hand()
	if (!istype(P))
		return list()
	var/hex = painting_hex(book_page_ink(P.colour))
	return hex ? list(hex) : list()

/obj/item/canvas/sketch/on_finished(mob/user)
	painting_registry -= src
	var/list/D = list("w" = canvas_w, "h" = canvas_h, "palette" = palette, "data" = paint_data, "title" = title, "by" = author_name, "ckey" = author_ckey, "date" = painted_at)
	if (imported_design)
		D["imported"] = 1
	if (QDELETED(target) || !drawing_add(target, D))
		to_chat(user, SPAN_WARNING("The picture would not fit on \the [target]."))
	else
		to_chat(user, SPAN_NOTICE("You draw [painting_name_text()] on \the [target]."))
	qdel(src)

/obj/item/canvas/sketch/editor_closed()
	if (!QDELETED(src))
		qdel(src)

/////////////////////////////// Admin list ///////////////////////////////

// Loaded pages and books with drawings join the admin list.
/obj/item/weapon/paper/after_load()
	..()
	if (length(drawings))
		drawing_holders |= src

/obj/item/weapon/book/after_load()
	..()
	if (length(drawings))
		drawing_holders |= src

/proc/drawing_holders_refresh()
	for (var/atom/A in drawing_holders.Copy())
		if (QDELETED(A) || !length(drawing_list(A)))
			drawing_holders -= A

#undef DRAWINGS_PER_PAPER
#undef DRAWINGS_PER_BOOK
