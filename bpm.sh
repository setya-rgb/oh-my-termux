#!/usr/bin/env bash

# ============================================================================
# Bash Plugin Manager (BPM) - Oh-My-Bash Style
# ============================================================================

# Default paths
BPM_DIR="${BPM_DIR:-$HOME/.bpm}"
BPM_CUSTOM_DIR="${BPM_CUSTOM_DIR:-$BPM_DIR/custom}"
BPM_PLUGINS_DIR="${BPM_PLUGINS_DIR:-$BPM_DIR/plugins}"
BPM_THEMES_DIR="${BPM_THEMES_DIR:-$BPM_DIR/themes}"
BPM_CACHE_DIR="${BPM_CACHE_DIR:-$BPM_DIR/cache}"
BPM_LOG_FILE="${BPM_LOG_FILE:-$BPM_DIR/bpm.log}"

# Colors for output
declare -r BPM_COLOR_RED='\033[0;31m'
declare -r BPM_COLOR_GREEN='\033[0;32m'
declare -r BPM_COLOR_YELLOW='\033[0;33m'
declare -r BPM_COLOR_BLUE='\033[0;34m'
declare -r BPM_COLOR_MAGENTA='\033[0;35m'
declare -r BPM_COLOR_CYAN='\033[0;36m'
declare -r BPM_COLOR_RESET='\033[0m'

# Arrays to store loaded plugins and themes
declare -a BPM_LOADED_PLUGINS=()
declare -a BPM_LOADED_THEMES=()
declare -a BPM_PLUGIN_PATHS=()

# ============================================================================
# Core Functions
# ============================================================================

bpm_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$BPM_LOG_FILE"
}

bpm_echo() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${BPM_COLOR_RESET}"
}

bpm_error() { bpm_echo "$BPM_COLOR_RED" "❌ ERROR: $1"; bpm_log "ERROR" "$1"; }
bpm_success() { bpm_echo "$BPM_COLOR_GREEN" "✅ $1"; bpm_log "INFO" "$1"; }
bpm_warning() { bpm_echo "$BPM_COLOR_YELLOW" "⚠️  WARNING: $1"; bpm_log "WARN" "$1"; }
bpm_info() { bpm_echo "$BPM_COLOR_BLUE" "ℹ️  $1"; bpm_log "INFO" "$1"; }

# ============================================================================
# Initialization
# ============================================================================

bpm_init() {
    bpm_info "Initializing Bash Plugin Manager..."
    
    # Create directory structure
    local dirs=("$BPM_DIR" "$BPM_CUSTOM_DIR" "$BPM_PLUGINS_DIR" "$BPM_THEMES_DIR" "$BPM_CACHE_DIR")
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            bpm_log "INFO" "Created directory: $dir"
        fi
    done
    
    # Create default bashrc template if not exists
    if [[ ! -f "$BPM_DIR/bashrc" ]]; then
        cat > "$BPM_DIR/bashrc" << 'EOF'
# BPM Managed Bash Configuration

# User customizations
export BPM_THEME="default"

# Custom plugins load
source "$HOME/.bpm/plugins.sh"

# Aliases
alias bpm-list='bpm plugin list'
alias bpm-update='bpm plugin update-all'
alias bpm-search='bpm plugin search'

# Custom aliases directory
if [[ -d "$HOME/.bpm/custom/aliases" ]]; then
    for alias_file in "$HOME/.bpm/custom/aliases/"*.sh; do
        [[ -f "$alias_file" ]] && source "$alias_file"
    done
fi

# Custom functions directory
if [[ -d "$HOME/.bpm/custom/functions" ]]; then
    for func_file in "$HOME/.bpm/custom/functions/"*.sh; do
        [[ -f "$func_file" ]] && source "$func_file"
    done
fi
EOF
        bpm_success "Created default bashrc template"
    fi
    
    bpm_success "BPM initialized successfully"
}

# ============================================================================
# Plugin Management
# ============================================================================

# Clone plugin from git repository
bpm_plugin_install() {
    local repo_url="$1"
    local plugin_name="$2"
    
    if [[ -z "$repo_url" ]]; then
        bpm_error "Usage: bpm plugin install <git-url> [plugin-name]"
        return 1
    fi
    
    # Extract plugin name from URL if not provided
    if [[ -z "$plugin_name" ]]; then
        plugin_name=$(basename "$repo_url" .git)
        plugin_name="${plugin_name#bpm-}"
        plugin_name="${plugin_name#bash-}"
    fi
    
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' already installed"
        return 1
    fi
    
    bpm_info "Installing plugin: $plugin_name"
    bpm_log "INFO" "Cloning $repo_url to $plugin_dir"
    
    if git clone --depth 1 "$repo_url" "$plugin_dir" 2>&1 | tee -a "$BPM_LOG_FILE"; then
        bpm_success "Plugin '$plugin_name' installed successfully"
        
        # Check if plugin has an init script
        if [[ -f "$plugin_dir/init.sh" ]]; then
            bpm_info "Plugin has init.sh script"
        elif [[ -f "$plugin_dir/plugin.sh" ]]; then
            bpm_info "Plugin has plugin.sh script"
        fi
        
        return 0
    else
        bpm_error "Failed to install plugin '$plugin_name'"
        rm -rf "$plugin_dir"
        return 1
    fi
}

# Load a plugin
bpm_plugin_load() {
    local plugin_name="$1"
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ ! -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' not found"
        return 1
    fi
    
    # Check if already loaded
    for loaded in "${BPM_LOADED_PLUGINS[@]}"; do
        if [[ "$loaded" == "$plugin_name" ]]; then
            bpm_warning "Plugin '$plugin_name' already loaded"
            return 0
        fi
    done
    
    # Source plugin files in priority order
    local sourced=false
    local init_files=("init.sh" "plugin.sh" "${plugin_name}.sh" "main.sh")
    
    for init_file in "${init_files[@]}"; do
        if [[ -f "$plugin_dir/$init_file" ]]; then
            bpm_log "INFO" "Loading plugin $plugin_name from $init_file"
            source "$plugin_dir/$init_file"
            sourced=true
            break
        fi
    done
    
    # If no init file, source all .sh files
    if [[ "$sourced" == false ]]; then
        bpm_info "No standard init file found, loading all .sh files for $plugin_name"
        while IFS= read -r -d '' script; do
            source "$script"
            bpm_log "INFO" "Sourced $script"
        done < <(find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0)
        sourced=true
    fi
    
    # Add bin directory to PATH if exists
    if [[ -d "$plugin_dir/bin" ]]; then
        export PATH="$plugin_dir/bin:$PATH"
        bpm_log "INFO" "Added $plugin_dir/bin to PATH"
    fi
    
    BPM_LOADED_PLUGINS+=("$plugin_name")
    bpm_success "Loaded plugin: $plugin_name"
}

# Unload a plugin (limited functionality in bash)
bpm_plugin_unload() {
    local plugin_name="$1"
    bpm_warning "Complete plugin unloading is limited in bash"
    bpm_info "Plugin '$plugin_name' marked as unloaded (functions remain in memory)"
    
    # Remove from loaded plugins array
    local new_loaded=()
    for loaded in "${BPM_LOADED_PLUGINS[@]}"; do
        [[ "$loaded" != "$plugin_name" ]] && new_loaded+=("$loaded")
    done
    BPM_LOADED_PLUGINS=("${new_loaded[@]}")
}

# List installed plugins
bpm_plugin_list() {
    echo ""
    bpm_echo "$BPM_COLOR_CYAN" "=== Installed Plugins ==="
    
    if [[ -z "$(ls -A "$BPM_PLUGINS_DIR" 2>/dev/null)" ]]; then
        bpm_info "No plugins installed"
        return 0
    fi
    
    for plugin in "$BPM_PLUGINS_DIR"/*; do
        if [[ -d "$plugin" ]]; then
            local plugin_name=$(basename "$plugin")
            local loaded_flag=""
            
            for loaded in "${BPM_LOADED_PLUGINS[@]}"; do
                if [[ "$loaded" == "$plugin_name" ]]; then
                    loaded_flag=" ${BPM_COLOR_GREEN}[loaded]${BPM_COLOR_RESET}"
                    break
                fi
            done
            
            echo "  • $plugin_name$loaded_flag"
        fi
    done
    echo ""
}

# Update a specific plugin
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
        cd "$plugin_dir"
        git pull --rebase 2>&1 | tee -a "$BPM_LOG_FILE"
    )
    
    bpm_success "Plugin '$plugin_name' updated"
}

# Update all plugins
bpm_plugin_update_all() {
    bpm_info "Updating all plugins..."
    
    for plugin_dir in "$BPM_PLUGINS_DIR"/*; do
        if [[ -d "$plugin_dir" && -d "$plugin_dir/.git" ]]; then
            local plugin_name=$(basename "$plugin_dir")
            bpm_plugin_update "$plugin_name"
        fi
    done
    
    bpm_success "All plugins updated"
}

# Remove a plugin
bpm_plugin_remove() {
    local plugin_name="$1"
    local plugin_dir="$BPM_PLUGINS_DIR/$plugin_name"
    
    if [[ ! -d "$plugin_dir" ]]; then
        bpm_error "Plugin '$plugin_name' not found"
        return 1
    fi
    
    bpm_warning "Removing plugin: $plugin_name"
    rm -rf "$plugin_dir"
    bpm_success "Plugin '$plugin_name' removed"
}

# Search for plugins (from known repositories)
bpm_plugin_search() {
    local query="$1"
    bpm_info "Searching for plugins matching: $query"
    
    # This would query a registry in a real implementation
    cat << EOF
Known plugin repositories:
  • bpm-git - Git aliases and helpers (github.com/bpm-plugins/bpm-git)
  • bpm-docker - Docker utilities (github.com/bpm-plugins/bpm-docker)
  • bpm-kubectl - Kubernetes completions (github.com/bpm-plugins/bpm-kubectl)
  • bpm-aws - AWS CLI helpers (github.com/bpm-plugins/bpm-aws)
  • bpm-python - Python virtualenv wrapper (github.com/bpm-plugins/bpm-python)
EOF
}

# ============================================================================
# Theme Management
# ============================================================================

bpm_theme_list() {
    echo ""
    bpm_echo "$BPM_COLOR_CYAN" "=== Available Themes ==="
    
    # Built-in themes
    echo "  • default (built-in)"
    echo "  • minimal (built-in)"
    
    # Custom themes
    if [[ -d "$BPM_THEMES_DIR" ]]; then
        for theme in "$BPM_THEMES_DIR"/*.sh; do
            if [[ -f "$theme" ]]; then
                local theme_name=$(basename "$theme" .sh)
                echo "  • $theme_name"
            fi
        done
    fi
    echo ""
}

bpm_theme_set() {
    local theme_name="$1"
    
    if [[ "$theme_name" == "default" ]]; then
        _bpm_theme_default
        bpm_success "Theme set to: default"
    elif [[ "$theme_name" == "minimal" ]]; then
        _bpm_theme_minimal
        bpm_success "Theme set to: minimal"
    elif [[ -f "$BPM_THEMES_DIR/$theme_name.sh" ]]; then
        source "$BPM_THEMES_DIR/$theme_name.sh"
        bpm_success "Theme set to: $theme_name"
    else
        bpm_error "Theme '$theme_name' not found"
        return 1
    fi
    
    export BPM_THEME="$theme_name"
}

# Built-in themes
_bpm_theme_default() {
    # Default prompt with git branch
    PROMPT_COMMAND='_bpm_update_prompt'
    
    _bpm_update_prompt() {
        local git_branch=""
        if git rev-parse --git-dir >/dev/null 2>&1; then
            git_branch=" ($(git branch 2>/dev/null | grep '^*' | colrm 1 2))"
        fi
        
        local exit_code="$?"
        local exit_color="$BPM_COLOR_GREEN"
        [[ "$exit_code" != 0 ]] && exit_color="$BPM_COLOR_RED"
        
        PS1="\[$BPM_COLOR_CYAN\]\u\[$BPM_COLOR_RESET\]@\[$BPM_COLOR_MAGENTA\]\h\[$BPM_COLOR_RESET\] \[$BPM_COLOR_YELLOW\]\w\[$BPM_COLOR_RESET\]\[$BPM_COLOR_GREEN\]${git_branch}\[$BPM_COLOR_RESET\]\n\[${exit_color}\]\$\[$BPM_COLOR_RESET\] "
    }
    _bpm_update_prompt
}

_bpm_theme_minimal() {
    PS1="\[$BPM_COLOR_GREEN\]\w\[$BPM_COLOR_RESET\] \$ "
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
    echo "Initializing $plugin_name..."
    # Add initialization code here
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

bpm_source_config() {
    local config_file="$1"
    
    if [[ -f "$config_file" ]]; then
        bpm_log "INFO" "Sourcing config: $config_file"
        source "$config_file"
    else
        bpm_warning "Config file not found: $config_file"
    fi
}

bpm_load_plugins_from_file() {
    local plugins_file="$BPM_DIR/plugins.txt"
    
    if [[ -f "$plugins_file" ]]; then
        bpm_info "Loading plugins from $plugins_file"
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue
            
            # Format: plugin-name or git-url plugin-name
            local plugin_name="$line"
            if [[ "$line" =~ [[:space:]] ]]; then
                plugin_name="${line##* }"
                line="${line%% *}"
            fi
            
            # Check if plugin directory exists
            if [[ -d "$BPM_PLUGINS_DIR/$plugin_name" ]]; then
                bpm_plugin_load "$plugin_name"
            elif [[ "$line" =~ ^https?:// || "$line" =~ git@ ]]; then
                bpm_plugin_install "$line" "$plugin_name"
                bpm_plugin_load "$plugin_name"
            else
                bpm_warning "Plugin not found: $line"
            fi
        done < "$plugins_file"
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

bpm_info_display() {
    cat << EOF
${BPM_COLOR_CYAN}═══════════════════════════════════════════════════════════${BPM_COLOR_RESET}
${BPM_COLOR_YELLOW}  Bash Plugin Manager (BPM) - Oh-My-Bash Style${BPM_COLOR_RESET}
${BPM_COLOR_CYAN}═══════════════════════════════════════════════════════════${BPM_COLOR_RESET}

${BPM_COLOR_GREEN}Directories:${BPM_COLOR_RESET}
  • BPM_DIR: $BPM_DIR
  • Plugins: $BPM_PLUGINS_DIR
  • Themes:  $BPM_THEMES_DIR
  • Custom:  $BPM_CUSTOM_DIR

${BPM_COLOR_GREEN}Loaded Plugins:${BPM_COLOR_RESET} ${#BPM_LOADED_PLUGINS[@]}
${BPM_COLOR_GREEN}Current Theme:${BPM_COLOR_RESET} ${BPM_THEME:-default}

${BPM_COLOR_GREEN}Commands:${BPM_COLOR_RESET}
  • bpm plugin install <url> [name]  - Install a plugin
  • bpm plugin list                   - List installed plugins
  • bpm plugin load <name>            - Load a plugin
  • bpm plugin update <name>          - Update a plugin
  • bpm plugin update-all             - Update all plugins
  • bpm plugin remove <name>          - Remove a plugin
  • bpm plugin search <term>          - Search for plugins
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
                install)   bpm_plugin_install "$@" ;;
                list)      bpm_plugin_list ;;
                load)      bpm_plugin_load "$@" ;;
                unload)    bpm_plugin_unload "$@" ;;
                update)    bpm_plugin_update "$@" ;;
                update-all) bpm_plugin_update_all ;;
                remove|rm) bpm_plugin_remove "$@" ;;
                search)    bpm_plugin_search "$@" ;;
                *)         bpm_plugin_list ;;
            esac
            ;;
        theme|themes)
            local subcmd="$1"
            shift || true
            case "$subcmd" in
                list)      bpm_theme_list ;;
                set)       bpm_theme_set "$@" ;;
                *)         bpm_theme_list ;;
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
# Auto-loading
# ============================================================================

# Auto-load plugins from plugins.txt if it exists
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

# Export main function for subshells
export -f bpm