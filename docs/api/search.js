document.addEventListener("DOMContentLoaded", async () => {
  const input = document.getElementById("api-search");
  if (!input) return;
  const status = document.getElementById("search-status");
  const results = document.getElementById("search-results");
  try {
    const response = await fetch("search-index.json");
    if (!response.ok) throw new Error("Search index unavailable");
    const index = await response.json();
    const search = () => {
      const words = input.value.trim().toLowerCase().split(/\s+/).map(word => word.replace(/^\/+/, '')).filter(Boolean);
      results.replaceChildren();
      if (!words.length) {
        status.textContent = "Search " + index.length + " documented pages and members. Coverage is incremental.";
        return;
      }
      const matches = index.filter(item => words.every(word => item.label.toLowerCase().includes(word)));
      status.textContent = matches.length + " results" + (matches.length > 100 ? " (first 100 shown; refine your search)" : "");
      for (const item of matches.slice(0, 100)) {
        const li = document.createElement("li");
        const link = document.createElement("a");
        link.href = item.url;
        link.textContent = item.label;
        li.append(link);
        results.append(li);
      }
    };
    input.addEventListener("input", search);
    input.addEventListener("keydown", event => {
      if (event.key === "Enter") {
        const first = results.querySelector("a");
        if (first) first.focus();
      }
    });
    search();
  } catch (error) {
    status.textContent = "Search could not load. Browse the module and type trees below.";
  }
});
