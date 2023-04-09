#!/usr/bin/env pwsh

# Stolen from:
# https://www.reddit.com/r/PowerShell/comments/10zxwcv/sharing_this_cool_thing_i_wrote_psscriptanalzyer/

$ScriptAnalyzerResults = Invoke-ScriptAnalyzer -Path . -Recurse

if ($null -ne $ScriptAnalyzerResults) {
    foreach ($BrokenRule in $ScriptAnalyzerResults) {
        throw "$($BrokenRule.RuleName) | SEVERITY:$($BrokenRule.Severity) | ScriptPath:$($BrokenRule.ScriptPath) | Message:$($BrokenRule.Message)"
    }
}
