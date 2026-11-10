#!/usr/bin/env bash
# tests/bench.mojo, 3 runs: pure-Mojo xxHash vs the system libxxhash in the same process (best of 5 inside each run).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work
.venv/bin/mojo build -O3 -I src tests/bench.mojo -o .work/bench 2>.work/build.err || { echo "FAIL build: tests/bench.mojo"; cat .work/build.err; exit 1; }
for i in 1 2 3; do echo "== run $i"; .work/bench || { echo "FAIL run: $i"; exit 1; }; done
