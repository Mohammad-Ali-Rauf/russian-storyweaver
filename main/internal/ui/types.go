package ui

import (
	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/ai"
	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
	"github.com/charmbracelet/lipgloss"
)

// Colors matching your shell script
var (
	ColorPrimary = lipgloss.NewStyle().Foreground(lipgloss.Color("39"))  // Bright blue
	ColorSuccess = lipgloss.NewStyle().Foreground(lipgloss.Color("82"))  // Green
	ColorWarning = lipgloss.NewStyle().Foreground(lipgloss.Color("214")) // Orange
	ColorError   = lipgloss.NewStyle().Foreground(lipgloss.Color("196")) // Red
	ColorInfo    = lipgloss.NewStyle().Foreground(lipgloss.Color("51"))  // Cyan
	ColorText    = lipgloss.NewStyle().Foreground(lipgloss.Color("255")) // White
	ColorAccent  = lipgloss.NewStyle().Foreground(lipgloss.Color("201")) // Pink
	ColorReset   = lipgloss.NewStyle()
)

type App struct {
	configManager *config.Manager
	aiClient      *ai.Client
	currentConfig *config.Config
}

func NewApp(cfgManager *config.Manager) *App {
	return &App{
		configManager: cfgManager,
		aiClient:      ai.NewClient(),
	}
}
