#!/bin/sh
# Builds the instrumented original. The instrumentation is inert unless
# LCS_TRACE_SCRIPT is set, so this is also a normal playable build.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${LCS_BUILD:-/tmp/lcsbuild}"
cd "$ROOT"
[ -f configure ] || ./bootstrap
mkdir -p "$BUILD"
cd "$BUILD"
[ -f Makefile ] || "$ROOT/configure"
make -j"$(nproc)"
echo "built $BUILD/src/crimesquad"
