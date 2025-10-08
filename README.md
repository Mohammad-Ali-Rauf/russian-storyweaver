# 🎉 Russian AI Storyteller 🇷🇺

[![Bash](https://img.shields.io/badge/Bash-4.0-blue.svg)](https://www.gnu.org/software/bash/)
[![Ollama](https://img.shields.io/badge/Ollama-Required-orange.svg)](https://ollama.com)
[![Python](https://img.shields.io/badge/Python-3.6%2B-yellow.svg)](https://python.org)
[![FFmpeg](https://img.shields.io/badge/FFmpeg-Required-red.svg)](https://ffmpeg.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **AI-Powered Russian Language Learning Assistant** - Generate immersive Russian stories with translations, vocabulary, exercises, and audio narration!

---

## 🚀 Quick Start

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install python3 jq ffmpeg python3-venv

# macOS  
brew install python3 jq ffmpeg
```

### Installation & Run
```bash
# 1. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Pull AI model
ollama pull infidelis/GigaChat-20B-A3B-instruct-v1.5:q4_0

# 3. Download & run
wget -O russian-story.sh https://raw.githubusercontent.com/yourusername/russian-ai-storyteller/main/russian-ai-storyteller.sh
chmod +x russian-story.sh

# Interactive mode (recommended for beginners)
./russian-story.sh

# 🎲 Surprise me! Random story
./russian-story.sh --random
```

---

## 🎮 Quick Menu Reference

### 📊 Levels
| Number | Level | Description |
|--------|-------|-------------|
| **1** | 🟢 Beginner | A1 (150 words) |
| **2** | 🟡 Intermediate | A2-B1 (300 words) |
| **3** | 🔴 Advanced | B2-C1 (500 words) |
| **4** | 🎲 Random | Surprise level |

### 🎭 Topics
| Number | Topic | English |
|--------|-------|---------|
| **1** | 🤝 дружба | Friendship |
| **2** | ✈️ путешествие | Travel |
| **3** | 👨‍👩‍👧‍👦 семья | Family |
| **4** | 💖 любовь | Love |
| **5** | 💼 работа | Work |
| **6** | 📚 учёба | Studies |
| **7** | ⚽ спорт | Sports |
| **8** | 🎨 искусство | Art |
| **9** | 🎵 музыка | Music |
| **10** | 📖 книги | Books |

---

## 🎲 Surprise Me Mode!

**Can't decide? Let the AI choose for you!** The random mode combines unexpected topics with different difficulty levels for endless variety.

```bash
# Quick random story
./russian-story.sh --random

# From menu: Choose option 4
╔══════════════════════════════════════════════╗
║           RUSSIAN AI STORYTELLER            ║
╚══════════════════════════════════════════════╝

🎯 CHOOSE LEVEL:
   1. 🟢 Beginner (A1)
   2. 🟡 Intermediate (A2-B1) 
   3. 🔴 Advanced (B2-C1)
   4. 🎲 Random topic & level    <-- PICK THIS!
   5. 📊 Show stats
   6. 🚪 Exit
```

**Example random combinations:**
- 🎨 **Art** (Advanced) - 500-word story about Russian painters
- ⚽ **Sports** (Beginner) - Simple 150-word story about soccer
- 💼 **Work** (Intermediate) - 300-word office story
- ✈️ **Travel** (Advanced) - Complex travel adventure

---

## ⚡ Power User Commands

### 🎯 Direct Story Generation
```bash
# Generate specific topic and level
./russian-story.sh --topic путешествие --level intermediate

# 🎲 Random story (surprise me!)
./russian-story.sh --random

# Quick beginner story without audio
./russian-story.sh --topic семья --level beginner --no-audio

# Advanced story with audio
./russian-story.sh --topic искусство --level advanced
```

### 📊 Management Commands
```bash
# Show your progress statistics
./russian-story.sh --stats

# List all generated stories
./russian-story.sh --list-stories

# Clean generated audio files
./russian-story.sh --clean-audio
```

---

## ✨ What It Looks Like

### 🎓 Complete Lesson Output
<details>
<summary>📖 Click to see full lesson example</summary>

```bash
╔══════════════════════════════════════════════╗
║               RUSSIAN LESSON                 ║
╚══════════════════════════════════════════════╝

🎭 TOPIC: дружба | 📊 LEVEL: beginner
══════════════════════════════════════════════

📖 RUSSIAN STORY:
Маша и Лена - хорошие подруги. Они часто играют вместе. 
Маша любит рисовать картинки, а Лена помогает ей с красками.

🌍 ENGLISH TRANSLATION:
Masha and Lena are good friends. They often play together.
Masha likes to draw pictures, and Lena helps her with paints.

📚 VOCABULARY:
   • хорошие (adjective) - good
   • подруги (noun) - friends  
   • часто (adverb) - often
   • рисовать (verb) - to draw

🔊 Generating audio narration...
✅ Audio generated successfully (135168 bytes)

🎧 Listen to this story in Russian? (y/N): y
🔊 Playing audio... (Press Ctrl+C to stop)
✅ Audio playback completed

🎯 EXERCISES:
   • FILL-IN: Кто помогает Маше с красками?
   • TRUE-FALSE: Маша и Лена посмеиваются друг над другом.
   • QNA: Как часто Маша и Лена играют вместе?

✅ Story saved to: /home/user/.local/share/russian-ai-stories/2025-10/story-001.json
```
</details>

---

## 📚 Complete Output Format

<details>
<summary>🔧 Click to see FULL JSON structure with audio</summary>

```json
{
  "story_ru": "Маша и Лена - хорошие подруги. Они часто играют вместе. Маша любит рисовать картинки, а Лена помогает ей с красками. Иногда они посмеиваются друг над другом, но всегда остаются друзьями.",
  "story_en": "Masha and Lena are good friends. They often play together. Masha likes to draw pictures, and Lena helps her with paints. Sometimes they laugh at each other, but they always stay friends.",
  "vocab": [
    {
      "word": "хорошие",
      "translation": "good", 
      "pos": "adjective"
    },
    {
      "word": "подруги",
      "translation": "friends",
      "pos": "noun"
    },
    {
      "word": "друг",
      "translation": "friend",
      "pos": "noun"
    },
    {
      "word": "часто", 
      "translation": "often",
      "pos": "adverb"
    },
    {
      "word": "рисовать",
      "translation": "to draw",
      "pos": "verb"
    },
    {
      "word": "любить",
      "translation": "to like", 
      "pos": "verb"
    }
  ],
  "exercises": [
    {
      "type": "fill-in",
      "question": "Кто помогает Маше с красками?",
      "answer": "Лена"
    },
    {
      "type": "true-false", 
      "question": "Маша и Лена посмеиваются друг над другом.",
      "answer": true
    },
    {
      "type": "qna",
      "question": "Как часто Маша и Лена играют вместе?",
      "answer": "Они часто играют вместе."
    }
  ],
  "metadata": {
    "topic": "дружба",
    "level": "beginner", 
    "generated_date": "2025-10-08",
    "audio_file": "/home/user/.local/share/russian-ai-stories/audio/2025-10-08-дружба-beginner.mp3",
    "word_count_ru": 78,
    "word_count_en": 82
  }
}
```
</details>

### 🗂️ File Structure
```
~/.local/share/russian-ai-stories/
├── audio/
│   └── 2025-10-08-дружба-beginner.mp3    # 🔊 Audio file
├── archive/
│   └── 2025-10-08-story-001.json         # 📁 Dated backup
├── 2025-10/                              # 📅 Monthly folder
│   ├── story-001.json                    # 📄 Current story
│   └── story-002.json
└── russian_stories.log                   # 📊 Activity log
```

---

## 🎯 Features

### 🎓 Learning Features
- **📖 AI-Generated Stories** - Authentic Russian content at 3 difficulty levels
- **🌍 Professional Translations** - Accurate English translations
- **📚 Vocabulary Builder** - Word lists with parts of speech
- **🎯 Interactive Exercises** - Fill-in-blank, True/False, and Q&A
- **🔊 Audio Narration** - Native Russian pronunciation
- **💾 Progress Tracking** - Organized archive with statistics

### 🔧 Technical Features  
- **🐍 Virtual Environment Management** - Automatic gTTS installation & cleanup
- **🤖 Flexible AI Integration** - Works with any Ollama model
- **🛡️ Error Resilience** - Robust JSON parsing and error handling
- **🎨 Beautiful UI** - Colorful, emoji-rich interface
- **📊 Smart Storage** - Monthly folders with archive system

---

## ⚙️ Configuration

### Custom AI Models:
Edit the `AI_MODEL` variable to use your preferred model:
```bash
readonly AI_MODEL="your-preferred-model"
```

---

## 🛠️ Technical Details

### Dependencies:
- **Ollama** - Local AI inference
- **Python 3** - Audio generation and JSON processing  
- **jq** - JSON parsing and manipulation
- **ffmpeg/ffplay** - Audio playback
- **python3-venv** - Virtual environment management

### Virtual Environment Magic:
- 🐍 Creates isolated Python environment for each session
- 📦 Automatically installs gTTS without system changes
- 🔊 Generates Russian audio with proper pronunciation  
- 🧹 Completely cleans up after itself

---

## 🤝 Contributing

We welcome contributions! Feel free to:
- 🐛 Report bugs and issues
- 💡 Suggest new features and topics  
- 🔧 Submit pull requests
- 📚 Improve documentation

### Development:
```bash
git clone https://github.com/yourusername/russian-ai-storyteller
cd russian-ai-storyteller
# Start hacking! 🚀
```

---

## 📄 License

MIT License - feel free to use this project for personal or commercial purposes.
