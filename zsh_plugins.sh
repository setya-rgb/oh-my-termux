#!/data/data/com.termux/files/usr/bin/bash

# Termux-optimized Zsh plugin configuration script
# Colors for Termux
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Termux Zsh Plugin Configuration${NC}"
echo -e "${BLUE}================================${NC}"

# Update packages first (Termux specific)
echo -e "${YELLOW}Updating Termux packages...${NC}"
pkg update -y && pkg upgrade -y

# Install required packages for Termux
echo -e "${YELLOW}Installing required packages...${NC}"
pkg install -y zsh git curl wget

# Install Oh My Zsh (Termux compatible)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${YELLOW}Installing Oh My Zsh for Termux...${NC}"
    # Termux-specific installation (avoid chsh issues)
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
    
    # Copy template config if .zshrc doesn't exist
    if [ ! -f "$HOME/.zshrc" ]; then
        cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
    fi
else
    echo -e "${GREEN}Oh My Zsh already installed${NC}"
fi

# Set custom plugins directory
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
mkdir -p "$PLUGINS_DIR"

# Clone plugins with sparse checkout for Termux (saves space)
clone_plugin() {
    local repo=$1
    local name=$2
    local url="https://github.com/$repo.git"
    
    if [ -d "$PLUGINS_DIR/$name" ]; then
        echo -e "${GREEN}✓ $name already exists${NC}"
    else
        echo -e "${YELLOW}Cloning $name...${NC}"
        git clone --depth 1 "$url" "$PLUGINS_DIR/$name" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $name installed${NC}"
        else
            echo -e "${RED}✗ Failed to clone $name${NC}"
        fi
    fi
}

# Install Termux-optimized plugins
echo -e "\n${BLUE}Installing plugins...${NC}"
clone_plugin "zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
clone_plugin "zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting"
clone_plugin "zsh-users/zsh-completions" "zsh-completions"

# Termux-specific plugin (optional)
clone_plugin "termux/termux-zsh" "termux-zsh"

# Configure .zshrc for Termux
echo -e "\n${BLUE}Configuring .zshrc...${NC}"

# Backup existing .zshrc
if [ -f "$HOME/.zshrc" ]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}Backup created${NC}"
fi

# Set plugins
PLUGINS_LINE="plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions termux-zsh)"

if grep -q "^plugins=" "$HOME/.zshrc"; then
    sed -i "s/^plugins=.*/$PLUGINS_LINE/" "$HOME/.zshrc"
else
    echo "$PLUGINS_LINE" >> "$HOME/.zshrc"
fi

# Termux-specific optimizations
cat >> "$HOME/.zshrc" << 'EOF'

# Termux specific settings
DISABLE_AUTO_UPDATE="true"  # Save data on mobile
DISABLE_UPDATE_PROMPT="true"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Syntax highlighting colors for Termux
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
ZSH_HIGHLIGHT_STYLES[default]=none
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red
ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan
ZSH_HIGHLIGHT_STYLES[alias]=fg=green

# Performance optimizations for mobile
COMPLETION_WAITING_DOTS="true"
LS_COLORS=""
HISTSIZE=1000
SAVEHIST=1000
EOF

# Set Zsh as default shell (Termux specific)
echo -e "\n${YELLOW}Setting Zsh as default shell...${NC}"
if command -v termux-reload-settings &> /dev/null; then
    # Fix for Termux's login shell
    echo "exec zsh" >> "$HOME/.bashrc" 2>/dev/null
    echo -e "${GREEN}Zsh configured as default shell${NC}"
else
    echo -e "${YELLOW}Run 'chsh' manually to set zsh as default if desired${NC}"
fi

echo -e "\n${GREEN}✅ Configuration complete!${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${YELLOW}To apply changes:${NC}"
echo -e "  1. Restart Termux"
echo -e "  2. OR run: ${GREEN}source ~/.zshrc${NC}"
echo -e "  3. OR type: ${GREEN}zsh${NC}"
echo -e "${BLUE}================================${NC}"

# Offer to reload
read -p "Reload Zsh now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    exec zsh
fi