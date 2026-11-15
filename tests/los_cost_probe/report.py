#!/usr/bin/env python3
"""Print Markdown tables from the probe's result files (see README.md)."""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
KINDS = ("stand", "walk-one", "walk-all", "pan", "door")


def load(name):
    path = HERE / "results" / f"{name}.json"
    if not path.exists():
        return {}
    return {mark["phase"]: mark for mark in json.loads(path.read_text())["marks"]}


def per(mark, key, what="ms"):
    return (mark.get(what) or {}).get(key, 0)


def profile(mark, suffix):
    rows = [row for row in mark.get("profile", []) if row["name"].endswith(suffix)]
    return sum(row["calls"] for row in rows), sum(row["total_s"] for row in rows)


def cost_table(map_name):
    on, off = load(f"{map_name}-on"), load(f"{map_name}-off")
    print("| Scene | Clients | Refreshes /s | ms per refresh | capture ms | decisions per refresh | LOS ms per second | world.cpu on / off | Daemon CPU % on / off | kB/s per client on / off | Masks held per client | Mask adds+removes /s |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for phase, mark in on.items():
        if "kind" not in mark:
            continue
        base = off.get(phase, {})
        seconds = mark["seconds"]
        active = mark["active"]
        refreshes = per(mark, "presenter_refresh", "count")
        refresh_ms = per(mark, "presenter_refresh") + per(mark, "tree_refresh")
        captures = per(mark, "capture", "count")
        decisions, _ = profile(mark, "/decision_snapshot")
        host, base_host = mark.get("host", {}), base.get("host", {})
        print("| {} | {} | {:.1f} | {} | {} | {} | {:.1f} | {} / {} | {} / {} | {} / {} | {} | {:.1f} |".format(
            f"{mark['scene']} {mark['kind']}", active, refreshes / seconds,
            f"{refresh_ms / refreshes:.1f}" if refreshes else "-",
            f"{per(mark, 'capture') / captures:.2f}" if captures else "-",
            round(decisions / refreshes) if refreshes else "-",
            per(mark, "reconcile") / seconds,
            mark["avg_cpu"], base.get("avg_cpu", "-"),
            host.get("daemon_cpu_pct", "-"), base_host.get("daemon_cpu_pct", "-"),
            round(host["kb_per_s_to_clients"] / active, 1) if host else "-",
            round(base_host["kb_per_s_to_clients"] / active, 1) if base_host else "-",
            round(mark["max_los_masks"] / active), (mark["image_adds"] + mark["image_removes"]) / seconds))


def memory_table(map_name):
    on, off = load(f"{map_name}-on"), load(f"{map_name}-off")
    print("| Step | Contexts | Presenters | Snapshots | Client images | Presenter list entries | Daemon private MB on | off |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for phase, mark in on.items():
        if not phase.startswith("memory/"):
            continue
        print("| {} | {} | {} | {} | {} | {} | {} | {} |".format(
            phase.split("/")[1], mark["contexts"], mark["presenters"] + mark["tree_presenters"], mark["snapshots"],
            mark["client_images"], mark["presenter_list_entries"],
            mark.get("host", {}).get("daemon_private_mb_last", "-"), off.get(phase, {}).get("host", {}).get("daemon_private_mb_last", "-")))


def main():
    for map_name in sys.argv[1:] or ("small", "gaia"):
        on = load(f"{map_name}-on")
        if not on:
            continue
        print(f"\n## {map_name}\n")
        for key in ("playing", "clients"):
            if key in on:
                print("- " + ", ".join(f"{k}={v}" for k, v in on[key].items() if k not in ("phase", "wall_s")))
        print()
        cost_table(map_name)
        print()
        memory_table(map_name)


if __name__ == "__main__":
    main()
