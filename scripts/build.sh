#!/usr/bin/env bash
# build.sh -- synthesize the blinky and generate build/impl1/blink_impl1.bit
set -euo pipefail

RADIANT="${RADIANT:-$HOME/lscc/radiant/2026.1}"
export bali_LICENSE_FILE="$RADIANT/license/license.dat"
export LM_LICENSE_FILE="$RADIANT/license/license.dat"
export PATH="$RADIANT/bin/lin64:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # project root (parent of scripts/)
BUILD="$ROOT/build"

# Fresh build dir, and sweep any legacy Radiant droppings from the project root.
rm -rf "$BUILD"
rm -rf "$ROOT"/impl1 "$ROOT"/blink.rdf "$ROOT"/blink1.sty "$ROOT"/promote.* \
       "$ROOT"/.recovery "$ROOT"/radiantc.log.* "$ROOT"/radiantc.tcl.* 2>/dev/null || true
mkdir -p "$BUILD"

echo ">> Running Radiant flow (synthesis -> map -> par -> bitgen)..."
# Run from build/ so all generated files land there; build.tcl finds its own sources.
( cd "$BUILD" && radiantc "$ROOT/scripts/build.tcl" )

if [[ -f "$BUILD/impl1/blink_impl1.bit" ]]; then
  echo ">> SUCCESS: bitstream at build/impl1/blink_impl1.bit ($(stat -c%s "$BUILD/impl1/blink_impl1.bit") bytes)"
else
  echo ">> FAILED: no bitstream produced"; exit 1
fi
