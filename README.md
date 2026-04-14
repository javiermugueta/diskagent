# diskagent (Linux/macOS/Windows)

Go agent for Linux, macOS, and Windows that:
- Detects mounted filesystems using native OS APIs (Linux: `/proc/self/mountinfo`, macOS: `getfsstat`, Windows: logical drives API)
- Calculates per mount point:
  - `filesystem_total_bytes`
  - `filesystem_used_bytes`
  - `filesystem_usage_percent` (`used/total * 100`)
- Excludes pseudo/virtual filesystems by default (for example: `proc`, `sysfs`, `tmpfs`, `cgroup`, `overlay`)
- Publishes metrics to Oracle Cloud Infrastructure Monitoring

## Installation (Quick Start)

Use release assets from GitHub:
- https://github.com/javiermugueta/diskagent/releases

### Linux

Option A: install via `install.sh`

```bash
curl -fsSL https://raw.githubusercontent.com/javiermugueta/diskagent/main/install.sh | sudo bash
```

If your proxy blocks `raw.githubusercontent.com`:

```bash
curl -L https://github.com/javiermugueta/diskagent/releases/download/v0.1.7/install.sh | sudo bash -- --version v0.1.7
```

Option B: install from `.tar.gz`

```bash
tar -xzf linuxfsagent-v0.1.7-linux-amd64.tar.gz
cd linuxfsagent-v0.1.7-linux-amd64
cp .env.example .env   # if OCI output will be used
sudo ./install-systemd.sh
```

Option C: install from `RPM` (Oracle Linux / RHEL)

```bash
# disable problematic external repos if needed
sudo dnf --disablerepo=docker-ce-stable localinstall -y ./linuxfsagent-v0.1.7-1.x86_64.rpm
```

### macOS

Option A: install from `.pkg` (recommended)

```bash
sudo installer -pkg ./linuxfsagent-v0.1.7-macos-universal.pkg -target /
```

Option B: run from `.tar.gz`

```bash
tar -xzf linuxfsagent-v0.1.7-darwin-arm64.tar.gz
cd linuxfsagent-v0.1.7-darwin-arm64
./linuxfsagent --once --output stdout
```

### Windows

Run in PowerShell as Administrator:

```powershell
Expand-Archive .\linuxfsagent-v0.1.7-windows-amd64.zip -DestinationPath .\out -Force
cd .\out\linuxfsagent-v0.1.7-windows-amd64
Copy-Item .env.example .env
.\install-windows.ps1
```

This creates a scheduled task (`linuxfsagent`) that starts at boot as `SYSTEM`.
Default install directory:

- `C:\ProgramData\linuxfsagent`

## Configuration

Environment variables are required only when the agent sends metrics to OCI:
- required for `--output=oci_metrics`
- required for `--output=both`
- not required for `--output=stdout`

Variables:

- `ORACLE_METRICS_NAMESPACE` (required)
- `ORACLE_COMPARTMENT_OCID` (required)
- `ORACLE_RESOURCE_GROUP` (optional)
- `ORACLE_AUTH_MODE` (optional):
  - `config` (default): uses `~/.oci/config`
  - `instance_principal`: uses Instance Principal

### When to set them

- Set them before first run if you want OCI publishing.
- If you run `stdout` only, you can skip them.

### Persistence model

- `export VAR=...` in a shell is temporary (only current session/process tree).
- Service/task config files are persistent across reboots.

### Linux (`systemd`) persistence

Use `/opt/linuxfsagent/.env` (persistent; loaded by `run-linuxfsagent.sh`):

```bash
sudo tee /opt/linuxfsagent/.env >/dev/null <<'EOF'
ORACLE_METRICS_NAMESPACE=your_namespace
ORACLE_COMPARTMENT_OCID=ocid1.compartment...
# optional:
# ORACLE_RESOURCE_GROUP=disk-agent
# ORACLE_AUTH_MODE=instance_principal
EOF
```

Then ensure service output mode uses OCI (`oci_metrics` or `both`) and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart linuxfsagent
```

### macOS (`launchd`) persistence

Default `.pkg` service uses `--output stdout`. For OCI mode, define environment
variables in the LaunchDaemon plist (or wrap execution with a script that exports
them), then reload the daemon.

### Windows (Scheduled Task) persistence

Use `C:\ProgramData\linuxfsagent\.env` (persistent; loaded by `run-windows.ps1`):

```powershell
@'
ORACLE_METRICS_NAMESPACE=your_namespace
ORACLE_COMPARTMENT_OCID=ocid1.compartment...
# ORACLE_RESOURCE_GROUP=disk-agent
# ORACLE_AUTH_MODE=instance_principal
'@ | Set-Content C:\ProgramData\linuxfsagent\.env
```

Then update task arguments to `--output oci_metrics` or `--output both` if needed,
and restart the scheduled task.

## Runtime Options

```bash
# OCI Monitoring only
go run ./cmd/linuxfsagent --once --output oci_metrics

# Standard output only
go run ./cmd/linuxfsagent --once --output stdout

# Both destinations (default)
go run ./cmd/linuxfsagent --once --output both

# Daemon mode (every 60s)
go run ./cmd/linuxfsagent --interval 60s

# Include pseudo/virtual filesystems
go run ./cmd/linuxfsagent --once --include-pseudo-fs
```

## Verify Installation

### Linux (`systemd`)

```bash
sudo systemctl status linuxfsagent
journalctl -u linuxfsagent -f
```

To change runtime flags, edit:

- `/etc/systemd/system/linuxfsagent.service`

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart linuxfsagent
```

### macOS (`launchd`)

The `.pkg` installs:

- binary: `/usr/local/bin/linuxfsagent`
- sample config: `/usr/local/etc/linuxfsagent/.env.example`
- LaunchDaemon: `/Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist`

Check status/logs:

```bash
sudo launchctl list | grep com.javiermugueta.linuxfsagent
tail -f /var/log/linuxfsagent.log
```

### Windows (Scheduled Task)

```powershell
Get-ScheduledTask -TaskName linuxfsagent | Get-ScheduledTaskInfo
```

## Uninstall

### Linux (installed via `install-systemd.sh`)

```bash
sudo systemctl disable --now linuxfsagent || true
sudo rm -f /etc/systemd/system/linuxfsagent.service
sudo systemctl daemon-reload
sudo rm -rf /opt/linuxfsagent
```

### Linux (installed via RPM)

```bash
sudo dnf remove -y linuxfsagent
```

### macOS (installed via `.pkg`)

```bash
sudo launchctl unload /Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist
sudo rm -f /usr/local/bin/linuxfsagent
sudo rm -rf /usr/local/etc/linuxfsagent
sudo rm -f /var/log/linuxfsagent.log
```

macOS (from `.tar.gz`): remove the extracted folder and any manually copied binaries/scripts.

### Windows

From the extracted package folder:

```powershell
.\uninstall-windows.ps1
```

Keep files but remove scheduled task only:

```powershell
.\uninstall-windows.ps1 -KeepFiles
```

## Build and Packaging (From Source)

```bash
# Linux tar.gz
./scripts/package_linux.sh v0.1.0

# macOS tar.gz
./scripts/package_macos.sh v0.1.0

# macOS universal pkg (must run on macOS)
./scripts/package_macos_pkg.sh v0.1.0

# Windows zip
./scripts/package_windows.sh v0.1.0

# Linux RPM (must run on Linux with rpmbuild)
./scripts/package_rpm.sh v0.1.0 amd64
```

## Release Process

Generate release artifacts + checksums:

```bash
./scripts/release_artifacts.sh v0.1.0
```

Expected artifacts include Linux/macOS/Windows packages, optional RPMs, and `checksums.txt`.

## Metric Dimensions

- `mount_point`
- `fs_type`
- `fs_name`

## Notes

- Used space is calculated as `Blocks - Bfree`, multiplied by `Bsize`.
- Up to 50 datapoints are sent per request to OCI Monitoring.
