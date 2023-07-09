[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
param()

. "$HOME\.dotfiles\common\powershell\Aliases.ps1"

. "$HOME\.dotfiles\private\common\private_profile.ps1"

$env:PYTHONIOENCODING="utf-8"

# \todo reenable this when package resolves python3.12 problem
#Invoke-Expression "$(thefuck --alias)"

Import-Module posh-git

$theme="blue-owl"
if ($IsWindows) {
    $theme_path="$HOME\Documents\WindowsPowerShell\$theme.omp.json"
} else {
    $theme_path="$HOME\.config\powershell\$theme.omp.json"
}

$Env:KOMOREBI_CONFIG_HOME = "$HOME\.config\komorebi"

oh-my-posh init pwsh --config $theme_path | Invoke-Expression
