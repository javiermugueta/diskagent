Build a Go project called `diskagent` with a binary `linuxfsagent` that collects filesystem/disk usage metrics on Linux, macOS, and Windows, and outputs to OCI Monitoring and/or stdout.

## Core behavior
- Per filesystem/drive collect:
  - total bytes
  - used bytes
  - used percent (`used/total*100`)
- Output modes via `--output`:
  - `stdout`
  - `oci_metrics`
  - `both` (default)
- Execution modes:
  - `--once`
  - periodic loop with `--interval` (default `60s`)
- Optional `--include-pseudo-fs`; otherwise exclude pseudo/virtual fs by default.
- Graceful shutdown on signals.

## OS-specific collection
- Linux: parse `/proc/self/mountinfo` + `statfs`.
- macOS: `getfsstat`.
- Windows: logical drive APIs + free/total space APIs.

## OCI publishing
Use OCI Go SDK and publish these metrics:
- `filesystem_total_bytes`
- `filesystem_used_bytes`
- `filesystem_usage_percent`

Dimensions:
- `mount_point`
- `fs_type`
- `fs_name`

OCI env vars:
- `ORACLE_METRICS_NAMESPACE` (required when output includes OCI)
- `ORACLE_COMPARTMENT_OCID` (required when output includes OCI)
- `ORACLE_RESOURCE_GROUP` (optional)
- `ORACLE_AUTH_MODE` (`config` default or `instance_principal`)

## Interactive setup
Add subcommand:
- `linuxfsagent setup`

It must:
- Prompt for output mode (`stdout|oci_metrics|both`)
- If OCI output selected, prompt for OCI vars and validate basic compartment OCID format.
- Persist `.env` by platform:
  - Linux: `/opt/linuxfsagent/.env`
  - macOS: `/usr/local/etc/linuxfsagent/.env`
  - Windows: `C:\ProgramData\linuxfsagent\.env`
- Support:
  - `--env-file <path>`
  - `--no-restart`
- Try to update/restart runtime:
  - Linux: `systemctl daemon-reload && systemctl restart linuxfsagent`
  - macOS: `launchctl unload/load` daemon plist
  - Windows: restart scheduled task with `schtasks`

## Packaging scripts
Create scripts to produce release artifacts:

- `scripts/package_linux.sh`:
  - `linuxfsagent-<version>-linux-amd64.tar.gz`
  - `linuxfsagent-<version>-linux-arm64.tar.gz`
  - include bin, `.env.example`, `run-linuxfsagent.sh`, `install-systemd.sh`, `linuxfsagent.service`

- `scripts/package_rpm.sh <version> <amd64|arm64>` with spec template in `packaging/rpm/linuxfsagent.spec.in`

- `scripts/package_macos.sh`:
  - `linuxfsagent-<version>-darwin-amd64.tar.gz`
  - `linuxfsagent-<version>-darwin-arm64.tar.gz`

- `scripts/package_macos_pkg.sh <version>` (must run on macOS):
  - build universal binary
  - output `linuxfsagent-<version>-macos-universal.pkg`
  - install:
    - `/usr/local/bin/linuxfsagent`
    - `/usr/local/etc/linuxfsagent/.env.example`
    - `/Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist`
  - include postinstall script that loads daemon

- `scripts/package_windows.sh`:
  - `linuxfsagent-<version>-windows-amd64.zip`
  - `linuxfsagent-<version>-windows-arm64.zip`
  - include:
    - `linuxfsagent.exe`
    - `.env.example`
    - `run-windows.ps1`
    - `install-windows.ps1`
    - `uninstall-windows.ps1`

- `scripts/release_artifacts.sh <tag>`:
  - call package scripts
  - generate `dist/checksums.txt` (sha256)

## Installers/service files
Create:
- `install.sh` for Linux endpoint install from GitHub Releases (`--version`, `--repo`), checksum validation, then run `install-systemd.sh`
- Linux service files/scripts:
  - `packaging/linuxfsagent.service` (run as `opc`)
  - `packaging/install-systemd.sh`
  - `packaging/run-linuxfsagent.sh`
- macOS launchd files:
  - `packaging/macos/com.javiermugueta.linuxfsagent.plist`
  - `packaging/macos/scripts/postinstall`
- Windows scripts:
  - `packaging/windows/run-windows.ps1`
  - `packaging/windows/install-windows.ps1` (register startup scheduled task as SYSTEM)
  - `packaging/windows/uninstall-windows.ps1`

## GitHub Actions release
Create `.github/workflows/release.yml`:
- Trigger on tag `v*`
- Ubuntu job: build Linux/macOS/windows tar/zip, RPM, checksums, upload release assets
- macOS job: build/upload `.pkg`
- Release assets should include:
  - linux tar.gz (amd64/arm64)
  - darwin tar.gz (amd64/arm64)
  - windows zip (amd64/arm64)
  - rpm x86_64
  - macos universal pkg
  - checksums.txt
  - install.sh

## Code structure
Use this layout:

- `cmd/linuxfsagent/main.go`
- `cmd/linuxfsagent/setup.go`
- `internal/collector/common.go`
- `internal/collector/linux.go`
- `internal/collector/darwin.go`
- `internal/collector/windows.go`
- `internal/publisher/oci.go`
- packaging/scripts/workflow/readme files above
- `go.mod`, `README.md`

## README requirements
Document clearly:
- quick install per OS
- OCI variable requirements and persistence model
- interactive setup usage
- verify commands per OS
- uninstall per OS
- build/release steps

## Validation
- Ensure `go test ./...` passes
- ensure cross-compile sanity for windows (`GOOS=windows GOARCH=amd64 go test ./...`)
