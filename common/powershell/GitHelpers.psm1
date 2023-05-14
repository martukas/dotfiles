#!/usr/bin/env pwsh

function GitRemoveSubmodule($submodule_name)
{
    # Remove the submodule entry from .git/config
    git submodule deinit -f $submodule_name
    # Remove the submodule directory from the superproject's .git/modules directory
    Remove-Item -Force -Recurse .git/modules/$submodule_name
    # Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
    git rm -f $submodule_name
}

function GitCdRoot
{
    $git_root = git root
    if ($git_root) {
        Set-Location $git_root
    }
}

function GitNewBranch
{
    git checkout -b $args[0]
    git push --set-upstream origin $args[0]
}

function GitAddAllCommitPush {
    git add -A
    git commit -m $args
    git push
}

function GitAddAllCommitPushBypassHooks {
    git add -A
    git commit --no-verify -m $args
    git push
}

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

function GitCommitIssueBranch
{
    $branch = git symbolic-ref --short HEAD
    if ($branch -match '^(issue_)([0-9]+)(.*)$') {
        if ($args.Count -lt 1) {
            Write-Error "No commit message provided!" -ErrorAction Stop
        }
        $NUMBER=$Matches[2]
        $message = "$args; updates #$NUMBER"
        GitAddAllCommitPush $message
    }
    else {
        Write-Error "Not on an issue branch!" -ErrorAction Stop
    }
}
