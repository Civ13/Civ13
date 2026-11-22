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
