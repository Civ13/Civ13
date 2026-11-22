// Design codes: player designs as short text a player can copy out of the
// game and paste back in, on any server or region. Every code starts with
// "C13<KIND>/<version>/" and then the design's own fields, split by "/":
//
//   C13ART/1/<w>x<h>/<palette>/<packed>  pictures: paintings, drawings, rock art
//                                         (palette "rrggbb,..."; packed pixels as
//                                         in painting_codec.dm)
//   C13FLAG/1/<background>/<8 layers>     flags from the flag maker
//   C13POLE/1/<cloth>/<symbol>/<colour>   flags on a pole
//   C13CLOTH/1/<body>/<colours>/<pieces>/<name>  tailoring designs
//   C13SYMBOL/1/<palette>/<packed>        faction symbols (32x32, pixels packed
//                                         as for pictures, up to 16 colours)
//   C13SHIP/1/<name>/<tiles>              ship's draughts (naval/ship_draught.dm)
//   C13HOUSE/1/<name>/<tiles>/<notes>     house plans (game/objects/house_plan.dm)
//
// A code only describes a design. Importing never skips the normal rules:
// pictures still need the pigments, a canvas and room under the region cap,
// clothes still need the research, and every import is logged for staff.

#define DESIGN_CODE_SHORT_MAX 300 // flags and clothes; pictures go through the editor
#define DESIGN_CODE_ART_MAX 20000 // longest picture code the editor accepts
#define DESIGN_CODE_SYMBOL_MAX 1400 // a 32x32 faction symbol at its busiest
#define DESIGN_CODE_COOLDOWN 20 // deciseconds between pasted codes per account
#define DESIGN_CODE_LOG_MAX 100

var/global/list/design_code_import_log = list() // newest last, shown in Player Art
var/global/list/design_code_last_import = list() // ckey -> world.time

// The fields after "C13<kind>/<version>/", or null when the code is another
// kind, another version or too long. Spaces and line breaks pasted with it are dropped.
/proc/design_code_fields(code, kind, max_length = DESIGN_CODE_SHORT_MAX, version = 1)
	if (!istext(code))
		return null
	code = replacetext(replacetext(replacetext(replacetext(code, " ", ""), "\n", ""), ascii2text(13), ""), "\t", "")
	if (!length(code) || length(code) > max_length)
		return null
	var/head = "C13[kind]/[version]/"
	if (cmptext(copytext(code, 1, length(head) + 1), head) != 1)
		return null
	return splittext(copytext(code, length(head) + 1), "/")

// The kind a code says it is ("ART", "FLAG", ...), for a clearer refusal.
/proc/design_code_kind(code)
	if (!istext(code))
		return null
	code = trim(code)
	if (!cmptext(copytext(code, 1, 4), "C13"))
		return null
	var/stop = findtext(code, "/")
	return stop > 4 ? uppertext(copytext(code, 4, stop)) : null

/proc/design_code_kind_name(kind)
	switch (kind)
		if ("ART")
			return "a picture"
		if ("FLAG")
			return "a flag from the flag maker"
		if ("POLE")
			return "a flag on a pole"
		if ("CLOTH")
			return "a clothing design"
		if ("SYMBOL")
			return "a faction symbol"
		if ("SHIP")
			return "a ship's draught"
		if ("SUB")
			return "a submarine sheet"
		if ("CAR")
			return "a vehicle sheet"
		if ("AIR")
			return "an airship sheet"
		if ("TRAIN")
			return "a train sheet"
		if ("STATION")
			return "a space station plan"
		if ("HOUSE")
			return "a house plan"
	return null

// Why a pasted code was refused, for the player.
/proc/design_code_refusal(code, wanted_kind)
	var/kind = design_code_kind(code)
	if (kind && kind != wanted_kind && design_code_kind_name(kind))
		return "That design code is for [design_code_kind_name(kind)], not [design_code_kind_name(wanted_kind)]."
	return "That is not a working design code for [design_code_kind_name(wanted_kind)]."

// "#rrggbb" -> "rrggbb" for codes, or null.
/proc/design_code_colour_out(value)
	value = painting_hex(value)
	return value ? copytext(value, 2) : null

// "rrggbb" from a code -> "#rrggbb", or null.
/proc/design_code_colour_in(value)
	return istext(value) && length(value) == 6 ? painting_hex("#[value]") : null

// Asks the player to paste a code. Returns the text, or null when cancelled
// or pasted again too soon.
/proc/design_code_ask(mob/user, title, prompt, max_length = DESIGN_CODE_SHORT_MAX)
	if (!user || !user.client)
		return null
	var/typed = WWinput(user, prompt, title, "", "text")
	if (!istext(typed) || !length(trim(typed)))
		return null
	if (length(typed) > max_length)
		to_chat(user, SPAN_WARNING("That design code is too long."))
		return null
	if (!design_code_cooldown_ok(user))
		return null
	return typed

/proc/design_code_cooldown_ok(mob/user)
	var/key = user && user.ckey ? user.ckey : "\ref[user]"
	if (design_code_last_import[key] && world.time < design_code_last_import[key] + DESIGN_CODE_COOLDOWN)
		to_chat(user, SPAN_WARNING("Wait a moment before using another design code."))
		return FALSE
	design_code_last_import[key] = world.time
	return TRUE

// Records an accepted import in the game log and the Player Art list.
/proc/design_code_log(mob/user, kind, what, code)
	var/turf/T = get_turf(user)
	var/where = T ? "([T.x],[T.y],[T.z])" : "(nowhere)"
	var/line = "[key_name(user)] used a [kind] design code ([length(code)] characters) for [what] at [where]."
	log_game(line)
	design_code_import_log += "[time2text(world.realtime, "YYYY-MM-DD hh:mm")] [line]"
	if (design_code_import_log.len > DESIGN_CODE_LOG_MAX)
		design_code_import_log.Cut(1, design_code_import_log.len - DESIGN_CODE_LOG_MAX + 1)

// A pop-up with the code ready to copy.
/proc/design_code_show(mob/user, title, code, note = null)
	if (!user || !user.client || !istext(code))
		return
	var/list/html = list("<html><head><meta charset='utf-8'><title>Design code</title><style>body{background:#2b2622;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:8px}textarea{width:100%;height:110px;font-family:monospace;font-size:11px;background:#1d1916;color:#e9dfc8;border:1px solid #806040}button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;padding:3px 8px;margin-top:4px;cursor:pointer}</style></head><body>")
	html += "<b>[html_encode(title)]</b><br>Copy this code and keep it anywhere outside the game. Paste it back in to make the same design again.[note ? "<br><span style='color:#b0a080'>[html_encode(note)]</span>" : ""]"
	html += "<textarea id='c' readonly onclick='this.select()'>[html_encode(code)]</textarea><br><button onclick=\"var t=document.getElementById('c');t.focus();t.select();try{document.execCommand('copy');document.getElementById('s').innerHTML='Copied.';}catch(e){document.getElementById('s').innerHTML='Press Ctrl+C to copy.';}\">Copy</button> <span id='s'>Press Ctrl+C after selecting to copy.</span>"
	html += "<script>var t=document.getElementById('c');t.focus();t.select();</script></body></html>"
	show_browse(user, jointext(html, ""), "window=design_code;size=460x260")

/////////////////////////////// Pictures ///////////////////////////////

/proc/painting_design_code(w, h, palette_text, packed)
	var/list/pal = painting_palette_list(palette_text)
	if (!pal || !istext(packed))
		return null
	var/list/out = list()
	for (var/hex in pal)
		out += copytext(hex, 2)
	return "C13ART/1/[w]x[h]/[jointext(out, ",")]/[packed]"

// A picture code -> list("w", "h", "palette" = "#rrggbb,...", "plain"), or null.
// The editor reads codes in the browser; this is the same check on the server.
/proc/painting_parse_design_code(code)
	var/list/F = design_code_fields(code, "ART", DESIGN_CODE_ART_MAX)
	if (!F || F.len != 3)
		return null
	var/list/size = splittext(F[1], "x")
	if (size.len != 2)
		return null
	var/w = text2num(size[1])
	var/h = text2num(size[2])
	if (!isnum(w) || !isnum(h) || w != round(w) || h != round(h) || w < 1 || h < 1 || w > PAINT_MAX_SIDE || h > PAINT_MAX_SIDE)
		return null
	var/list/hexes = splittext(F[2], ",")
	if (!hexes.len || hexes.len > PAINT_MAX_COLOURS)
		return null
	for (var/i = 1, i <= hexes.len, i++)
		hexes[i] = design_code_colour_in(hexes[i])
		if (!hexes[i])
			return null
	var/plain = painting_unpack(F[3], w * h)
	if (!plain || painting_max_index(plain) >= hexes.len)
		return null
	return list("w" = w, "h" = h, "palette" = jointext(hexes, ","), "plain" = plain)

// Only the painter (or staff) may copy a finished picture's code, so a
// painting stays the painter's own; anyone may copy the canvas they paint.
/proc/painting_code_allowed(mob/user, author_ckey)
	if (!user || !user.client)
		return FALSE
	if (user.client.holder && (user.client.holder.rights & R_ADMIN))
		return TRUE
	return author_ckey && user.ckey == author_ckey

// The read-only code box under a finished picture.
/proc/painting_code_box(code)
	if (!code)
		return ""
	return "<details style='margin-top:6px;font-family:Verdana,sans-serif;font-size:11px'><summary>Design code</summary><textarea readonly onclick='this.select()' style='width:95%;height:70px;font-family:monospace;font-size:10px'>[html_encode(code)]</textarea><div>Copy it to paint this picture again: open a canvas and use Import.</div></details>"

/////////////////////////////// Faction symbols ///////////////////////////////

#define DESIGN_CODE_DIGITS "0123456789abcdef"

// A symbol grid pixel as "#rrggbb" (stamped shapes can carry an alpha byte).
/proc/faction_symbol_code_pixel(value)
	var/hex = istext(value) ? painting_hex(copytext(value, 1, 8)) : null
	return hex ? hex : "#ffffff"

// The colours a symbol code keeps: the 16 most used, most used first.
/proc/faction_symbol_code_palette(list/grid)
	var/list/freq = list()
	for (var/i = 1, i <= grid.len, i++)
		var/hex = faction_symbol_code_pixel(grid[i])
		freq[hex] = (freq[hex] ? freq[hex] : 0) + 1
	var/list/palette = list()
	while (freq.len && palette.len < PAINT_MAX_COLOURS)
		var/best = null
		for (var/hex in freq)
			if (!best || freq[hex] > freq[best])
				best = hex
		palette += best
		freq -= best
	return palette

// How many different colours a symbol uses (more than 16 export approximated).
/proc/faction_symbol_colour_count(list/grid)
	var/list/seen = list()
	for (var/i = 1, i <= grid.len, i++)
		seen[faction_symbol_code_pixel(grid[i])] = TRUE
	return seen.len

// C13SYMBOL/1/<palette>/<packed> for a symbol grid, or null. A colour past the
// 16 kept ones becomes the nearest kept colour.
/proc/faction_symbol_design_code(list/grid)
	if (!islist(grid) || grid.len != FACTION_SYMBOL_SIZE * FACTION_SYMBOL_SIZE)
		return null
	var/list/palette = faction_symbol_code_palette(grid)
	var/list/nearest = list()
	var/list/plain = list()
	for (var/i = 1, i <= grid.len, i++)
		var/hex = faction_symbol_code_pixel(grid[i])
		var/index = palette.Find(hex)
		if (!index)
			index = nearest[hex]
		if (!index)
			var/list/c = painting_rgb(hex)
			var/best_distance = -1
			for (var/k = 1, k <= palette.len, k++)
				var/list/p = painting_rgb(palette[k])
				var/distance = (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2 + (c[3] - p[3]) ** 2
				if (best_distance < 0 || distance < best_distance)
					best_distance = distance
					index = k
			nearest[hex] = index
		plain += copytext(DESIGN_CODE_DIGITS, index, index + 1)
	var/list/out = list()
	for (var/hex in palette)
		out += copytext(hex, 2)
	return "C13SYMBOL/1/[jointext(out, ",")]/[painting_pack(jointext(plain, ""))]"

// A symbol code -> a new grid ("#RRGGBB" per pixel, row by row from the top), or null.
/proc/faction_symbol_parse_design_code(code)
	var/list/F = design_code_fields(code, "SYMBOL", DESIGN_CODE_SYMBOL_MAX)
	if (!F || F.len != 2)
		return null
	var/list/hexes = splittext(F[1], ",")
	if (!hexes.len || hexes.len > PAINT_MAX_COLOURS)
		return null
	for (var/i = 1, i <= hexes.len, i++)
		hexes[i] = design_code_colour_in(hexes[i])
		if (!hexes[i])
			return null
	var/plain = painting_unpack(lowertext(F[2]), FACTION_SYMBOL_SIZE * FACTION_SYMBOL_SIZE)
	if (!plain || painting_max_index(plain) >= hexes.len)
		return null
	var/list/grid = new/list(FACTION_SYMBOL_SIZE * FACTION_SYMBOL_SIZE)
	for (var/i = 1, i <= grid.len, i++)
		grid[i] = uppertext(hexes[findtext(DESIGN_CODE_DIGITS, copytext(plain, i, i + 1))])
	return grid

// The editors' Copy design code button: shows the code of the grid on the canvas.
/proc/faction_symbol_show_code(mob/user, list/grid)
	var/code = faction_symbol_design_code(grid)
	if (!code)
		return
	if (faction_symbol_colour_count(grid) > PAINT_MAX_COLOURS)
		to_chat(user, SPAN_NOTICE("This symbol uses more than [PAINT_MAX_COLOURS] colours, so the code keeps the [PAINT_MAX_COLOURS] most used and swaps the rest for the closest of those."))
	design_code_show(user, "Faction symbol design code", code, "Paste it in a faction symbol editor: Paste a design code, then Save.")

// The editors' Paste design code button: a new grid from a pasted code, or null
// (the player was already told why).
/proc/faction_symbol_ask_code(mob/user, title, what)
	var/code = design_code_ask(user, title, "Paste the faction symbol's design code (it starts with C13SYMBOL/).", DESIGN_CODE_SYMBOL_MAX)
	if (!code)
		return null
	var/list/grid = faction_symbol_parse_design_code(code)
	if (!grid)
		to_chat(user, SPAN_WARNING(design_code_refusal(code, "SYMBOL")))
		return null
	design_code_log(user, "faction symbol", what, code)
	return grid

#undef DESIGN_CODE_DIGITS

/proc/painting_import_log_html()
	if (!design_code_import_log.len)
		return ""
	var/list/html = list("<h3>Recent design code imports</h3><div style='font-family:monospace;font-size:11px'>")
	for (var/i = design_code_import_log.len, i >= 1, i--)
		html += "[html_encode(design_code_import_log[i])]<br>"
	html += "</div>"
	return jointext(html, "")
