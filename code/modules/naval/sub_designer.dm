// ============================================================
// The submarine designer (docs/ship-draught.md, "Submarine sheets")
// ------------------------------------------------------------
// Hold a blank ship's draught (or a submarine sheet) and a pen or pencil and
// choose "Draw a submarine on the sheet": a small window shows her plan,
// three sections across and four to seven long, bow to the top, starboard on
// the right. Clicking a section makes it hull or a lock-out hatch, stands a
// fitting in it or puts a bulkhead or watertight door across its bow side.
// The glass bow and the stern engine room are drawn for the builder.
//
// Like the ship designer, every change goes to the server, which reads it as
// a design code and answers with the sheet's own summary, so the window never
// disagrees with the sheet. Save keeps the drawing on the sheet.
//
// A fitting is shown as the sprite the built thing has in the game: PNGs cut
// from the game's DMIs by scripts/build_sub_designer_icons.py and sent with
// browse_rsc. A fitting with no picture shows as its letter.
// ============================================================

#define SUB_DESIGNER_WINDOW "sub_designer"
#define SUB_DESIGNER_PREVIEW_GAP 3 // deciseconds between summaries per drawer

var/global/list/sub_designers = list() // mob -> /datum/sub_designer

// Fitting key -> its picture, sent to the window as "subd_fit_<key>.png".
// The keys differ by more than case: Windows serves the cache without it.
var/global/list/sub_designer_sprites = list(
	"W" = 'icons/sub_designer/fit_W.png',
	"S" = 'icons/sub_designer/fit_S.png',
	"E" = 'icons/sub_designer/fit_E.png',
	"A" = 'icons/sub_designer/fit_A.png',
	"L" = 'icons/sub_designer/fit_L.png',
	"B" = 'icons/sub_designer/fit_B.png',
)

// One drawer at one sheet. The window talks to this datum, not the sheet.
/datum/sub_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/last_preview = null

/datum/sub_designer/Destroy()
	if (drawer && sub_designers[drawer] == src)
		sub_designers -= drawer
	drawer = null
	sheet = null
	return ..()

/obj/item/ship_draught/proc/open_sub_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	var/datum/sub_designer/old = sub_designers[H]
	if (old)
		qdel(old)
	var/datum/sub_designer/S = new
	S.drawer = H
	S.sheet = src
	sub_designers[H] = S
	var/datum/sub_draught/D = sub_draught()
	if (!D)
		D = new /datum/sub_draught(5)
	for (var/fitting in sub_designer_sprites)
		H << browse_rsc(sub_designer_sprites[fitting], "subd_fit_[fitting].png")
	show_browse(H, sub_designer_html(S, D), "window=[SUB_DESIGNER_WINDOW];size=640x560")
	onclose(H, SUB_DESIGNER_WINDOW, S)
	sub_designer_stats(H, D)
	qdel(D)

// A sheet for the window: list(name, length, list(list(col, row, frame,
// fitting, wall), ...)).
/proc/sub_designer_sheet(datum/sub_draught/D)
	var/list/cells = list()
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		var/list/xy = splittext(key, ",")
		cells += list(list(text2num(xy[1]), text2num(xy[2]), C[1], C[2] ? C[2] : "", C[3] ? C[3] : ""))
	return list(D.name, D.length, cells)

/proc/sub_designer_html(datum/sub_designer/S, datum/sub_draught/D)
	var/list/fittings = list()
	for (var/key in sub_draught_fittings)
		var/list/P = sub_draught_fittings[key]
		fittings += list(list(key, P["name"]))
	var/list/pictures = list()
	for (var/key in sub_designer_sprites)
		pictures += key
	var/list/examples = list()
	for (var/datum/sub_draught/E in sub_draught_examples())
		examples += list(sub_designer_sheet(E))
		qdel(E)
	var/list/html = list("<html><head><meta charset='utf-8'><title>Submarine sheet</title><style>")
	html += "body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:6px}"
	html += "#wrap{display:flex;gap:12px;align-items:flex-start}table{border-collapse:collapse}td.s{width:54px;height:54px;text-align:center;vertical-align:middle;cursor:pointer;font-size:10px;color:#fff;box-sizing:border-box}"
	html += "button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;margin:1px;padding:3px 6px;cursor:pointer}button.on{background:#b48c4d;color:#211c16}"
	html += "#side{width:300px}#stats{margin-top:6px;padding:4px;background:#1d1916;border:1px solid #5a3d22;min-height:80px}#st{margin-top:4px;color:#ffd985;min-height:16px}.warning{color:#e08060}"
	html += "input,select{background:#1d1916;color:#e9dfc8;border:1px solid #806040}.hint{color:#b0a080}.lbl{color:#b0a080;font-size:10px;text-align:center}.fit{display:inline-block;background:#211c16;border:1px solid #b48c4d;border-radius:3px;padding:1px 4px;font-size:12px;color:#ffd985}img.pic{vertical-align:middle;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}#fits button{display:inline-flex;align-items:center;width:146px;text-align:left;vertical-align:top;height:32px;font-size:11px;line-height:12px;padding:2px 4px;overflow:hidden}#fits img.pic,#fits .fit{flex:none}#fits img.pic,#fits .fit{margin-right:4px}</style></head><body><div id='wrap'><div>"
	html += "<div class='lbl'>bow</div><table id='g'></table><div class='lbl'>stern</div><div class='lbl'>port &#8592; &#8594; starboard</div></div><div id='side'>"
	html += "<div>Name: <input id='nm' maxlength='40' style='width:200px' value='[html_encode(D.name)]' onchange='changed()'></div>"
	html += "<div style='margin-top:4px'>Length: <select id='len' onchange='setLength(+this.value)'></select> sections</div>"
	html += "<div style='margin-top:4px'>Sections: <button id='t_h' onclick=\"tool('h')\">Hull</button><button id='t_x' onclick=\"tool('x')\">Lock-out hatch</button></div>"
	html += "<div>Across the bow side: <button id='t_wb' onclick=\"tool('wb')\">Bulkhead</button><button id='t_wd' onclick=\"tool('wd')\">Door</button><button id='t_wn' onclick=\"tool('wn')\">Open</button></div>"
	html += "<div style='margin-top:4px'>Fittings:</div><div id='fits'></div>"
	html += "<div style='margin-top:4px'><button onclick='undo()'>Undo</button> Start from: <select id='ex'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>"
	html += "<div id='stats'></div><div id='st'></div>"
	html += "<div style='margin-top:6px'><button onclick=\"send('save')\">Save to the sheet</button></div>"
	html += "<div class='hint' style='margin-top:6px'>The glass bow and the engine room in the stern, with its fuel and ballast tanks, are part of every boat. Hatches go in her side sections. Right-click a section to take its fitting out.</div>"
	html += "</div></div><script>"
	html += "var REF='\ref[S]',BEAM=[SUB_DRAUGHT_BEAM],MINL=[SUB_DRAUGHT_MIN_LENGTH],MAXL=[SUB_DRAUGHT_MAX_LENGTH],FITS=[json_encode(fittings)],PICS=[json_encode(pictures)],EXAMPLES=[json_encode(examples)],START=[json_encode(sub_designer_sheet(D))];"
	html += sub_designer_script()
	html += "</script></body></html>"
	return jointext(html, "")

// Raw string: no DM interpolation inside.
/proc/sub_designer_script()
	return @{"
var L=5,cells={},cur='h',hist=[],timer=null;
function key(c,r){return c+','+r;}
function stern(r){return r==L;}
function tank(c,r){return r==L&&c!=2;}
function fitPic(k,n){for(var i=0;i<PICS.length;i++)if(PICS[i]==k)return '<img class=pic width='+n+' height='+n+' src=\"subd_fit_'+k+'.png\" alt=\"'+k+'\" title=\"'+fitName(k)+'\" onerror=\"noPic(this)\">';return '<span class=fit title=\"'+fitName(k)+'\">'+k+'</span>';}
function noPic(i){var s=document.createElement('span');s.className='fit';s.title=i.title;s.innerHTML=i.alt;i.parentNode.replaceChild(s,i);}
function fitName(k){for(var i=0;i<FITS.length;i++)if(FITS[i][0]==k)return FITS[i][1];return k;}
function load(sheet){document.getElementById('nm').value=sheet[0];L=sheet[1];cells={};for(var r=1;r<=L;r++)for(var c=1;c<=BEAM;c++)cells[key(c,r)]=['h','',''];for(var i=0;i<sheet[2].length;i++){var t=sheet[2][i];cells[key(t[0],t[1])]=[t[2],t[3],t[4]];}document.getElementById('len').value=L;}
function snap(){var o={};for(var k in cells)o[k]=cells[k].slice();return [L,o];}
function push(){hist.push(snap());if(hist.length>50)hist.shift();}
function undo(){if(!hist.length)return;var h=hist.pop();L=h[0];cells=h[1];document.getElementById('len').value=L;draw();changed();}
function setLength(n){push();var old=cells;cells={};L=n;for(var r=1;r<=L;r++)for(var c=1;c<=BEAM;c++){var o=old[key(c,r)];var v=o?o.slice():['h','',''];if(r==1||r==L){v[0]='h';if(r==1)v[2]='';if(r==L){v[1]='';if(c!=2)v[2]='';}}cells[key(c,r)]=v;}draw();changed();}
function tool(t){cur=t;var b=document.getElementsByTagName('button');for(var i=0;i<b.length;i++)b[i].className=(b[i].id=='t_'+t)?'on':'';}
function apply(c,r,right){var v=cells[key(c,r)];push();if(right){v[1]='';}
else if(cur=='h'){v[0]='h';}
else if(cur=='x'){if(c==2||r==1||r==L){status('Hatches go in her side sections, not the bow or the engine room.');hist.pop();return;}v[0]='x';}
else if(cur=='wb'||cur=='wd'||cur=='wn'){if(r==1||tank(c,r)){status(r==1?'The bow side of the first row is her glass.':'The stern tanks are sealed already.');hist.pop();return;}v[2]=cur=='wn'?'':cur.charAt(1);}
else{if(r==L){status('The stern row is her engine room.');hist.pop();return;}v[1]=cur;}
draw();changed();}
function draw(){var g=document.getElementById('g');var h='';for(var r=1;r<=L;r++){h+='<tr>';for(var c=BEAM;c>=1;c--){var v=cells[key(c,r)];var bg=v[0]=='x'?'#5f7a4a':'#56616b';var label='';
if(tank(c,r)){bg='#6a4a3a';label='tank';}else if(r==L&&c==2){bg='#4a4f58';label='engine';}else if(v[0]=='x')label='hatch';
var st='background:'+bg+';';var top='1px solid #333';if(r==1)top='4px solid #7fb6d8';else if(tank(c,r))top='4px solid #8a5a3a';else if(v[2]=='b')top='5px solid #c8c8c8';else if(v[2]=='d')top='5px dashed #d0a050';st+='border-top:'+top+';';
var side=v[0]=='x'?'4px dotted #9fd07f':(r==1?'4px solid #7fb6d8':'4px solid #222');if(c==BEAM)st+='border-left:'+side+';';else st+='border-left:1px solid #333;';if(c==1)st+='border-right:'+side+';';else st+='border-right:1px solid #333;';if(r==L)st+='border-bottom:4px solid #222;';
var fit=v[1]?fitPic(v[1],32)+'<br>':'';
h+='<td class=s style=\"'+st+'\" title=\"'+(v[1]?fitName(v[1]):'')+'\" onclick=\"apply('+c+','+r+',0)\" oncontextmenu=\"apply('+c+','+r+',1);return false;\">'+fit+label+'</td>';}h+='</tr>';}g.innerHTML=h;}
function code(){var nm=document.getElementById('nm').value.replace(/[\/;,]/g,' ').replace(/ /g,'_');if(!nm)nm='submarine';var t=[];for(var r=1;r<=L;r++)for(var c=1;c<=BEAM;c++){var v=cells[key(c,r)];t.push(c+','+r+','+v[0]+','+(v[1]||'-')+','+(v[2]||'-'));}return 'C13SUB/1/'+nm+'/'+L+'/'+t.join(';');}
function send(mode){window.location='byond://?src='+REF+'&sub='+mode+'&code='+encodeURIComponent(code())+'&name='+encodeURIComponent(document.getElementById('nm').value);}
function changed(){if(timer)clearTimeout(timer);timer=setTimeout(function(){timer=null;send('preview');},400);}
function status(t){document.getElementById('st').innerHTML=t;}
function subStatus(t){status(t);}
function subStats(t){document.getElementById('stats').innerHTML=t;}
function loadExample(){var i=document.getElementById('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);draw();changed();}
(function(){var s=document.getElementById('len');for(var n=MINL;n<=MAXL;n++){var o=document.createElement('option');o.value=n;o.innerHTML=n;s.appendChild(o);}
var f=document.getElementById('fits');var h='';for(var i=0;i<FITS.length;i++)h+='<button id=\"t_'+FITS[i][0]+'\" onclick=\"tool(\''+FITS[i][0]+'\')\">'+fitPic(FITS[i][0],24)+FITS[i][1]+'</button>';f.innerHTML=h;
var e=document.getElementById('ex');for(var j=0;j<EXAMPLES.length;j++){var o2=document.createElement('option');o2.value=j;o2.innerHTML=EXAMPLES[j][0];e.appendChild(o2);}})();
load(START);tool('h');draw();
"}

/proc/sub_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[SUB_DESIGNER_WINDOW].browser:subStatus")

/proc/sub_designer_stats(mob/user, datum/sub_draught/D)
	user << output(list2params(list(D.summary_text())), "[SUB_DESIGNER_WINDOW].browser:subStats")

/datum/sub_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["sub"] || H != drawer || sub_designers[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		sub_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	var/save = href_list["sub"] == "save"
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + SUB_DESIGNER_PREVIEW_GAP)
			return
		last_preview = world.time
	var/code = href_list["code"]
	if (!istext(code) || length(code) > DESIGN_CODE_SUB_MAX)
		sub_designer_status(H, "The drawing could not be read.")
		return
	var/datum/sub_draught/D = sub_draught_from_code(code)
	if (!D)
		sub_designer_status(H, "The drawing could not be read.")
		return
	D.name = sub_draught_clean_name(href_list["name"])
	sub_designer_stats(H, D)
	if (save)
		sheet.take_sub(D)
		sub_designer_status(H, "Saved on the sheet.")
	qdel(D)

#undef SUB_DESIGNER_WINDOW
#undef SUB_DESIGNER_PREVIEW_GAP
