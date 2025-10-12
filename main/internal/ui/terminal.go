package ui

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
)

func (a *App) printHeader() {
	fmt.Print("\033[2J\033[H") // Clear screen and move cursor to top
	fmt.Println(ColorPrimary.Render("╔══════════════════════════════════════════════════════════════════╗"))
	fmt.Println(ColorPrimary.Render("║                 " + ColorText.Render("Polyglot AI Storyteller") + ColorPrimary.Render(" v") + config.Version + "           ║"))
	fmt.Println(ColorPrimary.Render("║               Cloud-Powered Language Learning                   ║"))
	fmt.Println(ColorPrimary.Render("╚══════════════════════════════════════════════════════════════════╝"))
	fmt.Println()
}

func (a *App) printStatus(emoji, message string) {
	fmt.Println(ColorInfo.Render(emoji + " " + message))
}

func (a *App) printSuccess(message string) {
	fmt.Println(ColorSuccess.Render("✅ " + message))
}

func (a *App) printError(message string) {
	fmt.Fprintln(os.Stderr, ColorError.Render("❌ "+message))
}

func (a *App) printWarning(message string) {
	fmt.Println(ColorWarning.Render("⚠️ " + message))
}

func (a *App) getUserChoice(prompt string, min, max int) (int, bool) {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Print(ColorInfo.Render(prompt))
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		if input == "q" || input == "quit" {
			return 0, true
		}

		choice, err := strconv.Atoi(input)
		if err == nil && choice >= min && choice <= max {
			return choice, false
		}

		fmt.Println(ColorError.Render("Please enter a number between " + strconv.Itoa(min) + " and " + strconv.Itoa(max)))
	}
}

func (a *App) waitForInput() {
	fmt.Println()
	fmt.Print(ColorInfo.Render("Press any key to continue..."))
	bufio.NewReader(os.Stdin).ReadByte()
}
