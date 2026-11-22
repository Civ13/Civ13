// ============================================================
// The house designer (docs/house-plans.md)
// ------------------------------------------------------------
// Hold a blank ship's draught (or a house plan) and a pen or pencil and
// choose to draw a house: a window shows one storey of the plan at a time as
// a floor plan on the sheet, north to the top. A wall, door, window, pillar,
// stairs, floor or roofing is picked from the palette and clicked or dragged
// onto tiles; with "Drag a box" a drag draws the outline of a room (walls) or
// fills it (floors, roofs, the eraser). The storey buttons step between the
// ground floor and the storeys above it, where the walls of the storey below
// show through faintly so the next walls can be stood on them.
//
// Every change goes to the server, which reads it as a design code and
// answers with the plan's own figures and checks (house_plan_checks.dm), so
// the window never disagrees with the sheet. Save keeps the drawing on the
// sheet. The Part panel says what the picked (or pointed at) part is, what it
// is for and how it is built (DATA.HELP); the Checks panel lists the findings
// and rings their tiles, switching to their storey; the Notes panel holds the
// notes pinned to tiles.
//
// The sheet is drawn on a canvas with plan symbols, not sprites: a wall is a
// filled tile, a door its swing, a pillar a disc, roofing a hatch.
//
// The page is house_designer_page() with one block of data at @@DATA@@:
//   REF       this designer's ref, for the window's links
//   SIDE      the tiles of the sheet each way
//   STOREYS   the storeys a plan holds
//   PART      the characters of one upload part
//   MAX       the longest code a plan may have
//   NOTES     the most notes a plan holds; NOTELEN the characters of one
//   PIECES    list(key, name, kind, storeys it carries, tiles it reaches)
//   FLOORS    list(key, name, foundation)
//   ROOFS     list(key, name)
//   START     the plan: list(name, list(list(storey, x, y, floor, piece, roof), ...),
//             list(list(storey, x, y, note), ...))
//   EXAMPLES  ready-made plans in the same form
//   HELP      the part book: key -> list(what, use, how)
// A drawing can be longer than one link holds, so the window sends it in
// parts: ?src=REF;house=begin;n=<parts>;mode=preview|save;name=<name>, then
// house=part;i=<index>;d=<text> for each as the server acknowledges the last
// (houseAck), then house=end. The server answers with housePlan(json of
// house_designer_answer()), houseStatus(text) and, after a save, houseSaved().
// ============================================================

#define HOUSE_DESIGNER_WINDOW "house_designer"
#define HOUSE_DESIGNER_PART 900 // characters per upload part
#define HOUSE_DESIGNER_PREVIEW_GAP 3 // deciseconds between answers per drawer

// mob -> /datum/house_designer. A proc with a static list, not a global:
// the world's global init proc has no room for more.
/proc/house_designers()
	var/static/list/open
	if (!open)
		open = list()
	return open

/datum/house_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/list/upload_parts = null
	var/upload_count = 0
	var/upload_mode = null
	var/upload_name = null
	var/last_preview = null

/datum/house_designer/Destroy()
	var/list/open = house_designers()
	if (drawer && open[drawer] == src)
		open -= drawer
	drawer = null
	sheet = null
	upload_parts = null
	return ..()

/obj/item/ship_draught/proc/open_house_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	if (draught_code && !house_plan_kind())
		to_chat(H, SPAN_WARNING("The sheet already holds another drawing."))
		return
	var/list/open = house_designers()
	var/datum/house_designer/old = open[H]
	if (old)
		qdel(old)
	var/datum/house_designer/A = new
	A.drawer = H
	A.sheet = src
	open[H] = A
	var/datum/house_plan/D = house_plan()
	if (!D)
		D = new
	show_browse(H, house_designer_html(A, D), "window=[HOUSE_DESIGNER_WINDOW];size=1180x760")
	onclose(H, HOUSE_DESIGNER_WINDOW, A)
	house_designer_stats(H, D)
	qdel(D)

// A plan for the window: list(name, tiles, notes).
/proc/house_designer_sheet(datum/house_plan/D)
	var/list/tiles = list()
	for (var/s = 1, s <= HOUSE_PLAN_STOREYS, s++)
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (!D.cell(s, x, y))
					continue
				var/floor = D.floor_key(s, x, y)
				var/piece = D.piece_key(s, x, y)
				var/roof = D.roof_key(s, x, y)
				tiles += list(list(s, x, y, floor ? floor : "", piece ? piece : "", roof ? roof : ""))
	var/list/pinned = list()
	for (var/list/N in D.notes)
		pinned += list(N.Copy())
	return list(D.name, tiles, pinned)

/proc/house_designer_data(datum/house_designer/A, datum/house_plan/D)
	var/list/pieces = list()
	var/list/table = house_plan_pieces()
	for (var/key in table)
		pieces += list(list(key, table[key]["name"], table[key]["kind"], table[key]["tier"], table[key]["reach"]))
	var/list/floors = list()
	table = house_plan_floors()
	for (var/key in table)
		floors += list(list(key, table[key]["name"], table[key]["foundation"] ? 1 : 0))
	var/list/roofs = list()
	table = house_plan_roofs()
	for (var/key in table)
		roofs += list(list(key, table[key]["name"]))
	var/list/examples = list()
	for (var/datum/house_plan/E in house_plan_examples())
		examples += list(house_designer_sheet(E))
		qdel(E)
	return list(
		"REF" = A ? "\ref[A]" : "",
		"SIDE" = HOUSE_PLAN_SIDE,
		"STOREYS" = HOUSE_PLAN_STOREYS,
		"PART" = HOUSE_DESIGNER_PART,
		"MAX" = DESIGN_CODE_HOUSE_MAX,
		"NOTES" = HOUSE_PLAN_NOTES_MAX,
		"NOTELEN" = HOUSE_PLAN_NOTE_LENGTH,
		"PIECES" = pieces,
		"FLOORS" = floors,
		"ROOFS" = roofs,
		"START" = house_designer_sheet(D),
		"EXAMPLES" = examples,
		"HELP" = design_part_help_for("house_plan"),
	)

/proc/house_designer_html(datum/house_designer/A, datum/house_plan/D)
	var/list/halves = splittext(house_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(house_designer_data(A, D)) + halves[2]

// What the window is told of a plan: its figures and its findings.
/proc/house_designer_answer(datum/house_plan/D)
	var/list/box = D.extent()
	var/list/parts = list()
	var/list/P = D.parts()
	for (var/part in P)
		parts += list(list(part, P[part]))
	var/list/materials = list()
	var/list/M = D.materials()
	for (var/material in M)
		materials += list(list(material, M[material]))
	var/datum/design_report/R = D.check_design()
	. = list(
		"storeys" = D.top_storey(),
		"wide" = box ? box[3] - box[1] + 1 : 0,
		"deep" = box ? box[4] - box[2] + 1 : 0,
		"tiles" = D.tile_count(),
		"parts" = parts,
		"materials" = materials,
		"checks" = R.data(),
	)
	qdel(R)

/proc/house_designer_ack(mob/user, n)
	user << output(list2params(list("[n]")), "[HOUSE_DESIGNER_WINDOW].browser:houseAck")

/proc/house_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[HOUSE_DESIGNER_WINDOW].browser:houseStatus")

/proc/house_designer_stats(mob/user, datum/house_plan/D)
	user << output(list2params(list(json_encode(house_designer_answer(D)))), "[HOUSE_DESIGNER_WINDOW].browser:housePlan")

// Tells the window its drawing is the one on the sheet now.
/proc/house_designer_saved(mob/user)
	user << output(null, "[HOUSE_DESIGNER_WINDOW].browser:houseSaved")

/datum/house_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["house"] || H != drawer || house_designers()[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		upload_parts = null
		house_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	if (sheet.draught_code && !sheet.house_plan_kind())
		upload_parts = null
		house_designer_status(H, "The sheet already holds another drawing.")
		return
	switch (href_list["house"])
		if ("begin")
			var/n = text2num(href_list["n"])
			var/max_parts = CEILING(DESIGN_CODE_HOUSE_MAX / HOUSE_DESIGNER_PART, 1)
			if (!isnum(n) || n < 1 || n > max_parts || n != round(n) || !(href_list["mode"] in list("preview", "save")))
				house_designer_status(H, "The drawing could not be sent.")
				return
			upload_parts = list()
			upload_count = n
			upload_mode = href_list["mode"]
			upload_name = href_list["name"]
			house_designer_ack(H, 0)
		if ("part")
			var/i = text2num(href_list["i"])
			var/d = href_list["d"]
			if (!upload_parts || !isnum(i) || i != upload_parts.len || i >= upload_count || !istext(d) || length(d) > HOUSE_DESIGNER_PART)
				upload_parts = null
				house_designer_status(H, "The drawing could not be sent.")
				return
			upload_parts += d
			house_designer_ack(H, i + 1)
		if ("end")
			var/list/got = upload_parts
			upload_parts = null
			if (!got || got.len != upload_count)
				house_designer_status(H, "The drawing could not be sent.")
				return
			var/result = accept_drawing(H, jointext(got, ""), upload_name, upload_mode == "save")
			if (!isnull(result))
				house_designer_status(H, result)

// Reads a drawing sent from the window. A preview answers with the figures;
// a save keeps it on the sheet. Returns a status line, or null when the
// figures alone answer.
/datum/house_designer/proc/accept_drawing(mob/living/human/H, code, new_name, save)
	// Too soon after the last answer: the window only needs to know it may
	// send again.
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + HOUSE_DESIGNER_PREVIEW_GAP)
			return ""
		last_preview = world.time
	// house_plan_from_code() refuses a tile off the sheet, a key that is in
	// no table, a tile written twice and more notes than a plan holds.
	var/datum/house_plan/D = house_plan_from_code(code)
	if (!D)
		return "The drawing could not be read. It may be too big for one sheet."
	D.name = house_plan_clean_name(new_name)
	house_designer_stats(H, D)
	if (save)
		sheet.take_house(D)
		qdel(D)
		house_designer_saved(H)
		return "Saved on the sheet."
	qdel(D)
	return null

// Raw string: no DM interpolation inside, and never a double quote followed
// by a closing brace. Plain ES5 for the embedded browser. One @@DATA@@.
/proc/house_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>House plan</title><style>
html,body{height:100%}
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:0;overflow:hidden}
#wrap{display:flex;align-items:flex-start;padding:6px 8px 0 8px}
#plan{flex:0 0 528px;width:528px;margin-right:10px}
#side{flex:0 0 268px;width:268px;margin-right:10px}
#info{flex:1 1 0;min-width:0}
.sec{border:1px solid #66513b;background:#30271e;margin-bottom:8px}
.sec h2{font-size:13px;margin:0;padding:5px 8px;border-bottom:2px solid #b48c4d}
.sec h2 span{float:right;font-size:11px;font-weight:normal;color:#bfae96;margin-top:1px}
.sec .in{padding:6px 8px}
button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;margin:0;padding:3px 7px;cursor:pointer;font-family:Verdana,sans-serif;font-size:11px}
button:hover{border-color:#ffd985}
button.on{background:#b48c4d;color:#211c16;border-color:#ffd985}
button.go{flex:none;white-space:nowrap;background:#6b4d1f;border-color:#b48c4d;font-weight:bold;font-size:12px;padding:5px 14px}
input,select{background:#1d1916;color:#e9dfc8;border:1px solid #806040;font-family:Verdana,sans-serif;font-size:11px;height:22px;box-sizing:border-box;padding:1px 3px}
.row{display:flex;align-items:center;margin-bottom:5px}
.row label{flex:0 0 46px;color:#bfae96;font-size:11px}
.hint{color:#b0a080;font-size:11px;line-height:1.35}
.lbl{color:#b0a080;font-size:10px;text-align:center;letter-spacing:1px;text-transform:uppercase}

/* The storeys */
#tabs{display:flex;align-items:center;margin-bottom:5px}
#tabs .hint{margin-right:6px}
#tabs button{position:relative;min-width:58px;height:24px;margin-right:3px;font-size:11px;padding:3px 12px 3px 6px}
#tabs button i{position:absolute;right:3px;top:8px;width:6px;height:6px;border-radius:3px;background:#806040}
#tabs button.has i{background:#ffd985}
#tabs button.bad i{background:#ff6f3c}
#tabs button.warn i{background:#ffd23f}
#tabs button.on i{box-shadow:0 0 0 1px #211c16}

/* The sheet */
#board{display:flex;justify-content:center;align-items:center;margin:2px 0}
#board .lbl{flex:none;width:9px;line-height:11px;word-wrap:break-word;letter-spacing:0}
#g{display:block;margin:0 3px;border:2px solid #0f0c09;background:#d9c9a3;cursor:crosshair;-webkit-user-select:none;-ms-user-select:none;user-select:none}
#at{height:15px;margin-top:3px;color:#bfae96;font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#view{display:flex;align-items:center;margin-top:3px}
#view label{color:#bfae96;font-size:11px;margin-right:12px;cursor:pointer;white-space:nowrap}
#view input{height:auto;vertical-align:-2px;margin:0 3px 0 0}

/* Figures */
#stats{height:64px;overflow:auto;line-height:1.4}
.fg{display:flex;margin:2px 0 6px 0}
.fg div{flex:1 1 0;background:#262019;border:1px solid #54432f;padding:3px 0;text-align:center;margin-right:4px}
.fg div:last-child{margin-right:0}
.fg b{display:block;font-size:15px;color:#ffd985}
.fg span{font-size:10px;color:#bfae96}
#st{flex:1 1 auto;min-width:0;color:#ffd985;margin-left:9px;font-size:11px;line-height:1.25}

/* Palette */
.ph{color:#bfae96;font-size:11px;margin:5px 0 3px 0}
.pal{display:flex;flex-wrap:wrap}
.pal button{display:flex;align-items:center;text-align:left;width:131px;height:30px;line-height:12px;padding:1px 4px 1px 2px;margin:0 3px 3px 0;overflow:hidden;box-sizing:border-box}
.pal button canvas{flex:none;width:24px;height:24px;margin-right:5px;border:1px solid #14100c;background:#d9c9a3}
.pal button .nm{flex:1 1 auto;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pal button .nm u{display:block;text-decoration:none;font-size:10px;color:#bfae96}
.pal button.on .nm u{color:#3a2a14}
.acts button{margin:0 3px 3px 0}

/* Part, Notes and Checks */
#part{height:150px;overflow:auto;line-height:1.35;box-sizing:border-box}
.pn{font-size:13px;font-weight:bold;margin-bottom:4px;display:flex;align-items:center}
.pn canvas{flex:none;width:28px;height:28px;margin-right:7px;border:1px solid #14100c;background:#d9c9a3}
.pn .w{flex:1 1 auto}
.pn span.s{font-size:11px;font-weight:normal;color:#bfae96;margin-left:8px}
.pr{display:flex;margin-top:2px}
.pr i{flex:0 0 38px;font-style:normal;color:#b48c4d;font-size:11px;padding-top:1px}
.pr span{flex:1 1 auto;min-width:0}
#notes{max-height:112px;overflow:auto;box-sizing:border-box}
.nt{display:flex;align-items:flex-start;padding:3px 5px;border:1px solid #54432f;border-left:3px solid #ffd985;border-radius:3px;background:#262019;margin-bottom:3px;cursor:pointer;line-height:1.3}
.nt:hover,.nt.on{border-color:#ffd985}
.nt b{flex:0 0 74px;color:#ffd985;font-size:10px;font-weight:normal;padding-top:1px}
.nt span{flex:1 1 auto;min-width:0;word-wrap:break-word}
#ned{display:none;margin-bottom:5px}
#ned input{width:100%;margin:3px 0}
#checks{overflow-y:auto;box-sizing:border-box}
.vd{padding:5px 7px;border:1px solid #6caa68;border-radius:3px;background:#253b25;color:#c4e8c0}
.vd.bad{border-color:#c77a39;background:#3a2a1a;color:#f3c79a}
.vd .also{color:#f2dc8f;margin-top:3px}
.ck{display:flex;align-items:flex-start;margin-top:4px;padding:5px 7px 5px 6px;border:1px solid #54432f;border-left:3px solid #bfae96;border-radius:3px;background:#262019;line-height:1.3;cursor:default}
.ck.has{cursor:pointer}
.ck .tag{flex:0 0 52px;margin-right:7px;text-align:center;font-size:10px;font-weight:bold;letter-spacing:0.5px;text-transform:uppercase;border-radius:2px;padding:1px 0;margin-top:1px;border:1px solid #bfae96;color:#bfae96}
.ck .tx{flex:1 1 auto;min-width:0}
.ck .wh{display:block;color:#bfae96;font-size:11px;margin-top:1px}
.ck.error{border-left-color:#c77a39;background:#3a2a1a}
.ck.error .tag{background:#c77a39;border-color:#c77a39;color:#241405}
.ck.warning{border-left-color:#c9a52e;background:#373016}
.ck.warning .tag{border-color:#c9a52e;color:#f2dc8f}
.ck.note{color:#bfae96}
.ck.has:hover,.ck.lit{border-color:#ffd985}
.ck.pin{box-shadow:inset 0 0 0 1px #ffd985}
.ck.pin .wh{color:#ffd985}
.ck:focus{outline:2px solid #ffd985;outline-offset:-1px}
</style></head><body><div id='wrap'>

<div id='plan'>
<div class='sec'><h2>House plan<span id='dims'></span></h2><div class='in'>
<div id='tabs'></div>
<div class='lbl'>north</div>
<div id='board'><div class='lbl'>west</div><canvas id='g' width='500' height='500'></canvas><div class='lbl'>east</div></div>
<div class='lbl'>south</div>
<div id='at'></div>
<div id='view'><label><input type='checkbox' id='vr' checked onclick='draw()'>Show roofing</label><label><input type='checkbox' id='vb' checked onclick='draw()'>Show the storey below</label><label><input type='checkbox' id='bx' onclick='boxMode()'>Drag a box</label></div>
</div></div>
<div class='sec'><h2>Figures<span id='figk'></span></h2><div class='in'><div id='stats'><span class='hint'>Reckoning...</span></div></div></div>
</div>

<div id='side'>
<div class='row'><label for='nm'>Name</label><input id='nm' maxlength='40' style='flex:1 1 auto;min-width:0' onchange='changed()' onkeyup='changed()'></div>
<div class='ph'>Walls and supports <span class='hint'>- they hold the roof</span></div><div class='pal' id='pw'></div>
<div class='ph'>Doors, windows and ways up</div><div class='pal' id='po'></div>
<div class='ph'>Floors <span class='hint'>- stone is a foundation</span></div><div class='pal' id='pf'></div>
<div class='ph'>Roofing <span class='hint'>- also the floor above</span></div><div class='pal' id='pr'></div>
<div class='ph'>Tools</div><div class='pal' id='pt'></div>
<div class='acts' style='margin-top:2px'><button onclick='roofStorey()' title='Roofs every tile inside the walls of this storey, wall tiles included, with the picked roofing'>Roof this storey</button><button onclick='copyBelow()' title='Stands the walls, windows and pillars of the storey below on this one'>Copy the walls below</button><button onclick='clearStorey()'>Clear storey</button></div>
<div class='row' style='margin-top:3px'><button onclick='undo()' style='margin-right:3px'>Undo</button><button onclick='redo()' style='margin-right:8px'>Redo</button><span class='hint' style='white-space:nowrap'>Start from&nbsp;</span><select id='ex' style='flex:1 1 auto;min-width:0;margin-right:4px'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>
<div class='row' style='margin-bottom:0'><button class='go' onclick='send(1)'>Save to the sheet</button><span id='st'></span></div>
<div class='hint' style='margin-top:6px'>Click or drag to draw with the picked part. A tile holds one piece, one floor and one roofing. Right-click clears what the picked tool draws.</div>
</div>

<div id='info'>
<div class='sec'><h2>Part</h2><div class='in' id='part'></div></div>
<div class='sec'><h2>Notes<span id='ntn'></span></h2><div class='in'><div id='ned'><span class='hint' id='nwh'></span><input id='ntx' maxlength='80' onkeydown='if(event.keyCode==13)noteSave()'><button onclick='noteSave()' style='margin-right:3px'>Pin the note</button><button onclick='noteDrop()' style='margin-right:3px'>Take it off</button><button onclick='noteShut()'>Cancel</button></div><div id='notes'></div></div></div>
<div class='sec' style='margin-bottom:0'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div>
</div>

</div><script>
var DATA=@@DATA@@;
var REF=DATA.REF,SIDE=DATA.SIDE,STOREYS=DATA.STOREYS,PART=DATA.PART,MAX=DATA.MAX,NOTES=DATA.NOTES,NOTELEN=DATA.NOTELEN,PIECES=DATA.PIECES,FLOORS=DATA.FLOORS,ROOFS=DATA.ROOFS,EXAMPLES=DATA.EXAMPLES||[],HELP=DATA.HELP||{};
var cells={},notes=[],S=1,cur={l:'p',k:'T'},hist=[],fut=[],Z=25,g=null;
var parts=null,busy=0,dirty=false,timer=null,rev=0,savedRev=0,sendRev=0;
var CHK=[],lit=-1,pin=-1,peek=null,hov=null,drag=null,stroked=false,noteAt=null;
var LEVEL={error:['Fix','#c0391b'],warning:['Warning','#a8780a'],note:['Note','#4a5f7a']};
var INK='#2a1c0e',PAPER='#d9c9a3',WALL={T:'#8a5a2b',S:'#77726a',C:'#b5b2a8',N:'#8a5a2b',M:'#77726a',D:'#8a5a2b'};
var FLOORC={w:'#c9a56b',s:'#aaa69b',c:'#c6c4bb'},ROOFC={t:'#a8860f',w:'#6e4520',c:'#b5522d',k:'#55524c',g:'#2f7fa3'};
var KINDS={wall:'holds the roof 1 tile',door:'holds its own tile',window:'holds the roof 1 tile',pillar:'',stairs:'open tile above',ladder:'open tile above'};
function $(i){return document.getElementById(i);}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;');}
function key(s,x,y){return s+','+x+','+y;}
function row(list,k){for(var i=0;i<list.length;i++)if(list[i][0]==k)return list[i];return null;}
function several(n,one){return n+' '+one+(n==1?'':'s');}
function plural(n,s){return n==1||/s$/.test(s)?s:s+'s';}
function cap(s){s=s+'';return s.charAt(0).toUpperCase()+s.substring(1);}
function inGrid(x,y){return x>=1&&y>=1&&x<=SIDE&&y<=SIDE;}
function storeyName(s){return s==1?'Ground floor':['','','Second','Third','Fourth','Fifth','Sixth'][s]+' storey';}
function storeyTab(s){return s==1?'Ground':['','','2nd','3rd','4th','5th','6th'][s];}
function at(s,x,y){return inGrid(x,y)?cells[key(s,x,y)]||null:null;}
function pieceAt(s,x,y){var c=at(s,x,y);return c&&c[1]?c[1]:'';}
function roofAt(s,x,y){var c=at(s,x,y);return c&&c[2]?c[2]:'';}
function isFloor(s,x,y){return s<=1||!!roofAt(s-1,x,y);}
function kindOf(k){var r=row(PIECES,k);return r?r[2]:'';}
function solid(k){var d=kindOf(k);return d=='wall'||d=='window'||d=='pillar';}
function wallish(k){var d=kindOf(k);return d=='wall'||d=='window'||d=='door';}
function wayUp(s,x,y){var d=kindOf(pieceAt(s,x,y));return (d=='stairs'||d=='ladder')&&!roofAt(s,x,y);}

// ---- Plan symbols ----
// Each draws one tile k pixels a side at px,py on context c.
function drawFloor(c,f,px,py,k){var i,n;c.fillStyle=FLOORC[f]||PAPER;c.fillRect(px,py,k,k);c.strokeStyle='rgba(42,28,14,0.28)';c.lineWidth=1;c.beginPath();
if(f=='w'){n=Math.max(2,Math.round(k/8));for(i=1;i<n;i++){c.moveTo(px,py+Math.round(i*k/n)+0.5);c.lineTo(px+k,py+Math.round(i*k/n)+0.5);}}
else if(f=='s'){c.moveTo(px,py+Math.round(k/2)+0.5);c.lineTo(px+k,py+Math.round(k/2)+0.5);c.moveTo(px+Math.round(k/3)+0.5,py);c.lineTo(px+Math.round(k/3)+0.5,py+k/2);c.moveTo(px+Math.round(2*k/3)+0.5,py+k/2);c.lineTo(px+Math.round(2*k/3)+0.5,py+k);}
c.stroke();}
function drawRoof(c,r,px,py,k,strong){var i,st=Math.max(4,Math.round(k/4));c.save();c.beginPath();c.rect(px,py,k,k);c.clip();c.globalAlpha=strong?0.34:0.16;c.fillStyle=ROOFC[r]||INK;c.fillRect(px,py,k,k);
c.globalAlpha=strong?0.95:0.6;c.strokeStyle=ROOFC[r]||INK;c.lineWidth=strong?1.6:1;c.beginPath();for(i=-k;i<k;i+=st){c.moveTo(px+i,py+k);c.lineTo(px+i+k,py);}c.stroke();c.restore();}
// Whether a door or window at x,y runs west to east: a wall stands beside it there.
function runsAcross(s,x,y){return wallish(pieceAt(s,x-1,y))||wallish(pieceAt(s,x+1,y))||!(wallish(pieceAt(s,x,y-1))||wallish(pieceAt(s,x,y+1)));}
function drawPiece(c,p,px,py,k,across,faint){var d=kindOf(p),col=WALL[p]||INK,m,i,t;c.save();if(faint)c.globalAlpha=0.3;c.lineWidth=1;c.strokeStyle=INK;
if(d=='wall'){c.fillStyle=col;c.fillRect(px,py,k,k);c.strokeRect(px+0.5,py+0.5,k-1,k-1);
if(p=='T'){c.strokeStyle='rgba(42,28,14,0.45)';c.beginPath();c.moveTo(px+1,py+Math.round(k/2)+0.5);c.lineTo(px+k-1,py+Math.round(k/2)+0.5);c.stroke();}
if(p=='S'){c.strokeStyle='rgba(42,28,14,0.45)';c.beginPath();c.moveTo(px+1,py+Math.round(k/2)+0.5);c.lineTo(px+k-1,py+Math.round(k/2)+0.5);c.moveTo(px+Math.round(k/2)+0.5,py+1);c.lineTo(px+Math.round(k/2)+0.5,py+k/2);c.stroke();}}
else if(d=='window'){t=Math.max(4,Math.round(k/3));m=Math.round((k-t)/2);c.fillStyle=col;
if(across){c.fillRect(px,py+m,k,t);c.strokeRect(px+0.5,py+m+0.5,k-1,t-1);c.fillStyle='#bfe3f2';c.fillRect(px+3,py+m+2,k-6,t-4);}
else{c.fillRect(px+m,py,t,k);c.strokeRect(px+m+0.5,py+0.5,t-1,k-1);c.fillStyle='#bfe3f2';c.fillRect(px+m+2,py+3,t-4,k-6);}}
else if(d=='door'){t=Math.max(3,Math.round(k/6));c.fillStyle=col;c.strokeStyle=col;c.lineWidth=Math.max(1.5,k/14);c.beginPath();
if(across){c.fillRect(px,py+k/2-t/2,t,t);c.fillRect(px+k-t,py+k/2-t/2,t,t);c.moveTo(px+t,py+k/2);c.lineTo(px+t,py+2);c.stroke();c.lineWidth=1;c.beginPath();c.arc(px+t,py+k/2,k/2-2,-Math.PI/2,0);c.stroke();}
else{c.fillRect(px+k/2-t/2,py,t,t);c.fillRect(px+k/2-t/2,py+k-t,t,t);c.moveTo(px+k/2,py+t);c.lineTo(px+k-2,py+t);c.stroke();c.lineWidth=1;c.beginPath();c.arc(px+k/2,py+t,k/2-2,0,Math.PI/2);c.stroke();}}
else if(d=='pillar'){if(p=='R'){m=Math.round(k*0.26);c.fillStyle='#8a5a2b';c.fillRect(px+m,py+m,k-2*m,k-2*m);c.strokeRect(px+m+0.5,py+m+0.5,k-2*m-1,k-2*m-1);c.beginPath();c.moveTo(px+m,py+m);c.lineTo(px+k-m,py+k-m);c.moveTo(px+k-m,py+m);c.lineTo(px+m,py+k-m);c.stroke();}
else{c.fillStyle=p=='Q'?'#b5b2a8':'#77726a';c.beginPath();c.arc(px+k/2,py+k/2,k*0.32,0,Math.PI*2);c.fill();c.stroke();if(p=='Q'){c.beginPath();c.arc(px+k/2,py+k/2,k*0.14,0,Math.PI*2);c.stroke();}}}
else if(d=='stairs'){c.fillStyle='#e7dcc0';c.fillRect(px+2,py+2,k-4,k-4);c.strokeRect(px+2.5,py+2.5,k-5,k-5);c.beginPath();for(i=1;i<5;i++){m=Math.round(2+i*(k-4)/5)+0.5;c.moveTo(px+2,py+m);c.lineTo(px+k-2,py+m);}c.stroke();
c.fillStyle=INK;c.beginPath();c.moveTo(px+k/2,py+3);c.lineTo(px+k/2-k*0.16,py+3+k*0.22);c.lineTo(px+k/2+k*0.16,py+3+k*0.22);c.closePath();c.fill();}
else if(d=='ladder'){m=Math.round(k*0.3);c.lineWidth=Math.max(1.5,k/13);c.strokeStyle='#6e4520';c.beginPath();c.moveTo(px+m,py+2);c.lineTo(px+m,py+k-2);c.moveTo(px+k-m,py+2);c.lineTo(px+k-m,py+k-2);
for(i=1;i<5;i++){t=Math.round(i*k/5)+0.5;c.moveTo(px+m,py+t);c.lineTo(px+k-m,py+t);}c.stroke();}
c.restore();}
// The opening over stairs or a ladder of the storey below.
function drawOpening(c,px,py,k){c.save();c.strokeStyle=INK;c.setLineDash([3,2]);c.lineWidth=1;c.strokeRect(px+2.5,py+2.5,k-5,k-5);c.setLineDash([]);
c.fillStyle=INK;c.beginPath();c.moveTo(px+k/2,py+k-4);c.lineTo(px+k/2-k*0.16,py+k-4-k*0.22);c.lineTo(px+k/2+k*0.16,py+k-4-k*0.22);c.closePath();c.fill();c.beginPath();c.moveTo(px+k/2,py+5);c.lineTo(px+k/2,py+k-8);c.stroke();c.restore();}
function drawAir(c,px,py,k){c.fillStyle='#b9a880';c.fillRect(px,py,k,k);c.fillStyle='rgba(42,28,14,0.22)';c.fillRect(px+Math.round(k/2)-1,py+Math.round(k/2)-1,2,2);}
function drawEraser(c,px,py,k){c.strokeStyle='#c0391b';c.lineWidth=Math.max(2,k/8);c.beginPath();c.moveTo(px+k*0.25,py+k*0.25);c.lineTo(px+k*0.75,py+k*0.75);c.moveTo(px+k*0.75,py+k*0.25);c.lineTo(px+k*0.25,py+k*0.75);c.stroke();}
function drawPin(c,px,py,k,on){c.save();c.fillStyle=on?'#fff6dc':'#ffd23f';c.strokeStyle=INK;c.lineWidth=1;c.beginPath();c.moveTo(px+k-1,py+1);c.lineTo(px+k-1,py+k*0.48);c.lineTo(px+k*0.52,py+1);c.closePath();c.fill();c.stroke();c.restore();}
// A tool's picture on a small canvas.
function icon(cv,t){var c=cv.getContext('2d'),k=cv.width;c.fillStyle=PAPER;c.fillRect(0,0,k,k);
if(t.l=='p')drawPiece(c,t.k,0,0,k,true,false);else if(t.l=='f')drawFloor(c,t.k,0,0,k);else if(t.l=='r')drawRoof(c,t.k,0,0,k,true);else if(t.l=='x')drawEraser(c,0,0,k);else if(t.l=='n'){c.fillStyle='#efe4c4';c.fillRect(3,3,k-6,k-6);drawPin(c,2,2,k-4,false);}}

// ---- The sheet ----
function draw(){var x,y,c,px,py,p,b,i,f,n,showR=$('vr').checked,showB=$('vb').checked,strong=cur.l=='r';
g.fillStyle=PAPER;g.fillRect(0,0,SIDE*Z,SIDE*Z);
for(y=1;y<=SIDE;y++)for(x=1;x<=SIDE;x++){px=(x-1)*Z;py=(y-1)*Z;c=at(S,x,y);
if(S>1){if(isFloor(S,x,y)){g.fillStyle='#e7dcc0';g.fillRect(px,py,Z,Z);}else drawAir(g,px,py,Z);}
if(c&&c[0])drawFloor(g,c[0],px,py,Z);
if(S>1&&showB&&!(c&&c[1])){b=pieceAt(S-1,x,y);if(b&&!wayUp(S-1,x,y))drawPiece(g,b,px,py,Z,runsAcross(S-1,x,y),true);}
if(S>1&&wayUp(S-1,x,y)&&!(c&&c[1]))drawOpening(g,px,py,Z);
if(c&&c[1])drawPiece(g,c[1],px,py,Z,runsAcross(S,x,y),false);
if(c&&c[2]&&showR)drawRoof(g,c[2],px,py,Z,strong);}
g.strokeStyle='rgba(42,28,14,0.16)';g.lineWidth=1;g.beginPath();for(i=0;i<=SIDE;i++){g.moveTo(i*Z+0.5,0);g.lineTo(i*Z+0.5,SIDE*Z);g.moveTo(0,i*Z+0.5);g.lineTo(SIDE*Z,i*Z+0.5);}g.stroke();
for(i=0;i<notes.length;i++){n=notes[i];if(n[0]==S)drawPin(g,(n[1]-1)*Z,(n[2]-1)*Z,Z,noteAt&&noteAt[0]==S&&noteAt[1]==n[1]&&noteAt[2]==n[2]);}
f=finding();if(f&&f.deck==S){g.strokeStyle=LEVEL[f.level][1];g.lineWidth=3;for(i=0;i<f.cells.length;i++){p=(f.cells[i]+'').split(',');g.strokeRect((+p[0]-1)*Z+2.5,(+p[1]-1)*Z+2.5,Z-5,Z-5);}
g.strokeStyle='#fff6dc';g.lineWidth=1;for(i=0;i<f.cells.length;i++){p=(f.cells[i]+'').split(',');g.strokeRect((+p[0]-1)*Z+0.5,(+p[1]-1)*Z+0.5,Z-1,Z-1);}}
if(drag&&drag.box){b=boxOf(drag);g.strokeStyle='#c0391b';g.setLineDash([5,3]);g.lineWidth=2;g.strokeRect((b[0]-1)*Z+1,(b[1]-1)*Z+1,(b[2]-b[0]+1)*Z-2,(b[3]-b[1]+1)*Z-2);g.setLineDash([]);}
else if(hov){g.strokeStyle='#c0391b';g.lineWidth=2;g.strokeRect((hov[0]-1)*Z+1,(hov[1]-1)*Z+1,Z-2,Z-2);}
tabs();where();}
function count(s){var n=0,k;for(k in cells)if(s===undefined||k.indexOf(s+',')==0)n++;return n;}
function where(){var t='',c,n,r,i;if(hov){c=at(S,hov[0],hov[1]);t=storeyName(S)+', tile '+hov[0]+','+hov[1]+': ';n=[];
if(c&&c[0]){r=row(FLOORS,c[0]);n.push(r?r[1]:c[0]);}if(c&&c[1]){r=row(PIECES,c[1]);n.push(r?r[1]:c[1]);}if(c&&c[2]){r=row(ROOFS,c[2]);n.push(r?r[1]:c[2]);}
if(!n.length)n.push(S>1?(isFloor(S,hov[0],hov[1])?'bare upper floor':(wayUp(S-1,hov[0],hov[1])?'the opening over the way up':'open air')):'bare ground');
t+=n.join(', ');for(i=0;i<notes.length;i++)if(notes[i][0]==S&&notes[i][1]==hov[0]&&notes[i][2]==hov[1])t+=' - note: '+notes[i][3];}
$('at').innerHTML=esc(t);$('dims').innerHTML=esc(storeyName(S))+' &middot; '+several(count(S),'tile')+' drawn';}
function tabs(){var h='<span class="hint">Storey</span>',s,cls,i,lv;for(s=1;s<=STOREYS;s++){cls=s==S?'on':'';if(count(s))cls+=' has';lv='';for(i=0;i<CHK.length;i++)if(CHK[i].deck==s&&CHK[i].level!='note'){if(CHK[i].level=='error')lv='bad';else if(!lv)lv='warn';}
h+='<button class="'+cls+' '+lv+'" onclick="storey('+s+')" title="'+esc(storeyName(s))+'">'+storeyTab(s)+'<i></i></button>';}$('tabs').innerHTML=h;}
function storey(s){S=s;hov=null;noteShut();draw();listNotes();}

// ---- Drawing on it ----
function snap(){return JSON.stringify([cells,notes]);}
function restore(t){var o=JSON.parse(t);cells=o[0];notes=o[1];}
function push(t){hist.push(t||snap());if(hist.length>60)hist.shift();fut=[];}
function undo(){if(!hist.length){status('Nothing to undo.');return;}fut.push(snap());restore(hist.pop());status('');after();}
function redo(){if(!fut.length){status('Nothing to redo.');return;}hist.push(snap());restore(fut.pop());status('');after();}
function after(){rev++;if($('st').innerHTML=='Saved on the sheet.')status('');draw();listNotes();changed();}
// Sets one of a tile's three keys (i: 0 floor, 1 piece, 2 roof); '' clears it.
function put(s,x,y,i,v){var k=key(s,x,y),c=cells[k];if(!inGrid(x,y))return false;if(!c){if(!v)return false;c=cells[k]=['','',''];}if(c[i]==v)return false;c[i]=v;if(!c[0]&&!c[1]&&!c[2])delete cells[k];return true;}
function wipe(s,x,y){var k=key(s,x,y);if(!cells[k])return false;delete cells[k];return true;}
function layer(){return cur.l=='f'?0:(cur.l=='p'?1:2);}
// Draws with the picked tool on one tile of this storey.
function one(x,y,right){if(cur.l=='x')return wipe(S,x,y);if(cur.l=='n')return false;return put(S,x,y,layer(),right?'':cur.k);}
function boxOf(d){return [Math.min(d.x0,d.x),Math.min(d.y0,d.y),Math.max(d.x0,d.x),Math.max(d.y0,d.y)];}
// A box of walls is its outline; floors, roofing and the eraser fill it.
function box(d){var b=boxOf(d),x,y,did=false,ring=cur.l=='p'&&wallish(cur.k)&&!d.right;
for(y=b[1];y<=b[3];y++)for(x=b[0];x<=b[2];x++){if(ring&&x>b[0]&&x<b[2]&&y>b[1]&&y<b[3])continue;if(one(x,y,d.right))did=true;}return did;}
function pos(e){var cv=$('g'),r=cv.getBoundingClientRect(),x=Math.floor((e.clientX-r.left-2)/Z)+1,y=Math.floor((e.clientY-r.top-2)/Z)+1;return inGrid(x,y)?[x,y]:null;}
function boxMode(){drag=null;}
function hook(){var cv=$('g');cv.onmousedown=function(e){e=e||window.event;var p=pos(e),right=e.button==2;if(!p||e.button==1)return;if(e.preventDefault)e.preventDefault();
if(cur.l=='n'&&!right){noteOpen(p[0],p[1]);return;}
drag={x0:p[0],y0:p[1],x:p[0],y:p[1],right:right,box:$('bx').checked,before:snap()};stroked=false;status('');
if(!drag.box&&one(p[0],p[1],right)){stroked=true;}draw();};
cv.onmousemove=function(e){e=e||window.event;var p=pos(e);if(drag&&e.buttons!==undefined&&!e.buttons){finish();}
if(!p){if(hov){hov=null;draw();}return;}if(hov&&hov[0]==p[0]&&hov[1]==p[1])return;hov=p;
if(drag){drag.x=p[0];drag.y=p[1];if(!drag.box&&one(p[0],p[1],drag.right))stroked=true;}draw();peekAt();};
cv.onmouseleave=function(){if(hov){hov=null;draw();peekAt();}};
cv.oncontextmenu=function(){return false;};
document.onmouseup=function(){finish();};}
function finish(){var d=drag;if(!d)return;drag=null;if(d.box&&box(d))stroked=true;if(stroked){push(d.before);after();}else draw();}
function roofStorey(){var seen={},q=[],i,x,y,p,n,did=false,r=cur.l=='r'?cur.k:(lastRoof()||'w'),before=snap(),D=[[0,-1],[0,1],[-1,0],[1,0]];
// Everything the weather cannot walk to from beyond the sheet, doors shut.
for(i=1;i<=SIDE;i++){q.push([i,0],[i,SIDE+1],[0,i],[SIDE+1,i]);}
while(q.length){p=q.shift();for(i=0;i<4;i++){x=p[0]+D[i][0];y=p[1]+D[i][1];if(!inGrid(x,y)||seen[x+','+y])continue;n=pieceAt(S,x,y);if(solid(n)||kindOf(n)=='door')continue;seen[x+','+y]=1;q.push([x,y]);}}
for(y=1;y<=SIDE;y++)for(x=1;x<=SIDE;x++){if(seen[x+','+y])continue;n=kindOf(pieceAt(S,x,y));if(n=='stairs'||n=='ladder')continue;if(!roofAt(S,x,y)&&put(S,x,y,2,r))did=true;}
if(!did){status('Nothing to roof: draw walls all the way round a room first.');return;}push(before);status('');after();}
function lastRoof(){var k;for(k in cells)if(cells[k][2])return cells[k][2];return '';}
function copyBelow(){var x,y,p,d,did=false,before=snap();if(S<2){status('The ground floor has no storey below it.');return;}
for(y=1;y<=SIDE;y++)for(x=1;x<=SIDE;x++){p=pieceAt(S-1,x,y);d=kindOf(p);if(!p||d=='stairs'||d=='ladder'||!isFloor(S,x,y)||pieceAt(S,x,y))continue;
// A door upstairs opens on a drop: it becomes a window of the wall it stands in.
if(d=='door')p=masonry(S-1,x,y)?'M':'N';if(put(S,x,y,1,p))did=true;}
if(!did){status('Nothing to copy: roof the storey below first, wall tiles included.');return;}push(before);status('');after();}
function masonry(s,x,y){var D=[[0,-1],[0,1],[-1,0],[1,0]],i,r;for(i=0;i<4;i++){r=row(PIECES,pieceAt(s,x+D[i][0],y+D[i][1]));if(r&&r[2]!='door'&&r[3]>=4)return true;}return false;}
function clearStorey(){var k,before=snap(),did=false,i;for(k in cells)if(k.indexOf(S+',')==0){delete cells[k];did=true;}for(i=notes.length-1;i>=0;i--)if(notes[i][0]==S){notes.splice(i,1);did=true;}if(!did)return;push(before);status('');after();}
function load(sheet){var i,t;$('nm').value=sheet[0];cells={};notes=[];for(i=0;i<sheet[1].length;i++){t=sheet[1][i];if(inGrid(+t[1],+t[2]))cells[key(+t[0],+t[1],+t[2])]=[t[3]||'',t[4]||'',t[5]||''];}
for(i=0;i<(sheet[2]||[]).length;i++){t=sheet[2][i];notes.push([+t[0],+t[1],+t[2],t[3]+'']);}}
function loadExample(){var i=$('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);$('ex').value='';S=1;status('');after();}

// ---- The palette ----
function tool(l,k){cur={l:l,k:k};marks();part();draw();if(l!='n')noteShut();}
function tid(t){return 't_'+t.l+'_'+t.k;}
function pbtn(t,name,sub){return '<button id="'+tid(t)+'" onclick="tool(\''+t.l+'\',\''+t.k+'\')"><canvas width="24" height="24"></canvas><span class="nm">'+esc(cap(name))+(sub?'<u>'+esc(sub)+'</u>':'')+'</span></button>';}
function carries(r){return r[3]?'carries '+r[3]+(r[2]=='pillar'?', reaches '+r[4]:''):(KINDS[r[2]]||'');}
function palette(){var h=['','','','',''],i,r,b,t,all=[];
for(i=0;i<PIECES.length;i++){r=PIECES[i];t={l:'p',k:r[0]};all.push(t);h[r[2]=='wall'||r[2]=='pillar'?0:1]+=pbtn(t,r[1],carries(r));}
for(i=0;i<FLOORS.length;i++){r=FLOORS[i];t={l:'f',k:r[0]};all.push(t);h[2]+=pbtn(t,r[1],r[2]?'a foundation':'');}
for(i=0;i<ROOFS.length;i++){r=ROOFS[i];t={l:'r',k:r[0]};all.push(t);h[3]+=pbtn(t,r[1].replace(/ roof$/,''),'');}
t={l:'x',k:'x'};all.push(t);h[4]+=pbtn(t,'eraser','clears a tile');t={l:'n',k:'note'};all.push(t);h[4]+=pbtn(t,'note','pin words to a tile');
$('pw').innerHTML=h[0];$('po').innerHTML=h[1];$('pf').innerHTML=h[2];$('pr').innerHTML=h[3];$('pt').innerHTML=h[4];
for(i=0;i<all.length;i++){b=$(tid(all[i]));if(b)icon(b.getElementsByTagName('canvas')[0],all[i]);}marks();}
function marks(){var b=document.getElementsByTagName('button'),i;for(i=0;i<b.length;i++)if(b[i].id.indexOf('t_')==0)b[i].className=b[i].id==tid(cur)?'on':'';}
function helpKey(t){return t.l=='f'?'floor_'+t.k:(t.l=='r'?'roof_'+t.k:t.k);}
function toolOfHelp(k){if(k.indexOf('floor_')==0)return {l:'f',k:k.substring(6)};if(k.indexOf('roof_')==0)return {l:'r',k:k.substring(5)};if(k=='x')return {l:'x',k:'x'};if(k=='note')return {l:'n',k:'note'};return {l:'p',k:k};}
function toolName(t){var r;if(t.l=='x')return 'eraser';if(t.l=='n')return 'note';r=row(t.l=='p'?PIECES:(t.l=='f'?FLOORS:ROOFS),t.k);return r?r[1]:t.k;}

// ---- Notes ----
function cleanNote(t){return (t+'').replace(/_/g,' ').replace(/[^A-Za-z0-9 !()+\-.:=?]/g,'').replace(/^\s+|\s+$/g,'').substring(0,NOTELEN);}
function noteIndex(s,x,y){for(var i=0;i<notes.length;i++)if(notes[i][0]==s&&notes[i][1]==x&&notes[i][2]==y)return i;return -1;}
function noteOpen(x,y){var i=noteIndex(S,x,y);noteAt=[S,x,y];$('ned').style.display='block';$('nwh').innerHTML=esc(storeyName(S)+', tile '+x+','+y);$('ntx').value=i>=0?notes[i][3]:'';draw();listNotes();try{$('ntx').focus();}catch(e){}}
function noteShut(){if(!noteAt)return;noteAt=null;$('ned').style.display='none';draw();listNotes();}
function noteSave(){var t=cleanNote($('ntx').value),i,before=snap();if(!noteAt)return;if(!t){noteDrop();return;}i=noteIndex(noteAt[0],noteAt[1],noteAt[2]);
if(i<0&&notes.length>=NOTES){status('A plan holds '+NOTES+' notes. Take one off first.');return;}
if(i>=0){if(notes[i][3]==t){noteShut();return;}notes[i][3]=t;}else notes.push([noteAt[0],noteAt[1],noteAt[2],t]);push(before);noteAt=null;$('ned').style.display='none';status('');after();}
function noteDrop(){var i,before=snap();if(!noteAt)return;i=noteIndex(noteAt[0],noteAt[1],noteAt[2]);if(i<0){noteShut();return;}notes.splice(i,1);push(before);noteAt=null;$('ned').style.display='none';status('');after();}
function noteGo(i){var n=notes[i];if(!n)return;S=n[0];noteOpen(n[1],n[2]);}
function listNotes(){var h='',i,n;for(i=0;i<notes.length;i++){n=notes[i];h+='<div class="nt'+(noteAt&&noteAt[0]==n[0]&&noteAt[1]==n[1]&&noteAt[2]==n[2]?' on':'')+'" onclick="noteGo('+i+')" title="Click to show and edit it"><b>'+storeyTab(n[0])+' '+n[1]+','+n[2]+'</b><span>'+esc(n[3])+'</span></div>';}
if(!notes.length&&!noteAt)h='<span class="hint">No notes yet. Pick the note tool and click a tile to pin one.</span>';$('notes').innerHTML=h;$('ntn').innerHTML=notes.length+' of '+NOTES;fit();}

// ---- Talking to the server ----
function code(){var nm=$('nm').value.replace(/[\/;,]/g,' ').replace(/^\s+|\s+$/g,'').replace(/ /g,'_'),runs=[],nt=[],s,x,y,c,d,t,n,i;if(!nm)nm='house';
for(s=1;s<=STOREYS;s++)for(y=1;y<=SIDE;y++){x=1;while(x<=SIDE){c=cells[key(s,x,y)];if(!c){x++;continue;}t=(c[0]||'-')+(c[1]||'-')+(c[2]||'-');n=1;
while(x+n<=SIDE){d=cells[key(s,x+n,y)];if(!d||(d[0]||'-')+(d[1]||'-')+(d[2]||'-')!=t)break;n++;}runs.push(s+','+x+','+y+','+n+','+t);x+=n;}}
for(i=0;i<notes.length;i++)nt.push(notes[i][0]+','+notes[i][1]+','+notes[i][2]+','+notes[i][3].replace(/ /g,'_'));
return 'C13HOUSE/1/'+nm+'/'+runs.join(';')+'/'+nt.join(';');}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function waiting(){return parts!==null&&new Date().getTime()-busy<4000;}
function send(save){var p,j;if(timer){clearTimeout(timer);timer=null;}if(waiting()){if(save)status('Wait a moment...');dirty=true;return;}
p=code();if(p.length>MAX){status('The plan is too detailed for one sheet: simplify it, or split the house over two plans.');return;}
parts=[];for(j=0;j<p.length;j+=PART)parts.push(p.substring(j,j+PART));busy=new Date().getTime();dirty=false;if(save){sendRev=rev;status('Saving...');}
go('house=begin&n='+parts.length+'&mode='+(save?'save':'preview')+'&name='+encodeURIComponent($('nm').value));}
function houseAck(n){n=parseInt(n,10);if(!parts)return;if(n<parts.length){go('house=part&i='+n+'&d='+encodeURIComponent(parts[n]));return;}parts=null;go('house=end');}
function done(){parts=null;if(dirty){dirty=false;changed();}}
// The server answers once per 0.3 s: wait out the gap, so the last change
// is never the one it skips.
function changed(){if(timer)clearTimeout(timer);timer=setTimeout(function(){timer=null;send(0);},450);}
function status(t){$('st').innerHTML=t;}
function houseStatus(t){if(t!=='')status(esc(t));done();}
function houseSaved(){savedRev=sendRev;}
// Leaving with changes the sheet does not hold yet says so beside Save.
function unsaved(){return rev!=savedRev;}
function parse(s){var A=null;try{A=JSON.parse(s);}catch(e){A=null;}
if(!A){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e2){}try{A=JSON.parse(s);}catch(e3){A=null;}}
return A;}
// The server's answer: the figures and the findings.
function housePlan(s){var A=parse(s),o,i,p=[],m=[];if(!A){done();return;}
o='';
for(i=0;i<(A.parts||[]).length;i++)p.push('<b>'+(+A.parts[i][1])+'</b> '+esc(plural(+A.parts[i][1],A.parts[i][0])));
for(i=0;i<(A.materials||[]).length;i++)m.push('<b>'+(+A.materials[i][1])+'</b> '+esc(A.materials[i][0]));
o+='<div><span class="hint">Parts</span> &nbsp;'+(p.length?p.join(', '):'none yet')+'</div>';
if(m.length)o+='<div style="margin-top:3px"><span class="hint">About</span> &nbsp;'+m.join(', ')+' <span class="hint">by the usual recipes</span></div>';
$('stats').innerHTML=o;$('figk').innerHTML=A.storeys?several(+A.storeys,'storey')+' &middot; '+(+A.wide)+' by '+(+A.deep)+' tiles':'nothing drawn';checks(A.checks||[]);done();}

// ---- The Part and Checks panels ----
function finding(){var i=lit>=0?lit:pin;return i>=0&&CHK[i]?CHK[i]:null;}
function part(){var f=finding(),t,H,R=[['what','What'],['use','Use'],['how','How']],i,why,h,k;
if(f&&f.part){t=toolOfHelp(f.part);why='named by the check';}
else if(peek){t=peek.t;why=peek.why;}
else{t=cur;why='picked to draw with';}
k=helpKey(t);H=HELP[k];
h='<div class="pn"><canvas id="pic" width="28" height="28"></canvas><span class="w">'+esc(cap(toolName(t)))+'<span class="s">'+why+'</span></span></div>';
if(H)for(i=0;i<R.length;i++)if(H[R[i][0]])h+='<div class="pr"><i>'+R[i][1]+'</i><span>'+esc(H[R[i][0]])+'</span></div>';
$('part').innerHTML=h;icon($('pic'),t);}
function peekAt(){var c=hov?at(S,hov[0],hov[1]):null,p=null;if(c&&!drag){if(c[1])p={t:{l:'p',k:c[1]},why:'on the plan'};else if(c[2])p={t:{l:'r',k:c[2]},why:'on the plan'};else if(c[0])p={t:{l:'f',k:c[0]},why:'on the plan'};}
if((p?helpKey(p.t):'')!=(peek?helpKey(peek.t):'')){peek=p;part();}}
function whereText(i){var f=CHK[i];return (i==pin?'&#9679; ringed on the ':'&#9675; '+several(f.cells.length,'tile')+' on the ')+esc(storeyName(f.deck).toLowerCase());}
function mark(){var i,b,f,w;for(i=0;i<CHK.length;i++){b=$('ck_'+i);if(!b)continue;f=CHK[i];
b.className='ck '+f.level+(f.cells.length||f.part?' has':'')+(i==pin?' pin':'')+(i==lit?' lit':'');w=$('wh_'+i);if(w)w.innerHTML=whereText(i);}}
function show(i){lit=i;mark();part();draw();}
// Keeping a finding ringed steps to its storey.
function keep(i){pin=pin==i?-1:i;if(pin>=0&&CHK[i].cells.length&&CHK[i].deck>=1&&CHK[i].deck<=STOREYS&&CHK[i].deck!=S){S=CHK[i].deck;noteShut();listNotes();}mark();part();draw();}
function hookCheck(i){var b=$('ck_'+i);b.onmouseenter=b.onfocus=function(){show(i);};b.onmouseleave=b.onblur=function(){if(lit==i)show(-1);};b.onclick=function(){keep(i);};}
function checks(A){var i,f,was=CHK[pin]?CHK[pin].text:null,n=[0,0,0],h='',p=[];
CHK=[];lit=-1;pin=-1;for(i=0;i<A.length;i++){f={level:LEVEL[A[i].level]?A[i].level:'note',text:A[i].text||'',cells:A[i].cells||[],part:A[i].part||'',deck:+A[i].deck||1};CHK.push(f);if(was!==null&&f.text==was)pin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class="vd bad"><b>It cannot be built as drawn.</b> '+several(n[0],'thing')+' the game will refuse.</div>';
else h+='<div class="vd"><b>It can be built as drawn.</b>'+(n[1]?'<div class="also">'+several(n[1],'warning')+' below will not stop the building, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<CHK.length;i++){f=CHK[i];h+='<div tabindex="0" id="ck_'+i+'" class="ck"'+(f.cells.length?' title="Click to keep it ringed on the plan; click again to let go"':'')+'><span class="tag">'+LEVEL[f.level][0]+'</span><span class="tx">'+esc(f.text)+(f.cells.length?'<span class="wh" id="wh_'+i+'"></span>':'')+'</span></div>';}
$('checks').innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(several(n[1],'warning'));if(n[2])p.push(several(n[2],'note'));$('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<CHK.length;i++)hookCheck(i);
mark();part();draw();fit();}
// Pointing at a part in the palette shows what it is.
document.onmouseover=function(e){e=e||window.event;var b=e.target||e.srcElement,p=null,q;if(drag)return;
while(b&&b!=document.body){if(b.id&&b.id.indexOf('t_')==0){q=b.id.split('_');p={t:{l:q[1],k:q.slice(2).join('_')},why:''};p.why=helpKey(p.t)==helpKey(cur)?'picked to draw with':'click to pick it';break;}if(b.id=='g')return;b=b.parentNode;}
if((p?helpKey(p.t):'')!=(peek?helpKey(peek.t):'')){peek=p;part();}};
// The Checks panel fills the window's height, whatever it is.
function fit(){var h=(window.innerHeight||document.documentElement.clientHeight||770),c=$('checks'),top=c.getBoundingClientRect().top;c.style.height=Math.max(110,h-top-9)+'px';}
window.onresize=fit;
(function(){var e=$('ex'),j,o;for(j=0;j<EXAMPLES.length;j++){o=document.createElement('option');o.value=j;o.innerHTML=esc(EXAMPLES[j][0]);e.appendChild(o);}
g=$('g').getContext('2d');$('g').width=SIDE*Z;$('g').height=SIDE*Z;load(DATA.START);palette();hook();listNotes();draw();part();fit();changed();})();
</script></body></html>"}

#undef HOUSE_DESIGNER_WINDOW
#undef HOUSE_DESIGNER_PART
#undef HOUSE_DESIGNER_PREVIEW_GAP
