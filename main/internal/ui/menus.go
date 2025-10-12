package ui

import (
	"bufio"
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
)

func (a *App) showLanguageMenu() {
	fmt.Println(ColorPrimary.Render("🌍 Select Language"))
	fmt.Println("──────────────────────────────────────────────────────────────────")
	fmt.Println()

	// Get sorted language keys for consistent ordering
	var languages []string
	for lang := range config.Languages {
		languages = append(languages, lang)
	}
	sort.Strings(languages)

	for i, lang := range languages {
		language := config.Languages[lang]
		fmt.Printf("   %s%d.%s %s\n", ColorText, i+1, ColorReset, language.Display)
	}
	fmt.Println()
}

func (a *App) showLevelMenu() {
	fmt.Println(ColorPrimary.Render("📊 Select Difficulty Level"))
	fmt.Println("──────────────────────────────────────────────────────────────────")
	fmt.Println()

	// Get sorted level keys for consistent ordering
	var levels []string
	for level := range config.Levels {
		levels = append(levels, level)
	}
	sort.Strings(levels)

	for i, level := range levels {
		levelInfo := config.Levels[level]
		displayLevel := strings.Title(level)
		fmt.Printf("   %s%d.%s %s (%s)\n", ColorText, i+1, ColorReset, displayLevel, levelInfo.Description)
	}
	fmt.Println()
}

func (a *App) showMainMenu() {
	a.printHeader()
	fmt.Println(ColorPrimary.Render("🎯 Main Menu"))
	fmt.Println("══════════════════════════════════════════════════════════════════")
	fmt.Println()
	fmt.Printf("   %s1. 🆕 New Learning Session%s\n", ColorSuccess, ColorReset)
	fmt.Printf("   %s2. 🌍 Change Language%s\n", ColorInfo, ColorReset)
	fmt.Printf("   %s3. 📊 Change Level%s\n", ColorWarning, ColorReset)
	fmt.Printf("   %s4. ⚙️ Settings%s\n", ColorText, ColorReset)
	fmt.Printf("   %s5. 🚪 Exit%s\n", ColorError, ColorReset)
	fmt.Println()
}

func (a *App) selectLanguage() error {
	a.printHeader()
	a.showLanguageMenu()

	choice, quit := a.getUserChoice("Choose language (1-3): ", 1, 3)
	if quit {
		return nil
	}

	// Map choice to language
	languages := []string{"russian", "urdu", "english"}
	selectedLang := languages[choice-1]

	a.currentConfig.Language = selectedLang
	if err := a.configManager.Save(a.currentConfig); err != nil {
		return err
	}

	language := config.Languages[selectedLang]
	a.printSuccess("Language set to: " + language.Display)
	return nil
}

func (a *App) selectLevel() error {
	a.printHeader()
	a.showLevelMenu()

	choice, quit := a.getUserChoice("Choose level (1-3): ", 1, 3)
	if quit {
		return nil
	}

	// Map choice to level
	levels := []string{"beginner", "intermediate", "advanced"}
	selectedLevel := levels[choice-1]

	a.currentConfig.Level = selectedLevel
	if err := a.configManager.Save(a.currentConfig); err != nil {
		return err
	}

	a.printSuccess("Level set to: " + selectedLevel)
	return nil
}

func (a *App) getTopic() (string, error) {
	a.printHeader()
	fmt.Println(ColorPrimary.Render("📝 Enter Story Topic"))
	fmt.Println("──────────────────────────────────────────────────────────────────")
	fmt.Println(ColorText.Render("Examples: technology, travel, food, sports, animals"))
	fmt.Println()

	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Print(ColorInfo.Render("Topic: "))
		topic, _ := reader.ReadString('\n')
		topic = strings.TrimSpace(topic)

		if topic != "" {
			return topic, nil
		}

		fmt.Println(ColorError.Render("Please enter a topic"))
	}
}
