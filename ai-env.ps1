[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = "Stop"

$PythonVersion = "3.11"
$UvDir = Join-Path $PSScriptRoot ".uv"
$LocalUv = Join-Path $UvDir "uv.exe"
$VenvDir = Join-Path $PSScriptRoot ".venv"
$VenvPython = Join-Path $VenvDir "Scripts/python.exe"
$WorkDir = Join-Path $PSScriptRoot "work"
$RemoveLocalUv = $false

function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message"
}

function Get-EmbeddedRequirements {
    @"
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
"@
}

function Get-Uv {
    $systemUv = Get-Command uv -ErrorAction SilentlyContinue
    if ($null -ne $systemUv) {
        Write-Status "Using system uv at $($systemUv.Source)"
        return $systemUv.Source
    }

    if (Test-Path $LocalUv) {
        Write-Status "Using local uv at $LocalUv"
        return $LocalUv
    }

    $installer = Get-Command powershell -ErrorAction SilentlyContinue
    if ($null -eq $installer) {
        $installer = Get-Command pwsh -ErrorAction SilentlyContinue
    }
    if ($null -eq $installer) {
        throw "Missing PowerShell executable needed to bootstrap uv."
    }

    Write-Status "Installing uv into $UvDir"
    New-Item -ItemType Directory -Force -Path $UvDir | Out-Null
    $env:UV_INSTALL_DIR = $UvDir
    $env:UV_NO_MODIFY_PATH = "1"
    & $installer.Source -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/install.ps1 | iex" | Out-Null
    Remove-Item Env:UV_INSTALL_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:UV_NO_MODIFY_PATH -ErrorAction SilentlyContinue

    if (-not (Test-Path $LocalUv)) {
        throw "uv installation completed but $LocalUv was not created."
    }

    $script:RemoveLocalUv = $true
    return $LocalUv
}

function Remove-TemporaryUv {
    if ($script:RemoveLocalUv -and (Test-Path $UvDir)) {
        Write-Status "Removing temporary uv installation from $UvDir"
        Remove-Item -Recurse -Force $UvDir
    }
}

function Install-Env {
    $requirementsPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-env-requirements-" + [System.Guid]::NewGuid().ToString("N") + ".txt")
    Set-Content -Path $requirementsPath -Value (Get-EmbeddedRequirements) -NoNewline
    $uv = Get-Uv

    try {
        Write-Status "Ensuring Python $PythonVersion is available"
        & $uv python install $PythonVersion

        if (-not (Test-Path $VenvPython)) {
            Write-Status "Creating virtual environment in $VenvDir"
            & $uv venv --python $PythonVersion $VenvDir
        } else {
            Write-Status "Using existing virtual environment in $VenvDir"
        }

        Write-Status "Installing dependencies"
        & $uv pip install --python $VenvPython -r $requirementsPath
        Write-Status "Environment is ready"
    } finally {
        Remove-Item -Force $requirementsPath -ErrorAction SilentlyContinue
        Remove-TemporaryUv
    }
}

Install-Env
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Write-Status "Starting JupyterLab in $WorkDir"
& $VenvPython -m jupyter lab $WorkDir @Args
