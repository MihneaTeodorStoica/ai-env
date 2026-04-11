#!/usr/bin/env sh
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
LOCAL_UV="$ROOT/.uv/uv"
VENV_DIR="$ROOT/.venv"
WORK_DIR="$ROOT/work"

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

if command -v uv >/dev/null 2>&1; then
    UV_BIN="$(command -v uv)"
    echo "[+] Using system uv: $UV_BIN"
elif [ -x "$LOCAL_UV" ]; then
    UV_BIN="$LOCAL_UV"
    echo "[+] Using local uv: $UV_BIN"
else
    echo "[+] Installing uv into .uv/"
    curl -LsSf https://astral.sh/uv/install.sh | \
        env UV_INSTALL_DIR="$ROOT/.uv" UV_NO_MODIFY_PATH=1 sh
    UV_BIN="$LOCAL_UV"
fi

if [ ! -d "$VENV_DIR" ]; then
    echo "[+] Creating Python 3.11 virtual environment in .venv/"
    "$UV_BIN" venv --python 3.11 "$VENV_DIR"
else
    echo "[+] Virtual environment already exists: $VENV_DIR"
fi

echo "[+] Installing packages into .venv/"
# shellcheck disable=SC2086
"$UV_BIN" pip install --python "$VENV_DIR/bin/python" $PACKAGES

if [ ! -d "$WORK_DIR" ]; then
    echo "[+] Creating work/ directory"
    mkdir -p "$WORK_DIR"
fi

echo "[+] Starting JupyterLab in work/"

cd "$WORK_DIR"

TOKEN="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
echo "$TOKEN" > "$ROOT/token.txt"

exec "$UV_BIN" run --python "$VENV_DIR/bin/python" \
    jupyter lab \
    --ip=127.0.0.1 \
    --ServerApp.root_dir="$WORK_DIR" \
    --ServerApp.open_browser=True \
    --IdentityProvider.token="$TOKEN"