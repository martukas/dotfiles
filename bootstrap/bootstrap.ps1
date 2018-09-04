Write-Host "==============================================================="
Write-Host "============== MGS personal bootstrapper - Win10 =============="
Write-Host "==============================================================="
Write-Host " "
Write-Host "  -- removes OneDrive"
Write-Host "  -- installs esenstials: PowerShell7, Git, Python"
Write-Host "  -- configures ssh and github credentials"
Write-Host "  -- clones the dotfile repository"
Write-Host "  -- installs common programs"
Write-Host " "
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

Write-Host " "

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "Running script in $dir"

Push-Location $dir

Write-Host "[Win10] Remove OneDrive"
winget uninstall Microsoft.OneDrive

Write-Host "[Win10] Set new PowerShell profile root"
New-ItemProperty `
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' `
  Personal -Value "$HOME\Documents" -Type ExpandString -Force

Write-Host "[Win10] Installing modern PowerShell"
winget install -e --id Microsoft.PowerShell

Write-Host "[Win10] Installing Git"
winget install --id Git.Git -e --source winget

#Must install python here, so that we have it available in bash for dotbot
Write-Host "[Win10] Installing Python"
winget install --id Python.Python.3.12 -e --source winget --scope=machine
#Temporary solution until bash profiles are imported
$py_alias = "alias python='winpty python.exe'"
$out_path = "$HOME\.bash_profile"
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($out_path, $py_alias, $Utf8NoBomEncoding)

Start-Process -FilePath "$Env:Programfiles\Git\bin\sh.exe" `
	-ArgumentList "--login","-i","-c",'"./config_ssh.sh start"'

Pop-Location

Write-Host "Bootstrapping complete. You should now restart the machine and run 'install.ps1' from pwsh."
Write-Host " "
Write-Host -NoNewLine 'Press any key to restart machine...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

Restart-Computer -Confirm

