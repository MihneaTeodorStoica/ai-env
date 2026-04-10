#!/usr/bin/env sh
set -eu

PYTHON_VERSION="3.11"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UV_DIR="$SCRIPT_DIR/.uv"
LOCAL_UV="$UV_DIR/uv"
VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
INSTALL_STAMP="$VENV_DIR/.requirements-installed"

status() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

need_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

requirements_changed() {
    [ ! -f "$INSTALL_STAMP" ] || [ "$REQUIREMENTS_FILE" -nt "$INSTALL_STAMP" ]
}

resolve_uv() {
    if command -v uv >/dev/null 2>&1; then
        UV=$(command -v uv)
        status "Using system uv at $UV"
        return
    fi

    if [ -x "$LOCAL_UV" ]; then
        UV="$LOCAL_UV"
        status "Using existing local uv at $UV"
        return
    fi

    need_command curl
    status "Installing local uv into $UV_DIR"
    mkdir -p "$UV_DIR"
    env UV_INSTALL_DIR="$UV_DIR" sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"
    UV="$LOCAL_UV"
}

cd "$SCRIPT_DIR"

[ -f "$REQUIREMENTS_FILE" ] || die "Could not find $REQUIREMENTS_FILE"

resolve_uv

status "Ensuring Python $PYTHON_VERSION is available"
"$UV" python install "$PYTHON_VERSION"

if [ ! -x "$VENV_PYTHON" ]; then
    status "Creating virtual environment in $VENV_DIR"
    "$UV" venv --python "$PYTHON_VERSION" "$VENV_DIR"
else
    status "Using existing virtual environment in $VENV_DIR"
fi

if requirements_changed; then
    status "Installing dependencies from $(basename "$REQUIREMENTS_FILE")"
    "$UV" pip install --python "$VENV_PYTHON" -r "$REQUIREMENTS_FILE"
    touch "$INSTALL_STAMP"
else
    status "Dependencies already up to date"
fi

status "Environment is ready"
