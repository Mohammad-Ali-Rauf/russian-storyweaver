package ui

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
)

func (a *App) Run() error {
	// Setup signal handling
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-signalChan
		fmt.Println(ColorError.Render("\n🛑 Session interrupted"))
		os.Exit(1)
	}()

	// Load configuration
	cfg, err := a.configManager.Load()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}
	a.currentConfig = cfg

	a.printHeader()
	a.printStatus("⚙️", "Initializing "+config.AppName+" v"+config.Version+"...")
	a.printSuccess("Application ready")

	// Main application loop
	for {
		a.showMainMenu()
		choice, quit := a.getUserChoice("Choose option (1-5): ", 1, 5)
		if quit {
			break
		}

		switch choice {
		case 1:
			if err := a.startLearningSession(); err != nil {
				a.printError("Learning session failed: " + err.Error())
			} else {
				a.printSuccess("Learning session completed successfully")
			}
		case 2:
			if err := a.selectLanguage(); err != nil {
				a.printError("Failed to change language: " + err.Error())
			}
		case 3:
			if err := a.selectLevel(); err != nil {
				a.printError("Failed to change level: " + err.Error())
			}
		case 4:
			a.showSettings()
		case 5:
			a.printSuccess("Happy learning! 👋")
			return nil
		}

		if choice != 5 {
			a.waitForInput()
		}
	}

	a.printSuccess("Thank you for learning languages! 🌍")
	return nil
}

func (a *App) startLearningSession() error {
	topic, err := a.getTopic()
	if err != nil {
		return err
	}

	a.printStatus("🚀", "Starting "+a.currentConfig.Level+" "+a.currentConfig.Language+" session: "+topic)

	story, err := a.aiClient.GenerateStory(a.currentConfig.Language, a.currentConfig.Level, topic)
	if err != nil {
		return fmt.Errorf("failed to generate story content: %w", err)
	}

	return a.displayStory(story, a.currentConfig.Language, a.currentConfig.Level, topic)
}

func (a *App) showSettings() {
	a.printHeader()
	fmt.Println(ColorPrimary.Render("⚙️ Settings"))
	fmt.Println("══════════════════════════════════════════════════════════════════")
	fmt.Println()

	langInfo := config.Languages[a.currentConfig.Language]

	fmt.Printf("🌍 %sCurrent Language:%s %s%s%s\n", ColorText, ColorReset, ColorAccent, langInfo.Display, ColorReset)
	fmt.Printf("📊 %sCurrent Level:%s %s%s%s\n", ColorText, ColorReset, ColorAccent, a.currentConfig.Level, ColorReset)
	fmt.Printf("🔤 %sAuto-translate:%s %s%v%s\n", ColorText, ColorReset, ColorAccent, a.currentConfig.AutoTranslate, ColorReset)
	fmt.Printf("🎯 %sDaily Goal:%s %s%d story/day%s\n", ColorText, ColorReset, ColorAccent, a.currentConfig.DailyGoal, ColorReset)

	a.waitForInput()
}
