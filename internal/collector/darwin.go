//go:build darwin

package collector

import "syscall"

// CollectFSMetrics enumera filesystems montados en macOS y calcula total/used/%uso.
func CollectFSMetrics(opts CollectOptions) ([]FileSystemMetric, error) {
	n, err := syscall.Getfsstat(nil, 0)
	if err != nil {
		return nil, err
	}
	if n <= 0 {
		return []FileSystemMetric{}, nil
	}

	stats := make([]syscall.Statfs_t, n)
	n, err = syscall.Getfsstat(stats, 0)
	if err != nil {
		return nil, err
	}

	metrics := make([]FileSystemMetric, 0, n)
	for i := 0; i < n; i++ {
		st := stats[i]
		mountPoint := cStringFromBytes(st.Mntonname[:])
		fsType := cStringFromBytes(st.Fstypename[:])
		fsName := cStringFromBytes(st.Mntfromname[:])
		if shouldSkipMount(fsType, mountPoint, opts) {
			continue
		}

		blockSize := uint64(st.Bsize)
		total := st.Blocks * blockSize
		used := (st.Blocks - st.Bfree) * blockSize

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

	return metrics, nil
}

func cStringFromBytes(b []int8) string {
	out := make([]byte, 0, len(b))
	for _, c := range b {
		if c == 0 {
			break
		}
		out = append(out, byte(c))
	}
	return string(out)
}
