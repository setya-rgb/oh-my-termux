#!/data/data/com.termux/files/usr/bin/bash

# ZSH Setup Script for Termux with Zert
# Run: chmod +x zsh.sh && ./zsh.sh

echo "Setting up ZSH with Zert for Termux..."

# Update packages
echo "Updating packages..."
pkg update -y && pkg upgrade -y

# Install essential packages
echo "Installing required packages..."
pkg install -y zsh git curl wget vim nano \
    termux-api termux-tools \
    openssh tur-repo \
    python nodejs \
    ncdu htop

# Install Oh-My-Zsh (for its library/functions)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh-My-Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh-My-Zsh already installed"
fi

# Create custom .zshrc with Zert bootstrap
echo "Creating .zshrc configuration with Zert..."
cat > "$HOME/.zshrc" << 'EOF'
# ZSH Configuration for Termux with Zert Plugin Manager

# -------------------------------
# Zert Bootstrap (Plugin Manager)
# -------------------------------
ZERT_PLUGINS_DIR="${ZERT_PLUGINS_DIR:-${ZERT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zert}/plugins}"; \
[[ -f "$ZERT_PLUGINS_DIR/zert/zert.zsh" ]] || \
(curl -fsSL https://raw.githubusercontent.com/oxcl/zert/main/bootstrap.sh | zsh); \
source "$ZERT_PLUGINS_DIR/zert/zert.zsh"

# -------------------------------
# Oh-My-Zsh Configuration
# -------------------------------
export ZSH="$HOME/.oh-my-zsh"

# Use OMZ libraries but not its plugin system (Zert handles plugins)
ZSH_DISABLE_COMPFIX=true

# -------------------------------
# Zert Plugins
# -------------------------------
# Core plugins (using Zert's simple syntax)
zert load zsh-users/zsh-autosuggestions
zert load zsh-users/zsh-syntax-highlighting
zert load zsh-users/zsh-history-substring-search

# OMZ plugins (Zert can load them too)
zert load ohmyzsh/ohmyzsh lib/directories
zert load ohmyzsh/ohmyzsh plugins/git
zert load ohmyzsh/ohmyzsh plugins/extract
zert load ohmyzsh/ohmyzsh plugins/sudo
zert load ohmyzsh/ohmyzsh plugins/command-not-found

# Powerlevel10k theme
zert load romkatv/powerlevel10k

# Additional useful plugins
zert load agkozak/zsh-z  # Better directory jumping (replaces 'z' plugin)

# -------------------------------
# Powerlevel10k Settings
# -------------------------------
# Theme is already loaded via zert
[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"

# -------------------------------
# Termux Specific Settings
# -------------------------------
if [[ "$TERMUX_VERSION" != "" ]]; then
    # Disable flow control
    stty -ixon
    
    # Set editor
    export EDITOR="nano"
    
    # Termux-specific aliases
    alias termux-reload="source ~/.zshrc"
    alias termux-update="pkg update && pkg upgrade"
    alias termux-list="pkg list-all"
    alias termux-clear="pkg autoclean"
    
    # Better ls
    alias ls="ls --color=auto"
    alias ll="ls -lah --color=auto"
    alias la="ls -A --color=auto"
    alias l="ls -CF --color=auto"
    
    # Navigation
    alias ..="cd .."
    alias ...="cd ../.."
    alias ....="cd ../../.."
    
    # Quick access directories
    alias downloads="cd ~/storage/downloads"
    alias documents="cd ~/storage/documents"
    alias dcim="cd ~/storage/dcim"
    alias music="cd ~/storage/music"
    alias videos="cd ~/storage/videos"
    
    # Network aliases
    alias myip="curl -s ifconfig.me"
    alias localip="ifconfig wlan0 | grep inet | grep -v inet6 | awk '{print \$2}'"
    
    # Process management
    alias psg="ps aux | grep -v grep | grep -i"
    alias meminfo="free -m -l -t"
    alias ports="netstat -tulanp"
    
    # Quick commands
    alias c="clear"
    alias h="history"
    alias path='echo $PATH | tr ":" "\n"'
fi

# -------------------------------
# History Settings
# -------------------------------
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# -------------------------------
# Completion Settings
# -------------------------------
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# -------------------------------
# Aliases
# -------------------------------
alias cat="batcat 2>/dev/null || cat"
alias grep="grep --color=auto"
alias df="df -h"
alias du="du -h"
alias free="free -h"
alias mkdir="mkdir -pv"

# Git aliases
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline --graph"
alias gd="git diff"

# -------------------------------
# Custom Functions
# -------------------------------
mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz) tar xzf "$1" ;;
            *.bz2) bunzip2 "$1" ;;
            *.rar) unrar x "$1" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xf "$1" ;;
            *.tbz2) tar xjf "$1" ;;
            *.tgz) tar xzf "$1" ;;
            *.zip) unzip "$1" ;;
            *.Z) uncompress "$1" ;;
            *.7z) 7z x "$1" ;;
            *) echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# -------------------------------
# Zert Lockfile (Reproducibility)
# -------------------------------
# After adding/removing plugins, run: zert lock
# This creates ~/.zert.lock to pin exact versions
if [[ -f "$HOME/.zert.lock" ]]; then
    # Lockfile exists, Zert will use it automatically
    :
fi

# Create Zert lockfile on first run
if [[ ! -f "$HOME/.zert.lock" && -f "$ZERT_PLUGINS_DIR/zert/zert.zsh" ]]; then
    echo "Creating Zert lockfile for reproducible environment..."
    zert lock
fi

echo "ZSH with Zert loaded successfully!"
EOF

# Create basic Powerlevel10k config if not exists
if [ ! -f "$HOME/.p10k.zsh" ]; then
    echo "Creating basic Powerlevel10k configuration..."
    cat > "$HOME/.p10k.zsh" << 'EOF'
# Basic Powerlevel10k config for Termux with Zert
() {
    # Powerlevel10k instant prompt
    typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
    
    # Enable/disable segments
    typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs time)
    
    # Style
    typeset -g POWERLEVEL9K_MODE=nerdfont-complete
    typeset -g POWERLEVEL9K_ICON_PADDING=none
    typeset -g POWERLEVEL9K_BACKGROUND=236
    typeset -g POWERLEVEL9K_FOREGROUND=252
    
    # Directory
    typeset -g POWERLEVEL9K_DIR_BACKGROUND=blue
    typeset -g POWERLEVEL9K_DIR_FOREGROUND=black
    typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
    
    # Git
    typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=green
    typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=green
    typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=yellow
    
    # Time
    typeset -g POWERLEVEL9K_TIME_BACKGROUND=black
    typeset -g POWERLEVEL9K_TIME_FOREGROUND=white
    typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
}
EOF
fi

# Configure Termux appearance
echo "Configuring Termux appearance..."
mkdir -p "$HOME/.termux"

# Download Nerd Font for icons
curl -L "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Meslo/M-DZ/complete/Meslo%20LG%20M%20DZ%20Regular%20Nerd%20Font%20Complete.ttf" -o "$HOME/.termux/font.ttf"

# Install bat if available
pkg install -y bat 2>/dev/null || echo "bat not available, skipping"

# Setup storage access
echo "Setting up storage access..."
termux-setup-storage

# Change default shell to zsh
echo "Changing default shell to ZSH..."
chsh -s zsh

# Final message
echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "   1. Restart Termux completely"
echo "   2. Run 'p10k configure' to customize the prompt"
echo "   3. Configure git:"
echo "      git config --global user.name 'Your Name'"
echo "      git config --global user.email 'you@example.com'"
echo ""
echo "Zert Commands:"
echo "   zert list       - List installed plugins"
echo "   zert update     - Update all plugins"
echo "   zert lock       - Create/update lockfile (pin versions)"
echo "   zert clean      - Remove unused plugins"
echo ""
echo "Enjoy ZSH with Zert on Termux!"
echo "Your plugins are locked in ~/.zert.lock for reproducibility"

# Source zshrc if in zsh
if [[ "$SHELL" == *"zsh"* ]]; then
    source "$HOME/.zshrc"
fi