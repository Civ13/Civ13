#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
awk '/^\/obj\/structure\/trains$/ { active=1 } /^\/obj\/structure\/trains\/storage/ { exit } active { print }' "$repo/code/modules/1713/trains.dm" | sed -E "s@icon = 'icons/obj/vehicles/trains.dmi'@icon = null@; s@'sound/[^']+'@null@g" > "$work/production.dm"
cp "$repo/tests/train_collision/fixture.dm" "$work/fixture.dm"
printf '#include "fixture.dm"\n#include "production.dm"\n' > "$work/probe.dme"
DreamMaker "$work/probe.dme" | tee "$work/compile.log"
grep -q '0 errors, 0 warnings' "$work/compile.log"
cd "$work"
# Restrict only the tiny fixture process; never run against a live game.
(ulimit -v 262144; ulimit -t 5; timeout --kill-after=2s 15s DreamDaemon probe.dmb -invisible -safe -log runtime.log)
cat runtime.log
grep -q 'RESULT failures=0' runtime.log
if grep -Eq 'runtime error:|FAIL ' runtime.log; then exit 1; fi
