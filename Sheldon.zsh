#!/bin/zsh

# Sheldon-like Plugin Manager in Zsh (YAML config with local support)
# Supports global and local (project-specific) plugins

SHELDON_GLOBAL_DIR="${SHELDON_GLOBAL_DIR:-$HOME/.sheldon}"
SHELDON_GLOBAL_PLUGINS_DIR="${SHELDON_GLOBAL_PLUGINS_DIR:-$HOME/.zsh/plugins}"
SHELDON_GLOBAL_CONFIG="${SHELDON_GLOBAL_CONFIG:-$SHELDON_GLOBAL_DIR/plugins.yaml}"

# Local config (overridden by --local flag)
SHELDON_LOCAL_CONFIG=""
SHELDON_LOCAL_PLUGINS_DIR=""

# Colors
autoload -U colors && colors

# Initialize directories and config
sheldon_init() {
    local config_file=$1
    local plugins_dir=$2

    mkdir -p "$plugins_dir"
    mkdir -p "$(dirname "$config_file")"

    # Create default YAML config if missing
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# Sheldon-style YAML plugin configuration
plugins:
  # Examples:
  # - name: zsh-autosuggestions
  #   github: zsh-users/zsh-autosuggestions
  #   branch: master
  #
  # - name: zsh-syntax-highlighting
  #   github: zsh-users/zsh-syntax-highlighting
EOF
    fi
}

# Simple YAML parser for Zsh
sheldon_parse_yaml() {
    local file=$1
    local in_plugins=0
    local current_name=""
    local current_github=""
    local current_branch=""

    [[ ! -f "$file" ]] && return

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Check for plugins: section
        if [[ "$line" =~ ^plugins: ]]; then
            in_plugins=1
            continue
        fi

        if [[ $in_plugins -eq 1 ]]; then
            # New plugin entry (starts with - name:)
            if [[ "$line" =~ ^[[:space:]]*-\ name:[[:space:]]*(.+)$ ]]; then
                # If we have a previous plugin, output it
                if [[ -n "$current_name" && -n "$current_github" ]]; then
                    echo "$current_name|$current_github|${current_branch:-master}"
                fi
                # Start new plugin
                current_name="${match[1]// /}"
                current_github=""
                current_branch="master"
            fi

            # Parse github: field
            if [[ "$line" =~ ^[[:space:]]*github:[[:space:]]*(.+)$ && -n "$current_name" ]]; then
                current_github="${match[1]// /}"
            fi

            # Parse branch: field
            if [[ "$line" =~ ^[[:space:]]*branch:[[:space:]]*(.+)$ && -n "$current_name" ]]; then
                current_branch="${match[1]// /}"
            fi
        fi
    done < "$file"

    # Output the last plugin
    if [[ -n "$current_name" && -n "$current_github" ]]; then
        echo "$current_name|$current_github|${current_branch:-master}"
    fi
}

# Clone or update plugin
sheldon_clone() {
    local name=$1
    local github_path=$2
    local branch=$3
    local plugins_dir=$4
    local url="https://github.com/${github_path}.git"
    local plugin_path="$plugins_dir/$name"

    if [[ -d "$plugin_path" ]]; then
        # Update existing plugin
        (cd "$plugin_path" && git pull --quiet origin "$branch" &>/dev/null)
    else
        # Clone new plugin
        git clone --quiet --depth 1 --branch "$branch" "$url" "$plugin_path" &>/dev/null
    fi
}

# Load plugins (global + local)
sheldon_load() {
    local local_mode=$1

    if [[ "$local_mode" == "local" ]]; then
        # Load only local plugins
        sheldon_load_local
    else
        # Load global plugins first, then local
        sheldon_load_global
        sheldon_load_local
    fi
}

sheldon_load_global() {
    print -P "%F{blue}→ Loading global plugins from $SHELDON_GLOBAL_CONFIG%f"

    local pids=()

    # Parse YAML and clone in parallel
    while IFS='|' read -r name github branch; do
        if [[ -n "$name" && -n "$github" ]]; then
            print -P "%F{green}  ✓%f $name ($branch) [global]"
            sheldon_clone "$name" "$github" "$branch" "$SHELDON_GLOBAL_PLUGINS_DIR" &
            pids+=($!)
        fi
    done <<< "$(sheldon_parse_yaml "$SHELDON_GLOBAL_CONFIG")"

    # Wait for all clones to finish
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    # Source global plugins
    while IFS='|' read -r name github branch; do
        if [[ -n "$name" ]]; then
            sheldon_source_plugin "$name" "$SHELDON_GLOBAL_PLUGINS_DIR" "global"
        fi
    done <<< "$(sheldon_parse_yaml "$SHELDON_GLOBAL_CONFIG")"
}

sheldon_load_local() {
    # Find local .sheldon config in current or parent directories
    local current_dir="$PWD"
    local found_config=""

    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/.sheldon/plugins.yaml" ]]; then
            found_config="$current_dir/.sheldon/plugins.yaml"
            SHELDON_LOCAL_PLUGINS_DIR="$current_dir/.sheldon/plugins"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done

    if [[ -n "$found_config" ]]; then
        SHELDON_LOCAL_CONFIG="$found_config"
        mkdir -p "$SHELDON_LOCAL_PLUGINS_DIR"

        print -P "%F{blue}→ Loading local plugins from $SHELDON_LOCAL_CONFIG%f"

        local pids=()

        # Parse YAML and clone in parallel
        while IFS='|' read -r name github branch; do
            if [[ -n "$name" && -n "$github" ]]; then
                print -P "%F{cyan}  📁%f $name ($branch) [local]"
                sheldon_clone "$name" "$github" "$branch" "$SHELDON_LOCAL_PLUGINS_DIR" &
                pids+=($!)
            fi
        done <<< "$(sheldon_parse_yaml "$SHELDON_LOCAL_CONFIG")"

        # Wait for all clones to finish
        for pid in "${pids[@]}"; do
            wait "$pid"
        done

        # Source local plugins
        while IFS='|' read -r name github branch; do
            if [[ -n "$name" ]]; then
                sheldon_source_plugin "$name" "$SHELDON_LOCAL_PLUGINS_DIR" "local"
            fi
        done <<< "$(sheldon_parse_yaml "$SHELDON_LOCAL_CONFIG")"
    elif [[ "$1" == "strict" ]]; then
        print -P "%F{red}⚠ No local .sheldon/plugins.yaml found in current directory tree%f"
        return 1
    fi
}

sheldon_source_plugin() {
    local name=$1
    local plugins_dir=$2
    local scope=$3
    local plugin_path="$plugins_dir/$name"

    if [[ -f "$plugin_path/$name.plugin.zsh" ]]; then
        source "$plugin_path/$name.plugin.zsh"
        print -P "%F{green}  ✓%f Sourced $name [$scope]"
    elif [[ -f "$plugin_path/$name.zsh" ]]; then
        source "$plugin_path/$name.zsh"
        print -P "%F{green}  ✓%f Sourced $name [$scope]"
    elif [[ -f "$plugin_path/init.zsh" ]]; then
        source "$plugin_path/init.zsh"
        print -P "%F{green}  ✓%f Sourced $name [$scope]"
    else
        print -P "%F{yellow}  ⚠%f $name [$scope] (no init file found)"
    fi
}

# List plugins
sheldon_list() {
    print -P "%F{blue}Global plugins:%f"
    if [[ -d "$SHELDON_GLOBAL_PLUGINS_DIR" ]]; then
        for plugin in "$SHELDON_GLOBAL_PLUGINS_DIR"/*; do
            if [[ -d "$plugin" ]]; then
                local branch=$(cd "$plugin" && git branch --show-current 2>/dev/null)
                print -P "  - %F{cyan}${plugin:t}%f (%F{yellow}$branch%f)"
            fi
        done
    else
        print -P "  %F{red}No global plugins installed. Run 'sheldon load' first.%f"
    fi

    # Check for local plugins
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.sheldon/plugins" ]]; then
            print -P "\n%F{blue}Local plugins (in $current_dir):%f"
            for plugin in "$current_dir/.sheldon/plugins"/*; do
                if [[ -d "$plugin" ]]; then
                    local branch=$(cd "$plugin" && git branch --show-current 2>/dev/null)
                    print -P "  - %F{cyan}${plugin:t}%f (%F{yellow}$branch%f) [local]"
                fi
            done
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done
}

# Update plugins
sheldon_update() {
    # Update global plugins
    print -P "%F{yellow}→ Updating global plugins...%f"
    while IFS='|' read -r name github branch; do
        if [[ -n "$name" ]]; then
            local plugin_path="$SHELDON_GLOBAL_PLUGINS_DIR/$name"
            if [[ -d "$plugin_path" ]]; then
                print -P "%F{green}  ✓%f Updating $name [global]"
                (cd "$plugin_path" && git pull --quiet origin "$branch")
            fi
        fi
    done <<< "$(sheldon_parse_yaml "$SHELDON_GLOBAL_CONFIG")"

    # Update local plugins if present
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/.sheldon/plugins.yaml" ]]; then
            print -P "\n%F{yellow}→ Updating local plugins in $current_dir...%f"
            while IFS='|' read -r name github branch; do
                if [[ -n "$name" ]]; then
                    local plugin_path="$current_dir/.sheldon/plugins/$name"
                    if [[ -d "$plugin_path" ]]; then
                        print -P "%F{cyan}  📁%f Updating $name [local]"
                        (cd "$plugin_path" && git pull --quiet origin "$branch")
                    fi
                fi
            done <<< "$(sheldon_parse_yaml "$current_dir/.sheldon/plugins.yaml")"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done

    print -P "%F{green}✓ Update complete!%f"
}

# Add plugin
sheldon_add() {
    local local_flag=0
    local name=""
    local github=""
    local branch="master"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                local_flag=1
                shift
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                elif [[ -z "$github" ]]; then
                    github="$1"
                else
                    branch="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" || -z "$github" ]]; then
        print -P "%F{red}Usage: sheldon add [--local] <name> <github-user/repo> [branch]%f"
        return 1
    fi

    if [[ $local_flag -eq 1 ]]; then
        # Add to local config
        local local_config="./.sheldon/plugins.yaml"
        mkdir -p "./.sheldon"

        if [[ ! -f "$local_config" ]]; then
            echo "plugins:" > "$local_config"
        fi

        cat >> "$local_config" << EOF

  - name: $name
    github: $github
    branch: $branch
EOF
        print -P "%F{green}✓ Added $name ($github) to local config%f"
        print -P "%F{yellow}Run 'sheldon load --local' to install it%f"
    else
        # Add to global config
        cat >> "$SHELDON_GLOBAL_CONFIG" << EOF

  - name: $name
    github: $github
    branch: $branch
EOF
        print -P "%F{green}✓ Added $name ($github) to global config%f"
        print -P "%F{yellow}Run 'sheldon load' to install it%f"
    fi
}

# Remove plugin
sheldon_remove() {
    local local_flag=0
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                local_flag=1
                shift
                ;;
            *)
                name="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        print -P "%F{red}Usage: sheldon remove [--local] <name>%f"
        return 1
    fi

    if [[ $local_flag -eq 1 ]]; then
        # Remove from local config
        if [[ -f "./.sheldon/plugins.yaml" ]]; then
            sed -i.bak "/- name: $name$/,/branch:/d" "./.sheldon/plugins.yaml"
            rm -rf "./.sheldon/plugins/$name"
            print -P "%F{green}✓ Removed $name from local config%f"
        else
            print -P "%F{red}No local config found%f"
        fi
    else
        # Remove from global config
        sed -i.bak "/- name: $name$/,/branch:/d" "$SHELDON_GLOBAL_CONFIG"
        rm -rf "$SHELDON_GLOBAL_PLUGINS_DIR/$name"
        print -P "%F{green}✓ Removed $name from global config%f"
    fi
}

# Initialize local config in current directory
sheldon_init_local() {
    if [[ -f "./.sheldon/plugins.yaml" ]]; then
        print -P "%F{yellow}Local config already exists%f"
        return 1
    fi

    mkdir -p "./.sheldon"
    cat > "./.sheldon/plugins.yaml" << 'EOF'
# Local project-specific plugins
plugins:
  # Add project-specific plugins here
  # - name: my-project-plugin
  #   github: myuser/myproject-plugin
EOF

    print -P "%F{green}✓ Initialized local config in .sheldon/plugins.yaml%f"
}

# Main CLI
sheldon() {
    case "$1" in
        init)
            if [[ "$2" == "--local" ]]; then
                sheldon_init_local
            else
                sheldon_init "$SHELDON_GLOBAL_CONFIG" "$SHELDON_GLOBAL_PLUGINS_DIR"
                print -P "%F{green}✓ Initialized global config! Edit $SHELDON_GLOBAL_CONFIG%f"
            fi
            ;;
        load)
            if [[ "$2" == "--local" ]]; then
                sheldon_load "local"
            else
                sheldon_init "$SHELDON_GLOBAL_CONFIG" "$SHELDON_GLOBAL_PLUGINS_DIR"
                sheldon_load "global+local"
            fi
            ;;
        list)
            sheldon_list
            ;;
        update)
            sheldon_update
            ;;
        add)
            shift
            sheldon_add "$@"
            ;;
        remove|rm)
            shift
            sheldon_remove "$@"
            ;;
        *)
            print -P "%F{cyan}Sheldon Plugin Manager (with --local support)%f"
            print -P "%F{blue}Commands:%f"
            print "  sheldon init                   - Initialize global config"
            print "  sheldon init --local           - Initialize local config in current dir"
            print "  sheldon load                   - Load global + local plugins"
            print "  sheldon load --local           - Load only local plugins"
            print "  sheldon list                   - List global & local plugins"
            print "  sheldon update                 - Update all plugins"
            print "  sheldon add <name> <repo> [branch]     - Add global plugin"
            print "  sheldon add --local <name> <repo>      - Add local plugin"
            print "  sheldon remove <name>          - Remove global plugin"
            print "  sheldon remove --local <name>  - Remove local plugin"
            ;;
    esac
}

# Auto-load if sourced directly
if [[ "${(%):-%N}" == *"sheldon"* ]]; then
    sheldon load
fi