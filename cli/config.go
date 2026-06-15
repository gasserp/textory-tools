package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

const defaultBaseURL = "https://textory.dev"

// config holds the persisted CLI configuration.
type config struct {
	Token string `json:"token"`
	URL   string `json:"url"`
}

// configPath returns the path to the config file, creating the parent
// directory's lineage information but not the directory itself.
func configPath() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "textory", "config.json"), nil
}

// loadConfig reads the config file, if present. A missing file is not an
// error; it returns a zero-value config.
func loadConfig() (config, error) {
	var cfg config
	path, err := configPath()
	if err != nil {
		return cfg, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return cfg, nil
		}
		return cfg, err
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		return cfg, fmt.Errorf("parse config %s: %w", path, err)
	}
	return cfg, nil
}

// saveConfig writes the config file, creating the parent directory if
// needed. The directory is created with 0700 and the file with 0600.
func saveConfig(cfg config) error {
	path, err := configPath()
	if err != nil {
		return err
	}
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o600)
}
