# diskagent (Linux/macOS/Windows)

Go agent for Linux, macOS, and Windows that:
- Detects mounted filesystems using native OS APIs (Linux: `/proc/self/mountinfo`, macOS: `getfsstat`, Windows: logical drives API)
- Calculates per mount point:
  - `filesystem_total_bytes`
  - `filesystem_used_bytes`
  - `filesystem_usage_percent` (`used/total * 100`)
- Excludes pseudo/virtual filesystems by default (for example: `proc`, `sysfs`, `tmpfs`, `cgroup`, `overlay`)
- Publishes metrics to Oracle Cloud Infrastructure Monitoring

## Environment Variables

- `ORACLE_METRICS_NAMESPACE` (required if `--output=oci_metrics` or `--output=both`)
- `ORACLE_COMPARTMENT_OCID` (required if `--output=oci_metrics` or `--output=both`)
- `ORACLE_RESOURCE_GROUP` (optional)
- `ORACLE_AUTH_MODE` (optional):
  - `config` (default): uses `~/.oci/config`
  - `instance_principal`: uses Instance Principal

## Run

```bash
go mod tidy
go run ./cmd/linuxfsagent --once
```

Output selector:

```bash
# OCI Monitoring only
go run ./cmd/linuxfsagent --once --output oci_metrics

# Standard output only (stdout)
go run ./cmd/linuxfsagent --once --output stdout

# Both destinations (default)
go run ./cmd/linuxfsagent --once --output both
```

Daemon mode (every 60s by default):

```bash
go run ./cmd/linuxfsagent --interval 60s
```

Include pseudo/virtual filesystems:

```bash
go run ./cmd/linuxfsagent --once --include-pseudo-fs
```

## Linux Packaging

Build Linux packages (`amd64` and `arm64`):

```bash
./scripts/package_linux.sh
```

Optional version argument:

```bash
./scripts/package_linux.sh v0.1.0
```

Output in `dist/`:

- `linuxfsagent-<version>-linux-amd64.tar.gz`
- `linuxfsagent-<version>-linux-arm64.tar.gz`

Linux usage:

```bash
tar -xzf linuxfsagent-<version>-linux-amd64.tar.gz
cd linuxfsagent-<version>-linux-amd64
cp .env.example .env   # if OCI output will be used
./run-linuxfsagent.sh --once --output stdout
```

## macOS Packaging

Build macOS packages (`amd64` and `arm64`):

```bash
./scripts/package_macos.sh v0.1.0
```

Output in `dist/`:

- `linuxfsagent-<version>-darwin-amd64.tar.gz`
- `linuxfsagent-<version>-darwin-arm64.tar.gz`
- `linuxfsagent-<version>-macos-universal.pkg` (with `./scripts/package_macos_pkg.sh <version>`)

macOS usage:

```bash
tar -xzf linuxfsagent-<version>-darwin-arm64.tar.gz
cd linuxfsagent-<version>-darwin-arm64
./linuxfsagent --once --output stdout
```

Installable macOS package (`.pkg`):

```bash
./scripts/package_macos_pkg.sh v0.1.0
sudo installer -pkg dist/linuxfsagent-v0.1.0-macos-universal.pkg -target /
```

The `.pkg` installs:

- binary: `/usr/local/bin/linuxfsagent`
- sample config: `/usr/local/etc/linuxfsagent/.env.example`
- LaunchDaemon: `/Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist`

## Windows Packaging

Build Windows packages (`amd64` and `arm64`):

```bash
./scripts/package_windows.sh v0.1.0
```

Output in `dist/`:

- `linuxfsagent-<version>-windows-amd64.zip`
- `linuxfsagent-<version>-windows-arm64.zip`

Each zip includes:

- `linuxfsagent.exe`
- `run-windows.ps1`
- `install-windows.ps1`
- `uninstall-windows.ps1`
- `.env.example`

Windows installation (PowerShell as Administrator):

```powershell
Expand-Archive .\linuxfsagent-v0.1.0-windows-amd64.zip -DestinationPath .\out -Force
cd .\out\linuxfsagent-v0.1.0-windows-amd64
Copy-Item .env.example .env
.\install-windows.ps1
```

The installer creates a scheduled task (`linuxfsagent`) that starts on boot as `SYSTEM`.
Default install directory:

- `C:\ProgramData\linuxfsagent`

## Release and Endpoint Installation (GitHub)

Generate release artifacts + checksums:

```bash
./scripts/release_artifacts.sh v0.1.0
```

Upload these files to release `v0.1.0` on GitHub:

- `dist/linuxfsagent-v0.1.0-linux-amd64.tar.gz`
- `dist/linuxfsagent-v0.1.0-linux-arm64.tar.gz`
- `dist/linuxfsagent-v0.1.0-darwin-amd64.tar.gz`
- `dist/linuxfsagent-v0.1.0-darwin-arm64.tar.gz`
- `dist/linuxfsagent-v0.1.0-windows-amd64.zip`
- `dist/linuxfsagent-v0.1.0-windows-arm64.zip`
- `dist/linuxfsagent-v0.1.0-macos-universal.pkg`
- `dist/linuxfsagent-v0.1.0-1.x86_64.rpm` (if generated on Linux with `rpmbuild`)
- `dist/linuxfsagent-v0.1.0-1.aarch64.rpm` (optional; depends on build host)
- `dist/checksums.txt`

Direct installation via endpoint:

```bash
curl -fsSL https://raw.githubusercontent.com/javiermugueta/diskagent/v0.1.0/install.sh | sudo bash
```

If your proxy blocks `raw.githubusercontent.com`, use release assets (`github.com`):

```bash
curl -L https://github.com/javiermugueta/diskagent/releases/download/v0.1.0/install.sh | sudo bash -- --version v0.1.0
```

Install latest published release:

```bash
curl -fsSL https://raw.githubusercontent.com/javiermugueta/diskagent/main/install.sh | sudo bash
```

RPM installation (Oracle Linux / RHEL):

```bash
# if you have external repos with TLS issues, disable them in this command
sudo dnf --disablerepo=docker-ce-stable localinstall -y ./linuxfsagent-v0.1.7-1.x86_64.rpm
sudo systemctl status linuxfsagent
journalctl -u linuxfsagent -f
```

Install as `systemd` service (Linux target host):

```bash
sudo ./install-systemd.sh
sudo systemctl status linuxfsagent
journalctl -u linuxfsagent -f
```

The service runs as user/group `opc`, and the installer sets ownership of `/opt/linuxfsagent` to `opc:opc`.

If you need to change flags (for example `--output stdout`), edit:

- `/etc/systemd/system/linuxfsagent.service`

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart linuxfsagent
```

On macOS, if installed via `.pkg`, the `LaunchDaemon` starts automatically and writes logs to:

- `/var/log/linuxfsagent.log`

Useful macOS commands:

```bash
sudo launchctl list | grep com.javiermugueta.linuxfsagent
tail -f /var/log/linuxfsagent.log
```

## Uninstall

Linux (installed via `install-systemd.sh`):

```bash
sudo systemctl disable --now linuxfsagent || true
sudo rm -f /etc/systemd/system/linuxfsagent.service
sudo systemctl daemon-reload
sudo rm -rf /opt/linuxfsagent
```

Linux (installed via RPM):

```bash
sudo dnf remove -y linuxfsagent
```

macOS (installed via `.pkg`):

```bash
sudo launchctl unload /Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist
sudo rm -f /usr/local/bin/linuxfsagent
sudo rm -rf /usr/local/etc/linuxfsagent
sudo rm -f /var/log/linuxfsagent.log
```

macOS (from tar.gz): remove the extracted folder and any manually copied binaries/scripts.

Windows:

```powershell
# from the extracted package folder:
.\uninstall-windows.ps1
```

Useful option:

```powershell
.\uninstall-windows.ps1 -KeepFiles
```

## Metric Dimensions

- `mount_point`
- `fs_type`
- `fs_name`

## Notes

- Used space is calculated as `Blocks - Bfree`, multiplied by `Bsize`.
- Up to 50 datapoints are sent per request to OCI Monitoring.
