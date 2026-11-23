// ============================================================
// The rail designer (docs/trains.md "Rail plans")
// ------------------------------------------------------------
// Hold a blank ship's draught (or a rail plan) and a pen or pencil and choose
// to draw a railway: a window shows the sheet as a plan of the ground, north
// to the top, RAIL_PLAN_SIDE tiles each way. Track is drawn tile by tile with
// a click or a drag; a tile's shape follows from the track beside it, as it
// does on the ground. The Ease curve tool steps a corner between sharp,
// radius 4 and radius 8.
//
// Every change goes to the server, which reads it as a design code
// (rail_plan_from_code) and answers with the plan's own figures and checks
// (rail_plan.dm), so the window never disagrees with the sheet. Save keeps
// the drawing on the sheet. The Checks panel lists the findings and rings
// their tiles.
//
// The sheet is drawn on a canvas with plan symbols, not sprites: two rails on
// sleepers, a sharp corner as a mitred angle with a turning point, a buffer
// bar on an end. A corner marked for easing shows the wide curve it becomes,
// on the true circle the laid track follows (train_arcs.dm), over the tiles
// that curve will lie on; the straight track it replaces fades under it.
//
// The page is rail_designer_page() with one block of data at @@DATA@@:
//   REF     this designer's ref, for the window's links
//   SIDE    the tiles of the sheet each way
//   PART    the characters of one upload part
//   MAX     the longest code a plan may have
//   RADII   the radii a corner can be eased to
//   CAR     the tiles sharp corners must be apart; LONG the same for long cars
//   NAME    the plan's name
//   TRACK   list("x,y", ...) of every tile of track
//   CURVES  list("x,y,radius", ...) of every corner marked for easing
// A drawing can be longer than one link holds, so the window sends it in
// parts: ?src=REF;rail=begin;n=<parts>;mode=preview|save|export (or rail=import);name=<name>, then
// rail=part;i=<index>;d=<text> for each as the server acknowledges the last
// (railAck), then rail=end. The server answers with railPlan(json of
// rail_designer_answer()), railStatus(text) and, after a save, railSaved().
// ============================================================

#define RAIL_DESIGNER_WINDOW "rail_designer"
#define RAIL_DESIGNER_PART 900 // characters per upload part
#define RAIL_DESIGNER_PREVIEW_GAP 3 // deciseconds between answers per drawer

// mob -> /datum/rail_designer. A proc with a static list, not a global:
// the world's global init proc has no room for more.
/proc/rail_designers()
	var/static/list/open
	if (!open)
		open = list()
	return open

/datum/rail_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/list/upload_parts = null
	var/upload_count = 0
	var/upload_mode = null
	var/upload_name = null
	var/last_preview = null

/datum/rail_designer/Destroy()
	var/list/open = rail_designers()
	if (drawer && open[drawer] == src)
		open -= drawer
	drawer = null
	sheet = null
	upload_parts = null
	return ..()

// TRUE when sheet S holds a drawing that is not a rail plan.
/proc/rail_designer_other_drawing(obj/item/ship_draught/S)
	return S.draught_code && design_code_kind(S.draught_code) != "RAIL"

/obj/item/ship_draught/proc/open_rail_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	if (rail_designer_other_drawing(src))
		to_chat(H, SPAN_WARNING("The sheet already holds another drawing."))
		return
	var/list/open = rail_designers()
	var/datum/rail_designer/old = open[H]
	if (old)
		qdel(old)
	var/datum/rail_designer/A = new
	A.drawer = H
	A.sheet = src
	open[H] = A
	var/datum/rail_plan/D = rail_plan()
	if (!D)
		D = new
	show_browse(H, rail_designer_html(A, D), "window=[RAIL_DESIGNER_WINDOW];size=1070x775")
	onclose(H, RAIL_DESIGNER_WINDOW, A)
	rail_designer_stats(H, D)
	qdel(D)

/proc/rail_designer_data(datum/rail_designer/A, datum/rail_plan/D)
	var/list/tiles = list()
	for (var/key in D.track)
		tiles += key
	var/list/bent = list()
	for (var/key in D.curves)
		bent += "[key],[D.curves[key]]"
	return list(
		"REF" = A ? "\ref[A]" : "",
		"SIDE" = RAIL_PLAN_SIDE,
		"PART" = RAIL_DESIGNER_PART,
		"MAX" = DESIGN_CODE_RAIL_MAX,
		"RADII" = train_arc_radii(),
		"CAR" = TRAIN_CAR_LENGTH,
		"LONG" = TRAIN_LONG_CAR_LENGTH,
		"NAME" = D.name,
		"TRACK" = tiles,
		"CURVES" = bent,
	)

/proc/rail_designer_html(datum/rail_designer/A, datum/rail_plan/D)
	var/list/halves = splittext(rail_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(rail_designer_data(A, D)) + halves[2]

// What the window is told of a plan: its figures and its findings.
/proc/rail_designer_answer(datum/rail_plan/D)
	var/list/box = D.extent()
	var/sharp = 0
	for (var/key in D.track)
		var/list/p = splittext(key, ",")
		if (!D.curves[key] && D.is_corner(text2num(p[1]), text2num(p[2])))
			sharp++
	var/list/done = D.finished_tiles()
	var/datum/design_report/R = D.check_design()
	. = list(
		"tiles" = D.tile_count(),
		"curves" = length(D.curves),
		"sharp" = sharp,
		"laid" = length(done),
		"wide" = box ? box[3] - box[1] + 1 : 0,
		"deep" = box ? box[4] - box[2] + 1 : 0,
		// Each tile of track takes a stack of sleepers and a rail length.
		"sleepers" = D.tile_count(),
		"rails" = D.tile_count(),
		"checks" = R.data(),
	)
	qdel(R)

/proc/rail_designer_ack(mob/user, n)
	user << output(list2params(list("[n]")), "[RAIL_DESIGNER_WINDOW].browser:railAck")

/proc/rail_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[RAIL_DESIGNER_WINDOW].browser:railStatus")

/proc/rail_designer_stats(mob/user, datum/rail_plan/D)
	user << output(list2params(list(json_encode(rail_designer_answer(D)))), "[RAIL_DESIGNER_WINDOW].browser:railPlan")

// Tells the window its drawing is the one on the sheet now.
/proc/rail_designer_saved(mob/user)
	user << output(null, "[RAIL_DESIGNER_WINDOW].browser:railSaved")

/datum/rail_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["rail"] || H != drawer || rail_designers()[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		upload_parts = null
		rail_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	// Import and Export work the same in every designer (naval/draught_kinds.dm).
	if (href_list["rail"] == "import")
		upload_parts = null
		sheet.draught_import_in_window(H, RAIL_DESIGNER_WINDOW)
		return
	if (rail_designer_other_drawing(sheet))
		upload_parts = null
		rail_designer_status(H, "The sheet already holds another drawing.")
		return
	switch (href_list["rail"])
		if ("begin")
			var/n = text2num(href_list["n"])
			var/max_parts = CEILING(DESIGN_CODE_RAIL_MAX / RAIL_DESIGNER_PART, 1)
			if (!isnum(n) || n < 1 || n > max_parts || n != round(n) || !(href_list["mode"] in list("preview", "save", "export")))
				rail_designer_status(H, "The drawing could not be sent.")
				return
			upload_parts = list()
			upload_count = n
			upload_mode = href_list["mode"]
			upload_name = href_list["name"]
			rail_designer_ack(H, 0)
		if ("part")
			var/i = text2num(href_list["i"])
			var/d = href_list["d"]
			if (!upload_parts || !isnum(i) || i != upload_parts.len || i >= upload_count || !istext(d) || length(d) > RAIL_DESIGNER_PART)
				upload_parts = null
				rail_designer_status(H, "The drawing could not be sent.")
				return
			upload_parts += d
			rail_designer_ack(H, i + 1)
		if ("end")
			var/list/got = upload_parts
			upload_parts = null
			if (!got || got.len != upload_count)
				rail_designer_status(H, "The drawing could not be sent.")
				return
			var/export = upload_mode == "export"
			var/result = accept_drawing(H, jointext(got, ""), upload_name, export || upload_mode == "save")
			if (!isnull(result))
				rail_designer_status(H, result)
			if (export && result == "Saved on the sheet.")
				sheet.draught_export(H, rail_plan_clean_name(upload_name))

// Reads a drawing sent from the window. A preview answers with the figures;
// a save keeps it on the sheet. Returns a status line, or null when the
// figures alone answer.
/datum/rail_designer/proc/accept_drawing(mob/living/human/H, code, new_name, save)
	// Too soon after the last answer: the window only needs to know it may
	// send again.
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + RAIL_DESIGNER_PREVIEW_GAP)
			return ""
		last_preview = world.time
	// rail_plan_from_code() refuses a tile off the sheet, a run that is not
	// three numbers and a curve on a tile with no track or of no known radius.
	var/datum/rail_plan/D = rail_plan_from_code(code)
	if (!D)
		return "The drawing could not be read."
	D.name = rail_plan_clean_name(new_name)
	rail_designer_stats(H, D)
	if (save)
		sheet.take_rail(D)
		qdel(D)
		rail_designer_saved(H)
		return "Saved on the sheet."
	qdel(D)
	return null

// Raw string: no DM interpolation inside, and never a double quote followed
// by a closing brace. Plain ES5 for the embedded browser. One @@DATA@@.
/proc/rail_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Rail plan</title><style>
html,body{height:100%}
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:0;overflow:hidden}
#wrap{display:flex;align-items:flex-start;padding:6px 8px 0 8px}
#plan{flex:0 0 694px;width:694px;margin-right:10px}
#side{flex:1 1 0;min-width:0}
.sec{border:1px solid #66513b;background:#30271e;margin-bottom:8px}
.sec h2{font-size:13px;margin:0;padding:5px 8px;border-bottom:2px solid #b48c4d}
.sec h2 span{float:right;font-size:11px;font-weight:normal;color:#bfae96;margin-top:1px}
.sec .in{padding:6px 8px}
button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;margin:0;padding:3px 7px;cursor:pointer;font-family:Verdana,sans-serif;font-size:11px}
button:hover{border-color:#ffd985}
button.on{background:#b48c4d;color:#211c16;border-color:#ffd985}
button.go{flex:none;white-space:nowrap;background:#6b4d1f;border-color:#b48c4d;font-weight:bold;font-size:12px;padding:5px 14px}
button.cd{flex:none;white-space:nowrap;margin-right:4px}
input{background:#1d1916;color:#e9dfc8;border:1px solid #806040;font-family:Verdana,sans-serif;font-size:11px;height:22px;box-sizing:border-box;padding:1px 3px}
.row{display:flex;align-items:center;margin-bottom:5px}
.row label{flex:0 0 46px;color:#bfae96;font-size:11px}
.hint{color:#b0a080;font-size:11px;line-height:1.4}
.hint b{color:#e9dfc8;font-weight:normal}
.lbl{color:#b0a080;font-size:10px;text-align:center;letter-spacing:1px;text-transform:uppercase}
.ph{color:#bfae96;font-size:11px;margin:5px 0 3px 0}

/* The sheet */
#board{display:flex;justify-content:center;align-items:center;margin:2px 0}
#board .lbl{flex:none;width:9px;line-height:11px;word-wrap:break-word;letter-spacing:0}
#g{display:block;margin:0 3px;border:2px solid #0f0c09;background:#d9c9a3;cursor:crosshair;-webkit-user-select:none;-ms-user-select:none;user-select:none}
#at{height:15px;margin-top:3px;color:#bfae96;font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}

/* Tools */
.pal{display:flex}
.pal button{flex:1 1 0;display:flex;align-items:center;text-align:left;height:32px;line-height:12px;padding:1px 4px 1px 2px;margin-right:3px;overflow:hidden;box-sizing:border-box}
.pal button:last-child{margin-right:0}
.pal button canvas{flex:none;width:26px;height:26px;margin-right:5px;border:1px solid #14100c;background:#d9c9a3}
.pal button .nm{flex:1 1 auto;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pal button .nm u{display:block;text-decoration:none;font-size:10px;color:#bfae96}
.pal button.on .nm u{color:#3a2a14}
#st{flex:1 1 auto;min-width:0;color:#ffd985;margin-left:9px;font-size:11px;line-height:1.25}
#key{display:flex;flex-wrap:wrap;margin-top:6px}
#key div{display:flex;align-items:center;margin:0 10px 2px 0;color:#bfae96;font-size:10px;white-space:nowrap}
#key canvas{width:20px;height:20px;margin-right:4px;border:1px solid #14100c;background:#d9c9a3}

/* Figures */
.fg{display:flex;margin:0 0 5px 0}
.fg div{flex:1 1 0;background:#262019;border:1px solid #54432f;padding:3px 0;text-align:center;margin-right:4px}
.fg div:last-child{margin-right:0}
.fg b{display:block;font-size:15px;color:#ffd985}
.fg span{font-size:10px;color:#bfae96}

/* Checks */
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
<div class='sec' style='margin-bottom:0'><h2>Rail plan<span id='dims'></span></h2><div class='in'>
<div class='lbl'>north</div>
<div id='board'><div class='lbl'>west</div><canvas id='g' width='640' height='640'></canvas><div class='lbl'>east</div></div>
<div class='lbl'>south</div>
<div id='at'></div>
</div></div>
</div>

<div id='side'>
<div class='row'><label for='nm'>Name</label><input id='nm' maxlength='40' style='flex:1 1 auto;min-width:0' onchange='changed()' onkeyup='changed()'></div>
<div class='ph'>Tools <span class='hint'>- right-click always lifts track</span></div>
<div class='pal'><button id='t_track' onclick='tool("track")' title='Click or drag to draw a line of track'><canvas width='26' height='26'></canvas><span class='nm'>Track<u>click or drag</u></span></button><button id='t_erase' onclick='tool("erase")' title='Click or drag to lift track off the sheet'><canvas width='26' height='26'></canvas><span class='nm'>Erase<u>lifts track</u></span></button><button id='t_ease' onclick='tool("ease")' title='Click a corner to step it between sharp, radius 4 and radius 8'><canvas width='26' height='26'></canvas><span class='nm'>Ease curve<u>click a corner</u></span></button></div>
<div class='row' style='margin-top:5px'><button onclick='undo()' style='margin-right:3px'>Undo</button><button onclick='redo()' style='margin-right:8px'>Redo</button><button onclick='clearAll()' title='Lifts every tile of track off the drawing. The sheet keeps its last save until you save again.'>Clear</button></div>
<div class='row'><button class='go' onclick='send(1)'>Save to the sheet</button><span id='st'></span></div>
<div class='row' style='margin-bottom:0'><button class='cd' onclick='exportCode()' title='Save the drawing on the sheet and show its design code to copy'>Export code</button><button class='cd' onclick='importCode()' title='Paste a design code; it replaces what is drawn on this sheet'>Import code</button></div>
<div class='hint' style='margin-top:6px' id='help'></div>
<div id='key'><div><canvas id='k_s' width='20' height='20'></canvas>straight</div><div><canvas id='k_c' width='20' height='20'></canvas>sharp corner</div><div><canvas id='k_e' width='20' height='20'></canvas>end</div><div><canvas id='k_w' width='20' height='20'></canvas>wide curve</div></div>
<div class='sec' style='margin-top:8px'><h2>Figures<span id='figk'></span></h2><div class='in' id='stats'><span class='hint'>Reckoning...</span></div></div>
<div class='sec' style='margin-bottom:0'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div>
</div>

</div><script>
var DATA=@@DATA@@;
var REF=DATA.REF,SIDE=DATA.SIDE,PART=DATA.PART,MAX=DATA.MAX,RADII=DATA.RADII||[4,8],CAR=DATA.CAR||4,LONG=DATA.LONG||8;
var track={},curves={},cur='track',hist=[],fut=[],Z=16,g=null,SP=null;
var parts=null,busy=0,dirty=false,timer=null,rev=0,savedRev=0,sendRev=0;
var CHK=[],lit=-1,pin=-1,hov=null,drag=null,stroked=false;
var LEVEL={error:['Fix','#c0391b'],warning:['Warning','#a8780a'],note:['Note','#4a5f7a']};
var INK='#2a1c0e',PAPER='#d9c9a3',TIE='#7a4f26',CURVE='#17505f',CURVETIE='#3f8291',BAD='#c0391b';
// The four ways from a tile: name, east, south (north is up the sheet).
var DIRS=[['north',0,-1],['south',0,1],['east',1,0],['west',-1,0]];
function $(i){return document.getElementById(i);}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;');}
function key(x,y){return x+','+y;}
function xy(k){var p=(k+'').split(',');return [+p[0],+p[1]];}
function several(n,one){return n+' '+one+(n==1?'':'s');}
function inGrid(x,y){return x>=1&&y>=1&&x<=SIDE&&y<=SIDE;}
function has(x,y){return inGrid(x,y)&&!!track[key(x,y)];}
function count(o){var n=0,k;for(k in o)n++;return n;}

// ---- The line ----
// These follow rail_plan.dm, so the sheet shows at once what the server will say.
function links(x,y){var L=[],d;for(d=0;d<4;d++)if(has(x+DIRS[d][1],y+DIRS[d][2]))L.push(d);return L;}
function opposite(a,b){return (a^1)==b;}
function isCorner(x,y){var L;if(!has(x,y))return false;L=links(x,y);return L.length==2&&!opposite(L[0],L[1]);}
function curveAt(x,y){return curves[key(x,y)]||0;}
// The tiles of a curve of radius R from where it leaves the first straight:
// [towards the turn, along the first heading] each (train_arc_path).
function arcPath(R){var P=[],run=R>=8?3:2,i=0,j,k;for(j=0;j<=run;j++)P.push([0,j]);j=run;
for(k=1;k<=R-run;k++){i++;P.push([i,j]);j++;P.push([i,j]);}for(k=1;k<=run;k++){i++;P.push([i,j]);}return P;}
// The corner at x,y eased to radius R: where it starts, its heading there,
// the way it turns, the tiles it lies on and the straight tiles it takes up.
function curveGeom(x,y,R){var L=links(x,y),G,P,i,d,k,px,py;if(L.length!=2)return null;
G={x:x,y:y,R:R,hx:-DIRS[L[0]][1],hy:-DIRS[L[0]][2],bx:DIRS[L[1]][1],by:DIRS[L[1]][2],tiles:[],legs:[],off:false};
G.sx=x-R*G.hx;G.sy=y-R*G.hy;P=arcPath(R);
for(i=0;i<P.length;i++){px=G.sx+P[i][0]*G.bx+P[i][1]*G.hx;py=G.sy+P[i][0]*G.by+P[i][1]*G.hy;if(!inGrid(px,py))G.off=true;G.tiles.push(key(px,py));}
for(d=0;d<2;d++)for(k=1;k<=R;k++)G.legs.push(key(x+k*DIRS[L[d]][1],y+k*DIRS[L[d]][2]));return G;}
// Why the corner at x,y cannot be eased as marked, or ''.
function curveProblem(x,y){var R=curveAt(x,y),G,i,p,on={};if(!R)return '';
if(!isCorner(x,y))return 'this tile is not a corner';G=curveGeom(x,y,R);
for(i=0;i<G.legs.length;i++){p=xy(G.legs[i]);on[G.legs[i]]=1;if(!has(p[0],p[1])||isCorner(p[0],p[1])||links(p[0],p[1]).length>2||curveAt(p[0],p[1]))return 'it needs '+R+' tiles of plain straight track on each side';}
if(G.off)return 'the curve would run off the sheet';
for(i=0;i<G.tiles.length;i++)if(track[G.tiles[i]]&&!on[G.tiles[i]])return 'other track is in the way of the curve';
return '';}
// What the marked corners do to the sheet: the curves that can be eased, the
// tiles each will lie on and the straight tiles it replaces.
function spans(){var k,p,G,i,S={eased:[],over:{},under:{},bad:{}};
for(k in curves){p=xy(k);if(curveProblem(p[0],p[1])){S.bad[k]=1;continue;}G=curveGeom(p[0],p[1],curves[k]);S.eased.push(G);
S.under[k]=G;for(i=0;i<G.legs.length;i++)S.under[G.legs[i]]=G;for(i=0;i<G.tiles.length;i++)S.over[G.tiles[i]]=G;}return S;}

// ---- Plan symbols ----
// Track on one tile k pixels a side centred on cx,cy, leading the ways in L.
function rails(c,cx,cy,k,d,from){var vx=DIRS[d][1],vy=DIRS[d][2],q=k*0.2,h=k/2,s;for(s=-1;s<=1;s+=2){c.moveTo(cx+vx*from-vy*q*s,cy+vy*from+vx*q*s);c.lineTo(cx+vx*h-vy*q*s,cy+vy*h+vx*q*s);}}
function tie(c,cx,cy,k,d,at,half){var vx=DIRS[d][1],vy=DIRS[d][2];c.moveTo(cx+vx*at-vy*half,cy+vy*at+vx*half);c.lineTo(cx+vx*at+vy*half,cy+vy*at-vx*half);}
function drawTrack(c,cx,cy,k,L,faint){var i,a,b,q=k*0.2,h=k/2,w=k*0.36,s,lone=!L.length;
c.save();if(faint)c.globalAlpha=0.34;c.lineCap='butt';if(lone)L=[2,3];
// Sleepers first, the rails over them.
c.strokeStyle=TIE;c.lineWidth=Math.max(2,k/7);c.beginPath();
if(L.length==2&&!opposite(L[0],L[1])){tie(c,cx,cy,k,L[0],k*0.4,w*0.78);tie(c,cx,cy,k,L[1],k*0.4,w*0.78);}
else{for(i=0;i<L.length;i++)tie(c,cx,cy,k,L[i],k*0.33,w);if(L.length<3)tie(c,cx,cy,k,L[0],0,w);}
c.stroke();
c.strokeStyle=INK;c.lineWidth=Math.max(1.3,k/11);c.beginPath();
if(L.length==2&&!opposite(L[0],L[1])){a=DIRS[L[0]];b=DIRS[L[1]];
// A sharp corner: both rails turn a right angle on the tile.
for(s=-1;s<=1;s+=2){c.moveTo(cx+a[1]*h+b[1]*q*s,cy+a[2]*h+b[2]*q*s);c.lineTo(cx+(a[1]+b[1])*q*s,cy+(a[2]+b[2])*q*s);c.lineTo(cx+b[1]*h+a[1]*q*s,cy+b[2]*h+a[2]*q*s);}}
else for(i=0;i<L.length;i++)rails(c,cx,cy,k,L[i],0);
c.stroke();
if(L.length==2&&!opposite(L[0],L[1])){c.fillStyle=INK;c.beginPath();c.arc(cx,cy,Math.max(1.6,k*0.12),0,Math.PI*2);c.fill();}
else if(L.length>2){c.fillStyle=PAPER;c.lineWidth=Math.max(1.3,k/11);c.beginPath();c.arc(cx,cy,k*0.2,0,Math.PI*2);c.fill();c.stroke();}
else if(lone||L.length==1){c.lineWidth=Math.max(2.5,k/5);c.beginPath();
if(lone){tie(c,cx,cy,k,2,k*0.42,w);tie(c,cx,cy,k,3,k*0.42,w);}else tie(c,cx,cy,k,L[0],-k*0.06,w);c.stroke();}
c.restore();}
// A wide curve on the circle the laid track follows: it leaves the near edge
// of its first tile and meets the far edge of its last (train_arcs.dm).
// ox,oy is the centre of its first tile, k the pixels of a tile.
function drawArc(c,ox,oy,k,G,bad){var rad=(G.R+0.5)*k,ccx=ox+G.bx*rad-G.hx*k/2,ccy=oy+G.by*rad-G.hy*k/2,n=Math.round((G.R+0.5)*Math.PI/2*3),i,t,s,r,steps=6*G.R;
function pt(t,r){return [ccx-G.bx*r*Math.cos(t)+G.hx*r*Math.sin(t),ccy-G.by*r*Math.cos(t)+G.hy*r*Math.sin(t)];}
c.save();c.lineCap='butt';c.strokeStyle=bad?BAD:CURVETIE;c.lineWidth=Math.max(2,k/7);c.beginPath();
for(i=0;i<n;i++){t=(i+0.5)/n*Math.PI/2;s=pt(t,rad-k*0.36);c.moveTo(s[0],s[1]);s=pt(t,rad+k*0.36);c.lineTo(s[0],s[1]);}c.stroke();
c.strokeStyle=bad?BAD:CURVE;c.lineWidth=Math.max(1.5,k/9);c.beginPath();
for(r=-1;r<=1;r+=2)for(i=0;i<=steps;i++){s=pt(i/steps*Math.PI/2,rad+r*k*0.2);if(i)c.lineTo(s[0],s[1]);else c.moveTo(s[0],s[1]);}c.stroke();c.restore();}
// The radius on a corner marked for easing.
function drawBadge(c,cx,cy,k,R,bad){c.save();c.fillStyle=bad?BAD:CURVE;c.strokeStyle='#fff6dc';c.lineWidth=1;c.beginPath();c.arc(cx,cy,k*0.44,0,Math.PI*2);c.fill();c.stroke();
c.fillStyle='#fff6dc';c.font='bold '+Math.round(k*0.6)+'px Verdana,sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText(R+'',cx,cy+0.5);c.restore();}
function drawEraser(c,px,py,k){c.strokeStyle=BAD;c.lineWidth=Math.max(2,k/8);c.beginPath();c.moveTo(px+k*0.25,py+k*0.25);c.lineTo(px+k*0.75,py+k*0.75);c.moveTo(px+k*0.75,py+k*0.25);c.lineTo(px+k*0.25,py+k*0.75);c.stroke();}
// A small picture of a wide curve, for the tool and the key.
function drawCurveIcon(c,k){var G={R:1,hx:0,hy:-1,bx:1,by:0};c.fillStyle='rgba(23,80,95,0.16)';c.fillRect(0,0,k,k);drawArc(c,k*0.15,k*0.67,k*0.5,G,false);}
function icons(){var c;c=$('t_track').getElementsByTagName('canvas')[0].getContext('2d');drawTrack(c,13,13,26,[2,3],false);
c=$('t_erase').getElementsByTagName('canvas')[0].getContext('2d');drawTrack(c,13,13,26,[2,3],true);drawEraser(c,0,0,26);
c=$('t_ease').getElementsByTagName('canvas')[0].getContext('2d');drawCurveIcon(c,26);
drawTrack($('k_s').getContext('2d'),10,10,20,[2,3],false);drawTrack($('k_c').getContext('2d'),10,10,20,[1,2],false);drawTrack($('k_e').getContext('2d'),10,10,20,[3],false);drawCurveIcon($('k_w').getContext('2d'),20);}

// ---- The sheet ----
function draw(){var k,p,i,f,G,W=SIDE*Z;SP=spans();
g.fillStyle=PAPER;g.fillRect(0,0,W,W);
// The ground a wide curve will lie on.
g.fillStyle='rgba(23,80,95,0.16)';for(k in SP.over){p=xy(k);g.fillRect((p[0]-1)*Z,(p[1]-1)*Z,Z,Z);}
// A faint line every tile and a firmer one every four: the length of a car,
// and of the straight a radius 4 curve needs.
g.lineWidth=1;g.strokeStyle='rgba(42,28,14,0.13)';g.beginPath();for(i=0;i<=SIDE;i++){g.moveTo(i*Z+0.5,0);g.lineTo(i*Z+0.5,W);g.moveTo(0,i*Z+0.5);g.lineTo(W,i*Z+0.5);}g.stroke();
g.strokeStyle='rgba(42,28,14,0.3)';g.beginPath();for(i=CAR;i<SIDE;i+=CAR){g.moveTo(i*Z+0.5,0);g.lineTo(i*Z+0.5,W);g.moveTo(0,i*Z+0.5);g.lineTo(W,i*Z+0.5);}g.stroke();
// The track as drawn; what a curve will replace fades under it.
for(k in track){p=xy(k);drawTrack(g,(p[0]-0.5)*Z,(p[1]-0.5)*Z,Z,links(p[0],p[1]),!!SP.under[k]);}
for(i=0;i<SP.eased.length;i++){G=SP.eased[i];drawArc(g,(G.sx-0.5)*Z,(G.sy-0.5)*Z,Z,G,false);}
for(k in curves){p=xy(k);drawBadge(g,(p[0]-0.5)*Z,(p[1]-0.5)*Z,Z,curves[k],!!SP.bad[k]);}
// With the Ease curve tool every corner it can be used on is ringed.
if(cur=='ease'){g.strokeStyle=CURVE;g.lineWidth=2;for(k in track){p=xy(k);if(!curves[k]&&isCorner(p[0],p[1])){g.beginPath();g.arc((p[0]-0.5)*Z,(p[1]-0.5)*Z,Z*0.62,0,Math.PI*2);g.stroke();}}}
f=finding();if(f){g.strokeStyle=LEVEL[f.level][1];g.lineWidth=3;for(i=0;i<f.cells.length;i++){p=xy(f.cells[i]);g.strokeRect((p[0]-1)*Z+1.5,(p[1]-1)*Z+1.5,Z-3,Z-3);}
g.strokeStyle='#fff6dc';g.lineWidth=1;for(i=0;i<f.cells.length;i++){p=xy(f.cells[i]);g.strokeRect((p[0]-1)*Z-0.5,(p[1]-1)*Z-0.5,Z+1,Z+1);}}
if(hov){g.strokeStyle=BAD;g.lineWidth=2;g.strokeRect((hov[0]-1)*Z+1,(hov[1]-1)*Z+1,Z-2,Z-2);}
where();}
// What the tile under the pointer is.
function shape(x,y){var L=links(x,y),k=key(x,y),R=curveAt(x,y),G,t,why;
if(!has(x,y)){G=SP&&SP.over[k];return 'bare ground'+(G?' - the radius '+G.R+' curve from '+G.x+','+G.y+' will lie here':'');}
if(!L.length)t='a lone tile of track';
else if(L.length==1)t='the end of the line, running '+DIRS[L[0]][0];
else if(L.length>2)t='track meeting '+L.length+' ways - a switch is laid here by hand';
else if(opposite(L[0],L[1]))t='straight track, '+(L[0]<2?'north to south':'west to east');
else t=(R?'corner':'sharp corner')+', '+DIRS[L[0]][0]+' to '+DIRS[L[1]][0];
if(R){why=curveProblem(x,y);t+=why?' - marked for a radius '+R+' curve, but '+why:' - to be eased into a curve of radius '+R;}
else{G=SP&&SP.under[k];if(G)t+=' - relaid as part of the radius '+G.R+' curve from '+G.x+','+G.y;else if(SP&&SP.over[k])t+=' - a wide curve joins the line here';}
return t;}
function where(){var n=count(track),t='';if(hov)t='Tile '+hov[0]+','+hov[1]+': '+shape(hov[0],hov[1]);
$('at').innerHTML=esc(t);$('dims').innerHTML=several(n,'tile')+' of track'+(rev!=savedRev?' &middot; not saved yet':'');}

// ---- Drawing on it ----
function snap(){return JSON.stringify([track,curves]);}
function restore(t){var o=JSON.parse(t);track=o[0];curves=o[1];}
function push(t){hist.push(t||snap());if(hist.length>60)hist.shift();fut=[];}
function undo(){if(!hist.length){status('Nothing to undo.');return;}fut.push(snap());restore(hist.pop());status('');after();}
function redo(){if(!fut.length){status('Nothing to redo.');return;}hist.push(snap());restore(fut.pop());status('');after();}
function after(){rev++;if($('st').innerHTML=='Saved on the sheet.')status('');draw();changed();}
// Lays or lifts track on one tile; lifting a corner forgets its curve.
function one(x,y,lift){var k=key(x,y);if(!inGrid(x,y))return false;if(lift){if(!track[k])return false;delete track[k];delete curves[k];return true;}if(track[k])return false;track[k]=1;return true;}
// A drag draws an unbroken line: west or east first, then north or south.
function lineTo(d,x,y){var did=false;while(d.x!=x){d.x+=d.x<x?1:-1;if(one(d.x,d.y,d.lift))did=true;}while(d.y!=y){d.y+=d.y<y?1:-1;if(one(d.x,d.y,d.lift))did=true;}return did;}
// Steps a corner between sharp and each radius it can be eased to.
function ease(x,y){var k=key(x,y),R=curveAt(x,y),i,before=snap(),why;
if(!has(x,y)){status('Click a corner of the line to ease it.');return;}
if(!R&&!isCorner(x,y)){status('Only a corner can be eased: click a tile where the line turns a right angle.');return;}
i=-1;for(why=0;why<RADII.length;why++)if(RADII[why]==R)i=why;
if(R&&i==RADII.length-1)delete curves[k];else curves[k]=RADII[R?i+1:0];
push(before);status('');after();
why=curveProblem(x,y);if(why)status('Marked for radius '+curves[k]+', but '+esc(why)+'.');}
function clearAll(){var before=snap();if(!count(track)&&!count(curves)){status('Nothing is drawn.');return;}track={};curves={};push(before);status('Cleared. Undo brings it back.');rev++;draw();changed();}
function pos(e){var cv=$('g'),r=cv.getBoundingClientRect(),x=Math.floor((e.clientX-r.left-2)/Z)+1,y=Math.floor((e.clientY-r.top-2)/Z)+1;return inGrid(x,y)?[x,y]:null;}
function hook(){var cv=$('g');cv.onmousedown=function(e){e=e||window.event;var p=pos(e),right=e.button==2;if(!p||e.button==1)return;if(e.preventDefault)e.preventDefault();
if(cur=='ease'&&!right){ease(p[0],p[1]);return;}
drag={x:p[0],y:p[1],lift:right||cur!='track',before:snap()};stroked=false;status('');if(one(p[0],p[1],drag.lift))stroked=true;draw();};
cv.onmousemove=function(e){e=e||window.event;var p=pos(e);if(drag&&e.buttons!==undefined&&!e.buttons)finish();
if(!p){if(hov){hov=null;draw();}return;}if(hov&&hov[0]==p[0]&&hov[1]==p[1])return;hov=p;
if(drag&&lineTo(drag,p[0],p[1]))stroked=true;draw();};
cv.onmouseleave=function(){if(hov){hov=null;draw();}};
cv.oncontextmenu=function(){return false;};
document.onmouseup=function(){finish();};}
function finish(){var d=drag;if(!d)return;drag=null;if(stroked){push(d.before);after();}else draw();}
function tool(t){var i,T=['track','erase','ease'];cur=t;for(i=0;i<T.length;i++)$('t_'+T[i]).className=T[i]==t?'on':'';if(g)draw();}
function load(){var i,p;$('nm').value=DATA.NAME||'railway';track={};curves={};
for(i=0;i<(DATA.TRACK||[]).length;i++){p=xy(DATA.TRACK[i]);if(inGrid(p[0],p[1]))track[key(p[0],p[1])]=1;}
for(i=0;i<(DATA.CURVES||[]).length;i++){p=(DATA.CURVES[i]+'').split(',');if(track[key(+p[0],+p[1])])curves[key(+p[0],+p[1])]=+p[2];}}

// ---- Talking to the server ----
// The drawing as a design code: runs of track eastwards, then the curves.
function code(){var nm=$('nm').value.replace(/[\/;,]/g,' ').replace(/^\s+|\s+$/g,'').replace(/ /g,'_'),runs=[],bent=[],x,y,n,k;if(!nm)nm='railway';
for(y=1;y<=SIDE;y++){x=1;while(x<=SIDE){if(!track[key(x,y)]){x++;continue;}n=1;while(x+n<=SIDE&&track[key(x+n,y)])n++;runs.push(x+','+y+','+n);x+=n;}}
for(k in curves)if(track[k])bent.push(k+','+curves[k]);
return 'C13RAIL/1/'+nm+'/'+runs.join(';')+'/'+bent.join(';');}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function waiting(){return parts!==null&&new Date().getTime()-busy<4000;}
// Export saves like Save and then shows the code; Import asks for one.
function exportCode(){send('export');}
function importCode(){if(timer){clearTimeout(timer);timer=null;}go('rail=import');}
function send(save){var p,j;if(timer){clearTimeout(timer);timer=null;}if(waiting()){if(save)status('Wait a moment...');dirty=true;return;}
p=code();if(p.length>MAX){status('The plan is too long for one sheet: draw longer straight runs, or split the line over two plans.');return;}
parts=[];for(j=0;j<p.length;j+=PART)parts.push(p.substring(j,j+PART));busy=new Date().getTime();dirty=false;if(save){sendRev=rev;status('Saving...');}
go('rail=begin&n='+parts.length+'&mode='+(save=='export'?'export':save?'save':'preview')+'&name='+encodeURIComponent($('nm').value));}
function railAck(n){n=parseInt(n,10);if(!parts)return;if(n<parts.length){go('rail=part&i='+n+'&d='+encodeURIComponent(parts[n]));return;}parts=null;go('rail=end');}
function done(){parts=null;if(dirty){dirty=false;changed();}}
// The server answers once per 0.3 s: wait out the gap, so the last change
// is never the one it skips.
function changed(){if(timer)clearTimeout(timer);timer=setTimeout(function(){timer=null;send(0);},450);}
function status(t){$('st').innerHTML=t;}
function railStatus(t){if(t!=='')status(esc(t));done();}
function railSaved(){savedRev=sendRev;where();}
function parse(s){var A=null;try{A=JSON.parse(s);}catch(e){A=null;}
if(!A){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e2){}try{A=JSON.parse(s);}catch(e3){A=null;}}
return A;}
// The server's answer: the figures and the findings.
function railPlan(s){var A=parse(s),o;if(!A){done();return;}
o='<div class="fg"><div><b>'+(+A.tiles)+'</b><span>tiles of track</span></div><div><b>'+(+A.curves)+'</b><span>wide curves</span></div><div><b>'+(+A.sleepers)+'</b><span>sleepers</span></div><div><b>'+(+A.rails)+'</b><span>rail lengths</span></div></div>';
o+='<div class="hint">'+(+A.tiles?'Each tile of track takes a stack of sleepers and a rail length. '+several(+A.sharp,'sharp corner')+'. Easing a corner relays its tiles: it gains and loses no rail.':'One stack of sleepers and one rail length for every tile of track you draw.')+'</div>';
$('stats').innerHTML=o;$('figk').innerHTML=+A.tiles?(+A.wide)+' by '+(+A.deep)+' tiles on the ground':'nothing drawn';checks(A.checks||[]);done();}

// ---- The Checks panel ----
function finding(){var i=lit>=0?lit:pin;return i>=0&&CHK[i]?CHK[i]:null;}
function whereText(i){var f=CHK[i];return i==pin?'&#9679; ringed on the sheet':'&#9675; '+several(f.cells.length,'tile')+' - click to ring '+(f.cells.length==1?'it':'them');}
function mark(){var i,b,f,w;for(i=0;i<CHK.length;i++){b=$('ck_'+i);if(!b)continue;f=CHK[i];
b.className='ck '+f.level+(f.cells.length?' has':'')+(i==pin?' pin':'')+(i==lit?' lit':'');w=$('wh_'+i);if(w)w.innerHTML=whereText(i);}}
function show(i){lit=i;mark();draw();}
function keep(i){if(!CHK[i].cells.length)return;pin=pin==i?-1:i;mark();draw();}
function hookCheck(i){var b=$('ck_'+i);b.onmouseenter=b.onfocus=function(){show(i);};b.onmouseleave=b.onblur=function(){if(lit==i)show(-1);};b.onclick=function(){keep(i);};}
function checks(A){var i,f,was=CHK[pin]?CHK[pin].text:null,n=[0,0,0],h='',p=[];
CHK=[];lit=-1;pin=-1;for(i=0;i<A.length;i++){f={level:LEVEL[A[i].level]?A[i].level:'note',text:A[i].text||'',cells:A[i].cells||[]};CHK.push(f);if(was!==null&&f.text==was)pin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class="vd bad"><b>It cannot be laid as drawn.</b> '+several(n[0],'thing')+' to put right first.</div>';
else h+='<div class="vd"><b>It can be laid as drawn.</b>'+(n[1]?'<div class="also">'+several(n[1],'warning')+' below will not stop the laying, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<CHK.length;i++){f=CHK[i];h+='<div tabindex="0" id="ck_'+i+'" class="ck"'+(f.cells.length?' title="Click to keep it ringed on the sheet; click again to let go"':'')+'><span class="tag">'+LEVEL[f.level][0]+'</span><span class="tx">'+esc(f.text)+(f.cells.length?'<span class="wh" id="wh_'+i+'"></span>':'')+'</span></div>';}
$('checks').innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(several(n[1],'warning'));if(n[2])p.push(several(n[2],'note'));$('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<CHK.length;i++)hookCheck(i);
mark();draw();fit();}
// The Checks panel fills the window's height, whatever it is.
function fit(){var h=(window.innerHeight||document.documentElement.clientHeight||775),c=$('checks'),top=c.getBoundingClientRect().top;c.style.height=Math.max(90,h-top-9)+'px';}
window.onresize=fit;
(function(){$('help').innerHTML='Draw the line tile by tile: where it turns a right angle it makes a corner. Keep corners <b>'+CAR+' tiles apart</b> ('+LONG+' for long cars). A wide curve needs <b>'+RADII.join(' or ')+' straight tiles</b> on each side of its corner. Once saved, use the sheet in your hand to peg the plan out on the ground.';
g=$('g').getContext('2d');$('g').width=SIDE*Z;$('g').height=SIDE*Z;load();icons();hook();tool('track');draw();fit();changed();})();
</script></body></html>"}

#undef RAIL_DESIGNER_WINDOW
#undef RAIL_DESIGNER_PART
#undef RAIL_DESIGNER_PREVIEW_GAP
