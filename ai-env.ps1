Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$LocalUv = Join-Path $Root ".uv\uv.exe"
$VenvDir = Join-Path $Root ".venv"
$WorkDir = Join-Path $Root "work"
$PythonBin = Join-Path $VenvDir "Scripts\python.exe"

$Packages = @(
    "numpy",
    "pandas",
    "scipy",
    "scikit-learn",
    "xgboost",
    "lightgbm",
    "catboost",
    "torch",
    "torchvision",
    "pytorch-lightning",
    "torchmetrics",
    "transformers",
    "datasets",
    "evaluate",
    "spacy",
    "nltk",
    "gensim",
    "fasttext",
    "opencv-python",
    "Pillow",
    "scikit-image",
    "matplotlib",
    "seaborn",
    "plotly",
    "autoviz",
    "joblib",
    "tqdm",
    "tensorboard",
    "tensorflow",
    "keras",
    "jax",
    "flax",
    "optax",
    "ydata-profiling",
    "jupyterlab"
)

$SystemUv = Get-Command uv -ErrorAction SilentlyContinue
if ($SystemUv) {
    $UvBin = $SystemUv.Source
    Write-Host "[+] Using system uv: $UvBin"
}
elseif (Test-Path -Path $LocalUv -PathType Leaf) {
    $UvBin = $LocalUv
    Write-Host "[+] Using local uv: $UvBin"
}
else {
    Write-Host "[+] Installing uv into .uv/"
    $PreviousUvInstallDir = $env:UV_INSTALL_DIR
    $PreviousUvNoModifyPath = $env:UV_NO_MODIFY_PATH

    try {
        $env:UV_INSTALL_DIR = Join-Path $Root ".uv"
        $env:UV_NO_MODIFY_PATH = "1"
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    }
    finally {
        $env:UV_INSTALL_DIR = $PreviousUvInstallDir
        $env:UV_NO_MODIFY_PATH = $PreviousUvNoModifyPath
    }

    $UvBin = $LocalUv
}

if (-not (Test-Path -Path $UvBin -PathType Leaf)) {
    throw "uv was not found after installation: $UvBin"
}

if (-not (Test-Path -Path $VenvDir -PathType Container)) {
    Write-Host "[+] Creating Python 3.11 virtual environment in .venv/"
    & $UvBin venv --python 3.11 $VenvDir
}
else {
    Write-Host "[+] Virtual environment already exists: $VenvDir"
}

Write-Host "[+] Installing packages into .venv/"
& $UvBin pip install --python $PythonBin @Packages

if (-not (Test-Path -Path $WorkDir -PathType Container)) {
    Write-Host "[+] Creating work/ directory"
    New-Item -ItemType Directory -Path $WorkDir | Out-Null
}

Write-Host "[+] Starting JupyterLab in work/"

Set-Location $WorkDir

$TokenAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
$Token = -join (1..32 | ForEach-Object {
        $TokenAlphabet[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($TokenAlphabet.Length)]
    })
Set-Content -Path (Join-Path $Root "token.txt") -Value $Token -NoNewline

& $UvBin run --python $PythonBin `
    jupyter lab `
    --ip=127.0.0.1 `
    --ServerApp.root_dir="$WorkDir" `
    --ServerApp.open_browser=True `
    --IdentityProvider.token="$Token"
