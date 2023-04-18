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

function cdgr
{
    $git_root = git root
    if ($git_root) {
        Set-Location $git_root
    }
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

New-Alias dfu DotfilesUpdate

# Dotfiles upgrade submodules
function DotfilesUpgrade() {
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

New-Alias df-upgrade DotfilesUpgrade

function GitNewBranch
{
    git checkout -b $args[0]
    git push --set-upstream origin $args[0]
}

# should be gnb, but Drum'n'bass sounds better
New-Alias dnb GitNewBranch

function GitMakeIssueBranch
{
    $subname = $args[0]
    if ($subname -match '^([0-9]+)(.*)$') {
        $branch_name = "issue_$subname"
        Write-Output "Creating git branch = $branch_name"
        GitNewBranch $branch_name
    }
    else {
        Write-Error "Must provide branch sub-name beginning with ticket number!" -ErrorAction Stop
    }
}

New-Alias missue GitMakeIssueBranch

function GitCommitIssueBranch
{
    $branch = git symbolic-ref --short HEAD
    if ($branch -match '^(issue_)([0-9]+)(.*)$') {
        if ($args.Count -lt 1) {
            Write-Error "No commit message provided!" -ErrorAction Stop
        }
        $NUMBER=$Matches[2]
        $message = "$args; updates #$NUMBER"
        GitAddAllCommitPush `"$message`"
    }
    else {
        Write-Error "Not on an issue branch!" -ErrorAction Stop
    }
}

New-Alias issue GitCommitIssueBranch

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
    git commit -m `"$args`"
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
