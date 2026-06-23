#!/usr/bin/env bash
# Run both the official example testbench and the extended edge-case testbench.
set -euo pipefail

cd "$(dirname "$0")/.."

make clean
make run-official
make run-edge
