# 🌍 Polyglot AI Storyteller - Cloud-Powered Language Learning

[![Bash](https://img.shields.io/badge/Bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)
[![Ollama](https://img.shields.io/badge/Ollama-Required-orange.svg)](https://ollama.com)
[![Cloud AI](https://img.shields.io/badge/AI-gpt--oss:120b--cloud-green.svg)](https://ollama.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Intelligent Multi-Language Learning** - Generate immersive stories in Russian, Urdu, and English with translations, vocabulary, exercises, and cloud AI power!

---

## 🚀 Quick Start

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install curl jq

# macOS  
brew install curl jq
```

### Installation & Setup
```bash
# 1. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Start Ollama service
ollama serve

# 3. Pull the cloud model (in another terminal)
ollama pull gpt-oss:120b-cloud

# 4. Download Polyglot AI Storyteller
wget -O polyglot-storyteller.sh https://raw.githubusercontent.com/your-repo/polyglot-storyteller/main/polyglot-storyteller.sh
chmod +x polyglot-storyteller.sh

# 5. Run the application
./polyglot-storyteller.sh
```

---

## 🌟 What's New in v3.0

### 🆕 Major Improvements
- **🌍 Multi-Language Support** - Russian, Urdu, and English
- **☁️ Cloud AI Integration** - Uses `gpt-oss:120b-cloud` for superior performance
- **🎨 Modern UI** - Clean, responsive interface with better readability
- **⚡ Streamlined Code** - Reduced from 800+ to ~400 lines
- **🔧 Simplified Setup** - No Python/audio dependencies required

### 🗣️ Language Support
| Language | Code | Level | Features |
|----------|------|-------|----------|
| 🇷🇺 Russian | `ru` | A1-C1 | Technical & cultural stories |
| 🇵🇰 Urdu | `ur` | A1-C1 | Native-level fluency |
| 🇺🇸 English | `en` | A1-C1 | Literary & technical content |

---

## 🎮 Quick Menu Guide

### Main Menu
```
🎯 Main Menu
══════════════════════════════════════════════════════════════════

   1. 🆕 New Learning Session
   2. 🌍 Change Language
   3. 📊 Change Level  
   4. ⚙️ Settings
   5. 🚪 Exit
```

### Language Selection
```
🌍 Select Language
──────────────────────────────────────────────────────────────────

   1. 🇷🇺 Russian
   2. 🇵🇰 Urdu
   3. 🇺🇸 English
```

### Difficulty Levels
```
📊 Select Difficulty Level
──────────────────────────────────────────────────────────────────

   1. Beginner (A1) - Simple vocabulary, basic sentences
   2. Intermediate (A2-B1) - Complex sentences, everyday topics  
   3. Advanced (B2-C1) - Advanced grammar, technical topics
```

---

## ✨ Features

### 🎓 Learning Features
- **📖 AI-Generated Stories** - Authentic content in 3 languages
- **🌍 Professional Translations** - Accurate translations between languages
- **📚 Vocabulary Builder** - Contextual word lists with examples
- **🎯 Interactive Exercises** - Multiple choice, fill-in-blank, true/false
- **☁️ Cloud AI Power** - High-quality content from `gpt-oss:120b-cloud`

### 🔧 Technical Features
- **⚡ Fast Performance** - Cloud model eliminates local processing delays
- **🛡️ Error Resilience** - Robust JSON parsing and API error handling
- **🎨 Modern Interface** - Clean, color-coded UI with emojis
- **📊 Progress Tracking** - Session management and statistics
- **🔧 No Dependencies** - Only requires curl, jq, and Ollama

---

## 🎯 Usage Examples

### Interactive Session
```bash
./polyglot-storyteller.sh

# Example flow:
# 1. Choose "🆕 New Learning Session"
# 2. Select language (e.g., 🇵🇰 Urdu)  
# 3. Choose level (e.g., Advanced)
# 4. Enter topic (e.g., "linux")
# 5. Enjoy your personalized lesson!
```

### Sample Urdu Output
```
📖 Story:
آصف ایک پرجوش سافٹ ویئر انجینئر تھا جو ہمیشہ نئی ٹیکنالوجیوں کی تلاش میں رہتا تھا۔ 
ایک دن اس نے اپنے دوست سے سنا کہ لینکس ایک آزاد اور اوپن سورس آپریٹنگ سسٹم ہے...

🌍 Translation:
Asif was an enthusiastic software engineer who was always on the lookout for new technologies.
One day he heard from his friend that Linux is a free and open-source operating system...

📚 Vocabulary:
   • اوپن سورس - open source
   • ڈسٹری بیوشن - distribution
   • ٹرمینل - terminal
```

### Sample Russian Output  
```
📖 Story:
В один холодный февральский вечер кибер‑специалист Алексей, известный в сообществе как «Тень»...
🌍 Translation:
On a cold February evening, cyber specialist Alexei, known in the community as "Shadow"...
```

---

## ⚙️ Configuration

### Settings Management
The application automatically manages configuration in:
```
~/.local/share/polyglot-stories/config/app_config.json
```

### Customizable Settings:
- **Default Language** - Russian, Urdu, or English
- **Difficulty Level** - Beginner, Intermediate, Advanced  
- **Auto-translate** - Show/hide translations
- **Daily Goal** - Stories per day target

---

## 🗂️ File Structure

```
~/.local/share/polyglot-stories/
├── config/
│   └── app_config.json          # ⚙️ User preferences
├── cache/                       # 🔄 Temporary files
├── sessions/                    # 📊 Learning sessions
└── app.log                     # 📝 Application log
```

---

## 🔧 Technical Details

### Cloud AI Integration
- **Model**: `gpt-oss:120b-cloud` via Ollama API
- **Endpoint**: `http://localhost:11434/api/chat`
- **Timeout**: 90 seconds with retry logic
- **JSON Processing**: Robust parsing with error handling

### API Call Example
```bash
curl -s -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss:120b-cloud",
    "messages": [{
      "role": "user", 
      "content": "Create an engaging Urdu story about linux..."
    }],
    "stream": false
  }'
```

---

## 🛠️ Troubleshooting

### Common Issues

**❌ "AI service unavailable"**
```bash
# Check if Ollama is running
ollama serve

# Verify model is available
ollama list
```

**❌ "Invalid story data received"**
```bash
# Check the application log
tail -f ~/.local/share/polyglot-stories/app.log
```

**❌ Model not found**
```bash
# Pull the required model
ollama pull gpt-oss:120b-cloud
```

### Debug Mode
Add debug output by checking the log file:
```bash
tail -f ~/.local/share/polyglot-stories/app.log
```

---

## 🌟 Why Choose Polyglot AI Storyteller?

### ✅ Advantages Over Original
- **🌍 True Multi-Lingual** - Not just Russian, but Urdu and English
- **☁️ Cloud Power** - No local model bottlenecks
- **⚡ Lightweight** - 50% less code, faster execution
- **🎯 Better UX** - Modern interface with intuitive navigation
- **🔧 Simplified** - No complex audio/Python dependencies

### 🎓 Perfect For
- **Language Learners** - Authentic content at appropriate levels
- **Educators** - Ready-to-use language learning materials
- **Polyglots** - Practice multiple languages in one tool
- **Tech Enthusiasts** - Technical stories about programming, security, etc.

---

## 🤝 Contributing

We welcome contributions to make language learning even better!

### Areas for Improvement:
- 🌐 Add more languages (Spanish, French, Arabic, etc.)
- 🎵 Integrate text-to-speech for audio practice  
- 📱 Create web/mobile interface
- 🔌 Add plugin system for custom exercises
- 📊 Enhanced progress analytics

### Development:
```bash
git clone https://github.com/your-username/polyglot-storyteller
cd polyglot-storyteller
# Start contributing! 🚀
```

---

## 📄 License

MIT License - free for personal, educational, and commercial use.