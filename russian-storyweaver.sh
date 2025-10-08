#!/bin/bash
# File: russian-ai-storyteller.sh
# Description: Generate AI-corrected Russian stories with translation, vocab, exercises, and audio narration
# Requires: Ollama, Python3, ffmpeg/ffplay, jq

set -euo pipefail
IFS=$'\n\t'

# ================================
# 🎨 CONFIGURATION & CONSTANTS
# ================================
readonly APP_DIR="${HOME}/.local/share/russian-ai-stories"
readonly AUDIO_DIR="${APP_DIR}/audio"
readonly CONFIG_DIR="${APP_DIR}/config"
readonly LOG_FILE="${APP_DIR}/russian_stories.log"

# Color codes for pretty output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# Model configuration - KEEPING YOUR ORIGINAL MODEL
readonly AI_MODEL="infidelis/GigaChat-20B-A3B-instruct-v1.5:q4_0"

# Topics database
readonly TOPICS=("дружба" "путешествие" "семья" "любовь" "работа" "учёба" "спорт" "искусство" "музыка" "книги")
readonly TOPIC_EMOJIS=("🤝" "✈️" "👨‍👩‍👧‍👦" "💖" "💼" "📚" "⚽" "🎨" "🎵" "📖")

# ================================
# 🚀 INITIALIZATION & SETUP
# ================================

initialize_app() {
    echo -e "${CYAN}"
    cat << "EOF"
📖 ██████╗ ██╗   ██╗███████╗███████╗██████╗ ██╗ █████╗ ███╗   ██╗
  ██╔══██╗██║   ██║██╔════╝██╔════╝██╔══██╗██║██╔══██╗████╗  ██║
  ██████╔╝██║   ██║███████╗█████╗  ██████╔╝██║███████║██╔██╗ ██║
  ██╔══██╗██║   ██║╚════██║██╔══╝  ██╔══██╗██║██╔══██║██║╚██╗██║
  ██║  ██║╚██████╔╝███████║███████╗██║  ██║██║██║  ██║██║ ╚████║
  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
EOF
    echo -e "${RESET}"
    echo -e "${BLUE}           AI-Powered Russian Language Learning Assistant${RESET}"
    echo -e "${BLUE}===========================================================${RESET}"
    echo ""
    
    # Create necessary directories
    mkdir -p "$APP_DIR" "$AUDIO_DIR" "$CONFIG_DIR"
    
    check_dependencies
    setup_ollama
}

check_dependencies() {
    echo -e "${YELLOW}🔍 Checking dependencies...${RESET}"
    
    local missing_deps=()
    
    # Check for required commands (REMOVED gtts Python check)
    for cmd in python3 jq ffplay; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing dependencies: ${missing_deps[*]}${RESET}"
        echo -e "${YELLOW}💡 Please install missing packages and try again.${RESET}"
        exit 1
    fi
    
    # Check if python3-venv is available (needed for virtual environments)
    if ! python3 -c "import venv" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Python venv module not available${RESET}"
        echo -e "${CYAN}💡 Attempting to install python3-venv...${RESET}"
        
        # Try to install venv based on OS
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y python3-venv
        elif command -v brew &>/dev/null; then
            brew install python3
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y python3-virtualenv
        else
            echo -e "${YELLOW}⚠️  Cannot automatically install python3-venv${RESET}"
            echo -e "${CYAN}💡 Will attempt to continue anyway...${RESET}"
        fi
    fi
    
    echo -e "${GREEN}✅ All core dependencies are satisfied!${RESET}"
    echo -e "${BLUE}ℹ️  gTTS will be automatically installed in a virtual environment${RESET}"
}

setup_ollama() {
    if ! command -v ollama &>/dev/null; then
        echo -e "${YELLOW}📥 Ollama not found! Installing...${RESET}"
        curl -fsSL https://ollama.com/install.sh | sh
        echo -e "${GREEN}✅ Ollama installed successfully!${RESET}"
    fi
    
    # Verify model is available
    if ! ollama list | grep -q "$AI_MODEL"; then
        echo -e "${YELLOW}🤖 Model $AI_MODEL not found. Please pull it with:${RESET}"
        echo -e "${CYAN}   ollama pull $AI_MODEL${RESET}"
        echo -e "${YELLOW}📚 You can find other models at: https://ollama.com/library${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ AI Model '$AI_MODEL' is ready!${RESET}"
}

# ================================
# 🎯 CORE FUNCTIONALITY
# ================================

run_llm() {
    local prompt="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        local response
        if response=$(ollama run "$AI_MODEL" "$prompt" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'); then
            if [[ -n "$response" ]]; then
                echo "$response"
                return 0
            fi
        fi
        
        ((retry_count++))
        echo -e "${YELLOW}⚠️  AI request failed (attempt $retry_count/$max_retries)...${RESET}" >&2
        sleep 2
    done
    
    echo -e "${RED}❌ Failed to get response from AI after $max_retries attempts${RESET}" >&2
    return 1
}

generate_audio() {
    local story="$1"
    local filename="$2"
    
    echo -e "${CYAN}🔊 Generating audio narration...${RESET}"
    
    # Create temporary directory for virtual environment
    local venv_dir="$APP_DIR/temp_audio_venv"
    
    # Cleanup function
    cleanup_audio_venv() {
        if [[ -d "$venv_dir" ]]; then
            rm -rf "$venv_dir" && echo -e "${YELLOW}🧹 Cleaned up temporary virtual environment${RESET}"
        fi
    }
    
    # Set up cleanup trap
    trap cleanup_audio_venv EXIT
    
    # Create virtual environment
    echo -e "${BLUE}🐍 Setting up Python virtual environment...${RESET}"
    if ! python3 -m venv "$venv_dir"; then
        echo -e "${RED}❌ Failed to create virtual environment${RESET}"
        echo -e "${YELLOW}💡 Ensure python3-venv is installed on your system${RESET}"
        return 1
    fi
    
    # Install gTTS in the virtual environment
    echo -e "${BLUE}📦 Installing gTTS in virtual environment...${RESET}"
    if ! "$venv_dir/bin/pip" install gtts --quiet; then
        echo -e "${RED}❌ Failed to install gTTS${RESET}"
        cleanup_audio_venv
        return 1
    fi
    echo -e "${GREEN}✅ gTTS installed successfully${RESET}"
    
    # Generate audio using the virtual environment's Python
    echo -e "${BLUE}🎵 Generating audio file...${RESET}"
    if ! "$venv_dir/bin/python3" - <<EOF
import sys
import os
from gtts import gTTS

try:
    # Ensure directory exists
    os.makedirs(os.path.dirname("$filename"), exist_ok=True)
    
    # Generate audio
    tts = gTTS("""$story""", lang='ru')
    tts.save("""$filename""")
    
    # Verify file was created
    if os.path.exists("""$filename"""):
        file_size = os.path.getsize("""$filename""")
        print(f"✅ Audio generated successfully ({file_size} bytes)")
    else:
        print("❌ Audio file was not created")
        sys.exit(1)
        
except Exception as e:
    print(f"❌ Audio generation failed: {e}")
    sys.exit(1)
EOF
    then
        echo -e "${RED}❌ Audio generation failed${RESET}"
        cleanup_audio_venv
        return 1
    fi
    
    # Cleanup virtual environment
    cleanup_audio_venv
    trap - EXIT
    
    return 0
}

play_audio() {
    local audio_file="$1"
    
    echo ""
    read -rp "🎧 Listen to this story in Russian? (y/N): " listen
    [[ "$listen" =~ ^[Yy]$ ]] || return 0
    
    # Check if audio file exists and has content
    if [[ ! -f "$audio_file" ]]; then
        echo -e "${RED}❌ Audio file not found: $audio_file${RESET}"
        return 1
    fi
    
    local file_size
    file_size=$(stat -f%z "$audio_file" 2>/dev/null || stat -c%s "$audio_file" 2>/dev/null)
    if [[ $file_size -eq 0 ]]; then
        echo -e "${RED}❌ Audio file is empty${RESET}"
        return 1
    fi
    
    echo -e "${CYAN}🔊 Playing audio... (Press Ctrl+C to stop)${RESET}"
    if ffplay -nodisp -autoexit "$audio_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Audio playback completed${RESET}"
    else
        echo -e "${RED}❌ Audio playback failed${RESET}"
        return 1
    fi
}

# ================================
# 📚 STORY GENERATION
# ================================

generate_full_lesson() {
    local topic="$1"
    local difficulty="$2"
    local prompt
    
    case $difficulty in
        beginner)
            prompt="Напиши короткий рассказ на русском языке на тему '$topic' для уровня A1 (до 150 слов). Переведи рассказ на английский. 

Создай строго JSON со следующими ключами и форматом:

{
  \"story_ru\": \"<Рассказ на русском>\",
  \"story_en\": \"<English translation>\",
  \"vocab\": [
    {\"word\": \"<слово>\", \"translation\": \"<translation>\", \"pos\": \"<часть речи>\"}
  ],
  \"exercises\": [
    {\"type\": \"fill-in\", \"question\": \"<вопрос>\", \"answer\": \"<ответ>\"},
    {\"type\": \"true-false\", \"question\": \"<вопрос>\", \"answer\": true},
    {\"type\": \"qna\", \"question\": \"<вопрос>\", \"answer\": \"<ответ>\"}
  ]
}

ВЕРНИ ТОЛЬКО JSON! Никаких комментариев, никакого текста вне JSON, никаких markdown блоков. Только чистый JSON."
            ;;
        intermediate)
            prompt="Напиши рассказ на русском языке на тему '$topic' для уровня A2–B1 (до 300 слов). Переведи на английский. 

Создай строго JSON с ключами story_ru, story_en, vocab и exercises. Формат vocab и exercises такой же, как в beginner.

ВЕРНИ ТОЛЬКО JSON! Никаких комментариев, никакого текста вне JSON, никаких markdown блоков. Только чистый JSON."
            ;;
        advanced)
            prompt="Напиши рассказ на русском языке на тему '$topic' для уровня B2–C1 (до 500 слов). Переведи на английский. 

Создай строго JSON с ключами story_ru, story_en, vocab и exercises. Формат vocab и exercises такой же, как в beginner.

ВЕРНИ ТОЛЬКО JSON! Никаких комментариев, никакого текста вне JSON, никаких markdown блоков. Только чистый JSON."
            ;;
    esac

    echo -e "${MAGENTA}🤖 Generating story, translation, vocab, and exercises...${RESET}"
    run_llm "$prompt"
}

validate_and_parse_json() {
    local json_output="$1"
    
    # Create a temporary Python script to avoid heredoc issues
    local temp_python_script="$APP_DIR/temp_validate.py"
    
    cat > "$temp_python_script" << 'PYTHON_EOF'
import sys, json, re

text = sys.argv[1]

# Clean the input - remove markdown code blocks and surrounding text
text = re.sub(r'^```json\s*', '', text, flags=re.IGNORECASE)
text = re.sub(r'\s*```$', '', text)
text = re.sub(r'^JSON:\s*', '', text, flags=re.IGNORECASE)

# Extract JSON between first { and last }
start_idx = text.find('{')
end_idx = text.rfind('}') + 1

if start_idx == -1 or end_idx == 0:
    print("❌ No JSON structure found", file=sys.stderr)
    sys.exit(1)

json_text = text[start_idx:end_idx]

try:
    obj = json.loads(json_text)
except json.JSONDecodeError as e:
    print(f"❌ JSON parsing failed: {e}", file=sys.stderr)
    sys.exit(1)

# Validate structure
required_keys = ["story_ru", "story_en", "vocab", "exercises"]
for k in required_keys:
    if k not in obj:
        print(f"❌ Missing required key: {k}", file=sys.stderr)
        sys.exit(1)

# Fix vocab format if needed
if not isinstance(obj["vocab"], list):
    print("❌ Vocab must be a list", file=sys.stderr)
    sys.exit(1)

# Convert vocab to proper format if it's in different structure
fixed_vocab = []
for item in obj["vocab"]:
    if isinstance(item, str):
        # Simple string - convert to object
        fixed_vocab.append({"word": item, "translation": "unknown", "pos": "unknown"})
    elif isinstance(item, dict):
        # Already an object, ensure it has required fields
        fixed_item = item.copy()
        if "word" not in fixed_item:
            fixed_item["word"] = "unknown"
        if "translation" not in fixed_item:
            fixed_item["translation"] = "unknown"
        if "pos" not in fixed_item:
            fixed_item["pos"] = "unknown"
        fixed_vocab.append(fixed_item)
    else:
        # Unknown format, skip
        continue

obj["vocab"] = fixed_vocab

# Fix exercises format if needed
if not isinstance(obj["exercises"], list):
    # Try to convert from object format to list format
    if isinstance(obj["exercises"], dict):
        fixed_exercises = []
        for ex_type, ex_data in obj["exercises"].items():
            if isinstance(ex_data, list):
                for ex_item in ex_data:
                    if isinstance(ex_item, dict) and "question" in ex_item:
                        fixed_exercises.append({
                            "type": ex_type,
                            "question": ex_item["question"],
                            "answer": ex_item.get("answer", "unknown")
                        })
                    elif isinstance(ex_item, str):
                        fixed_exercises.append({
                            "type": ex_type,
                            "question": ex_item,
                            "answer": "unknown"
                        })
            elif isinstance(ex_data, str):
                fixed_exercises.append({
                    "type": ex_type,
                    "question": ex_data,
                    "answer": "unknown"
                })
        obj["exercises"] = fixed_exercises
    else:
        print("❌ Exercises must be a list or object", file=sys.stderr)
        sys.exit(1)

# Ensure all exercises have required fields
for i, ex in enumerate(obj["exercises"]):
    if not isinstance(ex, dict):
        obj["exercises"][i] = {"type": "unknown", "question": str(ex), "answer": "unknown"}
    else:
        if "type" not in ex:
            ex["type"] = "unknown"
        if "question" not in ex:
            ex["question"] = "unknown"
        if "answer" not in ex:
            ex["answer"] = "unknown"

print(json.dumps(obj, ensure_ascii=False, indent=2))
PYTHON_EOF

    # Run the Python script and capture output
    local result
    if result=$(python3 "$temp_python_script" "$json_output" 2>&1); then
        echo "$result"
        rm -f "$temp_python_script"
        return 0
    else
        echo "$result" >&2
        rm -f "$temp_python_script"
        return 1
    fi
}

# ================================
# 💾 STORY MANAGEMENT
# ================================

save_story() {
    local json_data="$1" topic="$2" level="$3"
    
    local folder="$APP_DIR/$(date +%Y-%m)"
    local archive_folder="$APP_DIR/archive"
    mkdir -p "$folder" "$archive_folder"
    
    # Find next available number
    local i=1
    while [[ -f "$folder/story-$(printf '%03d' $i).json" ]]; do
        ((i++))
    done
    
    local filename="$folder/story-$(printf '%03d' $i).json"
    local archive_file="$archive_folder/$(date +%Y-%m-%d)-story-$(printf '%03d' $i).json"
    
    # Save to current month folder
    echo "$json_data" > "$filename"
    
    # Also save to archive with date
    echo "$json_data" > "$archive_file"
    
    echo -e "${GREEN}✅ Story saved to:${RESET}"
    echo -e "   ${CYAN}$filename${RESET}"
    echo -e "   ${BLUE}$archive_file${RESET}"
}

# ================================
# 🎮 LESSON RUNNER
# ================================

run_lesson() {
    local difficulty="$1" topic="$2"
    
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║               RUSSIAN LESSON                 ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "🎭 ${BOLD}TOPIC:${RESET} ${MAGENTA}$topic${RESET} | 📊 ${BOLD}LEVEL:${RESET} ${YELLOW}$difficulty${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════════${RESET}"
    echo ""

    # Generate lesson content
    local json_output
    if ! json_output=$(generate_full_lesson "$topic" "$difficulty"); then
        echo -e "${RED}❌ Failed to generate lesson content${RESET}"
        return 1
    fi

    # Clean and validate JSON
    local valid_json
    if ! valid_json=$(validate_and_parse_json "$json_output"); then
        echo -e "${RED}❌ Invalid JSON response from AI${RESET}"
        echo -e "${YELLOW}📝 Raw output for debugging:${RESET}"
        echo "$json_output"
        return 1
    fi

    # Extract content
    local story_ru story_en vocab_json exercises_json
    story_ru=$(echo "$valid_json" | jq -r '.story_ru')
    story_en=$(echo "$valid_json" | jq -r '.story_en')
    vocab_json=$(echo "$valid_json" | jq -c '.vocab')
    exercises_json=$(echo "$valid_json" | jq -c '.exercises')

    # Display Russian story
    echo -e "${GREEN}📖 RUSSIAN STORY:${RESET}"
    echo -e "${WHITE}$story_ru${RESET}"
    echo ""

    # Display English translation
    echo -e "${BLUE}🌍 ENGLISH TRANSLATION:${RESET}"
    echo -e "${WHITE}$story_en${RESET}"
    echo ""

    # Display vocabulary
    echo -e "${YELLOW}📚 VOCABULARY:${RESET}"
    echo "$vocab_json" | jq -r '.[] | "   \(.word) (\(.pos)) - \(.translation)"' | while read -r line; do
        echo -e "   ${CYAN}•${RESET} $line"
    done
    echo ""

    # Generate audio with virtual environment
    local audio_file="$AUDIO_DIR/$(date +%Y-%m-%d)-$topic-$difficulty.mp3"
    if generate_audio "$story_ru" "$audio_file"; then
        play_audio "$audio_file"
    else
        echo -e "${YELLOW}⚠️  Audio generation failed, but story was saved successfully${RESET}"
    fi

    # Save story
    save_story "$valid_json" "$topic" "$difficulty"

    # Display exercises
    echo -e "${MAGENTA}🎯 EXERCISES:${RESET}"
    echo "$exercises_json" | jq -r '.[] | "\(.type | ascii_upcase): \(.question)"' | while read -r line; do
        echo -e "   ${MAGENTA}•${RESET} $line"
    done
    echo ""
}

# ================================
# 🎪 USER INTERFACE
# ================================

show_main_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════╗
║           RUSSIAN AI STORYTELLER            ║
║                 MAIN MENU                   ║
╚══════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
    
    echo -e "${BOLD}🎯 CHOOSE LEVEL:${RESET}"
    echo -e "   ${GREEN}1.${RESET} 🟢 Beginner (A1)"
    echo -e "   ${YELLOW}2.${RESET} 🟡 Intermediate (A2-B1)" 
    echo -e "   ${RED}3.${RESET} 🔴 Advanced (B2-C1)"
    echo -e "   ${MAGENTA}4.${RESET} 🎲 Random topic & level"
    echo -e "   ${BLUE}5.${RESET} 📊 Show stats"
    echo -e "   ${WHITE}6.${RESET} 🚪 Exit"
    echo ""
}

show_topic_menu() {
    echo -e "${BOLD}🎭 CHOOSE TOPIC:${RESET}"
    for i in "${!TOPICS[@]}"; do
        local emoji="${TOPIC_EMOJIS[$i]}"
        local topic="${TOPICS[$i]}"
        echo -e "   ${CYAN}$((i+1)).${RESET} $emoji $topic"
    done
    echo ""
}

get_user_choice() {
    local prompt="$1"
    read -rp "$prompt" choice
    echo "$choice"
}

show_stats() {
    local total_stories=0
    local total_audio=0
    
    if [[ -d "$APP_DIR" ]]; then
        total_stories=$(find "$APP_DIR" -name "*.json" -type f | wc -l)
        total_audio=$(find "$AUDIO_DIR" -name "*.mp3" -type f 2>/dev/null | wc -l)
    fi
    
    clear
    echo -e "${CYAN}📊 APPLICATION STATISTICS${RESET}"
    echo -e "${BLUE}══════════════════════════${RESET}"
    echo ""
    echo -e "📁 ${BOLD}Storage Directory:${RESET} ${YELLOW}$APP_DIR${RESET}"
    echo ""
    echo -e "📚 ${GREEN}Total Stories:${RESET} ${WHITE}$total_stories${RESET}"
    echo -e "🔊 ${BLUE}Total Audio Files:${RESET} ${WHITE}$total_audio${RESET}"
    echo ""
    
    if [[ $total_stories -gt 0 ]]; then
        echo -e "${BOLD}Recent Stories:${RESET}"
        find "$APP_DIR" -name "*.json" -type f -exec ls -lt {} + 2>/dev/null | head -5 | while read -r line; do
            echo -e "   ${CYAN}•${RESET} $line"
        done
    fi
    
    echo ""
    read -n 1 -s -r -p "   Press any key to continue..."
}

# ================================
# 🎯 MAIN APPLICATION FLOW
# ================================

main() {
    initialize_app
    
    while true; do
        show_main_menu
        local choice
        choice=$(get_user_choice "Your choice [1-6]: ")
        
        case $choice in
            1) difficulty="beginner" ;;
            2) difficulty="intermediate" ;;
            3) difficulty="advanced" ;;
            4) 
                # Random topic and level
                local levels=("beginner" "intermediate" "advanced")
                difficulty="${levels[$((RANDOM % 3))]}"
                topic="${TOPICS[$((RANDOM % ${#TOPICS[@]}))]}"
                run_lesson "$difficulty" "$topic"
                continue
                ;;
            5) 
                show_stats
                continue
                ;;
            6) 
                echo ""
                echo -e "${GREEN}Спасибо за изучение русского! До встречи! 👋${RESET}"
                echo ""
                exit 0
                ;;
            *) 
                echo -e "${RED}❌ Invalid choice. Please try again.${RESET}"
                sleep 1
                continue
                ;;
        esac
        
        show_topic_menu
        local topic_choice
        topic_choice=$(get_user_choice "Choose topic [1-${#TOPICS[@]}]: ")
        
        if [[ "$topic_choice" =~ ^[0-9]+$ ]] && [[ "$topic_choice" -ge 1 ]] && [[ "$topic_choice" -le ${#TOPICS[@]} ]]; then
            local topic_index=$((topic_choice - 1))
            topic="${TOPICS[$topic_index]}"
            
            echo ""
            echo -e "${MAGENTA}🚀 Launching lesson: ${YELLOW}$topic${RESET} | ${CYAN}$difficulty${RESET}${RESET}"
            echo -e "${BLUE}══════════════════════════════════════════════${RESET}"
            sleep 1
            
            if run_lesson "$difficulty" "$topic"; then
                echo -e "${GREEN}✅ Lesson completed successfully!${RESET}"
            else
                echo -e "${RED}❌ Lesson failed. Please try again.${RESET}"
            fi
        else
            echo -e "${RED}❌ Invalid topic choice.${RESET}"
            sleep 1
            continue
        fi
        
        echo ""
        read -rp "🔄 Generate another story? (y/N): " again
        if [[ ! "$again" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${GREEN}Удачи в изучении русского языка! 🇷🇺${RESET}"
            echo -e "${CYAN}До скорой встречи! 👋${RESET}"
            echo ""
            break
        fi
    done
}

# ================================
# 🚀 START THE APPLICATION
# ================================

# Handle script interrupts gracefully
trap 'echo -e "\n${RED}❌ Script interrupted. Exiting...${RESET}"; exit 1' INT TERM

# Run the main function
main "$@"
