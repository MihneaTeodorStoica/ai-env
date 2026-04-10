#!/usr/bin/env sh
set -eu

UV="./.uv/uv"

mkdir -p work
"$UV" run jupyter lab work