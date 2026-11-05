#!/usr/bin/env bash
# Stream-backed world save (format 5) through the real Save_World/Load_World.
# Builds the Linux shim (i386, needs gcc-multilib) and helper, then runs
# stream_roundtrip.dme with them beside the .dmb.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
compiler=${DREAMMAKER:-DreamMaker}
daemon=${DREAMDAEMON:-DreamDaemon}
cd "$root"
bash tools/savestream/build.sh linux >/dev/null
run=$(mktemp -d -t civ13-stream-save.XXXXXXXX)
"$compiler" -max_errors 0 tests/world_save/stream_roundtrip.dme | tee "$run/compile.log"
grep -q '0 errors, 0 warnings' "$run/compile.log"
cp tests/world_save/stream_roundtrip.dmb tests/world_save/stream_roundtrip.rsc "$run/"
cp tools/savestream/bin/linux/libsavestream.so tools/savestream/bin/linux/savestream_helper "$run/"
cd "$run"
"$daemon" stream_roundtrip.dmb -ip 127.0.0.1 -nowebclient -invisible -close -trusted -log runtime.log -params "low_memory=1&segment=${1:-2}&stream=1"
cat "$run/runtime.log"
if grep -Eiq 'runtime error:|bad ref|BUG:|##ERROR:|RUNTIME:|infinite loop|segmentation|assertion failed|fatal error' "$run/runtime.log"; then
  echo "Unexpected world-save engine diagnostic" >&2
  exit 1
fi
test "$(tr -d '\r\n' < "$run/result.txt")" = PASS
echo "Evidence retained at $run"
