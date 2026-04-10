#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
PYTHON_VERSION="3.11"
VENV_DIR="$SCRIPT_DIR/.venv"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
WORK_DIR="$SCRIPT_DIR/work"
UV_DIR="$SCRIPT_DIR/.uv"
JUPYTER_SUBCOMMAND="lab"
AUTO_INSTALL=1
FORCE_INSTALL=0
INSTALL_ARGS=""
PASS_THROUGH=""

status() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: ./run.sh [options] [-- <extra jupyter args>]

Start Jupyter for this project, bootstrapping the environment when needed.

Options:
  -h, --help                 Show this help message and exit
  --python VERSION           Python version to use when bootstrapping (default: $PYTHON_VERSION)
  --venv DIR                 Virtual environment directory (default: $VENV_DIR)
  --requirements FILE        Requirements file used for bootstrap checks (default: $REQUIREMENTS_FILE)
  --work-dir DIR             Directory to open in Jupyter (default: $WORK_DIR)
  --uv-dir DIR               Directory for a repo-local uv install (default: $UV_DIR)
  --command NAME             Jupyter subcommand to run, e.g. lab or notebook (default: $JUPYTER_SUBCOMMAND)
  --no-install               Fail instead of auto-running install.sh when setup is missing
  --force-install            Always run install.sh before launching
  --recreate-venv            Pass through to install.sh
  --force-sync               Pass through to install.sh
  --skip-python-install      Pass through to install.sh
  --local-uv                 Pass through to install.sh
EOF
}

abspath() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$SCRIPT_DIR" "$1" ;;
    esac
}

append_install_arg() {
    if [ -n "$INSTALL_ARGS" ]; then
        INSTALL_ARGS="$INSTALL_ARGS
$1"
    else
        INSTALL_ARGS="$1"
    fi
}

append_passthrough() {
    if [ -n "$PASS_THROUGH" ]; then
        PASS_THROUGH="$PASS_THROUGH
$1"
    else
        PASS_THROUGH="$1"
    fi
}

setup_needed() {
    VENV_PYTHON="$VENV_DIR/bin/python"
    INSTALL_STAMP="$VENV_DIR/.requirements-installed"
    [ ! -x "$VENV_PYTHON" ] || [ ! -f "$INSTALL_STAMP" ] || [ "$REQUIREMENTS_FILE" -nt "$INSTALL_STAMP" ]
}

run_install() {
    set -- "$INSTALL_SCRIPT"
    old_ifs=$IFS
    IFS='
'
    for arg in $INSTALL_ARGS; do
        set -- "$@" "$arg"
    done
    IFS=$old_ifs
    "$@"
}

run_jupyter() {
    VENV_PYTHON="$VENV_DIR/bin/python"
    set -- "$VENV_PYTHON" -m jupyter "$JUPYTER_SUBCOMMAND" "$WORK_DIR"
    old_ifs=$IFS
    IFS='
'
    for arg in $PASS_THROUGH; do
        set -- "$@" "$arg"
    done
    IFS=$old_ifs
    exec "$@"
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
            append_install_arg "--python"
            append_install_arg "$2"
            shift 2
            ;;
        --venv)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            VENV_DIR=$(abspath "$2")
            append_install_arg "--venv"
            append_install_arg "$VENV_DIR"
            shift 2
            ;;
        --requirements)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            REQUIREMENTS_FILE=$(abspath "$2")
            append_install_arg "--requirements"
            append_install_arg "$REQUIREMENTS_FILE"
            shift 2
            ;;
        --work-dir)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            WORK_DIR=$(abspath "$2")
            shift 2
            ;;
        --uv-dir)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            UV_DIR=$(abspath "$2")
            append_install_arg "--uv-dir"
            append_install_arg "$UV_DIR"
            shift 2
            ;;
        --command)
            [ "$#" -ge 2 ] || die "Missing value for $1"
            JUPYTER_SUBCOMMAND="$2"
            shift 2
            ;;
        --no-install)
            AUTO_INSTALL=0
            shift
            ;;
        --force-install)
            FORCE_INSTALL=1
            shift
            ;;
        --recreate-venv)
            append_install_arg "--recreate-venv"
            shift
            ;;
        --force-sync)
            append_install_arg "--force"
            shift
            ;;
        --skip-python-install)
            append_install_arg "--skip-python-install"
            shift
            ;;
        --local-uv)
            append_install_arg "--local-uv"
            shift
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                append_passthrough "$1"
                shift
            done
            break
            ;;
        *)
            append_passthrough "$1"
            shift
            ;;
    esac
done

cd "$SCRIPT_DIR"

[ -x "$INSTALL_SCRIPT" ] || die "Install script is missing or not executable: $INSTALL_SCRIPT"

if [ "$FORCE_INSTALL" -eq 1 ]; then
    status "Running install.sh before launch"
    run_install
elif setup_needed; then
    if [ "$AUTO_INSTALL" -eq 1 ]; then
        status "Environment missing or stale; running install.sh"
        run_install
    else
        die "Environment is missing or stale; run ./install.sh or remove --no-install"
    fi
fi

mkdir -p "$WORK_DIR"
status "Starting Jupyter $JUPYTER_SUBCOMMAND in $WORK_DIR"
run_jupyter
