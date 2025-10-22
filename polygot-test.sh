#!/bin/bash
#
# Polyglot AI Storyteller - Cloud-Based Language Learning Assistant
# Redesigned version with enhanced UI, multi-language support, and cloud AI
# Production-ready with SQLite database
#
# Features:
# - AI-generated stories in Russian, Urdu, and English
# - Cloud-based GPT-OSS model for better performance
# - SQLite database for persistent storage
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
readonly DB_FILE="${APP_DIR}/stories.db"

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
# 🗄️ DATABASE MANAGEMENT
# =============================================================================

init_database() {
    print_status "🗄️" "Initializing database..."
    
    # Create schema if database doesn't exist
    if [[ ! -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" << 'EOF'
-- Users table to track learning progress
CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_active DATETIME DEFAULT CURRENT_TIMESTAMP,
    total_stories INTEGER DEFAULT 0,
    total_exercises INTEGER DEFAULT 0,
    preferred_language TEXT DEFAULT 'russian',
    preferred_level TEXT DEFAULT 'beginner'
);

-- Stories table to store generated content
CREATE TABLE IF NOT EXISTS stories (
    story_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    session_id TEXT NOT NULL,
    language TEXT NOT NULL,
    level TEXT NOT NULL,
    topic TEXT NOT NULL,
    title TEXT,
    story_text TEXT NOT NULL,
    translation TEXT NOT NULL,
    word_count INTEGER DEFAULT 0,
    reading_time_minutes INTEGER DEFAULT 1,
    ai_model_used TEXT DEFAULT 'gpt-oss:120b-cloud',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (session_id) REFERENCES users(session_id)
);

-- Vocabulary table for word tracking
CREATE TABLE IF NOT EXISTS vocabulary (
    vocab_id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id INTEGER NOT NULL,
    word TEXT NOT NULL,
    translation TEXT NOT NULL,
    example_sentence TEXT,
    language TEXT NOT NULL,
    difficulty_level TEXT DEFAULT 'beginner',
    times_encountered INTEGER DEFAULT 1,
    last_encountered DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (story_id) REFERENCES stories(story_id)
);

-- Exercises table
CREATE TABLE IF NOT EXISTS exercises (
    exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id INTEGER NOT NULL,
    exercise_type TEXT NOT NULL CHECK (exercise_type IN ('multiple_choice', 'fill_blank', 'matching', 'translation')),
    question TEXT NOT NULL,
    correct_answer TEXT NOT NULL,
    options JSON,
    user_answer TEXT,
    is_correct BOOLEAN,
    completed_at DATETIME,
    FOREIGN KEY (story_id) REFERENCES stories(story_id)
);

-- User progress tracking
CREATE TABLE IF NOT EXISTS user_progress (
    progress_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_id TEXT NOT NULL,
    language TEXT NOT NULL,
    level TEXT NOT NULL,
    stories_completed INTEGER DEFAULT 0,
    exercises_completed INTEGER DEFAULT 0,
    correct_answers INTEGER DEFAULT 0,
    total_time_minutes INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 0,
    last_study_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (session_id) REFERENCES users(session_id),
    UNIQUE(user_id, language, level)
);

-- Learning sessions table
CREATE TABLE IF NOT EXISTS learning_sessions (
    session_id TEXT PRIMARY KEY,
    user_id INTEGER,
    language TEXT NOT NULL,
    level TEXT NOT NULL,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    duration_minutes INTEGER DEFAULT 0,
    stories_generated INTEGER DEFAULT 0,
    exercises_completed INTEGER DEFAULT 0,
    accuracy_rate REAL DEFAULT 0.0,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Schema version table
CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_stories_user_language ON stories(user_id, language);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at);
CREATE INDEX IF NOT EXISTS idx_vocabulary_language_word ON vocabulary(language, word);
CREATE INDEX IF NOT EXISTS idx_exercises_story_type ON exercises(story_id, exercise_type);
CREATE INDEX IF NOT EXISTS idx_user_progress_language_level ON user_progress(language, level);
CREATE INDEX IF NOT EXISTS idx_learning_sessions_time ON learning_sessions(start_time);

-- Initialize schema version
INSERT OR IGNORE INTO schema_version (version) VALUES (1);
EOF
        print_success "Database schema created"
    fi
    
    print_success "Database initialized successfully"
}

sqlite3_escape() {
    local str="$1"
    # Escape single quotes for SQLite
    echo "$str" | sed "s/'/''/g"
}

db_insert_story() {
    local session_id="$1" language="$2" level="$3" topic="$4" story_json="$5"
    
    local user_id=$(sqlite3 "$DB_FILE" "SELECT user_id FROM users WHERE session_id = '$session_id';" 2>/dev/null || echo "")
    
    # Create user if doesn't exist
    if [[ -z "$user_id" ]]; then
        user_id=$(sqlite3 "$DB_FILE" "
            INSERT INTO users (session_id) VALUES ('$session_id');
            SELECT last_insert_rowid();
        " 2>/dev/null)
    fi
    
    # Insert story
    local story_id=$(sqlite3 "$DB_FILE" "
        INSERT INTO stories (user_id, session_id, language, level, topic, story_text, translation, word_count)
        VALUES (
            $user_id, 
            '$session_id', 
            '$language', 
            '$level', 
            '$(sqlite3_escape "$topic")',
            '$(sqlite3_escape "$(jq -r '.story_text' <<< "$story_json")")',
            '$(sqlite3_escape "$(jq -r '.translation' <<< "$story_json")")',
            $(jq -r '.story_text | length' <<< "$story_json")
        );
        SELECT last_insert_rowid();
    " 2>/dev/null)
    
    # Insert vocabulary
    jq -r '.vocabulary[]? | [.word, .translation, .example] | @tsv' <<< "$story_json" 2>/dev/null | \
    while IFS=$'\t' read -r word translation example; do
        if [[ -n "$word" && -n "$translation" ]]; then
            sqlite3 "$DB_FILE" "
                INSERT INTO vocabulary (story_id, word, translation, example_sentence, language)
                VALUES (
                    $story_id,
                    '$(sqlite3_escape "$word")',
                    '$(sqlite3_escape "$translation")',
                    '$(sqlite3_escape "$example")',
                    '$language'
                );
            " 2>/dev/null
        fi
    done
    
    # Insert exercises
    local exercise_count=$(jq -r '.exercises | length' <<< "$story_json" 2>/dev/null || echo "0")
    for i in $(seq 0 $((exercise_count - 1)) 2>/dev/null); do
        local type=$(jq -r ".exercises[$i].type" <<< "$story_json" 2>/dev/null)
        local question=$(jq -r ".exercises[$i].question" <<< "$story_json" 2>/dev/null)
        local answer=$(jq -r ".exercises[$i].answer" <<< "$story_json" 2>/dev/null)
        local options=$(jq -c ".exercises[$i].options" <<< "$story_json" 2>/dev/null)
        
        if [[ -n "$type" && -n "$question" && -n "$answer" ]]; then
            sqlite3 "$DB_FILE" "
                INSERT INTO exercises (story_id, exercise_type, question, correct_answer, options)
                VALUES (
                    $story_id,
                    '$type',
                    '$(sqlite3_escape "$question")',
                    '$(sqlite3_escape "$answer")',
                    '$(sqlite3_escape "$options")'
                );
            " 2>/dev/null
        fi
    done
    
    # Update user stats
    sqlite3 "$DB_FILE" "
        UPDATE users 
        SET total_stories = total_stories + 1,
            last_active = CURRENT_TIMESTAMP
        WHERE user_id = $user_id;
    " 2>/dev/null
    
    echo "$story_id"
}

db_record_exercise_result() {
    local exercise_id="$1" user_answer="$2" is_correct="$3"
    
    sqlite3 "$DB_FILE" "
        UPDATE exercises 
        SET user_answer = '$(sqlite3_escape "$user_answer")',
            is_correct = $is_correct,
            completed_at = CURRENT_TIMESTAMP
        WHERE exercise_id = $exercise_id;
    " 2>/dev/null
    
    # Update user progress
    sqlite3 "$DB_FILE" "
        INSERT OR REPLACE INTO user_progress (user_id, session_id, language, level, exercises_completed, correct_answers, updated_at)
        SELECT 
            u.user_id,
            u.session_id,
            s.language,
            s.level,
            COALESCE(up.exercises_completed, 0) + 1,
            COALESCE(up.correct_answers, 0) + $is_correct,
            CURRENT_TIMESTAMP
        FROM exercises e
        JOIN stories s ON e.story_id = s.story_id
        JOIN users u ON s.user_id = u.user_id
        LEFT JOIN user_progress up ON u.user_id = up.user_id AND s.language = up.language AND s.level = up.level
        WHERE e.exercise_id = $exercise_id;
    " 2>/dev/null
}

db_get_user_stats() {
    local session_id="$1"
    
    sqlite3 -json "$DB_FILE" "
        SELECT 
            u.total_stories,
            u.total_exercises,
            up.language,
            up.level,
            up.streak_days,
            up.correct_answers,
            up.exercises_completed,
            (up.correct_answers * 100.0 / NULLIF(up.exercises_completed, 0)) as accuracy_percentage
        FROM users u
        LEFT JOIN user_progress up ON u.user_id = up.user_id
        WHERE u.session_id = '$session_id'
    " 2>/dev/null | jq -r '.[0] // {}' 2>/dev/null || echo "{}"
}

db_get_vocabulary_list() {
    local session_id="$1" language="$2" limit="${3:-20}"
    
    sqlite3 -json "$DB_FILE" "
        SELECT 
            v.word,
            v.translation,
            v.example_sentence,
            COUNT(DISTINCT v.story_id) as times_encountered,
            AVG(CASE WHEN e.is_correct THEN 1.0 ELSE 0.0 END) as mastery_rate
        FROM vocabulary v
        JOIN stories s ON v.story_id = s.story_id
        JOIN users u ON s.user_id = u.user_id
        LEFT JOIN exercises e ON s.story_id = e.story_id
        WHERE u.session_id = '$session_id' AND v.language = '$language'
        GROUP BY v.word, v.translation
        ORDER BY times_encountered DESC, mastery_rate ASC
        LIMIT $limit
    " 2>/dev/null | jq -r '.' 2>/dev/null || echo "[]"
}

generate_session_id() {
    if command -v openssl >/dev/null 2>&1; then
        echo "session_$(date +%s)_$(openssl rand -hex 8 2>/dev/null)"
    else
        echo "session_$(date +%s)_${RANDOM}${RANDOM}${RANDOM}"
    fi
}

get_current_session_id() {
    if [[ -f "${SESSIONS_DIR}/current_session" ]]; then
        cat "${SESSIONS_DIR}/current_session" 2>/dev/null
    else
        local new_session=$(generate_session_id)
        echo "$new_session" > "${SESSIONS_DIR}/current_session"
        echo "$new_session"
    fi
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
        }' > "$CONFIG_FILE" 2>/dev/null || {
            print_error "Failed to create configuration file"
            return 1
        }
        print_success "Configuration initialized"
    fi
    
    # Initialize database
    init_database || {
        print_error "Failed to initialize database"
        return 1
    }
    
    print_success "Environment setup completed"
}

check_dependencies() {
    print_status "🔍" "Checking dependencies..."
    
    local deps=("curl" "jq" "sqlite3")
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
    echo -e "   ${COLOR_TEXT}4. 📈 View Statistics${COLOR_RESET}"
    echo -e "   ${COLOR_TEXT}5. 📚 Vocabulary List${COLOR_RESET}"
    echo -e "   ${COLOR_TEXT}6. ⚙️ Settings${COLOR_RESET}"
    echo -e "   ${COLOR_ERROR}7. 🚪 Exit${COLOR_RESET}"
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
    current_lang=$(jq -r '.language' "$CONFIG_FILE" 2>/dev/null || echo "russian")
    
    show_language_menu
    local choice
    choice=$(get_user_choice "${COLOR_INFO}Choose language (1-${#LANGUAGES[@]}): ${COLOR_RESET}" 1 "${#LANGUAGES[@]}")
    [[ "$choice" == "quit" ]] && return 1
    
    local languages=("russian" "urdu" "english")
    local selected_lang="${languages[$((choice - 1))]}"
    
    jq --arg lang "$selected_lang" '.language = $lang' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE" 2>/dev/null
    
    print_success "Language set to: ${LANGUAGES[$selected_lang]%%|*}"
}

select_level() {
    local current_level
    current_level=$(jq -r '.level' "$CONFIG_FILE" 2>/dev/null || echo "beginner")
    
    show_level_menu
    local choice
    choice=$(get_user_choice "${COLOR_INFO}Choose level (1-${#LEVELS[@]}): ${COLOR_RESET}" 1 "${#LEVELS[@]}")
    [[ "$choice" == "quit" ]] && return 1
    
    local levels=("beginner" "intermediate" "advanced")
    local selected_level="${levels[$((choice - 1))]}"
    
    jq --arg level "$selected_level" '.level = $level' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE" 2>/dev/null
    
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
    local session_id=$(get_current_session_id)
    
    # Validate JSON
    if ! jq -e '.' <<< "$story_json" >/dev/null 2>&1; then
        print_error "Invalid story data received"
        return 1
    fi
    
    # Store in database
    local story_id
    story_id=$(db_insert_story "$session_id" "$language" "$level" "$topic" "$story_json") || {
        print_error "Failed to save story to database"
        return 1
    }
    
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
    echo -e "📚 ${COLOR_TEXT}Story ID:${COLOR_RESET} ${COLOR_ACCENT}#$story_id${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
    echo ""
    
    # Display story content
    local story_text=$(jq -r '.story_text' <<< "$story_json")
    echo -e "${COLOR_SUCCESS}📖 Story:${COLOR_RESET}"
    echo -e "${COLOR_TEXT}$story_text${COLOR_RESET}"
    echo ""
    
    local translation=$(jq -r '.translation' <<< "$story_json")
    echo -e "${COLOR_INFO}🌍 Translation:${COLOR_RESET}"
    echo -e "${COLOR_TEXT}$translation${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_WARNING}📚 Vocabulary:${COLOR_RESET}"
    jq -r '.vocabulary[]? | "   • \(.word) - \(.translation)"' <<< "$story_json" 2>/dev/null | \
    while IFS= read -r line; do
        echo -e "${COLOR_TEXT}$line${COLOR_RESET}"
    done
    echo ""
    
    # Run exercises with database tracking
    run_exercises_with_tracking "$story_id" "$story_json"
    
    print_success "Lesson completed! Excellent work! 🎉"
}

run_exercises_with_tracking() {
    local story_id="$1" story_json="$2"
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
        
        # Get exercise ID from database
        local exercise_id=$(sqlite3 "$DB_FILE" "
            SELECT exercise_id FROM exercises 
            WHERE story_id = $story_id AND question = '$(sqlite3_escape "$question")'
            LIMIT 1;
        " 2>/dev/null)
        
        if [[ "$user_answer" == "$answer" ]]; then
            echo -e "${COLOR_SUCCESS}✅ Correct!${COLOR_RESET}"
            ((correct_answers++))
            db_record_exercise_result "$exercise_id" "$user_answer" 1
        else
            echo -e "${COLOR_ERROR}❌ The answer is: $answer${COLOR_RESET}"
            db_record_exercise_result "$exercise_id" "$user_answer" 0
        fi
    done
    
    echo -e "\n${COLOR_PRIMARY}📊 Score: ${correct_answers}/${exercise_count} correct${COLOR_RESET}"
    echo "──────────────────────────────────────────────────────────────────"
}

# =============================================================================
# 📊 STATISTICS & VOCABULARY VIEWS
# =============================================================================

show_stats_menu() {
    local session_id=$(get_current_session_id)
    local stats=$(db_get_user_stats "$session_id")
    
    print_header
    echo -e "${COLOR_PRIMARY}📊 Learning Statistics${COLOR_RESET}"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ "$stats" != "{}" ]]; then
        local total_stories=$(jq -r '.total_stories' <<< "$stats")
        local total_exercises=$(jq -r '.exercises_completed' <<< "$stats")
        local accuracy=$(jq -r '.accuracy_percentage' <<< "$stats")
        local streak=$(jq -r '.streak_days' <<< "$stats")
        
        echo -e "📚 ${COLOR_TEXT}Stories Completed:${COLOR_RESET} ${COLOR_ACCENT}${total_stories:-0}${COLOR_RESET}"
        echo -e "💪 ${COLOR_TEXT}Exercises Completed:${COLOR_RESET} ${COLOR_ACCENT}${total_exercises:-0}${COLOR_RESET}"
        echo -e "🎯 ${COLOR_TEXT}Accuracy:${COLOR_RESET} ${COLOR_ACCENT}${accuracy:-0}%${COLOR_RESET}"
        echo -e "🔥 ${COLOR_TEXT}Current Streak:${COLOR_RESET} ${COLOR_ACCENT}${streak:-0} days${COLOR_RESET}"
    else
        echo -e "${COLOR_INFO}No learning data yet. Complete your first story!${COLOR_RESET}"
    fi
    
    echo ""
    echo -e "${COLOR_INFO}Press any key to continue...${COLOR_RESET}"
    read -n 1 -s
}

show_vocabulary_menu() {
    local current_lang
    current_lang=$(jq -r '.language' "$CONFIG_FILE" 2>/dev/null || echo "russian")
    
    print_header
    echo -e "${COLOR_PRIMARY}📚 Vocabulary List${COLOR_RESET}"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    
    local vocab_list=$(db_get_vocabulary_list "$(get_current_session_id)" "$current_lang" 50)
    
    if [[ "$vocab_list" != "[]" && "$vocab_list" != "null" ]]; then
        echo "$vocab_list" | jq -r '.[] | "\(.word) - \(.translation) (\(.times_encountered)x))"' 2>/dev/null | \
        while IFS= read -r line; do
            echo -e "   ${COLOR_TEXT}•${COLOR_RESET} $line"
        done
    else
        echo -e "${COLOR_INFO}No vocabulary recorded yet. Complete some stories first!${COLOR_RESET}"
    fi
    
    echo ""
    echo -e "${COLOR_INFO}Press any key to continue...${COLOR_RESET}"
    read -n 1 -s
}

# =============================================================================
# ⚙️ SETTINGS MANAGEMENT
# =============================================================================

show_settings() {
    print_header
    echo -e "${COLOR_PRIMARY}⚙️ Settings${COLOR_RESET}"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    
    local language=$(jq -r '.language' "$CONFIG_FILE" 2>/dev/null || echo "russian")
    local level=$(jq -r '.level' "$CONFIG_FILE" 2>/dev/null || echo "beginner")
    local auto_translate=$(jq -r '.auto_translate' "$CONFIG_FILE" 2>/dev/null || echo "true")
    local daily_goal=$(jq -r '.daily_goal' "$CONFIG_FILE" 2>/dev/null || echo "1")
    
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
    
    language=$(jq -r '.language' "$CONFIG_FILE" 2>/dev/null || echo "russian")
    level=$(jq -r '.level' "$CONFIG_FILE" 2>/dev/null || echo "beginner")
    
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
        choice=$(get_user_choice "${COLOR_INFO}Choose option (1-7): ${COLOR_RESET}" 1 7)
        
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
            4) show_stats_menu ;;
            5) show_vocabulary_menu ;;
            6) show_settings ;;
            7)
                print_success "Happy learning! 👋"
                exit 0
                ;;
            "quit")
                print_success "Goodbye! 👋"
                exit 0
                ;;
        esac
        
        [[ $choice -ne 7 ]] && {
            echo ""
            read -rp "$(echo -e "${COLOR_INFO}Press Enter to continue... ${COLOR_RESET}")" continue_choice
        }
    done
    
    print_success "Thank you for learning languages! 🌍"
}

# Run application
main "$@"