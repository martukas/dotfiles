#!/usr/bin/env pwsh

# Adapted from from:
# https://www.reddit.com/r/PowerShell/comments/10zxwcv/sharing_this_cool_thing_i_wrote_psscriptanalzyer/
# https://sysadmin-central.com/2021/11/04/powershell-how-to-check-if-string-contains-any-value-in-array/

# Check if a string contains any one of a set of terms to search for
# Returns True if found or False otherwise
function containsArrayValue {
    param (
        [Parameter(Mandatory=$True)]
        [string]$description,

        [Parameter(Mandatory=$True)]
        [array]$searchTerms
    )

    foreach($searchTerm in $searchTerms) {
        if($description -like "*$($searchTerm)*") {
            return $true;
        }
    }

    return $false;
}

$UselessValue = "bla"

# Run Analyzer on everything recursively
$Results = Invoke-ScriptAnalyzer -Path . -Recurse

# Find the paths of git sub-modules
$SubModulePaths = git submodule --quiet foreach --recursive pwd

# Eliminate results for files in git sub-modules
$FilteredResults = $Results | Where-Object {-Not (containsArrayValue $_.ScriptPath $SubModulePaths)}

# Sanitize paths and and add links to rule pages
foreach ($item in $FilteredResults)
{
    Add-Member -InputObject $item -MemberType NoteProperty -Name "RelPath" `
        -Value ($item.ScriptPath | Resolve-Path -Relative)
    $Link = "https://github.com/PowerShell/PSScriptAnalyzer/blob/master/docs/Rules/" `
            + $item.RuleName.Substring(2) + ".md"
    Add-Member -InputObject $item -MemberType NoteProperty -Name "Link" `
        -Value $Link
}

if ($null -ne $FilteredResults)
{
    # List all violations
    $FilteredResults | Sort-Object RelPath, Line | Format-Table `
        -Property Severity, RelPath, Line, Column, RuleName, Link `
        -AutoSize -Wrap

    $SeverityValues = [Enum]::GetNames("Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticSeverity")

    # Calculate severity statistics
    $SeverityStats = $SeverityValues | ForEach-Object {
        $ourObject = New-Object -TypeName psobject;
        $ourObject | Add-Member -MemberType NoteProperty -Name "Severity" -Value $_;
        $ourObject | Add-Member -MemberType NoteProperty -Name "Count" -Value (
        $FilteredResults | Where-Object -Property Severity -EQ -Value $_ | Measure-Object
        ).Count;
        $ourObject
    }

    # Print severity stats
    $SeverityStats | Format-Table

    $NumFailures = ($FilteredResults).Count

    # Since there was at least one failure, get mad now
    throw "ScriptAnalyzer failed with $($NumFailures) violations"
}
