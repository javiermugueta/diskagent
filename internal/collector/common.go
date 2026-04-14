package collector

import "strings"

// FileSystemMetric contiene datos de uso para un mountpoint.
type FileSystemMetric struct {
	MountPoint string
	FSName     string
	FSType     string
	TotalBytes uint64
	UsedBytes  uint64
	UsedPct    float64
}

// CollectOptions controla el comportamiento de colección.
type CollectOptions struct {
	ExcludePseudoFS bool
}

func shouldSkipMount(fsType, mountPoint string, opts CollectOptions) bool {
	if !opts.ExcludePseudoFS {
		return false
	}

	if _, ok := pseudoFSTypes[fsType]; ok {
		return true
	}
	for _, p := range pseudoMountPrefixes {
		if mountPoint == p || strings.HasPrefix(mountPoint, p+"/") {
			return true
		}
	}
	return false
}

var pseudoFSTypes = map[string]struct{}{
	// Linux
	"autofs":      {},
	"bpf":         {},
	"binfmt_misc": {},
	"cgroup":      {},
	"cgroup2":     {},
	"configfs":    {},
	"debugfs":     {},
	"devpts":      {},
	"devtmpfs":    {},
	"fusectl":     {},
	"hugetlbfs":   {},
	"mqueue":      {},
	"nsfs":        {},
	"overlay":     {},
	"proc":        {},
	"pstore":      {},
	"ramfs":       {},
	"rpc_pipefs":  {},
	"securityfs":  {},
	"squashfs":    {},
	"sysfs":       {},
	"tmpfs":       {},
	"tracefs":     {},
	// macOS
	"devfs": {},
	"fdesc": {},
	"volfs": {},
}

var pseudoMountPrefixes = []string{
	"/proc",
	"/sys",
	"/dev",
}
