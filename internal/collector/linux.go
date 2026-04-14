package collector

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
)

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

// CollectLinuxFSMetrics enumera filesystems montados y calcula total/used/%uso.
func CollectLinuxFSMetrics(opts CollectOptions) ([]FileSystemMetric, error) {
	f, err := os.Open("/proc/self/mountinfo")
	if err != nil {
		return nil, fmt.Errorf("open mountinfo: %w", err)
	}
	defer f.Close()

	s := bufio.NewScanner(f)
	seen := map[string]struct{}{}
	metrics := make([]FileSystemMetric, 0, 32)

	for s.Scan() {
		line := s.Text()
		fields := strings.Fields(line)
		if len(fields) < 10 {
			continue
		}

		sep := -1
		for i := 6; i < len(fields); i++ {
			if fields[i] == "-" {
				sep = i
				break
			}
		}
		if sep == -1 || sep+2 >= len(fields) {
			continue
		}

		mountPoint := decodeMountEscapes(fields[4])
		fsType := fields[sep+1]
		fsName := decodeMountEscapes(fields[sep+2])
		if shouldSkipMount(fsType, mountPoint, opts) {
			continue
		}

		if _, ok := seen[mountPoint]; ok {
			continue
		}
		seen[mountPoint] = struct{}{}

		stat := syscall.Statfs_t{}
		if err := syscall.Statfs(mountPoint, &stat); err != nil {
			continue
		}

		blockSize := uint64(stat.Bsize)
		total := stat.Blocks * blockSize
		used := (stat.Blocks - stat.Bfree) * blockSize

		var usedPct float64
		if total > 0 {
			usedPct = (float64(used) / float64(total)) * 100.0
		}

		metrics = append(metrics, FileSystemMetric{
			MountPoint: mountPoint,
			FSName:     fsName,
			FSType:     fsType,
			TotalBytes: total,
			UsedBytes:  used,
			UsedPct:    usedPct,
		})
	}

	if err := s.Err(); err != nil {
		return nil, fmt.Errorf("scan mountinfo: %w", err)
	}

	return metrics, nil
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
}

var pseudoMountPrefixes = []string{
	"/proc",
	"/sys",
	"/dev",
}

func decodeMountEscapes(s string) string {
	repl := strings.NewReplacer(
		`\\040`, " ",
		`\\011`, "\t",
		`\\012`, "\n",
		`\\134`, `\\`,
	)

	if strings.IndexByte(s, '\\') == -1 {
		return s
	}

	out := repl.Replace(s)
	return decodeOctalEscapes(out)
}

func decodeOctalEscapes(in string) string {
	if strings.IndexByte(in, '\\') == -1 {
		return in
	}

	b := make([]byte, 0, len(in))
	for i := 0; i < len(in); i++ {
		if in[i] == '\\' && i+3 < len(in) {
			oct := in[i+1 : i+4]
			if isOctal(oct) {
				v, _ := strconv.ParseUint(oct, 8, 8)
				b = append(b, byte(v))
				i += 3
				continue
			}
		}
		b = append(b, in[i])
	}
	return string(b)
}

func isOctal(s string) bool {
	if len(s) != 3 {
		return false
	}
	for i := 0; i < 3; i++ {
		if s[i] < '0' || s[i] > '7' {
			return false
		}
	}
	return true
}
