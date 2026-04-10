#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PYTHON_VERSION="3.11"
UV_DIR="$SCRIPT_DIR/.uv"
LOCAL_UV="$UV_DIR/uv"
VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"
DEPS_MARKER="$VENV_DIR/.ai-env-packages.txt"
WORK_DIR="$SCRIPT_DIR/work"
PASSWORD_FILE="$SCRIPT_DIR/password.txt"
REMOVE_LOCAL_UV=0
PACKAGES="
numpy
pandas
scipy
scikit-learn
xgboost
lightgbm
catboost
torch
torchvision
pytorch-lightning
torchmetrics
transformers
datasets
evaluate
spacy
nltk
gensim
fasttext
opencv-python
Pillow
scikit-image
matplotlib
seaborn
plotly
autoviz
joblib
tqdm
tensorboard
tensorflow
keras
jax
flax
optax
ydata-profiling
jupyterlab
"

status() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

generate_password() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 24 | tr -d '\n'
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import secrets; print(secrets.token_urlsafe(24), end="")'
        return
    fi

    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
}

ensure_password() {
    if [ ! -s "$PASSWORD_FILE" ]; then
        PASSWORD=$(generate_password)
        printf '%s\n' "$PASSWORD" >"$PASSWORD_FILE"
        status "Generated server password in $PASSWORD_FILE"
    else
        PASSWORD=$(head -n 1 "$PASSWORD_FILE")
    fi

    [ -n "$PASSWORD" ] || die "Password file is empty: $PASSWORD_FILE"
}

ensure_uv() {
    if command -v uv >/dev/null 2>&1; then
        UV=$(command -v uv)
        status "Using system uv at $UV"
        return
    fi

    if [ -x "$LOCAL_UV" ]; then
        UV="$LOCAL_UV"
        status "Using local uv at $UV"
        return
    fi

    command -v curl >/dev/null 2>&1 || die "Missing required command: curl"
    status "Installing uv into $UV_DIR"
    mkdir -p "$UV_DIR"
    env UV_INSTALL_DIR="$UV_DIR" UV_NO_MODIFY_PATH=1 sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"
    UV="$LOCAL_UV"
    REMOVE_LOCAL_UV=1
}

cleanup_local_uv() {
    if [ "$REMOVE_LOCAL_UV" -eq 1 ] && [ -d "$UV_DIR" ]; then
        status "Removing temporary uv installation from $UV_DIR"
        rm -rf "$UV_DIR"
    fi
}

dependencies_match() {
    [ -f "$DEPS_MARKER" ] || return 1
    [ "$(cat "$DEPS_MARKER")" = "$PACKAGES" ]
}

install_env() {
    trap 'cleanup_local_uv' EXIT INT TERM HUP

    ensure_uv

    status "Ensuring Python $PYTHON_VERSION is available"
    "$UV" python install "$PYTHON_VERSION"

    if [ ! -x "$VENV_PYTHON" ]; then
        status "Creating virtual environment in $VENV_DIR"
        "$UV" venv --python "$PYTHON_VERSION" "$VENV_DIR"
    else
        status "Using existing virtual environment in $VENV_DIR"
    fi

    if dependencies_match; then
        status "Dependencies already up to date"
    else
        status "Installing dependencies"
        # shellcheck disable=SC2086
        set -- $PACKAGES
        "$UV" pip install --python "$VENV_PYTHON" "$@"
        printf '%s' "$PACKAGES" >"$DEPS_MARKER"
    fi

    cleanup_local_uv
    trap - EXIT INT TERM HUP
    status "Environment is ready"
}

cd "$SCRIPT_DIR"
install_env
ensure_password
HASHED_PASSWORD=$(AI_ENV_PASSWORD="$PASSWORD" "$VENV_PYTHON" -c 'import os; from jupyter_server.auth import passwd; print(passwd(os.environ["AI_ENV_PASSWORD"]))')
mkdir -p "$WORK_DIR"
status "Starting JupyterLab in $WORK_DIR"
exec "$VENV_PYTHON" -m jupyter lab "$WORK_DIR" \
    --PasswordIdentityProvider.hashed_password="$HASHED_PASSWORD" \
    --PasswordIdentityProvider.password_required=True \
    --PasswordIdentityProvider.allow_password_change=False \
    "$@"
