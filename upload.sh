#!/usr/bin/env bash

# ============================================================================
# Bash Plugin Manager (BPM) - Oh-My-Bash Style
# Fixed version - no ShellCheck warnings
# ============================================================================

# Default paths
BPM_DIR="${BPM_DIR:-$HOME/.bpm}"
BPM_CUSTOM_DIR="${BPM_CUSTOM_DIR:-$BPM_DIR/custom}"
BPM_PLUGINS_DIR="${BPM_PLUGINS_DIR:-$BPM_DIR/plugins}"
BPM_THEMES_DIR="${BPM_THEMES_DIR:-$BPM_DIR/themes}"
BPM_CACHE_DIR="${BPM_CACHE_DIR:-$BPM_DIR/cache}"
BPM_LOG_FILE="${BPM_LOG_FILE:-$BPM_DIR/bpm.log}"

# Colors for output - use tput if available for better compatibility
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    BPM_COLOR_RED=$(tput setaf 1)
    BPM_COLOR_GREEN=$(tput setaf 2)
    BPM_COLOR_YELLOW=$(tput setaf 3)
    BPM_COLOR_BLUE=$(tput setaf 4)
    BPM_COLOR_MAGENTA=$(tput setaf 5)
    BPM_COLOR_CYAN=$(tput setaf 6)
    BPM_COLOR_RESET=$(tput sgr0)
else
    BPM_COLOR_RED='\033[0;31m'
    BPM_COLOR_GREEN='\033[0;32m'
    BPM_COLOR_YELLOW='\033[0;33m'
    BPM_COLOR_BLUE='\033[0;34m'
    BPM_COLOR_MAGENTA='\033[0;35m'
    BPM_COLOR_CYAN='\033[0;36m'
    BPM_COLOR_RESET='\033[0m'
fi

# Arrays to store loaded plugins
declare -a BPM_LOADED_PLUGINS=()

# ============================================================================
# Core Functions
# ============================================================================

bpm_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$BPM_LOG_FILE" 2>/dev/null || true
}

bpm_echo() {
    local color="$1"
    local message="$2"
    if [[ -t 1 ]]; then
        echo -e "${color}${message}${BPM_COLOR_RESET}"
    else
        echo "$message"
    fi
}

bpm_error() { bpm_echo "$BPM_COLOR_RED" "❌ ERROR: $1"; bpm_log "ERROR" "$1"; }
bpm_success() { bpm_echo "$BPM_COLOR_GREEN" "✅ $1"; bpm_log "INFO" "$1"; }
bpm_warning() { bpm_echo "$BPM_COLOR_YELLOW" "⚠️  WARNING: $1"; bpm_log "WARN" "$1"; }
bpm_info() { bpm_echo "$BPM_COLOR_BLUE" "ℹ️  $1"; bpm_log "INFO" "$1"; }

# ============================================================================
# Initialization
# ============================================================================

bpm_init() {
    echo ""
    bpm_info "Initializing Bash Plugin Manager..."
    
    # Create directory structure
    local dirs=("$BPM_DIR" "$BPM_CUSTOM_DIR" "$BPM_PLUGINS_DIR" "$BPM_THEMES_DIR" "$BPM_CACHE_DIR")
    local created=0
    local dir
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null
            if [[ -d "$dir" ]]; then
                ((created++))
                bpm_log "INFO" "Created directory: $dir"
            fi
        fi
    done
    
    # Create default plugins.txt if not exists
    if [[ ! -f "$BPM_DIR/plugins.txt" ]]; then
        cat > "$BPM_DIR/plugins.txt" << 'EOF'
# BPM Plugins Configuration
# Format: plugin-name or git-url [plugin-name]
# Example:
# bpm-git
# https://github.com/user/awesome-bash-plugin.git awesome-plugin

EOF
        bpm_success "Created plugins.txt template"
    fi
    
    # Create custom directory structure
    mkdir -p "$BPM_CUSTOM_DIR"/{aliases,functions,lib,completions} 2>/dev/null
    
    bpm_success "BPM initialized successfully"
    echo ""
    bpm_info "Next steps:"
    echo "  1. Add plugins to ~/.bpm/plugins.txt"
    echo "  2. Run 'source ~/.bpm/init.sh' in your .bashrc"
    echo ""
}

# ============================================================================
# Plugin Management
# ============================================================================

bpm_plugin_install() {
    local repo_url="$1"
    local plugin_name="$2"
    
    if [[ -z "$repo_url" ]]; then
        bpm_error "Usage: bpm plugin install <git-url> [plugin-name]"
        return 1
    fi
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        bpm_error "Git is required to install plugins"
        return 1
    fi
    
    # Extract plugin name from URL if not provided
    if [[ -z "$plugin_name" ]]; then
        plugin_name=$(basename "$repo_url" .git)
        plugin_name="${plugin_name#bpm-}"
        plugin_name="${plugin_name#bash-}"
        plugin_name="${plugin_name#plugin-}"
    fi
    
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' already installed"
        return 1
    fi
    
    bpm_info "Installing plugin: $plugin_name"
    bpm_log "INFO" "Cloning $repo_url to $plugin_dir"
    
    if git clone --depth 1 "$repo_url" "$plugin_dir" 2>&1 | tee -a "$BPM_LOG_FILE" >/dev/null; then
        bpm_success "Plugin '$plugin_name' installed successfully"
        
        # Check if plugin has an init script
        if [[ -f "$plugin_dir/init.sh" ]]; then
            bpm_info "Plugin has init.sh script"
        elif [[ -f "$plugin_dir/plugin.sh" ]]; then
            bpm_info "Plugin has plugin.sh script"
        fi
        
        # Add to plugins.txt if not already there
        if ! grep -q "^$plugin_name$" "$BPM_DIR/plugins.txt" 2>/dev/null && \
           ! grep -q "$repo_url" "$BPM_DIR/plugins.txt" 2>/dev/null; then
            echo "$repo_url $plugin_name" >> "$BPM_DIR/plugins.txt"
            bpm_info "Added to plugins.txt"
        fi
        
        return 0
    else
        bpm_error "Failed to install plugin '$plugin_name'"
        rm -rf "$plugin_dir" 2>/dev/null
        return 1
    fi
}

bpm_plugin_load() {
    local plugin_name="$1"
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ ! -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' not found"
        return 1
    fi
    
    # Check if already loaded
    local loaded
    for loaded in "${BPM_LOADED_PLUGINS[@]}"; do
        if [[ "$loaded" == "$plugin_name" ]]; then
            return 0
        fi
    done
    
    # Source plugin files in priority order
    local sourced=false
    local init_files=("init.sh" "plugin.sh" "${plugin_name}.sh" "main.sh")
    local init_file
    
    for init_file in "${init_files[@]}"; do
        if [[ -f "$plugin_dir/$init_file" ]]; then
            bpm_log "INFO" "Loading plugin $plugin_name from $init_file"
            # shellcheck source=/dev/null
            source "$plugin_dir/$init_file" 2>/dev/null && sourced=true
            break
        fi
    done
    
    # If no init file, source all .sh files
    if [[ "$sourced" == false ]]; then
        shopt -s nullglob
        local scripts=("$plugin_dir"/*.sh)
        if [[ ${#scripts[@]} -gt 0 ]]; then
            local script
            bpm_info "Loading all .sh files for $plugin_name"
            for script in "${scripts[@]}"; do
                # shellcheck source=/dev/null
                source "$script" 2>/dev/null
                bpm_log "INFO" "Sourced $script"
            done
            sourced=true
        fi
        shopt -u nullglob
    fi
    
    # Add bin directory to PATH if exists
    if [[ -d "$plugin_dir/bin" ]]; then
        export PATH="$plugin_dir/bin:$PATH"
        bpm_log "INFO" "Added $plugin_dir/bin to PATH"
    fi
    
    BPM_LOADED_PLUGINS+=("$plugin_name")
    bpm_success "Loaded plugin: $plugin_name"
    return 0
}

bpm_plugin_list() {
    echo ""
    bpm_echo "$BPM_COLOR_CYAN" "=== Installed Plugins ==="
    
    if [[ ! -d "$BPM_PLUGINS_DIR" ]] || [[ -z "$(ls -A "$BPM_PLUGINS_DIR" 2>/dev/null)" ]]; then
        bpm_info "No plugins installed"
        echo "  Run 'bpm plugin install <url>' to install plugins"
        echo ""
        return 0
    fi
    
    local count=0
    local plugin
    for plugin in "$BPM_PLUGINS_DIR"/*; do
        if [[ -d "$plugin" ]]; then
            local plugin_name
            plugin_name=$(basename "$plugin")
            local loaded_flag=""
            
            local loaded
            for loaded in "${BPM_LOADED_PLUGINS[@]}"; do
                if [[ "$loaded" == "$plugin_name" ]]; then
                    loaded_flag=" ${BPM_COLOR_GREEN}[loaded]${BPM_COLOR_RESET}"
                    break
                fi
            done
            
            echo "  • $plugin_name$loaded_flag"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        bpm_info "No plugins found"
    fi
    echo ""
}

bpm_plugin_update() {
    local plugin_name="$1"
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ ! -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' not found"
        return 1
    fi
    
    if [[ ! -d "$plugin_dir/.git" ]]; then
        bpm_error "Plugin '$plugin_name' is not a git repository"
        return 1
    fi
    
    bpm_info "Updating plugin: $plugin_name"
    (
        cd "$plugin_dir" || exit
        git pull --rebase 2>&1 | tee -a "$BPM_LOG_FILE"
    )
    
    bpm_success "Plugin '$plugin_name' updated"
}

bpm_plugin_update_all() {
    bpm_info "Updating all plugins..."
    local updated=0
    local plugin_dir
    
    for plugin_dir in "$BPM_PLUGINS_DIR"/*; do
        if [[ -d "$plugin_dir" && -d "$plugin_dir/.git" ]]; then
            local plugin_name
            plugin_name=$(basename "$plugin_dir")
            bpm_plugin_update "$plugin_name"
            ((updated++))
        fi
    done
    
    if [[ $updated -eq 0 ]]; then
        bpm_info "No git-managed plugins to update"
    else
        bpm_success "Updated $updated plugins"
    fi
}

bpm_plugin_remove() {
    local plugin_name="$1"
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ ! -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' not found"
        return 1
    fi
    
    bpm_warning "Removing plugin: $plugin_name"
    rm -rf "$plugin_dir"
    
    # Remove from plugins.txt
    if [[ -f "$BPM_DIR/plugins.txt" ]]; then
        local temp_file
        temp_file=$(mktemp)
        grep -v "^$plugin_name$" "$BPM_DIR/plugins.txt" | grep -v " $plugin_name$" > "$temp_file"
        mv "$temp_file" "$BPM_DIR/plugins.txt"
    fi
    
    # Remove from loaded array
    local new_loaded=()
    local loaded
    for loaded in "${BPM_LOADED_PLUGINS[@]}"; do
        [[ "$loaded" != "$plugin_name" ]] && new_loaded+=("$loaded")
    done
    BPM_LOADED_PLUGINS=("${new_loaded[@]}")
    
    bpm_success "Plugin '$plugin_name' removed"
}

bpm_plugin_search() {
    local query="$1"
    echo ""
    bpm_info "Searching for plugins matching: ${query:-all}"
    
    # Known plugin repositories (could be extended)
    cat << EOF

${BPM_COLOR_CYAN}Available Plugins:${BPM_COLOR_RESET}
  • ${BPM_COLOR_GREEN}bpm-git${BPM_COLOR_RESET} - Git aliases and helpers
  • ${BPM_COLOR_GREEN}bpm-docker${BPM_COLOR_RESET} - Docker utilities and aliases
  • ${BPM_COLOR_GREEN}bpm-kubectl${BPM_COLOR_RESET} - Kubernetes completions and aliases
  • ${BPM_COLOR_GREEN}bpm-aws${BPM_COLOR_RESET} - AWS CLI helpers and completion
  • ${BPM_COLOR_GREEN}bpm-python${BPM_COLOR_RESET} - Python virtualenv wrapper
  • ${BPM_COLOR_GREEN}bpm-node${BPM_COLOR_RESET} - Node.js/NPM utilities
  • ${BPM_COLOR_GREEN}bpm-docker-compose${BPM_COLOR_RESET} - Docker Compose helpers

${BPM_COLOR_YELLOW}Install with:${BPM_COLOR_RESET}
  bpm plugin install https://github.com/bpm-plugins/<plugin-name>.git

EOF
}

# ============================================================================
# Theme Management
# ============================================================================

bpm_theme_list() {
    echo ""
    bpm_echo "$BPM_COLOR_CYAN" "=== Available Themes ==="
    echo "  • ${BPM_COLOR_GREEN}default${BPM_COLOR_RESET} (built-in) - Full prompt with git branch"
    echo "  • ${BPM_COLOR_GREEN}minimal${BPM_COLOR_RESET} (built-in) - Simple prompt"
    echo "  • ${BPM_COLOR_GREEN}powerline${BPM_COLOR_RESET} (built-in) - Powerline-style prompt"
    
    if [[ -d "$BPM_THEMES_DIR" ]]; then
        local theme
        for theme in "$BPM_THEMES_DIR"/*.sh; do
            if [[ -f "$theme" ]]; then
                local theme_name
                theme_name=$(basename "$theme" .sh)
                echo "  • $theme_name"
            fi
        done
    fi
    echo ""
}

bpm_theme_set() {
    local theme_name="$1"
    
    if [[ -z "$theme_name" ]]; then
        bpm_error "Usage: bpm theme set <theme-name>"
        return 1
    fi
    
    case "$theme_name" in
        default)
            _bpm_theme_default
            bpm_success "Theme set to: default"
            ;;
        minimal)
            _bpm_theme_minimal
            bpm_success "Theme set to: minimal"
            ;;
        powerline)
            _bpm_theme_powerline
            bpm_success "Theme set to: powerline"
            ;;
        *)
            if [[ -f "$BPM_THEMES_DIR/$theme_name.sh" ]]; then
                # shellcheck source=/dev/null
                source "$BPM_THEMES_DIR/$theme_name.sh"
                bpm_success "Theme set to: $theme_name"
            else
                bpm_error "Theme '$theme_name' not found"
                return 1
            fi
            ;;
    esac
    
    export BPM_THEME="$theme_name"
}

# Built-in themes
_bpm_theme_default() {
    _bpm_update_prompt() {
        local git_branch=""
        if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
            # Use awk instead of grep for better compatibility
            git_branch=" ($(git branch 2>/dev/null | awk '/^\*/ {print $2}'))"
        fi
        
        local exit_code="$?"
        local exit_color="$BPM_COLOR_GREEN"
        [[ "$exit_code" != 0 ]] && exit_color="$BPM_COLOR_RED"
        
        PS1="\[$BPM_COLOR_CYAN\]\u\[$BPM_COLOR_RESET\]@\[$BPM_COLOR_MAGENTA\]\h\[$BPM_COLOR_RESET\] \[$BPM_COLOR_YELLOW\]\w\[$BPM_COLOR_RESET\]\[$BPM_COLOR_GREEN\]${git_branch}\[$BPM_COLOR_RESET\]\n\[${exit_color}\]\$\[$BPM_COLOR_RESET\] "
    }
    PROMPT_COMMAND="_bpm_update_prompt"
    _bpm_update_prompt
}

_bpm_theme_minimal() {
    PS1="\[$BPM_COLOR_GREEN\]\w\[$BPM_COLOR_RESET\] \\$ "
    PROMPT_COMMAND=""
}

_bpm_theme_powerline() {
    _bpm_powerline_prompt() {
        local git_info=""
        if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
            local branch
            branch=$(git branch 2>/dev/null | awk '/^\*/ {print $2}')
            git_info=" ⎇ $branch"
        fi
        
        PS1="\[$BPM_COLOR_CYAN\]\u@\h\[$BPM_COLOR_RESET\]:\[$BPM_COLOR_YELLOW\]\w\[$BPM_COLOR_GREEN\]${git_info}\[$BPM_COLOR_RESET\]\\$ "
    }
    PROMPT_COMMAND="_bpm_powerline_prompt"
    _bpm_powerline_prompt
}

# ============================================================================
# Plugin Templates
# ============================================================================

bpm_create_plugin() {
    local plugin_name="$1"
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ -z "$plugin_name" ]]; then
        bpm_error "Usage: bpm create-plugin <plugin-name>"
        return 1
    fi
    
    if [[ -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' already exists"
        return 1
    fi
    
    mkdir -p "$plugin_dir"/{bin,lib,completions}
    
    # Create init.sh
    cat > "$plugin_dir/init.sh" << EOF
#!/usr/bin/env bash
# BPM Plugin: $plugin_name
# Description: Auto-generated plugin template

# Prevent multiple sourcing
if [[ -n "\${_BPM_${plugin_name^^}_LOADED:-}" ]]; then
    return 0
fi
readonly _BPM_${plugin_name^^}_LOADED=true

# Plugin variables
export ${plugin_name^^}_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Add to PATH
export PATH="\${${plugin_name^^}_DIR}/bin:\$PATH"

# Main plugin function
${plugin_name}_info() {
    echo "$plugin_name plugin loaded"
}

# Completions directory
if [[ -d "\${${plugin_name^^}_DIR}/completions" ]]; then
    for comp in "\${${plugin_name^^}_DIR}/completions/"*.sh; do
        [[ -f "\$comp" ]] && source "\$comp"
    done
fi

# Initialize
${plugin_name}_init() {
    # Add initialization code here
    echo "✓ $plugin_name initialized"
}

${plugin_name}_init
EOF
    
    chmod +x "$plugin_dir/init.sh"
    
    # Create README
    cat > "$plugin_dir/README.md" << EOF
# $plugin_name

BPM plugin for $plugin_name

## Installation

\`\`\`bash
bpm plugin install <repository-url> $plugin_name
\`\`\`

## Usage

\`\`\`bash
# Add usage examples here
\`\`\`

## Functions

- \`${plugin_name}_info\` - Display plugin information

## License

MIT
EOF
    
    bpm_success "Plugin template created at: $plugin_dir"
    bpm_info "Edit $plugin_dir/init.sh to customize"
}

# ============================================================================
# Configuration Management
# ============================================================================

bpm_load_plugins_from_file() {
    local plugins_file="$BPM_DIR/plugins.txt"
    
    if [[ ! -f "$plugins_file" ]]; then
        return 0
    fi
    
    local loaded_count=0
    local line
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Parse line: can be "plugin-name" or "git-url plugin-name"
        local git_url=""
        local plugin_name="$line"
        
        if [[ "$line" =~ [[:space:]]+ ]]; then
            git_url="${line%% *}"
            plugin_name="${line##* }"
        fi
        
        # Check if plugin directory exists
        if [[ -d "$BPM_PLUGINS_DIR/$plugin_name" ]]; then
            bpm_plugin_load "$plugin_name" 2>/dev/null && ((loaded_count++))
        elif [[ -n "$git_url" && "$git_url" =~ ^(https?://|git@) ]]; then
            bpm_plugin_install "$git_url" "$plugin_name" 2>/dev/null
            bpm_plugin_load "$plugin_name" 2>/dev/null && ((loaded_count++))
        fi
    done < "$plugins_file"
    
    [[ $loaded_count -gt 0 ]] && bpm_success "Loaded $loaded_count plugins from plugins.txt"
}

# ============================================================================
# Utility Functions
# ============================================================================

bpm_info_display() {
    local loaded_count=${#BPM_LOADED_PLUGINS[@]}
    local plugin_count=0
    if [[ -d "$BPM_PLUGINS_DIR" ]]; then
        plugin_count=$(find "$BPM_PLUGINS_DIR" -maxdepth 1 -type d | tail -n +2 | wc -l)
    fi
    
    cat << EOF

${BPM_COLOR_CYAN}═══════════════════════════════════════════════════════════${BPM_COLOR_RESET}
${BPM_COLOR_YELLOW}  Bash Plugin Manager (BPM) - Oh-My-Bash Style${BPM_COLOR_RESET}
${BPM_COLOR_CYAN}═══════════════════════════════════════════════════════════${BPM_COLOR_RESET}

${BPM_COLOR_GREEN}Directories:${BPM_COLOR_RESET}
  • BPM_DIR: $BPM_DIR
  • Plugins: $BPM_PLUGINS_DIR ($plugin_count installed)
  • Themes:  $BPM_THEMES_DIR
  • Custom:  $BPM_CUSTOM_DIR

${BPM_COLOR_GREEN}Loaded Plugins:${BPM_COLOR_RESET} $loaded_count
${BPM_COLOR_GREEN}Current Theme:${BPM_COLOR_RESET} ${BPM_THEME:-default}

${BPM_COLOR_GREEN}Commands:${BPM_COLOR_RESET}
  • bpm plugin install <url> [name]  - Install a plugin
  • bpm plugin list                   - List installed plugins
  • bpm plugin load <name>            - Load a plugin
  • bpm plugin update <name>          - Update a plugin
  • bpm plugin update-all             - Update all plugins
  • bpm plugin remove <name>          - Remove a plugin
  • bpm plugin search [term]          - Search for plugins
  • bpm theme list                    - List available themes
  • bpm theme set <name>              - Set active theme
  • bpm create-plugin <name>          - Create a new plugin
  • bpm init                          - Initialize BPM

${BPM_COLOR_CYAN}═══════════════════════════════════════════════════════════${BPM_COLOR_RESET}

EOF
}

# ============================================================================
# Main CLI Interface
# ============================================================================

bpm() {
    local cmd="$1"
    shift || true
    
    case "$cmd" in
        init)
            bpm_init
            ;;
        plugin|plugins)
            local subcmd="$1"
            shift || true
            case "$subcmd" in
                install)     bpm_plugin_install "$@" ;;
                list)        bpm_plugin_list ;;
                load)        bpm_plugin_load "$@" ;;
                update)      bpm_plugin_update "$@" ;;
                update-all)  bpm_plugin_update_all ;;
                remove|rm)   bpm_plugin_remove "$@" ;;
                search)      bpm_plugin_search "$@" ;;
                *)           bpm_plugin_list ;;
            esac
            ;;
        theme|themes)
            local subcmd="$1"
            shift || true
            case "$subcmd" in
                list)        bpm_theme_list ;;
                set)         bpm_theme_set "$@" ;;
                *)           bpm_theme_list ;;
            esac
            ;;
        create-plugin)
            bpm_create_plugin "$@"
            ;;
        info|status)
            bpm_info_display
            ;;
        help|--help|-h)
            bpm_info_display
            ;;
        *)
            bpm_info_display
            ;;
    esac
}

# ============================================================================
# Create init script for bashrc sourcing
# ============================================================================

_create_init_script() {
    local init_script="$BPM_DIR/init.sh"
    
    cat > "$init_script" << 'EOF'
#!/usr/bin/env bash
# BPM Init Script - Source this in your .bashrc

export BPM_DIR="${BPM_DIR:-$HOME/.bpm}"

# Source BPM if not already loaded
if [[ -f "$BPM_DIR/bpm.sh" ]] && [[ -z "$_BPM_LOADED" ]]; then
    export _BPM_LOADED=true
    source "$BPM_DIR/bpm.sh"
fi

# Load plugins from config
if [[ -f "$BPM_DIR/plugins.txt" ]]; then
    bpm_load_plugins_from_file
fi

# Set default theme if not set
if [[ -z "$BPM_THEME" ]]; then
    bpm_theme_set "default"
fi

# Source custom bashrc if exists
if [[ -f "$BPM_DIR/bashrc" ]] && [[ -z "$BPM_BASHRC_SOURCED" ]]; then
    export BPM_BASHRC_SOURCED=true
    source "$BPM_DIR/bashrc"
fi
EOF
    
    chmod +x "$init_script" 2>/dev/null
}

# ============================================================================
# Auto-loading when script is sourced
# ============================================================================

# Only run auto-loading if script is being sourced, not executed
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Create init script on first load
    if [[ ! -f "$BPM_DIR/init.sh" ]]; then
        _create_init_script
    fi
    
    # Auto-load plugins from plugins.txt
    bpm_load_plugins_from_file
    
    # Set default theme if not set
    if [[ -z "$BPM_THEME" ]]; then
        bpm_theme_set "default"
    fi
fi

# Export main function for subshells
export -f bpm
export -f bpm_plugin_load bpm_theme_set bpm_load_plugins_from_file