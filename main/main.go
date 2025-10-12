package main

import (
	"fmt"
	"os"

	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/ui"
)

func main() {
	// Initialize configuration
	cfgManager, err := config.NewManager()
	if err != nil {
		fmt.Printf("Error initializing config: %v\n", err)
		os.Exit(1)
	}

	app := ui.NewApp(cfgManager)
	if err := app.Run(); err != nil {
		fmt.Printf("Error running application: %v\n", err)
		os.Exit(1)
	}
}
