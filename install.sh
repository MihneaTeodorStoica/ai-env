#!/usr/bin/env sh
set -eu

UV="./.uv/uv"

if [ ! -x "$UV" ]; then
    mkdir -p .uv
    env UV_INSTALL_DIR="./.uv" sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"
fi

"$UV" python install 3.11

if [ ! -x ".venv/bin/python" ]; then
    "$UV" venv --python 3.11
fi

"$UV" pip install -r requirements.txt