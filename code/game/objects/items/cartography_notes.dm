// Drawing, notes and copies of player maps.
//
// Ink: anyone holding a pen, pencil, crayon or pigment can draw on a held map
// in a few ink colours, one chart cell at a time, and pin short written notes
// to places on it. The ink is one character per chart cell ("0" for none),
// kept run-length packed like paintings, so a sketched-over map stays small.
//
// Copies work like book copies: use a blank map on a drawn one to copy it by
// hand (as long as a monk takes over a book), or load the drawn map into a
// printing press as the original and a blank map as the copy (as long as the
// press takes over a book). Either way the copy is faithful: the chart, its
// land, the ink, the notes and the title.

#define MAP_HAND_COPY_TIME 200 // the same as copying a book by hand
#define MAP_PRESS_COPY_TIME 250 // the same as printing a book
#define MAP_MARK_LIGHT 0.3 // the light needed to sketch is the light needed to draw
#define MAP_NOTES_MAX 30
#define MAP_NOTE_LEN 80
#define MAP_INK_PACKED_MAX 40000

/obj/item/weapon/cartography_map/var/chart_ink = "" // packed, one character per chart cell, "" when none
/obj/item/weapon/cartography_map/var/list/chart_notes = null // list(list("x" = col, "y" = row from the south, "t" = text))

/proc/cartography_ink_colors()
	var/static/list/colors = list("1" = "#2a2320", "2" = "#b3261e", "3" = "#2b4f9e", "4" = "#7b3fa0")
	return colors

/proc/cartography_ink_names()
	var/static/list/names = list("1" = "black", "2" = "red", "3" = "blue", "4" = "purple")
	return names

// Checked ink for a chart of count cells: packed, "" when nothing is drawn,
// or null when it is not valid ink.
/proc/cartography_ink_clean(packed, count)
	if (!istext(packed) || count < 1 || length(packed) > MAP_INK_PACKED_MAX)
		return null
	if (packed == "")
		return ""
	var/plain = painting_unpack(packed, count)
	if (!plain)
		return null
	var/static/regex/foreign = regex("\[^0-4\]")
	if (foreign.Find(plain))
		return null
	var/static/regex/inked = regex("\[1-4\]")
	if (!inked.Find(plain))
		return ""
	return painting_pack(plain)

// A checked note, or null.
/proc/cartography_note_valid(list/N, cols, rows)
	if (!islist(N) || !isnum(N["x"]) || !isnum(N["y"]) || !istext(N["t"]))
		return FALSE
	if (N["x"] != round(N["x"]) || N["y"] != round(N["y"]) || N["x"] < 1 || N["y"] < 1 || N["x"] > cols || N["y"] > rows)
		return FALSE
	return length(N["t"]) > 0 && length(N["t"]) <= MAP_NOTE_LEN * 4 // sanitized text may hold entities

/proc/cartography_notes_copy(list/source, cols, rows)
	if (!length(source))
		return null
	var/list/out = list()
	for (var/list/N in source)
		if (out.len >= MAP_NOTES_MAX)
			break
		if (cartography_note_valid(N, cols, rows))
			out += list(list("x" = N["x"], "y" = N["y"], "t" = N["t"]))
	return out.len ? out : null

/obj/item/weapon/cartography_map/proc/has_known_cells()
	var/static/regex/known = regex("\[^0\]")
	return chart_valid() && known.Find(chart)

// Anything worth copying: sketched land, ink or notes.
/obj/item/weapon/cartography_map/proc/map_has_content()
	return has_known_cells() || chart_ink || length(chart_notes)

// A blank map takes a copy; it is used up by turning into the copy.
/obj/item/weapon/cartography_map/proc/map_copy_blank()
	return !map_has_content() && (name == initial(name) || name == "map of [chart_label]") && !length(contents)

// Makes M a faithful copy of this map.
/obj/item/weapon/cartography_map/proc/copy_map_into(obj/item/weapon/cartography_map/M)
	if (!istype(M) || M == src)
		return FALSE
	M.chart = chart
	M.chart_land = chart_land
	M.chart_label = chart_label
	M.chart_cell = chart_cell
	M.chart_cols = chart_cols
	M.chart_rows = chart_rows
	M.chart_ink = chart_valid() ? (cartography_ink_clean(chart_ink, chart_cols * chart_rows) || "") : ""
	M.chart_notes = chart_valid() ? cartography_notes_copy(chart_notes, chart_cols, chart_rows) : null
	M.name = name
	return TRUE

/proc/cartography_copy_light(mob/user)
	var/turf/T = get_turf(user)
	return T && T.get_lumcount() >= MAP_MARK_LIGHT

/////////////////////////////// Copying by hand ///////////////////////////////

// Using a blank map on a drawn one copies it by hand, as a monk copies a book.
/obj/item/weapon/cartography_map/proc/hand_copy_into(obj/item/weapon/cartography_map/blank, mob/user)
	if (!istype(blank) || blank == src || !user || blank.loc != user)
		return FALSE
	if (!map_has_content())
		to_chat(user, SPAN_WARNING("There is nothing on [src] to copy."))
		return FALSE
	if (!blank.map_copy_blank())
		to_chat(user, SPAN_WARNING("Use a blank map to make a copy; [blank] would be drawn over."))
		return FALSE
	if (!cartography_copy_light(user))
		to_chat(user, SPAN_WARNING("It is too dark to copy a map. Find some light first."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start copying [src] onto the blank map..."))
	if (!do_after(user, MAP_HAND_COPY_TIME, src))
		to_chat(user, SPAN_WARNING("You stop copying."))
		return FALSE
	if (QDELETED(src) || QDELETED(blank) || blank.loc != user || !user.Adjacent(src) || !map_has_content() || !blank.map_copy_blank() || !cartography_copy_light(user))
		return FALSE
	copy_map_into(blank)
	to_chat(user, SPAN_NOTICE("You finish copying [src]."))
	return TRUE

/////////////////////////////// Printing ///////////////////////////////

// Returns a reason the press can't copy original onto stock, or null.
/proc/cartography_print_problem(obj/item/weapon/cartography_map/original, obj/item/weapon/cartography_map/stock)
	if (!istype(original) || !istype(stock) || original == stock)
		return "Both documents must be maps."
	if (!stock.map_copy_blank())
		return "The copy must be a blank map. Use Unload Printing Press to recover the maps."
	if (!original.map_has_content())
		return "There is nothing on [original] to print."
	return null

/obj/structure/printingpress/proc/print_map(mob/living/human/H)
	if (copying || !istype(H) || !Adjacent(H) || H.incapacitated() || !islist(base) || !islist(copy) || base.len != 1 || copy.len != 1)
		return FALSE
	var/obj/item/weapon/cartography_map/original = base[1]
	var/obj/item/weapon/cartography_map/stock = copy[1]
	if (!press_retains_document(original) || !press_retains_document(stock))
		return FALSE
	var/problem = cartography_print_problem(original, stock)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return FALSE
	copying = TRUE
	icon_state = "printingpress1"
	visible_message("Printing \the [original]...")
	var/done = do_after(H, machine_work_time(src, MAP_PRESS_COPY_TIME), src)
	if (!src || gcDestroyed)
		return FALSE
	copying = FALSE
	icon_state = "printingpress0"
	if (!done || !Adjacent(H) || base.len != 1 || copy.len != 1 || base[1] != original || copy[1] != stock)
		return FALSE
	return finish_map_print(H)

/obj/structure/printingpress/proc/finish_map_print(mob/user)
	if (!islist(base) || !islist(copy) || base.len != 1 || copy.len != 1)
		return FALSE
	var/obj/item/weapon/cartography_map/original = base[1]
	var/obj/item/weapon/cartography_map/stock = copy[1]
	if (!press_retains_document(original) || !press_retains_document(stock))
		return FALSE
	var/problem = cartography_print_problem(original, stock)
	if (problem)
		if (user)
			to_chat(user, SPAN_WARNING(problem))
		return FALSE
	original.copy_map_into(stock)
	var/turf/place = get_turf(src)
	base -= original
	copy -= stock
	original.loc = place
	stock.loc = place
	visible_message("The printing press finishes printing \the [original].")
	return stock

/////////////////////////////// Drawing and notes ///////////////////////////////

// Why user can't draw on this map now, or null.
/obj/item/weapon/cartography_map/proc/mark_problem(mob/user)
	if (!user || !user.client || user.incapacitated() || loc != user)
		return "Hold the map to draw on it."
	if (!drawing_tool(user))
		return "Hold a pen, a pencil, a crayon or some pigment to draw on the map."
	if (!cartography_copy_light(user))
		return "It is too dark to draw."
	return null

/obj/item/weapon/cartography_map/verb/draw_on_map_verb()
	set name = "Draw on Map"
	set category = null
	set src in usr
	open_editor(usr)

/obj/item/weapon/cartography_map/proc/open_editor(mob/user)
	var/problem = mark_problem(user)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	// A blank map drawn by hand charts the land it is drawn in.
	if (!chart_land || !chart_valid())
		start_chart(get_turf(user))
	show_browse(user, map_html(get_turf(user), TRUE), "window=cartography_map;size=[min(900, chart_cols * map_scale() + 60)]x[min(900, chart_rows * map_scale() + 250 + 20 * length(chart_notes))]")
	return TRUE

/obj/item/weapon/cartography_map/proc/set_ink(packed)
	if (!chart_valid())
		return FALSE
	var/clean = cartography_ink_clean(packed, chart_cols * chart_rows)
	if (isnull(clean))
		return FALSE
	chart_ink = clean
	return TRUE

/obj/item/weapon/cartography_map/proc/add_note(x, y, text)
	if (!chart_valid() || length(chart_notes) >= MAP_NOTES_MAX)
		return FALSE
	var/list/N = list("x" = x, "y" = y, "t" = text)
	if (!cartography_note_valid(N, chart_cols, chart_rows))
		return FALSE
	if (!islist(chart_notes))
		chart_notes = list()
	chart_notes += list(N)
	return TRUE

/obj/item/weapon/cartography_map/proc/erase_note(index)
	if (!isnum(index) || index != round(index) || index < 1 || index > length(chart_notes))
		return FALSE
	chart_notes.Cut(index, index + 1)
	if (!chart_notes.len)
		chart_notes = null
	return TRUE

/obj/item/weapon/cartography_map/Topic(href, list/href_list)
	var/mob/user = usr
	if (!user || QDELETED(src) || !chart_valid())
		return
	var/problem = mark_problem(user)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	if (!isnull(href_list["ink"]) && !set_ink(href_list["ink"]))
		to_chat(user, SPAN_WARNING("The drawing would not stay on the map."))
	if (href_list["note"])
		var/x = text2num(href_list["x"])
		var/y = text2num(href_list["y"])
		if (length(chart_notes) >= MAP_NOTES_MAX)
			to_chat(user, SPAN_WARNING("There is no room left for another note on the map."))
		else if (isnum(x) && isnum(y))
			var/text = sanitize(player_input(user, "What do you write here?", "Map note", null, "text", null, TRUE), MAP_NOTE_LEN)
			if (text && !QDELETED(src) && !mark_problem(user) && add_note(x, y, text))
				to_chat(user, SPAN_NOTICE("You write \"[text]\" on the map."))
	else if (href_list["erase"])
		if (erase_note(text2num(href_list["erase"])))
			to_chat(user, SPAN_NOTICE("You scratch out the note."))
	if (!QDELETED(src))
		open_editor(user)

/obj/item/weapon/cartography_map/proc/map_toolbar_html()
	var/list/html = list("<style>button{font-family:Georgia,serif;margin:0 3px 6px 0;border:1px solid #6b4f2e;background:#e8dcc0;color:#2a2320;cursor:pointer}button.on{outline:2px solid #f5d76e}</style><div>")
	var/list/colors = cartography_ink_colors()
	var/list/names = cartography_ink_names()
	for (var/c in colors)
		html += "<button data-t='[c]' onclick=\"tool('ink','[c]')\"><span class='k' style='background:[colors[c]];margin-left:0'></span>[names[c]] ink</button>"
	html += "<button data-t='erase' onclick=\"tool('erase')\">Eraser</button><button data-t='note' onclick=\"tool('note')\">Write a note</button><button onclick=\"go('save=1')\"><b>Save drawing</b></button></div>"
	html += "<div style='font-size:12px;margin-bottom:6px'>Drag on the map to draw. With Write a note, click where the note goes. Save the drawing before you close the map.</div>"
	return jointext(html, "")

/obj/item/weapon/cartography_map/proc/map_notes_html(editing)
	if (!length(chart_notes))
		return ""
	var/list/html = list("<div style='margin-top:8px;font-size:13px'><b>Notes</b><ol style='margin:4px 0 0 0;padding-left:22px'>")
	var/i = 0
	for (var/list/N in chart_notes)
		i++
		html += "<li>[html_encode(N["t"])][editing ? " <a href='#' style='color:#f5b38a' onclick=\"go('erase=[i]');return false\">scratch out</a>" : ""]</li>"
	html += "</ol></div>"
	return jointext(html, "")

// Draws the ink and notes over the chart, and the drawing tools when editing.
// Expects C, s, w, h, k, px and py from map_html.
/obj/item/weapon/cartography_map/proc/map_marks_js(editing)
	var/list/ink_colors = list()
	var/list/colors = cartography_ink_colors()
	for (var/c in colors)
		ink_colors += "'[c]':'[colors[c]]'"
	var/list/notes = list()
	for (var/list/N in chart_notes)
		notes += "\[[N["x"]],[N["y"]]\]"
	var/js = "var IC={[jointext(ink_colors, ",")]},P='[chart_ink]',N=\[[jointext(notes, ",")]\],E=[editing ? 1 : 0],REF='\ref[src]';"
	return js + painting_draw_script() + cartography_marks_script()

/proc/cartography_marks_script()
	return @{"
var cv=document.getElementById('m'),g=cv.getContext('2d'),A=(P?unpackArt(P,w*h):new Array(w*h+1).join('0')).split(''),ink='1',mode='ink',down=false,dirty=false;
function cell(x,y){var i=y*w+x,c=A[i];g.fillStyle=(c!='0'&&IC[c])?IC[c]:(C[s.charAt(i)]||C['0']);g.fillRect(x*k,(h-1-y)*k,k,k);}
function marks(){if(px>0){g.fillStyle='#d0202a';g.fillRect((px-1)*k-k,(h-py)*k-k,k*3,k*3);g.fillStyle='#fff';g.fillRect((px-1)*k,(h-py)*k,k,k);}
var r=Math.max(6,k*1.5);g.font='bold '+Math.round(r*1.3)+'px Georgia';g.textAlign='center';g.textBaseline='middle';
for(var n=0;n<N.length;n++){var x=(N[n][0]-0.5)*k,y=(h-N[n][1]+0.5)*k;g.fillStyle='#fff8e0';g.beginPath();g.arc(x,y,r,0,7);g.fill();g.lineWidth=1;g.strokeStyle='#2a2320';g.stroke();g.fillStyle='#2a2320';g.fillText(String(n+1),x,y+1);}}
function R(){for(var y=0;y<h;y++)for(var x=0;x<w;x++)cell(x,y);marks();}
function at(e){var b=cv.getBoundingClientRect();return [Math.floor((e.clientX-b.left)/k),h-1-Math.floor((e.clientY-b.top)/k)];}
function paint(e){var p=at(e);if(p[0]<0||p[1]<0||p[0]>=w||p[1]>=h)return;var c=mode=='erase'?'0':ink,i=p[1]*w+p[0];if(A[i]!=c){A[i]=c;dirty=true;cell(p[0],p[1]);}}
function go(q){location.href='byond://?src='+REF+';'+q+(dirty?';ink='+packArt(A.join('')):'');}
function tool(m,c){mode=m;if(c)ink=c;var b=document.getElementsByTagName('button');for(var i=0;i<b.length;i++)b[i].className=b[i].getAttribute('data-t')==(m=='ink'?ink:m)?'on':'';}
R();
if(E){tool('ink','1');
cv.onmousedown=function(e){if(mode=='note'){var p=at(e);if(p[0]>=0&&p[1]>=0&&p[0]<w&&p[1]<h)go('note=1;x='+(p[0]+1)+';y='+(p[1]+1));return;}down=true;paint(e);};
cv.onmousemove=function(e){if(down)paint(e);};
document.onmouseup=function(){if(down){down=false;marks();}};}
"}

#undef MAP_HAND_COPY_TIME
#undef MAP_PRESS_COPY_TIME
#undef MAP_MARK_LIGHT
#undef MAP_NOTES_MAX
#undef MAP_NOTE_LEN
#undef MAP_INK_PACKED_MAX
