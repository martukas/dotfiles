[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
param()

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

# git new branch
function gnb
{
    git checkout -b $args[0]
    git push --set-upstream origin $args[0]
}


function GitRemoveSubmodule($submodule_name)
{
    # Remove the submodule entry from .git/config
    git submodule deinit -f $submodule_name
    # Remove the submodule directory from the superproject's .git/modules directory
    Remove-Item -Force -Recurse .git/modules/$submodule_name
    # Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
    git rm -f $submodule_name
}

New-Alias git-rm-submodule GitRemoveSubmodule

function GitAddAllCommitPush {
    git add -A
    git commit -m ""$args""
    git push
}

New-Alias commit-push GitAddAllCommitPush

$env:PYTHONIOENCODING="utf-8"

Invoke-Expression "$(thefuck --alias)"

Import-Module posh-git

# Load custom theme for Windows Terminal
if ($IsWindows) {
    $theme="blue-owl"
    oh-my-posh init pwsh --config `
    "$HOME\Documents\WindowsPowerShell\$theme.omp.json" `
    | Invoke-Expression
}
