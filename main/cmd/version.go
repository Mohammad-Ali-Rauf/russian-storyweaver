package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
)

var cfg, err := a.configManager.Load()

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the version number",
	Long:  `Print the current version of Polyglot AI Storyteller`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Polyglot AI Storyteller v%s\n", cfg.Version)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}