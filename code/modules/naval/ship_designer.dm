// ============================================================
// The ship designer (docs/ship-draught.md): drawing a ship's draught
// ------------------------------------------------------------
// Hold a ship's draught and a pen or pencil and choose "Draw on the sheet":
// a browser window shows the sheet as a grid, bow to the top. Floors, decks
// above and fittings are painted on it; a rectangle tool and a mirror for
// port and starboard save work. Every change is sent to the server, which
// reads it as a design code and answers with the draught's own summary:
// tiles, size class, cost, speed and what still stops her being built. The
// estimate is always the server's, so the window never disagrees with the
// sheet or the ship.
//
// Save keeps the drawing on the sheet, finished or not. The server checks the
// code like a pasted one, so nothing drawn here goes past the draught's rules.
// ============================================================

#define SHIP_DESIGNER_WINDOW "ship_designer"
#define SHIP_DESIGNER_PART 900 // characters per upload part
#define SHIP_DESIGNER_PREVIEW_GAP 3 // deciseconds between summaries per drawer

var/global/list/ship_designers = list() // mob -> sheet being drawn

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
	show_browse(H, ship_designer_html(src, D), "window=[SHIP_DESIGNER_WINDOW];size=900x700")
	onclose(H, SHIP_DESIGNER_WINDOW, src)
	ship_designer_stats(H, D ? D : new /datum/ship_draught)
	if (D)
		qdel(D)

/proc/ship_designer_html(obj/item/ship_draught/S, datum/ship_draught/D)
	var/list/pieces = list()
	for (var/key in ship_draught_pieces)
		var/list/P = ship_draught_pieces[key]
		pieces += list(list(key, P["name"], P["turns"] ? 1 : 0))
	var/list/examples = list()
	for (var/datum/ship_draught/E in ship_draught_examples())
		examples += list(list(E.name, ship_designer_cells(E)))
		qdel(E)
	var/list/html = list("<html><head><meta charset='utf-8'><title>Ship's draught</title><style>")
	html += "body{background:#2b2622;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:6px}"
	html += "#wrap{display:flex;gap:10px}canvas{border:2px solid #5a3d22;cursor:crosshair;background:#20303a}"
	html += "button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;margin:1px;padding:3px 6px;cursor:pointer}button.on{background:#a07040;color:#fff}"
	html += "#side{width:290px}#stats{margin-top:6px;padding:4px;background:#1d1916;border:1px solid #5a3d22;min-height:80px}#st{margin-top:4px;color:#e0c070;min-height:16px}.warning{color:#e08060}"
	html += "input,select{background:#1d1916;color:#e9dfc8;border:1px solid #806040}.hint{color:#b0a080}</style></head><body><div id='wrap'><canvas id='c'></canvas><div id='side'>"
	html += "<div>Name: <input id='nm' maxlength='40' style='width:200px' value='[html_encode(D ? D.name : "ship")]'></div>"
	html += "<div style='margin-top:4px'>Floors: <button id='t_w' onclick=\"tool('w')\">Planks</button><button id='t_s' onclick=\"tool('s')\">Steel</button><button id='t_x' onclick=\"tool('x')\">Erase</button></div>"
	html += "<div>Deck above: <button id='t_u' onclick=\"tool('u')\">Add</button><button id='t_n' onclick=\"tool('n')\">Remove</button></div>"
	html += "<div style='margin-top:4px'>Fittings:</div><div id='pcs'></div>"
	html += "<div>Facing: <button id='f_1' onclick='face(1)'>N</button><button id='f_4' onclick='face(4)'>E</button><button id='f_2' onclick='face(2)'>S</button><button id='f_8' onclick='face(8)'>W</button> <span class='hint'>(benches, doors)</span></div>"
	html += "<div style='margin-top:4px'><button id='m_r' onclick='toggleRect()'>Rectangle</button><button id='m_m' onclick='toggleMirror()'>Mirror port/starboard</button><button onclick='undo()'>Undo</button><button onclick='clearAll()'>Clear</button></div>"
	html += "<div style='margin-top:4px'>Start from: <select id='ex'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>"
	html += "<div id='stats'></div><div id='st'></div>"
	html += "<div style='margin-top:6px'><button onclick=\"send('save')\">Save to the sheet</button></div>"
	html += "<div class='hint' style='margin-top:6px'>The bow is the top of the sheet. Click or drag to draw; right-click erases the fitting on a tile. The ship needs one tiller or steering oar. The design code of a saved sheet can be copied from the sheet itself.</div>"
	html += "</div></div><script>"
	html += "var N=[SHIP_DRAUGHT_SIDE],MID=[round(SHIP_DRAUGHT_SIDE / 2)],K=16,REF='\ref[S]',PART=[SHIP_DESIGNER_PART],PIECES=[json_encode(pieces)],EXAMPLES=[json_encode(examples)],START=[json_encode(ship_designer_cells(D))];"
	html += ship_designer_script()
	html += "</script></body></html>"
	return jointext(html, "")

// Raw string: no DM interpolation inside.
/proc/ship_designer_script()
	return @{"
var cv=document.getElementById('c'),g=cv.getContext('2d'),cells={},t='w',fd=1,rect=false,mirror=false,undos=[],down=null,parts=null,mode='',busy=false,timer=null,last=null;
cv.width=N*K;cv.height=N*K;
var NAMES={};for(var i=0;i<PIECES.length;i++)NAMES[PIECES[i][0]]=PIECES[i];
function key(x,y){return x+','+y;}
function load(list){cells={};for(var i=0;i<list.length;i++){var c=list[i];cells[key(c[0],c[1])]=[c[2],c[3],c[4],c[5]];}}
function st(s){document.getElementById('st').innerHTML=s;}
var ARROW={1:'↑',2:'↓',4:'→',8:'←'};
function drawCell(x,y){var c=cells[key(x,y)],px=x*K,py=(N-1-y)*K;g.fillStyle='#20303a';g.fillRect(px,py,K,K);
if(c){g.fillStyle=c[0]=='s'?'#8a9098':'#9a6a3a';g.fillRect(px,py,K,K);if(c[3]){g.strokeStyle='#e0d060';g.lineWidth=2;g.strokeRect(px+2,py+2,K-4,K-4);g.lineWidth=1;}
if(c[1]){g.fillStyle='#fff';g.font='bold 11px Verdana';g.textAlign='center';g.fillText(c[1],px+K/2-(NAMES[c[1]]&&NAMES[c[1]][2]?3:0),py+K-4);if(NAMES[c[1]]&&NAMES[c[1]][2]){g.font='9px Verdana';g.fillText(ARROW[c[2]]||'',px+K-4,py+K-4);}}}
g.strokeStyle='rgba(255,255,255,0.08)';g.strokeRect(px+0.5,py+0.5,K-1,K-1);}
function draw(){for(var y=0;y<N;y++)for(var x=0;x<N;x++)drawCell(x,y);g.strokeStyle='rgba(255,255,255,0.25)';g.beginPath();g.moveTo((MID+0.5)*K,0);g.lineTo((MID+0.5)*K,N*K);g.stroke();}
function mark(){var b=document.getElementsByTagName('button');for(var i=0;i<b.length;i++){var id=b[i].id;if(id.indexOf('t_')==0)b[i].className=id=='t_'+t?'on':'';if(id.indexOf('f_')==0)b[i].className=id=='f_'+fd?'on':'';}
document.getElementById('m_r').className=rect?'on':'';document.getElementById('m_m').className=mirror?'on':'';}
function tool(x){t=x;mark();}
function face(d){fd=d;mark();}
function toggleRect(){rect=!rect;mark();}
function toggleMirror(){mirror=!mirror;mark();}
function snap(){undos.push(JSON.stringify(cells));if(undos.length>60)undos.shift();}
function undo(){if(undos.length){cells=JSON.parse(undos.pop());draw();changed();}}
function clearAll(){snap();cells={};draw();changed();}
function mirrorDir(d){return d==4?8:(d==8?4:d);}
function apply(x,y,erasePiece,d){if(x<0||y<0||x>=N||y>=N)return;var k=key(x,y),c=cells[k];
if(erasePiece){if(c)c[1]='';return;}
if(t=='w'||t=='s'){if(c)c[0]=t;else cells[k]=[t,'',1,0];return;}
if(t=='x'){delete cells[k];return;}
if(!c)return;
if(t=='u'){c[3]=1;return;}if(t=='n'){c[3]=0;return;}
c[1]=t;c[2]=d;}
function at(x,y,erasePiece){apply(x,y,erasePiece,fd);var m=2*MID-x;if(mirror&&m!=x&&m>=0&&m<N)apply(m,y,erasePiece,mirrorDir(fd));}
function pos(e){var r=cv.getBoundingClientRect();return [Math.floor((e.clientX-r.left)/K),N-1-Math.floor((e.clientY-r.top)/K)];}
cv.oncontextmenu=function(){return false;};
cv.onmousedown=function(e){var p=pos(e);snap();down=[p[0],p[1],e.button==2];if(!rect){at(p[0],p[1],down[2]);draw();}};
cv.onmousemove=function(e){if(!down)return;var p=pos(e);if(rect){draw();g.strokeStyle='#fff';var x0=Math.min(down[0],p[0]),x1=Math.max(down[0],p[0]),y0=Math.min(down[1],p[1]),y1=Math.max(down[1],p[1]);g.strokeRect(x0*K,(N-1-y1)*K,(x1-x0+1)*K,(y1-y0+1)*K);return;}
if(t.length==1&&NAMES[t]&&!down[2])return;at(p[0],p[1],down[2]);draw();};
document.onmouseup=function(e){if(!down)return;if(rect){var p=pos(e),x0=Math.min(down[0],p[0]),x1=Math.max(down[0],p[0]),y0=Math.min(down[1],p[1]),y1=Math.max(down[1],p[1]);
for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++)at(x,y,down[2]);}down=null;draw();changed();};
function code(){var out=[];for(var k in cells){var c=cells[k];out.push(k+','+c[0]+','+(c[1]||'-')+','+c[2]+','+(c[3]?1:0));}return 'C13SHIP/1/ship/'+out.join(';');}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function changed(){if(timer)clearTimeout(timer);timer=setTimeout(function(){timer=null;send('preview');},600);}
function send(m){if(busy){if(m=='save')st('Wait a moment...');else changed();return;}var p=code();parts=[];for(var j=0;j<p.length;j+=PART)parts.push(p.substring(j,j+PART));if(!parts.length)parts.push('');
mode=m;busy=true;if(m=='save')st('Saving...');go('ship=begin&n='+parts.length+'&mode='+m+'&name='+encodeURIComponent(document.getElementById('nm').value));}
function shipAck(n){n=parseInt(n,10);if(!parts)return;if(n<parts.length){go('ship=part&i='+n+'&d='+encodeURIComponent(parts[n]));return;}parts=null;go('ship=end');}
function txt(s){return decodeURIComponent((s+'').replace(/\+/g,' '));}
function shipStats(s){busy=false;document.getElementById('stats').innerHTML=txt(s);}
function shipStatus(s){busy=false;st(txt(s));}
function loadExample(){var v=document.getElementById('ex').value;if(v==='')return;snap();var e=EXAMPLES[parseInt(v,10)];load(e[1]);document.getElementById('nm').value=e[0];draw();changed();}
(function(){var el=document.getElementById('pcs');for(var i=0;i<PIECES.length;i++){var b=document.createElement('button');b.id='t_'+PIECES[i][0];b.innerHTML=PIECES[i][0]+' '+PIECES[i][1];
b.onclick=(function(k){return function(){tool(k);};})(PIECES[i][0]);el.appendChild(b);}
var s=document.getElementById('ex');for(var i=0;i<EXAMPLES.length;i++){var o=document.createElement('option');o.value=i;o.innerHTML=EXAMPLES[i][0];s.appendChild(o);}})();
load(START);mark();draw();
"}

/proc/ship_designer_ack(mob/user, n)
	user << output(list2params(list("[n]")), "[SHIP_DESIGNER_WINDOW].browser:shipAck")

/proc/ship_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[SHIP_DESIGNER_WINDOW].browser:shipStatus")

/proc/ship_designer_stats(mob/user, datum/ship_draught/D)
	user << output(list2params(list(D.summary_text())), "[SHIP_DESIGNER_WINDOW].browser:shipStats")

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
		return "Saved on the sheet."
	qdel(D)
	return null

#undef SHIP_DESIGNER_WINDOW
#undef SHIP_DESIGNER_PART
#undef SHIP_DESIGNER_PREVIEW_GAP
