// The painting editor: a browser window with a pixel grid. Strokes stay in the
// browser; Save and Finish send the whole painting back in parts, each part
// acknowledged before the next, and the server checks size, palette and the
// pigments the painter carries before it keeps anything.

#define PAINT_WINDOW "painting_editor"

var/global/list/painting_editors = list() // mob -> canvas being painted

/proc/painting_can_reach(mob/user, obj/item/canvas/C)
	if (!user || !C || QDELETED(C) || user.incapacitated())
		return FALSE
	if (istype(C, /obj/item/canvas/sketch))
		var/obj/item/canvas/sketch/S = C
		return !QDELETED(S.target) && (S.target in user.get_contents()) && drawing_tool(user)
	if (C.loc == user || (C in user.get_contents()))
		return !C.needs_easel
	if (istype(C.loc, /obj/structure/easel))
		return get_dist(user, C.loc) <= 1
	if (istype(C.loc, /obj/structure/rock_art)) // rock_art.dm: stand on its tile
		return get_turf(user) == get_turf(C.loc)
	return FALSE

/proc/painting_open_editor(mob/user, obj/item/canvas/C)
	if (!user || !user.client || !istype(C))
		return
	if (C.finished)
		painting_show_full(user, C)
		return
	if (!painting_can_reach(user, C))
		to_chat(user, SPAN_WARNING(istype(C.loc, /obj/structure/rock_art) ? "Stand in front of the rock to paint it." : (C.needs_easel ? "Set \the [C] on an easel and stand beside it to paint it." : "Hold \the [C] to paint it.")))
		return
	if (C.editing && C.editing != user && C.editing.client && painting_editors[C.editing] == C)
		to_chat(user, SPAN_WARNING("[C.editing] is already painting \the [C]."))
		return
	var/obj/item/canvas/previous = painting_editors[user]
	if (previous && previous != C)
		previous.editing = null
	C.editing = user
	painting_editors[user] = C
	var/list/allowed = painting_allowed_colours(user, C)
	if (allowed.len <= 1)
		to_chat(user, SPAN_NOTICE("You carry no pigments, so you can only paint with the canvas colour. Grind charcoal, iron ore, clay or bone in a mortar for pigment."))
	show_browse(user, painting_editor_html(user, C, allowed), "window=[PAINT_WINDOW];size=[min(980, max(C.canvas_w, C.canvas_h) * painting_editor_scale(C) + 300)]x[min(900, max(C.canvas_w, C.canvas_h) * painting_editor_scale(C) + 140)]")
	onclose(user, PAINT_WINDOW, C)

/proc/painting_close_editor(mob/user)
	var/obj/item/canvas/C = painting_editors[user]
	painting_editors -= user
	if (C && C.editing == user)
		C.editing = null
		C.upload_parts = null
	if (user && user.client)
		show_browse(user, null, "window=[PAINT_WINDOW]")
	if (C && !C.finished)
		C.editor_closed()

/proc/painting_editor_scale(obj/item/canvas/C)
	return clamp(round(512 / max(C.canvas_w, C.canvas_h)), 3, 32)

/proc/painting_editor_html(mob/user, obj/item/canvas/C, list/allowed)
	var/k = painting_editor_scale(C)
	var/list/pal = painting_palette_list(C.palette)
	var/plain = pal ? painting_unpack(C.paint_data, C.canvas_w * C.canvas_h) : null
	if (!plain)
		pal = list(C.base_colour)
		plain = ""
	var/list/pigments = list()
	for (var/obj/item/pigment/P in painting_carried_pigments(user))
		pigments += "[html_encode(P.name)] ([P.pigment_uses])"
	var/list/html = list("<html><head><meta charset='utf-8'><title>Painting [html_encode(C.name)]</title><style>")
	html += "body{background:#2b2622;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:6px}"
	html += "#wrap{display:flex;gap:10px}canvas{image-rendering:pixelated;border:2px solid #5a3d22;cursor:crosshair;background:#000}"
	html += ".sw{display:inline-block;width:22px;height:22px;margin:1px;border:2px solid #222;cursor:pointer}.sw.mix{width:14px;height:14px}.sw.on{border-color:#fff}"
	html += "button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;margin:1px;padding:3px 6px;cursor:pointer}button.on{background:#806040}"
	html += "#side{width:250px}#st{margin-top:6px;color:#e0c070;min-height:30px}input{width:230px}</style></head><body><div id='wrap'><canvas id='c'></canvas><div id='side'>"
	html += "<div><b>[C.canvas_w]x[C.canvas_h]</b> [html_encode(C.name)]</div>"
	html += "<div>Tools: <button id='t_pen' onclick=\"tool('pen')\">Brush</button><button id='t_fill' onclick=\"tool('fill')\">Fill</button><button id='t_pick' onclick=\"tool('pick')\">Pick</button><button onclick='undo()'>Undo</button><button onclick='toggleGrid()'>Grid</button></div>"
	html += "<div>Brush size: <button id='s_1' onclick='size(1)'>1</button><button id='s_2' onclick='size(2)'>2</button><button id='s_3' onclick='size(3)'>3</button></div>"
	html += "<div style='margin-top:6px'>Colours (canvas and pigments):</div><div id='pal'></div><div>Mixes:</div><div id='mix'></div>"
	html += "<div style='margin-top:4px;color:#b0a080'>Pigments carried: [pigments.len ? jointext(pigments, ", ") : "none"]. A painting may use [PAINT_MAX_COLOURS] colours.</div>"
	html += "<div style='margin-top:8px'>Title: <input id='ti' maxlength='[PAINT_TITLE_LENGTH]' value='[html_encode(C.title)]'></div>"
	html += "<div style='margin-top:6px'><button onclick=\"send('save')\">Save</button><button onclick=\"if(confirm('Finish the painting? It cannot be changed afterwards.'))send('finish')\">Finish</button></div>"
	html += "<div style='margin-top:8px'>Design code: <button onclick='exportCode()'>Export</button><button onclick='importCode()'>Import</button><br><textarea id='code' style='width:240px;height:54px;font-family:monospace;font-size:10px' placeholder='Paste a design code here, then press Import'></textarea><div style='color:#b0a080'>Export gives this picture as text to keep outside the game. Import draws a code onto this canvas, fitted to its size, with each colour changed to the nearest one you can paint.</div></div>"
	html += "<div id='st'></div></div></div><script>"
	html += "var W=[C.canvas_w],H=[C.canvas_h],K=[k],REF='\ref[C]',BASE='[C.base_colour]',MAXC=[PAINT_MAX_COLOURS],PART=[PAINT_PART_LENGTH],MAXSIDE=[PAINT_MAX_SIDE],MAXCODE=[DESIGN_CODE_ART_MAX];"
	html += "var BASECOLS=[json_encode(painting_base_colours(user, C))],ALLOWED=[json_encode(allowed)],PAL=[json_encode(pal)],PLAIN='[plain]';"
	html += painting_draw_script()
	html += painting_editor_script()
	html += "</script></body></html>"
	return jointext(html, "")

/proc/painting_base_colours(mob/user, obj/item/canvas/C)
	var/list/out = list(C.base_colour) | C.extra_colours(user)
	for (var/obj/item/pigment/P in painting_carried_pigments(user))
		for (var/hex in P.pigment_colors)
			out |= painting_hex(hex)
	return out

// Raw string: no DM interpolation inside.
/proc/painting_editor_script()
	return @{"
var cv=document.getElementById('c'),g=cv.getContext('2d'),grid=[],cur=BASECOLS.length>1?BASECOLS[1]:BASE,t='pen',bs=1,showGrid=K>=6,undos=[],down=false,parts=null,mode='',busy=false;
cv.width=W*K;cv.height=H*K;
(function(){for(var i=0;i<W*H;i++){var d=PLAIN.length==W*H?parseInt(PLAIN.charAt(i),16):0;grid.push(PAL[d]||BASE);}})();
function st(s){document.getElementById('st').innerHTML=s;}
function cell(x,y){g.fillStyle=grid[y*W+x];g.fillRect(x*K,y*K,K,K);if(showGrid){g.strokeStyle='rgba(0,0,0,0.12)';g.strokeRect(x*K+0.5,y*K+0.5,K-1,K-1);}}
function draw(){for(var y=0;y<H;y++)for(var x=0;x<W;x++)cell(x,y);}
function toggleGrid(){showGrid=!showGrid;draw();}
function used(){var u={},n=0;for(var i=0;i<grid.length;i++){if(!u[grid[i]]){u[grid[i]]=1;n++;}}return [u,n];}
function canUse(c){var r=used();if(r[0][c]||r[1]<MAXC)return true;st('This painting already uses '+MAXC+' colours. Paint over one of them first.');return false;}
function mark(){var s=document.getElementsByClassName('sw');for(var i=0;i<s.length;i++)s[i].className=s[i].className.replace(' on','')+(s[i].getAttribute('data-c')==cur?' on':'');}
function swatch(c,mix,el){var d=document.createElement('span');d.className='sw'+(mix?' mix':'');d.style.background=c;d.setAttribute('data-c',c);d.title=c;d.onclick=function(){cur=c;if(t=='pick')tool('pen');mark();};el.appendChild(d);}
function tool(x){t=x;var b=document.getElementsByTagName('button');for(var i=0;i<b.length;i++){if(b[i].id.indexOf('t_')==0)b[i].className=b[i].id=='t_'+x?'on':'';}}
function size(n){bs=n;for(var i=1;i<=3;i++)document.getElementById('s_'+i).className=i==n?'on':'';}
function snap(){undos.push(grid.slice());if(undos.length>40)undos.shift();}
function undo(){if(undos.length){grid=undos.pop();draw();}}
function pos(e){var r=cv.getBoundingClientRect();return [Math.floor((e.clientX-r.left)/K),Math.floor((e.clientY-r.top)/K)];}
function paint(x,y){if(!canUse(cur))return;var o=Math.floor((bs-1)/2);for(var dy=0;dy<bs;dy++)for(var dx=0;dx<bs;dx++){var px=x-o+dx,py=y-o+dy;if(px<0||py<0||px>=W||py>=H)continue;grid[py*W+px]=cur;cell(px,py);}}
function fill(x,y){var from=grid[y*W+x];if(from==cur||!canUse(cur))return;var q=[[x,y]];while(q.length){var p=q.pop(),i=p[1]*W+p[0];if(p[0]<0||p[1]<0||p[0]>=W||p[1]>=H||grid[i]!=from)continue;grid[i]=cur;q.push([p[0]+1,p[1]],[p[0]-1,p[1]],[p[0],p[1]+1],[p[0],p[1]-1]);}draw();}
cv.onmousedown=function(e){var p=pos(e);if(t=='pick'){var c=grid[p[1]*W+p[0]];if(ALLOWED.indexOf(c)>=0){cur=c;mark();}tool('pen');return;}snap();if(t=='fill'){fill(p[0],p[1]);return;}down=true;paint(p[0],p[1]);};
cv.onmousemove=function(e){if(!down||t!='pen')return;var p=pos(e);paint(p[0],p[1]);};
document.onmouseup=function(){down=false;};
function go(q){window.location='byond://?src='+REF+'&'+q;}
function encode(){var r=used();var pal=[BASE],idx={};idx[BASE]=0;for(var c in r[0]){if(!(c in idx)){idx[c]=pal.length;pal.push(c);}}
if(pal.length>MAXC)return null;var s=[];for(var i=0;i<grid.length;i++)s.push(idx[grid[i]].toString(16));return [pal,packArt(s.join(''))];}
function send(m){if(busy)return;var e=encode();if(!e){st('Too many colours.');return;}var pal=e[0],p=e[1];
parts=[];for(var j=0;j<p.length;j+=PART)parts.push(p.substring(j,j+PART));mode=m;busy=true;st('Sending...');go('paint=begin&n='+parts.length+'&pal='+encodeURIComponent(pal.join(',')));}
function paintAck(n){n=parseInt(n,10);if(!parts)return;if(n<parts.length){go('paint=part&i='+n+'&d='+encodeURIComponent(parts[n]));return;}
parts=null;go('paint=end&mode='+mode+(IMPORTED?'&imported=1':'')+'&title='+encodeURIComponent(document.getElementById('ti').value));}
var IMPORTED=false;
function exportCode(){var e=encode();if(!e){st('Too many colours.');return;}var h=[];for(var i=0;i<e[0].length;i++)h.push(e[0][i].substring(1));var b=document.getElementById('code');b.value='C13ART/1/'+W+'x'+H+'/'+h.join(',')+'/'+e[1];b.focus();b.select();st('Design code ready. Press Ctrl+C to copy it.');}
function readCode(s){s=(s||'').replace(/\s+/g,'');if(s.length>MAXCODE)return 'That design code is too long.';var m=/^C13ART\/1\/(\d{1,3})x(\d{1,3})\/([0-9a-fA-F,]+)\/([0-9a-f~.]+)$/i.exec(s);if(!m)return 'That is not a picture design code.';
var w=parseInt(m[1],10),h=parseInt(m[2],10);if(w<1||h<1||w>MAXSIDE||h>MAXSIDE)return 'That picture is too big.';var pal=m[3].split(',');if(!pal.length||pal.length>MAXC)return 'That picture has too many colours.';
for(var i=0;i<pal.length;i++){if(!/^[0-9a-fA-F]{6}$/.test(pal[i]))return 'That design code is damaged.';pal[i]='#'+pal[i].toLowerCase();}
var p=m[4].toLowerCase(),o=[],n=w*h,j=0;while(j<p.length){var c=p.charAt(j++);if(c=='~'||c=='.')return 'That design code is damaged.';var d=parseInt(c,16);if(d>=pal.length)return 'That design code is damaged.';var r=1;if(p.charAt(j)=='~'){var e=p.indexOf('.',j);if(e<0||e-j>6)return 'That design code is damaged.';r=parseInt(p.substring(j+1,e),10);if(!(r>=4))return 'That design code is damaged.';j=e+1;}if(o.length+r>n)return 'That design code is damaged.';for(var k=0;k<r;k++)o.push(d);}
if(o.length!=n)return 'That design code is damaged.';return [w,h,pal,o];}
function rgbOf(c){return [parseInt(c.substr(1,2),16),parseInt(c.substr(3,2),16),parseInt(c.substr(5,2),16)];}
function nearest(c){if(ALLOWED.indexOf(c)>=0)return c;var a=rgbOf(c),best=BASE,bd=1e9;for(var i=0;i<ALLOWED.length;i++){var b=rgbOf(ALLOWED[i]),d=(a[0]-b[0])*(a[0]-b[0])+(a[1]-b[1])*(a[1]-b[1])+(a[2]-b[2])*(a[2]-b[2]);if(d<bd){bd=d;best=ALLOWED[i];}}return best;}
function importCode(){var r=readCode(document.getElementById('code').value);if(typeof r=='string'){st(r);return;}var w=r[0],h=r[1],pal=r[2],px=r[3],map=[],changed=0;
for(var i=0;i<pal.length;i++){map.push(nearest(pal[i]));if(map[i]!=pal[i])changed++;}
var sc=Math.min(W/w,H/h),nw=Math.max(1,Math.round(w*sc)),nh=Math.max(1,Math.round(h*sc)),ox=Math.floor((W-nw)/2),oy=Math.floor((H-nh)/2);snap();
for(var y=0;y<H;y++)for(var x=0;x<W;x++){var u=x-ox,v=y-oy;grid[y*W+x]=(u<0||v<0||u>=nw||v>=nh)?BASE:map[px[Math.floor(v*h/nh)*w+Math.floor(u*w/nw)]];}
IMPORTED=true;draw();st('Design imported'+(w!=W||h!=H?' and fitted from '+w+'x'+h:'')+'.'+(changed?' '+changed+' colour'+(changed>1?'s were':' was')+' changed to the nearest paint you have.':'')+' Undo puts the canvas back.');}
function paintStatus(s){busy=false;st(decodeURIComponent((s+'').replace(/\+/g,' ')));}
for(var i=0;i<BASECOLS.length;i++)swatch(BASECOLS[i],false,document.getElementById('pal'));
for(var i=0;i<ALLOWED.length;i++)if(BASECOLS.indexOf(ALLOWED[i])<0)swatch(ALLOWED[i],true,document.getElementById('mix'));
tool('pen');size(1);mark();draw();
"}

/proc/painting_editor_ack(mob/user, n)
	user << output(list2params(list("[n]")), "[PAINT_WINDOW].browser:paintAck")

/proc/painting_editor_status(mob/user, text)
	user << output(list2params(list(text)), "[PAINT_WINDOW].browser:paintStatus")

/obj/item/canvas/Topic(href, list/href_list)
	var/mob/user = usr
	if (href_list["close"])
		if (user && painting_editors[user] == src)
			painting_editors -= user
		if (editing == user)
			editing = null
			upload_parts = null
			if (!finished)
				editor_closed()
		return
	if (!href_list["paint"])
		return ..()
	if (!user || editing != user || painting_editors[user] != src || finished)
		return
	if (!painting_can_reach(user, src))
		painting_editor_status(user, "You are no longer at the canvas.")
		return
	switch (href_list["paint"])
		if ("begin")
			var/n = text2num(href_list["n"])
			if (!isnum(n) || n < 1 || n > PAINT_MAX_PARTS || n != round(n) || !painting_palette_list(href_list["pal"]))
				painting_editor_status(user, "The painting could not be sent.")
				return
			upload_parts = list()
			upload_count = n
			upload_palette = href_list["pal"]
			painting_editor_ack(user, 0)
		if ("part")
			var/i = text2num(href_list["i"])
			var/d = href_list["d"]
			if (!upload_parts || !isnum(i) || i != upload_parts.len || i >= upload_count || !istext(d) || length(d) > PAINT_PART_LENGTH)
				upload_parts = null
				painting_editor_status(user, "The painting could not be sent.")
				return
			upload_parts += d
			painting_editor_ack(user, i + 1)
		if ("end")
			var/list/got = upload_parts
			upload_parts = null
			if (!got || got.len != upload_count)
				painting_editor_status(user, "The painting could not be sent.")
				return
			var/result = accept_painting(user, jointext(got, ""), upload_palette, href_list["mode"] == "finish", href_list["title"], href_list["imported"] == "1")
			if (result)
				painting_editor_status(user, result)

// Checks and keeps an upload. Returns a status line for the editor.
/obj/item/canvas/proc/accept_painting(mob/user, packed, palette_text, finish, new_title, imported = FALSE)
	var/list/pal = painting_palette_list(palette_text)
	if (!pal || pal[1] != base_colour)
		return "The painting could not be read."
	var/plain = painting_unpack(packed, canvas_w * canvas_h)
	if (!plain || painting_max_index(plain) >= pal.len)
		return "The painting could not be read."
	var/list/allowed = painting_allowed_colours(user, src)
	var/list/kept = painting_palette_list(palette) || list()
	for (var/hex in pal)
		if (!(hex in allowed) && !(hex in kept))
			return "You no longer carry the pigment for one of these colours. Pick it up again or paint over it."
	if (finish)
		if (format_weight > 0 && painting_weight_total() + format_weight > PAINTING_REGION_CAP)
			return "This land already holds as many finished paintings as it can. An admin can make room."
		new_title = sanitizeSafe(new_title, PAINT_TITLE_LENGTH)
		if (!length(new_title))
			return "Give the painting a title before finishing it."
	palette = jointext(pal, ",")
	paint_data = painting_pack(plain)
	if (imported && !imported_design)
		imported_design = TRUE
		design_code_log(user, "picture", "[src]", painting_design_code(canvas_w, canvas_h, palette, paint_data))
	if (!author_ckey)
		author_ckey = user.ckey
		author_name = user.real_name
	if (finish)
		title = new_title
		author_ckey = user.ckey
		author_name = user.real_name
		painted_at = time2text(world.realtime, "YYYY-MM-DD")
		use_pigments(user, plain, pal)
		finished = TRUE
		name = "\"[title]\""
		painting_registry |= src
		log_game("[key_name(user)] finished the [format] painting \"[title]\" ([canvas_w]x[canvas_h])[imported_design ? " from an imported design code" : ""] at ([user.x],[user.y],[user.z]).")
	else if (length(new_title))
		title = sanitizeSafe(new_title, PAINT_TITLE_LENGTH)
	refresh_small()
	update_icon()
	if (istype(loc, /obj/structure/easel))
		var/obj/structure/easel/E = loc
		E.update_icon()
	if (finish)
		painting_close_editor(user)
		if (format != "sketch")
			to_chat(user, SPAN_NOTICE("You finish [painting_name_text()]."))
		on_finished(user)
		return null
	return "Saved."

#undef PAINT_WINDOW
