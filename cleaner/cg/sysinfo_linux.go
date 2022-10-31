//go:build linux

// build +linux

package main

import "golang.org/x/sys/unix"

func sysLoad1mAvg() float64 {
	var info unix.Sysinfo_t
	unix.Sysinfo(&info)

	const si_load_shift = 16
	load := float64(info.Loads[0]) / float64(1<<si_load_shift)

	return load
}
