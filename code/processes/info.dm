var/global/info_style = {"
   <style>

		html,
		body {
			margin: 0;
			padding: 0;
			background-color: #392611;
			color: #e1e1d7;
			font-family: "Book Antiqua", "Palatino Linotype", serif;
			text-rendering: optimizeLegibility;
			-webkit-font-smoothing: antialiased;
			-moz-osx-font-smoothing: grayscale;
			font-size: 14px;
			height: 100vh;
			display: flex;
			flex-direction: column;
		}

		h3 {
			font-size: 16px;
			font-weight: bold;
			padding-bottom: 2px;
			border-bottom: 1px solid;
		}

		#tabs {
			background-color: #271a0c;
			display: flex;
			border-bottom: 1px solid #1a1108;
			overflow-x: auto;
			flex-shrink: 0;
			scrollbar-face-color: #a68b7d;
			scrollbar-shadow-color: #271a0c;
			scrollbar-highlight-color: #e1e1d7;
			scrollbar-3dlight-color: #a68b7d;
			scrollbar-darkshadow-color: #000000;
			scrollbar-track-color: #392611;
			scrollbar-arrow-color: #271a0c;
		}

		/* Modern scrollbar for Chromium-based BYOND */
		#tabs::-webkit-scrollbar {
			width: 12px;
		}

		#tabs::-webkit-scrollbar-track {
			background: #392611;
		}

		#tabs::-webkit-scrollbar-thumb {
			background: #a68b7d;
			border: 2px solid #392611;
			border-radius: 4px;
		}

		#tabs::-webkit-scrollbar-thumb:hover {
			background: #bda294;
		}


		.tab {
			padding: 6px 12px;
			cursor: pointer;
			user-select: none;
			font-size: 15px;
			white-space: nowrap;
			border-right: 1px solid #1a1108;
		}

		.tab:hover {
			background-color: #3f2a13;
		}

		.tab.active {
			background-color: #392611;
			color: #ff8040;
		}

		#content {
			flex-grow: 1;
			overflow-y: auto;
			padding: 8px;
			scrollbar-face-color: #a68b7d;
			scrollbar-shadow-color: #271a0c;
			scrollbar-highlight-color: #e1e1d7;
			scrollbar-3dlight-color: #a68b7d;
			scrollbar-darkshadow-color: #000000;
			scrollbar-track-color: #392611;
			scrollbar-arrow-color: #271a0c;
		}

		/* Modern scrollbar for Chromium-based BYOND */
		#content::-webkit-scrollbar {
			width: 12px;
		}

		#content::-webkit-scrollbar-track {
			background: #392611;
		}

		#content::-webkit-scrollbar-thumb {
			background: #a68b7d;
			border: 2px solid #392611;
			border-radius: 4px;
		}

		#content::-webkit-scrollbar-thumb:hover {
			background: #bda294;
		}

		table.stat-table {
			width: 100%;
			border-collapse: collapse;
		}

		table.stat-table td {
			padding: 2px 4px;
			vertical-align: top;
		}

		table.stat-table td.stat-name {
			width: 40%;
			white-space: nowrap;
		}

		table.stat-table td.stat-value {
			width: 60%;
			word-break: break-word;
		}

		.verb-list {
			display: flex;
			flex-wrap: wrap;
			padding: 8px;
		}

		.verb-button {
			background: #271a0c;
			border: 1px solid #1a1108;
			color: #e1e1d7;
			padding: 4px 8px;
			border-radius: 3px;
			cursor: pointer;
			font-size: 13px;
			transition: all 0.1s;
			text-decoration: none;
			display: inline-block;
			margin-right: 6px;
			margin-bottom: 6px;
		}

		.verb-button:hover {
			background: #3f2a13;
			color: #ff8040;
			border-color: #ff8040;
		}

		.verb-button:active {
			background: #1a1108;
			transform: translateY(1px);
		}

		.verb-category-header {
			background: #1a1108;
			color: #ff8040;
			padding: 4px 8px;
			font-size: 14px;
			font-weight: bold;
			border-bottom: 1px solid #ff8040;
			margin-top: 10px;
		}

		.verb-category-header:first-child {
			margin-top: 0;
		}

		table.stat-table tr.empty-stat td {
			height: 10px;
		}
	</style>
"}
var/global/info_template = {"
<!DOCTYPE html>
<html>

<head>
	<meta charset="utf-8" />
	<meta http-equiv="X-UA-Compatible" content="IE=edge" />
	<title>Info Panels</title>
	[info_style]
</head>

<body>
	<div id="tabs"></div>
	<div id="content">
		<div id="stats-container">
			<div style="padding: 20px; text-align: center;">
				Loading info panel...
				/* STATS */
			</div>
		</div>
		<div id="verbs-container"></div>
	</div>

    <script>
        var currentTab = "Status";
        var lastTabsJSON = "";
        var lastVerbsJSON = "";
        var lastStatsJSON = "";
        var lastActiveTab = "";

        // Called by the server via output() each tick.
        function receiveStats(dataString) {
            if (!dataString) return;

            var data;
            try {
                data = JSON.parse(dataString);
            } catch (e) {
                return;
            }

            if (!data) return;

            if (data.current_tab) {
                currentTab = data.current_tab;
            }

            // Only render tabs if they changed or active tab changed
            var tabsJSON = JSON.stringify(data.tabs);
            if (tabsJSON !== lastTabsJSON || currentTab !== lastActiveTab) {
                renderTabs(data.tabs);
                lastTabsJSON = tabsJSON;
                lastActiveTab = currentTab;
            }

            // Only render stats if they changed
            var statsJSON = JSON.stringify(data.stats);
            if (statsJSON !== lastStatsJSON) {
                renderStats(data.stats);
                lastStatsJSON = statsJSON;
            }

            // Only render verbs if they changed
            var verbsJSON = JSON.stringify(data.verbs);
            if (verbsJSON !== lastVerbsJSON) {
                renderVerbs(data.verbs);
                lastVerbsJSON = verbsJSON;
            }
        }

        function renderVerbs(verbs) {
            var container = document.getElementById("verbs-container");
            container.innerHTML = "";

            // Group verbs by category
            var grouped = {};
            var i, v, cat;
            for (i = 0; i < verbs.length; i++) {
                v = verbs\[i];
                if (!grouped\[v.category]) grouped\[v.category] = \[];
                grouped\[v.category].push(v);
            }

            var categories = \[];
            for (cat in grouped) {
                if (grouped.hasOwnProperty(cat)) categories.push(cat);
            }
            categories.sort();

            for (i = 0; i < categories.length; i++) {
                cat = categories\[i];
                if (categories.length > 1 || currentTab === "Admin") {
                    var header = document.createElement("div");
                    header.className = "verb-category-header";
                    header.innerHTML = cat;
                    container.appendChild(header);
                }

                var verbList = document.createElement("div");
                verbList.className = "verb-list";

                var catVerbs = grouped\[cat];
                for (var j = 0; j < catVerbs.length; j++) {
                    var verb = catVerbs\[j];
                    var button = document.createElement("a");
                    button.className = "verb-button";
                    button.innerHTML = verb.name;
                    button.href = "byond://?action=execute_verb&verb=" + encodeURIComponent(verb.command);
                    verbList.appendChild(button);
                }

                container.appendChild(verbList);
            }
        }

        function renderTabs(tabs) {
            var tabsDiv = document.getElementById("tabs");
            tabsDiv.innerHTML = "";

            for (var i = 0; i < tabs.length; i++) {
                (function(tab) {
                    var tabEl = document.createElement("div");
                    tabEl.className = "tab" + (tab === currentTab ? " active" : "");
                    tabEl.innerHTML = tab;
                    tabEl.onclick = function() {
                        currentTab = tab;
                        notifyServerTabChange(tab);
                        renderTabs(tabs);
                    };
                    tabsDiv.appendChild(tabEl);
                })(tabs\[i]);
            }
        }

        function renderStats(stats) {
            var container = document.getElementById("stats-container");
            container.innerHTML = "";

            if (!stats || stats.length === 0) return;

            var table = document.createElement("table");
            table.className = "stat-table";

            for (var i = 0; i < stats.length; i++) {
                var stat = stats\[i];
                var tr = document.createElement("tr");

                if (!stat.name && !stat.value) {
                    tr.className = "empty-stat";
                    var td = document.createElement("td");
                    td.colSpan = 2;
                    tr.appendChild(td);
                } else {
                    var nameTd = document.createElement("td");
                    nameTd.className = "stat-name";
                    nameTd.innerHTML = stat.name || "";

                    var valueTd = document.createElement("td");
                    valueTd.className = "stat-value";
                    valueTd.innerHTML = stat.value || "";

                    tr.appendChild(nameTd);
                    tr.appendChild(valueTd);
                }
                table.appendChild(tr);
            }

            container.appendChild(table);
        }

        function notifyServerTabChange(newTab) {
            window.__location_proxy.href = "byond://?action=statpanel_tab&tab=" + encodeURIComponent(newTab);
        }

        window.receiveStats = receiveStats;

        // Signal ready to server once page has loaded.
        window.onload = function() {
            window.__location_proxy.href = "byond://?action=statpanel_ready";
        };

        // Return focus to the map after clicking anything non-interactive.
        document.addEventListener("click", function(e) {
            var t = e.target || e.srcElement;
            // Walk up the DOM to see if we hit an interactive element
            while (t && t !== document) {
                var tag = t.nodeName ? t.nodeName.toUpperCase() : "";
                var cls = t.className || "";
                if (tag === "INPUT" || tag === "TEXTAREA" || tag === "A" ||
                    cls.indexOf("tab") !== -1) return;
                t = t.parentNode;
            }
            window.location.href = "byond://?action=refocus_map";
        });
    </script>
</body>

</html>
	"}