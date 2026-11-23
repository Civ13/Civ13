// ============================================================
// The airship designer (docs/airship-sheets.md)
// ------------------------------------------------------------
// Hold a blank ship's draught (or an airship sheet) and a pen or pencil and
// choose "Draw on the sheet": a window shows the airship's deck plan, bow to
// the top and her port side on the left. The size, the engine and the crew
// are picked beside the plan; decks, gas cells and the parts that stand on
// the deck are picked from a palette and clicked or dragged onto it. A tile
// with no deck is open air, and the eraser clears a tile back to it.
//
// Like the vehicle designer (craft/vehicle_designer.dm), every change goes to
// the server, which reads it as a design code and answers with the sheet's
// own summary and checks, so the window never disagrees with the sheet. Save
// keeps the drawing on the sheet. The Part panel says what the picked (or
// pointed at) thing is, what it is for and how to use it (DATA.HELP); the
// Checks panel lists the findings and lights their tiles.
//
// A tile shows three layers: its deck as the tile's own picture, the part
// standing on it over that, and the gas cell hung over it in a small box in
// the tile's corner, so that the cell hides neither. The pictures are the
// sprites the built things have in the game: PNGs cut from the game's DMIs by
// scripts/build_air_designer_icons.py and sent with browse_rsc. A key with no
// picture shows as its letter.
//
// The page is air_designer_page() with one block of data at @@DATA@@:
//   REF       this designer's ref, for the window's links
//   DECKS     list(key, name, weight of a tile)
//   CELLS     list(key, name, what it holds up full)
//   PARTS     list(key, name)
//   ENGINES   list(key, name, min cc, max cc, steel per 1000 cc, power per 1000 cc)
//   MIN, MAX  the sizes a sheet may be, each way
//   CREW_MAX  the largest crew a sheet may be drawn for
//   DECK_MAX  the most tiles of deck an airship may have
//   START     the sheet: list(name, engine, cc, crew, width, length,
//             list(list(col, row, deck, cell, part), ...)) with "" for none;
//             only tiles with deck are listed, the rest are open air
//   EXAMPLES  ready-made sheets in the same form
//   PICS      the pictures the server sends: "deck_p", "cell_c", "part_W"
//             ... each as "aird_<name>.png" (air_designer_sprites())
//   HELP      the part book: key -> list(what, use, how)
// The window sends ?src=REF;air=preview|save|export|import;code=<C13AIR code>;name=<name>
// and the server answers with airStats(summary html), airChecks(json of
// the report's data()) and airStatus(text).
// ============================================================

#define AIR_DESIGNER_WINDOW "air_designer"
#define AIR_DESIGNER_PREVIEW_GAP 3 // deciseconds between summaries per drawer

// mob -> /datum/air_designer. A proc with a static list, not a global: the
// world's global init proc has no room for more.
/proc/air_designers()
	var/static/list/open
	if (!open)
		open = list()
	return open

// Picture name -> its picture, sent to the window as "aird_<name>.png". The
// name is the key's table and the key: "deck_<key>", "cell_<key>" or
// "part_<key>", as the vehicle designer names its own, because Windows serves
// the browser's cache without case. Cut from the game's DMIs by
// scripts/build_air_designer_icons.py.
/proc/air_designer_sprites()
	var/static/list/table
	if (!table)
		table = list(
		"deck_p" = 'icons/air_designer/deck_p.png',
		"deck_a" = 'icons/air_designer/deck_a.png',
		"deck_s" = 'icons/air_designer/deck_s.png',
		"cell_c" = 'icons/air_designer/cell_c.png',
		"cell_r" = 'icons/air_designer/cell_r.png',
		"cell_k" = 'icons/air_designer/cell_k.png',
		"part_W" = 'icons/air_designer/part_W.png',
		"part_E" = 'icons/air_designer/part_E.png',
		"part_Y" = 'icons/air_designer/part_Y.png',
		"part_M" = 'icons/air_designer/part_M.png',
		"part_T" = 'icons/air_designer/part_T.png',
		"part_X" = 'icons/air_designer/part_X.png',
		"part_B" = 'icons/air_designer/part_B.png',
		)
	return table

/datum/air_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/last_preview = null

/datum/air_designer/Destroy()
	var/list/open = air_designers()
	if (drawer && open[drawer] == src)
		open -= drawer
	drawer = null
	sheet = null
	return ..()

/obj/item/ship_draught/proc/open_air_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	var/list/open = air_designers()
	var/datum/air_designer/old = open[H]
	if (old)
		qdel(old)
	var/datum/air_designer/A = new
	A.drawer = H
	A.sheet = src
	open[H] = A
	var/datum/air_draught/D = air_draught()
	if (!D)
		var/list/examples = air_draught_examples()
		D = examples[1]
		examples -= D
		for (var/datum/E in examples)
			qdel(E)
		D.name = "airship"
	var/list/sprites = air_designer_sprites()
	for (var/key in sprites)
		H << browse_rsc(sprites[key], "aird_[key].png")
	show_browse(H, air_designer_html(A, D), "window=[AIR_DESIGNER_WINDOW];size=1080x690")
	onclose(H, AIR_DESIGNER_WINDOW, A)
	air_designer_stats(H, D)
	qdel(D)

// A sheet for the window: list(name, engine, cc, crew, width, length, tiles).
// Only the tiles with deck are listed.
/proc/air_designer_sheet(datum/air_draught/D)
	var/list/tiles = list()
	for (var/row = 1, row <= D.length, row++)
		for (var/col = 1, col <= D.width, col++)
			var/list/C = D.cell(col, row)
			if (!C[1])
				continue
			tiles += list(list(col, row, C[1], C[2] ? C[2] : "", C[3] ? C[3] : ""))
	return list(D.name, D.engine, D.cc, D.crew, D.width, D.length, tiles)

/proc/air_designer_data(datum/air_designer/A, datum/air_draught/D)
	var/list/decks = list()
	var/list/deck_table = air_draught_decks()
	for (var/key in deck_table)
		var/obj/covers/airship_deck/P = deck_table[key]["path"]
		decks += list(list(key, deck_table[key]["name"], initial(P.air_weight)))
	var/list/cells = list()
	var/list/cell_table = air_draught_cells()
	for (var/key in cell_table)
		var/obj/structure/airship_gas_cell/P = cell_table[key]["path"]
		cells += list(list(key, cell_table[key]["name"], initial(P.max_lift)))
	var/list/parts = list()
	var/list/part_table = air_draught_parts()
	for (var/key in part_table)
		parts += list(list(key, part_table[key]["name"]))
	var/list/engines = list()
	for (var/key in vehicle_draught_engines)
		var/list/E = vehicle_draught_engines[key]
		var/obj/structure/engine/internal/P = E["path"]
		engines += list(list(key, E["name"], E["min"], E["max"], E["steel"], initial(P.maxpower)))
	var/list/examples = list()
	for (var/datum/air_draught/E in air_draught_examples())
		examples += list(air_designer_sheet(E))
		qdel(E)
	var/list/pics = list()
	for (var/key in air_designer_sprites())
		pics += key
	return list(
		"REF" = A ? "\ref[A]" : "",
		"DECKS" = decks,
		"CELLS" = cells,
		"PARTS" = parts,
		"ENGINES" = engines,
		"MIN" = AIR_DRAUGHT_MIN,
		"MAX" = AIR_DRAUGHT_MAX,
		"CREW_MAX" = AIR_DRAUGHT_MAX_DECK,
		"DECK_MAX" = AIR_DRAUGHT_MAX_DECK,
		"START" = air_designer_sheet(D),
		"EXAMPLES" = examples,
		"PICS" = pics,
		"HELP" = design_part_help_for("air_sheet"),
	)

/proc/air_designer_html(datum/air_designer/A, datum/air_draught/D)
	var/list/halves = splittext(air_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(air_designer_data(A, D)) + halves[2]

/proc/air_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[AIR_DESIGNER_WINDOW].browser:airStatus")

/proc/air_designer_stats(mob/user, datum/air_draught/D)
	user << output(list2params(list(D.summary_text())), "[AIR_DESIGNER_WINDOW].browser:airStats")
	var/datum/design_report/R = D.check_design()
	user << output(list2params(list(json_encode(R.data()))), "[AIR_DESIGNER_WINDOW].browser:airChecks")
	qdel(R)

/datum/air_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["air"] || H != drawer || air_designers()[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		air_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	// Import and Export work the same in every designer (naval/draught_kinds.dm).
	if (href_list["air"] == "import")
		sheet.draught_import_in_window(H, AIR_DESIGNER_WINDOW)
		return
	var/export = href_list["air"] == "export"
	var/save = export || href_list["air"] == "save"
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + AIR_DESIGNER_PREVIEW_GAP)
			return
		last_preview = world.time
	var/code = href_list["code"]
	if (!istext(code) || length(code) > DESIGN_CODE_AIR_MAX)
		air_designer_status(H, "The drawing could not be read.")
		return
	var/datum/air_draught/D = air_draught_from_code(code)
	if (!D)
		air_designer_status(H, "The drawing could not be read.")
		return
	D.name = air_draught_clean_name(href_list["name"])
	air_designer_stats(H, D)
	if (save)
		sheet.take_air(D)
		air_designer_status(H, "Saved on the sheet.")
		if (export)
			sheet.draught_export(H, D.name)
	qdel(D)

// Raw string: no DM interpolation inside, and never a double quote followed
// by a closing brace. Plain ES5 for the embedded browser. One @@DATA@@.
/proc/air_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Airship sheet</title><style>
html,body{height:100%}
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:0;overflow:hidden}
#wrap{display:flex;align-items:flex-start;padding:6px 8px 0 8px}
#plan{flex:0 0 420px;width:420px;margin-right:10px}
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
#board{display:flex;justify-content:center;align-items:center;height:392px;margin:0 0 3px 0}
#g{position:relative;background:#1a2530;border:2px solid #0f0c09;-webkit-user-select:none;-ms-user-select:none;user-select:none}
.t{position:absolute;box-sizing:border-box;border:1px solid #14100c;cursor:pointer;overflow:hidden;background-size:100% 100%;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}
.t.none{background:#1a2530;border:1px dashed #33465a}
.t.none i{position:absolute;left:0;right:0;top:50%;margin-top:-7px;text-align:center;font-style:normal;font-size:10px;color:#4f6880}
.t:hover{border-color:#ffd985}
.t .p{position:absolute;left:0;top:0;width:100%;height:100%}
.t .pl{position:absolute;left:50%;top:50%;width:18px;height:18px;margin:-10px 0 0 -10px;line-height:18px;font-size:12px}
.t .gc{position:absolute;top:1px;right:1px;box-sizing:border-box;border:1px solid #b48c4d;background:#211c16;overflow:hidden;text-align:center;font-weight:bold;color:#ffd985}
.t .gc img{position:absolute;left:0;top:0;width:100%;height:100%}
.t .ring{position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none}

/* Figures */
#stats{min-height:112px;line-height:1.4}
.fg{display:flex;margin:6px 0 5px 0}
.fg div{flex:1 1 0;background:#262019;border:1px solid #54432f;padding:3px 0;text-align:center;margin-right:4px}
.fg div:last-child{margin-right:0}
.fg b{display:block;font-size:15px;color:#ffd985}
.fg b.bad{color:#f3a26a}
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
.pal button{display:flex;align-items:center;text-align:left;width:143px;height:30px;line-height:11px;padding:1px 4px 1px 3px;margin:0 3px 3px 0;overflow:hidden;box-sizing:border-box}
.pal button .ic{flex:none;width:24px;height:24px;margin-right:5px;text-align:center}
.pal button .ic .chip{margin-top:2px}
.pal button .nm{flex:1 1 auto;min-width:0}

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
<div class='sec'><h2>Deck plan<span id='dims'></span></h2><div class='in'>
<div id='ends'><div class='lbl'>port</div><div class='lbl'>bow</div><div class='lbl'>starboard</div></div>
<div id='board'><div id='g'></div></div>
<div class='lbl'>stern</div>
</div></div>
<div class='sec'><h2>Figures<span id='figk'></span></h2><div class='in'><div id='stats'><span class='hint'>Reckoning...</span></div></div></div>
</div>

<div id='side'>
<div class='row'><label for='nm'>Name</label><input id='nm' maxlength='40' style='flex:1 1 auto;min-width:0' onchange='changed()' onkeyup='changed()'></div>
<div class='row'><label>Size</label><select id='sw' onchange='setSize(+this.value,L)'></select>&nbsp;wide &nbsp;<select id='sl' onchange='setSize(W,+this.value)'></select>&nbsp;long</div>
<div class='row'><label for='eng'>Engine</label><select id='eng' style='flex:1 1 auto;min-width:0;margin-right:5px' onchange='setEngine(this.value)'></select><input id='cc' type='number' style='flex:0 0 62px;width:62px' onchange='setCc(this.value)'>&nbsp;cc</div>
<div class='hint' id='engh' style='margin:-2px 0 5px 50px'></div>
<div class='row'><label for='crew'>Crew</label><input id='crew' type='number' min='0' style='flex:0 0 52px;width:52px;margin-right:7px' onchange='setCrew(this.value)'><span class='hint' id='crewh'></span></div>
<div class='ph'>Deck <span class='hint'>- a tile without it is open air</span></div><div class='pal' id='pd'></div>
<div class='ph'>Gas cells <span class='hint'>- one hangs over a tile of deck</span></div><div class='pal' id='pg'></div>
<div class='ph'>Parts <span class='hint'>- one stands on a tile of deck</span></div><div class='pal' id='pp'></div>
<div class='row' style='margin-top:4px'><button onclick='undo()' style='margin-right:3px'>Undo</button><button onclick='redo()' style='margin-right:8px'>Redo</button><span class='hint' style='white-space:nowrap'>Start from&nbsp;</span><select id='ex' style='flex:1 1 auto;min-width:0;margin-right:4px'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>
<div class='row'><button class='go' onclick='send(1)'>Save to the sheet</button><span id='st'></span></div>
<div class='row' style='margin-bottom:0'><button class='cd' onclick='exportCode()' title='Save the drawing on the sheet and show its design code to copy'>Export code</button><button class='cd' onclick='importCode()' title='Paste a design code; it replaces what is drawn on this sheet'>Import code</button></div>
<div class='hint' style='margin-top:7px'>Click or drag over tiles to draw with the picked tool. Right-click takes a tile's part off, then its gas cell, then its deck. The small box in a tile's corner is the gas cell hung over it.</div>
</div>

<div id='info'>
<div class='sec'><h2>Part</h2><div class='in' id='part'></div></div>
<div class='sec' style='margin-bottom:0'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div>
</div>

</div><script>
var DATA=@@DATA@@;
var REF=DATA.REF,DECKS=DATA.DECKS,CELLS=DATA.CELLS,PARTS=DATA.PARTS,ENGINES=DATA.ENGINES,MIN=DATA.MIN,MAX=DATA.MAX,CREW_MAX=DATA.CREW_MAX,DECK_MAX=DATA.DECK_MAX,EXAMPLES=DATA.EXAMPLES||[],PICS=DATA.PICS||[],HELP=DATA.HELP||{};
var DECKCOL={p:'#7a5230',a:'#a9b4bd',s:'#56616b'};
var EN='',CC=0,CREW=0,W=3,L=5,cells={},cur='d:p',hist=[],fut=[],timer=null,lastSent=0,T=64;
var CHK=[],lit=-1,pin=-1,peek=null,stroke=false,stroked=false;
var LEVEL={error:['Fix','#ff6f3c'],warning:['Warning','#ffd23f'],note:['Note','#fff6dc']};
function $(i){return document.getElementById(i);}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;');}
function key(c,r){return c+','+r;}
function row(list,k){for(var i=0;i<list.length;i++)if(list[i][0]==k)return list[i];return null;}
function engine(){return row(ENGINES,EN)||ENGINES[0];}
function several(n,one){return n+' '+one+(n==1?'':'s');}
function cap(s){s=s+'';return s.charAt(0).toUpperCase()+s.substring(1);}
function num(n){return Math.round(n*10)/10;}

// ---- Pictures ----
// A thing is 'kind:key': d deck, g gas cell, p part, x the eraser, e engine.
var PICNAME={d:'deck_',g:'cell_',p:'part_'};
function hasPic(n){for(var i=0;i<PICS.length;i++)if(PICS[i]==n)return true;return false;}
function picSrc(kind,k){var n=PICNAME[kind]?PICNAME[kind]+k:null;return n&&hasPic(n)?'aird_'+n+'.png':null;}
function noPic(i){var s=document.createElement('span');s.className=i.getAttribute('data-c')||'chip';s.innerHTML=i.alt;i.parentNode.replaceChild(s,i);}
function pic(kind,k,n,cls){if(kind=='e')return '';var s=picSrc(kind,k),letter=kind=='x'?'&#215;':esc(k.charAt(0).toUpperCase());
if(s)return '<img class="pic'+(cls?' '+cls:'')+'" width="'+n+'" height="'+n+'" src="'+s+'" alt="'+esc(k)+'" data-c="'+(cls?'chip '+cls:'chip')+'" onerror="noPic(this)">';
if(kind=='d')return '<span class="chip'+(cls?' '+cls:'')+'" style="background:'+(DECKCOL[k]||'#56616b')+';color:#fff">'+letter+'</span>';
return '<span class="chip'+(cls?' '+cls:'')+'">'+letter+'</span>';}
function nameOf(kind,k){var r;
if(kind=='x')return 'eraser';
if(kind=='e'){r=row(ENGINES,k);return r?r[1]:k;}
if(kind=='d'){r=row(DECKS,k);return r?r[1]:k;}
if(kind=='g'){r=row(CELLS,k);return r?r[1]:k;}
if(k=='E')return CC+'cc '+engine()[1];
r=row(PARTS,k);return r?r[1]:k;}
// The kind of a bare key, as a check names it.
function kindOf(k){if(k=='x')return 'x';if(row(DECKS,k))return 'd';if(row(CELLS,k))return 'g';if(row(PARTS,k))return 'p';if(row(ENGINES,k))return 'e';return 'p';}

// ---- The sheet ----
function sizeOk(w,l){return w>=MIN&&w<=MAX&&l>=MIN&&l<=MAX&&w==Math.round(w)&&l==Math.round(l);}
function blank(){var r,c;cells={};for(r=1;r<=L;r++)for(c=1;c<=W;c++)cells[key(c,r)]=['','',''];}
function load(sheet){$('nm').value=sheet[0];EN=sheet[1];CC=+sheet[2];CREW=+sheet[3];W=+sheet[4];L=+sheet[5];blank();var i,t;
for(i=0;i<sheet[6].length;i++){t=sheet[6][i];if(cells[key(t[0],t[1])]&&t[2])cells[key(t[0],t[1])]=[t[2],t[3]||'',t[4]||''];}}
function snap(){var o={},k;for(k in cells)o[k]=cells[k].slice();return [EN,CC,CREW,W,L,o];}
function put(h){EN=h[0];CC=h[1];CREW=h[2];W=h[3];L=h[4];cells=h[5];}
function push(s){hist.push(s||snap());if(hist.length>60)hist.shift();fut=[];}
function undo(){if(!hist.length){status('Nothing to undo.');return;}fut.push(snap());put(hist.pop());status('');refresh();changed();}
function redo(){if(!fut.length){status('Nothing to redo.');return;}hist.push(snap());put(fut.pop());status('');refresh();changed();}
// New tiles are open air; the tiles cut off are gone (Undo brings them back).
function resize(w,l){var old=cells,r,c,o;W=w;L=l;cells={};for(r=1;r<=L;r++)for(c=1;c<=W;c++){o=old[key(c,r)];cells[key(c,r)]=o?o:['','',''];}}
function setSize(w,l){if(!sizeOk(w,l)||(w==W&&l==L)){controls();return;}push();resize(w,l);status('');refresh();changed();}
function clampCc(n){var e=engine();n=Math.round(+n);if(isNaN(n))n=CC||e[2];return Math.min(Math.max(n,e[2]),e[3]);}
function setEngine(k){if(k==EN||!row(ENGINES,k))return;push();EN=k;CC=clampCc(CC);refresh();changed();}
function setCc(v){var n=clampCc(v);if(n==CC){$('cc').value=CC;return;}push();CC=n;refresh();changed();}
function setCrew(v){var n=Math.round(+v);if(isNaN(n))n=CREW;n=Math.min(Math.max(n,0),CREW_MAX);if(n==CREW){$('crew').value=CREW;return;}push();CREW=n;controls();changed();}
function tool(t){cur=t;marks();part();}
// Draws on one tile. A drag is one stroke: Undo takes all of it back.
function apply(c,r,right,drag){var v=cells[key(c,r)],kind=cur.charAt(0),k=cur.substring(2),b,before;if(!v)return;b=v.join('|');before=snap();if(!drag)status('');
if(right){if(v[2])v[2]='';else if(v[1])v[1]='';else v[0]='';}
else if(kind=='x'){v[0]='';v[1]='';v[2]='';}
else if(kind=='d'){v[0]=k;}
else if(!v[0]){if(!drag)status('Lay deck on the tile first: a '+nameOf(kind,k)+' needs it under it.');return;}
else if(kind=='g'){v[1]=k;}
else{v[2]=k;}
if(v.join('|')==b)return;
if(!(drag&&stroked))push(before);stroked=true;
draw();changed();}
function down(c,r,e){e=e||window.event;if(e.button==2)return;stroke=true;stroked=false;apply(c,r,0,0);if(e.preventDefault)e.preventDefault();}
function over(c,r,e){e=e||window.event;if(!stroke)return;if(e.buttons!==undefined&&!(e.buttons&1)){stroke=false;return;}apply(c,r,0,1);}
document.onmouseup=function(){stroke=false;};
function loadExample(){var i=$('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);status('');refresh();changed();}
function count(){var n={deck:0,cells:0,engines:0,tanks:0,weight:0,lift:0},k,v,d,g;for(k in cells){v=cells[k];if(!v[0])continue;n.deck++;d=row(DECKS,v[0]);if(d)n.weight+=+d[2];
if(v[1]){n.cells++;g=row(CELLS,v[1]);if(g)n.lift+=+g[2];}if(v[2]=='E')n.engines++;else if(v[2]&&'YMTX'.indexOf(v[2])>=0)n.tanks++;}return n;}

// ---- Drawing ----
function tile(c,r){var v=cells[key(c,r)],x=(c-1)*T,y=(r-1)*T,st='left:'+x+'px;top:'+y+'px;width:'+T+'px;height:'+T+'px;',h='',src,what=[],B=Math.max(13,Math.round(T*0.44));
if(v[0]){src=picSrc('d',v[0]);st+='background-color:'+(DECKCOL[v[0]]||'#56616b')+';';if(src)st+='background-image:url('+src+');';else h+='<span class="chip pl" style="margin-top:'+(T>=48?-10:-9)+'px">'+esc(v[0].toUpperCase())+'</span>';what.push(nameOf('d',v[0]));}
else if(T>=40)h+='<i>air</i>';
if(v[2]){src=picSrc('p',v[2]);h+=src?'<img class="pic p" src="'+src+'" alt="'+esc(v[2])+'" data-c="chip pl" onerror="noPic(this)">':'<span class="chip pl">'+esc(v[2])+'</span>';what.push(nameOf('p',v[2]));}
if(v[1]){src=picSrc('g',v[1]);h+='<span class="gc" style="width:'+B+'px;height:'+B+'px;line-height:'+(B-2)+'px;font-size:'+(B>=20?11:9)+'px">'+(src?'<img class="pic" src="'+src+'" alt="'+esc(v[1].toUpperCase())+'" onerror="this.parentNode.innerHTML=this.alt">':esc(v[1].toUpperCase()))+'</span>';what.push(nameOf('g',v[1])+' over it');}
h+='<span class="ring"></span>';
return '<div class="t'+(v[0]?'':' none')+'" id="c_'+c+'_'+r+'" style="'+st+'" title="'+esc(cap(what.join(', ')||'open air'))+'" onmousedown="down('+c+','+r+',event)" onmouseover="over('+c+','+r+',event)" oncontextmenu="apply('+c+','+r+',1,0);return false;">'+h+'</div>';}
function draw(){var g=$('g'),h='',r,c,m=Math.max(W,L);T=m<=6?64:(m<=8?48:(m<=9?42:(m<=10?38:(m<=11?35:32))));
g.style.width=(W*T)+'px';g.style.height=(L*T)+'px';
for(r=1;r<=L;r++)for(c=1;c<=W;c++)h+=tile(c,r);g.innerHTML=h;
$('dims').innerHTML=W+' wide, '+L+' long';light();}
function opts(sel,list,val){var h='',i;for(i=0;i<list.length;i++)h+='<option value="'+esc(list[i][0])+'"'+(list[i][0]==val?' selected':'')+'>'+esc(list[i][1])+'</option>';sel.innerHTML=h;sel.value=val;}
function controls(){var i,a=[],e=engine(),p;
opts($('eng'),ENGINES,EN);for(i=MIN;i<=MAX;i++)a.push([i,i]);opts($('sw'),a,W);opts($('sl'),a,L);
$('cc').value=CC;$('cc').min=e[2];$('cc').max=e[3];p=Math.round(e[5]*CC/1000);
$('engh').innerHTML=e[2]+' to '+e[3]+' cc &middot; each engine pushes '+p;
$('crew').value=CREW;$('crew').max=CREW_MAX;$('crewh').innerHTML='0 to '+CREW_MAX+' aboard; each weighs 1';
palette();}
function pname(kind,k){var r=kind=='p'&&k=='E'?row(PARTS,k):null;return r?r[1]:nameOf(kind,k);}
function pbtn(kind,k){var id=kind+':'+k,n=kind=='x'?'eraser - open air':pname(kind,k).replace(/^airship helm$/,'helm').replace(/ airship| \(\d+u\)/,'');return '<button id="t_'+id+'" onclick="tool(\''+id+'\')"><span class="ic">'+pic(kind,k,24)+'</span><span class="nm">'+esc(cap(n))+'</span></button>';}
function palette(){var h='',i;for(i=0;i<DECKS.length;i++)h+=pbtn('d',DECKS[i][0]);h+=pbtn('x','x');$('pd').innerHTML=h;
h='';for(i=0;i<CELLS.length;i++)h+=pbtn('g',CELLS[i][0]);$('pg').innerHTML=h;
h='';for(i=0;i<PARTS.length;i++)h+=pbtn('p',PARTS[i][0]);$('pp').innerHTML=h;marks();}
function marks(){var b=document.getElementsByTagName('button'),i;for(i=0;i<b.length;i++)if(b[i].id.indexOf('t_')==0)b[i].className=b[i].id=='t_'+cur?'on':'';}
function refresh(){controls();draw();part();}

// ---- Talking to the server ----
// Only the tiles with deck are written: the rest are open air.
function code(){var nm=$('nm').value.replace(/[\/;,]/g,' ').replace(/^\s+|\s+$/g,'').replace(/ /g,'_'),t=[],r,c,v;if(!nm)nm='airship';
for(r=1;r<=L;r++)for(c=1;c<=W;c++){v=cells[key(c,r)];if(v[0])t.push(c+','+r+','+v[0]+','+(v[1]||'-')+','+(v[2]||'-'));}
return 'C13AIR/1/'+nm+'/'+EN+'/'+CC+'/'+CREW+'/'+W+'/'+L+'/'+t.join(';');}
// Export saves like Save and then shows the code; Import asks for one.
function exportCode(){send('export');}
function importCode(){if(timer){clearTimeout(timer);timer=null;}location.href='byond://?src='+REF+';air=import';}
function send(save){if(timer){clearTimeout(timer);timer=null;}lastSent=new Date().getTime();if(save)status('Saving...');
location.href='byond://?src='+REF+';air='+(save=='export'?'export':save?'save':'preview')+';code='+encodeURIComponent(code())+';name='+encodeURIComponent($('nm').value);}
// The server answers one summary per 0.3 s: wait out the gap, so the last
// change is never the one it skips.
function changed(){if(timer)clearTimeout(timer);var wait=Math.max(300,450-(new Date().getTime()-lastSent));timer=setTimeout(function(){timer=null;send(0);},wait);}
function status(t){$('st').innerHTML=t;}
function airStatus(t){status(esc(t));}
// The summary's lines become figures; its findings are the Checks panel's.
function airStats(t){t=(t+'').replace(/(<br>)?<span class=.(warning|notice).>.*?<\/span>/g,'');
var m=/weighs ([\d.]+) and ([\d.]+) with a crew of (\d+); her gas cells hold up ([\d.]+)/.exec(t),k=/Building her takes (.*?)\. Her engines are drawn as (.*?)s\./.exec(t),d=/an airship of (\d+) tiles? of deck/.exec(t),o,top,cls,n=count(),p,sp;
if(!m||!k){$('stats').innerHTML=t;$('figk').innerHTML='';return;}
top=Math.max(+m[2],+m[4],1)*1.15;cls=+m[1]>+m[4]?'bad':(+m[2]>+m[4]?'warn':'');sp=num(+m[4]-+m[2]);
o='<div class="fg"><div><b>'+m[1]+'</b><span>deck weighs</span></div><div><b>'+m[2]+'</b><span>with crew of '+m[3]+'</span></div><div><b>'+m[4]+'</b><span>cells hold up</span></div><div><b'+(sp<0?' class="bad"':'')+'>'+sp+'</b><span>lift to spare</span></div></div>';
o+='<div class="bar" title="Her weight with her crew against what her gas cells hold up full of hydrogen"><i class="'+cls+'" style="width:'+Math.min(100,Math.round(+m[2]*100/top))+'%"></i><u style="left:'+Math.round(+m[4]*100/top)+'%"></u></div>';
o+='<div><span class="hint">Cost</span> &nbsp;<b>'+(k[1]||'nothing')+'</b></div>';
p=Math.round(engine()[5]*CC/1000)*n.engines;
o+='<div><span class="hint">Engines</span> &nbsp;'+(n.engines?n.engines+' x '+k[2]+', '+several(n.tanks,'tank')+' &middot; push '+p+' <span class="hint">(half ahead '+n.deck+', full '+(n.deck*2)+')</span>':'none: slow ahead only')+'</div>';
$('stats').innerHTML=o;$('figk').innerHTML=d?several(+d[1],'tile')+' of deck, '+DECK_MAX+' at most':'';}

// ---- The Part and Checks panels ----
function finding(){var i=lit>=0?lit:pin;return i>=0&&CHK[i]?CHK[i]:null;}
function part(){var f=finding(),kind,k,H,R=[['what','What'],['use','Use'],['how','How']],i,why,h;
if(f&&f.part){k=f.part;kind=kindOf(k);why='named by the check';}
else if(peek){kind=peek.charAt(0);k=peek.substring(2);why=peek==cur?'picked to draw with':(peek.charAt(1)=='!'?'on the plan':(kind=='e'?'chosen above':'click to pick it'));}
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
function airChecks(s){var A=null,i,f,was=CHK[pin]?CHK[pin].text:null,n=[0,0,0],h='',p=[];
try{A=JSON.parse(s);}catch(e){A=null;}
if(!A){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e2){}try{A=JSON.parse(s);}catch(e3){A=[];}}
if(!A||!A.length)A=[];
CHK=[];lit=-1;pin=-1;for(i=0;i<A.length;i++){f={level:LEVEL[A[i].level]?A[i].level:'note',text:A[i].text||'',cells:A[i].cells||[],part:A[i].part||''};CHK.push(f);if(was!==null&&f.text==was)pin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class="vd bad"><b>Not ready to build.</b> '+several(n[0],'thing')+' to fix first.</div>';
else h+='<div class="vd"><b>Ready to build.</b> As drawn she can be built at an airship yard.'+(n[1]?'<div class="also">'+several(n[1],'warning')+' below will not stop the build, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<CHK.length;i++){f=CHK[i];h+='<div tabindex="0" id="ck_'+i+'" class="ck"'+(f.cells.length?' title="Click to keep it ringed on the plan; click again to let go"':'')+'><span class="tag">'+LEVEL[f.level][0]+'</span><span class="tx">'+esc(f.text)+(f.cells.length?'<span class="wh" id="wh_'+i+'"></span>':'')+'</span></div>';}
$('checks').innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(several(n[1],'warning'));if(n[2])p.push(several(n[2],'note'));$('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<CHK.length;i++)hook(i);
mark();part();light();}
// Pointing at a tool, a tile or the engine shows what it is.
document.onmouseover=function(e){e=e||window.event;var b=e.target||e.srcElement,k=null,p,v;if(stroke)return;
while(b&&b!=document.body){if(b.id){
if(b.id.indexOf('t_')==0){k=b.id.substring(2);break;}
if(b.id.indexOf('c_')==0){p=b.id.split('_');v=cells[key(p[1],p[2])];if(v)k=v[2]?'p!'+v[2]:(v[1]?'g!'+v[1]:(v[0]?'d!'+v[0]:null));break;}
if(b.id=='eng'||b.id=='cc'){k='e:'+EN;break;}}
b=b.parentNode;}
if(k!=peek){peek=k;part();}};
// The panels fill the window's height, whatever it is.
function fit(){var h=(window.innerHeight||document.documentElement.clientHeight||690),c=$('checks'),top=c.getBoundingClientRect().top;c.style.height=Math.max(120,h-top-9)+'px';}
window.onresize=fit;
(function(){var e=$('ex'),j,o;for(j=0;j<EXAMPLES.length;j++){o=document.createElement('option');o.value=j;o.innerHTML=esc(EXAMPLES[j][0]);e.appendChild(o);}
load(DATA.START);cur='d:'+(DECKS.length?DECKS[0][0]:'p');refresh();fit();changed();})();
</script></body></html>"}

#undef AIR_DESIGNER_WINDOW
#undef AIR_DESIGNER_PREVIEW_GAP
