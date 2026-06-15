//go:build !windows

package main

import (
	"os/exec"
	"syscall"
)

// detach configures cmd to run in its own session, detached from the
// current terminal, so it survives after the parent process exits.
func detach(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
}
