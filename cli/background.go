package main

import (
	"os"
	"os/exec"
)

// spawnBackground re-executes the current binary with the resolved content
// piped via stdin, detached from the current process group, and returns
// immediately without waiting for it to finish. Any error is silently
// dropped: background mode is best-effort and must not block the shell.
//
// Content is written to the pipe before Start returns, so the write
// completes synchronously in this process (it fits well within the OS pipe
// buffer given the 32768-character content limit) and the child can read it
// even after the parent exits.
func spawnBackground(content, tokenFlag, urlFlag string) {
	exe, err := os.Executable()
	if err != nil {
		return
	}

	// Quiet by default: there is no terminal to show output to.
	args := []string{"-q"}
	if tokenFlag != "" {
		args = append(args, "-t", tokenFlag)
	}
	if urlFlag != "" {
		args = append(args, "-u", urlFlag)
	}

	r, w, err := os.Pipe()
	if err != nil {
		return
	}

	cmd := exec.Command(exe, args...)
	cmd.Stdin = r
	detach(cmd)

	if err := cmd.Start(); err != nil {
		r.Close()
		w.Close()
		return
	}

	// Write content and close our copies; the child holds its own fds.
	_, _ = w.Write([]byte(content))
	w.Close()
	r.Close()
}
