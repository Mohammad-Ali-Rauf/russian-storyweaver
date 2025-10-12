package config

type Config struct {
	Language      string `json:"language"`
	Level         string `json:"level"`
	AutoTranslate bool   `json:"auto_translate"`
	DailyGoal     int    `json:"daily_goal"`
}

type Language struct {
	Display string
	Code    string
}

type Level struct {
	Code        string
	Description string
}

var Languages = map[string]Language{
	"russian": {"🇷🇺 Russian", "ru"},
	"urdu":    {"🇵🇰 Urdu", "ur"},
	"english": {"🇺🇸 English", "en"},
}

var Levels = map[string]Level{
	"beginner":     {"A1", "Simple vocabulary, basic sentences"},
	"intermediate": {"A2-B1", "Complex sentences, everyday topics"},
	"advanced":     {"B2-C1", "Advanced grammar, technical topics"},
}
