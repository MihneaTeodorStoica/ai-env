#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
INSTALL_STAMP="$SCRIPT_DIR/.venv/.requirements-installed"
WORK_DIR="$SCRIPT_DIR/work"

status() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

setup_needed() {
    [ ! -x "$VENV_PYTHON" ] || [ ! -f "$INSTALL_STAMP" ] || [ "$REQUIREMENTS_FILE" -nt "$INSTALL_STAMP" ]
}

cd "$SCRIPT_DIR"

if setup_needed; then
    [ -x "$INSTALL_SCRIPT" ] || die "Install script is missing or not executable: $INSTALL_SCRIPT"
    status "Environment missing or stale; running install.sh"
    "$INSTALL_SCRIPT"
fi

mkdir -p "$WORK_DIR"
status "Starting JupyterLab in $WORK_DIR"
exec "$VENV_PYTHON" -m jupyter lab "$WORK_DIR" "$@"
