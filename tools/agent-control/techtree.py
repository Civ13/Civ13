"""Tech tree for agent characters, built from the game's own recipe catalog.

The catalog comes from `scripts/build-crafting-atlas.py --catalog-only --game-catalog PATH`,
which reads config/crafting/*.txt and the DM sources. Nothing here talks to the game: given
a goal ("iron pickaxe", "furnace") and what the character carries, it answers what the goal
needs and which part to get first, so the model does not rediscover recipes by trial and error.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CACHE = ROOT / "data" / "agent-control" / "game-catalog.json"

# How a raw resource (one nothing crafts) is gathered, in the words the autopilot's skills use.
GATHER_HINTS = (
    ("/material/wood", "chop a tree with an axe"),
    ("/material/leaves", "pick leaves off a branch (grab intent)"),
    ("/material/bone", "hunt an animal and butcher it"),
    ("/material/rawhide", "hunt an animal and butcher it"),
    ("pelt", "hunt an animal and butcher it"),
    ("snacks/meat", "hunt an animal and butcher it"),
    ("/material/stone", "mine underground rock with a pickaxe"),
    (re.compile(r"^/obj/item/stack/ore/[a-z]+$"), "mine underground rock with a pickaxe, or sift dirt and sand"),
    (re.compile(r"^/material/(copper|tin|gold|silver|lead)$"), "mine or sift the ore, then smelt it in a kiln or furnace"),
    ("/material/clay", "dig clay with a shovel at a riverbank or clay ground"),
    ("/material/sandstone", "mine sandstone with a pickaxe"),
    ("/obj/item/stack/grass_cuttings", "cut_grass on grass"),
    ("grown/", "harvest a crop or a wild plant"),
    ("/obj/item/stack/farming/seeds", "gather seeds from wild plants"),
    ("/material/flint", "search a rock for flint (grab intent)"),
    ("water", "fill a container at a river, lake or well"),
)
MAX_DEPTH = 6
# Tools that any suitable held item satisfies; they are named, never planned as things to build.
HAND_TOOLS = {
    "held sharp tool": "a sharpened flint or a knife",
    "held hatchet": "an axe or hatchet",
    "accessible liquid container": "a pot, mug or bucket",
    "knife": "a sharpened flint or a knife",
    "flint": "a sharpened flint",
}
# Kinds that are reactions in a beaker, not a way for a nomad to get a basic material.
LAST_RESORT_KINDS = ("Chemistry",)
# Words that name a form, not a different thing: "iron ingot" is the iron material stack.
FORM_WORDS = ("ingot", "ingots", "bar", "bars", "sheet", "sheets", "stack", "pieces")

# Routes the catalog does not extract yet (blacksmithing.dm, molds.dm), checked against the source.
_HEADS = (("pickaxe", "/obj/item/weapon/material/part/pickaxe"),
          ("shovel", "/obj/item/weapon/material/part/shovel"),
          ("axehead", "/obj/item/weapon/material/part/axehead/hatchet"))
SUPPLEMENT = [
    ("/material/iron", {"name": "wrought iron", "inputs": [("/obj/item/stack/ore/iron_sponge", "sponge iron", "")], "tools": ["anvil"],
                        "how": "click the anvil while holding the sponge iron to hammer it into wrought iron"}),
    ("/material/steel", {"name": "steel", "inputs": [("/obj/item/stack/ore/iron_pig", "pig iron", "")], "tools": ["anvil"],
                         "how": "click the anvil while holding the pig iron to hammer it into steel"}),
] + [
    (f"/obj/item/weapon/clay/mold/{shape}/fired", {"name": f"fired {shape} mold", "inputs": [(f"/obj/item/weapon/clay/mold/{shape}", f"unfired {shape} mold", "1")],
                                                    "tools": ["clay kiln"], "how": "fire the unfired clay mold in a lit kiln"})
    for shape, _ in _HEADS
] + [
    (head, {"name": f"{shape} head", "inputs": [(f"/obj/item/weapon/clay/mold/{shape}/fired", f"fired {shape} mold", "1"), ("/obj/item/stack/ore/copper", "metal ore or ingots", "")],
            "tools": ["anvil"], "how": "fill the fired mold with metal, melt it in a kiln or furnace, then use the filled mold on an anvil"})
    for shape, head in _HEADS
]


def _is_global(recipe):
    """Nomad maps use the global material list; other material lists belong to other maps."""
    kinds = [recipe.get("kind", "")] + [v.get("kind", "") for v in recipe.get("variants", [])]
    return any(kind == "Material / global" or not kind.startswith("Material /") for kind in kinds)


def _global_quantity(recipe, root=ROOT):
    """The global list's cost for a recipe whose catalog row came from another map's list."""
    for variant in [recipe] + recipe.get("variants", []):
        if variant.get("kind") == "Material / global" and variant.get("file") and variant.get("line"):
            try:
                lines = (root / variant["file"]).read_text(encoding="utf-8", errors="replace").splitlines()
                fields = lines[int(variant["line"]) - 1].replace("RECIPE: ", "").split(",")
                return fields[3].strip() if len(fields) > 3 else None
            except (OSError, ValueError, IndexError):
                return None
    return None


def _key(type_id):
    """One key for a material and its stack type (/material/bone == /obj/item/stack/material/bone)."""
    text = str(type_id).strip().rstrip("/")
    if text.startswith("/obj/item/stack/material/"):
        text = "/material/" + text[len("/obj/item/stack/material/"):]
    return text


def _words(text):
    return re.findall(r"[a-z0-9]+", str(text).lower())


class TechTree:
    def __init__(self, catalog, root=ROOT):
        self.routes = {}  # key -> list of {"name", "inputs": [(key, name, qty)], "tools": [...], "how", "era", "research"}
        self.names = {}  # key -> display name
        self.labels = {}  # key -> every name it goes by (recipe names and output names)
        self._costs = {}
        self._found = {}
        for recipe in catalog.get("recipes", []):
            if not _is_global(recipe):
                continue
            quantity = _global_quantity(recipe, root) if recipe.get("kind", "").startswith("Material /") and recipe.get("kind") != "Material / global" else None
            inputs = []
            for index, item in enumerate(recipe.get("inputs", [])):
                key = _key(item.get("id", ""))
                qty = quantity if (quantity and index == 0) else item.get("quantity", "")
                if "station" in str(qty):
                    continue  # a station input is a tool, listed below
                inputs.append((key, item.get("name", key), str(qty)))
                self.names.setdefault(key, item.get("name", key))
            tools = []
            for item in recipe.get("inputs", []):
                if "station" in str(item.get("quantity", "")):
                    tools.append(item.get("name", ""))
            if recipe.get("station"):
                tools.append(recipe.get("processor_name") or recipe["station"].rsplit("/", 1)[-1])
            if recipe.get("kind") == "Anvil":
                tools.append("anvil")
            research = re.search(r"research node: ([a-z_]+)", recipe.get("conditions", ""), re.I)
            route = {
                "name": recipe.get("name", ""),
                "kind": recipe.get("kind", ""),
                "inputs": inputs,
                "tools": [t for t in tools if t],
                "how": "",
                "era": recipe.get("era_sort", 99),
                "research": research.group(1) if research else "",
            }
            world = [i for i in recipe.get("inputs", []) if str(i.get("id", "")).startswith(("/turf/", "/mob/", "/obj/structure/wild/"))]
            if world:
                route["inputs"] = [i for i in inputs if not i[0].startswith(("/turf/", "/mob/", "/obj/structure/wild/"))]
                route["from_world"] = True
            for output in recipe.get("outputs", []):
                key = _key(output.get("id", ""))
                self.routes.setdefault(key, []).append(route)
                # A material recipe's output "name" is its material (a bone pickaxe says "bone"), so only the recipe name counts.
                self.labels.setdefault(key, set()).add(recipe.get("name", ""))
                if not recipe.get("kind", "").startswith("Material /"):
                    self.labels[key].add(output.get("name", ""))
                label = recipe.get("name") if recipe.get("kind", "").startswith("Material /") else output.get("name", key)
                self.names.setdefault(key, label)
        for output, routes in catalog.get("acquisition", {}).items():
            key = _key(output)
            names = {item.get("name", "") for item in routes}
            # The procedure entry says which tools it needs; drop the bare recipe-list copy of it.
            self.routes[key] = [r for r in self.routes.get(key, []) if r["name"] not in names]
            for item in routes:
                ins = [(_key(i), self.names.get(_key(i), str(i).rsplit("/", 1)[-1]), "") for i in item.get("inputs", [])
                       if not str(i).startswith(("/turf/", "/mob/"))]
                steps = item.get("steps") or []
                self.routes.setdefault(key, []).append({
                    "name": item.get("name", ""),
                    "kind": "Acquisition",
                    "inputs": ins,
                    "tools": list(item.get("tools") or []),
                    "how": steps[0] if steps else "",
                    "era": 99,
                    "research": "",
                    "from_world": any(str(i).startswith(("/turf/", "/mob/")) for i in item.get("inputs", [])),
                })
                self.labels.setdefault(key, set()).add(item.get("name", ""))
            self.names.setdefault(key, output.rsplit("/", 1)[-1])
        for key, extra in SUPPLEMENT:
            route = {"kind": "Supplement", "era": 99, "research": "", **extra}
            self.routes.setdefault(key, []).append(route)
            self.names.setdefault(key, extra["name"])
            self.labels.setdefault(key, set()).add(extra["name"])
        for key, rows in catalog.get("resources", {}).items():
            name = rows.get("name", key) if isinstance(rows, dict) else key
            self.names.setdefault(_key(key), name)
            if _key(key) in self.labels and not _key(key).startswith("/material/"):
                self.labels[_key(key)].add(name)  # the object's in-game name ("furnace" for the bloomery)
        for key, routes in self.routes.items():
            # A route that needs its own output (re-forging iron into iron) never helps to get it first.
            routes[:] = [r for r in routes if key not in {k for k, _, _ in r["inputs"]}] or routes

    # --- lookup -------------------------------------------------------------------------------
    def find(self, query):
        """The best matching output key for a name like "bone pickaxe" or "furnace", or None."""
        want = _words(query)
        if not want:
            return None
        if tuple(want) in self._found:
            return self._found[tuple(want)]
        found = self._find(want)
        if found is None and any(word in FORM_WORDS for word in want):
            found = self._find([word for word in want if word not in FORM_WORDS])
        self._found[tuple(want)] = found
        return found

    def _find(self, want):
        ranked = self._ranked(want)
        return ranked[0][1] if ranked else None

    def tool_key(self, tool, max_era=None, visiting=frozenset()):
        """The cheapest thing that answers to a tool name: "anvil" is a stone anvil before an iron one."""
        ranked = self._ranked(_words(tool))
        if not ranked:
            return None
        best = {key: rank for rank, (_, key) in enumerate(ranked)}
        return min(best, key=lambda key: (self._cost(key, max_era, visiting), best[key]))

    def _ranked(self, want):
        """(score, key) for every output whose name holds all the wanted words, best first."""
        if not want:
            return []
        scores = {}
        for key, routes in self.routes.items():
            labels = {self.names.get(key, "")} | self.labels.get(key, set())
            for label in labels:
                have = _words(label)
                if not have:
                    continue
                hits = sum(1 for word in want if word in have or (word.endswith("s") and word[:-1] in have))
                if hits < len(want):
                    continue
                score = 100 - (len(have) - hits) * 5 - min(r["era"] for r in routes) / 10
                score += 20 if " ".join(have) == " ".join(want) else 0
                score += 10 if key.startswith("/material/") else 0  # "bronze" is the metal, not a bronze trinket
                scores[key] = max(scores.get(key, 0), score)
        return sorted(((score, key) for key, score in scores.items()), key=lambda pair: (-pair[0], pair[1]))

    def best_route(self, key, max_era=None):
        routes = self._routes(key, max_era)
        return min(routes, key=lambda route: self._route_cost(route, max_era, frozenset({key}))) if routes else None

    def _routes(self, key, max_era):
        routes = self.routes.get(key, [])
        if max_era is not None:
            routes = [r for r in routes if r["era"] in (99, None) or r["era"] <= max_era] or routes
        return routes

    def _cost(self, key, max_era, visiting):
        """Rough number of steps to get `key` from nothing; gathered materials cost 1, cycles a lot."""
        cache = self._costs.setdefault(max_era, {})
        if key in cache:
            return cache[key]
        if key in visiting or len(visiting) > MAX_DEPTH:
            return 50
        if self.gather_hint(key):
            return 1
        routes = self._routes(key, max_era)
        if not routes:
            return 3  # find or trade
        best = min(self._route_cost(route, max_era, visiting | {key}) for route in routes)
        if not visiting:
            cache[key] = best
        return best

    def _route_cost(self, route, max_era, visiting):
        if route["kind"] in LAST_RESORT_KINDS:
            return 100
        total = 1 + sum(self._cost(key, max_era, visiting) for key, _, _ in route["inputs"])
        for tool in route["tools"]:
            if tool.lower() in HAND_TOOLS:
                continue
            tool_key = self.tool_key(tool, max_era, visiting)
            total += self._cost(tool_key, max_era, visiting) if tool_key else 3
        return total

    def gather_hint(self, key):
        for marker, hint in GATHER_HINTS:
            if (marker.search(key) if hasattr(marker, "search") else marker in key):
                return hint
        return ""

    # --- planning -----------------------------------------------------------------------------
    def plan(self, query, carried=(), max_era=None):
        """Ordered steps (leaves first) to make `query`; skips parts already carried.

        Returns (steps, problem): each step is {"make": name, "from": [...], "tools": [...], "how": text}
        or {"gather": name, "how": hint}.
        """
        key = self.find(query)
        if not key:
            return [], f'no recipe makes "{query}"'
        have = [str(name).lower() for name in carried]
        steps, seen = [], set()

        def carrying(name):
            words = _words(name)
            return bool(words) and any(all(word in _words(item) or word + "s" in _words(item) for word in words) for item in have)

        def visit(item_key, depth, visiting):
            name = self.names.get(item_key, item_key.rsplit("/", 1)[-1])
            if item_key in seen or (depth and carrying(name)):
                return
            route = self.best_route(item_key, max_era)
            if route is None or depth >= MAX_DEPTH or item_key in visiting:
                seen.add(item_key)
                steps.append({"gather": name, "how": self.gather_hint(item_key) or "find it in the world or trade for it"})
                return
            hint = self.gather_hint(item_key)
            # A basic material is gathered, even where a reaction or a station could also make it.
            if hint and depth and (route.get("from_world") or route["kind"] in LAST_RESORT_KINDS or route["kind"] == "Acquisition"):
                seen.add(item_key)
                steps.append({"gather": name, "how": hint})
                return
            if route.get("from_world") and not route["inputs"]:
                seen.add(item_key)
                steps.append({"gather": name, "how": hint or route["how"] or route["name"]})
                return
            visiting = visiting | {item_key}
            for tool in route["tools"]:
                if tool.lower() in HAND_TOOLS:
                    continue
                tool_key = self.tool_key(tool, max_era, visiting)
                if tool_key and tool_key != item_key and not carrying(tool):
                    visit(tool_key, depth + 1, visiting)
            for input_key, _, _ in route["inputs"]:
                visit(input_key, depth + 1, visiting)
            seen.add(item_key)
            steps.append({
                "make": route["name"] if route["kind"].startswith(("Material /", "Supplement")) else name,
                "from": [f"{qty} {label}".strip() if qty and qty.isdigit() else label for _, label, qty in route["inputs"]],
                "tools": [HAND_TOOLS.get(tool.lower(), tool) for tool in route["tools"]],
                "how": route["how"],
                "research": route["research"],
                "world": route.get("from_world", False),
            })

        visit(key, 0, frozenset())
        return steps, ""

    def describe(self, query, carried=(), max_era=None, limit=6):
        """A short text plan for the prompt."""
        steps, problem = self.plan(query, carried, max_era)
        if problem:
            return problem
        lines = []
        for step in steps[:limit]:
            if "gather" in step:
                lines.append(f"get {step['gather']}: {step['how']}")
                continue
            parts = []
            if step["from"]:
                parts.append("from " + ", ".join(step["from"]))
            if step["tools"]:
                parts.append("using " + ", ".join(step["tools"]))
            text = f"make {step['make']}" + (" " + " ".join(parts) if parts else "")
            if step["how"]:
                text += f" ({step['how'][:120]})"
            lines.append(text)
        more = len(steps) - limit
        return "; then ".join(lines) + (f"; then {more} more step(s)" if more > 0 else "")


def load(path=None, regenerate=False):
    """Load the catalog, generating it with the atlas script when the cache is missing."""
    path = Path(path) if path else DEFAULT_CACHE
    if not regenerate and path == DEFAULT_CACHE and path.exists():
        sources = list((ROOT / "config" / "crafting").glob("*"))
        regenerate = any(source.stat().st_mtime > path.stat().st_mtime for source in sources)  # recipes changed since
    if regenerate or not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        script = ROOT / "scripts" / "build-crafting-atlas.py"
        subprocess.run([sys.executable, str(script), "--catalog-only", "--output", str(path.parent / "atlas"),
                        "--game-catalog", str(path)], check=True, cwd=ROOT, stdout=subprocess.DEVNULL)
    return TechTree(json.loads(path.read_text(encoding="utf-8")))


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Show how to make an item from the game's recipes.")
    parser.add_argument("item")
    parser.add_argument("--catalog")
    parser.add_argument("--carry", action="append", default=[], help="an item already carried")
    parser.add_argument("--max-era", type=int)
    options = parser.parse_args()
    tree = load(options.catalog)
    print(tree.describe(options.item, options.carry, options.max_era, limit=20))
