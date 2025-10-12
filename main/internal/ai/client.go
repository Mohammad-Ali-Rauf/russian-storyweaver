package ai

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Client struct {
	endpoint string
	model    string
	timeout  time.Duration
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type Request struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
	Stream   bool      `json:"stream"`
}

type Response struct {
	Message struct {
		Content string `json:"content"`
	} `json:"message"`
}

type StoryResponse struct {
	StoryText   string       `json:"story_text"`
	Translation string       `json:"translation"`
	Vocabulary  []Vocabulary `json:"vocabulary"`
	Exercises   []Exercise   `json:"exercises"`
}

type Vocabulary struct {
	Word        string `json:"word"`
	Translation string `json:"translation"`
	Example     string `json:"example"`
}

type Exercise struct {
	Type     string   `json:"type"`
	Question string   `json:"question"`
	Answer   string   `json:"answer"`
	Options  []string `json:"options"`
}

func NewClient() *Client {
	return &Client{
		endpoint: "http://localhost:11434/api/chat",
		model:    "gpt-oss:120b-cloud",
		timeout:  90 * time.Second,
	}
}

func (c *Client) GenerateStory(language, level, topic string) (*StoryResponse, error) {
	prompt := fmt.Sprintf(`Create an engaging %s story for %s language learners about %s. 
Provide the response as valid JSON with these exact fields:
- story_text: the story in %s
- translation: English translation
- vocabulary: array of objects with word, translation, example
- exercises: array of objects with type, question, answer, options

Make sure the JSON is valid and properly formatted. Return ONLY the JSON without any additional text or markdown code blocks.`, language, level, topic, language)

	// First try with AI
	aiResponse, err := c.callAI(prompt)
	if err == nil && aiResponse != "" {
		var story StoryResponse
		if err := json.Unmarshal([]byte(aiResponse), &story); err == nil {
			return &story, nil
		}
	}

	// Fallback story
	return &StoryResponse{
		StoryText:   fmt.Sprintf("Welcome to your %s lesson about %s. This is a sample story for learning.", language, topic),
		Translation: "Welcome to your language lesson. This is a sample story for learning.",
		Vocabulary: []Vocabulary{
			{Word: "welcome", Translation: "greeting", Example: "Welcome to the lesson."},
		},
		Exercises: []Exercise{
			{Type: "multiple_choice", Question: "What is this story about?", Answer: "learning", Options: []string{"learning", "working", "playing"}},
		},
	}, nil
}

func (c *Client) callAI(prompt string) (string, error) {
	request := Request{
		Model: c.model,
		Messages: []Message{
			{Role: "user", Content: prompt},
		},
		Stream: false,
	}

	jsonData, err := json.Marshal(request)
	if err != nil {
		return "", err
	}

	client := &http.Client{Timeout: c.timeout}
	resp, err := client.Post(c.endpoint, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var aiResp Response
	if err := json.Unmarshal(body, &aiResp); err != nil {
		return "", err
	}

	return aiResp.Message.Content, nil
}
