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
// Beside the plan, the Part panel says what the picked (or pointed at) tool
// is, what it is for and how to use it, and the Checks panel lists what the
// server found: pointing at a finding, or clicking it to keep it, rings its
// sections on the plan. Both are their own block at the end of the script
// (sub_designer_script()) and wrap tool(), draw() and subStats() from outside.
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
	"T" = 'icons/sub_designer/fit_T.png',
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
	show_browse(H, sub_designer_html(S, D), "window=[SUB_DESIGNER_WINDOW];size=900x580")
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
	// The Part and Checks panels (the third column).
	html += "#info{flex:1 1 0;min-width:0}.sec{border:1px solid #66513b;background:#30271e;margin-bottom:8px}.sec h2{font-size:13px;margin:0;padding:5px 8px;border-bottom:2px solid #b48c4d}.sec h2 span{float:right;font-size:11px;font-weight:normal;color:#bfae96;margin-top:1px}.sec .in{padding:6px 8px}"
	html += "#part{min-height:118px;line-height:1.35}.pn{font-size:13px;font-weight:bold;margin-bottom:3px}.pn span{font-size:11px;font-weight:normal;color:#bfae96;margin-left:8px}.pr{display:flex;margin-top:2px}.pr i{flex:0 0 38px;font-style:normal;color:#b48c4d;font-size:11px;padding-top:1px}.pr span{flex:1 1 auto;min-width:0}"
	html += ".vd{padding:5px 7px;border:1px solid #6caa68;border-radius:3px;background:#253b25;color:#c4e8c0}.vd.bad{border-color:#c77a39;background:#3a2a1a;color:#f3c79a}.vd.none{border-color:#66513b;background:none;color:#bfae96}.vd .also{color:#f2dc8f;margin-top:3px}"
	html += ".ck{display:flex;gap:7px;align-items:flex-start;margin-top:4px;padding:5px 7px 5px 6px;border:1px solid #54432f;border-left:3px solid #bfae96;border-radius:3px;background:#262019;line-height:1.3;cursor:default}.ck.has{cursor:pointer}"
	html += ".ck .tag{flex:0 0 52px;text-align:center;font-size:10px;font-weight:bold;letter-spacing:0.5px;text-transform:uppercase;border-radius:2px;padding:1px 0;margin-top:1px;border:1px solid #bfae96;color:#bfae96}.ck .tx{flex:1 1 auto;min-width:0}.ck .wh{display:block;color:#bfae96;font-size:11px;margin-top:1px}"
	html += ".ck.error{border-left-color:#c77a39;background:#3a2a1a}.ck.error .tag{background:#c77a39;border-color:#c77a39;color:#241405}.ck.warning{border-left-color:#c9a52e;background:#373016;color:#e9dfc8}.ck.warning .tag{border-color:#c9a52e;color:#f2dc8f}.ck.note{color:#bfae96}"
	html += ".ck.has:hover,.ck.lit{border-color:#ffd985}.ck.pin{box-shadow:inset 0 0 0 1px #ffd985}.ck.pin .wh{color:#ffd985}.ck:focus{outline:2px solid #ffd985;outline-offset:1px}#side{flex:0 0 300px}"
	html += "input,select{background:#1d1916;color:#e9dfc8;border:1px solid #806040}.hint{color:#b0a080}.lbl{color:#b0a080;font-size:10px;text-align:center}.fit{display:inline-block;background:#211c16;border:1px solid #b48c4d;border-radius:3px;padding:1px 4px;font-size:12px;color:#ffd985}img.pic{vertical-align:middle;image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}#fits button{display:inline-flex;align-items:center;width:146px;text-align:left;vertical-align:top;height:32px;font-size:11px;line-height:12px;padding:2px 4px;overflow:hidden}#fits img.pic,#fits .fit{flex:none}#fits img.pic,#fits .fit{margin-right:4px}</style></head><body><div id='wrap'><div>"
	html += "<div class='lbl'>bow</div><table id='g'></table><div class='lbl'>stern</div><div class='lbl'>port &#8592; &#8594; starboard</div></div><div id='side'>"
	html += "<div>Name: <input id='nm' maxlength='40' style='width:200px' value='[html_encode(D.name)]' onchange='changed()'></div>"
	html += "<div style='margin-top:4px'>Length: <select id='len' onchange='setLength(+this.value)'></select> sections</div>"
	html += "<div style='margin-top:4px'>Sections: <button id='t_h' onclick=\"tool('h')\">Hull</button><button id='t_x' onclick=\"tool('x')\">Lock-out hatch</button></div>"
	html += "<div>Across the bow side: <button id='t_wb' onclick=\"tool('wb')\">Bulkhead</button><button id='t_wd' onclick=\"tool('wd')\">Door</button><button id='t_wn' onclick=\"tool('wn')\">Open</button></div>"
	html += "<div style='margin-top:4px'>Fittings:</div><div id='fits'></div>"
	html += "<div style='margin-top:4px'><button onclick='undo()'>Undo</button> Start from: <select id='ex'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>"
	html += "<div id='stats'></div><div id='st'></div>"
	html += "<div style='margin-top:6px'><button onclick=\"send('save')\">Save to the sheet</button><button onclick=\"send('export')\" title='Save the drawing on the sheet and show its design code to copy'>Export code</button><button onclick='importCode()' title='Paste a design code; it replaces what is drawn on this sheet'>Import code</button></div>"
	html += "<div class='hint' style='margin-top:6px'>The glass bow and the engine room in the stern, with its fuel and ballast tanks, are part of every boat. Hatches go in her side sections. Right-click a section to take its fitting out.</div>"
	html += "</div><div id='info'><div class='sec'><h2>Part</h2><div class='in' id='part'></div></div><div class='sec'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div></div></div><script>"
	html += "var REF='\ref[S]',BEAM=[SUB_DRAUGHT_BEAM],MINL=[SUB_DRAUGHT_MIN_LENGTH],MAXL=[SUB_DRAUGHT_MAX_LENGTH],FITS=[json_encode(fittings)],PICS=[json_encode(pictures)],EXAMPLES=[json_encode(examples)],START=[json_encode(sub_designer_sheet(D))],HELP=[json_encode(design_part_help_for("sub"))];"
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
function importCode(){if(timer){clearTimeout(timer);timer=null;}window.location='byond://?src='+REF+'&sub=import';}
function changed(){if(timer)clearTimeout(timer);timer=setTimeout(function(){timer=null;send('preview');},400);}
function status(t){document.getElementById('st').innerHTML=t;}
function subStatus(t){status(t);}
function subStats(t){document.getElementById('stats').innerHTML=t;}
function loadExample(){var i=document.getElementById('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);draw();changed();}
(function(){var s=document.getElementById('len');for(var n=MINL;n<=MAXL;n++){var o=document.createElement('option');o.value=n;o.innerHTML=n;s.appendChild(o);}
var f=document.getElementById('fits');var h='';for(var i=0;i<FITS.length;i++)h+='<button id=\"t_'+FITS[i][0]+'\" onclick=\"tool(\''+FITS[i][0]+'\')\">'+fitPic(FITS[i][0],24)+FITS[i][1]+'</button>';f.innerHTML=h;
var e=document.getElementById('ex');for(var j=0;j<EXAMPLES.length;j++){var o2=document.createElement('option');o2.value=j;o2.innerHTML=EXAMPLES[j][0];e.appendChild(o2);}})();

// ---- The Part and Checks panels ----
// Their own block: tool(), draw() and subStats() above are wrapped from here
// and not changed. A finding's cells are 'col,row': row r is table row r-1
// and column c is cell BEAM-c of it, as draw() lays the plan out.
var SUBCHK=[],subLit=-1,subPin=-1,subPeek=null;
var SUBLEVEL={error:['Fix','#ff6f3c'],warning:['Warning','#ffd23f'],note:['Note','#fff6dc']};
var SUBTOOLS={h:'Hull section',x:'Lock-out hatch',wb:'Bulkhead',wd:'Watertight door',wn:'Open bow side'};
function subEsc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function subSeveral(n,one){return n+' '+one+(n==1?'':'s');}
function subName(k){var n=SUBTOOLS[k]||fitName(k);return n.charAt(0).toUpperCase()+n.substring(1);}
function subFinding(){var i=subLit>=0?subLit:subPin;return i>=0&&SUBCHK[i]?SUBCHK[i]:null;}
function subPart(){var f=subFinding(),k=f&&f.part?f.part:(subPeek||cur),H=HELP[k],L=[['what','What'],['use','Use'],['how','How']],i;
var h='<div class=pn>'+subEsc(subName(k))+'<span>'+(k==cur?'picked to draw with':(f&&f.part?'named by the check':'click to pick it'))+'</span></div>';
if(H)for(i=0;i<L.length;i++)if(H[L[i][0]])h+='<div class=pr><i>'+L[i][1]+'</i><span>'+subEsc(H[L[i][0]])+'</span></div>';
document.getElementById('part').innerHTML=h;}
function subLight(){var g=document.getElementById('g'),f=subFinding(),r,c,p,td,col;
for(r=0;r<g.rows.length;r++)for(c=0;c<g.rows[r].cells.length;c++){td=g.rows[r].cells[c];td.style.outline='';td.style.outlineOffset='';td.style.boxShadow='';}
if(!f)return;col=SUBLEVEL[f.level][1];
for(c=0;c<f.cells.length;c++){p=f.cells[c].split(',');td=g.rows[p[1]-1]&&g.rows[p[1]-1].cells[BEAM-p[0]];if(!td)continue;
td.style.outline='3px solid '+col;td.style.outlineOffset='-5px';td.style.boxShadow='inset 0 0 0 6px rgba(20,12,6,0.8)';}}
function subWhere(i){return i==subPin?'&#9679; ringed on the plan':'&#9675; '+subSeveral(SUBCHK[i].cells.length,'section')+' on the plan';}
function subMark(){var b=document.getElementById('checks').getElementsByTagName('div'),i,j=0,f,w;for(i=0;i<b.length;i++){if(b[i].id.indexOf('ck_')!=0)continue;f=SUBCHK[j];
b[i].className='ck '+f.level+(f.cells.length||f.part?' has':'')+(j==subPin?' pin':'')+(j==subLit?' lit':'');w=b[i].getElementsByTagName('span')[2];if(w)w.innerHTML=subWhere(j);j++;}}
function subShow(i){subLit=i;subMark();subPart();subLight();}
function subKeep(i){subPin=subPin==i?-1:i;subMark();subPart();subLight();}
function subChecks(s){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e){}var L=[],i,f,was=SUBCHK[subPin]?SUBCHK[subPin].text:null,n=[0,0,0],h='',p=[];
try{L=JSON.parse(s)||[];}catch(e){L=[];}
SUBCHK=[];subLit=-1;subPin=-1;for(i=0;i<L.length;i++){f={level:SUBLEVEL[L[i].level]?L[i].level:'note',text:L[i].text||'',cells:L[i].cells||[],part:L[i].part||''};SUBCHK.push(f);if(was!==null&&f.text==was)subPin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class=\'vd bad\'><b>Not ready to assemble.</b> '+subSeveral(n[0],'thing')+' to fix first.</div>';
else h+='<div class=vd><b>Ready to assemble.</b> As drawn she can be assembled on the water.'+(n[1]?'<div class=also>'+subSeveral(n[1],'warning')+' below will not stop the build, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<SUBCHK.length;i++){f=SUBCHK[i];h+='<div tabindex=0 id=ck_'+i+' class=ck'+(f.cells.length||f.part?' title=\'Click to keep it ringed on the plan; click again to let go\'':'')+'><span class=tag>'+SUBLEVEL[f.level][0]+'</span><span class=tx>'+subEsc(f.text)+(f.cells.length?'<span class=wh></span>':'')+'</span></div>';}
var c=document.getElementById('checks');c.innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(subSeveral(n[1],'warning'));if(n[2])p.push(subSeveral(n[2],'note'));document.getElementById('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<SUBCHK.length;i++)(function(i){var b=document.getElementById('ck_'+i);b.onmouseenter=b.onfocus=function(){subShow(i);};b.onmouseleave=b.onblur=function(){if(subLit==i)subShow(-1);};b.onclick=function(){subKeep(i);};})(i);
subMark();subPart();subLight();}
// The summary's own lines of findings are left out: the Checks panel has them.
var subStatsPlain=subStats;subStats=function(t){subStatsPlain((t+'').replace(/(<br>)?<span class=.(warning|notice).>.*?<\/span>/g,''));};
var subToolPlain=tool;tool=function(t){subToolPlain(t);subPart();};
var subDrawPlain=draw;draw=function(){subDrawPlain();subLight();};
// Pointing at a tool's button shows what it is before it is picked.
document.onmouseover=function(e){var b=e.target;while(b&&b.tagName!='BUTTON')b=b.parentNode;var k=b&&b.id&&b.id.indexOf('t_')==0?b.id.substring(2):null;if(k!=subPeek){subPeek=k;subPart();}};
load(START);tool('h');draw();
"}

/proc/sub_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[SUB_DESIGNER_WINDOW].browser:subStatus")

/proc/sub_designer_stats(mob/user, datum/sub_draught/D)
	user << output(list2params(list(D.summary_text())), "[SUB_DESIGNER_WINDOW].browser:subStats")
	// The same findings as fields, for the window's checks panel to lay out
	// and light up ("col,row" cells).
	var/datum/design_report/R = D.check_design()
	user << output(list2params(list(json_encode(R.data()))), "[SUB_DESIGNER_WINDOW].browser:subChecks")
	qdel(R)

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
	// Import and Export work the same in every designer (naval/draught_kinds.dm).
	if (href_list["sub"] == "import")
		sheet.draught_import_in_window(H, SUB_DESIGNER_WINDOW)
		return
	var/export = href_list["sub"] == "export"
	var/save = export || href_list["sub"] == "save"
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
		if (export)
			sheet.draught_export(H, D.name)
	qdel(D)

#undef SUB_DESIGNER_WINDOW
#undef SUB_DESIGNER_PREVIEW_GAP
