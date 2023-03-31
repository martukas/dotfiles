function Test-Administrator
{
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    if ( $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
    {
        Write-Output $true
    }
    else
    {
        Write-Output $false
    }
}

function upd
{
    winget upgrade --all
}

function dfu
{
    Push-Location (Get-Item "$HOME\.dotfiles").Target
    git pull
    .\install.ps1
    Pop-Location
}

# Load custom theme for Windows Terminal
$theme="blue-owl"

Import-Module posh-git
oh-my-posh init pwsh --config `
    "$HOME\Documents\WindowsPowerShell\$theme.omp.json" `
    | Invoke-Expression

#Write-Host "[Win10] Using MGS ps1 Profile"
