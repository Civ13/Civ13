// Player paintings: how a painting is stored, shrunk and drawn.
//
// A painting is a palette of up to PAINT_MAX_COLOURS "#rrggbb" colours (comma
// separated text) and one hex digit per pixel naming a palette entry, row by
// row from the top left. Runs of four or more equal pixels are packed as
// "<digit>~<count>." so plain backgrounds stay small; a 128x128 painting is at
// most 16 KB and usually a few KB. The world shows a shrunk copy ("small",
// three hex digits per pixel, 12-bit colour) built once when the painting is
// saved, by averaging each block of pixels in linear light. Only that small
// copy becomes a server icon, shared by identical paintings through
// painting_icon_cache. The full painting is drawn by the viewer's browser.
//
// The canvas and frame objects borrow the shape of tgstation's canvas system
// (easel, canvas sizes, framing), first ported to Civ13 in 2020; the editor,
// storage and rendering here are new.

// Painting size and palette: code/__defines/paintings.dm
#define PAINT_PART_LENGTH 1000 // characters per upload part
#define PAINT_MAX_PARTS 40
#define PAINT_TITLE_LENGTH 40

var/global/list/painting_icon_cache = list() // "<format>|<small>" -> icon
var/global/list/painting_linear_table = null // 0..255 sRGB -> linear light
var/global/list/painting_registry = list() // finished paintings in this world

/proc/painting_linear(c)
	if (!painting_linear_table)
		painting_linear_table = new /list(256)
		for (var/i = 0, i <= 255, i++)
			var/v = i / 255
			painting_linear_table[i + 1] = v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
	return painting_linear_table[clamp(round(c), 0, 255) + 1]

/proc/painting_srgb(v)
	v = clamp(v, 0, 1)
	v = v <= 0.0031308 ? v * 12.92 : 1.055 * (v ** (1 / 2.4)) - 0.055
	return clamp(round(v * 255), 0, 255)

// "#rrggbb" in lower case, or null.
/proc/painting_hex(value)
	if (!istext(value) || length(value) != 7 || copytext(value, 1, 2) != "#")
		return null
	value = lowertext(value)
	for (var/i = 2, i <= 7, i++)
		var/c = text2ascii(value, i)
		if (!((c >= 48 && c <= 57) || (c >= 97 && c <= 102)))
			return null
	return value

/proc/painting_rgb(hex)
	return list(hex2num(copytext(hex, 2, 4)), hex2num(copytext(hex, 4, 6)), hex2num(copytext(hex, 6, 8)))

/proc/painting_hex_of(r, g, b)
	return lowertext(rgb(r, g, b))

// Two colours mixed half and half, as the editor mixes them.
/proc/painting_mix(a, b)
	var/list/x = painting_rgb(a)
	var/list/y = painting_rgb(b)
	return painting_hex_of(round((x[1] + y[1]) / 2), round((x[2] + y[2]) / 2), round((x[3] + y[3]) / 2))

// The palette text as a list, or null when malformed.
/proc/painting_palette_list(text)
	if (!istext(text) || !length(text))
		return null
	var/list/out = splittext(text, ",")
	if (!out.len || out.len > PAINT_MAX_COLOURS)
		return null
	for (var/i = 1, i <= out.len, i++)
		out[i] = painting_hex(out[i])
		if (!out[i])
			return null
	return out

// Packed pixels -> plain text of one digit per pixel, or null when malformed
// or not exactly count pixels long.
/proc/painting_unpack(packed, count)
	if (!istext(packed) || count < 1)
		return null
	var/list/out = list()
	var/total = 0
	var/n = length(packed)
	var/i = 1
	while (i <= n)
		var/c = copytext(packed, i, i + 1)
		var/code = text2ascii(c)
		if (!((code >= 48 && code <= 57) || (code >= 97 && code <= 102)))
			return null
		i++
		var/run = 1
		if (i <= n && copytext(packed, i, i + 1) == "~")
			var/stop = findtext(packed, ".", i + 1)
			if (!stop || stop - i > 6)
				return null
			run = text2num(copytext(packed, i + 1, stop))
			if (!isnum(run) || run < 4 || run != round(run))
				return null
			i = stop + 1
		total += run
		if (total > count)
			return null
		out += (run == 1 ? c : painting_repeat(c, run))
	if (total != count)
		return null
	return jointext(out, "")

/proc/painting_repeat(c, run)
	var/list/parts = list()
	for (var/k = 1, k <= run, k++)
		parts += c
	return jointext(parts, "")

/proc/painting_pack(plain)
	var/list/out = list()
	var/n = length(plain)
	var/i = 1
	while (i <= n)
		var/c = copytext(plain, i, i + 1)
		var/j = i + 1
		while (j <= n && copytext(plain, j, j + 1) == c)
			j++
		var/run = j - i
		if (run >= 4)
			out += "[c]~[run]."
		else
			out += painting_repeat(c, run)
		i = j
	return jointext(out, "")

// The highest palette digit used by plain pixels.
/proc/painting_max_index(plain)
	var/top = 0
	for (var/i = 1, i <= length(plain), i++)
		var/code = text2ascii(plain, i)
		var/v = code <= 57 ? code - 48 : code - 87
		if (v > top)
			top = v
	return top

// Shrinks w x h plain pixels to aw x ah by averaging each source block in
// linear light. Returns 3 hex digits per small pixel, top row first.
/proc/painting_shrink(plain, list/palette, w, h, aw, ah)
	var/list/lin = list()
	for (var/hex in palette)
		var/list/c = painting_rgb(hex)
		lin += list(list(painting_linear(c[1]), painting_linear(c[2]), painting_linear(c[3])))
	var/list/out = list()
	for (var/sy = 0, sy < ah, sy++)
		var/y0 = round(sy * h / ah)
		var/y1 = max(y0 + 1, round((sy + 1) * h / ah))
		for (var/sx = 0, sx < aw, sx++)
			var/x0 = round(sx * w / aw)
			var/x1 = max(x0 + 1, round((sx + 1) * w / aw))
			var/r = 0
			var/g = 0
			var/b = 0
			var/n = 0
			for (var/y = y0, y < y1, y++)
				var/row = y * w
				for (var/x = x0, x < x1, x++)
					var/code = text2ascii(plain, row + x + 1)
					var/list/c = lin[(code <= 57 ? code - 48 : code - 87) + 1]
					r += c[1]
					g += c[2]
					b += c[3]
					n++
			out += painting_small_digit(painting_srgb(r / n))
			out += painting_small_digit(painting_srgb(g / n))
			out += painting_small_digit(painting_srgb(b / n))
	return jointext(out, "")

/proc/painting_small_digit(c)
	var/v = round((c + 8) / 17)
	return copytext("0123456789abcdef", clamp(v, 0, 15) + 1, clamp(v, 0, 15) + 2)

// An icon (copy of base_icon/base_state, blanked) with the small pixels drawn
// with their top left at pixel (left, top) counted from the icon's top left.
/proc/painting_build_icon(small, aw, ah, left, top, base_icon, base_state, only_dir = 0)
	var/key = "[base_state]|[aw]x[ah]|[left],[top]|[only_dir]|[small]"
	var/icon/cached = painting_icon_cache[key]
	if (cached)
		return cached
	if (!istext(small) || length(small) != aw * ah * 3)
		return null
	var/icon/I = icon(base_icon, base_state, only_dir ? only_dir : null)
	I.Blend("#00000000", ICON_MULTIPLY)
	var/height = I.Height()
	var/i = 1
	for (var/y = 0, y < ah, y++)
		var/iy = height - top - y
		for (var/x = 1, x <= aw, x++)
			var/colour = "#[copytext(small, i, i + 1)][copytext(small, i, i + 1)][copytext(small, i + 1, i + 2)][copytext(small, i + 1, i + 2)][copytext(small, i + 2, i + 3)][copytext(small, i + 2, i + 3)]"
			I.DrawBox(colour, left + x, iy, left + x, iy)
			i += 3
	if (only_dir)
		var/icon/D = icon(base_icon, base_state)
		D.Blend("#00000000", ICON_MULTIPLY)
		D.Insert(I, base_state, only_dir)
		I = D
	painting_icon_cache[key] = I
	return I

// Client-side drawing shared by the full view, the editor and the admin list.
// Raw string: no DM interpolation inside.
/proc/painting_draw_script()
	return @{"
function unpackArt(p,n){var o=[],i=0;while(i<p.length){var c=p.charAt(i++),r=1;if(p.charAt(i)=='~'){var s=p.indexOf('.',i);r=parseInt(p.substring(i+1,s),10);i=s+1;}for(var k=0;k<r;k++)o.push(c);}return o.join('');}
function packArt(s){var o=[],i=0;while(i<s.length){var c=s.charAt(i),j=i+1;while(j<s.length&&s.charAt(j)==c)j++;var r=j-i;if(r>=4)o.push(c+'~'+r+'.');else for(var k=0;k<r;k++)o.push(c);i=j;}return o.join('');}
function drawArt(cv,w,h,pal,plain,k){cv.width=w*k;cv.height=h*k;var g=cv.getContext('2d');for(var y=0;y<h;y++)for(var x=0;x<w;x++){g.fillStyle=pal[parseInt(plain.charAt(y*w+x),16)]||'#000';g.fillRect(x*k,y*k,k,k);}}
"}

// The full painting in a pop-up, drawn by the viewer's browser.
/proc/painting_show_full(mob/user, obj/item/canvas/C)
	if (!user || !user.client || !istype(C) || !C.paint_data)
		return
	var/side = max(C.canvas_w, C.canvas_h)
	var/k = max(1, round(448 / side))
	var/title = C.title ? html_encode(C.title) : "Untitled"
	var/by = C.author_name ? "by [html_encode(C.author_name)]" : ""
	var/list/html = list("<html><head><meta charset='utf-8'><title>[title]</title><style>body{background:#2b2622;color:#e9dfc8;font-family:Georgia,serif;text-align:center;margin:8px}canvas{image-rendering:pixelated;border:6px solid #5a3d22;box-shadow:0 0 0 2px #c9a24a}</style></head><body>")
	html += "<canvas id='a'></canvas><h3 style='margin:6px 0 0'>[title]</h3><div>[by]</div>"
	if (C.finished && painting_code_allowed(user, C.author_ckey))
		html += painting_code_box(painting_design_code(C.canvas_w, C.canvas_h, C.palette, C.paint_data))
	html += "<script>[painting_draw_script()]drawArt(document.getElementById('a'),[C.canvas_w],[C.canvas_h],'[C.palette]'.split(','),unpackArt('[C.paint_data]',[C.canvas_w * C.canvas_h]),[k]);</script></body></html>"
	show_browse(user, jointext(html, ""), "window=painting_view;size=[max(320, C.canvas_w * k + 60)]x[C.canvas_h * k + 220]")

// Read-only plan diagrams share the editors' checked sheet data, never their
// live windows or callbacks. The original code stays on the paper in the frame.
/datum/framed_plan_diagram
	var/title
	var/list/layers = list() // label -> rows of x, y, mark, description, accent
	var/list/notes = list()
	var/accent_label = "fitting or special part" // what a pale tile means on this kind of plan

/datum/framed_plan_diagram/proc/tile(layer, x, y, mark, description, accent = FALSE)
	var/list/tiles = layers[layer]
	if (!tiles)
		tiles = list()
		layers[layer] = tiles
	tiles += list(list(x, y, mark, description, accent))

/datum/framed_plan_diagram/proc/tile_bounds(layer)
	var/list/B
	for (var/label in layers)
		if (layer && label != layer)
			continue
		for (var/list/T in layers[label])
			if (!B)
				B = list(T[1], T[2], T[1], T[2])
			else
				B[1] = min(B[1], T[1])
				B[2] = min(B[2], T[2])
				B[3] = max(B[3], T[1])
				B[4] = max(B[4], T[2])
	return B

/datum/framed_plan_diagram/proc/html()
	var/list/out = list("<html><head><meta charset='utf-8'><title>Framed plan</title><style>")
	// Blueprint on parchment. Pale tiles use the same two colours as the wall thumbnail.
	out += "body{margin:14px;background:#ece0be;color:#203951;font:13px Verdana,sans-serif}h1{margin:0 0 4px 0;font-size:18px}h2{font-size:14px;margin:12px 0 4px 0}p{margin:6px 0;line-height:1.4}"
	out += ".plan{position:relative;background:#1b3d60;border:2px solid #14283f}"
	out += ".tile{position:absolute;width:29px;height:29px;line-height:29px;overflow:hidden;text-align:center;color:#fff;background:#2b5d82;border:1px solid #89b9ca;font:bold 10px/29px Verdana,sans-serif;cursor:help}"
	out += ".accent{background:#f0d7a1;color:#14283f;border-color:#c9a24a}"
	out += ".legend{color:#36526a}.key span{display:inline-block;white-space:nowrap;margin:0 12px 3px 0}"
	out += ".key b{display:inline-block;width:14px;height:14px;margin-right:5px;vertical-align:middle;border:1px solid #89b9ca;background:#2b5d82}.key b.accent{background:#f0d7a1;border-color:#c9a24a}.key b.gap{background:#1b3d60;border-color:#14283f}</style></head><body>"
	out += "<h1>[html_encode(title)]</h1><p class='legend'>Framed plan, read-only. North or the front is at the top; a train reads left to right. Hover a tile for details.</p>"
	// Storeys and decks use identical bounds so aligned tiles agree visually.
	var/list/B = tile_bounds()
	// The key lists only the tile colours this plan actually uses.
	var/plain = FALSE
	var/accented = FALSE
	for (var/label in layers)
		for (var/list/T in layers[label])
			if (T[5])
				accented = TRUE
			else
				plain = TRUE
	out += "<p class='legend key' aria-label='Tile key'>"
	if (plain)
		out += "<span><b></b>plain tile</span>"
	if (accented)
		out += "<span><b class='accent'></b>[html_encode(accent_label)]</span>"
	out += "<span><b class='gap'></b>nothing drawn</span></p>"
	var/w = (B[3] - B[1] + 1) * 31
	var/h = (B[4] - B[2] + 1) * 31
	for (var/layer in layers)
		var/list/tiles = layers[layer]
		out += "<h2>[html_encode(layer)]</h2><div class='plan' style='width:[w]px;height:[h]px'>"
		for (var/list/T in tiles)
			var/x = (T[1] - B[1]) * 31
			var/y = (T[2] - B[2]) * 31
			out += "<span class='tile[T[5] ? " accent" : ""]' style='left:[x]px;top:[y]px' title=\"[html_encode(T[4])]\">[html_encode(T[3])]</span>"
		out += "</div>"
	for (var/note in notes)
		out += "<p>[html_encode(note)]</p>"
	out += "</body></html>"
	return jointext(out, "")

// The small decorative image is rebuilt from the first non-empty layer,
// inside the existing 16x16 table-frame opening; generated overlays aren't saved.
/datum/framed_plan_diagram/proc/thumbnail()
	var/list/tiles = layers[layers[1]]
	var/list/B = tile_bounds(layers[1])
	var/w = B[3] - B[1] + 1
	var/h = B[4] - B[2] + 1
	var/scale = 14 / max(w, h)
	// Small plans get whole-pixel blocks so they read as a solid shape, not
	// scattered dots; every plan is centred in the 14x14 drawing area.
	var/block = clamp(round(scale), 1, 4)
	if (scale >= 1)
		scale = block
	var/left = 10 + round((14 - w * scale) / 2)
	var/top = 25 - round((14 - h * scale) / 2)
	var/icon/I = icon('icons/obj/paintings.dmi', "canvas_table")
	I.Blend("#00000000", ICON_MULTIPLY)
	I.DrawBox("#1b3d60", 9, 11, 24, 26)
	for (var/list/T in tiles)
		var/x = left + round((T[1] - B[1]) * scale)
		var/y = top - round((T[2] - B[2]) * scale)
		I.DrawBox(T[5] ? "#f0d7a1" : "#86c7d5", x, y - block + 1, x + block - 1, y)
	return I

// Window size that shows the widest layer and, where it fits, every layer
// without scrolling. Larger plans scroll inside the capped window.
/datum/framed_plan_diagram/proc/window_size()
	var/list/B = tile_bounds()
	var/w = (B[3] - B[1] + 1) * 31
	var/h = (B[4] - B[2] + 1) * 31
	return "[clamp(w + 80, 480, 1100)]x[clamp(layers.len * (h + 50) + notes.len * 26 + 170, 300, 760)]"

/proc/framed_plan_ship_label(floor, piece, facing)
	var/list/parts = ship_draught_pieces()
	var/list/P = piece ? parts[piece] : null
	var/material = floor == "s" ? "Steel deck" : "Wood deck"
	return P ? "[material], [P["name"]] ([dir2text(facing)])" : material

/obj/item/ship_draught/proc/framed_plan_diagram()
	var/kind = design_code_kind(draught_code)
	var/list/K = draught_kind_row()
	if (!K || length(draught_code) > K["max"] || !(kind in list("SHIP", "SUB", "CAR", "AIR", "HOUSE", "RAIL", "TRAIN", "STATION")))
		return null
	var/datum/D = call(K["read"])(draught_code)
	if (!D)
		return null
	var/datum/framed_plan_diagram/V = new
	V.title = "[D:name]"
	switch (kind)
		if ("SHIP")
			var/list/layout = ship_designer_layout(D)
			for (var/list/T in layout[1])
				V.tile("Main deck", T[1], -T[2], T[4] || uppertext(T[3]), framed_plan_ship_label(T[3], T[4], T[5]), !!T[4])
			for (var/list/T in layout[2])
				var/list/level = ship_draught_decks["[T[1]]"]
				V.tile(level["name"], T[2], -T[3], T[4] || uppertext(level["floor"]), framed_plan_ship_label(level["floor"], T[4], T[5]), !!T[4])
			V.accent_label = "deck tile with a fitting"
		if ("SUB")
			var/list/sheet = sub_designer_sheet(D)
			for (var/list/T in sheet[3])
				V.tile("Hull plan", T[1], T[2], T[4] || T[3], "Frame [T[3]], fitting [T[4] || "-"], wall [T[5] || "-"]", !!T[4] || !!T[5])
			V.accent_label = "frame with a fitting or wall"
		if ("CAR")
			var/list/sheet = vehicle_designer_sheet(D)
			var/datum/vehicle_draught/car = D
			for (var/list/T in sheet[7])
				if (T[3])
					V.tile("Chassis", T[1], T[2], T[5] || T[4] || T[3], "Frame [T[3]], running gear [T[4] || "-"], [T[5] ? car.part_name(T[5]) : "no fitting"]", !!T[5])
			V.notes += "Engine: [car.engine_name()]."
			V.accent_label = "frame with a fitting"
		if ("AIR")
			var/list/sheet = air_designer_sheet(D)
			var/datum/air_draught/A = D
			for (var/list/T in sheet[7])
				V.tile("Gondola", T[1], T[2], T[5] || T[4] || T[3], "Deck [T[3]], gas cell [T[4] || "-"], [T[5] ? A.part_name(T[5]) : "no fitting"]", !!T[5])
			V.notes += "Engine: [A.engine_name()]. Crew: [A.crew]."
			V.accent_label = "deck with a fitting"
		if ("HOUSE")
			var/list/sheet = house_designer_sheet(D)
			var/list/floors = house_plan_floors()
			var/list/pieces = house_plan_pieces()
			var/list/roofs = house_plan_roofs()
			for (var/list/T in sheet[2])
				var/list/floor = floors[T[4]]
				var/list/piece = pieces[T[5]]
				var/list/roof = roofs[T[6]]
				V.tile(house_plan_storey_name(T[1]), T[2], T[3], T[5] || uppertext(T[4]) || T[6], "[floor ? floor["name"] : "No floor"]; [piece ? piece["name"] : "no fitting"]; [roof ? roof["name"] : "no roof"]", !!piece || !!roof)
			for (var/list/N in sheet[3])
				V.notes += "[house_plan_storey_name(N[1])] ([N[2]], [N[3]]): [N[4]]"
			V.accent_label = "tile with a fitting or roof"
		if ("RAIL")
			var/datum/rail_plan/R = D
			for (var/key in R.track)
				var/list/XY = splittext(key, ",")
				var/x = text2num(XY[1])
				var/y = text2num(XY[2])
				var/list/links = list()
				for (var/heading in R.links(x, y))
					links += uppertext(copytext(dir2text(heading), 1, 2))
				var/curve = R.curve_at(x, y)
				V.tile("Rail route", x, y, curve ? "R[curve]" : jointext(links, ""), "Track at [key][curve ? ", radius [curve]" : ""]", !!curve)
			V.accent_label = "curved track (R and its radius)"
		if ("TRAIN")
			var/datum/train_draught/train = D
			var/i = 0
			var/offset = 0
			for (var/car in train.cars)
				i++
				var/name = train_draught_car_name(car)
				var/size = train_car_length(car)
				var/list/custom = train_custom_car(car)
				var/list/sections = custom ? custom["sections"] : null
				for (var/section = 1, section <= size, section++)
					var/part = sections ? sections[section] : null
					V.tile("Consist", offset + section, 1, section == 1 ? "[i]" : ".", "[i]: [name], section [section]/[size][part ? ", [part]" : ""]", i % 2)
				offset += size
				var/details = custom ? ", floor [custom["floor"]], roof [custom["roof"] || "-"], ends [custom["front"]]/[custom["back"]]" : ""
				V.notes += "[i]. [name] ([size] tiles)[details]"
			V.accent_label = "odd-numbered car (shading alternates car by car)"
		if ("STATION")
			var/list/sheet = station_designer_sheet(D)
			var/list/pieces = station_plan_pieces()
			for (var/list/T in sheet[2])
				var/list/P = pieces[T[3]]
				V.tile("Module layout", T[1], T[2], T[3], P["name"], TRUE)
			V.accent_label = "station module"
	qdel(D)
	if (!V.layers.len)
		qdel(V)
		return null
	return V
