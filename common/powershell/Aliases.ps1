#!/usr/bin/env pwsh

Import-Module "$HOME\.dotfiles\common\powershell\GitHelpers.psm1"

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

function mx
{
    chmod --recursive 775 $args
}

function mw
{
    chmod --recursive 664 $args
}

function own
{
    $user_name = id -un
    $user_group = id -gn
    sudo chown --recursive $user_name`:$user_group $args
}

function la
{
    Get-ChildItem -Force $args
}

function mcd
{
    mkdir $args[0]
    Set-Location $args[0]
}

function upd
{
    if ($IsWindows)
    {
        winget upgrade --all $args
    }
    else
    {
        ~\.dotfiles\linux\bin\apt-update-wrapper.sh $args
    }
}

function GoUp
{
    Param
    (
        [int]$Num = 1
    )
    for ($i = 1; $i -le $Num; $i++)
    {
        [string]$up += '../'
    }
    Set-Location $up
}

function DotfilesUpdate
{
    Push-Location (Get-Item "$HOME\.dotfiles").Target
    git pull
    if ($IsWindows)
    {
        .\install.ps1
    }
    else
    {
        .\install.sh
    }
    Pop-Location
}

function DotfilesUpgradeSubmodules() {
    Push-Location (Get-Item "$HOME\.dotfiles").Target
    git submodule update --remote private
    git submodule update --remote dotbot
    git submodule update --remote superpack
    git submodule update --remote common/bash-git-prompt
    git submodule update --remote common/bash/plugins/dircolors-solarized
    git submodule update --remote linux/logiops
    git submodule update --remote linux/gdb/qt5printers
    Pop-Location
}

New-Alias up GoUp
New-Alias dfu DotfilesUpdate
New-Alias df-upgrade DotfilesUpgradeSubmodules

New-Alias cdgr GitCdRoot
New-Alias dnb GitNewBranch # should be gnb, but Drum'n'bass sounds better
New-Alias missue GitMakeIssueBranch
New-Alias issue GitCommitIssueBranch
New-Alias git-rm-submodule GitRemoveSubmodule
New-Alias commit-push GitAddAllCommitPush
New-Alias commit-push-bypass-hooks GitAddAllCommitPushBypassHooks
