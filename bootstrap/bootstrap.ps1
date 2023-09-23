#!/usr/bin/env pwsh

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
$FAILURE=1
$SUCCESS=0

# @todo check if linux or windows (in old powershell!)
$confirmation = Read-Host "This script only supports Windows. Do you want to continue?"
if ($confirmation -ne 'y') {
    Write-Error "Aborted" -ErrorAction Stop
}

# Fail on first error
$ErrorActionPreference = "Stop"

Write-Output "==============================================================="
Write-Output "============== MGS personal bootstrapper - Win10 =============="
Write-Output "==============================================================="
Write-Output " "
Write-Output "  -- removes OneDrive"
Write-Output "  -- installs esenstials: PowerShell7, Git, Python"
Write-Output "  -- configures ssh and github credentials"
Write-Output "  -- clones the dotfile repository"
Write-Output "  -- installs common programs"
Write-Output " "
Write-Output 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

Write-Output " "

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-Output "Running script in $dir"

Push-Location $dir

Write-Output "Remove OneDrive"
winget uninstall Microsoft.OneDrive

Write-Output "Set new PowerShell profile root"
New-ItemProperty `
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' `
  Personal -Value "$HOME\Documents" -Type ExpandString -Force

Write-Output "Installing modern PowerShell"
winget install -e --id Microsoft.PowerShell

Write-Output "Installing Git"
winget install --id Git.Git -e --source winget

#Must install python here, so that we have it available in bash for dotbot
Write-Output "Installing Python"
winget install --id Python.Python.3.12 -e --source winget --scope=machine
#Temporary solution until bash profiles are imported
$py_alias = "alias python='winpty python.exe'"
$out_path = "$HOME\.bash_profile"
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($out_path, $py_alias, $Utf8NoBomEncoding)

Invoke-WebRequest -Uri "https://github.com/martukas/dotfiles/raw/master/bootstrap/config_ssh.sh" -OutFile "config_ssh.sh"

Start-Process -FilePath "$Env:Programfiles\Git\bin\sh.exe" -ArgumentList "--login","-i","-c",'"./config_ssh.sh start"'

Pop-Location

Write-Output "Bootstrapping complete. You should now restart the machine and run 'install.ps1' from pwsh."
Write-Output " "
Write-Output 'Press any key to restart machine...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

Restart-Computer -Confirm
