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

function la
{
    Get-ChildItem -Force
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

function git-rm-submodule($submodule_name)
{
    # Remove the submodule entry from .git/config
    git submodule deinit -f $submodule_name
    # Remove the submodule directory from the superproject's .git/modules directory
    Remove-Item -Force -Recurse .git/modules/$submodule_name
    # Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
    git rm -f $submodule_name
}

function commit-push {
    git add -A
    git commit -m '"$argumentList"'
    git push
}

$env:PYTHONIOENCODING="utf-8"

Invoke-Expression "$(thefuck --alias)"

# Load custom theme for Windows Terminal
$theme="blue-owl"

Import-Module posh-git
oh-my-posh init pwsh --config `
    "$HOME\Documents\WindowsPowerShell\$theme.omp.json" `
    | Invoke-Expression

#Write-Host "[Win10] Using MGS ps1 Profile"
