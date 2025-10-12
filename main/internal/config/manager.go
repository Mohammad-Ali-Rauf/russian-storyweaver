package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

const (
	AppName    = "Polyglot AI Storyteller"
	Version    = "3.0.0"
	AIEndpoint = "http://localhost:11434/api/chat"
	AIModel    = "gpt-oss:120b-cloud"
)

type Manager struct {
	configDir  string
	configFile string
}

func NewManager() (*Manager, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	appDir := filepath.Join(homeDir, ".local", "share", "polyglot-stories")
	configDir := filepath.Join(appDir, "config")
	configFile := filepath.Join(configDir, "app_config.json")

	return &Manager{
		configDir:  configDir,
		configFile: configFile,
	}, nil
}

func (m *Manager) Load() (*Config, error) {
	// Create directories if they don't exist
	if err := os.MkdirAll(m.configDir, 0755); err != nil {
		return nil, err
	}

	// Default config
	defaultConfig := &Config{
		Language:      "russian",
		Level:         "beginner",
		AutoTranslate: true,
		DailyGoal:     1,
	}

	// Check if config file exists
	if _, err := os.Stat(m.configFile); os.IsNotExist(err) {
		// Save default config
		if err := m.Save(defaultConfig); err != nil {
			return nil, err
		}
		return defaultConfig, nil
	}

	// Load existing config
	data, err := os.ReadFile(m.configFile)
	if err != nil {
		return nil, err
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return &config, nil
}

func (m *Manager) Save(config *Config) error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(m.configFile, data, 0644)
}
