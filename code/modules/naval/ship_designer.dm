// ============================================================
// The ship designer (docs/ship-draught.md): drawing a ship's draught
// ------------------------------------------------------------
// Hold a ship's draught and a pen or pencil and choose "Draw on the sheet":
// a browser window shows the sheet as a grid, bow to the top, in the game's
// brown and gold. Floors, decks above and fittings are picked from a palette
// of pictures and painted on it; a box tool and a mirror for port and
// starboard save work. Every change is sent to the server, which reads it as
// a design code and answers with the draught's own figures: tiles against
// the caps, size class, cost, speed and what still stops her being built.
// The figures are always the server's, so the window never disagrees with
// the sheet or the ship.
//
// Save keeps the drawing on the sheet, finished or not. The server checks the
// code like a pasted one, so nothing drawn here goes past the draught's rules.
// ============================================================

#define SHIP_DESIGNER_WINDOW "ship_designer"
#define SHIP_DESIGNER_PART 900 // characters per upload part
#define SHIP_DESIGNER_PREVIEW_GAP 3 // deciseconds between summaries per drawer

var/global/list/ship_designers = list() // mob -> sheet being drawn

// The window's pictures: every floor and fitting as its own sprite in the
// game, cut from the DMIs by scripts/build_ship_designer_icons.py (rerun it
// when ship_draught_floors or ship_draught_pieces change). A turning piece
// has one picture per facing. The window falls back to the letter of a piece
// whose picture is missing.
var/global/list/ship_designer_sprites = list(
	"shipd_floor_w.png" = 'icons/ship_designer/floor_w.png',
	"shipd_floor_s.png" = 'icons/ship_designer/floor_s.png',
	"shipd_piece_O.png" = 'icons/ship_designer/piece_O.png',
	"shipd_piece_T.png" = 'icons/ship_designer/piece_T.png',
	"shipd_piece_M.png" = 'icons/ship_designer/piece_M.png',
	"shipd_piece_R_1.png" = 'icons/ship_designer/piece_R_1.png',
	"shipd_piece_R_2.png" = 'icons/ship_designer/piece_R_2.png',
	"shipd_piece_R_4.png" = 'icons/ship_designer/piece_R_4.png',
	"shipd_piece_R_8.png" = 'icons/ship_designer/piece_R_8.png',
	"shipd_piece_K.png" = 'icons/ship_designer/piece_K.png',
	"shipd_piece_A.png" = 'icons/ship_designer/piece_A.png',
	"shipd_piece_P.png" = 'icons/ship_designer/piece_P.png',
	"shipd_piece_W.png" = 'icons/ship_designer/piece_W.png',
	"shipd_piece_D_1.png" = 'icons/ship_designer/piece_D_1.png',
	"shipd_piece_D_2.png" = 'icons/ship_designer/piece_D_2.png',
	"shipd_piece_D_4.png" = 'icons/ship_designer/piece_D_4.png',
	"shipd_piece_D_8.png" = 'icons/ship_designer/piece_D_8.png',
	"shipd_piece_G.png" = 'icons/ship_designer/piece_G.png',
	"shipd_piece_C.png" = 'icons/ship_designer/piece_C.png',
	"shipd_piece_B.png" = 'icons/ship_designer/piece_B.png',
)

// The names the window asks for: one picture for a floor or a fixed piece,
// one per facing for a piece that turns.
/proc/ship_designer_sprite_names()
	. = list()
	for (var/key in ship_draught_floors)
		. += "shipd_floor_[key].png"
	for (var/key in ship_draught_pieces)
		var/list/P = ship_draught_pieces[key]
		if (P["turns"])
			for (var/d in cardinal)
				. += "shipd_piece_[key]_[d].png"
		else
			. += "shipd_piece_[key].png"

/obj/item/ship_draught
	var/tmp/list/upload_parts = null
	var/tmp/upload_count = 0
	var/tmp/upload_mode = null
	var/tmp/upload_name = null
	var/tmp/last_preview = null

// The pen or pencil (or pigment) H holds in either hand, or null.
/proc/ship_designer_pen(mob/living/human/H)
	for (var/obj/item/I in list(H.get_active_hand(), H.get_inactive_hand()))
		if (istype(I, /obj/item/weapon/pen) || istype(I, /obj/item/pigment))
			return I
	return null

/proc/ship_designer_can_draw(mob/living/human/H, obj/item/ship_draught/S)
	return istype(H) && S && !QDELETED(S) && H.client && !H.incapacitated() && (S in H.get_contents()) && ship_designer_pen(H)

// Ready-made draughts to start from. Each one can be built as drawn (the
// probe checks).
/proc/ship_draught_examples()
	. = list()
	// A rowing galley: 27 planks, seven benches a side, steered from the stern.
	var/datum/ship_draught/galley = new
	galley.name = "rowing galley"
	for (var/x = 0, x < 3, x++)
		for (var/y = 0, y < 9, y++)
			galley.set_floor(x, y, "w")
	for (var/y = 1, y <= 7, y++)
		galley.set_piece(0, y, "R", EAST)
		galley.set_piece(2, y, "R", WEST)
	galley.set_piece(1, 0, "O")
	galley.set_piece(1, 8, "K")
	. += galley
	// A sloop: forty planks, two masts, a hold of crates and a pump.
	var/datum/ship_draught/sloop = new
	sloop.name = "sloop"
	for (var/x = 0, x < 4, x++)
		for (var/y = 0, y < 10, y++)
			sloop.set_floor(x, y, "w")
	sloop.set_piece(1, 0, "T")
	sloop.set_piece(1, 3, "M")
	sloop.set_piece(2, 7, "M")
	sloop.set_piece(0, 2, "C")
	sloop.set_piece(3, 2, "C")
	sloop.set_piece(2, 1, "P")
	sloop.set_piece(1, 9, "K")
	. += sloop
	// A steel cutter: a plated hull with a small cabin aft, one mast and oars.
	var/datum/ship_draught/cutter = new
	cutter.name = "steel cutter"
	for (var/x = 0, x < 5, x++)
		for (var/y = 0, y < 9, y++)
			cutter.set_floor(x, y, "s")
	cutter.set_piece(2, 0, "T")
	for (var/x = 0, x < 5, x++)
		if (x != 2)
			cutter.set_piece(x, 2, "W")
	cutter.set_piece(2, 2, "D")
	cutter.set_piece(0, 0, "B")
	cutter.set_piece(4, 0, "C")
	cutter.set_piece(2, 5, "M")
	for (var/y = 4, y <= 7, y++)
		cutter.set_piece(0, y, "R", EAST)
		cutter.set_piece(4, y, "R", WEST)
	cutter.set_piece(2, 8, "A")
	for (var/x = 0, x < 5, x++)
		for (var/y = 0, y < 2, y++)
			cutter.set_upper(x, y, TRUE)
	. += cutter

// The cells of a draught for the window, centred on the sheet's middle
// column, which the mirror reflects about:
// list(list(x, y, floor, piece, dir, upper), ...).
/proc/ship_designer_cells(datum/ship_draught/D)
	. = list()
	var/list/B = D ? D.extent() : null
	if (!B)
		return
	// Her middle column on the mirror line (the middle of the sheet).
	var/ox = round(SHIP_DRAUGHT_SIDE / 2) - (B[1] + round((B[3] - B[1]) / 2))
	var/oy = round((SHIP_DRAUGHT_SIDE - (B[4] - B[2] + 1)) / 2) - B[2]
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		var/list/xy = splittext(key, ",")
		. += list(list(text2num(xy[1]) + ox, text2num(xy[2]) + oy, C[1], C[2] ? C[2] : "", C[3], C[4] ? 1 : 0))

/obj/item/ship_draught/proc/open_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	var/obj/item/ship_draught/previous = ship_designers[H]
	if (previous && previous != src)
		previous.upload_parts = null
	ship_designers[H] = src
	var/datum/ship_draught/D = draught()
	for (var/sprite in ship_designer_sprites)
		H << browse_rsc(ship_designer_sprites[sprite], sprite)
	show_browse(H, ship_designer_html(src, D), "window=[SHIP_DESIGNER_WINDOW];size=1060x780")
	onclose(H, SHIP_DESIGNER_WINDOW, src)
	ship_designer_stats(H, D ? D : new /datum/ship_draught)
	if (D)
		qdel(D)

// Which heading of the window's palette each piece is drawn under. A piece
// in none of them goes under "Other", so a new piece still shows.
var/global/list/ship_designer_groups = list(
	"Steering and drive" = list("O", "T", "M", "R"),
	"Gear" = list("K", "A", "P", "C", "B"),
	"Cabin" = list("W", "D", "G"),
)

/proc/ship_designer_group(key)
	for (var/group in ship_designer_groups)
		if (key in ship_designer_groups[group])
			return group
	return "Other"

// The window is one page (ship_designer_page()) and one block of data: the
// palette is built from PIECES and FLOORS, so the tables in ship_draught.dm
// stay the only list of what a ship can be drawn with.
//   PIECES: list(key, name, turns, palette group, helm)
//   FLOORS: list(key, name)
/proc/ship_designer_html(obj/item/ship_draught/S, datum/ship_draught/D)
	var/list/pieces = list()
	for (var/key in ship_draught_pieces)
		var/list/P = ship_draught_pieces[key]
		pieces += list(list(key, P["name"], P["turns"] ? 1 : 0, ship_designer_group(key), P["helm"] ? 1 : 0))
	var/list/floors = list()
	for (var/key in ship_draught_floors)
		var/list/F = ship_draught_floors[key]
		floors += list(list(key, F["name"]))
	var/list/examples = list()
	for (var/datum/ship_draught/E in ship_draught_examples())
		examples += list(list(E.name, ship_designer_cells(E)))
		qdel(E)
	var/list/data = list(
		"N" = SHIP_DRAUGHT_SIDE,
		"MID" = round(SHIP_DRAUGHT_SIDE / 2),
		"REF" = "\ref[S]",
		"PART" = SHIP_DESIGNER_PART,
		"PIECES" = pieces,
		"FLOORS" = floors,
		"EXAMPLES" = examples,
		"START" = ship_designer_cells(D),
		"NAME" = D ? D.name : "ship",
	)
	var/list/halves = splittext(ship_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(data) + halves[2]

// Raw string: no DM interpolation inside, and no double quotes.
// The sheet is a view onto the 40x40 grid: Z pixels a tile, moved and zoomed
// freely. A click is turned into a tile from the canvas's own rectangle, so
// the drawing lands under the pointer however the window is sized.
/proc/ship_designer_page()
	return @{"<!doctype html><html><head><meta charset='utf-8'><title>Ship's draught</title><style>
:root{--line:#66513b;--dim:#bfae96;--bg:#211c16;--text:#eee5d3;--panel:#30271e;--accent:#b48c4d;--hi:#ffd985;--soft:#54432f;--chip:#443623;--inset:#262019;--good:#c4e8c0;--goodline:#6caa68;--goodbg:#253b25;--warn:#f3c79a;--warnline:#c77a39;--warnbg:#3a2a1a}
*{box-sizing:border-box}html,body{height:100%}
body{margin:0;background:var(--bg);color:var(--text);font:13px Verdana,sans-serif;overflow:hidden;display:flex;flex-direction:column;user-select:none}
#top{flex:0 0 auto;display:flex;align-items:center;gap:10px;padding:9px 12px 8px;border-bottom:1px solid var(--line)}
#top h1{font-size:17px;margin:0 6px 0 0;white-space:nowrap}
input,select{background:var(--inset);color:var(--text);border:1px solid var(--line);border-radius:3px;font:13px Verdana,sans-serif;padding:5px 7px}
button{background:var(--chip);color:var(--text);border:0;border-radius:3px;font:13px Verdana,sans-serif;padding:6px 10px;cursor:pointer}
button:hover{background:#544329}
button.on,button.on:hover{background:var(--accent);color:#2a1d0c;font-weight:bold}
button.primary,button.primary:hover{background:var(--accent);color:#fff;padding:7px 16px}
button:focus-visible,input:focus-visible,select:focus-visible{outline:2px solid var(--hi);outline-offset:1px}
#st{font-size:12px;color:var(--dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
#st.dirty{color:var(--hi)}#st.bad{color:var(--warn)}
.sp{flex:1 1 auto}.dim{color:var(--dim)}
#main{flex:1 1 auto;min-height:0;display:flex;gap:12px;padding:10px 12px}
#sheetcol{flex:1 1 auto;min-width:0;display:flex;flex-direction:column}
#sheetbar{flex:0 0 auto;display:flex;align-items:center;gap:6px;margin-bottom:6px}
#frame{flex:1 1 auto;min-height:0;position:relative;border:2px solid var(--line);background:#1b1611;overflow:hidden}
#c{position:absolute;left:0;top:0;cursor:crosshair}
.edge{position:absolute;font:bold 10px Verdana,sans-serif;letter-spacing:2px;color:#f3e6c4;background:rgba(33,28,22,0.72);padding:2px 6px;border-radius:2px;pointer-events:none}
#hover{flex:0 0 auto;margin-top:6px;color:var(--dim);height:17px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#hover b{color:var(--text);font-weight:normal}
#side{flex:0 0 372px;min-height:0;overflow-y:auto;display:flex;flex-direction:column;gap:10px}
.sec{flex:0 0 auto;border:1px solid var(--line);background:var(--panel)}
.sec h2{font-size:14px;margin:0;padding:7px 9px;border-bottom:2px solid var(--accent)}
.sec .in{padding:8px 9px}
.grp{color:var(--dim);font-size:11px;margin:5px 0 2px}.grp:first-child{margin-top:0}
.pal{display:grid;grid-template-columns:repeat(5,1fr);gap:4px}
button.tile{padding:3px 1px 2px;text-align:center;font-size:10px;line-height:1.15;border:2px solid transparent;font-weight:normal}
button.tile canvas{width:32px;height:32px;display:block;margin:0 auto 2px;border-radius:2px;image-rendering:pixelated}
button.tile.on,button.tile.on:hover{border-color:var(--hi);background:#5a4526;color:var(--text);font-weight:normal}
.row{display:flex;align-items:center;gap:4px;margin-top:6px}.row .lab{color:var(--dim);width:52px}
.row.off .seg{opacity:0.4}
.seg{display:inline-flex}.seg button{border-radius:0;border-right:1px solid var(--bg)}.seg button:first-child{border-radius:3px 0 0 3px}.seg button:last-child{border-radius:0 3px 3px 0;border-right:0}
kbd{background:#17130f;border:1px solid var(--line);border-radius:3px;padding:0 4px;font:11px Verdana,sans-serif;color:var(--dim)}
table{border-collapse:collapse;width:100%}td{padding:4px 0;border-bottom:1px solid var(--soft);vertical-align:top}td:first-child{color:var(--dim);width:64px}tr:last-child td{border-bottom:0}
.bar{height:8px;background:#17130f;border:1px solid var(--line);border-radius:4px;overflow:hidden;margin-top:4px}.bar i{display:block;height:100%;background:var(--accent)}.bar.over i{background:var(--warnline)}
.chip{display:inline-block;background:var(--chip);border-radius:3px;padding:2px 6px;margin:0 3px 3px 0}
.note{margin-top:8px;padding:6px 8px;border-radius:3px;border:1px solid var(--line);color:var(--dim)}
.note.ok{background:var(--goodbg);border-color:var(--goodline);color:var(--good)}
.note.bad{background:var(--warnbg);border-color:var(--warnline);color:var(--warn)}
.note div{margin-top:3px}
</style></head><body>
<div id='top'><h1>Ship's draught</h1><input id='nm' maxlength='40' style='width:210px' title='Her name'><span id='st'></span><span class='sp'></span><span class='dim'>Start from</span><select id='ex' title='Ready-made draughts to start from'><option value=''>a ready-made ship...</option></select><button class='primary' id='save'>Save to the sheet</button></div>
<div id='main'><div id='sheetcol'>
<div id='sheetbar'><span class='dim'>Zoom</span><span class='seg'><button id='z_sheet'>Whole sheet</button><button id='z_ship'>Fit ship</button><button id='z_in' title='Closer (mouse wheel)'>+</button><button id='z_out' title='Further (mouse wheel)'>-</button></span><span class='sp'></span><button id='b_undo' title='Undo'>Undo <kbd>Ctrl Z</kbd></button><button id='b_redo' title='Redo (Ctrl Y)'>Redo</button><button id='b_clear' title='Wipe the sheet (Undo brings it back)'>Clear</button></div>
<div id='frame'><canvas id='c'></canvas><div class='edge' style='left:50%;top:5px;transform:translateX(-50%)'>BOW</div><div class='edge' style='left:50%;bottom:5px;transform:translateX(-50%)'>STERN</div><div class='edge' style='left:5px;top:50%;transform:translateY(-50%)'>PORT</div><div class='edge' style='right:5px;top:50%;transform:translateY(-50%)'>STARBOARD</div></div>
<div id='hover'></div></div>
<div id='side'>
<div class='sec'><h2>Draw</h2><div class='in'><div id='pal'></div>
<div class='row' id='facerow'><span class='lab'>Facing</span><span class='seg'><button id='f_1' title='Facing the bow'>&uarr;</button><button id='f_4' title='Facing starboard'>&rarr;</button><button id='f_2' title='Facing the stern'>&darr;</button><button id='f_8' title='Facing port'>&larr;</button></span><kbd title='R turns the piece'>R</kbd><span class='sp'></span><span class='seg'><button id='m_free' title='Draw tile by tile'>Freehand</button><button id='m_box' title='Drag out a box of tiles'>Box</button></span></div>
<div class='row'><span class='lab'>Mirror</span><span class='seg'><button id='m_on'>On</button><button id='m_off'>Off</button></span><span class='dim' style='font-size:11px;margin-left:4px'>port and starboard match</span></div>
</div></div>
<div class='sec'><h2>Her figures</h2><div class='in' id='fig'><span class='dim'>Reckoning...</span></div></div>
</div></div>
<script>var DATA=@@DATA@@;
var N=DATA.N,MID=DATA.MID,REF=DATA.REF,PART=DATA.PART,PIECES=DATA.PIECES,FLOORS=DATA.FLOORS,EXAMPLES=DATA.EXAMPLES;
function $(i){return document.getElementById(i);}
var cv=$('c'),g=cv.getContext('2d'),frame=$('frame');
var cells={},t=FLOORS[0][0],fd=1,box=false,mirror=false,undos=[],redos=[],down=null,pan=null,hov=null,before=null;
var parts=null,busy=0,timer=null,IMG={},Z=16,vx=0,vy=0,fit='ship',rev=0,savedRev=0,sendRev=0,note='',noteBad=false;
var ZOOMS=[8,12,16,24,32,48],INK='#2a1a0c',GOLD='#ffd985',PAPER='#d8c8a2';
var NAMES={},FNAMES={},ICONS=[];
for(var i=0;i<PIECES.length;i++)NAMES[PIECES[i][0]]=PIECES[i];
for(var i=0;i<FLOORS.length;i++)FNAMES[FLOORS[i][0]]=FLOORS[i][1];
var FACING={1:'the bow',2:'the stern',4:'starboard',8:'port'};
var WASH={w:'rgba(150,100,56,0.5)',s:'rgba(150,156,164,0.45)'},FLAT={w:'#9a6a3a',s:'#8a9098'};
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function cap(s){return s.charAt(0).toUpperCase()+s.substring(1);}
function key(x,y){return x+','+y;}
function load(list){cells={};for(var i=0;i<list.length;i++){var c=list[i];cells[key(c[0],c[1])]=[c[2],c[3],c[4],c[5]];}}
function shown(i){return i&&i.complete&&i.naturalWidth>0;}
function pic(n){if(!IMG[n]){var i=new Image();i.onload=function(){draw();icons();};i.src='shipd_'+n+'.png';IMG[n]=i;}return IMG[n];}
function pieceName(k,d){return 'piece_'+k+(NAMES[k]&&NAMES[k][2]?'_'+d:'');}
function turns(k){return NAMES[k]&&NAMES[k][2];}

// ---- The view: Z pixels a tile, (vx, vy) the corner of the frame on the sheet ----
function clampView(){var W=cv.width,H=cv.height,S=N*Z;
vx=S<=W?-Math.floor((W-S)/2):Math.min(Math.max(vx,0),S-W);vy=S<=H?-Math.floor((H-S)/2):Math.min(Math.max(vy,0),S-H);}
function extent(){var b=null;for(var k in cells){var p=k.split(','),x=+p[0],y=+p[1];if(!b)b=[x,y,x,y];else{b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x);b[3]=Math.max(b[3],y);}}return b;}
function applyFit(){var W=cv.width,H=cv.height,whole=Math.max(4,Math.floor(Math.min(W,H)/N)),b=fit=='ship'?extent():null;
if(!b){Z=whole;vx=0;vy=0;clampView();return;}
var w=b[2]-b[0]+5,h=b[3]-b[1]+5;Z=Math.max(whole,Math.min(32,Math.floor(Math.min(W/w,H/h))));
vx=Math.round((b[0]+b[2]+1)/2*Z-W/2);vy=Math.round((N-(b[1]+b[3]+1)/2)*Z-H/2);clampView();}
function setFit(f){fit=f;applyFit();mark();draw();}
function zoom(dir,px,py){var i=0;if(dir>0){while(i<ZOOMS.length-1&&ZOOMS[i]<=Z)i++;}else{i=ZOOMS.length-1;while(i>0&&ZOOMS[i]>=Z)i--;}
var nz=ZOOMS[i];if(nz==Z)return;var ux=(px+vx)/Z,uy=(py+vy)/Z;Z=nz;vx=Math.round(ux*Z-px);vy=Math.round(uy*Z-py);fit='';clampView();mark();draw();}
function resize(){var W=frame.clientWidth,H=frame.clientHeight;if(W<8||H<8)return;cv.width=W;cv.height=H;cv.style.width=W+'px';cv.style.height=H+'px';if(fit)applyFit();else clampView();draw();}
function sx(x){return x*Z-vx;}
function sy(y){return (N-1-y)*Z-vy;}

// ---- Drawing the sheet ----
function hatch(c,px,py,k){c.save();c.beginPath();c.rect(px,py,k,k);c.clip();c.strokeStyle='rgba(255,217,133,0.6)';c.lineWidth=Math.max(1,k/16);var st=Math.max(3,k/4);for(var i=-k;i<k;i+=st){c.beginPath();c.moveTo(px+i,py+k);c.lineTo(px+i+k,py);c.stroke();}c.restore();}
function floorAt(c,f,px,py,k){c.fillStyle=FLAT[f]||'#888';c.fillRect(px,py,k,k);var i=pic('floor_'+f);if(shown(i)){c.drawImage(i,px,py,k,k);c.fillStyle=WASH[f]||'rgba(128,128,128,0.4)';c.fillRect(px,py,k,k);}}
function pieceAt(c,p,d,px,py,k){var i=pic(pieceName(p,d));if(shown(i)){c.drawImage(i,px,py,k,k);return;}
c.fillStyle='#fff';c.strokeStyle='#000';c.lineWidth=2;c.font='bold '+Math.max(9,Math.floor(k*0.6))+'px Verdana';c.textAlign='center';c.textBaseline='middle';c.strokeText(p,px+k/2,py+k/2);c.fillText(p,px+k/2,py+k/2);}
function arrowAt(c,d,px,py,k){var a=Math.max(3,k/6),cx=px+k/2,cy=py+k/2,r=k/2-1,ux=d==4?1:(d==8?-1:0),uy=d==2?1:(d==1?-1:0);
var tx=cx+ux*r,ty=cy+uy*r,bx=tx-ux*a,by=ty-uy*a;c.beginPath();c.moveTo(tx,ty);c.lineTo(bx-uy*a*0.8,by+ux*a*0.8);c.lineTo(bx+uy*a*0.8,by-ux*a*0.8);c.closePath();c.fillStyle=GOLD;c.fill();c.strokeStyle='#1a1008';c.lineWidth=1;c.stroke();}
function mirrorDir(d){return d==4?8:(d==8?4:d);}
function mirrorX(x){return 2*MID-x;}
function onSheet(x,y){return x>=0&&y>=0&&x<N&&y<N;}
function ghost(x,y,d){if(!onSheet(x,y))return;var px=sx(x),py=sy(y),c=cells[key(x,y)],ok=true;g.globalAlpha=0.7;
if(FNAMES[t])floorAt(g,t,px,py,Z);else if(t=='u'){if(c)hatch(g,px,py,Z);else ok=false;}else if(t!='x'){if(c)pieceAt(g,t,d,px,py,Z);else ok=false;}
g.globalAlpha=1;g.lineWidth=2;g.strokeStyle=ok&&t!='x'?GOLD:'#c0492b';g.strokeRect(px+1,py+1,Z-2,Z-2);
if(t=='x'||!ok){g.beginPath();g.moveTo(px+4,py+4);g.lineTo(px+Z-4,py+Z-4);g.moveTo(px+Z-4,py+4);g.lineTo(px+4,py+Z-4);g.stroke();}}
function boxOutline(x0,y0,x1,y1){g.lineWidth=2;g.strokeStyle=GOLD;g.strokeRect(sx(Math.min(x0,x1))+1,sy(Math.max(y0,y1))+1,(Math.abs(x1-x0)+1)*Z-2,(Math.abs(y1-y0)+1)*Z-2);}
function draw(){var W=cv.width,H=cv.height,S=N*Z,ox=-vx,oy=-vy;g.setLineDash([]);g.globalAlpha=1;
g.fillStyle='#1b1611';g.fillRect(0,0,W,H);g.fillStyle=PAPER;g.fillRect(ox,oy,S,S);g.imageSmoothingEnabled=Z%32!=0;
g.lineWidth=1;for(var i=0;i<=N;i++){g.strokeStyle=(i-MID)%5==0?'rgba(110,86,50,0.5)':'rgba(110,86,50,0.25)';
g.beginPath();g.moveTo(ox+i*Z+0.5,oy);g.lineTo(ox+i*Z+0.5,oy+S);g.stroke();g.beginPath();g.moveTo(ox,oy+i*Z+0.5);g.lineTo(ox+S,oy+i*Z+0.5);g.stroke();}
var k,c,p,x,y,px,py;
for(k in cells){c=cells[k];p=k.split(',');px=sx(+p[0]);py=sy(+p[1]);if(px+Z<0||py+Z<0||px>W||py>H)continue;
floorAt(g,c[0],px,py,Z);if(c[1]){pieceAt(g,c[1],c[2],px,py,Z);if(turns(c[1]))arrowAt(g,c[2],px,py,Z);}if(c[3])hatch(g,px,py,Z);}
g.strokeStyle=INK;g.lineWidth=Z>=16?2:1;g.beginPath();
for(k in cells){p=k.split(',');x=+p[0];y=+p[1];px=sx(x);py=sy(y);
if(!cells[key(x+1,y)]){g.moveTo(px+Z,py);g.lineTo(px+Z,py+Z);}if(!cells[key(x-1,y)]){g.moveTo(px,py);g.lineTo(px,py+Z);}
if(!cells[key(x,y+1)]){g.moveTo(px,py);g.lineTo(px+Z,py);}if(!cells[key(x,y-1)]){g.moveTo(px,py+Z);g.lineTo(px+Z,py+Z);}}
g.stroke();
g.setLineDash([6,5]);g.strokeStyle='rgba(120,60,30,0.75)';g.lineWidth=1;g.beginPath();g.moveTo(ox+(MID+0.5)*Z,oy);g.lineTo(ox+(MID+0.5)*Z,oy+S);g.stroke();g.setLineDash([]);
if(pan||!hov)return;
if(down&&box){boxOutline(down[0],down[1],hov[0],hov[1]);if(mirror)boxOutline(mirrorX(down[0]),down[1],mirrorX(hov[0]),hov[1]);return;}
ghost(hov[0],hov[1],fd);if(mirror&&mirrorX(hov[0])!=hov[0])ghost(mirrorX(hov[0]),hov[1],mirrorDir(fd));}

// ---- The palette ----
function paintIcon(I){var c=I[0].getContext('2d'),k=I[1];c.imageSmoothingEnabled=false;c.clearRect(0,0,32,32);
if(FNAMES[k]){floorAt(c,k,0,0,32);return;}
if(k=='u'){floorAt(c,FLOORS[0][0],0,0,32);hatch(c,0,0,32);return;}
if(k=='x'){c.fillStyle=PAPER;c.fillRect(0,0,32,32);c.strokeStyle='#c0492b';c.lineWidth=4;c.beginPath();c.moveTo(8,8);c.lineTo(24,24);c.moveTo(24,8);c.lineTo(8,24);c.stroke();return;}
c.fillStyle='#1b1611';c.fillRect(0,0,32,32);pieceAt(c,k,turns(k)?fd:1,0,0,32);}
function icons(){for(var i=0;i<ICONS.length;i++)paintIcon(ICONS[i]);}
function tile(into,k,name,tip){var b=document.createElement('button'),c=document.createElement('canvas');b.className='tile';b.id='t_'+k;b.title=tip;c.width=32;c.height=32;
b.appendChild(c);b.appendChild(document.createTextNode(name));b.onclick=function(){tool(k);};into.appendChild(b);ICONS.push([c,k]);}
function group(name){var h=document.createElement('div'),d=document.createElement('div');h.className='grp';h.appendChild(document.createTextNode(name));d.className='pal';$('pal').appendChild(h);$('pal').appendChild(d);return d;}
function palette(){var hull=group('Hull'),G={},i;
for(i=0;i<FLOORS.length;i++)tile(hull,FLOORS[i][0],cap(FLOORS[i][1]),'Lay '+FLOORS[i][1]);
tile(hull,'u','Deck above','A deck on the level above this tile. Right-click takes it off.');tile(hull,'x','Erase','Take the whole tile off the sheet');
for(i=0;i<PIECES.length;i++){var P=PIECES[i];if(!G[P[3]])G[P[3]]=group(P[3]);tile(G[P[3]],P[0],cap(P[1]),cap(P[1])+(P[2]?' (turn it with R)':''));}}
function mark(){var b=document.getElementsByTagName('button'),i,id;for(i=0;i<b.length;i++){id=b[i].id;
if(id.indexOf('t_')==0)b[i].className=id=='t_'+t?'tile on':'tile';if(id.indexOf('f_')==0)b[i].className=id=='f_'+fd?'on':'';}
$('m_box').className=box?'on':'';$('m_free').className=box?'':'on';$('m_on').className=mirror?'on':'';$('m_off').className=mirror?'':'on';
$('z_sheet').className=fit=='sheet'?'on':'';$('z_ship').className=fit=='ship'?'on':'';$('facerow').className=turns(t)?'row':'row off';}
function tool(x){t=x;mark();draw();}
function face(d){fd=d;icons();mark();draw();}
function turn(){face({1:4,4:2,2:8,8:1}[fd]);}

// ---- Changing the drawing ----
function apply(x,y,alt,d){if(!onSheet(x,y))return;var k=key(x,y),c=cells[k];
if(alt){if(c){if(t=='u')c[3]=0;else c[1]='';}return;}
if(FNAMES[t]){if(c)c[0]=t;else cells[k]=[t,'',1,0];return;}
if(t=='x'){delete cells[k];return;}
if(!c)return;
if(t=='u'){c[3]=1;return;}
c[1]=t;c[2]=d;}
function at(x,y,alt){apply(x,y,alt,fd);var m=mirrorX(x);if(mirror&&m!=x)apply(m,y,alt,mirrorDir(fd));}
function begin(){before=JSON.stringify(cells);}
function commit(){if(before===null)return;var b=before;before=null;if(b==JSON.stringify(cells))return;undos.push(b);if(undos.length>80)undos.shift();redos=[];changed();}
function undo(){if(!undos.length)return;redos.push(JSON.stringify(cells));cells=JSON.parse(undos.pop());draw();changed();}
function redo(){if(!redos.length)return;undos.push(JSON.stringify(cells));cells=JSON.parse(redos.pop());draw();changed();}
function clearAll(){begin();cells={};commit();draw();}
function loadExample(){var v=$('ex').value;if(v==='')return;begin();var e=EXAMPLES[parseInt(v,10)];load(e[1]);$('nm').value=e[0];$('ex').value='';commit();setFit('ship');}
function pos(e){var r=cv.getBoundingClientRect(),px=(e.clientX-r.left)*cv.width/r.width,py=(e.clientY-r.top)*cv.height/r.height;return [Math.floor((px+vx)/Z),N-1-Math.floor((py+vy)/Z),px,py];}
function tell(){var h=$('hover');if(!hov||!onSheet(hov[0],hov[1])){h.innerHTML='Click or drag to draw. Right-click takes a fitting off. The wheel zooms; drag with the middle button to move the sheet.';return;}
var c=cells[key(hov[0],hov[1])];if(!c){h.innerHTML=NAMES[t]||t=='u'?'Bare sheet: lay a floor here first.':'Bare sheet.';return;}
var s='';if(c[1]&&NAMES[c[1]]){s='<b>'+esc(cap(NAMES[c[1]][1]))+'</b>'+(turns(c[1])?' facing '+FACING[c[2]]:'')+' on ';}
s+='<b>'+esc(s?FNAMES[c[0]]:cap(FNAMES[c[0]]||'floor'))+'</b>';if(c[3])s+=' &middot; deck above';h.innerHTML=s;}
cv.oncontextmenu=function(){return false;};
cv.onmousedown=function(e){var p=pos(e);if(e.button==1){pan=[e.clientX,e.clientY,vx,vy];e.preventDefault();return;}
begin();down=[p[0],p[1],e.button==2,key(p[0],p[1])];hov=p;if(!box)at(p[0],p[1],down[2]);draw();};
cv.onmousemove=function(e){var p=pos(e);if(pan)return;var moved=!hov||hov[0]!=p[0]||hov[1]!=p[1];hov=p;if(!moved)return;tell();
if(down&&!box){var k=key(p[0],p[1]);if(k!=down[3]&&!(NAMES[t]&&NAMES[t][4]&&!down[2])){down[3]=k;at(p[0],p[1],down[2]);}}draw();};
cv.onmouseleave=function(){if(down)return;hov=null;tell();draw();};
document.onmousemove=function(e){if(!pan)return;vx=pan[2]-(e.clientX-pan[0]);vy=pan[3]-(e.clientY-pan[1]);fit='';clampView();mark();draw();};
document.onmouseup=function(e){if(pan){pan=null;draw();return;}if(!down)return;
if(box){var p=pos(e),x0=Math.min(down[0],p[0]),x1=Math.max(down[0],p[0]),y0=Math.min(down[1],p[1]),y1=Math.max(down[1],p[1]);
for(var y=Math.max(0,y0);y<=Math.min(N-1,y1);y++)for(var x=Math.max(0,x0);x<=Math.min(N-1,x1);x++)at(x,y,down[2]);}
down=null;commit();tell();draw();};
cv.addEventListener('wheel',function(e){e.preventDefault();var p=pos(e);zoom(e.deltaY<0?1:-1,p[2],p[3]);},{passive:false});
document.onkeydown=function(e){var tag=(e.target&&e.target.tagName)||'';if(tag=='INPUT'||tag=='SELECT')return;var k=(e.key||'').toLowerCase();
if(e.ctrlKey&&k=='z'){e.preventDefault();if(e.shiftKey)redo();else undo();}else if(e.ctrlKey&&k=='y'){e.preventDefault();redo();}
else if(k=='r'&&!e.ctrlKey){turn();}};

// ---- Talking to the server: it reckons every figure ----
function status(){var s=$('st');if(note){s.className=noteBad?'bad':'';s.innerHTML=esc(note);}else if(rev!=savedRev){s.className='dirty';s.innerHTML='&#9679; Unsaved changes';}else{s.className='';s.innerHTML='';}}
function say(s,bad){note=s;noteBad=!!bad;status();}
function code(){var out=[];for(var k in cells){var c=cells[k];out.push(k+','+c[0]+','+(c[1]||'-')+','+c[2]+','+(c[3]?1:0));}return 'C13SHIP/1/ship/'+out.join(';');}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function changed(){rev++;note='';status();preview();}
function preview(){if(timer)clearTimeout(timer);timer=setTimeout(function(){timer=null;send('preview');},600);}
function waiting(){return busy&&new Date().getTime()-busy<5000;}
function send(m){if(waiting()){if(m=='save')say('Wait a moment...');else preview();return;}var p=code();parts=[];for(var j=0;j<p.length;j+=PART)parts.push(p.substring(j,j+PART));if(!parts.length)parts.push('');
busy=new Date().getTime();if(m=='save'){sendRev=rev;say('Saving...');}go('ship=begin&n='+parts.length+'&mode='+m+'&name='+encodeURIComponent($('nm').value));}
function shipAck(n){n=parseInt(n,10);if(!parts)return;if(n<parts.length){go('ship=part&i='+n+'&d='+encodeURIComponent(parts[n]));return;}parts=null;go('ship=end');}
function txt(s){s=(s+'').replace(/\+/g,' ');try{return decodeURIComponent(s);}catch(e){return s;}}
function row(a,b){return '<tr><td>'+a+'</td><td>'+b+'</td></tr>';}
function figures(F){var h='<table>',i,over=F.tiles>F.max_tiles,decks=F.tiles+F.upper;
h+=row('Size','<b>'+esc(cap(F['class']))+'</b> &middot; '+F.tiles+' of '+F.max_tiles+' hull tiles<div class=\'bar'+(over?' over':'')+'\'><i style=\'width:'+Math.min(100,F.tiles*100/F.max_tiles)+'%\'></i></div>');
h+=row('Decks',F.upper?F.upper+' tile'+(F.upper==1?'':'s')+' of deck above &middot; '+decks+' of '+F.max_deck+' in all':'No deck above');
if(F.tiles){var c='';for(i=0;i<F.costs.length;i++)c+='<span class=\'chip\'>'+esc(F.costs[i])+'</span>';h+=row('Cost',c||'nothing');
var d=[];for(i=0;i<F.drives.length;i++)d.push(esc(F.drives[i][0])+' <b>'+esc(F.drives[i][1])+'</b>');
h+=row('Speed',d.length?d.join(' &middot; '):'<b>Slow ahead</b>, poled along: she has no masts or rowing benches');
if(F.ballast)h+=row('Ballast','Wants about '+F.ballast+' more tiles of weight low in her, or she sails crank');}
h+='</table>';
if(!F.tiles)h+='<div class=\'note\'>'+esc(F.problems[0]||'Nothing is drawn yet.')+'</div>';
else if(F.problems.length){h+='<div class=\'note bad\'><b>Not ready to build</b>';for(i=0;i<F.problems.length;i++)h+='<div>'+esc(F.problems[i])+'</div>';h+='</div>';}
else h+='<div class=\'note ok\'><b>Ready to build.</b> As drawn she can be built and commissioned.</div>';
$('fig').innerHTML=h;}
function shipStats(s){busy=0;s=txt(s);try{figures(JSON.parse(s));}catch(e){$('fig').innerHTML=s;}}
function shipStatus(s){busy=0;s=txt(s);if(s=='Saved on the sheet.')return;if(s)say(s,true);else if(note=='Saving...'||note=='Wait a moment...')say('');}
function shipSaved(){busy=0;savedRev=sendRev;say(rev==savedRev?'Saved on the sheet.':'');}

// ---- Setting up ----
$('f_1').onclick=function(){face(1);};$('f_4').onclick=function(){face(4);};$('f_2').onclick=function(){face(2);};$('f_8').onclick=function(){face(8);};
$('m_free').onclick=function(){box=false;mark();};$('m_box').onclick=function(){box=true;mark();};
$('m_on').onclick=function(){mirror=true;mark();draw();};$('m_off').onclick=function(){mirror=false;mark();draw();};
$('z_sheet').onclick=function(){setFit('sheet');};$('z_ship').onclick=function(){setFit('ship');};
$('z_in').onclick=function(){zoom(1,cv.width/2,cv.height/2);};$('z_out').onclick=function(){zoom(-1,cv.width/2,cv.height/2);};
$('b_undo').onclick=undo;$('b_redo').onclick=redo;$('b_clear').onclick=clearAll;$('save').onclick=function(){send('save');};
$('ex').onchange=loadExample;$('nm').oninput=function(){changed();};
(function(){var s=$('ex');for(var i=0;i<EXAMPLES.length;i++){var o=document.createElement('option');o.value=i;o.appendChild(document.createTextNode(cap(EXAMPLES[i][0])));s.appendChild(o);}})();
$('nm').value=DATA.NAME;load(DATA.START);palette();icons();mark();tell();resize();window.onresize=resize;
</script></body></html>
"}

/proc/ship_designer_ack(mob/user, n)
	user << output(list2params(list("[n]")), "[SHIP_DESIGNER_WINDOW].browser:shipAck")

/proc/ship_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[SHIP_DESIGNER_WINDOW].browser:shipStatus")

// The figures go as fields (summary_data()); the window lays them out.
/proc/ship_designer_stats(mob/user, datum/ship_draught/D)
	user << output(list2params(list(json_encode(D.summary_data()))), "[SHIP_DESIGNER_WINDOW].browser:shipStats")

// Tells the window its drawing is the one on the sheet now.
/proc/ship_designer_saved(mob/user)
	user << output(null, "[SHIP_DESIGNER_WINDOW].browser:shipSaved")

/obj/item/ship_draught/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H && ship_designers[H] == src)
			ship_designers -= H
		upload_parts = null
		return
	if (!href_list["ship"])
		return ..()
	if (!istype(H) || ship_designers[H] != src)
		return
	if (!ship_designer_can_draw(H, src))
		ship_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	switch (href_list["ship"])
		if ("begin")
			var/n = text2num(href_list["n"])
			var/max_parts = CEILING(DESIGN_CODE_SHIP_MAX / SHIP_DESIGNER_PART, 1)
			if (!isnum(n) || n < 1 || n > max_parts || n != round(n) || !(href_list["mode"] in list("preview", "save")))
				ship_designer_status(H, "The drawing could not be sent.")
				return
			upload_parts = list()
			upload_count = n
			upload_mode = href_list["mode"]
			upload_name = href_list["name"]
			ship_designer_ack(H, 0)
		if ("part")
			var/i = text2num(href_list["i"])
			var/d = href_list["d"]
			if (!upload_parts || !isnum(i) || i != upload_parts.len || i >= upload_count || !istext(d) || length(d) > SHIP_DESIGNER_PART)
				upload_parts = null
				ship_designer_status(H, "The drawing could not be sent.")
				return
			upload_parts += d
			ship_designer_ack(H, i + 1)
		if ("end")
			var/list/got = upload_parts
			upload_parts = null
			if (!got || got.len != upload_count)
				ship_designer_status(H, "The drawing could not be sent.")
				return
			var/result = accept_drawing(H, jointext(got, ""), upload_name, upload_mode == "save")
			if (!isnull(result))
				ship_designer_status(H, result)

// Reads a drawing sent from the window. A preview answers with the summary;
// a save keeps it on the sheet. Returns a status line, or null when the
// summary alone answers.
/obj/item/ship_draught/proc/accept_drawing(mob/living/human/H, code, new_name, save)
	// Too soon after the last summary: the window only needs to know it may
	// send again.
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + SHIP_DESIGNER_PREVIEW_GAP)
			return ""
		last_preview = world.time
	// An empty sheet sends no tiles: "C13SHIP/1/ship/".
	var/datum/ship_draught/D = ship_draught_from_code(code)
	if (!D)
		return "The drawing could not be read. It may be too big for one sheet."
	D.name = ship_draught_clean_name(new_name)
	ship_designer_stats(H, D)
	if (save)
		take(D)
		qdel(D)
		ship_designer_saved(H)
		return "Saved on the sheet."
	qdel(D)
	return null

#undef SHIP_DESIGNER_WINDOW
#undef SHIP_DESIGNER_PART
#undef SHIP_DESIGNER_PREVIEW_GAP
