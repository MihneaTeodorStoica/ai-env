[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$Help,
    [string]$Python = "3.11",
    [string]$Venv = ".venv",
    [string]$Requirements = "requirements.txt",
    [string]$WorkDir = "work",
    [string]$UvDir = ".uv",
    [string]$Command = "lab",
    [switch]$NoInstall,
    [switch]$ForceInstall,
    [switch]$RecreateVenv,
    [switch]$ForceSync,
    [switch]$SkipPythonInstall,
    [switch]$LocalUv,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$JupyterArgs
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
Usage: ./run.ps1 [options] [-- <extra jupyter args>]

Start Jupyter for this project, bootstrapping the environment when needed.

Options:
  -Help                    Show this help message and exit
  -Python VERSION          Python version to use when bootstrapping
  -Venv DIR                Virtual environment directory
  -Requirements FILE       Requirements file used for bootstrap checks
  -WorkDir DIR             Directory to open in Jupyter
  -UvDir DIR               Directory for a repo-local uv install
  -Command NAME            Jupyter subcommand to run, e.g. lab or notebook
  -NoInstall               Fail instead of auto-running install.ps1 when setup is missing
  -ForceInstall            Always run install.ps1 before launching
  -RecreateVenv            Pass through to install.ps1
  -ForceSync               Pass through to install.ps1
  -SkipPythonInstall       Pass through to install.ps1
  -LocalUv                 Pass through to install.ps1
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

$InstallScript = Join-Path $PSScriptRoot "install.ps1"
$VenvPath = Resolve-ProjectPath $Venv
$RequirementsPath = Resolve-ProjectPath $Requirements
$WorkPath = Resolve-ProjectPath $WorkDir
$VenvPython = Join-Path $VenvPath "Scripts/python.exe"
$InstallStamp = Join-Path $VenvPath ".requirements-installed"

if (-not (Test-Path $InstallScript)) {
    throw "Install script is missing: $InstallScript"
}

$installArgs = @(
    "-Python", $Python,
    "-Venv", $VenvPath,
    "-Requirements", $RequirementsPath,
    "-UvDir", (Resolve-ProjectPath $UvDir)
)
if ($RecreateVenv) { $installArgs += "-RecreateVenv" }
if ($ForceSync) { $installArgs += "-Force" }
if ($SkipPythonInstall) { $installArgs += "-SkipPythonInstall" }
if ($LocalUv) { $installArgs += "-LocalUv" }

$setupNeeded = -not (Test-Path $VenvPython) -or -not (Test-Path $InstallStamp)
if (-not $setupNeeded -and (Test-Path $RequirementsPath)) {
    $setupNeeded = (Get-Item $RequirementsPath).LastWriteTimeUtc -gt (Get-Item $InstallStamp).LastWriteTimeUtc
}

if ($ForceInstall) {
    Write-Status "Running install.ps1 before launch"
    & $InstallScript @installArgs
} elseif ($setupNeeded) {
    if ($NoInstall) {
        throw "Environment is missing or stale; run ./install.ps1 or remove -NoInstall."
    }

    Write-Status "Environment missing or stale; running install.ps1"
    & $InstallScript @installArgs
}

New-Item -ItemType Directory -Force -Path $WorkPath | Out-Null
Write-Status "Starting Jupyter $Command in $WorkPath"
& $VenvPython -m jupyter $Command $WorkPath @JupyterArgs
