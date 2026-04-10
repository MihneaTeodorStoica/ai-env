#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PYTHON_VERSION="3.11"
UV_DIR="$SCRIPT_DIR/.uv"
LOCAL_UV="$UV_DIR/uv"
VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"
WORK_DIR="$SCRIPT_DIR/work"

status() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

write_requirements_file() {
    cat >"$1" <<'EOF'
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
EOF
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
}

install_env() {
    REQUIREMENTS_TMP=$(mktemp "${TMPDIR:-/tmp}/ai-env-requirements.XXXXXX")
    trap 'rm -f "$REQUIREMENTS_TMP"' EXIT INT TERM HUP
    write_requirements_file "$REQUIREMENTS_TMP"

    ensure_uv

    status "Ensuring Python $PYTHON_VERSION is available"
    "$UV" python install "$PYTHON_VERSION"

    if [ ! -x "$VENV_PYTHON" ]; then
        status "Creating virtual environment in $VENV_DIR"
        "$UV" venv --python "$PYTHON_VERSION" "$VENV_DIR"
    else
        status "Using existing virtual environment in $VENV_DIR"
    fi

    status "Installing dependencies"
    "$UV" pip install --python "$VENV_PYTHON" -r "$REQUIREMENTS_TMP"

    rm -f "$REQUIREMENTS_TMP"
    trap - EXIT INT TERM HUP
    status "Environment is ready"
}

cd "$SCRIPT_DIR"
install_env
mkdir -p "$WORK_DIR"
status "Starting JupyterLab in $WORK_DIR"
exec "$VENV_PYTHON" -m jupyter lab "$WORK_DIR" "$@"
