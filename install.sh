#!/usr/bin/env sh
set -eu

UV="./.uv/uv"

mkdir -p .uv
env UV_INSTALL_DIR="./.uv" sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"
"$UV" python install 3.11
"$UV" venv --python 3.11 --clear
"$UV" pip install -r requirements.txt