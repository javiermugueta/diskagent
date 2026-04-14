param(
  [string]$InstallDir = "$env:ProgramData\\linuxfsagent",
  [string]$TaskName = "linuxfsagent",
  [switch]$KeepFiles
)

$ErrorActionPreference = "Stop"

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Host "Removed scheduled task '$TaskName'"
}

if (-not $KeepFiles -and (Test-Path $InstallDir)) {
  Remove-Item -Path $InstallDir -Recurse -Force
  Write-Host "Removed $InstallDir"
}
