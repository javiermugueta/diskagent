# diskagent (Linux)

Agente en Go para Linux que:
- Detecta filesystems montados leyendo `/proc/self/mountinfo`
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

## Release e instalación por endpoint (GitHub)

Generar artefactos de release + checksums:

```bash
./scripts/release_artifacts.sh v0.1.0
```

Sube estos archivos al release `v0.1.0` en GitHub:

- `dist/linuxfsagent-v0.1.0-linux-amd64.tar.gz`
- `dist/linuxfsagent-v0.1.0-linux-arm64.tar.gz`
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
sudo dnf localinstall -y ./linuxfsagent-v0.1.1-1.x86_64.rpm
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

## Dimensiones enviadas por métrica

- `mount_point`
- `fs_type`
- `fs_name`

## Notas

- El cálculo de usado se hace con `Blocks - Bfree`, multiplicado por `Bsize`.
- Se envían lotes de hasta 50 datapoints por request a OCI Monitoring.
