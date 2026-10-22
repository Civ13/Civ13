#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
compiler=${DREAMMAKER:-DreamMaker}
daemon=${DREAMDAEMON:-DreamDaemon}
cd "$root"
run=$(mktemp -d -t civ13-world-save.XXXXXXXX)
"$compiler" -max_errors 0 tests/world_save/roundtrip.dme | tee "$run/compile.log"
grep -q '0 errors, 0 warnings' "$run/compile.log"
cp tests/world_save/roundtrip.dmb tests/world_save/roundtrip.rsc "$run/"
cd "$run"
"$daemon" roundtrip.dmb -ip 127.0.0.1 -nowebclient -invisible -close -trusted -log runtime.log -params "${1:-}"
cat "$run/runtime.log"
if grep -Eiq 'runtime error:|bad ref|BUG:|##ERROR:|RUNTIME:|infinite loop|segmentation|assertion failed|fatal error' "$run/runtime.log"; then
  echo "Unexpected world-save engine diagnostic" >&2
  exit 1
fi
test "$(tr -d '\r\n' < "$run/result.txt")" = PASS
echo "Evidence retained at $run"
