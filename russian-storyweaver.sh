#!/bin/bash
# File: russian-ai-storyteller.sh
# Description: Enhanced AI-corrected Russian stories with streaming, better UX, and modern interface
# Requires: Ollama, Python3, ffmpeg/ffplay, jq

set -euo pipefail
IFS=$'\n\t'

# ================================
# 🎨 CONFIGURATION & CONSTANTS
# ================================
readonly APP_DIR="${HOME}/.local/share/russian-ai-stories"
readonly AUDIO_DIR="${APP_DIR}/audio"
readonly CONFIG_DIR="${APP_DIR}/config"
readonly CACHE_DIR="${APP_DIR}/cache"
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

# AI Models - using more reliable models
readonly CREATIVE_MODEL="infidelis/GigaChat-20B-A3B-instruct-v1.5:q4_0"
readonly VALIDATOR_MODEL="llama3:latest"

# Topics database with emojis
readonly TOPICS=(
    "дружба" "путешествие" "семья" "любовь" "работа" 
    "учёба" "спорт" "искусство" "музыка" "книги"
    "еда" "технологии" "природа" "город" "деревня"
)
readonly TOPIC_EMOJIS=("🤝" "✈️" "👨‍👩‍👧‍👦" "💖" "💼" "📚" "⚽" "🎨" "🎵" "📖" "🍕" "💻" "🌳" "🏙️" "🌄")

# ================================
# 🛠️ UTILITY FUNCTIONS
# ================================

log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

print_status() {
    local emoji="$1"
    local color="$2"
    local message="$3"
    echo -e "${color}${emoji} ${message}${RESET}"
}

print_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                   RUSSIAN AI STORYTELLER                    ║
║              Immersive Language Learning                    ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
}

# ================================
# 🚀 INITIALIZATION & SETUP
# ================================

initialize_app() {
    print_header
    
    # Create necessary directories
    mkdir -p "$APP_DIR" "$AUDIO_DIR" "$CONFIG_DIR" "$CACHE_DIR"
    
    check_dependencies
    setup_ollama_models
    
    log_message "Application initialized successfully"
}

check_dependencies() {
    print_status "🔍" "$YELLOW" "Checking dependencies..."
    
    local missing_deps=()
    local required_commands=("python3" "jq" "ffplay")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_status "❌" "$RED" "Missing dependencies: ${missing_deps[*]}"
        print_status "💡" "$YELLOW" "Please install missing packages and try again."
        exit 1
    fi
    
    print_status "✅" "$GREEN" "All core dependencies are satisfied!"
}

setup_ollama_models() {
    if ! command -v ollama &>/dev/null; then
        print_status "📥" "$YELLOW" "Ollama not found! Installing..."
        curl -fsSL https://ollama.com/install.sh | sh
        print_status "✅" "$GREEN" "Ollama installed successfully!"
    fi
    
    # Check and pull models if needed
    check_ollama_model "$CREATIVE_MODEL" "Creative"
    check_ollama_model "$VALIDATOR_MODEL" "Validator"
}

check_ollama_model() {
    local model="$1"
    local model_type="$2"
    
    if ! ollama list | grep -q "$model"; then
        print_status "📥" "$YELLOW" "$model_type model '$model' not found. Pulling..."
        if ollama pull "$model" 2>&1 | while read -r line; do
            echo -e "${BLUE}   ${line}${RESET}"
        done; then
            print_status "✅" "$GREEN" "$model_type model installed successfully!"
        else
            print_status "❌" "$RED" "Failed to pull $model_type model"
            exit 1
        fi
    else
        print_status "✅" "$GREEN" "$model_type model '$model' is ready!"
    fi
}

# ================================
# 🎯 ENHANCED AI FUNCTIONS WITH STREAMING
# ================================

stream_llm_response() {
    local model="$1"
    local prompt="$2"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        print_status "🤖" "$BLUE" "AI is thinking... (Attempt $((retry_count + 1))/$max_retries)"
        
        # Create a temporary file for the response
        local temp_response=$(mktemp)
        
        # Use timeout to prevent hanging and stream the response
        if timeout 300s ollama run "$model" "$prompt" 2>/dev/null | \
           tee "$temp_response" | \
           while IFS= read -r -n1 char; do
               printf "%s" "$char"
               sleep 0.01
           done; then
            
            local response
            response=$(cat "$temp_response")
            rm -f "$temp_response"
            
            if [[ -n "$response" ]]; then
                echo ""
                echo "$response"
                return 0
            fi
        fi
        
        rm -f "$temp_response"
        ((retry_count++))
        print_status "⚠️" "$YELLOW" "AI request failed, retrying in 2 seconds..."
        sleep 2
    done
    
    print_status "❌" "$RED" "Failed to get response from AI after $max_retries attempts"
    return 1
}

# FAST JSON VALIDATION - NO STREAMING, WITH TIMEOUT
validate_json_fast() {
    local broken_json="$1"
    
    print_status "🔧" "$YELLOW" "Quick JSON repair..."
    
    local prompt="Fix this JSON to be valid. Output ONLY the corrected JSON, no explanations. Required fields: story_ru, story_en, vocab, exercises.

JSON to fix:
$broken_json"

    # Use direct ollama call with timeout - NO STREAMING for speed
    timeout 30s ollama run "$VALIDATOR_MODEL" "$prompt" 2>/dev/null || return 1
}

generate_story_with_progress() {
    local topic="$1"
    local difficulty="$2"
    
    case $difficulty in
        beginner)
            local word_count="100-150"
            local level_desc="Beginner (A1)"
            ;;
        intermediate)
            local word_count="200-300" 
            local level_desc="Intermediate (A2-B1)"
            ;;
        advanced)
            local word_count="400-500"
            local level_desc="Advanced (B2-C1)"
            ;;
    esac
    
    print_status "🎨" "$MAGENTA" "Creative AI generating $level_desc story about '$topic'..."
    print_status "📝" "$BLUE" "Target length: $word_count words"
    echo ""
    
    local prompt="Create a Russian language learning story about '$topic' for $difficulty level.

REQUIRED JSON FORMAT:
{
  \"story_ru\": \"Russian text here\",
  \"story_en\": \"English translation here\", 
  \"vocab\": [
    {\"word\": \"russian_word\", \"translation\": \"english_translation\", \"pos\": \"part_of_speech\"}
  ],
  \"exercises\": [
    {\"type\": \"fill-blank\", \"question\": \"Complete the sentence...\", \"answer\": \"correct_answer\"},
    {\"type\": \"true-false\", \"question\": \"Statement in Russian\", \"answer\": true},
    {\"type\": \"comprehension\", \"question\": \"Question in Russian\", \"answer\": \"Answer in Russian\"}
  ]
}

Make it engaging and educational for Russian learners."

    stream_llm_response "$CREATIVE_MODEL" "$prompt"
}

# ================================
# 🎵 AUDIO GENERATION WITH PROGRESS
# ================================

generate_audio_with_progress() {
    local story="$1"
    local filename="$2"
    
    print_status "🔊" "$CYAN" "Setting up audio generation environment..."
    
    local venv_dir="$APP_DIR/audio_venv"
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d "$venv_dir" ]]; then
        print_status "🐍" "$BLUE" "Creating Python virtual environment..."
        if python3 -m venv "$venv_dir" 2>/dev/null; then
            print_status "✅" "$GREEN" "Virtual environment created"
        else
            print_status "❌" "$RED" "Failed to create virtual environment"
            return 1
        fi
    fi
    
    # Install gTTS if not already installed
    if ! "$venv_dir/bin/python" -c "import gtts" 2>/dev/null; then
        print_status "📦" "$BLUE" "Installing gTTS library..."
        if "$venv_dir/bin/pip" install gtts --quiet; then
            print_status "✅" "$GREEN" "gTTS installed successfully"
        else
            print_status "❌" "$RED" "Failed to install gTTS"
            return 1
        fi
    fi
    
    # Generate audio with progress indication
    print_status "🎵" "$CYAN" "Generating audio narration..."
    
    if "$venv_dir/bin/python" -c "
import os
import sys
from gtts import gTTS

try:
    # Ensure directory exists
    os.makedirs(os.path.dirname('$filename'), exist_ok=True)
    
    # Generate audio
    tts = gTTS(text='''$story''', lang='ru', slow=False)
    tts.save('$filename')
    
    # Verify file was created
    if os.path.exists('$filename'):
        file_size = os.path.getsize('$filename')
        print(f'✅ Audio generated successfully ({file_size} bytes)')
        sys.exit(0)
    else:
        print('❌ Audio file was not created')
        sys.exit(1)
        
except Exception as e:
    print(f'❌ Audio generation failed: {e}')
    sys.exit(1)
" 2>&1; then
        print_status "✅" "$GREEN" "Audio generated successfully: $filename"
        return 0
    else
        print_status "❌" "$RED" "Audio generation failed"
        return 1
    fi
}

play_audio_interactive() {
    local audio_file="$1"
    
    if [[ ! -f "$audio_file" ]]; then
        print_status "❌" "$RED" "Audio file not found: $audio_file"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}🎧 Audio Options:${RESET}"
    echo -e "   ${GREEN}1.${RESET} Listen to story"
    echo -e "   ${GREEN}2.${RESET} Skip audio"
    echo -e "   ${GREEN}3.${RESET} Listen and repeat mode"
    
    local choice
    read -rp "Choose option [1-3]: " choice
    
    case $choice in
        1)
            print_status "🔊" "$CYAN" "Playing story... (Press 'q' to stop)"
            if ffplay -nodisp -autoexit "$audio_file" >/dev/null 2>&1; then
                print_status "✅" "$GREEN" "Playback completed"
            else
                print_status "❌" "$RED" "Playback failed"
            fi
            ;;
        2)
            print_status "⏭️" "$YELLOW" "Audio skipped"
            ;;
        3)
            print_status "🔁" "$MAGENTA" "Listen and repeat mode"
            print_status "🔊" "$CYAN" "Playing segment... Repeat after the audio"
            ffplay -nodisp -autoexit "$audio_file" >/dev/null 2>&1
            echo -e "${GREEN}🎤 Your turn to repeat! Press Enter when ready...${RESET}"
            read -r
            ;;
        *)
            print_status "⏭️" "$YELLOW" "Audio skipped"
            ;;
    esac
}

# ================================
# 📚 STORY PROCESSING PIPELINE
# ================================

validate_and_parse_json() {
    local json_output="$1"
    
    # Create cache directory if it doesn't exist
    mkdir -p "$CACHE_DIR"
    local python_script="$CACHE_DIR/json_validator.py"
    
    cat > "$python_script" << 'PYTHON_EOF'
import sys, json, re

def extract_json(text):
    # First, try to find JSON within the text
    json_pattern = r'\{(?:[^{}]|(?:\{(?:[^{}]|(?:\{[^{}]*\}))*\}))*\}'
    matches = re.findall(json_pattern, text, re.DOTALL)
    
    for match in matches:
        try:
            # Try to parse the potential JSON
            obj = json.loads(match)
            # Check if it has our expected structure
            if isinstance(obj, dict) and 'story_ru' in obj:
                return obj
        except:
            continue
    
    return None

def validate_json(text):
    # Try to extract JSON first
    extracted = extract_json(text)
    if extracted:
        # Ensure all required fields exist
        if 'story_ru' not in extracted:
            extracted['story_ru'] = "Story content not available"
        if 'story_en' not in extracted:
            extracted['story_en'] = "Translation not available"
        if 'vocab' not in extracted or not isinstance(extracted.get('vocab'), list):
            extracted['vocab'] = []
        if 'exercises' not in extracted or not isinstance(extracted.get('exercises'), list):
            extracted['exercises'] = []
        
        print(json.dumps(extracted, ensure_ascii=False, indent=2))
        return True
    
    # If no JSON found, try to parse the entire text as JSON
    try:
        # Clean the text
        clean_text = re.sub(r'^```json\s*', '', text, flags=re.IGNORECASE)
        clean_text = re.sub(r'\s*```\s*$', '', clean_text)
        clean_text = clean_text.strip()
        
        obj = json.loads(clean_text)
        # Ensure required fields
        if 'story_ru' not in obj:
            obj['story_ru'] = "Story content not available"
        if 'story_en' not in obj:
            obj['story_en'] = "Translation not available" 
        if 'vocab' not in obj:
            obj['vocab'] = []
        if 'exercises' not in obj:
            obj['exercises'] = []
            
        print(json.dumps(obj, ensure_ascii=False, indent=2))
        return True
    except:
        pass
        
    return False

if __name__ == "__main__":
    input_text = sys.argv[1]
    if not validate_json(input_text):
        sys.exit(1)
PYTHON_EOF

    if python3 "$python_script" "$json_output" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

display_story_content() {
    local valid_json="$1"
    
    local story_ru=$(echo "$valid_json" | jq -r '.story_ru')
    local story_en=$(echo "$valid_json" | jq -r '.story_en')
    local vocab_json=$(echo "$valid_json" | jq -c '.vocab')
    
    echo -e "${GREEN}📖 RUSSIAN STORY:${RESET}"
    echo -e "${WHITE}$story_ru${RESET}"
    echo ""
    
    echo -e "${BLUE}🌍 ENGLISH TRANSLATION:${RESET}"
    echo -e "${WHITE}$story_en${RESET}"
    echo ""
    
    echo -e "${YELLOW}📚 VOCABULARY LIST:${RESET}"
    if [[ "$vocab_json" != "null" ]] && [[ -n "$vocab_json" ]]; then
        echo "$vocab_json" | jq -r '.[]? | "   • \(.word) (\(.pos)) - \(.translation)"' | while read -r line; do
            echo -e "   ${CYAN}$line${RESET}"
        done
    else
        echo -e "   ${YELLOW}No vocabulary provided${RESET}"
    fi
    echo ""
}

display_exercises() {
    local valid_json="$1"
    local exercises_json=$(echo "$valid_json" | jq -c '.exercises')
    
    echo -e "${MAGENTA}🎯 LEARNING EXERCISES:${RESET}"
    if [[ "$exercises_json" != "null" ]] && [[ -n "$exercises_json" ]]; then
        echo "$exercises_json" | jq -r '.[]? | "   🎯 \(.type | ascii_upcase): \(.question)"' | while read -r line; do
            echo -e "   ${MAGENTA}$line${RESET}"
        done
    else
        echo -e "   ${YELLOW}No exercises provided${RESET}"
    fi
    echo ""
    
    echo -e "${CYAN}💡 Tip: Try to complete the exercises before checking the answers!${RESET}"
}

save_story_with_metadata() {
    local json_data="$1"
    local topic="$2"
    local level="$3"
    local audio_file="$4"
    
    local timestamp=$(date +%Y-%m-%d-%H-%M-%S)
    local filename="$APP_DIR/story-${timestamp}.json"
    local archive_dir="$APP_DIR/archive/$(date +%Y/%m)"
    
    mkdir -p "$archive_dir"
    local archive_file="$archive_dir/story-${timestamp}.json"
    
    # Add metadata to JSON
    local enhanced_json=$(echo "$json_data" | jq --arg topic "$topic" \
        --arg level "$level" \
        --arg audio "$audio_file" \
        --arg timestamp "$(date -Iseconds)" \
        '. + {metadata: {topic: $topic, level: $level, audio_file: $audio, created: $timestamp}}')
    
    echo "$enhanced_json" > "$filename"
    echo "$enhanced_json" > "$archive_file"
    
    print_status "💾" "$GREEN" "Story saved:"
    echo -e "   ${CYAN}Primary:${RESET} $filename"
    echo -e "   ${BLUE}Archive:${RESET} $archive_file"
}

# SMART JSON EXTRACTION - handles duplicate JSON output
quick_json_fix() {
    local json_text="$1"
    
    local python_script="$CACHE_DIR/quick_fix.py"
    
    cat > "$python_script" << 'PYTHON_EOF'
import sys, json, re

def extract_best_json(text):
    # Split by ```json markers to find the best JSON block
    parts = re.split(r'```(?:json)?', text)
    
    # Look for the most complete JSON block
    best_json = None
    max_length = 0
    
    for part in parts:
        part = part.strip()
        if not part:
            continue
            
        # Try to find JSON objects in this part
        json_objects = re.findall(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', part, re.DOTALL)
        
        for json_str in json_objects:
            try:
                # Clean common issues
                clean_json = re.sub(r',\s*([}\]])', r'\1', json_str)  # Remove trailing commas
                clean_json = re.sub(r'(\w)\s*\n\s*"', r'\1,\n"', clean_json)  # Add missing commas
                
                obj = json.loads(clean_json)
                # Check if this is a valid story structure
                if 'story_ru' in obj and 'story_en' in obj:
                    # Prefer the longest valid JSON
                    if len(json_str) > max_length:
                        best_json = obj
                        max_length = len(json_str)
            except json.JSONDecodeError:
                # Try with more fixes
                try:
                    # Fix missing quotes in pos fields
                    fixed_json = re.sub(r'"pos":\s*([^,"}\s]+)', r'"pos": "\1"', json_str)
                    # Fix missing commas in arrays
                    fixed_json = re.sub(r'"\s*\n\s*"', '",\n"', fixed_json)
                    obj = json.loads(fixed_json)
                    if 'story_ru' in obj and 'story_en' in obj:
                        if len(json_str) > max_length:
                            best_json = obj
                            max_length = len(json_str)
                except:
                    continue
    
    return best_json

text = sys.argv[1]

# Try to extract the best JSON
extracted = extract_best_json(text)
if extracted:
    # Fix common issues in the extracted JSON
    # Ensure all required fields with proper structure
    if 'vocab' not in extracted or not isinstance(extracted.get('vocab'), list):
        extracted['vocab'] = []
    else:
        # Fix vocab items missing pos quotes
        for item in extracted['vocab']:
            if isinstance(item, dict) and 'pos' in item and not isinstance(item['pos'], str):
                item['pos'] = str(item['pos'])
            elif isinstance(item, dict) and 'pos' not in item:
                item['pos'] = "unknown"
    
    if 'exercises' not in extracted or not isinstance(extracted.get('exercises'), list):
        extracted['exercises'] = []
    
    print(json.dumps(extracted, ensure_ascii=False, indent=2))
    sys.exit(0)

# If extraction fails, try manual parsing of the most likely JSON block
try:
    # Find the longest block that looks like JSON
    json_blocks = re.findall(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', text, re.DOTALL)
    if json_blocks:
        # Take the longest block (most complete)
        longest_block = max(json_blocks, key=len)
        # Apply fixes
        fixed = re.sub(r',\s*([}\]])', r'\1', longest_block)
        fixed = re.sub(r'"pos":\s*([^,"}\s]+)', r'"pos": "\1"', fixed)
        fixed = re.sub(r'(\w)\s*\n\s*"', r'\1,\n"', fixed)
        obj = json.loads(fixed)
        print(json.dumps(obj, ensure_ascii=False, indent=2))
        sys.exit(0)
except:
    pass

sys.exit(1)
PYTHON_EOF

    if python3 "$python_script" "$json_text" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

process_story_generation() {
    local topic="$1"
    local difficulty="$2"
    
    print_header
    echo -e "${CYAN}🚀 Generating Russian Learning Story${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════════${RESET}"
    echo -e "🎭 ${BOLD}Topic:${RESET} ${MAGENTA}$topic${RESET}"
    echo -e "📊 ${BOLD}Level:${RESET} ${YELLOW}$difficulty${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════════${RESET}"
    echo ""
    
    # Step 1: Generate story with streaming
    print_status "1️⃣" "$CYAN" "Step 1: Generating story content..."
    local story_output
    if ! story_output=$(generate_story_with_progress "$topic" "$difficulty"); then
        print_status "❌" "$RED" "Failed to generate story content"
        return 1
    fi
    
         # Step 2: SMART JSON VALIDATION
    print_status "2️⃣" "$YELLOW" "Step 2: Validating JSON structure..."
    local valid_json
    
    # First try direct parsing
    if valid_json=$(validate_and_parse_json "$story_output"); then
        print_status "✅" "$GREEN" "Direct JSON parsing successful"
    else
        print_status "🔍" "$YELLOW" "Direct parse failed, extracting best JSON from AI output..."
        local quick_fixed
        if quick_fixed=$(quick_json_fix "$story_output"); then
            valid_json="$quick_fixed"
            print_status "✅" "$GREEN" "JSON extraction successful"
        else
            print_status "❌" "$RED" "Failed to extract valid JSON"
            print_status "🔄" "$YELLOW" "Trying manual extraction..."
            # Last resort: manually extract the JSON part
            local manual_json=$(echo "$story_output" | grep -o '{.*}' | head -1)
            if [[ -n "$manual_json" ]]; then
                # Basic cleanup
                manual_json=$(echo "$manual_json" | sed 's/,"noun"/, "noun"/g' | sed 's/,"adv"/, "adv"/g')
                if valid_json=$(validate_and_parse_json "$manual_json"); then
                    print_status "✅" "$GREEN" "Manual extraction successful"
                else
                    print_status "❌" "$RED" "All JSON extraction methods failed"
                    return 1
                fi
            else
                print_status "❌" "$RED" "No JSON structure found in AI output"
                return 1
            fi
        fi
    fi
    
    # Step 3: Extract and display content
    print_status "3️⃣" "$BLUE" "Step 3: Processing story content..."
    display_story_content "$valid_json"
    
    # Step 4: Generate audio
    local audio_file="$AUDIO_DIR/$(date +%Y%m%d-%H%M%S)-$topic-$difficulty.mp3"
    local story_ru=$(echo "$valid_json" | jq -r '.story_ru')
    if generate_audio_with_progress "$story_ru" "$audio_file"; then
        # Step 5: Interactive audio
        play_audio_interactive "$audio_file"
    else
        print_status "⚠️" "$YELLOW" "Audio generation failed, but story was saved successfully"
        audio_file=""
    fi
    
    # Step 6: Save story
    save_story_with_metadata "$valid_json" "$topic" "$difficulty" "$audio_file"
    
    # Step 7: Display exercises
    print_status "7️⃣" "$MAGENTA" "Step 7: Learning exercises..."
    display_exercises "$valid_json"
    
    echo ""
    print_status "🎉" "$GREEN" "Lesson completed successfully!"
    echo ""
}

# ================================
# 🎪 ENHANCED USER INTERFACE
# ================================

show_main_menu() {
    print_header
    
    echo -e "${BOLD}🎯 CHOOSE YOUR LEARNING PATH:${RESET}"
    echo ""
    echo -e "   ${GREEN}1.${RESET} 🟢 ${GREEN}Beginner${RESET} (A1) - Simple stories, basic vocabulary"
    echo -e "   ${YELLOW}2.${RESET} 🟡 ${YELLOW}Intermediate${RESET} (A2-B1) - Everyday conversations"
    echo -e "   ${RED}3.${RESET} 🔴 ${RED}Advanced${RESET} (B2-C1) - Complex topics, sophisticated language"
    echo -e "   ${MAGENTA}4.${RESET} 🎲 ${MAGENTA}Surprise Me${RESET} - Random topic & level"
    echo -e "   ${CYAN}5.${RESET} 📊 ${CYAN}Statistics${RESET} - View your progress"
    echo -e "   ${BLUE}6.${RESET} 🎧 ${BLUE}Audio Library${RESET} - Browse previous stories"
    echo -e "   ${WHITE}7.${RESET} 🚪 ${WHITE}Exit${RESET}"
    echo ""
}

show_topic_menu() {
    echo -e "${BOLD}🎭 CHOOSE A TOPIC:${RESET}"
    echo ""
    
    for i in "${!TOPICS[@]}"; do
        local emoji="${TOPIC_EMOJIS[$i]}"
        local topic="${TOPICS[$i]}"
        printf "   ${CYAN}%2d.${RESET} %s %s\n" "$((i+1))" "$emoji" "$topic"
        
        # Two columns layout for better readability
        if (( (i + 1) % 2 == 0 )) || (( i == ${#TOPICS[@]} - 1 )); then
            echo ""
        fi
    done
}

show_statistics() {
    print_header
    echo -e "${CYAN}📊 LEARNING STATISTICS${RESET}"
    echo -e "${BLUE}══════════════════════════${RESET}"
    echo ""
    
    local total_stories=0
    local total_audio=0
    
    if [[ -d "$APP_DIR" ]]; then
        total_stories=$(find "$APP_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
        total_audio=$(find "$AUDIO_DIR" -name "*.mp3" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    echo -e "📁 ${BOLD}Storage Directory:${RESET} ${YELLOW}$APP_DIR${RESET}"
    echo ""
    
    echo -e "📚 ${GREEN}Total Stories:${RESET} ${WHITE}$total_stories${RESET}"
    echo -e "🔊 ${BLUE}Total Audio Files:${RESET} ${WHITE}$total_audio${RESET}"
    echo ""
    
    if [[ $total_stories -gt 0 ]]; then
        echo -e "${BOLD}Recent Stories:${RESET}"
        find "$APP_DIR" -name "*.json" -type f -exec ls -lt {} + 2>/dev/null | head -3 | while read -r line; do
            local file=$(echo "$line" | awk '{print $9}')
            local date=$(echo "$line" | awk '{print $6, $7, $8}')
            echo -e "   ${CYAN}•${RESET} $date - $(basename "$file")"
        done
    fi
    
    echo ""
    read -n 1 -s -r -p "   ${CYAN}Press any key to continue...${RESET}"
}

show_audio_library() {
    print_header
    echo -e "${CYAN}🎧 AUDIO LIBRARY${RESET}"
    echo -e "${BLUE}════════════════════${RESET}"
    echo ""
    
    local audio_files=()
    while IFS= read -r -d $'\0' file; do
        audio_files+=("$file")
    done < <(find "$AUDIO_DIR" -name "*.mp3" -type f -print0 2>/dev/null | sort -zr)
    
    if [[ ${#audio_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No audio files found. Generate some stories first!${RESET}"
        echo ""
        read -n 1 -s -r -p "   ${CYAN}Press any key to continue...${RESET}"
        return
    fi
    
    echo -e "${BOLD}Available Audio Stories:${RESET}"
    echo ""
    
    for i in "${!audio_files[@]}"; do
        local file="${audio_files[$i]}"
        local base_name=$(basename "$file" .mp3)
        echo -e "   ${GREEN}$((i+1)).${RESET} ${base_name}"
    done
    
    echo ""
    echo -e "${CYAN}Enter a number to play, or 'b' to go back:${RESET}"
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#audio_files[@]} ]]; then
        local selected_file="${audio_files[$((choice-1))]}"
        echo ""
        print_status "🔊" "$CYAN" "Playing: $(basename "$selected_file")"
        ffplay -nodisp -autoexit "$selected_file" >/dev/null 2>&1
    fi
}

# Fixed validation functions
validate_menu_choice() {
    [[ "$1" =~ ^[1-7]$ ]]
}

validate_topic_choice() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 ]] && [[ "$1" -le ${#TOPICS[@]} ]]
}

# Simplified user input function
get_user_choice() {
    local prompt="$1"
    local validation_func="$2"
    
    while true; do
        read -p "$prompt" choice
        if $validation_func "$choice"; then
            echo "$choice"
            return 0
        else
            echo -e "${RED}Invalid choice. Please try again.${RESET}" >&2
        fi
    done
}

# ================================
# 🎯 MAIN APPLICATION FLOW
# ================================

main() {
    initialize_app
    
    while true; do
        show_main_menu
        local choice
        choice=$(get_user_choice "Your choice [1-7]:" "validate_menu_choice")
        
        case $choice in
            1) difficulty="beginner" ;;
            2) difficulty="intermediate" ;;
            3) difficulty="advanced" ;;
            4) 
                # Random selection
                local levels=("beginner" "intermediate" "advanced")
                difficulty="${levels[$((RANDOM % 3))]}"
                topic="${TOPICS[$((RANDOM % ${#TOPICS[@]}))]}"
                echo ""
                print_status "🎲" "$MAGENTA" "Surprise selection: $topic ($difficulty)"
                process_story_generation "$topic" "$difficulty"
                continue
                ;;
            5) 
                show_statistics
                continue
                ;;
            6)
                show_audio_library
                continue
                ;;
            7) 
                echo ""
                print_status "👋" "$GREEN" "Спасибо за изучение русского! До встречи!"
                echo ""
                exit 0
                ;;
        esac
        
        show_topic_menu
        local topic_choice
        topic_choice=$(get_user_choice "Choose topic [1-${#TOPICS[@]}]: " "validate_topic_choice")
        
        local topic_index=$((topic_choice - 1))
        topic="${TOPICS[$topic_index]}"
        
        process_story_generation "$topic" "$difficulty"
        
        echo ""
        read -rp "🔄 Generate another story? (y/N): " again
        if [[ ! "$again" =~ ^[Yy]$ ]]; then
            echo ""
            print_status "👋" "$GREEN" "Удачи в изучении русского языка! 🇷🇺"
            echo ""
            break
        fi
    done
}

# ================================
# 🚀 START THE APPLICATION
# ================================

# Handle interrupts gracefully
trap 'echo -e "\n${RED}❌ Script interrupted. Exiting...${RESET}"; exit 1' INT TERM

# Run the application
main "$@"
