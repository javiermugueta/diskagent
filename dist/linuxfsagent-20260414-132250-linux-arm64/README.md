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
