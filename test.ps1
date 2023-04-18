#!/usr/bin/env pwsh

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
