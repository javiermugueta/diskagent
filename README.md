# diskagent (Linux/macOS)

Agente en Go para Linux y macOS que:
- Detecta filesystems montados de forma nativa por SO (Linux: `/proc/self/mountinfo`, macOS: `getfsstat`)
- Calcula por mountpoint:
  - `filesystem_total_bytes`
  - `filesystem_used_bytes`
  - `filesystem_usage_percent` (`used/total * 100`)
- Excluye por defecto filesystems pseudo/virtuales (ej: `proc`, `sysfs`, `tmpfs`, `cgroup`, `overlay`)
- Publica métricas en Oracle Cloud Infrastructure Monitoring

## Variables de entorno

- `ORACLE_METRICS_NAMESPACE` (obligatoria si `--output=oci_metrics` o `--output=both`)
- `ORACLE_COMPARTMENT_OCID` (obligatoria si `--output=oci_metrics` o `--output=both`)
- `ORACLE_RESOURCE_GROUP` (opcional)
- `ORACLE_AUTH_MODE` (opcional):
  - `config` (default): usa `~/.oci/config`
  - `instance_principal`: usa Instance Principal

## Ejecución

```bash
go mod tidy
go run ./cmd/linuxfsagent --once
```

Selector de salida:

```bash
# Solo OCI Monitoring
go run ./cmd/linuxfsagent --once --output oci_metrics

# Solo salida estándar (stdout)
go run ./cmd/linuxfsagent --once --output stdout

# Ambos destinos (default)
go run ./cmd/linuxfsagent --once --output both
```

Modo daemon (cada 60s por defecto):

```bash
go run ./cmd/linuxfsagent --interval 60s
```

Incluir también pseudo/virtuales:

```bash
go run ./cmd/linuxfsagent --once --include-pseudo-fs
```

## Empaquetado para Linux

Genera paquetes listos para copiar a Linux (`amd64` y `arm64`):

```bash
./scripts/package_linux.sh
```

Opcionalmente puedes pasar una versión:

```bash
./scripts/package_linux.sh v0.1.0
```

Salida en `dist/`:

- `linuxfsagent-<version>-linux-amd64.tar.gz`
- `linuxfsagent-<version>-linux-arm64.tar.gz`

Uso en Linux:

```bash
tar -xzf linuxfsagent-<version>-linux-amd64.tar.gz
cd linuxfsagent-<version>-linux-amd64
cp .env.example .env   # si usarás salida OCI
./run-linuxfsagent.sh --once --output stdout
```

## Empaquetado para macOS

Genera paquetes para macOS (`amd64` y `arm64`):

```bash
./scripts/package_macos.sh v0.1.0
```

Salida en `dist/`:

- `linuxfsagent-<version>-darwin-amd64.tar.gz`
- `linuxfsagent-<version>-darwin-arm64.tar.gz`
- `linuxfsagent-<version>-macos-universal.pkg` (con `./scripts/package_macos_pkg.sh <version>`)

Uso en macOS:

```bash
tar -xzf linuxfsagent-<version>-darwin-arm64.tar.gz
cd linuxfsagent-<version>-darwin-arm64
./linuxfsagent --once --output stdout
```

Empaquetado instalable (`.pkg`) en macOS:

```bash
./scripts/package_macos_pkg.sh v0.1.0
sudo installer -pkg dist/linuxfsagent-v0.1.0-macos-universal.pkg -target /
```

El `.pkg` instala:

- binario: `/usr/local/bin/linuxfsagent`
- ejemplo de config: `/usr/local/etc/linuxfsagent/.env.example`
- LaunchDaemon: `/Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist`

## Release e instalación por endpoint (GitHub)

Generar artefactos de release + checksums:

```bash
./scripts/release_artifacts.sh v0.1.0
```

Sube estos archivos al release `v0.1.0` en GitHub:

- `dist/linuxfsagent-v0.1.0-linux-amd64.tar.gz`
- `dist/linuxfsagent-v0.1.0-linux-arm64.tar.gz`
- `dist/linuxfsagent-v0.1.0-darwin-amd64.tar.gz`
- `dist/linuxfsagent-v0.1.0-darwin-arm64.tar.gz`
- `dist/linuxfsagent-v0.1.0-macos-universal.pkg`
- `dist/linuxfsagent-v0.1.0-1.x86_64.rpm` (si se genera en Linux con `rpmbuild`)
- `dist/linuxfsagent-v0.1.0-1.aarch64.rpm` (opcional, depende del host de build)
- `dist/checksums.txt`

Instalación directa desde endpoint:

```bash
curl -fsSL https://raw.githubusercontent.com/javiermugueta/diskagent/v0.1.0/install.sh | sudo bash
```

Si tu proxy bloquea `raw.githubusercontent.com`, usa assets del release (dominio `github.com`):

```bash
curl -L https://github.com/javiermugueta/diskagent/releases/download/v0.1.0/install.sh | sudo bash -- --version v0.1.0
```

Para instalar el último release publicado:

```bash
curl -fsSL https://raw.githubusercontent.com/javiermugueta/diskagent/main/install.sh | sudo bash
```

Instalacion con RPM (Oracle Linux / RHEL):

```bash
# si tienes repos externos con problemas TLS, desactívalos en este comando
sudo dnf --disablerepo=docker-ce-stable localinstall -y ./linuxfsagent-v0.1.6-1.x86_64.rpm
sudo systemctl status linuxfsagent
journalctl -u linuxfsagent -f
```

Instalar como servicio `systemd` (en la máquina Linux destino):

```bash
sudo ./install-systemd.sh
sudo systemctl status linuxfsagent
journalctl -u linuxfsagent -f
```

La unidad se instala para ejecutar como usuario/grupo `opc`, y el instalador asigna propiedad de `/opt/linuxfsagent` a `opc:opc`.

Si necesitas cambiar flags (por ejemplo `--output stdout`), edita:

- `/etc/systemd/system/linuxfsagent.service`

Y recarga:

```bash
sudo systemctl daemon-reload
sudo systemctl restart linuxfsagent
```

En macOS, si instalas con `.pkg`, el `LaunchDaemon` se carga automáticamente y escribe logs en:

- `/var/log/linuxfsagent.log`

Comandos útiles en macOS:

```bash
sudo launchctl list | grep com.javiermugueta.linuxfsagent
tail -f /var/log/linuxfsagent.log
```

## Desinstalación

Linux (instalación por `install-systemd.sh`):

```bash
sudo systemctl disable --now linuxfsagent || true
sudo rm -f /etc/systemd/system/linuxfsagent.service
sudo systemctl daemon-reload
sudo rm -rf /opt/linuxfsagent
```

Linux (instalación por RPM):

```bash
sudo dnf remove -y linuxfsagent
```

macOS (instalación por `.pkg`):

```bash
sudo launchctl unload /Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist
sudo rm -f /usr/local/bin/linuxfsagent
sudo rm -rf /usr/local/etc/linuxfsagent
sudo rm -f /var/log/linuxfsagent.log
```

macOS (uso desde tar.gz): borra la carpeta descomprimida y cualquier script/binario que hayas copiado manualmente.

## Dimensiones enviadas por métrica

- `mount_point`
- `fs_type`
- `fs_name`

## Notas

- El cálculo de usado se hace con `Blocks - Bfree`, multiplicado por `Bsize`.
- Se envían lotes de hasta 50 datapoints por request a OCI Monitoring.
