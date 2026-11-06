#!/usr/bin/env bash
# Times save, full preflight and import of a generated world in each level
# format, through the real Save_World/validate_world_save/Load_World.
#
#   bash tools/savestream/bench/run_level_bench.sh [size]   # size x size x 2 world, default 40
#
# Needs DreamMaker/DreamDaemon (scripts/cloud_byond_setup.sh) and gcc-multilib
# for the Linux shim. Prints one JSON line per format (3, 4 and 5).
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
size=${1:-40}
compiler=${DREAMMAKER:-DreamMaker}
daemon=${DREAMDAEMON:-DreamDaemon}
cd "$root"
bash tools/savestream/build.sh linux >/dev/null
"$compiler" -max_errors 0 tools/savestream/bench/level_bench.dme > /dev/null
for params in "size=$size" "size=$size&low_memory=1" "size=$size&stream=1"; do
  run=$(mktemp -d -t civ13-level-bench.XXXXXXXX)
  cp tools/savestream/bench/level_bench.dmb tools/savestream/bench/level_bench.rsc "$run/"
  cp tools/savestream/bin/linux/libsavestream.so tools/savestream/bin/linux/savestream_helper "$run/"
  (cd "$run" && "$daemon" level_bench.dmb -ip 127.0.0.1 -nowebclient -invisible -close -trusted -log runtime.log -params "$params" >/dev/null 2>&1 || true)
  if [ -f "$run/bench.json" ]; then cat "$run/bench.json"; else tail -5 "$run/runtime.log"; fi
  rm -rf "$run"
done
