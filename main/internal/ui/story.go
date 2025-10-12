package ui

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/ai"
	"github.com/Mohammad-Ali-Rauf/polyglot-storyweaver/internal/config"
)

func (a *App) displayStory(story *ai.StoryResponse, language, level, topic string) error {
	a.printHeader()
	fmt.Println(ColorPrimary.Render("📖 Learning Session"))
	fmt.Println("══════════════════════════════════════════════════════════════════")
	fmt.Println()

	// Get language display name
	langInfo := config.Languages[language]

	fmt.Printf("🌍 %sLanguage:%s %s%s%s\n", ColorText, ColorReset, ColorAccent, langInfo.Display, ColorReset)
	fmt.Printf("📊 %sLevel:%s %s%s%s\n", ColorText, ColorReset, ColorAccent, level, ColorReset)
	fmt.Printf("🎭 %sTopic:%s %s%s%s\n", ColorText, ColorReset, ColorAccent, topic, ColorReset)
	fmt.Println("──────────────────────────────────────────────────────────────────")
	fmt.Println()

	// Display story text
	fmt.Printf("%s📖 Story:%s\n", ColorSuccess, ColorReset)
	fmt.Printf("%s%s%s\n", ColorText, story.StoryText, ColorReset)
	fmt.Println()

	// Display translation
	fmt.Printf("%s🌍 Translation:%s\n", ColorInfo, ColorReset)
	fmt.Printf("%s%s%s\n", ColorText, story.Translation, ColorReset)
	fmt.Println()

	// Display vocabulary
	fmt.Printf("%s📚 Vocabulary:%s\n", ColorWarning, ColorReset)
	for _, vocab := range story.Vocabulary {
		fmt.Printf("   %s• %s - %s%s\n", ColorText, vocab.Word, vocab.Translation, ColorReset)
	}
	fmt.Println()

	// Run exercises
	if err := a.runExercises(story); err != nil {
		return err
	}

	a.printSuccess("Lesson completed! Excellent work! 🎉")
	return nil
}

func (a *App) runExercises(story *ai.StoryResponse) error {
	if len(story.Exercises) == 0 {
		return nil
	}

	fmt.Println(ColorPrimary.Render("💪 Practice Exercises"))
	fmt.Println("──────────────────────────────────────────────────────────────────")

	correctAnswers := 0
	reader := bufio.NewReader(os.Stdin)

	for i, exercise := range story.Exercises {
		fmt.Printf("\n%sExercise %d/%d:%s\n", ColorText, i+1, len(story.Exercises), ColorReset)
		fmt.Printf("%sQ: %s%s\n", ColorText, exercise.Question, ColorReset)

		if exercise.Type == "multiple_choice" && len(exercise.Options) > 0 {
			fmt.Printf("%sOptions:%s\n", ColorInfo, ColorReset)
			for _, option := range exercise.Options {
				fmt.Printf("   %s%s\n", ColorText, option)
			}
		}

		fmt.Println()
		fmt.Print(ColorInfo.Render("Your answer: "))
		userAnswer, _ := reader.ReadString('\n')
		userAnswer = strings.TrimSpace(userAnswer)

		if userAnswer == exercise.Answer {
			fmt.Printf("%s✅ Correct!%s\n", ColorSuccess, ColorReset)
			correctAnswers++
		} else {
			fmt.Printf("%s❌ The answer is: %s%s\n", ColorError, exercise.Answer, ColorReset)
		}
	}

	fmt.Printf("\n%s📊 Score: %d/%d correct%s\n", ColorPrimary, correctAnswers, len(story.Exercises), ColorReset)
	fmt.Println("──────────────────────────────────────────────────────────────────")
	return nil
}
