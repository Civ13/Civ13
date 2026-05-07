let currentTab = "Status";

function receiveStats(dataString) {
	const contentDiv = document.getElementById("content");
	contentDiv.innerHTML = "";

	if (!dataString) {
		console.log("No data received");
		return;
	}

	let data;
	try {
		data = JSON.parse(dataString);
	} catch (e) {
		console.error("Failed to parse stat data:", e, dataString);
		return;
	}

	if (!data) return;

	if (data.current_tab) {
		currentTab = data.current_tab;
	}

	renderTabs(data.tabs);

	if (data.stats && data.stats.length > 0) {
		renderStats(data.stats);
	}

	if (data.verbs && data.verbs.length > 0) {
		renderVerbs(data.verbs);
	}
}

function renderVerbs(verbs) {
	const contentDiv = document.getElementById("content");

	// Group verbs by category
	const grouped = {};
	verbs.forEach((v) => {
		if (!grouped[v.category]) grouped[v.category] = [];
		grouped[v.category].push(v);
	});

	const categories = Object.keys(grouped).sort();

	categories.forEach((cat) => {
		// Show header if there's more than one category in this tab OR if it's the Admin tab
		if (categories.length > 1 || currentTab === "Admin") {
			const header = document.createElement("div");
			header.className = "verb-category-header";
			header.innerText = cat;
			contentDiv.appendChild(header);
		}

		const verbList = document.createElement("div");
		verbList.className = "verb-list";

		grouped[cat].forEach((verb) => {
			const button = document.createElement("a");
			button.className = "verb-button";
			button.innerText = verb.name;
			button.href = `byond://?action=execute_verb&verb=${encodeURIComponent(verb.command)}`;
			verbList.appendChild(button);
		});

		contentDiv.appendChild(verbList);
	});
}

function renderTabs(tabs) {
	const tabsDiv = document.getElementById("tabs");
	tabsDiv.innerHTML = "";

	tabs.forEach((tab) => {
		const tabEl = document.createElement("div");
		tabEl.className = "tab";
		if (tab === currentTab) {
			tabEl.classList.add("active");
		}
		tabEl.innerText = tab;
		tabEl.onclick = () => {
			currentTab = tab;
			notifyServerTabChange(tab);
			renderTabs(tabs);
		};
		tabsDiv.appendChild(tabEl);
	});
}

function renderStats(stats) {
	const contentDiv = document.getElementById("content");

	const table = document.createElement("table");
	table.className = "stat-table";

	stats.forEach((stat) => {
		const tr = document.createElement("tr");

		if (!stat.name && !stat.value) {
			tr.className = "empty-stat";
			const td = document.createElement("td");
			td.colSpan = 2;
			tr.appendChild(td);
		} else {
			const nameTd = document.createElement("td");
			nameTd.className = "stat-name";
			nameTd.innerHTML = stat.name || ""; // Using innerHTML as stats might contain formatting or links

			const valueTd = document.createElement("td");
			valueTd.className = "stat-value";
			valueTd.innerHTML = stat.value || "";

			tr.appendChild(nameTd);
			tr.appendChild(valueTd);
		}
		table.appendChild(tr);
	});

	contentDiv.appendChild(table);
}

function notifyServerTabChange(newTab) {
	window.location.href = `byond://?action=statpanel_tab&tab=${encodeURIComponent(newTab)}`;
}

// In BYOND, we expose the function to the global scope so the output() command can call it.
window.receiveStats = receiveStats;
