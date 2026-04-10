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
$DepsMarker = Join-Path $VenvDir ".ai-env-packages.txt"
$WorkDir = Join-Path $PSScriptRoot "work"
$PasswordFile = Join-Path $PSScriptRoot "password.txt"
$RemoveLocalUv = $false
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

function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message"
}

function New-RandomPassword {
    return [Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
}

function Get-OrCreatePassword {
    if (-not (Test-Path $PasswordFile) -or [string]::IsNullOrWhiteSpace((Get-Content -Raw $PasswordFile -ErrorAction SilentlyContinue))) {
        $password = New-RandomPassword
        Set-Content -Path $PasswordFile -Value $password -NoNewline
        Write-Status "Generated server password in $PasswordFile"
        return $password
    }

    return (Get-Content -Raw $PasswordFile).Trim()
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

function Test-DependenciesMatch {
    if (-not (Test-Path $DepsMarker)) {
        return $false
    }

    return (Get-Content -Raw $DepsMarker) -eq ($Packages -join "`n")
}

function Install-Env {
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

        if (Test-DependenciesMatch) {
            Write-Status "Dependencies already up to date"
        } else {
            Write-Status "Installing dependencies"
            & $uv pip install --python $VenvPython @Packages
            Set-Content -Path $DepsMarker -Value ($Packages -join "`n") -NoNewline
        }

        Write-Status "Environment is ready"
    } finally {
        Remove-TemporaryUv
    }
}

Install-Env
$Password = Get-OrCreatePassword
$env:AI_ENV_PASSWORD = $Password
$HashedPassword = & $VenvPython -c "import os; from jupyter_server.auth import passwd; print(passwd(os.environ['AI_ENV_PASSWORD']))"
Remove-Item Env:AI_ENV_PASSWORD -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Write-Status "Starting JupyterLab in $WorkDir"
& $VenvPython -m jupyter lab $WorkDir --PasswordIdentityProvider.hashed_password=$HashedPassword --PasswordIdentityProvider.password_required=True --PasswordIdentityProvider.allow_password_change=False @Args
