[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
param()

. "$HOME\.dotfiles\common\powershell\Aliases.ps1"

. "$HOME\.dotfiles\private\common\private_profile.ps1"

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
