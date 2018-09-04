$FAILURE=1
$SUCCESS=0

function CreateStartupApp($Name, $RunPath) {
    Write-Host "[Win10] Creating startup app '$Name' -> $RunPath"

    $RegItem = @{
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        Name = $Name
    }

    # Create path if missing
    $Path = Get-Item -Path $RegItem.Path -ErrorAction SilentlyContinue
    if ($null -eq $Path) { New-Item -Path $RegItem.Path }

    if ($null -eq (Get-ItemProperty @RegItem -ErrorAction SilentlyContinue)) {
        New-ItemProperty @RegItem -Value "$RunPath" -PropertyType DWord -Force | Out-Null
        Write-Host 'Added Registry value' -f Green
    } else {
        Write-Host "Value already exists" -f Yellow
        #set-ItemProperty @RegItem -Value "$RunPath"
    }
}

function ColorizePrompt() {
    Write-Host "[Win10] Setting up colorized and git-aware PowerShell prompt"
    Install-Module posh-git -Scope CurrentUser -Force
    winget install JanDeDobbeleer.OhMyPosh -s winget
}

function InstallNerdfonts()
{
    oh-my-posh font install Hack
    oh-my-posh font install Meslo
}

function DefaultFileExplorerSettings() {
    Write-Host "[Win10] Show extensions and hidden files in file explorer"
    Set-Itemproperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'HideFileExt' -value 0
    Set-Itemproperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'Hidden' -value 1
    #Set-Itemproperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
    #  -Name 'ShowSuperHidden' -value 1
}

function NumLockOnStartup() {
    Write-Host "[Win10] NumLock on at startup"
    Set-Itemproperty -path 'registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' `
      -Name 'InitialKeyboardIndicators' -value 2147483650
    # could also be =2 on some systems
}

function DarkThemeUI() {
    Write-Host "[Win10] Use dark UI theme"
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
      -Name 'AppsUseLightTheme' -Value 0
}

$request=$args[0]

Switch ($request)
{
    {$_ -match 'test'} {
        Write-Host "---=== TEST CLAUSE OR PLACEHOLDER ===---"
        Write-Host "  Will not actually install anything."
        Write-Host " "
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        Exit $SUCCESS
    }
    {$_ -match 'system_defaults'} {
        DefaultFileExplorerSettings
        NumLockOnStartup
        DarkThemeUI
        Exit $SUCCESS
    }
    {$_ -match 'startup'} {
        $prog_name=$args[1]
        $prog_path=$args[2]
        CreateStartupApp "$prog_name" "$prog_path"
        Exit $SUCCESS
    }
    {$_ -match 'colorize'} {
        ColorizePrompt
        InstallNerdfonts
        Exit $SUCCESS
    }
    default {
        Write-Host "Request invalid"
        Exit $FAILURE
    }
}
