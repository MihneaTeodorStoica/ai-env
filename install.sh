#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PYTHON_VERSION="3.11"
VENV_DIR="$SCRIPT_DIR/.venv"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
UV_DIR="$SCRIPT_DIR/.uv"
LOCAL_UV="$UV_DIR/uv"
INSTALL_STAMP=""
FORCE_SYNC=0
RECREATE_VENV=0
SKIP_PYTHON_INSTALL=0
PREFER_LOCAL_UV=0

status() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: ./install.sh [options]

Prepare the local Python environment for this project.

Options:
  -h, --help                 Show this help message and exit
  --python VERSION           Python version for uv to install/use (default: $PYTHON_VERSION)
  --venv DIR                 Virtual environment directory (default: $VENV_DIR)
  --requirements FILE        Requirements file to install (default: $REQUIREMENTS_FILE)
  --uv-dir DIR               Directory for a repo-local uv install (default: $UV_DIR)
  --force                    Reinstall dependencies even when requirements are unchanged
  --recreate-venv            Remove and recreate the virtual environment before installing
  --skip-python-install      Skip 'uv python install'
  --local-uv                 Prefer a repo-local uv over the system uv
EOF
}

abspath() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$SCRIPT_DIR" "$1" ;;
    esac
}

need_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

requirements_changed() {
    [ "$FORCE_SYNC" -eq 1 ] || [ ! -f "$INSTALL_STAMP" ] || [ "$REQUIREMENTS_FILE" -nt "$INSTALL_STAMP" ]
}

resolve_uv() {
    if [ "$PREFER_LOCAL_UV" -eq 1 ] && [ -x "$LOCAL_UV" ]; then
        UV="$LOCAL_UV"
        status "Using local uv at $UV"
        return
    fi

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

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --python)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            PYTHON_VERSION="$2"
            shift 2
            ;;
        --venv)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            VENV_DIR=$(abspath "$2")
            shift 2
            ;;
        --requirements)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            REQUIREMENTS_FILE=$(abspath "$2")
            shift 2
            ;;
        --uv-dir)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            UV_DIR=$(abspath "$2")
            LOCAL_UV="$UV_DIR/uv"
            shift 2
            ;;
        --force)
            FORCE_SYNC=1
            shift
            ;;
        --recreate-venv)
            RECREATE_VENV=1
            shift
            ;;
        --skip-python-install)
            SKIP_PYTHON_INSTALL=1
            shift
            ;;
        --local-uv)
            PREFER_LOCAL_UV=1
            shift
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

VENV_PYTHON="$VENV_DIR/bin/python"
INSTALL_STAMP="$VENV_DIR/.requirements-installed"

cd "$SCRIPT_DIR"

[ -f "$REQUIREMENTS_FILE" ] || die "Could not find requirements file: $REQUIREMENTS_FILE"

resolve_uv

if [ "$SKIP_PYTHON_INSTALL" -eq 0 ]; then
    status "Ensuring Python $PYTHON_VERSION is available"
    "$UV" python install "$PYTHON_VERSION"
else
    status "Skipping Python installation step"
fi

if [ "$RECREATE_VENV" -eq 1 ] && [ -d "$VENV_DIR" ]; then
    status "Recreating virtual environment in $VENV_DIR"
    rm -rf "$VENV_DIR"
fi

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
