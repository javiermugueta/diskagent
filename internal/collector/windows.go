//go:build windows

package collector

import (
	"fmt"
	"strings"
	"syscall"
	"unsafe"
)

const (
	driveUnknown   = 0
	driveNoRootDir = 1
	driveRemovable = 2
	driveFixed     = 3
	driveRemote    = 4
	driveCDROM     = 5
	driveRAMDisk   = 6
)

var (
	kernel32                    = syscall.NewLazyDLL("kernel32.dll")
	procGetLogicalDriveStringsW = kernel32.NewProc("GetLogicalDriveStringsW")
	procGetDriveTypeW           = kernel32.NewProc("GetDriveTypeW")
	procGetDiskFreeSpaceExW     = kernel32.NewProc("GetDiskFreeSpaceExW")
)

// CollectFSMetrics enumera unidades montadas en Windows y calcula total/used/%uso.
func CollectFSMetrics(opts CollectOptions) ([]FileSystemMetric, error) {
	drives, err := getLogicalDrives()
	if err != nil {
		return nil, err
	}

	metrics := make([]FileSystemMetric, 0, len(drives))
	for _, drive := range drives {
		driveType, err := getDriveType(drive)
		if err != nil {
			continue
		}
		if driveType == driveUnknown || driveType == driveNoRootDir {
			continue
		}

		freeBytes, totalBytes, err := getDiskFreeSpaceEx(drive)
		if err != nil || totalBytes == 0 {
			continue
		}

		used := totalBytes - freeBytes
		usedPct := (float64(used) / float64(totalBytes)) * 100.0

		mountPoint := strings.TrimSuffix(drive, "\\")
		if mountPoint == "" {
			mountPoint = drive
		}
		fsType := driveTypeLabel(driveType)
		if shouldSkipMount(fsType, mountPoint, opts) {
			continue
		}

		metrics = append(metrics, FileSystemMetric{
			MountPoint: mountPoint,
			FSName:     drive,
			FSType:     fsType,
			TotalBytes: totalBytes,
			UsedBytes:  used,
			UsedPct:    usedPct,
		})
	}

	return metrics, nil
}

func getLogicalDrives() ([]string, error) {
	sz, _, callErr := procGetLogicalDriveStringsW.Call(0, 0)
	if sz == 0 {
		return nil, fmt.Errorf("GetLogicalDriveStringsW(size): %w", callErr)
	}

	buf := make([]uint16, sz)
	r, _, callErr := procGetLogicalDriveStringsW.Call(sz, uintptr(unsafe.Pointer(&buf[0])))
	if r == 0 {
		return nil, fmt.Errorf("GetLogicalDriveStringsW(data): %w", callErr)
	}

	result := make([]string, 0, 8)
	start := 0
	for i := 0; i < len(buf); i++ {
		if buf[i] != 0 {
			continue
		}
		if i == start {
			break
		}
		drive := syscall.UTF16ToString(buf[start:i])
		if drive != "" {
			result = append(result, drive)
		}
		start = i + 1
	}
	return result, nil
}

func getDriveType(root string) (uint32, error) {
	p, err := syscall.UTF16PtrFromString(root)
	if err != nil {
		return 0, err
	}
	r, _, callErr := procGetDriveTypeW.Call(uintptr(unsafe.Pointer(p)))
	if r == 0 {
		return 0, fmt.Errorf("GetDriveTypeW(%s): %w", root, callErr)
	}
	return uint32(r), nil
}

func getDiskFreeSpaceEx(root string) (freeBytes uint64, totalBytes uint64, err error) {
	p, err := syscall.UTF16PtrFromString(root)
	if err != nil {
		return 0, 0, err
	}

	var avail, total, free uint64
	r, _, callErr := procGetDiskFreeSpaceExW.Call(
		uintptr(unsafe.Pointer(p)),
		uintptr(unsafe.Pointer(&avail)),
		uintptr(unsafe.Pointer(&total)),
		uintptr(unsafe.Pointer(&free)),
	)
	if r == 0 {
		return 0, 0, fmt.Errorf("GetDiskFreeSpaceExW(%s): %w", root, callErr)
	}
	return free, total, nil
}

func driveTypeLabel(t uint32) string {
	switch t {
	case driveRemovable:
		return "removable"
	case driveFixed:
		return "fixed"
	case driveRemote:
		return "remote"
	case driveCDROM:
		return "cdrom"
	case driveRAMDisk:
		return "ramdisk"
	default:
		return "unknown"
	}
}
