// ============================================================
// The station designer (docs/station-plans.md)
// ------------------------------------------------------------
// Hold a blank ship's draught (or a station plan) and a pen or pencil and
// choose to draw a space station: a window shows the plan's grid of slots,
// north to the top. A module is picked from the palette and clicked or
// dragged onto a slot; the eraser (or a right-click) clears a slot to open
// space. Docked modules show the hatch they share, the keel is drawn out
// from the keel airlock over the slots it must be left, and each docking
// airlock's berth is drawn on the slot beyond its outer hatch, where a
// rocket's capsule docks.
//
// Like the airship designer (naval/air_designer.dm), every change goes to
// the server, which reads it as a design code and answers with the plan's
// own figures, keel, berths and checks, so the window never disagrees with the
// sheet. Save keeps the drawing on the sheet. The Module panel says what the
// picked (or pointed at) module is, what it is for and how to get it
// (DATA.HELP); the Checks panel lists the findings and rings their slots.
//
// A slot is drawn in layers: a rim of hull, the floor inside it and the
// module's own furniture standing on that. The pictures are the sprites the
// built things have in the game: PNGs cut from the game's DMIs by
// scripts/build_station_designer_icons.py and sent with browse_rsc. A key
// with no picture shows as its letter.
//
// The page is station_designer_page() with one block of data at @@DATA@@:
//   REF       this designer's ref, for the window's links
//   SIDE      the slots of the grid each way
//   MAX       the most modules a plan may hold
//   PIECES    list(key, name)
//   START     the plan: list(name, list(list(col, row, key), ...))
//   EXAMPLES  ready-made plans in the same form
//   PICS      the pictures the server sends: "hull", "mod_C", "keel_wing"
//             ... each as "stad_<name>.png" (station_designer_sprites())
//   HELP      the part book: key -> list(what, use, how)
// The window sends ?src=REF;station=preview|save|export|import;code=<C13STATION code>;name=<name>
// and the server answers with stationPlan(json of station_designer_answer())
// and stationStatus(text).
// ============================================================

#define STATION_DESIGNER_WINDOW "station_designer"
#define STATION_DESIGNER_PREVIEW_GAP 3 // deciseconds between answers per drawer

// mob -> /datum/station_designer. A proc with a static list, not a global:
// the world's global init proc has no room for more.
/proc/station_designers()
	var/static/list/open
	if (!open)
		open = list()
	return open

// Picture name -> its picture, sent to the window as "stad_<name>.png". Cut
// from the game's DMIs by scripts/build_station_designer_icons.py.
/proc/station_designer_sprites()
	var/static/list/table
	if (!table)
		table = list(
		"hull" = 'icons/station_designer/hull.png',
		"floor" = 'icons/station_designer/floor.png',
		"hatch" = 'icons/station_designer/hatch.png',
		"mod_C" = 'icons/station_designer/mod_C.png',
		"mod_Q" = 'icons/station_designer/mod_Q.png',
		"mod_G" = 'icons/station_designer/mod_G.png',
		"mod_W" = 'icons/station_designer/mod_W.png',
		"mod_S" = 'icons/station_designer/mod_S.png',
		"mod_N" = 'icons/station_designer/mod_N.png',
		"mod_A" = 'icons/station_designer/mod_A.png',
		"mod_K" = 'icons/station_designer/mod_K.png',
		"mod_P" = 'icons/station_designer/mod_P.png',
		"keel_truss" = 'icons/station_designer/keel_truss.png',
		"keel_wing" = 'icons/station_designer/keel_wing.png',
		"keel_thruster" = 'icons/station_designer/keel_thruster.png',
		)
	return table

/datum/station_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/last_preview = null

/datum/station_designer/Destroy()
	var/list/open = station_designers()
	if (drawer && open[drawer] == src)
		open -= drawer
	drawer = null
	sheet = null
	return ..()

/obj/item/ship_draught/proc/open_station_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	if (draught_code && !station_plan_kind())
		to_chat(H, SPAN_WARNING("The sheet already holds another drawing."))
		return
	var/list/open = station_designers()
	var/datum/station_designer/old = open[H]
	if (old)
		qdel(old)
	var/datum/station_designer/A = new
	A.drawer = H
	A.sheet = src
	open[H] = A
	var/datum/station_plan/D = station_plan()
	if (!D)
		var/list/examples = station_plan_examples()
		D = examples[1]
		examples -= D
		for (var/datum/E in examples)
			qdel(E)
		D.name = "space station"
	var/list/sprites = station_designer_sprites()
	for (var/key in sprites)
		H << browse_rsc(sprites[key], "stad_[key].png")
	show_browse(H, station_designer_html(A, D), "window=[STATION_DESIGNER_WINDOW];size=1120x720")
	onclose(H, STATION_DESIGNER_WINDOW, A)
	station_designer_stats(H, D)
	qdel(D)

// A plan for the window: list(name, list(list(col, row, key), ...)), the
// slots north row first.
/proc/station_designer_sheet(datum/station_plan/D)
	var/list/slots = list()
	for (var/row = 1, row <= STATION_PLAN_SIDE, row++)
		for (var/col = 1, col <= STATION_PLAN_SIDE, col++)
			var/key = D.piece(col, row)
			if (key)
				slots += list(list(col, row, key))
	return list(D.name, slots)

/proc/station_designer_data(datum/station_designer/A, datum/station_plan/D)
	var/list/pieces = list()
	var/list/piece_table = station_plan_pieces()
	for (var/key in piece_table)
		pieces += list(list(key, piece_table[key]["name"]))
	var/list/examples = list()
	for (var/datum/station_plan/E in station_plan_examples())
		examples += list(station_designer_sheet(E))
		qdel(E)
	var/list/pics = list()
	for (var/key in station_designer_sprites())
		pics += key
	return list(
		"REF" = A ? "\ref[A]" : "",
		"SIDE" = STATION_PLAN_SIDE,
		"MAX" = STATION_PLAN_MAX_MODULES,
		"PIECES" = pieces,
		"START" = station_designer_sheet(D),
		"EXAMPLES" = examples,
		"PICS" = pics,
		"HELP" = design_part_help_for("station_plan"),
	)

/proc/station_designer_html(datum/station_designer/A, datum/station_plan/D)
	var/list/halves = splittext(station_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(station_designer_data(A, D)) + halves[2]

// The keel for the window: list(list(col, row, what), ...) for the slots of
// the grid it passes over, what being "truss", "wing" or "thruster". The
// porch and keel are truss, the boom ends carry the solar wings and the aft
// end the reboost thruster (orbit_found_station_plan).
/proc/station_designer_keel(datum/station_plan/D)
	. = list()
	var/list/slots = D.keel_slots()
	var/list/what = list("truss", "wing", "truss", "wing", "thruster")
	for (var/i = 1, i <= slots.len && i <= what.len, i++)
		var/list/xy = splittext(slots[i], ",")
		var/col = text2num(xy[1])
		var/row = text2num(xy[2])
		if (D.in_grid(col, row))
			. += list(list(col, row, what[i]))

// The berths for the window: list(list(col, row, lock col, lock row), ...)
// for each docking airlock's berth that lies on the grid, with the airlock
// it belongs to. A berth off the sheet is open space and is not drawn.
/proc/station_designer_berths(datum/station_plan/D)
	. = list()
	var/list/berths = D.berth_slots()
	for (var/berth in berths)
		var/list/xy = splittext(berth, ",")
		var/col = text2num(xy[1])
		var/row = text2num(xy[2])
		if (!D.in_grid(col, row))
			continue
		var/list/lock = splittext(berths[berth], ",")
		. += list(list(col, row, text2num(lock[1]), text2num(lock[2])))

// What the window is told of a plan: its figures, its keel, its berths and
// its findings.
/proc/station_designer_answer(datum/station_plan/D)
	var/list/C = D.costs()
	var/datum/design_report/R = D.check_design()
	. = list(
		"count" = D.module_count(),
		"max" = STATION_PLAN_MAX_MODULES,
		"allowance" = station_plan_allowance(),
		"bunks" = D.bunks(),
		"steel" = C["steel"],
		"cost" = D.costs_text(),
		"keel" = station_designer_keel(D),
		"berths" = station_designer_berths(D),
		"checks" = R.data(),
	)
	qdel(R)

/proc/station_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[STATION_DESIGNER_WINDOW].browser:stationStatus")

/proc/station_designer_stats(mob/user, datum/station_plan/D)
	user << output(list2params(list(json_encode(station_designer_answer(D)))), "[STATION_DESIGNER_WINDOW].browser:stationPlan")

/datum/station_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["station"] || H != drawer || station_designers()[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		station_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	// Import and Export work the same in every designer (naval/draught_kinds.dm).
	if (href_list["station"] == "import")
		sheet.draught_import_in_window(H, STATION_DESIGNER_WINDOW)
		return
	if (sheet.draught_code && !sheet.station_plan_kind())
		station_designer_status(H, "The sheet already holds another drawing.")
		return
	var/export = href_list["station"] == "export"
	var/save = export || href_list["station"] == "save"
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + STATION_DESIGNER_PREVIEW_GAP)
			return
		last_preview = world.time
	// station_plan_from_code() refuses a slot off the grid, a key that is no
	// module, a slot written twice and more modules than a plan holds.
	var/code = href_list["code"]
	if (!istext(code) || length(code) > DESIGN_CODE_STATION_MAX)
		station_designer_status(H, "The drawing could not be read.")
		return
	var/datum/station_plan/D = station_plan_from_code(code)
	if (!D)
		station_designer_status(H, "The drawing could not be read.")
		return
	D.name = station_plan_clean_name(href_list["name"])
	station_designer_stats(H, D)
	if (save)
		sheet.take_station(D)
		station_designer_status(H, "Saved on the sheet.")
		if (export)
			sheet.draught_export(H, D.name)
	qdel(D)

// Raw string: no DM interpolation inside, and never a double quote followed
// by a closing brace. Plain ES5 for the embedded browser. One @@DATA@@.
/proc/station_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Station plan</title><style>
html,body{height:100%}
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:0;overflow:hidden}
#wrap{display:flex;align-items:flex-start;padding:6px 8px 0 8px}
#plan{flex:0 0 474px;width:474px;margin-right:10px}
#side{flex:0 0 282px;width:282px;margin-right:10px}
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
button.cd{flex:none;white-space:nowrap;margin-right:4px}
.row{display:flex;align-items:center;margin-bottom:5px}
.row label{flex:0 0 50px;color:#bfae96;font-size:11px}
.hint{color:#b0a080;font-size:11px;line-height:1.35}
.lbl{color:#b0a080;font-size:10px;text-align:center;letter-spacing:1px;text-transform:uppercase}
img.pic{image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor;vertical-align:middle}
.chip{display:inline-block;background:#211c16;border:1px solid #b48c4d;border-radius:3px;min-width:16px;text-align:center;font-size:12px;line-height:18px;height:18px;color:#ffd985;font-weight:bold}

/* The plan */
#board{display:flex;justify-content:center;align-items:center;margin:2px 0}
#mid{display:flex;align-items:center;justify-content:center}
#mid .lbl{flex:none;width:9px;line-height:11px;word-wrap:break-word;letter-spacing:0}
#g{position:relative;background:#0b1018;border:2px solid #0f0c09;margin:0 3px;-webkit-user-select:none;-ms-user-select:none;user-select:none}
.t{position:absolute;box-sizing:border-box;cursor:pointer;overflow:hidden;background-color:#3b4046;background-size:100% 100%;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}
.t .fl{position:absolute;left:6px;top:6px;right:6px;bottom:6px;background-color:#6d7379;background-size:50% 50%;border:1px solid #14100c;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}
.t .p{position:absolute;left:50%;top:50%;width:48px;height:48px;margin:-24px 0 0 -24px}
.t .pl{position:absolute;left:50%;top:50%;width:18px;height:18px;margin:-10px 0 0 -10px;line-height:18px;font-size:12px}
.t .k{position:absolute;left:2px;top:1px;font-size:9px;font-weight:bold;color:#ffd985;background:#211c16;border:1px solid #806040;border-radius:2px;line-height:10px;padding:0 2px}
.t.none{background:none;border:1px dashed #1f2c3c}
.t.none:hover{border:1px solid #ffd985}
.t.keel{background:#161a12;border:1px dashed #b48c4d}
.t.keel i{position:absolute;left:0;right:0;bottom:1px;text-align:center;font-style:normal;font-size:9px;letter-spacing:1px;text-transform:uppercase;color:#b48c4d}
.t.keel .p{width:40px;height:40px;margin:-24px 0 0 -20px}
.t.berth{background:#101a24;border:1px dashed #7fb0d0}
.t.berth i{position:absolute;left:0;right:0;bottom:1px;text-align:center;font-style:normal;font-size:9px;letter-spacing:1px;text-transform:uppercase;color:#7fb0d0}
.t.berth .bc{position:absolute;left:50%;top:50%;width:26px;height:26px;margin:-19px 0 0 -13px;box-sizing:border-box;border:3px solid #7fb0d0;border-radius:50%;opacity:0.85}
.t.berth .bt{position:absolute;background:#7fb0d0;opacity:0.85}
.t .bw{position:absolute;left:3px;top:3px;right:3px;bottom:3px;border:2px dashed #7fb0d0;pointer-events:none}
.t .ring{position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none}
.t:hover .ring{box-shadow:inset 0 0 0 1px #ffd985}
.hx{position:absolute;width:18px;height:18px;margin:-9px 0 0 -9px;pointer-events:none;border:1px solid #ffd985;box-sizing:border-box;background:#3b4046;background-size:100% 100%;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor;z-index:2}

/* Figures */
#stats{min-height:70px;line-height:1.4}
.fg{display:flex;margin:2px 0 6px 0}
.fg div{flex:1 1 0;background:#262019;border:1px solid #54432f;padding:3px 0;text-align:center;margin-right:4px}
.fg div:last-child{margin-right:0}
.fg b{display:block;font-size:15px;color:#ffd985}
.fg b.bad{color:#f3a26a}
.fg span{font-size:10px;color:#bfae96}
#st{flex:1 1 auto;min-width:0;color:#ffd985;margin-left:9px;font-size:11px;line-height:1.25}

/* Palette */
.ph{color:#bfae96;font-size:11px;margin:5px 0 3px 0}
.pal{display:flex;flex-wrap:wrap}
.pal button{display:flex;align-items:center;text-align:left;width:138px;height:38px;line-height:12px;padding:1px 4px 1px 3px;margin:0 3px 3px 0;overflow:hidden;box-sizing:border-box}
.pal button .ic{flex:none;width:32px;height:32px;margin-right:6px;text-align:center;background:#6d7379;background-size:50% 50%;border:1px solid #14100c;box-sizing:border-box;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}
.pal button .ic.x{background:#0b1018;border:1px dashed #33465a}
.pal button .ic .chip{margin-top:5px}
.pal button .nm{flex:1 1 auto;min-width:0}
.pal button .nm u{display:block;text-decoration:none;font-size:10px;color:#bfae96}
.pal button.on .nm u{color:#3a2a14}

/* Module and Checks */
#part{height:176px;overflow:auto;line-height:1.35;box-sizing:border-box}
.pn{font-size:13px;font-weight:bold;margin-bottom:4px;display:flex;align-items:center}
.pn .ic{flex:none;margin-right:7px;background:#6d7379;background-size:50% 50%;border:1px solid #14100c;line-height:0;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}
.pn .ic.x{background:none;border:0;line-height:normal}
.pn .w{flex:1 1 auto}
.pn span.s{font-size:11px;font-weight:normal;color:#bfae96;margin-left:8px}
.pr{display:flex;margin-top:2px}
.pr i{flex:0 0 38px;font-style:normal;color:#b48c4d;font-size:11px;padding-top:1px}
.pr span{flex:1 1 auto;min-width:0}
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
<div class='sec'><h2>Station plan<span id='dims'></span></h2><div class='in'>
<div class='lbl'>north</div>
<div id='board'><div id='mid'><div class='lbl'>west</div><div id='g'></div><div class='lbl'>east</div></div></div>
<div class='lbl'>south</div>
</div></div>
<div class='sec'><h2>Figures<span id='figk'></span></h2><div class='in'><div id='stats'><span class='hint'>Reckoning...</span></div></div></div>
</div>

<div id='side'>
<div class='row'><label for='nm'>Name</label><input id='nm' maxlength='40' style='flex:1 1 auto;min-width:0' onchange='changed()' onkeyup='changed()'></div>
<div class='ph'>Modules <span class='hint'>- one to a slot; side by side they dock</span></div><div class='pal' id='pm'></div>
<div class='row' style='margin-top:4px'><button onclick='undo()' style='margin-right:3px'>Undo</button><button onclick='redo()' style='margin-right:8px'>Redo</button><span class='hint' style='white-space:nowrap'>Start from&nbsp;</span><select id='ex' style='flex:1 1 auto;min-width:0;margin-right:4px'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>
<div class='row'><button class='go' onclick='send(1)'>Save to the sheet</button><span id='st'></span></div>
<div class='row' style='margin-bottom:0'><button class='cd' onclick='exportCode()' title='Save the drawing on the sheet and show its design code to copy'>Export code</button><button class='cd' onclick='importCode()' title='Paste a design code; it replaces what is drawn on this sheet'>Import code</button></div>
<div class='hint' style='margin-top:7px'>Click or drag over slots to draw with the picked module. Right-click clears a slot. A station has one command module and one keel airlock: drawing either again moves it.</div>
<div class='hint' style='margin-top:6px'>A station needs at least one docking airlock, docked to one module, with the slot beyond it left empty: that is its berth, where rockets dock.</div>
<div class='hint' style='margin-top:6px'>The keel runs out from the keel airlock, away from the module it docks to: truss, a solar wing each side and the thruster at its end. Leave the slots it is drawn over empty.</div>
</div>

<div id='info'>
<div class='sec'><h2>Module</h2><div class='in' id='part'></div></div>
<div class='sec' style='margin-bottom:0'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div>
</div>

</div><script>
var DATA=@@DATA@@;
var REF=DATA.REF,SIDE=DATA.SIDE,MAX=DATA.MAX,PIECES=DATA.PIECES,EXAMPLES=DATA.EXAMPLES||[],PICS=DATA.PICS||[],HELP=DATA.HELP||{};
var cells={},cur='C',hist=[],fut=[],timer=null,lastSent=0,T=64,KEEL=[],BERTH=[];
var CHK=[],lit=-1,pin=-1,peek=null,stroke=false,stroked=false;
var LEVEL={error:['Fix','#ff6f3c'],warning:['Warning','#ffd23f'],note:['Note','#fff6dc']};
var KEELNAME={truss:'keel truss',wing:'solar wing',thruster:'reboost thruster'};
// The furniture that tells each module apart, for the palette.
var HAS={C:'console, way home',Q:'two bunks',G:'two trays',W:'a workbench',S:'two crates',N:'a deck hatch',A:'a way out',K:'the keel hangs here',P:'a docking port'};
function $(i){return document.getElementById(i);}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;');}
function key(c,r){return c+','+r;}
function row(list,k){for(var i=0;i<list.length;i++)if(list[i][0]==k)return list[i];return null;}
function several(n,one){return n+' '+one+(n==1?'':'s');}
function cap(s){s=s+'';return s.charAt(0).toUpperCase()+s.substring(1);}
function inGrid(c,r){return c>=1&&r>=1&&c<=SIDE&&r<=SIDE&&c==Math.round(c)&&r==Math.round(r);}

// ---- Pictures ----
function hasPic(n){for(var i=0;i<PICS.length;i++)if(PICS[i]==n)return true;return false;}
function src(n){return hasPic(n)?'stad_'+n+'.png':null;}
function noPic(i){var s=document.createElement('span');s.className=i.getAttribute('data-c')||'chip';s.innerHTML=i.alt;i.parentNode.replaceChild(s,i);}
function floorCss(){var s=src('floor');return s?'background-image:url('+s+');':'';}
// A module's picture on a square of floor, n pixels a side; the eraser is open space.
function pic(k,n){var s,h;
if(k=='x')return '<span class="ic x" style="width:'+n+'px;height:'+n+'px"><span class="chip" style="margin-top:'+Math.round((n-20)/2)+'px">&#215;</span></span>';
s=src('mod_'+k);h=s?'<img class="pic" width="'+(n-2)+'" height="'+(n-2)+'" src="'+s+'" alt="'+esc(k)+'" onerror="noPic(this)">':'<span class="chip" style="margin-top:'+Math.round((n-20)/2)+'px">'+esc(k)+'</span>';
return '<span class="ic" style="display:inline-block;width:'+n+'px;height:'+n+'px;'+floorCss()+'">'+h+'</span>';}
function nameOf(k){if(k=='x')return 'eraser';var r=row(PIECES,k);return r?r[1]:k;}

// ---- The plan ----
function load(sheet){var i,t;$('nm').value=sheet[0];cells={};for(i=0;i<sheet[1].length;i++){t=sheet[1][i];if(inGrid(+t[0],+t[1])&&row(PIECES,t[2]))cells[key(t[0],t[1])]=t[2];}}
function snap(){var o={},k;for(k in cells)o[k]=cells[k];return o;}
function push(s){hist.push(s||snap());if(hist.length>60)hist.shift();fut=[];}
function undo(){if(!hist.length){status('Nothing to undo.');return;}fut.push(snap());cells=hist.pop();status('');KEEL=[];BERTH=[];draw();changed();}
function redo(){if(!fut.length){status('Nothing to redo.');return;}hist.push(snap());cells=fut.pop();status('');KEEL=[];BERTH=[];draw();changed();}
function count(){var n=0,k;for(k in cells)n++;return n;}
function tool(t){cur=t;marks();part();}
// Draws on one slot. A drag is one stroke: Undo takes all of it back.
function apply(c,r,right,drag){var at=key(c,r),was=cells[at]||'',k=right?'x':cur,before,o;if(!inGrid(c,r))return;if(!drag)status('');
if(k=='x'){if(!was)return;before=snap();delete cells[at];}
else{if(was==k||!row(PIECES,k))return;
if(!was&&count()>=MAX){status('A station is launched with '+MAX+' modules at most. Add more in orbit with module kits.');return;}
before=snap();
// One command module and one keel airlock: the old one makes way.
if(k=='C'||k=='K')for(o in cells)if(cells[o]==k)delete cells[o];
cells[at]=k;}
if(!(drag&&stroked))push(before);stroked=true;
KEEL=[];BERTH=[];draw();changed();}
function down(c,r,e){e=e||window.event;if(e.button==2)return;stroke=true;stroked=false;apply(c,r,0,0);if(e.preventDefault)e.preventDefault();}
function over(c,r,e){e=e||window.event;if(!stroke)return;if(e.buttons!==undefined&&!(e.buttons&1)){stroke=false;return;}if(cur=='C'||cur=='K')return;apply(c,r,0,1);}
document.onmouseup=function(){stroke=false;};
function loadExample(){var i=$('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);status('');KEEL=[];BERTH=[];draw();changed();}

// ---- Drawing ----
function keelAt(c,r){for(var i=0;i<KEEL.length;i++)if(KEEL[i][0]==c&&KEEL[i][1]==r)return KEEL[i][2];return null;}
function berthAt(c,r){for(var i=0;i<BERTH.length;i++)if(BERTH[i][0]==c&&BERTH[i][1]==r)return BERTH[i];return null;}
// The tunnel from a berth's collar to the hatch of its docking airlock.
function tunnel(b){var dc=b[2]-b[0],dr=b[3]-b[1];
if(dc<0)return 'left:0;top:22px;width:19px;height:6px;';
if(dc>0)return 'right:0;top:22px;width:19px;height:6px;';
if(dr<0)return 'left:29px;top:0;width:6px;height:12px;';
return 'left:29px;top:38px;width:6px;height:12px;';}
function tile(c,r){var k=cells[key(c,r)],kw=keelAt(c,r),bw=berthAt(c,r),x=(c-1)*T,y=(r-1)*T,st='left:'+x+'px;top:'+y+'px;width:'+T+'px;height:'+T+'px;',h='',s,cls='t',what;
if(k){s=src('hull');if(s)st+='background-image:url('+s+');';
h+='<span class="fl" style="'+floorCss()+'"></span>';s=src('mod_'+k);
h+=s?'<img class="pic p" src="'+s+'" alt="'+esc(k)+'" data-c="chip pl" onerror="noPic(this)">':'<span class="chip pl">'+esc(k)+'</span>';
h+='<span class="k">'+esc(k)+'</span>';if(bw)h+='<span class="bw"></span>';what=nameOf(k)+(kw?', in the way of the keel':'')+(bw?', in the way of a docking airlock\'s berth':'');}
else if(kw){cls+=' keel';s=src('keel_'+kw);h+=s?'<img class="pic p" src="'+s+'" alt="keel" data-c="chip pl" onerror="noPic(this)">':'';h+='<i>keel</i>';what=KEELNAME[kw]+' on the keel: leave this slot empty'+(bw?'; a docking airlock\'s berth lies across it':'');}
else if(bw){cls+=' berth';h+='<span class="bt" style="'+tunnel(bw)+'"></span><span class="bc"></span><i>berth</i>';what='berth of a docking airlock: leave this slot empty for rockets';}
else{cls+=' none';what='open space';}
h+='<span class="ring"></span>';
return '<div class="'+cls+'" id="c_'+c+'_'+r+'" style="'+st+'" title="'+esc(cap(what))+'" onmousedown="down('+c+','+r+',event)" onmouseover="over('+c+','+r+',event)" oncontextmenu="apply('+c+','+r+',1,0);return false;">'+h+'</div>';}
// The hatch two docked modules share, on the wall between them.
function hatches(){var h='',r,c,s=src('hatch'),st=s?'background-image:url('+s+');':'';
for(r=1;r<=SIDE;r++)for(c=1;c<=SIDE;c++){if(!cells[key(c,r)])continue;
if(cells[key(c+1,r)])h+='<span class="hx" style="left:'+(c*T)+'px;top:'+((r-0.5)*T)+'px;'+st+'"></span>';
if(cells[key(c,r+1)])h+='<span class="hx" style="left:'+((c-0.5)*T)+'px;top:'+(r*T)+'px;'+st+'"></span>';}
return h;}
function draw(){var g=$('g'),h='',r,c;
g.style.width=(SIDE*T)+'px';g.style.height=(SIDE*T)+'px';
for(r=1;r<=SIDE;r++)for(c=1;c<=SIDE;c++)h+=tile(c,r);g.innerHTML=h+hatches();
$('dims').innerHTML=several(count(),'module')+', '+MAX+' at most';light();}
function pbtn(k){var n=k=='x'?'eraser':nameOf(k).replace(/ module$/,''),u=k=='x'?'open space':(HAS[k]||'');return '<button id="t_'+k+'" onclick="tool(\''+k+'\')">'+pic(k,32)+'<span class="nm">'+esc(cap(n))+(u?'<u>'+esc(u)+'</u>':'')+'</span></button>';}
function palette(){var h='',i;for(i=0;i<PIECES.length;i++)h+=pbtn(PIECES[i][0]);h+=pbtn('x');$('pm').innerHTML=h;marks();}
function marks(){var b=document.getElementsByTagName('button'),i;for(i=0;i<b.length;i++)if(b[i].id.indexOf('t_')==0)b[i].className=b[i].id=='t_'+cur?'on':'';}

// ---- Talking to the server ----
function code(){var nm=$('nm').value.replace(/[\/;,]/g,' ').replace(/^\s+|\s+$/g,'').replace(/ /g,'_'),t=[],r,c,k;if(!nm)nm='space_station';
for(r=1;r<=SIDE;r++)for(c=1;c<=SIDE;c++){k=cells[key(c,r)];if(k)t.push(c+','+r+','+k);}
return 'C13STATION/1/'+nm+'/'+t.join(';');}
// Export saves like Save and then shows the code; Import asks for one.
function exportCode(){send('export');}
function importCode(){if(timer){clearTimeout(timer);timer=null;}location.href='byond://?src='+REF+';station=import';}
function send(save){if(timer){clearTimeout(timer);timer=null;}lastSent=new Date().getTime();if(save)status('Saving...');
location.href='byond://?src='+REF+';station='+(save=='export'?'export':save?'save':'preview')+';code='+encodeURIComponent(code())+';name='+encodeURIComponent($('nm').value);}
// The server answers once per 0.3 s: wait out the gap, so the last change
// is never the one it skips.
function changed(){if(timer)clearTimeout(timer);var wait=Math.max(300,450-(new Date().getTime()-lastSent));timer=setTimeout(function(){timer=null;send(0);},wait);}
function status(t){$('st').innerHTML=t;}
function stationStatus(t){status(esc(t));}
function parse(s){var A=null;try{A=JSON.parse(s);}catch(e){A=null;}
if(!A){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e2){}try{A=JSON.parse(s);}catch(e3){A=null;}}
return A;}
// The server's answer: the figures, the keel, the berths and the findings.
function stationPlan(s){var A=parse(s),o,extra,i,k;if(!A)return;
BERTH=[];if(A.berths)for(i=0;i<A.berths.length;i++){k=A.berths[i];if(inGrid(+k[0],+k[1]))BERTH.push([+k[0],+k[1],+k[2],+k[3]]);}
KEEL=[];if(A.keel)for(i=0;i<A.keel.length;i++){k=A.keel[i];if(inGrid(+k[0],+k[1])&&KEELNAME[k[2]])KEEL.push([+k[0],+k[1],k[2]]);}
extra=Math.max(0,A.count-A.allowance);
o='<div class="fg"><div><b'+(A.count>A.max?' class="bad"':'')+'>'+(+A.count)+'</b><span>modules of '+(+A.max)+'</span></div><div><b>'+(+A.bunks)+'</b><span>bunks</span></div><div><b>'+extra+'</b><span>past the starter&#39;s '+(+A.allowance)+'</span></div><div><b>'+(+A.steel)+'</b><span>steel</span></div></div>';
o+='<div><span class="hint">Cost</span> &nbsp;A launch complex office builds her for <b>'+esc(A.cost)+'</b>.</div>';
$('stats').innerHTML=o;$('figk').innerHTML=KEEL.length?(KEEL.length<5?'her keel runs on past the sheet':'keel drawn over '+several(KEEL.length,'slot')):'no keel yet';
draw();checks(A.checks||[]);}

// ---- The Module and Checks panels ----
function finding(){var i=lit>=0?lit:pin;return i>=0&&CHK[i]?CHK[i]:null;}
function part(){var f=finding(),k,H,R=[['what','What'],['use','Use'],['how','How']],i,why,h;
if(f&&f.part){k=f.part;why='named by the check';}
else if(peek){k=peek.substring(1);why=peek.charAt(0)=='t'?(k==cur?'picked to draw with':'click to pick it'):(peek.charAt(0)=='k'?'its keel crosses this slot':(peek.charAt(0)=='b'?'its berth is this slot':'on the plan'));}
else{k=cur;why='picked to draw with';}
H=HELP[k];
h='<div class="pn">'+pic(k,34)+'<span class="w">'+esc(cap(nameOf(k)))+'<span class="s">'+why+'</span></span></div>';
if(H)for(i=0;i<R.length;i++)if(H[R[i][0]])h+='<div class="pr"><i>'+R[i][1]+'</i><span>'+esc(H[R[i][0]])+'</span></div>';
$('part').innerHTML=h;}
function light(){var g=$('g'),f=finding(),d=g.getElementsByTagName('div'),i,p,td,col,s;
for(i=0;i<d.length;i++){s=d[i].lastChild;if(s&&s.className=='ring'){s.style.outline='';s.style.boxShadow='';}}
if(!f)return;col=LEVEL[f.level][1];
for(i=0;i<f.cells.length;i++){p=(f.cells[i]+'').split(',');td=$('c_'+p[0]+'_'+p[1]);if(!td||!td.lastChild)continue;s=td.lastChild;
s.style.outline='3px solid '+col;s.style.outlineOffset='-4px';s.style.boxShadow='inset 0 0 0 5px rgba(20,12,6,0.75)';}}
function where(i){return i==pin?'&#9679; ringed on the plan':'&#9675; '+several(CHK[i].cells.length,'slot')+' on the plan';}
function mark(){var i,b,f,w;for(i=0;i<CHK.length;i++){b=$('ck_'+i);if(!b)continue;f=CHK[i];
b.className='ck '+f.level+(f.cells.length||f.part?' has':'')+(i==pin?' pin':'')+(i==lit?' lit':'');w=$('wh_'+i);if(w)w.innerHTML=where(i);}}
function show(i){lit=i;mark();part();light();}
function keep(i){pin=pin==i?-1:i;mark();part();light();}
function hook(i){var b=$('ck_'+i);b.onmouseenter=b.onfocus=function(){show(i);};b.onmouseleave=b.onblur=function(){if(lit==i)show(-1);};b.onclick=function(){keep(i);};}
function checks(A){var i,f,was=CHK[pin]?CHK[pin].text:null,n=[0,0,0],h='',p=[];
if(!A||!A.length)A=[];
CHK=[];lit=-1;pin=-1;for(i=0;i<A.length;i++){f={level:LEVEL[A[i].level]?A[i].level:'note',text:A[i].text||'',cells:A[i].cells||[],part:A[i].part||''};CHK.push(f);if(was!==null&&f.text==was)pin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class="vd bad"><b>Not ready to launch.</b> '+several(n[0],'thing')+' to fix first.</div>';
else h+='<div class="vd"><b>Ready to launch.</b> As drawn she can be launched from a launch complex office.'+(n[1]?'<div class="also">'+several(n[1],'warning')+' below will not stop the launch, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<CHK.length;i++){f=CHK[i];h+='<div tabindex="0" id="ck_'+i+'" class="ck"'+(f.cells.length?' title="Click to keep it ringed on the plan; click again to let go"':'')+'><span class="tag">'+LEVEL[f.level][0]+'</span><span class="tx">'+esc(f.text)+(f.cells.length?'<span class="wh" id="wh_'+i+'"></span>':'')+'</span></div>';}
$('checks').innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(several(n[1],'warning'));if(n[2])p.push(several(n[2],'note'));$('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<CHK.length;i++)hook(i);
mark();part();light();fit();}
// Pointing at a module in the palette or a slot shows what it is.
document.onmouseover=function(e){e=e||window.event;var b=e.target||e.srcElement,k=null,p,v;if(stroke)return;
while(b&&b!=document.body){if(b.id){
if(b.id.indexOf('t_')==0){k='t'+b.id.substring(2);break;}
if(b.id.indexOf('c_')==0){p=b.id.split('_');v=cells[key(p[1],p[2])];k=v?'c'+v:(keelAt(+p[1],+p[2])?'kK':(berthAt(+p[1],+p[2])?'bP':null));break;}}
b=b.parentNode;}
if(k!=peek){peek=k;part();}};
// The panels fill the window's height, whatever it is.
function fit(){var h=(window.innerHeight||document.documentElement.clientHeight||720),c=$('checks'),top=c.getBoundingClientRect().top;c.style.height=Math.max(120,h-top-9)+'px';}
window.onresize=fit;
(function(){var e=$('ex'),j,o;for(j=0;j<EXAMPLES.length;j++){o=document.createElement('option');o.value=j;o.innerHTML=esc(EXAMPLES[j][0]);e.appendChild(o);}
load(DATA.START);cur=PIECES.length?PIECES[0][0]:'x';palette();draw();part();fit();changed();})();
</script></body></html>"}

#undef STATION_DESIGNER_WINDOW
#undef STATION_DESIGNER_PREVIEW_GAP
