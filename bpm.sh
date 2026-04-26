#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONFIG
# -----------------------------------------------------------------------------
BPM_DIR="${HOME}/.bpm"
BPM_PLUGINS="${BPM_DIR}/plugins"

mkdir -p "$BPM_PLUGINS"

# -----------------------------------------------------------------------------
# LOGGING
# -----------------------------------------------------------------------------
bpm::log() { printf "[bpm] %s\n" "$*"; }
bpm::err() { printf "[bpm:error] %s\n" "$*" >&2; }

# -----------------------------------------------------------------------------
# CREATE (local plugin)
# -----------------------------------------------------------------------------
bpm::create() {
    # Usage: bpm::create plugin_name
    local name="${1:-}"

    [ -n "$name" ] || {
        bpm::err "usage: bpm::create <plugin_name>"
        return 1
    }

    local dir="$BPM_PLUGINS/$name"

    if [ -d "$dir" ]; then
        bpm::err "plugin already exists: $name"
        return 1
    fi

    mkdir -p "$dir" || return 1

    # main plugin file
    cat > "$dir/$name.plugin.sh" <<EOF
#!/usr/bin/env bash

# Plugin: $name
# bpm:version "0.1.0"
# bpm:author "unknown"
# bpm:description "$name plugin"

plugins=()

${name}::init() {
    echo "[${name}] loaded"
}

${name}::init
EOF

    # metadata file (optional, kept for compatibility)
    cat > "$dir/plugin.meta" <<EOF
name=$name
version=0.1.0
author=unknown
EOF

    chmod +x "$dir/$name.plugin.sh"

    # git init
    if command -v git >/dev/null 2>&1; then
        git init "$dir" >/dev/null 2>&1
        (
            cd "$dir" || exit 1
            git add . >/dev/null 2>&1
            git commit -m "init $name plugin" >/dev/null 2>&1 || true
        )
        bpm::log "git repo initialized"
    else
        bpm::log "git not found, skipping init"
    fi

    bpm::log "created plugin: $name"
}

# -----------------------------------------------------------------------------
# INSTALL (remote plugin)
# -----------------------------------------------------------------------------
bpm::install() {
    repo="$1"
    [ -n "$repo" ] || { bpm::err "usage: bpm::install user/repo"; return 1; }

    name="${repo##*/}"
    dest="$BPM_PLUGINS/$name"

    if [ -d "$dest" ]; then
        bpm::log "$name already installed"
        return 0
    fi

    git clone "https://github.com/$repo.git" "$dest" || {
        bpm::err "failed to clone $repo"
        return 1
    }

    bpm::log "installed $name"
}

# -----------------------------------------------------------------------------
# ADD (with metadata support)
# -----------------------------------------------------------------------------
bpm::add() {
    # Usage:
    #   bpm::add user/repo              # add remote GitHub plugin
    #   bpm::add /path/to/local/plugin  # add local plugin
    #
    # Plugin metadata format (in entry .sh file):
    #   plugins=(dep1 dep2 dep3)        # dependencies
    #   # bpm:description "Plugin description"
    #   # bpm:version "1.0.0"
    #   # bpm:author "Name"

    [ $# -eq 0 ] && {
        bpm::err "usage: bpm::add <user/repo | /path/to/plugin> [more...]"
        return 1
    }

    local failed=0
    for src in "$@"; do
        # Expand tilde to home directory
        src="${src/#\~/$HOME}"

        # Check if it's a local path (starts with / or .)
        if [[ "$src" =~ ^/ ]] || [[ "$src" =~ ^\. ]]; then
            # Local plugin
            if [ ! -d "$src" ]; then
                bpm::err "local plugin not found: $src"
                failed=1
                continue
            fi

            name="$(basename "$src")"
            dest="$BPM_PLUGINS/$name"

            if [ -d "$dest" ]; then
                bpm::log "plugin already exists: $name"
                continue
            fi

            bpm::log "adding local plugin: $name"
            ln -sf "$(realpath "$src")" "$dest" || {
                bpm::err "failed to link $src"
                failed=1
                continue
            }
            bpm::log "added $name (linked from $src)"

            # Parse metadata
            bpm::_parse_metadata "$dest"
        else
            # Remote GitHub plugin
            if [[ "$src" != */* ]] || [[ "$src" =~ ^/ ]] || [[ "$src" =~ /$ ]]; then
                bpm::err "invalid format: $src (expected user/repo)"
                failed=1
                continue
            fi

            name="${src##*/}"
            dest="$BPM_PLUGINS/$name"

            if [ -d "$dest" ]; then
                bpm::log "plugin already exists: $name"
                continue
            fi

            bpm::log "adding remote plugin: $src"
            git clone --quiet "https://github.com/$src.git" "$dest" || {
                bpm::err "failed to clone $src"
                failed=1
                continue
            }
            bpm::log "added $name"

            # Parse metadata
            bpm::_parse_metadata "$dest"
        fi
    done

    [ $failed -eq 0 ] && return 0 || return 1
}

# -----------------------------------------------------------------------------
# PARSE METADATA
# -----------------------------------------------------------------------------
bpm::_parse_metadata() {
    local plugin_dir="$1"
    local plugin_name="$(basename "$plugin_dir")"

    # Find entry file
    local entry_file=""
    for f in "$plugin_dir"/*.plugin.sh "$plugin_dir"/*.sh; do
        [ -f "$f" ] && entry_file="$f" && break
    done

    [ -z "$entry_file" ] && return 0

    # Parse metadata from comments and arrays
    local description=""
    local version=""
    local author=""
    local dependencies=()

    # Extract metadata from file
    while IFS= read -r line; do
        # Parse plugins=(dep1 dep2 dep3)
        if [[ "$line" =~ ^[[:space:]]*plugins=\(([^)]*)\) ]]; then
            deps_str="${BASH_REMATCH[1]}"
            # Split by whitespace
            read -ra deps <<< "$deps_str"
            dependencies+=("${deps[@]}")
        fi

        # Parse # bpm:description "..."
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*bpm:description[[:space:]]+[\"\']?(.*)[\"\']?$ ]]; then
            description="${BASH_REMATCH[1]}"
        fi

        # Parse # bpm:version "..."
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*bpm:version[[:space:]]+[\"\']?(.*)[\"\']?$ ]]; then
            version="${BASH_REMATCH[1]}"
        fi

        # Parse # bpm:author "..."
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*bpm:author[[:space:]]+[\"\']?(.*)[\"\']?$ ]]; then
            author="${BASH_REMATCH[1]}"
        fi
    done < "$entry_file"

    # Display metadata
    bpm::log "metadata for $plugin_name:"
    [ -n "$version" ] && bpm::log "  version: $version"
    [ -n "$author" ] && bpm::log "  author: $author"
    [ -n "$description" ] && bpm::log "  description: $description"

    # Handle dependencies
    if [ ${#dependencies[@]} -gt 0 ]; then
        bpm::log "  dependencies: ${dependencies[*]}"

        # Check missing dependencies
        local missing=()
        for dep in "${dependencies[@]}"; do
            if [ ! -d "$BPM_PLUGINS/$dep" ]; then
                missing+=("$dep")
            fi
        done

        if [ ${#missing[@]} -gt 0 ]; then
            bpm::log "  missing dependencies: ${missing[*]}"
            read -p "  Install missing dependencies? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for dep in "${missing[@]}"; do
                    bpm::add "$dep"
                done
            fi
        else
            bpm::log "  all dependencies satisfied"
        fi
    fi
}

# -----------------------------------------------------------------------------
# SHOW METADATA (utility function)
# -----------------------------------------------------------------------------
bpm::info() {
    # Usage: bpm::info plugin_name
    [ $# -eq 0 ] && {
        bpm::err "usage: bpm::info <plugin_name>"
        return 1
    }

    for plugin in "$@"; do
        local plugin_dir="$BPM_PLUGINS/$plugin"
        if [ ! -d "$plugin_dir" ]; then
            bpm::err "plugin not found: $plugin"
            continue
        fi

        echo "=== $plugin ==="
        bpm::_parse_metadata "$plugin_dir"
        echo
    done
}

# -----------------------------------------------------------------------------
# LOAD
# -----------------------------------------------------------------------------
bpm::load() {
    for name in "$@"; do
        dir="$BPM_PLUGINS/$name"

        [ -d "$dir" ] || {
            bpm::err "plugin not found: $name"
            continue
        }

        # find plugin entry
        file=""
        for f in "$dir"/*.plugin.sh "$dir"/*.sh; do
            [ -f "$f" ] && file="$f" && break
        done

        if [ -n "$file" ]; then
            # shellcheck disable=SC1090
            source "$file"
            bpm::log "loaded $name"
        else
            bpm::err "no entry file in $name"
        fi
    done
}

# -----------------------------------------------------------------------------
# UPDATE
# -----------------------------------------------------------------------------
bpm::update() {
    for dir in "$BPM_PLUGINS"/*; do
        [ -d "$dir/.git" ] || continue
        (cd "$dir" && git pull --quiet)
        bpm::log "updated $(basename "$dir")"
    done
}

# -----------------------------------------------------------------------------
# LIST
# -----------------------------------------------------------------------------
bpm::list() {
    for dir in "$BPM_PLUGINS"/*; do
        [ -d "$dir" ] || continue
        echo "$(basename "$dir")"
    done
}

# -----------------------------------------------------------------------------
# REMOVE
# -----------------------------------------------------------------------------
bpm::remove() {
    for name in "$@"; do
        rm -rf "$BPM_PLUGINS/$name"
        bpm::log "removed $name"
    done
}

# -----------------------------------------------------------------------------
# FORMAT (shfmt)
# -----------------------------------------------------------------------------
bpm::fmt() {
    # Usage:
    #   bpm::fmt                # format all plugins
    #   bpm::fmt plugin_name   # format one plugin
    #   bpm::fmt file.sh       # format single file

    if ! command -v shfmt >/dev/null 2>&1; then
        bpm::err "shfmt not installed"
        return 1
    fi

    fmt_file() {
        f="$1"
        [ -f "$f" ] || return
        shfmt -w -i 2 -ci "$f"
        bpm::log "formatted $(basename "$f")"
    }

    # no args → format all plugins
    if [ $# -eq 0 ]; then
        for dir in "$BPM_PLUGINS"/*; do
            [ -d "$dir" ] || continue
            find "$dir" -type f -name "*.sh" 2>/dev/null | while read -r f; do
                fmt_file "$f"
            done
        done
        return
    fi

    for arg in "$@"; do
        # case 1: direct file
        if [ -f "$arg" ]; then
            fmt_file "$arg"
            continue
        fi

        # case 2: plugin name
        dir="$BPM_PLUGINS/$arg"
        if [ -d "$dir" ]; then
            find "$dir" -type f -name "*.sh" 2>/dev/null | while read -r f; do
                fmt_file "$f"
            done
        else
            bpm::err "not found: $arg"
        fi
    done
}

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------
bpm::cli() {
    case "${1:-}" in
        create) shift; bpm::create "$@" ;;
        install) shift; bpm::install "$@" ;;
        add) shift; bpm::add "$@" ;;
        load) shift; bpm::load "$@" ;;
        update) shift; bpm::update "$@" ;;
        list) shift; bpm::list "$@" ;;
        remove) shift; bpm::remove "$@" ;;
        info) shift; bpm::info "$@" ;;
        fmt) shift; bpm::fmt "$@" ;;
        *) 
            echo "Usage: bpm {create|install|add|load|update|list|remove|info|fmt}"
            echo "  create <name>     - Create new local plugin"
            echo "  install <repo>    - Install GitHub plugin (user/repo)"
            echo "  add <path|repo>   - Add local or remote plugin"
            echo "  load <plugin>     - Load plugin(s)"
            echo "  update            - Update all plugins"
            echo "  list              - List installed plugins"
            echo "  remove <plugin>   - Remove plugin(s)"
            echo "  info <plugin>     - Show plugin metadata"
            echo "  fmt [plugin|file] - Format plugin code"
            return 1
            ;;
    esac
}

# Run CLI if script is executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && bpm::cli "$@"