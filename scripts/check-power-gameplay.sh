#!/usr/bin/env bash
# Compile the opt-in adapter without running a world or enabling production hooks.
set -euo pipefail
cd "$(dirname "$0")/.."
environment="$(mktemp --suffix=.dme "$PWD/.power-evidence-XXXXXX")"
base="${environment%.dme}"
trap 'rm -f "$environment" "$base.dmb" "$base.rsc" "$base.log"' EXIT
cat > "$environment" <<'DM'
#define POWER_EVIDENCE_TOKEN "compile-only"
#define POWER_EVIDENCE_COMMIT "compile-only"
#include "civ13.dme"
#include "tests/power/gameplay.dm"
DM
DreamMaker -max_errors 0 "$environment" | tee "$base.log"
grep -- '- 0 errors, 0 warnings' "$base.log"
