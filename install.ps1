[CmdletBinding()]
param(
    [switch]$Help,
    [string]$Python = "3.11",
    [string]$Venv = ".venv",
    [string]$Requirements = "requirements.txt",
    [string]$UvDir = ".uv",
    [switch]$Force,
    [switch]$RecreateVenv,
    [switch]$SkipPythonInstall,
    [switch]$LocalUv
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message"
}

function Resolve-ProjectPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $Path))
}

function Show-Usage {
    @"
Usage: ./install.ps1 [options]

Prepare the local Python environment for this project.

Options:
  -Help                    Show this help message and exit
  -Python VERSION          Python version for uv to install/use
  -Venv DIR                Virtual environment directory
  -Requirements FILE       Requirements file to install
  -UvDir DIR               Directory for a repo-local uv install
  -Force                   Reinstall dependencies even when requirements are unchanged
  -RecreateVenv            Remove and recreate the virtual environment before installing
  -SkipPythonInstall       Skip 'uv python install'
  -LocalUv                 Prefer a repo-local uv over the system uv
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

function Get-UvCommand {
    param(
        [string]$LocalUvExe,
        [switch]$PreferLocal
    )

    if ($PreferLocal -and (Test-Path $LocalUvExe)) {
        Write-Status "Using local uv at $LocalUvExe"
        return $LocalUvExe
    }

    $systemUv = Get-Command uv -ErrorAction SilentlyContinue
    if ($null -ne $systemUv) {
        Write-Status "Using system uv at $($systemUv.Source)"
        return $systemUv.Source
    }

    if (Test-Path $LocalUvExe) {
        Write-Status "Using existing local uv at $LocalUvExe"
        return $LocalUvExe
    }

    $installer = Get-Command powershell -ErrorAction SilentlyContinue
    if ($null -eq $installer) {
        $installer = Get-Command pwsh -ErrorAction SilentlyContinue
    }
    if ($null -eq $installer) {
        throw "Missing PowerShell executable needed to bootstrap uv."
    }

    Write-Status "Installing local uv into $UvDirPath"
    New-Item -ItemType Directory -Force -Path $UvDirPath | Out-Null
    $env:UV_INSTALL_DIR = $UvDirPath
    & $installer.Source -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/install.ps1 | iex" | Out-Null
    Remove-Item Env:UV_INSTALL_DIR -ErrorAction SilentlyContinue
    if (-not (Test-Path $LocalUvExe)) {
        throw "uv installation completed but $LocalUvExe was not created."
    }

    return $LocalUvExe
}

$VenvPath = Resolve-ProjectPath $Venv
$RequirementsPath = Resolve-ProjectPath $Requirements
$UvDirPath = Resolve-ProjectPath $UvDir
$LocalUvExe = Join-Path $UvDirPath "uv.exe"
$VenvPython = Join-Path $VenvPath "Scripts/python.exe"
$InstallStamp = Join-Path $VenvPath ".requirements-installed"

if (-not (Test-Path $RequirementsPath)) {
    throw "Could not find requirements file: $RequirementsPath"
}

$uv = Get-UvCommand -LocalUvExe $LocalUvExe -PreferLocal:$LocalUv

if (-not $SkipPythonInstall) {
    Write-Status "Ensuring Python $Python is available"
    & $uv python install $Python
} else {
    Write-Status "Skipping Python installation step"
}

if ($RecreateVenv -and (Test-Path $VenvPath)) {
    Write-Status "Recreating virtual environment in $VenvPath"
    Remove-Item -Recurse -Force $VenvPath
}

if (-not (Test-Path $VenvPython)) {
    Write-Status "Creating virtual environment in $VenvPath"
    & $uv venv --python $Python $VenvPath
} else {
    Write-Status "Using existing virtual environment in $VenvPath"
}

$requirementsChanged = $Force -or -not (Test-Path $InstallStamp) -or ((Get-Item $RequirementsPath).LastWriteTimeUtc -gt (Get-Item $InstallStamp -ErrorAction SilentlyContinue).LastWriteTimeUtc)
if ($requirementsChanged) {
    Write-Status "Installing dependencies from $(Split-Path $RequirementsPath -Leaf)"
    & $uv pip install --python $VenvPython -r $RequirementsPath
    New-Item -ItemType File -Force -Path $InstallStamp | Out-Null
} else {
    Write-Status "Dependencies already up to date"
}

Write-Status "Environment is ready"
