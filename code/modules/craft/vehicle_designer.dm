// ============================================================
// The vehicle designer (docs/vehicle-sheets.md)
// ------------------------------------------------------------
// Hold a blank ship's draught (or a vehicle sheet) and a pen or pencil and
// choose "Draw a vehicle on the sheet" (or "Draw a tank" or "Draw a plane",
// which open the same window on the heavy axis or the airframe controls with
// that kind's ready-made sheet): a window shows the vehicle's plan,
// front to the top and its left on the left. The axis, the engine and the
// size are picked above the plan; frames, wheels and tracks, and the parts
// that stand on the frames are picked from a palette and clicked onto it.
//
// Like the ship and submarine designers, every change goes to the server,
// which reads it as a design code and answers with the sheet's own summary
// and checks, so the window never disagrees with the sheet. Save keeps the
// drawing on the sheet. The Part panel says what the picked (or pointed at)
// thing is, what it is for and how to use it (DATA.HELP); the Checks panel
// lists the findings and lights their tiles.
//
// A frame, a part, a wheel or a track is shown as the sprite the built thing
// has in the game: PNGs cut from the game's DMIs by
// scripts/build_vehicle_designer_icons.py and sent with browse_rsc. The
// wheels and tracks of the left and right columns are drawn in boxes beside
// the plan; a dashed box marks a corner frame that still needs one.
//
// The page is vehicle_designer_page() with one block of data at @@DATA@@:
//   REF       this designer's ref, for the window's links
//   AXES      list(key, name, frame keys, weight it bears)
//   FRAMES    list(key, name)
//   MOVERS    list(key, name)
//   PARTS     list(key, name)
//   ENGINES   list(key, name, min cc, max cc, steel per 1000 cc, power per 1000 cc)
//   MIN, MAX  the sizes a land vehicle may be
//   PLANEMAX  a plane is 3 wide and 3 to PLANEMAX long, or 5 wide (a twin)
//             and 4 to PLANEMAX long
//   START     the sheet: list(name, axis, engine, cc, width, length,
//             list(list(col, row, frame, mover, part), ...)) with "" for none
//   EXAMPLES  ready-made sheets in the same form
//   PICS      the pictures the server sends: "frame_s", "mover_W", "part_E"
//             ... each as "vehd_<name>.png" (vehicle_designer_sprites)
//   HELP      the part book: key -> list(what, use, how)
// The window sends ?src=REF;car=preview|save|export|import;code=<C13CAR code>;name=<name>
// and the server answers with carStats(summary html), carChecks(json of
// the report's data()) and carStatus(text).
// ============================================================

#define VEHICLE_DESIGNER_WINDOW "vehicle_designer"
#define VEHICLE_DESIGNER_PREVIEW_GAP 3 // deciseconds between summaries per drawer

var/global/list/vehicle_designers = list() // mob -> /datum/vehicle_designer

// Picture name -> its picture, sent to the window as "vehd_<name>.png". The
// name is the key's table and the key: "frame_<key>", "mover_<key>" or
// "part_<key>". Keys of different tables differ only by case (the wood frame
// "w" and the wheel "W") and Windows serves the cache without it, so the
// table is part of the file's name. Cut from the game's DMIs by
// scripts/build_vehicle_designer_icons.py. A key with no picture shows as
// its letter.
var/global/list/vehicle_designer_sprites = list(
	"frame_s" = 'icons/vehicle_designer/frame_s.png',
	"frame_w" = 'icons/vehicle_designer/frame_w.png',
	"frame_a" = 'icons/vehicle_designer/frame_a.png',
	"mover_W" = 'icons/vehicle_designer/mover_W.png',
	"mover_K" = 'icons/vehicle_designer/mover_K.png',
	"part_E" = 'icons/vehicle_designer/part_E.png',
	"part_Y" = 'icons/vehicle_designer/part_Y.png',
	"part_M" = 'icons/vehicle_designer/part_M.png',
	"part_T" = 'icons/vehicle_designer/part_T.png',
	"part_X" = 'icons/vehicle_designer/part_X.png',
	"part_D" = 'icons/vehicle_designer/part_D.png',
	"part_G" = 'icons/vehicle_designer/part_G.png',
	"part_L" = 'icons/vehicle_designer/part_L.png',
	"part_C" = 'icons/vehicle_designer/part_C.png',
	"part_U" = 'icons/vehicle_designer/part_U.png',
	"part_H" = 'icons/vehicle_designer/part_H.png',
)

/datum/vehicle_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/last_preview = null

/datum/vehicle_designer/Destroy()
	if (drawer && vehicle_designers[drawer] == src)
		vehicle_designers -= drawer
	drawer = null
	sheet = null
	return ..()

// start_axis opens a blank sheet on that axis's first ready-made sheet: the
// light tank for "heavy", the light plane for "plane".
/obj/item/ship_draught/proc/open_vehicle_designer(mob/living/human/H, start_axis = "car")
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	var/datum/vehicle_designer/old = vehicle_designers[H]
	if (old)
		qdel(old)
	var/datum/vehicle_designer/V = new
	V.drawer = H
	V.sheet = src
	vehicle_designers[H] = V
	var/datum/vehicle_draught/D = vehicle_draught()
	if (!D)
		var/list/examples = vehicle_draught_examples()
		D = examples[1]
		for (var/datum/vehicle_draught/E in examples)
			if (E.axis == start_axis)
				D = E
				break
		examples -= D
		for (var/datum/E in examples)
			qdel(E)
		D.name = D.plane() ? "plane" : (D.axis == "heavy" ? "tank" : "vehicle")
	for (var/key in vehicle_designer_sprites)
		H << browse_rsc(vehicle_designer_sprites[key], "vehd_[key].png")
	show_browse(H, vehicle_designer_html(V, D), "window=[VEHICLE_DESIGNER_WINDOW];size=1000x640")
	onclose(H, VEHICLE_DESIGNER_WINDOW, V)
	vehicle_designer_stats(H, D)
	qdel(D)

// A sheet for the window: list(name, axis, engine, cc, width, length, cells).
/proc/vehicle_designer_sheet(datum/vehicle_draught/D)
	var/list/cells = list()
	for (var/row = 1, row <= D.length, row++)
		for (var/col = 1, col <= D.width, col++)
			var/list/C = D.cell(col, row)
			cells += list(list(col, row, C[1] ? C[1] : "", C[2] ? C[2] : "", C[3] ? C[3] : ""))
	return list(D.name, D.axis, D.engine, D.cc, D.width, D.length, cells)

/proc/vehicle_designer_data(datum/vehicle_designer/V, datum/vehicle_draught/D)
	var/list/axes = list()
	for (var/key in vehicle_draught_axes)
		var/list/A = vehicle_draught_axes[key]
		var/obj/structure/vehicleparts/axis/P = A["path"]
		axes += list(list(key, A["name"], A["frames"], initial(P.maxpower)))
	var/list/frames = list()
	for (var/key in vehicle_draught_frames)
		frames += list(list(key, vehicle_draught_frames[key]["name"]))
	var/list/movers = list()
	for (var/key in vehicle_draught_movers)
		movers += list(list(key, vehicle_draught_movers[key]["name"]))
	var/list/parts = list()
	for (var/key in vehicle_draught_parts)
		parts += list(list(key, vehicle_draught_parts[key]["name"]))
	var/list/engines = list()
	for (var/key in vehicle_draught_engines)
		var/list/E = vehicle_draught_engines[key]
		var/obj/structure/engine/internal/P = E["path"]
		engines += list(list(key, E["name"], E["min"], E["max"], E["steel"], initial(P.maxpower)))
	var/list/examples = list()
	for (var/datum/vehicle_draught/E in vehicle_draught_examples())
		examples += list(vehicle_designer_sheet(E))
		qdel(E)
	var/list/pics = list()
	for (var/key in vehicle_designer_sprites)
		pics += key
	return list(
		"REF" = V ? "\ref[V]" : "",
		"AXES" = axes,
		"FRAMES" = frames,
		"MOVERS" = movers,
		"PARTS" = parts,
		"ENGINES" = engines,
		"MIN" = VEHICLE_DRAUGHT_MIN,
		"MAX" = VEHICLE_DRAUGHT_MAX,
		"PLANEMAX" = AIRCRAFT_MAX_LENGTH,
		"START" = vehicle_designer_sheet(D),
		"EXAMPLES" = examples,
		"PICS" = pics,
		"HELP" = design_part_help_for("vehicle_sheet"),
	)

/proc/vehicle_designer_html(datum/vehicle_designer/V, datum/vehicle_draught/D)
	var/list/halves = splittext(vehicle_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(vehicle_designer_data(V, D)) + halves[2]

/proc/vehicle_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[VEHICLE_DESIGNER_WINDOW].browser:carStatus")

/proc/vehicle_designer_stats(mob/user, datum/vehicle_draught/D)
	user << output(list2params(list(D.summary_text())), "[VEHICLE_DESIGNER_WINDOW].browser:carStats")
	var/datum/design_report/R = D.check_design()
	user << output(list2params(list(json_encode(R.data()))), "[VEHICLE_DESIGNER_WINDOW].browser:carChecks")
	qdel(R)

/datum/vehicle_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["car"] || H != drawer || vehicle_designers[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		vehicle_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	// Import and Export work the same in every designer (naval/draught_kinds.dm).
	if (href_list["car"] == "import")
		sheet.draught_import_in_window(H, VEHICLE_DESIGNER_WINDOW)
		return
	var/export = href_list["car"] == "export"
	var/save = export || href_list["car"] == "save"
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + VEHICLE_DESIGNER_PREVIEW_GAP)
			return
		last_preview = world.time
	var/code = href_list["code"]
	if (!istext(code) || length(code) > DESIGN_CODE_CAR_MAX)
		vehicle_designer_status(H, "The drawing could not be read.")
		return
	var/datum/vehicle_draught/D = vehicle_draught_from_code(code)
	if (!D)
		vehicle_designer_status(H, "The drawing could not be read.")
		return
	D.name = vehicle_draught_clean_name(href_list["name"])
	vehicle_designer_stats(H, D)
	if (save)
		sheet.take_vehicle(D)
		vehicle_designer_status(H, "Saved on the sheet.")
		if (export)
			sheet.draught_export(H, D.name)
	qdel(D)

// Raw string: no DM interpolation inside, and never a double quote followed
// by a closing brace. Plain ES5 for the embedded browser. One @@DATA@@.
/proc/vehicle_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Vehicle sheet</title><style>
html,body{height:100%}
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:0;overflow:hidden}
#wrap{display:flex;align-items:flex-start;padding:6px 8px 0 8px}
#plan{flex:0 0 334px;width:334px;margin-right:10px}
#side{flex:0 0 292px;width:292px;margin-right:10px}
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
#ends{display:flex;margin-bottom:3px}
#ends .lbl{flex:1 1 0}
#ends .lbl:first-child{text-align:left}
#ends .lbl:last-child{text-align:right}
#board{display:flex;justify-content:center;margin:0 0 3px 0}
#gw{position:relative}
#g{position:absolute;top:0;background:#16120e;border:2px solid #0f0c09}
.sl{position:absolute;width:26px;height:26px;border:1px solid #b48c4d;background:#211c16;overflow:hidden;cursor:pointer;text-align:center;line-height:26px;font-weight:bold;color:#ffd985;font-size:12px}
.sl img{position:absolute;left:-3px;top:-3px;width:32px;height:32px}
.sl.slot{border:1px dashed #ffd985;color:#b48c4d;font-weight:normal;font-size:15px}
.sl.slot{background:#1b1713}
.sl.slot img{opacity:0.2}
.sl.loose{border:1px dashed #c9a52e;background:#373016}
.sl:hover{border-color:#fff6dc}
.t{position:absolute;box-sizing:border-box;border:1px solid #14100c;cursor:pointer;overflow:hidden;background-size:100% 100%;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}
.t.none{background:#1b1713;border:1px dashed #5a4a36}
.t.none i{position:absolute;left:0;right:0;top:50%;margin-top:-7px;text-align:center;font-style:normal;font-size:10px;color:#6f5d45}
.t:hover{border-color:#ffd985}
.t .p{position:absolute;left:0;top:0;width:100%;height:100%}
.t .pl{position:absolute;left:50%;top:50%;width:26px;height:26px;margin:-14px 0 0 -14px;line-height:26px;font-size:17px}
.t .k{position:absolute;font-size:10px;font-weight:bold;line-height:13px;width:13px;height:13px;text-align:center;background:#211c16;color:#ffd985;border:1px solid #806040}
.t .m{position:absolute;width:24px;height:24px;border:1px solid #b48c4d;background:#211c16;overflow:hidden;text-align:center;line-height:24px;font-weight:bold;color:#ffd985;font-size:12px}
.t .m img{position:absolute;left:-4px;top:-4px;width:32px;height:32px}
.t .m.loose{border:1px dashed #c9a52e;background:#373016}
.t .cn{position:absolute;width:12px;height:12px;border:0 solid #ffd985}
.t .ring{position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none}

/* Figures */
#stats{min-height:96px;line-height:1.4}
.fg{display:flex;margin:6px 0 5px 0}
.fg div{flex:1 1 0;background:#262019;border:1px solid #54432f;padding:3px 0;text-align:center;margin-right:4px}
.fg div:last-child{margin-right:0}
.fg b{display:block;font-size:15px;color:#ffd985}
.fg span{font-size:10px;color:#bfae96}
.bar{position:relative;height:8px;background:#1d1916;border:1px solid #54432f;margin-bottom:5px}
.bar i{position:absolute;left:0;top:0;bottom:0;background:#6caa68}
.bar i.warn{background:#c9a52e}
.bar i.bad{background:#c77a39}
.bar u{position:absolute;top:-2px;bottom:-2px;width:2px;background:#e9dfc8}
#st{flex:1 1 auto;min-width:0;color:#ffd985;margin-left:9px;font-size:11px;line-height:1.25}

/* Palette */
.ph{color:#bfae96;font-size:11px;margin:5px 0 2px 0}
.pal{display:flex;flex-wrap:wrap}
.pal button{display:flex;align-items:center;text-align:left;height:30px;line-height:11px;padding:1px 4px 1px 3px;margin:0 3px 3px 0;overflow:hidden;box-sizing:border-box}
.pal button .ic{flex:none;width:24px;height:24px;margin-right:5px;text-align:center}
.pal button .ic .chip{margin-top:2px}
.pal button .nm{flex:1 1 auto;min-width:0}
#pf button{width:94px}
#pm button{width:143px}
#pp button{width:143px}

/* Part and Checks */
#part{height:170px;overflow:auto;line-height:1.35;box-sizing:border-box}
.pn{font-size:13px;font-weight:bold;margin-bottom:4px;display:flex;align-items:center}
.pn .ic{flex:none;margin-right:7px}
.pn .ic:empty{display:none}
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
<div class='sec'><h2>Plan<span id='dims'></span></h2><div class='in'>
<div id='ends'><div class='lbl'>left</div><div class='lbl'>front</div><div class='lbl'>right</div></div>
<div id='board'><div id='gw'><div id='g'></div></div></div>
<div class='lbl'>back</div>
</div></div>
<div class='sec'><h2>Figures<span id='figk'></span></h2><div class='in'><div id='stats'><span class='hint'>Reckoning...</span></div></div></div>
</div>

<div id='side'>
<div class='row'><label for='nm'>Name</label><input id='nm' maxlength='40' style='flex:1 1 auto;min-width:0' onchange='changed()' onkeyup='changed()'></div>
<div class='row'><label for='ax'>Axis</label><select id='ax' style='flex:1 1 auto;min-width:0' onchange='setAxis(this.value)'></select></div>
<div class='row'><label>Size</label><span id='szl'><select id='sw' onchange='setSize(+this.value,L)'></select> wide &nbsp;<select id='sl' onchange='setSize(W,+this.value)'></select> long</span><span id='szp' style='display:none'><select id='sp' onchange='setPlaneSize(this.value)'></select> tiles</span></div>
<div class='row'><label for='eng'>Engine</label><select id='eng' style='flex:1 1 auto;min-width:0;margin-right:5px' onchange='setEngine(this.value)'></select><input id='cc' type='number' style='flex:0 0 62px;width:62px' onchange='setCc(this.value)'>&nbsp;cc</div>
<div class='hint' id='engh' style='margin:-2px 0 0 50px'></div>
<div class='ph'>Frames</div><div class='pal' id='pf'></div>
<div class='ph'>Wheels and tracks <span class='hint'>- fitted on the four corner frames</span></div><div class='pal' id='pm'></div>
<div class='ph'>Parts <span class='hint'>- one stands on a frame</span></div><div class='pal' id='pp'></div>
<div class='row' style='margin-top:4px'><button onclick='undo()' style='margin-right:8px'>Undo</button><span class='hint'>Start from&nbsp;</span><select id='ex' style='flex:1 1 auto;min-width:0;margin-right:4px'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>
<div class='row'><button class='go' onclick='send(1)'>Save to the sheet</button><span id='st'></span></div>
<div class='row' style='margin-bottom:0'><button class='cd' onclick='exportCode()' title='Save the drawing on the sheet and show its design code to copy'>Export code</button><button class='cd' onclick='importCode()' title='Paste a design code; it replaces what is drawn on this sheet'>Import code</button></div>
<div class='hint' style='margin-top:7px'>Click a tile to draw on it with the picked tool. Right-click takes its part off, then its wheel or track. The boxes beside the plan are where the corner frames' wheels or tracks run.</div>
</div>

<div id='info'>
<div class='sec'><h2>Part</h2><div class='in' id='part'></div></div>
<div class='sec' style='margin-bottom:0'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div>
</div>

</div><script>
var DATA=@@DATA@@;
var REF=DATA.REF,AXES=DATA.AXES,FRAMES=DATA.FRAMES,MOVERS=DATA.MOVERS,PARTS=DATA.PARTS,ENGINES=DATA.ENGINES,MIN=DATA.MIN,MAX=DATA.MAX,PMAX=DATA.PLANEMAX||DATA.MAX,EXAMPLES=DATA.EXAMPLES||[],PICS=DATA.PICS||[],HELP=DATA.HELP||{};
var FRAMECOL={s:'#56616b',w:'#7a5230',a:'#8a99a6'};
var AX='car',EN='',CC=0,W=2,L=3,cells={},cur='f:s',hist=[],timer=null,lastSent=0,T=64;
var CHK=[],lit=-1,pin=-1,peek=null;
var LEVEL={error:['Fix','#ff6f3c'],warning:['Warning','#ffd23f'],note:['Note','#fff6dc']};
function $(i){return document.getElementById(i);}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;');}
function key(c,r){return c+','+r;}
function row(list,k){for(var i=0;i<list.length;i++)if(list[i][0]==k)return list[i];return null;}
function axis(){return row(AXES,AX)||AXES[0];}
function engine(){return row(ENGINES,EN)||ENGINES[0];}
function plane(){return AX=='plane';}
function corner(c,r){return (c==1||c==W)&&(r==1||r==L);}
function several(n,one){return n+' '+one+(n==1?'':'s');}
function cap(s){s=s+'';return s.charAt(0).toUpperCase()+s.substring(1);}

// ---- Pictures ----
// A thing is 'kind:key': f frame, m mover, p part, x the eraser, a axis, e engine.
var PICNAME={f:'frame_',m:'mover_',p:'part_'};
function hasPic(n){for(var i=0;i<PICS.length;i++)if(PICS[i]==n)return true;return false;}
function picSrc(kind,k){var n=PICNAME[kind]?PICNAME[kind]+k:null;return n&&hasPic(n)?'vehd_'+n+'.png':null;}
function noPic(i){var s=document.createElement('span');s.className=i.getAttribute('data-c')||'chip';s.innerHTML=i.alt;i.parentNode.replaceChild(s,i);}
function pic(kind,k,n,cls){if(kind=='a'||kind=='e')return '';var s=picSrc(kind,k),letter=kind=='x'?'&#215;':esc(k.charAt(0).toUpperCase());
if(s)return '<img class="pic'+(cls?' '+cls:'')+'" width="'+n+'" height="'+n+'" src="'+s+'" alt="'+esc(k)+'" data-c="'+(cls?'chip '+cls:'chip')+'" onerror="noPic(this)">';
if(kind=='f')return '<span class="chip'+(cls?' '+cls:'')+'" style="background:'+(FRAMECOL[k]||'#56616b')+';color:#fff">'+letter+'</span>';
return '<span class="chip'+(cls?' '+cls:'')+'">'+letter+'</span>';}
function nameOf(kind,k){var r;
if(kind=='x')return 'eraser';
if(kind=='a'){r=row(AXES,k);return r?r[1]:k;}
if(kind=='e'){r=row(ENGINES,k);return r?r[1]:k;}
if(kind=='f'){r=row(FRAMES,k);return r?r[1]:k;}
if(kind=='m'){r=row(MOVERS,k);return r?r[1]:k;}
if(k=='E')return CC+'cc '+engine()[1];
if(k=='D'&&plane())return 'pilot\'s seat';
r=row(PARTS,k);return r?r[1]:k;}
// The kind of a bare key, as a check names it.
function kindOf(k){if(k=='x')return 'x';if(row(FRAMES,k))return 'f';if(row(MOVERS,k))return 'm';if(row(PARTS,k))return 'p';if(row(AXES,k))return 'a';if(row(ENGINES,k))return 'e';return 'p';}

// ---- The sheet ----
function sizeOk(w,l){if(plane())return (w==3&&l>=3&&l<=PMAX)||(w==5&&l>=4&&l<=PMAX);return w>=MIN&&w<=MAX&&l>=MIN&&l<=MAX;}
function firstFrame(){return axis()[2][0];}
function frameOk(f){var a=axis()[2];for(var i=0;i<a.length;i++)if(a[i]==f)return true;return false;}
function load(sheet){$('nm').value=sheet[0];AX=sheet[1];EN=sheet[2];CC=+sheet[3];W=+sheet[4];L=+sheet[5];cells={};var r,c,i,t;
for(r=1;r<=L;r++)for(c=1;c<=W;c++)cells[key(c,r)]=['','',''];
for(i=0;i<sheet[6].length;i++){t=sheet[6][i];cells[key(t[0],t[1])]=[t[2]||'',t[3]||'',t[4]||''];}
if(cur.charAt(0)=='f'&&!frameOk(cur.substring(2)))cur='f:'+firstFrame();}
function snap(){var o={},k;for(k in cells)o[k]=cells[k].slice();return [AX,EN,CC,W,L,o];}
function push(){hist.push(snap());if(hist.length>50)hist.shift();}
function undo(){if(!hist.length){status('Nothing to undo.');return;}var h=hist.pop();AX=h[0];EN=h[1];CC=h[2];W=h[3];L=h[4];cells=h[5];if(cur.charAt(0)=='f'&&!frameOk(cur.substring(2)))cur='f:'+firstFrame();refresh();changed();}
function resize(w,l){var old=cells,r,c,o;cells={};W=w;L=l;for(r=1;r<=L;r++)for(c=1;c<=W;c++){o=old[key(c,r)];cells[key(c,r)]=o?o:[firstFrame(),'',''];}}
function setSize(w,l){if(!sizeOk(w,l)||(w==W&&l==L)){controls();return;}push();resize(w,l);refresh();changed();}
function setPlaneSize(v){var p=v.split('x');setSize(+p[0],+p[1]);}
function setAxis(a){if(a==AX||!row(AXES,a))return;push();var was=plane(),k,v;AX=a;
if(plane()){resize(3,Math.min(Math.max(L,3),PMAX));for(k in cells)if(cells[k][0])cells[k][0]='a';}
else{if(!sizeOk(W,L))resize(Math.min(Math.max(W,MIN),MAX),Math.min(Math.max(L,MIN),MAX));for(k in cells){v=cells[k];if(v[0]&&!frameOk(v[0]))v[0]=was&&v[0]=='a'?'s':firstFrame();}}
if(cur.charAt(0)=='f'&&!frameOk(cur.substring(2)))cur='f:'+firstFrame();
refresh();changed();}
function clampCc(n){var e=engine();n=Math.round(+n);if(isNaN(n))n=CC||e[2];return Math.min(Math.max(n,e[2]),e[3]);}
function setEngine(k){if(k==EN||!row(ENGINES,k))return;push();EN=k;CC=clampCc(CC);refresh();changed();}
function setCc(v){var n=clampCc(v);if(n==CC){$('cc').value=CC;return;}push();CC=n;refresh();changed();}
function tool(t){cur=t;marks();part();}
function apply(c,r,right){var v=cells[key(c,r)],kind=cur.charAt(0),k=cur.substring(2),b=v.join('|');push();status('');
if(right){if(v[2])v[2]='';else v[1]='';}
else if(kind=='x'){v[0]='';v[1]='';v[2]='';}
else if(kind=='f'){v[0]=k;}
else if(!v[0]){hist.pop();status('Lay a frame on the tile first: a '+nameOf(kind,k)+' needs one under it.');return;}
else if(kind=='m'){v[1]=k;if(!corner(c,r))status('Only the four corner frames\' wheels and tracks are fitted.');}
else{v[2]=k;}
if(v.join('|')==b){hist.pop();return;}
draw();changed();}
function loadExample(){var i=$('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);refresh();changed();}

// ---- Drawing ----
function edge(c){return c==1||c==W;}
function tile(c,r){var v=cells[key(c,r)],x=(c-1)*T,y=(r-1)*T,cn=corner(c,r),lf=c==1,tp=r==1,st='left:'+x+'px;top:'+y+'px;width:'+T+'px;height:'+T+'px;',h='',src,what=[],mp='bottom:1px;left:1px;',kp='top:1px;'+(lf&&tp?'right:1px;':'left:1px;');
if(v[0]){src=picSrc('f',v[0]);st+='background-color:'+(FRAMECOL[v[0]]||'#56616b')+';';if(src)st+='background-image:url('+src+');';what.push(nameOf('f',v[0]));}
else h+='<i>no frame</i>';
if(v[2]){src=picSrc('p',v[2]);h+=src?'<img class="pic p" src="'+src+'" alt="'+esc(v[2])+'" data-c="chip pl" onerror="noPic(this)">':'<span class="chip pl">'+esc(v[2])+'</span>';
h+='<span class="k" style="'+kp+'">'+esc(v[2])+'</span>';what.push(nameOf('p',v[2]));}
if(v[1]){if(!edge(c)){src=picSrc('m',v[1]);h+='<span class="m loose" style="'+mp+'">'+(src?'<img class="pic" src="'+src+'" alt="'+esc(v[1])+'" onerror="this.parentNode.innerHTML=this.alt">':esc(v[1]))+'</span>';}what.push(nameOf('m',v[1])+(cn?'':' (not on a corner: left out)'));}
else if(cn&&v[0])what.push('corner: needs a wheel or track');
if(cn)h+='<span class="cn" style="'+(tp?'top:0;border-top-width:3px;':'bottom:0;border-bottom-width:3px;')+(lf?'left:0;border-left-width:3px;':'right:0;border-right-width:3px;')+'"></span>';
h+='<span class="ring"></span>';
return '<div class="t'+(v[0]?'':' none')+'" id="c_'+c+'_'+r+'" style="'+st+'" title="'+esc(cap(what.join(', ')||'empty tile'))+'" onclick="apply('+c+','+r+',0)" oncontextmenu="apply('+c+','+r+',1);return false;">'+h+'</div>';}
// A wheel or track of the left or right column, beside the plan.
function slot(c,r){var v=cells[key(c,r)],cn=corner(c,r),src,k=v[1]||'W',y=(r-1)*T+2+(r==1?4:(r==L?T-32:Math.round((T-28)/2))),t;
if(!v[1]&&!cn)return '';src=picSrc('m',k);
t=v[1]?cap(nameOf('m',v[1]))+(cn?'':' (not on a corner: left out)'):'A wheel or track goes here: pick one and click';
return '<span class="sl'+(v[1]?(cn?'':' loose'):' slot')+'" id="m_'+c+'_'+r+'" style="top:'+y+'px;'+(c==1?'left:0':'right:0')+'" title="'+esc(t)+'" onclick="slotClick('+c+','+r+')" oncontextmenu="slotClear('+c+','+r+');return false;">'+(src?'<img class="pic" src="'+src+'" alt="'+(v[1]?esc(k):'+')+'" onerror="this.parentNode.innerHTML=this.alt">':(v[1]?esc(k):'+'))+'</span>';}
function slotClick(c,r){if(cur.charAt(0)=='m'||cur.charAt(0)=='x'){if(cur.charAt(0)=='x')slotClear(c,r);else apply(c,r,0);}else status('Pick a wheel or a track, then click here.');}
function slotClear(c,r){var v=cells[key(c,r)];if(!v[1])return;push();v[1]='';draw();changed();}
function draw(){var g=$('g'),gw=$('gw'),h='',s='',r,c,G=30;T=(W<=4&&L<=5)?64:48;
gw.style.width=(W*T+4+2*G)+'px';gw.style.height=(L*T+4)+'px';g.style.left=G+'px';
g.style.width=(W*T)+'px';g.style.height=(L*T)+'px';
for(r=1;r<=L;r++)for(c=1;c<=W;c++){h+=tile(c,r);if(edge(c))s+=slot(c,r);}g.innerHTML=h;
var sl=$('sls');if(!sl){sl=document.createElement('div');sl.id='sls';gw.appendChild(sl);}sl.innerHTML=s;
$('dims').innerHTML=W+' wide, '+L+' long';light();}
function opts(sel,list,val){var h='',i;for(i=0;i<list.length;i++)h+='<option value="'+esc(list[i][0])+'"'+(list[i][0]==val?' selected':'')+'>'+esc(list[i][1])+'</option>';sel.innerHTML=h;sel.value=val;}
function controls(){var i,a=[],e=engine(),p;
opts($('ax'),AXES,AX);opts($('eng'),ENGINES,EN);
$('szl').style.display=plane()?'none':'';$('szp').style.display=plane()?'':'none';
if(plane()){for(i=3;i<=PMAX;i++)a.push(['3x'+i,'3 wide, '+i+' long']);for(i=4;i<=PMAX;i++)a.push(['5x'+i,'5 wide, '+i+' long (twin)']);opts($('sp'),a,W+'x'+L);}
else{for(i=MIN;i<=MAX;i++)a.push([i,i]);opts($('sw'),a,W);opts($('sl'),a,L);}
$('cc').value=CC;$('cc').min=e[2];$('cc').max=e[3];p=Math.round(e[5]*CC/1000);
$('engh').innerHTML=e[2]+' to '+e[3]+' cc &middot; '+p+' power, moves '+(p*2);
palette();}
function pname(kind,k){var r=kind=='p'&&k=='E'?row(PARTS,k):null;return r?r[1]:nameOf(kind,k);}
function pbtn(kind,k){var id=kind+':'+k;return '<button id="t_'+id+'" onclick="tool(\''+id+'\')"><span class="ic">'+pic(kind,k,24)+'</span><span class="nm">'+esc(cap(pname(kind,k)).replace(/ vehicle frame| \(\d+u\)/,''))+'</span></button>';}
function palette(){var h='',i,a=axis()[2];for(i=0;i<a.length;i++)h+=pbtn('f',a[i]);h+=pbtn('x','x');$('pf').innerHTML=h;
h='';for(i=0;i<MOVERS.length;i++)h+=pbtn('m',MOVERS[i][0]);$('pm').innerHTML=h;
h='';for(i=0;i<PARTS.length;i++)h+=pbtn('p',PARTS[i][0]);$('pp').innerHTML=h;marks();}
function marks(){var b=document.getElementsByTagName('button'),i;for(i=0;i<b.length;i++)if(b[i].id.indexOf('t_')==0)b[i].className=b[i].id=='t_'+cur?'on':'';}
function refresh(){controls();draw();part();}

// ---- Talking to the server ----
function code(){var nm=$('nm').value.replace(/[\/;,]/g,' ').replace(/^\s+|\s+$/g,'').replace(/ /g,'_'),t=[],r,c,v;if(!nm)nm='vehicle';
for(r=1;r<=L;r++)for(c=1;c<=W;c++){v=cells[key(c,r)];t.push(c+','+r+','+(v[0]||'-')+','+(v[1]||'-')+','+(v[2]||'-'));}
return 'C13CAR/1/'+nm+'/'+AX+'/'+EN+'/'+CC+'/'+W+'/'+L+'/'+t.join(';');}
// Export saves like Save and then shows the code; Import asks for one.
function exportCode(){send('export');}
function importCode(){if(timer){clearTimeout(timer);timer=null;}location.href='byond://?src='+REF+';car=import';}
function send(save){if(timer){clearTimeout(timer);timer=null;}lastSent=new Date().getTime();if(save)status('Saving...');
location.href='byond://?src='+REF+';car='+(save=='export'?'export':save?'save':'preview')+';code='+encodeURIComponent(code())+';name='+encodeURIComponent($('nm').value);}
// The server answers one summary per 0.3 s: wait out the gap, so the last
// change is never the one it skips.
function changed(){if(timer)clearTimeout(timer);var wait=Math.max(300,450-(new Date().getTime()-lastSent));timer=setTimeout(function(){timer=null;send(0);},wait);}
function status(t){$('st').innerHTML=t;}
function carStatus(t){status(esc(t));}
// The summary's lines become figures; its findings are the Checks panel's.
function carStats(t){t=(t+'').replace(/(<br>)?<span class=.(warning|notice).>.*?<\/span>/g,'');
var m=/weighs (\d+) empty and (\d+) with a crew of (\d+); it can move (\d+) at most/.exec(t),k=/Building it takes (.*?)\. It is drawn for a (.*?)\./.exec(t),h=/^<b>.*?<\/b>: (an? .*? on an? [^,<]*)/.exec(t),o,top,cls;
if(!m||!k){$('stats').innerHTML=t;$('figk').innerHTML='';return;}
top=Math.max(+m[2],+m[4],1)*1.15;cls=+m[1]>+m[4]?'bad':(+m[2]>+m[4]?'warn':'');
o='<div class="fg"><div><b>'+m[1]+'</b><span>weight empty</span></div><div><b>'+m[2]+'</b><span>with crew of '+m[3]+'</span></div><div><b>'+m[4]+'</b><span>can move</span></div></div>';
o+='<div class="bar" title="Its weight with a full crew against the most it can move"><i class="'+cls+'" style="width:'+Math.min(100,Math.round(+m[2]*100/top))+'%"></i><u style="left:'+Math.round(+m[4]*100/top)+'%"></u></div>';
o+='<div><span class="hint">Cost</span> &nbsp;<b>'+k[1]+'</b></div><div><span class="hint">Engine</span> &nbsp;'+k[2]+'</div>';
$('stats').innerHTML=o;$('figk').innerHTML=h?h[1].replace(/ tiles wide and /,' x ').replace(/ long on /,' on '):'';}

// ---- The Part and Checks panels ----
function finding(){var i=lit>=0?lit:pin;return i>=0&&CHK[i]?CHK[i]:null;}
function part(){var f=finding(),t,kind,k,H,R=[['what','What'],['use','Use'],['how','How']],i,why,h;
if(f&&f.part){k=f.part;kind=kindOf(k);why='named by the check';}
else if(peek){kind=peek.charAt(0);k=peek.substring(2);why=peek==cur?'picked to draw with':(peek.charAt(1)=='!'?'on the plan':(kind=='a'||kind=='e'?'chosen above':'click to pick it'));}
else{kind=cur.charAt(0);k=cur.substring(2);why='picked to draw with';}
if(kind=='x')k='x';H=HELP[k];
h='<div class="pn"><span class="ic">'+pic(kind,k,32)+'</span><span class="w">'+esc(cap(nameOf(kind,k)))+'<span class="s">'+why+'</span></span></div>';
if(H)for(i=0;i<R.length;i++)if(H[R[i][0]])h+='<div class="pr"><i>'+R[i][1]+'</i><span>'+esc(H[R[i][0]])+'</span></div>';
$('part').innerHTML=h;}
function light(){var g=$('g'),f=finding(),d=g.getElementsByTagName('div'),i,p,td,col,s;
for(i=0;i<d.length;i++){s=d[i].lastChild;if(s&&s.className=='ring'){s.style.outline='';s.style.boxShadow='';}}
if(!f)return;col=LEVEL[f.level][1];
for(i=0;i<f.cells.length;i++){p=(f.cells[i]+'').split(',');td=$('c_'+p[0]+'_'+p[1]);if(!td||!td.lastChild)continue;s=td.lastChild;
s.style.outline='3px solid '+col;s.style.outlineOffset='-4px';s.style.boxShadow='inset 0 0 0 5px rgba(20,12,6,0.75)';}}
function where(i){return i==pin?'&#9679; ringed on the plan':'&#9675; '+several(CHK[i].cells.length,'tile')+' on the plan';}
function mark(){var i,b,f,w;for(i=0;i<CHK.length;i++){b=$('ck_'+i);if(!b)continue;f=CHK[i];
b.className='ck '+f.level+(f.cells.length||f.part?' has':'')+(i==pin?' pin':'')+(i==lit?' lit':'');w=$('wh_'+i);if(w)w.innerHTML=where(i);}}
function show(i){lit=i;mark();part();light();}
function keep(i){pin=pin==i?-1:i;mark();part();light();}
function hook(i){var b=$('ck_'+i);b.onmouseenter=b.onfocus=function(){show(i);};b.onmouseleave=b.onblur=function(){if(lit==i)show(-1);};b.onclick=function(){keep(i);};}
function carChecks(s){var A=null,i,f,was=CHK[pin]?CHK[pin].text:null,n=[0,0,0],h='',p=[];
try{A=JSON.parse(s);}catch(e){A=null;}
if(!A){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e2){}try{A=JSON.parse(s);}catch(e3){A=[];}}
if(!A||!A.length)A=[];
CHK=[];lit=-1;pin=-1;for(i=0;i<A.length;i++){f={level:LEVEL[A[i].level]?A[i].level:'note',text:A[i].text||'',cells:A[i].cells||[],part:A[i].part||''};CHK.push(f);if(was!==null&&f.text==was)pin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class="vd bad"><b>Not ready to build.</b> '+several(n[0],'thing')+' to fix first.</div>';
else h+='<div class="vd"><b>Ready to build.</b> As drawn it can be built by hand and assembled.'+(n[1]?'<div class="also">'+several(n[1],'warning')+' below will not stop the build, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<CHK.length;i++){f=CHK[i];h+='<div tabindex="0" id="ck_'+i+'" class="ck"'+(f.cells.length?' title="Click to keep it ringed on the plan; click again to let go"':'')+'><span class="tag">'+LEVEL[f.level][0]+'</span><span class="tx">'+esc(f.text)+(f.cells.length?'<span class="wh" id="wh_'+i+'"></span>':'')+'</span></div>';}
$('checks').innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(several(n[1],'warning'));if(n[2])p.push(several(n[2],'note'));$('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<CHK.length;i++)hook(i);
mark();part();light();}
// Pointing at a tool, a tile or the axis or engine shows what it is.
document.onmouseover=function(e){e=e||window.event;var b=e.target||e.srcElement,k=null,p,v;
while(b&&b!=document.body){if(b.id){
if(b.id.indexOf('t_')==0){k=b.id.substring(2);break;}
if(b.id.indexOf('m_')==0){p=b.id.split('_');v=cells[key(p[1],p[2])];k=v&&v[1]?'m!'+v[1]:'m:W';break;}
if(b.id.indexOf('c_')==0){p=b.id.split('_');v=cells[key(p[1],p[2])];if(v)k=v[2]?'p!'+v[2]:(v[1]?'m!'+v[1]:(v[0]?'f!'+v[0]:null));break;}
if(b.id=='ax'){k='a:'+AX;break;}
if(b.id=='eng'||b.id=='cc'){k='e:'+EN;break;}}
b=b.parentNode;}
if(k!=peek){peek=k;part();}};
// The panels fill the window's height, whatever it is.
function fit(){var h=(window.innerHeight||document.documentElement.clientHeight||640),c=$('checks'),top=c.getBoundingClientRect().top;c.style.height=Math.max(120,h-top-9)+'px';}
window.onresize=fit;
(function(){var e=$('ex'),j,o;for(j=0;j<EXAMPLES.length;j++){o=document.createElement('option');o.value=j;o.innerHTML=esc(EXAMPLES[j][0]);e.appendChild(o);}
cur='x:x';load(DATA.START);cur='f:'+firstFrame();refresh();fit();changed();})();
</script></body></html>"}

#undef VEHICLE_DESIGNER_WINDOW
#undef VEHICLE_DESIGNER_PREVIEW_GAP
