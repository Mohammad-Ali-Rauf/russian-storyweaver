#!/bin/bash
#
# Polyglot AI Storyteller - Cloud-Based Language Learning Assistant
# Redesigned version with enhanced UI, multi-language support, and cloud AI
#
# Features:
# - AI-generated stories in Russian, Urdu, and English
# - Cloud-based GPT-OSS model for better performance
# - Streamlined codebase with reduced complexity
# - Modern, responsive user interface
# - Cross-language learning support

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# 🎯 CONFIGURATION & CONSTANTS
# =============================================================================

readonly APP_NAME="Polyglot AI Storyteller"
readonly VERSION="3.0.0"
readonly APP_DIR="${HOME}/.local/share/polyglot-stories"
readonly CONFIG_DIR="${APP_DIR}/config"
readonly CACHE_DIR="${APP_DIR}/cache"
readonly SESSIONS_DIR="${APP_DIR}/sessions"
readonly CONFIG_FILE="${CONFIG_DIR}/app_config.json"
readonly LOG_FILE="${APP_DIR}/app.log"

# Cloud AI Configuration
readonly CLOUD_AI_MODEL="gpt-oss:120b-cloud"
readonly CLOUD_AI_ENDPOINT="http://localhost:11434/api/chat"
readonly AI_TIMEOUT=90
readonly MAX_RETRIES=2

# UI Colors - Modern palette
readonly COLOR_PRIMARY='\033[1;94m'
readonly COLOR_SUCCESS='\033[0;32m'
readonly COLOR_WARNING='\033[1;33m'
readonly COLOR_ERROR='\033[0;31m'
readonly COLOR_INFO='\033[0;36m'
readonly COLOR_TEXT='\033[0;37m'
readonly COLOR_ACCENT='\033[1;35m'
readonly COLOR_RESET='\033[0m'

# Learning Configuration
declare -A LANGUAGES=(
    ["russian"]="🇷🇺 Russian|ru"
    ["urdu"]="🇵🇰 Urdu|ur" 
    ["english"]="🇺🇸 English|en"
)

declare -A LEVELS=(
    ["beginner"]="A1|Simple vocabulary, basic sentences"
    ["intermediate"]="A2-B1|Complex sentences, everyday topics"
    ["advanced"]="B2-C1|Advanced grammar, technical topics"
)

# =============================================================================
# 🛠️ CORE UTILITIES
# =============================================================================

print_header() {
    clear
    echo -e "${COLOR_PRIMARY}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                 ${COLOR_TEXT}Polyglot AI Storyteller${COLOR_PRIMARY} v${VERSION}           ║"
    echo "║               Cloud-Powered Language Learning                   ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
}

print_status() {
    local emoji="$1" message="$2"
    echo -e "${COLOR_INFO}${emoji} ${message}${COLOR_RESET}"
}

print_success() {
    local message="$1"
    echo -e "${COLOR_SUCCESS}✅ ${message}${COLOR_RESET}"
}

print_error() {
    local message="$1"
    echo -e "${COLOR_ERROR}❌ ${message}${COLOR_RESET}" >&2
}

print_warning() {
    local message="$1"
    echo -e "${COLOR_WARNING}⚠️ ${message}${COLOR_RESET}"
}

# =============================================================================
# 🏗️ ENVIRONMENT SETUP
# =============================================================================

setup_environment() {
    print_status "⚙️" "Setting up application environment..."
    
    local dirs=("$APP_DIR" "$CONFIG_DIR" "$CACHE_DIR" "$SESSIONS_DIR")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || {
            print_error "Failed to create directory: $dir"
            return 1
        }
    done

    # Initialize configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        jq -n '{
            language: "russian",
            level: "beginner",
            auto_translate: true,
            daily_goal: 1
        }' > "$CONFIG_FILE"
        print_success "Configuration initialized"
    fi
    
    print_success "Environment setup completed"
}

check_dependencies() {
    print_status "🔍" "Checking dependencies..."
    
    local deps=("curl" "jq" "python3")
    local missing=()
    
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    # Check for Ollama service
    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        print_error "Ollama service not running on localhost:11434"
        print_warning "Please ensure Ollama is installed and running"
        return 1
    fi
    
    print_success "All dependencies verified"
    return 0
}

# =============================================================================
# 🤖 CLOUD AI INTEGRATION
# =============================================================================

call_cloud_ai() {
    local prompt="$1"
    local retry_count=0
    
    # Create a temporary file for the clean response
    local temp_file=$(mktemp)
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        ((retry_count++))
        
        # Print status to stderr
        print_status "🤖" "Attempt $retry_count: Calling AI API..." >&2
        
        # Use jq to create properly formatted JSON
        local json_payload
        json_payload=$(jq -n --arg model "$CLOUD_AI_MODEL" --arg prompt "$prompt" '{
            model: $model,
            messages: [{
                role: "user",
                content: $prompt
            }],
            stream: false
        }')
        
        # Call the API and capture ONLY the response content
        if curl -s -X POST "$CLOUD_AI_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            --max-time $AI_TIMEOUT 2>/dev/null | \
            jq -r '.message.content' 2>/dev/null > "$temp_file"; then
            
            # Check if we got a valid response
            if [[ -s "$temp_file" ]]; then
                cat "$temp_file"
                rm -f "$temp_file"
                return 0
            fi
        fi
        
        [[ $retry_count -lt $MAX_RETRIES ]] && sleep 1
    done
    
    rm -f "$temp_file"
    print_error "AI service unavailable after $MAX_RETRIES attempts" >&2
    return 1
}

generate_story_content() {
    local language="$1" level="$2" topic="$3"
    
    local language_display
    case $language in
        "russian") language_display="Russian" ;;
        "urdu") language_display="Urdu" ;;
        "english") language_display="English" ;;
    esac
    
    print_status "🎨" "Creating $level $language_display story: $topic" >&2
    
    local prompt="Create an engaging $language story for $level language learners about $topic. 
Provide the response as valid JSON with these exact fields:
- story_text: the story in $language
- translation: English translation
- vocabulary: array of objects with word, translation, example
- exercises: array of objects with type, question, answer, options

Make sure the JSON is valid and properly formatted. Return ONLY the JSON without any additional text or markdown code blocks."

    local response
    response=$(call_cloud_ai "$prompt") || return 1
    
    # Debug: Show what we received
    echo "DEBUG: Raw response from AI: $response" >> "$LOG_FILE" 2>/dev/null
    
    # Try to parse the response directly
    if [[ -n "$response" ]]; then
        # Remove any control characters and extra whitespace
        local clean_response=$(echo "$response" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        echo "DEBUG: Cleaned response length: ${#clean_response}" >> "$LOG_FILE" 2>/dev/null
        
        # Validate JSON
        if echo "$clean_response" | jq -e '.' >/dev/null 2>&1; then
            if echo "$clean_response" | jq -e '.story_text and .translation' >/dev/null 2>&1; then
                echo "$clean_response"
                return 0
            else
                echo "DEBUG: Missing required fields" >> "$LOG_FILE" 2>/dev/null
            fi
        else
            echo "DEBUG: Invalid JSON structure" >> "$LOG_FILE" 2>/dev/null
            echo "DEBUG: jq error: $(echo "$clean_response" | jq . 2>&1)" >> "$LOG_FILE" 2>/dev/null
        fi
    fi
    
    # If all else fails, use fallback
    print_warning "AI response validation failed, creating fallback content" >&2
    jq -n --arg lang "$language" --arg topic "$topic" \
    '{
        story_text: "Welcome to your \($lang) lesson about \($topic). This is a sample story for learning.",
        translation: "Welcome to your language lesson. This is a sample story for learning.",
        vocabulary: [
            {word: "welcome", translation: "greeting", example: "Welcome to the lesson."}
        ],
        exercises: [
            {type: "multiple_choice", question: "What is this story about?", answer: "learning", options: ["learning", "working", "playing"]}
        ]
    }'
}

# =============================================================================
# 🎨 MODERN USER INTERFACE
# =============================================================================

show_language_menu() {
    echo -e "${COLOR_PRIMARY}🌍 Select Language${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
    echo ""
    
    local languages=("russian" "urdu" "english")
    local i=1
    for lang in "${languages[@]}"; do
        IFS='|' read -r display code <<< "${LANGUAGES[$lang]}"
        printf "   ${COLOR_TEXT}%d.${COLOR_RESET} %s\n" "$i" "$display"
        ((i++))
    done
    echo ""
}

show_level_menu() {
    echo -e "${COLOR_PRIMARY}📊 Select Difficulty Level${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
    echo ""
    
    local i=1
    for level in "${!LEVELS[@]}"; do
        IFS='|' read -r code description <<< "${LEVELS[$level]}"
        local display_level=$(echo "$level" | sed 's/.*/\u&/')
        printf "   ${COLOR_TEXT}%d.${COLOR_RESET} %s (%s)\n" "$i" "$display_level" "$description"
        ((i++))
    done
    echo ""
}

show_main_menu() {
    print_header
    echo -e "${COLOR_PRIMARY}🎯 Main Menu${COLOR_RESET}"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    echo -e "   ${COLOR_SUCCESS}1. 🆕 New Learning Session${COLOR_RESET}"
    echo -e "   ${COLOR_INFO}2. 🌍 Change Language${COLOR_RESET}"
    echo -e "   ${COLOR_WARNING}3. 📊 Change Level${COLOR_RESET}"
    echo -e "   ${COLOR_TEXT}4. ⚙️ Settings${COLOR_RESET}"
    echo -e "   ${COLOR_ERROR}5. 🚪 Exit${COLOR_RESET}"
    echo ""
}

get_user_choice() {
    local prompt="$1" min="$2" max="$3"
    local choice=""
    
    while true; do
        read -rp "$(echo -e "$prompt")" choice
        
        [[ "$choice" == "q" ]] && { echo "quit"; return 0; }
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= min)) && ((choice <= max)); then
            echo "$choice"
            return 0
        fi
        
        echo -e "${COLOR_ERROR}Please enter a number between $min and $max${COLOR_RESET}" >&2
    done
}

select_language() {
    local current_lang
    current_lang=$(jq -r '.language' "$CONFIG_FILE")
    
    show_language_menu
    local choice
    choice=$(get_user_choice "${COLOR_INFO}Choose language (1-${#LANGUAGES[@]}): ${COLOR_RESET}" 1 "${#LANGUAGES[@]}")
    [[ "$choice" == "quit" ]] && return 1
    
    local languages=("russian" "urdu" "english")
    local selected_lang="${languages[$((choice - 1))]}"
    
    jq --arg lang "$selected_lang" '.language = $lang' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    print_success "Language set to: ${LANGUAGES[$selected_lang]%%|*}"
}

select_level() {
    local current_level
    current_level=$(jq -r '.level' "$CONFIG_FILE")
    
    show_level_menu
    local choice
    choice=$(get_user_choice "${COLOR_INFO}Choose level (1-${#LEVELS[@]}): ${COLOR_RESET}" 1 "${#LEVELS[@]}")
    [[ "$choice" == "quit" ]] && return 1
    
    local levels=("beginner" "intermediate" "advanced")
    local selected_level="${levels[$((choice - 1))]}"
    
    jq --arg level "$selected_level" '.level = $level' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    print_success "Level set to: $selected_level"
}

get_topic() {
    # Clear any previous output and just get the topic
    clear
    print_header
    echo -e "${COLOR_PRIMARY}📝 Enter Story Topic${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
    echo -e "${COLOR_TEXT}Examples: technology, travel, food, sports, animals${COLOR_RESET}"
    echo ""
    
    local topic=""
    while [[ -z "$topic" ]]; do
        read -rp "$(echo -e "${COLOR_INFO}Topic: ${COLOR_RESET}")" topic
        [[ -z "$topic" ]] && echo -e "${COLOR_ERROR}Please enter a topic${COLOR_RESET}" >&2
    done
    
    echo "$topic"
}

# =============================================================================
# 📚 STORY DISPLAY & INTERACTION
# =============================================================================

display_story() {
    local story_json="$1" language="$2" level="$3" topic="$4"
    
    # Validate JSON first with better error reporting
    if ! jq -e '.' <<< "$story_json" >/dev/null 2>&1; then
        print_error "Invalid story data received"
        echo "DEBUG: Invalid JSON: $story_json" >> "$LOG_FILE" 2>/dev/null
        return 1
    fi
    
    # Additional validation for required fields
    if ! jq -e '.story_text and .translation' <<< "$story_json" >/dev/null 2>&1; then
        print_error "Story missing required fields (story_text or translation)"
        echo "DEBUG: Missing fields in: $story_json" >> "$LOG_FILE" 2>/dev/null
        return 1
    fi
    
    print_header
    echo -e "${COLOR_PRIMARY}📖 Learning Session${COLOR_RESET}"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    
    local language_display
    case $language in
        "russian") language_display="🇷🇺 Russian" ;;
        "urdu") language_display="🇵🇰 Urdu" ;;
        "english") language_display="🇺🇸 English" ;;
    esac
    
    echo -e "🌍 ${COLOR_TEXT}Language:${COLOR_RESET} ${COLOR_ACCENT}$language_display${COLOR_RESET}"
    echo -e "📊 ${COLOR_TEXT}Level:${COLOR_RESET} ${COLOR_ACCENT}$level${COLOR_RESET}"
    echo -e "🎭 ${COLOR_TEXT}Topic:${COLOR_RESET} ${COLOR_ACCENT}$topic${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
    echo ""
    
    # Display story text
    local story_text=$(jq -r '.story_text' <<< "$story_json")
    echo -e "${COLOR_SUCCESS}📖 Story:${COLOR_RESET}"
    echo -e "${COLOR_TEXT}$story_text${COLOR_RESET}"
    echo ""
    
    # Display translation
    local translation=$(jq -r '.translation' <<< "$story_json")
    echo -e "${COLOR_INFO}🌍 Translation:${COLOR_RESET}"
    echo -e "${COLOR_TEXT}$translation${COLOR_RESET}"
    echo ""
    
    # Display vocabulary
    echo -e "${COLOR_WARNING}📚 Vocabulary:${COLOR_RESET}"
    jq -r '.vocabulary[]? | "   • \(.word) - \(.translation)"' <<< "$story_json" 2>/dev/null | \
    while IFS= read -r line; do
        echo -e "${COLOR_TEXT}$line${COLOR_RESET}"
    done
    echo ""
    
    # Interactive exercises
    run_exercises "$story_json"
    
    print_success "Lesson completed! Excellent work! 🎉"
}

run_exercises() {
    local story_json="$1"
    local exercises=$(jq -r '.exercises // []' <<< "$story_json")
    local exercise_count=$(jq -r 'length' <<< "$exercises")
    
    [[ $exercise_count -eq 0 ]] && return 0
    
    echo -e "${COLOR_PRIMARY}💪 Practice Exercises${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
    
    local correct_answers=0
    
    for i in $(seq 0 $((exercise_count - 1))); do
        local type=$(jq -r ".[$i].type" <<< "$exercises")
        local question=$(jq -r ".[$i].question" <<< "$exercises")
        local answer=$(jq -r ".[$i].answer" <<< "$exercises")
        
        echo -e "\n${COLOR_TEXT}Exercise $((i + 1))/${exercise_count}:${COLOR_RESET}"
        echo -e "${COLOR_TEXT}Q: $question${COLOR_RESET}"
        
        case $type in
            "multiple_choice")
                local options=$(jq -r ".[$i].options[]" <<< "$exercises" 2>/dev/null | tr '\n' '|')
                if [[ -n "$options" ]]; then
                    echo -e "${COLOR_INFO}Options: $options${COLOR_RESET}" | tr '|' '\n' | sed 's/^/   /'
                fi
                ;;
        esac
        
        echo ""
        read -rp "$(echo -e "${COLOR_INFO}Your answer: ${COLOR_RESET}")" user_answer
        
        if [[ "$user_answer" == "$answer" ]]; then
            echo -e "${COLOR_SUCCESS}✅ Correct!${COLOR_RESET}"
            ((correct_answers++))
        else
            echo -e "${COLOR_ERROR}❌ The answer is: $answer${COLOR_RESET}"
        fi
    done
    
    echo -e "\n${COLOR_PRIMARY}📊 Score: ${correct_answers}/${exercise_count} correct${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
}

# =============================================================================
# ⚙️ SETTINGS MANAGEMENT
# =============================================================================

show_settings() {
    print_header
    echo -e "${COLOR_PRIMARY}⚙️ Settings${COLOR_RESET}"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    
    local language=$(jq -r '.language' "$CONFIG_FILE")
    local level=$(jq -r '.level' "$CONFIG_FILE")
    local auto_translate=$(jq -r '.auto_translate' "$CONFIG_FILE")
    local daily_goal=$(jq -r '.daily_goal' "$CONFIG_FILE")
    
    local language_display
    case $language in
        "russian") language_display="🇷🇺 Russian" ;;
        "urdu") language_display="🇵🇰 Urdu" ;;
        "english") language_display="🇺🇸 English" ;;
    esac
    
    echo -e "🌍 ${COLOR_TEXT}Current Language:${COLOR_RESET} ${COLOR_ACCENT}$language_display${COLOR_RESET}"
    echo -e "📊 ${COLOR_TEXT}Current Level:${COLOR_RESET} ${COLOR_ACCENT}$level${COLOR_RESET}"
    echo -e "🔤 ${COLOR_TEXT}Auto-translate:${COLOR_RESET} ${COLOR_ACCENT}$auto_translate${COLOR_RESET}"
    echo -e "🎯 ${COLOR_TEXT}Daily Goal:${COLOR_RESET} ${COLOR_ACCENT}$daily_goal story/day${COLOR_RESET}"
    
    echo -e "\n${COLOR_INFO}Press any key to continue...${COLOR_RESET}"
    read -n 1 -s
}

# =============================================================================
# 🚀 APPLICATION WORKFLOW
# =============================================================================

start_learning_session() {
    local language level topic
    
    language=$(jq -r '.language' "$CONFIG_FILE")
    level=$(jq -r '.level' "$CONFIG_FILE")
    
    # Get topic first, then show the starting message
    topic=$(get_topic "$language") || return 1
    
    print_status "🚀" "Starting $level $language session: $topic"
    
    local story_content
    story_content=$(generate_story_content "$language" "$level" "$topic") || {
        print_error "Failed to generate story content"
        return 1
    }
    
    display_story "$story_content" "$language" "$level" "$topic"
    return 0
}

main() {
    trap 'echo -e "\n${COLOR_ERROR}🛑 Session interrupted${COLOR_RESET}"; exit 1' INT TERM
    
    print_header
    print_status "⚙️" "Initializing $APP_NAME v$VERSION..."
    
    setup_environment || exit 1
    check_dependencies || exit 1
    
    print_success "Application ready"
    
    # Main application loop
    while true; do
        show_main_menu
        local choice
        choice=$(get_user_choice "${COLOR_INFO}Choose option (1-5): ${COLOR_RESET}" 1 5)
        
        case $choice in
            1)
                if start_learning_session; then
                    print_success "Learning session completed successfully"
                else
                    print_error "Learning session failed"
                fi
                ;;
            2) select_language ;;
            3) select_level ;;
            4) show_settings ;;
            5)
                print_success "Happy learning! 👋"
                exit 0
                ;;
            "quit")
                print_success "Goodbye! 👋"
                exit 0
                ;;
        esac
        
        [[ $choice -ne 5 ]] && {
            echo ""
            read -rp "$(echo -e "${COLOR_INFO}Continue? (Y/n): ${COLOR_RESET}")" continue_choice
            [[ "$continue_choice" =~ ^[Nn]$ ]] && break
        }
    done
    
    print_success "Thank you for learning languages! 🌍"
}

# Run application
main "$@"