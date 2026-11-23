// Server-backed draught editor, using the same paper and writing tools as
// the other planners. One short design code fits in a single browse request.
#define WATERWORKS_DESIGNER_WINDOW "waterworks_designer"

/proc/waterworks_editors()
	var/static/list/editors = list()
	return editors

/datum/waterworks_designer
	var/mob/living/human/drawer
	var/client/drawer_client
	var/datum/admission
	var/obj/item/ship_draught/sheet
	var/source_code
	var/last_check = -10

/datum/waterworks_designer/Destroy()
	var/list/editors = waterworks_editors()
	if (drawer && editors[drawer] == src)
		editors -= drawer
	sheet = null
	drawer = null
	drawer_client = null
	admission = null
	return ..()

/obj/item/ship_draught/proc/open_waterworks_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src) || !waterworks_held(H))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw waterworks."))
		return
	var/datum/waterworks_plan/D = waterworks_plan()
	if (!D && draught_code)
		to_chat(H, SPAN_WARNING("The sheet already holds another drawing."))
		return
	if (!D)
		D = new
	var/list/editors = waterworks_editors()
	var/datum/waterworks_designer/old = editors[H]
	if (old)
		qdel(old)
	var/datum/waterworks_designer/A = new
	A.drawer = H
	A.drawer_client = H.client
	A.admission = persistence_admission_identity
	A.sheet = src
	A.source_code = draught_code
	editors[H] = A
	var/list/dimensions = waterworks_dimensions()
	var/list/parts = list()
	var/list/table = waterworks_parts()
	for (var/key in table)
		var/list/P = table[key]
		parts[key] = list("name" = P["name"], "mode" = P["mode"], "use" = P["use"], "role" = P["role"], "research" = P["research"], "cost" = "[P["units"]] [P["stock"]]")
	var/list/data = list("ref" = "\ref[A]", "side" = dimensions[1], "limit" = dimensions[2], "parts" = parts, "route" = D.route, "name" = D.name, "mode" = D.mode)
	var/list/halves = splittext(waterworks_designer_page(), "@@DATA@@")
	show_browse(H, halves[1] + json_encode(data) + halves[2], "window=[WATERWORKS_DESIGNER_WINDOW];size=840x680")
	onclose(H, WATERWORKS_DESIGNER_WINDOW, A)
	qdel(D)

/datum/waterworks_designer/proc/answer(mob/living/human/H, message, datum/waterworks_plan/D)
	var/list/data = list("message" = message)
	if (D)
		var/turf/T = get_turf(H)
		var/datum/design_report/R = D.check_design()
		var/list/seen = cartography_visible_turfs(H)
		D.check_site(T, R, seen, H)
		data["checks"] = R.data()
		data["materials"] = D.materials(T, seen, H)
		data["site"] = T ? "[T.x], [T.y], level [T.z]" : "no ground"
		qdel(R)
	H << output(list2params(list(json_encode(data))), "[WATERWORKS_DESIGNER_WINDOW].browser:waterworksAnswer")

/datum/waterworks_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["waterworks"] || H != drawer || waterworks_editors()[H] != src || !drawer_client || H.client != drawer_client || drawer_client.mob != H)
		return
	if (!ship_designer_can_draw(H, sheet) || !sheet.waterworks_held(H))
		answer(H, "Hold this sheet and a pen or pencil.")
		return
	if (source_code != sheet.draught_code)
		answer(H, "The sheet changed. Close this window and open its current drawing.")
		return
	var/action = href_list["waterworks"]
	if (!(action in list("preview", "save", "export", "import")) || world.time < last_check + 3)
		return
	last_check = world.time
	if (action != "preview" && !sheet.waterworks_context(H, drawer_client, admission, source_code))
		answer(H, "The world has saved or loaded. Reopen the sheet before saving another drawing.")
		return
	if (href_list["waterworks"] == "import")
		var/datum/callback/recheck = CALLBACK(sheet, TYPE_PROC_REF(/obj/item/ship_draught, waterworks_context), H, drawer_client, admission, source_code)
		sheet.draught_import_in_window(H, WATERWORKS_DESIGNER_WINDOW, recheck)
		qdel(recheck)
		return
	var/code = href_list["code"]
	var/datum/waterworks_plan/D = istext(code) && length(code) <= DESIGN_CODE_WATER_MAX ? waterworks_plan_from_code(code) : null
	if (!D)
		answer(H, "That drawing could not be read.")
		return
	if (action != "preview")
		sheet.take_waterworks(D)
		source_code = sheet.draught_code
	answer(H, action == "preview" ? "Site checked. Save before pegging." : "Saved. Use the sheet menu to peg this route.", D)
	if (action == "export")
		sheet.draught_export(H, D.name)
	qdel(D)

/proc/waterworks_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'>
<title>Waterworks planner</title><style>
body{background:#211c16;color:#e9dfc8;font:13px Verdana,sans-serif;margin:10px}
h1{font-size:17px;margin:0 0 6px} h2{font-size:14px;color:#ffd985;margin:8px 0 4px}
p{margin:6px 0} #layout{display:flex;align-items:flex-start;gap:12px}
#drawing{flex:0 0 448px;margin-right:10px} #details{flex:1}
#grid{border-collapse:collapse;background:#d9c9a3;table-layout:fixed} #grid td{padding:0;border:1px solid #b19c73}
#grid button{width:34px;height:30px;padding:0;display:block;margin:0;background:transparent;color:#2a1c0e;border:0}
#grid button.on{background:#17505f;color:#fff} #grid button.mark{background:#a63a22;color:#fff}
button,select,input{background:#4a3a2a;border:1px solid #806040;color:#f2e5ca;margin-right:4px;padding:4px}
button:hover,button:focus{border-color:#ffd985;cursor:pointer} .hint{color:#c5b48e}
#checks{margin:0;padding-left:18px} #checks li{padding:2px;outline-offset:2px} #checks .error{color:#ffb098} #checks .warning{color:#f5da8c}
#status{color:#ffd985;min-height:18px}
</style></head><body>
<h1>Waterworks planner</h1>
<p class='hint'>Stand at the south-west grid corner. North is up. Only tiles you can see in good light can be surveyed and pegged.</p>
<div id='layout'><div id='drawing'>
<p><label for='name'>Plan name </label><input id='name' maxlength='40'>
<label for='mode'>Network </label><select id='mode'><option value='A'>Aqueduct</option><option value='S'>Sewer</option></select></p>
<table id='grid' aria-label='Route drawing, north at the top'></table>
<p><button id='undo'>Remove last</button><button id='clear'>Clear drawing</button></p>
<p class='hint'>Click a tile to add a part, or select another part to replace a numbered tile. Start at the inlet and follow tile edges.</p>
</div><div id='details'>
<label for='palette'>Part </label><select id='palette'></select>
<p id='parthelp' class='hint'></p>
<p><button id='preview'>Preview site</button><button id='save'>Save to sheet</button></p>
<p><button id='export'>Export code</button><button id='import'>Import code</button></p>
<p id='status' role='status'></p>
<h2>Material estimate</h2><p id='materials' class='hint'>Preview for quantities. Unsurveyed pieces are counted as unbuilt.</p>
<h2>Checks</h2><p id='site' class='hint'></p><ul id='checks'></ul>
<p class='hint'>Once saved, close the editor and use the sheet to peg the route. Pegs do not build or pay for parts.</p>
</div></div>
<script>
var D=@@DATA@@, route=D.route||[], buttons={}, marked=[], rev=0;
function el(id){return document.getElementById(id);}
function tile(x,y){return x+','+y;}
function index(x,y){for(var i=0;i<route.length;i++)if(route[i][0]===x&&route[i][1]===y)return i;return -1;}
function highlight(cells){var i;for(i=0;i<marked.length;i++)if(buttons[marked[i]])buttons[marked[i]].classList.remove('mark');marked=cells||[];for(i=0;i<marked.length;i++)if(buttons[marked[i]])buttons[marked[i]].classList.add('mark');}
function paint(){var k,b,i;highlight([]);for(k in buttons){b=buttons[k];b.textContent='';b.className='';b.title=k;}
for(i=0;i<route.length;i++){k=tile(route[i][0],route[i][1]);b=buttons[k];b.className='on';b.textContent=i+1;b.title=k+': '+D.parts[route[i][2]].name;}}
function dirty(){rev++;paint();el('checks').textContent='';el('site').textContent='';el('materials').textContent='Preview for quantities. Unsurveyed pieces are counted as unbuilt.';el('status').textContent='Drawing changed locally. Preview or save it.';}
function partHelp(){var p=D.parts[el('palette').value];el('parthelp').textContent=p.use+' Recipe: '+p.cost+' ('+p.research+').';}
function palette(){var box=el('palette'),k,p,o;box.textContent='';for(k in D.parts){p=D.parts[k];if(p.mode!==el('mode').value)continue;o=document.createElement('option');o.value=k;o.textContent=p.name;box.appendChild(o);}partHelp();}
function add(x,y){var i=index(x,y),last=route[route.length-1],p=el('palette').value;if(i>=0){route[i][2]=p;dirty();return;}
if(route.length>=D.limit){el('status').textContent='This sheet holds '+D.limit+' route tiles.';return;}
if(last&&Math.abs(last[0]-x)+Math.abs(last[1]-y)!==1){el('status').textContent='Add the next part on a tile edge touching the last one.';return;}
route.push([x,y,p]);dirty();}
function send(action){var href='?src='+D.ref+';waterworks='+action;if(action!=='import'){var n=el('name').value.replace(/[^a-z0-9 -]/gi,'').replace(/ /g,'_')||'waterworks';
href+=';code='+encodeURIComponent('C13WATER/1/'+n+'/'+el('mode').value+'/'+(route.length?route.join(';'):'-'));D.sent=rev;}
window.location=href;}
function waterworksAnswer(raw){var a=JSON.parse(raw),ch=el('checks'),m=el('materials'),items=[],k,i,f,li;el('status').textContent=a.message;
if(!a.checks||D.sent!==rev)return;
highlight([]);ch.textContent='';el('site').textContent='South-west origin: '+a.site;
for(k in a.materials)items.push(a.materials[k]+' '+k);
m.textContent=items.join(', ')||'No unbuilt parts on this drawing.';
if(!a.checks.length)ch.textContent='No planner findings at this site.';
for(i=0;i<a.checks.length;i++){f=a.checks[i];li=document.createElement('li');li.className=f.level;li.tabIndex=0;li.textContent=f.level+': '+f.text;
(function(c){li.onmouseover=li.onfocus=function(){highlight(c);};li.onmouseout=li.onblur=function(){highlight([]);};})(f.cells);ch.appendChild(li);}}
el('name').value=D.name;el('name').oninput=dirty;el('mode').value=D.mode;palette();
el('mode').onchange=function(){if(route.length&&!window.confirm('Clear this drawing to switch networks? The saved sheet stays as it was until you save.')){this.value=D.mode;return;}D.mode=this.value;route=[];palette();dirty();};
el('palette').onchange=partHelp;el('undo').onclick=function(){if(route.length){route.pop();dirty();}};
el('clear').onclick=function(){if(route.length&&window.confirm('Clear the drawing?')){route=[];dirty();}};
['preview','save','export','import'].forEach(function(a){el(a).onclick=function(){if(a!=='import'||window.confirm('Replace the drawing with an imported design?'))send(a);};});
for(var y=D.side;y>=1;y--){var row=el('grid').insertRow(-1);for(var x=1;x<=D.side;x++){var b=document.createElement('button');b.type='button';b.setAttribute('aria-label','Tile '+tile(x,y));
(function(px,py){b.onclick=function(){add(px,py);};})(x,y);row.insertCell(-1).appendChild(b);buttons[tile(x,y)]=b;}}
paint();
</script></body></html>"}

#undef WATERWORKS_DESIGNER_WINDOW
