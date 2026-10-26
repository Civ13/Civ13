"""Run extracted production Clean/clean_blood bodies in an offline native fixture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def proc(path, signature):
    source = (ROOT / path).read_text(encoding="utf-8")
    start = source.index(signature)
    end = re.search(r"^/", source[start + len(signature):], re.M)
    stop = start + len(signature) + end.start() if end else len(source)
    return source[start:stop].rstrip() + "\n"


def prepare(output, control):
    registration = (ROOT / "code/modules/admin/admin_verbs.dm").read_text()
    group = registration.split("var/list/admin_verbs_admin = list(", 1)[1].split("\n)", 1)[0]
    assert group.count("/client/proc/cmd_admin_clean_item") == 1
    assert registration.count("/client/proc/cmd_admin_clean_item") == 1
    assert "if (holder.rights & R_ADMIN)\t\t\tverbs += admin_verbs_admin" in registration
    assert "admin_verbs_admin," in registration.split("/client/proc/remove_admin_verbs()", 1)[1]
    command = proc("code/modules/admin/verbs/random_verbs.dm", "/client/proc/cmd_admin_clean_item(")
    assert 'obj/item/I as obj in world' in command and 'set name = "Clean"' in command
    # Native clients require a connection. Adapt only the client owner and audit sinks;
    # retain the production body, item typing, guard order and native item APIs.
    command = command.replace("/client/proc/cmd_admin_clean_item(obj/item/I as obj in world)",
                              "/datum/actor/proc/cmd_admin_clean_item(obj/item/I)")
    if control == "rights":
        command = command.replace("if (!check_rights(R_ADMIN, TRUE, src))", "if (FALSE)")
    elif control == "target":
        command = command.replace("QDELETED(I) || I.gcDestroyed || ", "")
    elif control == "refresh":
        command = command.replace("M.regenerate_icons()", "M.probe_no_refresh()")
    bodies = command
    bodies += proc("code/game/atoms.dm", "/atom/proc/clean_blood()")
    bodies += proc("code/game/objects/items.dm", "/obj/item/clean_blood()")
    bodies += proc("code/game/objects/items/clothing/clothing.dm", "/obj/item/clothing/clean_blood()")
    rights = proc("code/_helpers/admin.dm", "/proc/check_rights(")
    rights = rights.replace("var/mob/user = usr", "datum/actor/user")
    rights = rights.replace("var/client/C", "var/datum/actor/C").replace("istype(user, /client)", "istype(user, /datum/actor)")
    bodies += rights
    renderer = proc("code/game/mob/living/carbon/human/update_icons.dm", "/mob/living/human/regenerate_icons()")
    for call in ("update_inv_shoes(0)", "update_inv_w_uniform(0)", "update_inv_l_hand(0)", "update_inv_r_hand(0)", "update_inv_back(0)"):
        assert call in renderer
    output.mkdir(parents=True)
    (output / "production.dm").write_text(bodies, encoding="utf-8")
    (output / "probe.dm").write_bytes((ROOT / "tests/admin_clean/probe.dm").read_bytes())
    (output / "probe.dme").write_text('#define TRUE 1\n#define FALSE 0\n#define R_ADMIN 1\n#define QDELETED(X) (!X || X.gc_destroyed)\n#include "probe.dm"\n#include "production.dm"\n')
    metadata = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "diff": subprocess.check_output(["git", "diff", "HEAD"], cwd=ROOT, text=True),
                "production_sha256": hashlib.sha256(bodies.encode()).hexdigest(), "control": control,
                "limits": "One-tile native fixture; client authority and icon refresh are injected adapters. No connected-client menus or rendered appearance acceptance."}
    (output / "sources.json").write_text(json.dumps(metadata, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--byond-bin", type=Path)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--control", choices=["rights", "target", "refresh"])
    args = parser.parse_args()
    output = args.output.resolve()
    prepare(output, args.control)
    if args.prepare_only:
        print("PASS registration/source preparation; native runtime not run")
        return
    if not args.byond_bin:
        parser.error("--byond-bin required for native execution")
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    compiler = args.byond_bin / ("dm.exe" if os.name == "nt" else "DreamMaker")
    daemon = args.byond_bin / ("dd.exe" if os.name == "nt" else "DreamDaemon")
    built = subprocess.run([str(compiler), "-max_errors", "0", "probe.dme"], cwd=output,
                           capture_output=True, text=True, timeout=60, creationflags=flags)
    log = built.stdout + built.stderr
    (output / "compile.log").write_text(log)
    if built.returncode or "516.1681" not in log or "0 errors, 0 warnings" not in log:
        raise SystemExit(log)
    ran = subprocess.run([str(daemon), "probe.dmb", "-invisible", "-close", "-trusted", "-ip", "127.0.0.1", "-log", "runtime.log"],
                         cwd=output, capture_output=True, text=True, timeout=30, creationflags=flags)
    (output / "daemon.log").write_text(ran.stdout + ran.stderr)
    combined = (output / "runtime.log").read_text() + ran.stdout + ran.stderr
    if ran.returncode or re.search(r"runtime error|Bad ref|Bad loc|BUG:|## ERROR:", combined, re.I):
        raise SystemExit(combined)
    result = json.loads((output / "result.json").read_text())
    if result["checks"] != 43:
        raise SystemExit(f"Incomplete: {result}")
    expected = {"rights": "non-admin direct call rejected", "target": "queued deletion rejected", "refresh": "worn refresh"}
    if args.control:
        assert expected[args.control] in result["failed_labels"], result
    else:
        assert not result["failed_labels"], result
    print(json.dumps(result))
    print("PASS " + (args.control or "production Clean fixture"))


if __name__ == "__main__":
    main()
