// Faction symbol / faction creation canvas -- binds the 32x32 pixel grid.
// Shared by both drawing UIs (faction_symbol.tmpl and faction_creation.tmpl).
//
// The PAINT tool works as a click-drag brush: cells are painted locally the
// moment the mouse crosses them (instant feedback, with Bresenham
// interpolation between mouse samples so a fast drag still leaves a solid
// line), and the whole stroke is committed to the server as ONE Topic call on
// mouse-up -- one navigation per painted pixel would both flood the server
// and tear down the DOM mid-drag with every refresh. One stroke = one undo
// step server-side.
//
// The BUCKET tool stays a plain click (the fill itself is server-side).
//
// Bindings are re-applied after every NanoUI update since the framework fully
// replaces the content markup on each refresh; the in-progress stroke lives
// in module-level state, which survives those rebuilds (same pattern as
// research_tree.js).

var fsStrokeCells = null; // in-progress stroke: ordered "x,y" strings
var fsStrokeSeen = null;  // dedupe map for the current stroke
var fsLastX = 0;
var fsLastY = 0;

// Old-IE URL length limit is ~2083 chars; ~200 cells per href stays safely
// under it. Follow-up chunks carry stroke_continue so the server treats the
// whole stroke as a single undo step.
var FS_STROKE_CHUNK = 200;

function fsCanvas() {
	return document.getElementById('fs-canvas');
}

function fsTool() {
	var c = fsCanvas();
	return (c && c.getAttribute('data-tool')) || 'paint';
}

function fsColor() {
	var c = fsCanvas();
	return (c && c.getAttribute('data-color')) || '#000000';
}

function fsPaintLocal(x, y) {
	var key = x + ',' + y;
	if (fsStrokeSeen[key]) return;
	fsStrokeSeen[key] = true;
	fsStrokeCells.push(key);
	var el = document.querySelector('.fs-cell[data-x="' + x + '"][data-y="' + y + '"]');
	if (el) el.style.backgroundColor = fsColor();
}

// Bresenham between two sampled cells, so dragging faster than the browser
// fires mouseover events still paints an unbroken line.
function fsPaintLine(x0, y0, x1, y1) {
	var dx = Math.abs(x1 - x0);
	var dy = Math.abs(y1 - y0);
	var sx = x0 < x1 ? 1 : -1;
	var sy = y0 < y1 ? 1 : -1;
	var err = dx - dy;
	while (true) {
		fsPaintLocal(x0, y0);
		if (x0 === x1 && y0 === y1) break;
		var e2 = 2 * err;
		if (e2 > -dy) { err -= dy; x0 += sx; }
		if (e2 < dx) { err += dx; y0 += sy; }
	}
}

// While a multi-chunk stroke is still being sent (each chunk is its own timed
// byond:// navigation), any OTHER action -- a new stroke, Undo, Clear, Save --
// would interleave with the remaining chunks server-side and corrupt the
// stroke/undo state. This editor is single-user, so a client-side lock for the
// in-flight window (a second or two at worst) is all the serialisation needed.
var fsChunksInFlight = false;

function fsSendChunks(cells, offset) {
	var chunk = cells.slice(offset, offset + FS_STROKE_CHUNK);
	if (!chunk.length) {
		fsChunksInFlight = false;
		return;
	}
	// Joined with '_', NOT ';': NanoUtility.generateHref() builds the href by
	// plain concatenation with ';' between parameters and no URL-encoding, so
	// BYOND's param parser treats every ';' as a parameter separator -- a
	// ';'-joined stroke arrives as just its first cell (the rest become junk
	// params). '_' is a URL-unreserved character both the browser and BYOND
	// pass through untouched.
	var params = { stroke: 1, cells: chunk.join('_') };
	if (offset > 0) {
		params.stroke_continue = 1;
	}
	window.location.href = NanoUtility.generateHref(params);
	if (offset + FS_STROKE_CHUNK < cells.length) {
		fsChunksInFlight = true;
		// Space follow-up chunks out so each byond:// navigation actually
		// lands instead of being replaced by the next one.
		setTimeout(function () { fsSendChunks(cells, offset + FS_STROKE_CHUNK); }, 250);
	} else {
		fsChunksInFlight = false;
	}
}

// Swallow toolbar clicks (Undo/Clear/Save/stamp links) while chunks are still
// in flight, so they can't slip between two chunks of the same stroke.
function fsSuppressClicksInFlight(e) {
	if (!fsChunksInFlight) return;
	var ev = e || window.event;
	var t = ev.target || ev.srcElement;
	while (t && t.nodeType === 1) {
		if (t.tagName === 'A') {
			if (ev.preventDefault) ev.preventDefault();
			ev.returnValue = false;
			return false;
		}
		t = t.parentNode;
	}
}
if (document.addEventListener) {
	document.addEventListener('click', fsSuppressClicksInFlight, true);
} else if (document.attachEvent) {
	document.attachEvent('onclick', fsSuppressClicksInFlight);
}

function fsEndStroke() {
	if (!fsStrokeCells) return;
	var cells = fsStrokeCells;
	fsStrokeCells = null;
	fsStrokeSeen = null;
	if (cells.length) {
		fsSendChunks(cells, 0);
	}
}

function fsBindCells() {
	var cells = document.querySelectorAll('.fs-cell');
	for (var i = 0; i < cells.length; i++) {
		(function (el) {
			var x = parseInt(el.getAttribute('data-x'), 10);
			var y = parseInt(el.getAttribute('data-y'), 10);
			el.onmousedown = function (e) {
				// Don't start anything while a previous stroke's chunks are
				// still being sent -- new cells would interleave with them.
				if (fsChunksInFlight) {
					if (e && e.preventDefault) e.preventDefault();
					return false;
				}
				if (fsTool() === 'paint') {
					// A mouse-up outside the window can strand a stroke;
					// commit it before starting the new one.
					if (fsStrokeCells) fsEndStroke();
					fsStrokeCells = [];
					fsStrokeSeen = {};
					fsPaintLocal(x, y);
					fsLastX = x;
					fsLastY = y;
				} else {
					window.location.href = NanoUtility.generateHref({ paint: 1, x: x, y: y });
				}
				// No text/image drag-selection while stroking.
				if (e && e.preventDefault) e.preventDefault();
				return false;
			};
			el.onmouseover = function () {
				if (!fsStrokeCells) return;
				fsPaintLine(fsLastX, fsLastY, x, y);
				fsLastX = x;
				fsLastY = y;
			};
		})(cells[i]);
	}
	// Ending on the document, not the canvas: releasing the button outside
	// the grid still commits the stroke.
	document.onmouseup = fsEndStroke;
	var canvas = fsCanvas();
	if (canvas) {
		canvas.onselectstart = function () { return false; };
	}
}

if (typeof NanoStateManager !== 'undefined') {
	NanoStateManager.addAfterUpdateCallback('faction_symbol', function (data) {
		fsBindCells();
		return data;
	});
}
fsBindCells();
