#!/usr/bin/env pwsh

$SUCCESS=0

# Fail on first error
$ErrorActionPreference = "Stop"

function CreateStartupApp() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param()

    $Name = $args[0]
    $RunPath = $args[1]

    Write-Output "[Win10] Creating startup app '$Name' -> $RunPath"

    $RegItem = @{
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        Name = $Name
    }

    # Create path if missing
    $Path = Get-Item -Path $RegItem.Path -ErrorAction SilentlyContinue
    if ($null -eq $Path) { New-Item -Path $RegItem.Path }

    if ($null -eq (Get-ItemProperty @RegItem -ErrorAction SilentlyContinue)) {
        New-ItemProperty @RegItem -Value "$RunPath" -PropertyType String -Force | Out-Null
        Write-Host 'Added Registry value' -f Green
    } else {
        Write-Host "Value already exists" -f Yellow
        #set-ItemProperty @RegItem -Value "$RunPath"
    }
}

function DefaultModules() {
    Install-Module -Name posh-git -Scope CurrentUser -Force
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
}

function ColorizePrompt() {
    Write-Output "[Win10] Setting up colorized and git-aware PowerShell prompt"
    winget install JanDeDobbeleer.OhMyPosh -s winget
    oh-my-posh font install Hack
    oh-my-posh font install Meslo
}

function DefaultFileExplorerSettings() {
    Write-Output "[Win10] Show extensions and hidden files in file explorer"
    Set-Itemproperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'HideFileExt' -value 0
    Set-Itemproperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'Hidden' -value 1
    #Set-Itemproperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
    #  -Name 'ShowSuperHidden' -value 1
}

function NumLockOnStartup() {
    Write-Output "[Win10] NumLock on at startup"
    Set-Itemproperty -path 'registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' `
      -Name 'InitialKeyboardIndicators' -value 2147483650
    # could also be =2 on some systems
}

function DarkThemeUI() {
    Write-Output "[Win10] Use dark UI theme"
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
      -Name 'AppsUseLightTheme' -Value 0
}

function Install-KeepassDarkTheme() {
    Write-Output "[Win10] Installing Keepass plugins"
    Push-Location 'C:\Program Files (x86)\KeePass2x\Plugins'
    Invoke-WebRequest -Uri "https://github.com/xatupal/KeeTheme/releases/latest/download/KeeTheme.dll" -OutFile "KeeTheme.dll"
    Invoke-WebRequest -Uri "https://github.com/xatupal/KeeTheme/releases/latest/download/KeeTheme.plgx" -OutFile "KeeTheme.plgx"
    mkdir 'DarkenKP'
    Push-Location 'DarkenKP'
    Invoke-WebRequest -Uri "https://github.com/BradyThe/DarkenKP/releases/latest/download/KeeTheme.ini" -OutFile "KeeTheme.ini"
    Pop-Location
    Pop-Location
}

function Install-Komorebi() {
    Write-Output "[Win10] Installing Komorebi"
    winget install LGUG2Z.whkd
    winget install LGUG2Z.komorebi
}

$request=$args[0]

Switch ($request)
{
    {$_ -match 'test'} {
        Write-Output "---=== TEST CLAUSE OR PLACEHOLDER ===---"
        Write-Output "  Will not actually install anything."
        Write-Output " "
        Write-Output 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        Exit $SUCCESS
    }
    {$_ -match 'startup'} {
        $prog_name=$args[1]
        $prog_path=$args[2]
        CreateStartupApp "$prog_name" "$prog_path"
        Exit $SUCCESS
    }
    {$_ -match 'default-modules'} {
        DefaultModules
    }
    {$_ -match 'win10-defaults'} {
        DefaultFileExplorerSettings
        NumLockOnStartup
        DarkThemeUI
        Exit $SUCCESS
    }
    {$_ -match 'install-keepass-plugins'} {
        Install-KeepassDarkTheme
        Exit $SUCCESS
    }
    {$_ -match 'install-komorebi'} {
        Install-Komorebi
        Exit $SUCCESS
    }
    {$_ -match 'colorize'} {
        ColorizePrompt
        Exit $SUCCESS
    }
    default {
        Write-Error "Request invalid" -ErrorAction Stop
    }
}
