// Staff karma analysis view (code/modules/karma/karma_analysis.dm).
// KARMA_ROWS: one object per live rating, from the coordinator's karma files.
// Everything here is filtering and arithmetic in the viewer's window: the game
// does no work while staff explore.
var KARMA = { rows: [], focus: "", sortKey: "count", sortDesc: true };

var KARMA_GROUPS = {
	"target": function (r) { return r.target; },
	"giver": function (r) { return r.giver; },
	"kind": function (r) { return r.kind; },
	"giver_standing": function (r) { return r.giver_standing; },
	"playtime_band": function (r) { return karmaBand(r.giver_hours); },
	"faction": function (r) { return r.faction || "(none)"; },
	"region": function (r) { return r.region || "(unknown)"; },
	"notes": function (r) { return r.giver_notes ? "giver has notes" : "no notes"; },
	"flag": function (r) { return r.flags.length ? r.flags.join(", ") : "(no flags)"; },
	"week": function (r) { return karmaWeek(r.at); }
};

var KARMA_PRESETS = {
	"": null,
	"poorly_from_good": { group: "target", kind: "poorly", standing: "good_up", sort: "count" },
	"swing_7d": { group: "target", days: 7, sort: "abs_net" },
	"most_flagged": { group: "target", flagged: true, sort: "count" },
	"mostly_poorly": { group: "giver", sort: "share_poorly", min: 3 },
	"disagree": { group: "giver", disagree: true, sort: "count" }
};

function karmaBand(h) {
	if (h < 10) return "under 10 h";
	if (h < 50) return "10-50 h";
	if (h < 200) return "50-200 h";
	return "200+ h";
}

function karmaWeek(date) {
	var d = new Date(date + "T00:00:00Z");
	if (isNaN(d.getTime())) return "(unknown)";
	var day = (d.getUTCDay() + 6) % 7;
	var monday = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - day));
	return "week of " + monday.toISOString().slice(0, 10);
}

function karmaEl(id) { return document.getElementById(id); }

function karmaWeight(r, on) {
	if (on.banned && r.flags.indexOf("giver_banned") >= 0) return 0;
	return (on.standing ? r.factors.standing : 1) * (on.playtime ? r.factors.playtime : 1) * (on.age ? r.factors.age : 1);
}

function karmaOptions() {
	return {
		group: karmaEl("k_group").value,
		kind: karmaEl("k_kind").value,
		standing: karmaEl("k_standing").value,
		from: karmaEl("k_from").value,
		to: karmaEl("k_to").value,
		minHours: parseFloat(karmaEl("k_minhours").value) || 0,
		notes: karmaEl("k_notes").checked,
		flagged: karmaEl("k_flagged").checked,
		disagree: karmaEl("k_disagree").checked,
		target: karmaEl("k_target").value.toLowerCase(),
		giver: karmaEl("k_giver").value.toLowerCase(),
		faction: karmaEl("k_faction").value.toLowerCase(),
		region: karmaEl("k_region").value.toLowerCase(),
		min: parseInt(karmaEl("k_min").value, 10) || 0,
		on: {
			standing: karmaEl("k_f_standing").checked,
			playtime: karmaEl("k_f_playtime").checked,
			age: karmaEl("k_f_age").checked,
			banned: karmaEl("k_f_banned").checked
		}
	};
}

function karmaDisagrees(r) {
	if (r.target_standing === null || r.target_standing === undefined || r.target_standing === 0) return false;
	return (r.kind === "kindly") !== (r.target_standing > 0);
}

function karmaFilter(o) {
	var out = [];
	for (var i = 0; i < KARMA.rows.length; i++) {
		var r = KARMA.rows[i];
		if (o.kind && r.kind !== o.kind) continue;
		if (o.standing === "good_up" && r.giver_standing !== "good" && r.giver_standing !== "trusted") continue;
		if (o.standing === "poor_down" && r.giver_standing !== "poor" && r.giver_standing !== "bad") continue;
		if (o.standing && o.standing !== "good_up" && o.standing !== "poor_down" && r.giver_standing !== o.standing) continue;
		if (o.from && r.at < o.from) continue;
		if (o.to && r.at > o.to) continue;
		if (r.giver_hours < o.minHours) continue;
		if (o.notes && !r.giver_notes) continue;
		if (o.flagged && !r.flags.length) continue;
		if (o.disagree && !karmaDisagrees(r)) continue;
		if (o.target && r.target.indexOf(o.target) < 0) continue;
		if (o.giver && r.giver.indexOf(o.giver) < 0) continue;
		if (o.faction && (r.faction || "").toLowerCase().indexOf(o.faction) < 0) continue;
		if (o.region && (r.region || "").toLowerCase().indexOf(o.region) < 0) continue;
		out.push(r);
	}
	return out;
}

function karmaGroup(rows, o) {
	var key = KARMA_GROUPS[o.group] || KARMA_GROUPS.target;
	var groups = {};
	var order = [];
	for (var i = 0; i < rows.length; i++) {
		var r = rows[i];
		var k = key(r);
		var g = groups[k];
		if (!g) {
			g = groups[k] = { name: k, count: 0, kindly: 0, poorly: 0, wk: 0, wp: 0, noted: 0, flagged: 0, hours: 0 };
			order.push(g);
		}
		var w = karmaWeight(r, o.on);
		g.count++;
		if (r.kind === "kindly") { g.kindly++; g.wk += w; } else { g.poorly++; g.wp += w; }
		if (r.giver_notes) g.noted++;
		if (r.flags.length) g.flagged++;
		g.hours = Math.max(g.hours, r.target_hours || 0);
	}
	var out = [];
	for (var j = 0; j < order.length; j++) {
		var x = order[j];
		if (x.count < o.min) continue;
		x.net = x.wk - x.wp;
		x.abs_net = Math.abs(x.net);
		x.per10h = o.group === "target" ? x.net / Math.max(x.hours, 1) * 10 : null;
		x.share_noted = x.noted / x.count;
		x.share_flagged = x.flagged / x.count;
		x.share_poorly = x.poorly / x.count;
		out.push(x);
	}
	var s = KARMA.sortKey, d = KARMA.sortDesc ? -1 : 1;
	out.sort(function (a, b) {
		var av = a[s], bv = b[s];
		if (av === null) av = -Infinity;
		if (bv === null) bv = -Infinity;
		if (typeof av === "string") return av < bv ? -d : av > bv ? d : 0;
		return av < bv ? -d : av > bv ? d : 0;
	});
	return out;
}

var KARMA_COLUMNS = [
	["name", "Group"], ["count", "Ratings"], ["kindly", "Kindly"], ["poorly", "Poorly"], ["wk", "Weighted kindly"],
	["wp", "Weighted poorly"], ["net", "Net weighted"], ["per10h", "Net per 10 h"], ["share_noted", "From noted givers"],
	["share_flagged", "Flagged"], ["share_poorly", "Poorly share"]
];

function karmaCell(v) {
	if (v === null || v === undefined) return "";
	if (typeof v === "number") return (Math.round(v * 100) / 100).toString();
	return v;
}

function karmaText(tag, text) {
	var e = document.createElement(tag);
	e.textContent = text;
	return e;
}

function karmaRender() {
	var o = karmaOptions();
	var rows = karmaFilter(o);
	var groups = karmaGroup(rows, o);
	var table = karmaEl("k_table");
	table.innerHTML = "";
	var head = document.createElement("tr");
	for (var c = 0; c < KARMA_COLUMNS.length; c++) {
		var th = karmaText("th", KARMA_COLUMNS[c][1] + (KARMA.sortKey === KARMA_COLUMNS[c][0] ? (KARMA.sortDesc ? " v" : " ^") : ""));
		th.setAttribute("data-key", KARMA_COLUMNS[c][0]);
		th.style.cursor = "pointer";
		th.onclick = function () {
			var k = this.getAttribute("data-key");
			if (KARMA.sortKey === k) KARMA.sortDesc = !KARMA.sortDesc; else { KARMA.sortKey = k; KARMA.sortDesc = true; }
			karmaRender();
		};
		head.appendChild(th);
	}
	table.appendChild(head);
	for (var i = 0; i < groups.length; i++) {
		var tr = document.createElement("tr");
		for (var k = 0; k < KARMA_COLUMNS.length; k++) {
			var key = KARMA_COLUMNS[k][0];
			var v = groups[i][key];
			if (key.indexOf("share_") === 0) v = Math.round(v * 100) + "%";
			tr.appendChild(karmaText("td", karmaCell(v)));
		}
		table.appendChild(tr);
	}
	karmaEl("k_count").textContent = rows.length + " ratings in " + groups.length + " groups";
	karmaDetail(rows, o);
	karmaCsv(rows, o);
}

function karmaDetail(rows, o) {
	var table = karmaEl("k_rows");
	table.innerHTML = "";
	if (!karmaEl("k_showrows").checked) return;
	var cols = ["target", "giver", "kind", "weight", "giver_standing", "giver_hours", "giver_notes", "flags", "faction", "region", "at", "note"];
	var head = document.createElement("tr");
	for (var c = 0; c < cols.length; c++) head.appendChild(karmaText("th", cols[c]));
	table.appendChild(head);
	for (var i = 0; i < rows.length && i < 2000; i++) {
		var r = rows[i];
		var tr = document.createElement("tr");
		for (var k = 0; k < cols.length; k++) {
			var v = cols[k] === "weight" ? karmaWeight(r, o.on) : cols[k] === "flags" ? r.flags.join(" ") : r[cols[k]];
			tr.appendChild(karmaText("td", karmaCell(v === true ? "yes" : v === false ? "no" : v)));
		}
		table.appendChild(tr);
	}
}

function karmaCsvField(v) {
	v = v === null || v === undefined ? "" : String(v);
	return /[",\n]/.test(v) ? "\"" + v.replace(/"/g, "\"\"") + "\"" : v;
}

function karmaCsv(rows, o) {
	var cols = ["target", "target_hours", "target_standing", "giver", "kind", "weight", "giver_standing", "giver_hours", "giver_notes", "flags", "faction", "region", "at", "note"];
	var lines = [cols.join(",")];
	for (var i = 0; i < rows.length; i++) {
		var r = rows[i], line = [];
		for (var k = 0; k < cols.length; k++) {
			var v = cols[k] === "weight" ? karmaCell(karmaWeight(r, o.on)) : cols[k] === "flags" ? r.flags.join(" ") : r[cols[k]];
			line.push(karmaCsvField(v));
		}
		lines.push(line.join(","));
	}
	karmaEl("k_csv").value = lines.join("\n");
}

function karmaPreset() {
	var p = KARMA_PRESETS[karmaEl("k_preset").value];
	if (!p) return;
	karmaEl("k_group").value = p.group;
	karmaEl("k_kind").value = p.kind || "";
	karmaEl("k_standing").value = p.standing || "";
	karmaEl("k_flagged").checked = !!p.flagged;
	karmaEl("k_disagree").checked = !!p.disagree;
	karmaEl("k_min").value = p.min || "";
	var from = "";
	if (p.days) from = new Date(Date.now() - p.days * 86400000).toISOString().slice(0, 10);
	karmaEl("k_from").value = from;
	KARMA.sortKey = p.sort;
	KARMA.sortDesc = true;
	karmaRender();
}

function karmaInit(rows, focus) {
	KARMA.rows = rows || [];
	KARMA.focus = focus || "";
	if (KARMA.focus) {
		karmaEl("k_target").value = KARMA.focus;
		karmaEl("k_group").value = "giver";
	}
	var inputs = document.querySelectorAll("#k_controls input, #k_controls select");
	for (var i = 0; i < inputs.length; i++) {
		if (inputs[i].id === "k_preset") continue;
		inputs[i].onchange = karmaRender;
		inputs[i].onkeyup = karmaRender;
	}
	karmaEl("k_preset").onchange = karmaPreset;
	karmaRender();
}
