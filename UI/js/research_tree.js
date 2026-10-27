// Research tree - tech-tree view: prerequisite connector lines + click-through
// detail popup. Re-runs after every NanoUI update since the framework fully
// replaces #uiContent's markup on each refresh (see nano_state.js onUpdate).

// Persisted across refreshes (the DOM gets torn down and rebuilt every
// auto-update cycle, but this module-level state does not) so a click stays
// open/highlighted through the next periodic refresh instead of snapping shut.
var rtOpenNodeId = null;
// Which tree tab is active, persisted across the framework's full re-renders
// (same rationale as rtOpenNodeId) so switching tabs sticks through refreshes.
var rtActiveTreeIdx = 0;

// The currently-visible tree panel (falls back to the first one).
function rtActivePanel() {
	return document.querySelector('.rt-tree-panel[data-tree-idx="' + rtActiveTreeIdx + '"]')
		|| document.querySelector('.rt-tree-panel');
}

function rtDrawLines() {
	// Decorative only -- wrapped so a rendering quirk in the embedded browser
	// (e.g. IE's SVG elements not supporting innerHTML) can never throw out of
	// here and abort the CALLER (tab switching / post-update restore), which
	// would leave the UI half-switched with dead nodes.
	try {
		rtDrawLinesInner();
	} catch (err) {
		// lines just don't draw this pass; everything else keeps working
	}
}

function rtDrawLinesInner() {
	var panel = rtActivePanel();
	if (!panel) return;
	// Only the active panel is displayed; measuring a display:none panel yields
	// zeroed rects, so we always draw for the visible one.
	var wrap = panel.querySelector('.rt-tree-wrap');
	var svg = panel.querySelector('.rt-lines');
	if (!wrap || !svg) return;

	// Not innerHTML: IE's SVG DOM doesn't implement it (throws).
	while (svg.firstChild) {
		svg.removeChild(svg.firstChild);
	}
	// Explicit width AND height attributes (not just CSS width:100%) so the
	// SVG's internal coordinate space is 1:1 with real pixels. Without this,
	// an SVG with no viewBox defaults to a 300-unit-wide coordinate space
	// that then gets stretched by the browser to fill the CSS width, which
	// silently distorts every x-coordinate we compute below.
	svg.setAttribute('width', wrap.scrollWidth);
	svg.setAttribute('height', wrap.scrollHeight);

	var nodes = wrap.querySelectorAll('.rt-node[data-id]');
	var byId = {};
	for (var i = 0; i < nodes.length; i++) {
		byId[nodes[i].getAttribute('data-id')] = nodes[i];
	}

	var wrapRect = wrap.getBoundingClientRect();

	for (var j = 0; j < nodes.length; j++) {
		var child = nodes[j];
		var prereqAttr = child.getAttribute('data-prereqs');
		if (!prereqAttr) continue;
		var prereqIds = prereqAttr.split(',');
		for (var k = 0; k < prereqIds.length; k++) {
			var parent = byId[prereqIds[k]];
			if (!parent) continue;

			var pr = parent.getBoundingClientRect();
			var cr = child.getBoundingClientRect();

			// Line runs from the END (right edge) of the prerequisite node
			// to the BEGINNING (left edge) of the node that depends on it.
			var x1 = pr.right - wrapRect.left;
			var y1 = pr.top + pr.height / 2 - wrapRect.top;
			var x2 = cr.left - wrapRect.left;
			var y2 = cr.top + cr.height / 2 - wrapRect.top;
			var midX = x1 + (x2 - x1) / 2;

			var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
			path.setAttribute('d', 'M' + x1 + ',' + y1 + ' C' + midX + ',' + y1 + ' ' + midX + ',' + y2 + ' ' + x2 + ',' + y2);
			path.setAttribute('fill', 'none');
			path.setAttribute('stroke', '#8a6d3f');
			path.setAttribute('stroke-width', '1.5');
			path.setAttribute('opacity', '0.55');
			svg.appendChild(path);
		}
	}
}

// Recursively collects every ancestor (prereq, prereq-of-prereq, ...) of
// nodeId that is still locked, so the whole outstanding chain can be lit up.
function rtCollectLockedAncestors(nodeId, visited) {
	visited = visited || {};
	var el = document.querySelector('.rt-node[data-id="' + nodeId + '"]');
	if (!el) return visited;
	var prereqAttr = el.getAttribute('data-prereqs');
	if (!prereqAttr) return visited;
	var ids = prereqAttr.split(',');
	for (var i = 0; i < ids.length; i++) {
		var pid = ids[i];
		if (!pid || visited[pid]) continue;
		visited[pid] = true;
		rtCollectLockedAncestors(pid, visited);
	}
	return visited;
}

function rtClearHighlights() {
	var highlighted = document.querySelectorAll('.rt-ancestor-highlight');
	for (var i = 0; i < highlighted.length; i++) {
		highlighted[i].classList.remove('rt-ancestor-highlight');
	}
}

function rtHighlightChain(nodeId) {
	rtClearHighlights();
	var ancestors = rtCollectLockedAncestors(nodeId);
	for (var id in ancestors) {
		if (!ancestors.hasOwnProperty(id)) continue;
		var el = document.querySelector('.rt-node[data-id="' + id + '"]');
		if (el && el.classList.contains('rt-status-locked')) {
			el.classList.add('rt-ancestor-highlight');
		}
	}
}

function rtOpenDetail(nodeId) {
	var source = document.getElementById('rt-detail-' + nodeId);
	var body = document.getElementById('rt-modal-body');
	var backdrop = document.getElementById('rt-modal-backdrop');
	if (!source || !body || !backdrop) return;

	rtOpenNodeId = nodeId;
	body.innerHTML = source.innerHTML;

	// Copied markup loses any event listeners the framework bound to the
	// original .linkActive element (it re-binds those on its own schedule,
	// not on-demand) -- wire the click ourselves so "Assign" works instantly.
	var links = body.querySelectorAll('.linkActive[data-href]');
	for (var i = 0; i < links.length; i++) {
		(function (el) {
			el.onclick = function (e) {
				e.preventDefault();
				window.location.href = el.getAttribute('data-href');
			};
		})(links[i]);
	}

	backdrop.className = 'rt-open';
	rtHighlightChain(nodeId);
}

function rtCloseDetail() {
	rtOpenNodeId = null;
	var backdrop = document.getElementById('rt-modal-backdrop');
	if (backdrop) backdrop.className = '';
	rtClearHighlights();
}

// Node clicks are bound BOTH ways, belt and braces, because specialist-tab
// nodes have a history of being unclickable in BYOND's embedded browser
// while the same code passes in a desktop browser:
//   1. A direct onclick on every node -- the same primitive mechanism the
//      faction symbol editor's pixel grid uses, proven in this browser. It
//      is (re)applied on every refresh AND again right after every tab
//      switch, so nodes revealed from a display:none panel always get a
//      fresh binding while visible.
//   2. A document-level delegated listener as a fallback for anything that
//      somehow slipped binding (full DOM rebuilds, exotic event quirks).
function rtBindNodeClicks() {
	var nodes = document.querySelectorAll('.rt-node[data-id]');
	for (var i = 0; i < nodes.length; i++) {
		(function (el) {
			el.onclick = function () {
				rtOpenDetail(el.getAttribute('data-id'));
			};
		})(nodes[i]);
	}
}

var rtDelegationInstalled = false;
function rtInstallDelegation() {
	if (rtDelegationInstalled) return;
	rtDelegationInstalled = true;
	if (!document.addEventListener) return; // ancient engine: direct bindings still cover us
	document.addEventListener('click', function (e) {
		var el = e.target;
		while (el && el.nodeType === 1) {
			if (el.className && (' ' + el.className + ' ').indexOf(' rt-node ') >= 0 && el.getAttribute('data-id')) {
				// True fallback: a node that still carries its direct binding
				// already handled this click -- don't open the detail twice.
				if (el.onclick) return;
				rtOpenDetail(el.getAttribute('data-id'));
				return;
			}
			el = el.parentNode;
		}
	});
}

function rtBindNodes() {
	rtBindNodeClicks();
	rtInstallDelegation();

	var closeBtn = document.getElementById('rt-modal-close');
	if (closeBtn) closeBtn.onclick = rtCloseDetail;

	var backdrop = document.getElementById('rt-modal-backdrop');
	if (backdrop) {
		backdrop.onclick = function (e) {
			if (e.target === backdrop) rtCloseDetail();
		};
	}
}

// Show the tree panel at idx, hide the rest, sync the tab highlight, and
// (re)draw the connector lines for the now-visible panel.
function rtSwitchTree(idx) {
	rtActiveTreeIdx = idx;
	var panels = document.querySelectorAll('.rt-tree-panel');
	for (var i = 0; i < panels.length; i++) {
		var active = panels[i].getAttribute('data-tree-idx') == idx;
		panels[i].className = 'rt-tree-panel' + (active ? ' rt-tree-panel-active' : '');
	}
	var tabs = document.querySelectorAll('.rt-tab');
	for (var j = 0; j < tabs.length; j++) {
		var tActive = tabs[j].getAttribute('data-tree-idx') == idx;
		tabs[j].className = 'rt-tab' + (tActive ? ' rt-tab-active' : '');
	}
	// Rebind now that this panel's nodes are actually visible -- bindings made
	// while they sat in a display:none panel are the historic failure mode for
	// specialist tabs in BYOND's embedded browser.
	rtBindNodeClicks();
	rtDrawLines();
}

function rtBindTabs() {
	var tabs = document.querySelectorAll('.rt-tab');
	for (var i = 0; i < tabs.length; i++) {
		(function (el) {
			el.onclick = function () {
				rtSwitchTree(parseInt(el.getAttribute('data-tree-idx'), 10));
			};
		})(tabs[i]);
	}
}

function rtRefresh() {
	rtBindTabs();
	rtBindNodes();
	// Layout needs a tick to settle (grid reflow) before measuring positions.
	setTimeout(function () {
		// A fresh render marks tab 0 active in the markup; reassert whatever the
		// user had selected (this also draws the lines for that panel).
		rtSwitchTree(rtActiveTreeIdx);
		// The periodic auto-update replaces this whole content block, which
		// would otherwise silently snap the modal shut -- restore whatever
		// was open (and its highlight) right after the fresh render lands.
		if (rtOpenNodeId) {
			rtOpenDetail(rtOpenNodeId);
		}
	}, 30);
}

if (typeof NanoStateManager !== 'undefined') {
	NanoStateManager.addAfterUpdateCallback('research_tree', function (data) {
		rtRefresh();
		return data;
	});
}
rtRefresh();
if (window.addEventListener) {
	window.addEventListener('resize', rtDrawLines);
}
