param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AgentArgs
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$envFile = Join-Path $ScriptDir ".env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    if ($line.StartsWith("#")) { return }
    $parts = $line.Split('=', 2)
    if ($parts.Count -ne 2) { return }
    [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
  }
}

$exe = Join-Path $ScriptDir "linuxfsagent.exe"
if (!(Test-Path $exe)) {
  throw "linuxfsagent.exe not found in $ScriptDir"
}

& $exe @AgentArgs
exit $LASTEXITCODE
