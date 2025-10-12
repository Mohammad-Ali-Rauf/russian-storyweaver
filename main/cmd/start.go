package cmd

import (
	"fmt"

	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/ui"
	"github.com/spf13/cobra"
)

var startCmd = &cobra.Command{
	Use:   "start",
	Short: "Start an interactive learning session",
	Long: `Start an interactive language learning session.

This launches the full interactive terminal UI where you can:
• Generate AI-powered stories in your target language
• Practice with vocabulary and exercises  
• Change settings and track progress`,
	Run: func(cmd *cobra.Command, args []string) {
		app := ui.NewApp(cfgManager)
		if err := app.Run(); err != nil {
			fmt.Printf("Error: %v\n", err)
		}
	},
}

func init() {
	rootCmd.AddCommand(startCmd)
}
