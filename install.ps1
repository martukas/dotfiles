#!/usr/bin/env pwsh

if (-Not $IsWindows) {
    Write-Error "This script only supports Windows" -ErrorAction Stop
}

$user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($user)
if (-not($principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)))
{
    Write-Error "Please run this script as an administrator" -ErrorAction Stop
}

$found = [bool] (Get-Command -ErrorAction Ignore -Type Application pwsh)
if (-not($found))
{
    Write-Error "Latest PowerShell (pwsh.exe) is not installed. Pleas run 'winget install -e --id Microsoft.PowerShell'" -ErrorAction Stop
}

# Fail on first error
$ErrorActionPreference = "Stop"

$CONFIG_COMMON = "conf_common.yaml"
$CONFIG_WINDOWS = "conf_windows.yaml"
$DOTBOT_DIR = "dotbot"

$DOTBOT_BIN = "bin/dotbot"
$BASEDIR = $PSScriptRoot

Set-Location $BASEDIR

git -C $DOTBOT_DIR submodule sync --quiet --recursive
git submodule update --init --recursive $DOTBOT_DIR
git submodule update --init --recursive superpack
git submodule update --init --recursive private
git submodule update --init --recursive common/bash/plugins/dircolors-solarized

git submodule update

$confirmation = Read-Host "Do you want to run one-time installation scripts?"
if ($confirmation -eq 'y') {
    # Configure file exporer, numlock, theme
    .\windows\packages.ps1 default-modules
    .\windows\packages.ps1 windows-defaults

    # Need pip and pipenv for what comes next
    python -m pip install --upgrade pip
    python -m pip install --upgrade pipenv thefuck pre-commit

    Push-Location superpack
    pipenv install
    Start-Process pwsh -WindowStyle Maximized -ArgumentList `
        "-Command & {pipenv run python .\superpack\superpack.py ..\windows\packages.yml}"
    Pop-Location

    Write-Output 'Press any key to continue with dotbot config...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

#file associations - notepad++, irfanview

foreach ($PYTHON in ('python', 'python3')) {
    # Python redirects to Microsoft Store in Windows 10 when not installed
    if (& { $ErrorActionPreference = "SilentlyContinue"
            ![string]::IsNullOrEmpty((&$PYTHON -V))
            $ErrorActionPreference = "Stop" }) {

        Write-Output "Linking dotfiles for general bash use"
        &$PYTHON $(Join-Path $BASEDIR -ChildPath $DOTBOT_DIR | Join-Path -ChildPath $DOTBOT_BIN) `
            -d $BASEDIR -c $CONFIG_COMMON $Args

        Write-Output "Linking Windows-specific dotfiles"
        &$PYTHON $(Join-Path $BASEDIR -ChildPath $DOTBOT_DIR | Join-Path -ChildPath $DOTBOT_BIN) `
            -d $BASEDIR -c $CONFIG_WINDOWS $Args

        return
    }
}
Write-Error "Error: Cannot find Python."
