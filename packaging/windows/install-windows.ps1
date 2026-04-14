param(
  [string]$InstallDir = "$env:ProgramData\\linuxfsagent",
  [string]$TaskName = "linuxfsagent"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (!(Test-Path $InstallDir)) {
  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

Copy-Item -Path (Join-Path $scriptDir "linuxfsagent.exe") -Destination $InstallDir -Force
Copy-Item -Path (Join-Path $scriptDir "run-windows.ps1") -Destination $InstallDir -Force
if (Test-Path (Join-Path $scriptDir ".env.example")) {
  Copy-Item -Path (Join-Path $scriptDir ".env.example") -Destination $InstallDir -Force
}
if ((Test-Path (Join-Path $scriptDir ".env")) -and !(Test-Path (Join-Path $InstallDir ".env"))) {
  Copy-Item -Path (Join-Path $scriptDir ".env") -Destination $InstallDir -Force
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\\run-windows.ps1`" --interval 60s --output stdout"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName

Write-Host "Installed task '$TaskName'"
Write-Host "InstallDir: $InstallDir"
Write-Host "Check status: Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo"
