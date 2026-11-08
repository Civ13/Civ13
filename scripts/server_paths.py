"""Read a deployment's scripts/paths.txt.

Line 1 is a comment, then the historical fixed lines `mdir:`, `cdir:` and
`port:`. Optional `key:value` lines may follow:

    gitdir:<folder or absolute path>  build checkout, default <mdir>civ13-git
    supervisor:systemd               a service manager restarts DreamDaemon

Without the optional lines every script keeps its historical behavior.
"""
import os

SUPERVISORS = ("", "systemd")


def parse_paths(text):
    lines = text.splitlines()
    if len(lines) < 4:
        raise ValueError("paths.txt needs a comment line, mdir:, cdir: and port:")
    paths = {}
    for key, line in zip(("mdir", "cdir", "port"), lines[1:4]):
        prefix = key + ":"
        if not line.startswith(prefix):
            raise ValueError("paths.txt line for {} must start with {}".format(key, prefix))
        paths[key] = line[len(prefix):].strip()
    paths["gitdir"] = "civ13-git"
    paths["supervisor"] = ""
    for line in lines[4:]:
        line = line.strip()
        if not line or line.startswith("//") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip().lower()
        if key in ("gitdir", "supervisor"):
            paths[key] = value.strip()
    if paths["supervisor"] not in SUPERVISORS:
        raise ValueError("Unknown supervisor: {}".format(paths["supervisor"]))
    if not paths["gitdir"] or any(char in paths["gitdir"] for char in "\"'\n\r;|&$`"):
        raise ValueError("Invalid gitdir")
    gitdir = paths["gitdir"]
    paths["gitpath"] = gitdir if os.path.isabs(gitdir) else os.path.join(paths["mdir"], gitdir)
    paths["livepath"] = os.path.join(paths["mdir"], paths["cdir"])
    return paths


def read_paths(script_dir):
    with open(os.path.join(script_dir, "paths.txt"), encoding="utf-8") as handle:
        return parse_paths(handle.read())
