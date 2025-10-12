package cmd

import (
	"fmt"
	"os"

	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
	"github.com/spf13/cobra"
)

var cfgManager *config.Manager

var rootCmd = &cobra.Command{
	Use:   "polyglot",
	Short: "Polyglot AI Storyteller - Cloud-Powered Language Learning",
	Long: `🌍 Polyglot AI Storyteller - Cloud-Powered Language Learning

Generate engaging stories in multiple languages with AI-powered 
language learning exercises. Perfect for Russian, Urdu, and English learners.`,
	Version: config.Version,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		// Initialize config manager for all commands
		var err error
		cfgManager, err = config.NewManager()
		if err != nil {
			fmt.Printf("Error initializing config: %v\n", err)
			os.Exit(1)
		}
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.SetVersionTemplate("Polyglot AI Storyteller {{.Version}}\n")
}
