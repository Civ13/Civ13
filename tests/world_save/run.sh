#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
compiler=${DREAMMAKER:-DreamMaker}
daemon=${DREAMDAEMON:-DreamDaemon}
cd "$root"
"$compiler" -max_errors 0 tests/world_save/roundtrip.dme | tee /tmp/civ13-world-save-compile.log
grep -q '0 errors, 0 warnings' /tmp/civ13-world-save-compile.log
run=$(mktemp -d -t civ13-world-save.XXXXXXXX)
cp tests/world_save/roundtrip.dmb tests/world_save/roundtrip.rsc "$run/"
cd "$run"
"$daemon" roundtrip.dmb -invisible -safe -log runtime.log -params "${1:-}"
cat "$run/runtime.log"
test "$(tr -d '\r\n' < "$run/result.txt")" = PASS
echo "Evidence retained at $run"
