#!/bin/bash

# Neovim Installation Script for Termux (Android)
# Optimized for mobile/ARM64 environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running in Termux
check_termux() {
    if [[ -z "$PREFIX" ]] || [[ ! -d "/data/data/com.termux" ]]; then
        print_error "This script is designed for Termux only!"
        print_error "Please install Termux from F-Droid or Google Play Store first."
        exit 1
    fi
    print_msg "Termux environment detected"
}

# Update packages
update_packages() {
    print_step "Updating package lists..."
    pkg update -y && pkg upgrade -y
}

# Install dependencies
install_dependencies() {
    print_step "Installing required dependencies..."
    
    # Essential packages for Termux
    local packages=(
        neovim
        python
        nodejs
        git
        curl
        wget
        ripgrep
        fzf
        tree
        openssh
        which
        file
        findutils
        make
        cmake
        clang
        binutils
    )
    
    for pkg in "${packages[@]}"; do
        if ! pkg list-installed | grep -q "^$pkg$"; then
            print_msg "Installing $pkg..."
            pkg install -y $pkg
        else
            print_msg "$pkg already installed"
        fi
    done
}

# Setup storage access (optional)
setup_storage() {
    print_step "Setting up storage access..."
    if [[ ! -d "$HOME/storage" ]]; then
        print_msg "Granting storage permissions..."
        termux-setup-storage
        print_warning "Please grant storage permission when prompted"
        sleep 3
    else
        print_msg "Storage already configured"
    fi
}

# Create Neovim config directory
setup_config_dir() {
    print_step "Creating Neovim configuration directory..."
    
    NVIM_CONFIG_DIR="$HOME/.config/nvim"
    NVIM_DATA_DIR="$HOME/.local/share/nvim"
    
    if [ -d "$NVIM_CONFIG_DIR" ]; then
        print_warning "Existing config found. Backing up to $NVIM_CONFIG_DIR.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$NVIM_CONFIG_DIR"
    mkdir -p "$NVIM_CONFIG_DIR/lua"
    mkdir -p "$NVIM_CONFIG_DIR/lua/plugins"
    mkdir -p "$NVIM_CONFIG_DIR/after/ftplugin"
    mkdir -p "$NVIM_CONFIG_DIR/spell"
    
    print_msg "Configuration directories created"
}

# Create optimized init.lua for Termux
create_init_lua() {
    print_step "Creating optimized init.lua for Termux..."
    
    cat > "$HOME/.config/nvim/init.lua" << 'EOF'
-- Neovim configuration optimized for Termux (Android)
-- Lightweight and mobile-friendly

-- Set leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic settings (optimized for mobile)
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.undodir = os.getenv("HOME") .. "/.local/share/nvim/undo"
vim.opt.undofile = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 5
vim.opt.sidescrolloff = 5
vim.opt.signcolumn = 'yes'

-- Performance optimizations for Termux
vim.opt.timeoutlen = 500
vim.opt.ttimeoutlen = 50
vim.opt.updatetime = 300
vim.opt.lazyredraw = true
vim.opt.synmaxcol = 200

-- Disable unused features for speed
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_matchparen = 1

-- Key mappings (optimized for touch keyboards)
vim.keymap.set('n', '<C-h>', '<C-w>h')
vim.keymap.set('n', '<C-j>', '<C-w>j')
vim.keymap.set('n', '<C-k>', '<C-w>k')
vim.keymap.set('n', '<C-l>', '<C-w>l')

-- Quick save and quit
vim.keymap.set('n', '<leader>w', ':w<CR>')
vim.keymap.set('n', '<leader>q', ':q<CR>')
vim.keymap.set('n', '<leader>x', ':x<CR>')

-- Clear search highlights
vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>')

-- Better navigation with j/k (faster scrolling)
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')

-- Open file explorer
vim.keymap.set('n', '<leader>e', ':Explore<CR>')

-- Terminal toggle
vim.keymap.set('n', '<leader>t', ':belowright terminal<CR>')

-- Bootstrap lazy.nvim (lightweight plugin manager)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Minimal plugins for Termux
require("lazy").setup({
    spec = {
        {import = "plugins"},
    },
    defaults = {
        lazy = true,
        version = false,
    },
    install = {
        colorscheme = {"habamax"},
    },
    performance = {
        cache = {
            enabled = true,
        },
        rtp = {
            disabled_plugins = {
                "gzip",
                "matchit",
                "matchparen",
                "netrwPlugin",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
    checker = {
        enabled = false,
    },
})

-- Set theme
vim.cmd.colorscheme("habamax")

-- Print welcome message
print("Neovim ready! Type :Lazy to manage plugins")
EOF
}

# Create minimal plugin configuration for Termux
create_plugin_config() {
    print_step "Creating lightweight plugin configuration for Termux..."
    
    cat > "$HOME/.config/nvim/lua/plugins/init.lua" << 'EOF'
-- Lightweight plugins for Termux
return {
    -- Better file explorer (netrw is already there, but this is nicer)
    {
        "echasnovski/mini.files",
        version = false,
        config = function()
            require("mini.files").setup()
            vim.keymap.set('n', '<leader>e', ':MiniFiles<CR>')
        end,
    },
    
    -- Mini statusline (lightweight)
    {
        "echasnovski/mini.statusline",
        version = false,
        config = function()
            require("mini.statusline").setup()
        end,
    },
    
    -- Better syntax highlighting (optional)
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = { "lua", "vim", "python", "bash", "markdown" },
                auto_install = true,
                highlight = {
                    enable = true,
                    additional_vim_regex_highlighting = false,
                },
            })
        end,
    },
    
    -- Fuzzy finder for Termux
    {
        "ibhagwan/fzf-lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("fzf-lua").setup()
            vim.keymap.set('n', '<leader>ff', ':FzfLua files<CR>')
            vim.keymap.set('n', '<leader>fg', ':FzfLua live_grep<CR>')
            vim.keymap.set('n', '<leader>fb', ':FzfLua buffers<CR>')
        end,
    },
    
    -- Git integration (optional, only if needed)
    {
        "lewis6991/gitsigns.nvim",
        optional = true,
        config = function()
            require("gitsigns").setup()
        end,
    },
    
    -- Simple commenting
    {
        "echasnovski/mini.comment",
        version = false,
        config = function()
            require("mini.comment").setup()
            vim.keymap.set('n', 'gc', function() require('mini.comment').toggle_lines(vim.v.count1) end)
            vim.keymap.set('v', 'gc', function() require('mini.comment').toggle_selection() end)
        end,
    },
    
    -- Pair management
    {
        "echasnovski/mini.pairs",
        version = false,
        config = function()
            require("mini.pairs").setup()
        end,
    },
    
    -- Surround plugin
    {
        "echasnovski/mini.surround",
        version = false,
        config = function()
            require("mini.surround").setup()
        end,
    },
}
EOF
}

# Create .termux configuration for better keyboard
setup_termux_properties() {
    print_step "Configuring Termux keyboard enhancements..."
    
    if [[ ! -d "$HOME/.termux" ]]; then
        mkdir -p "$HOME/.termux"
    fi
    
    # Configure extra keys row
    cat > "$HOME/.termux/termux.properties" << 'EOF'
# Extra keys configuration for better Neovim experience
extra-keys = [['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']]

# Enable bell/vibrate
bell-character = ignore

# Use volume keys to move cursor
volume-keys = cursor

# Enable fullscreen keyboard
fullscreen = true

# Use custom font size
font-size = 12
EOF
    
    print_msg "Termux properties configured. Restart Termux for changes to take effect."
}

# Create custom aliases for Termux
create_aliases() {
    print_step "Creating shell aliases for Termux..."
    
    BASHRC="$HOME/.bashrc"
    
    if ! grep -q "# Neovim aliases" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'

# Neovim aliases for Termux
alias vim="nvim"
alias vi="nvim"
alias nv="nvim"
alias nvc="nvim ~/.config/nvim/init.lua"
alias vimrc="nvim ~/.config/nvim/init.lua"

# Quick commands
alias nupdate="pkg update && pkg upgrade"
alias nclean="pkg autoclean"
EOF
        print_msg "Aliases added to $BASHRC"
    else
        print_msg "Aliases already exist"
    fi
}

# Create a simple help file
create_help_file() {
    print_step "Creating Neovim help file..."
    
    cat > "$HOME/.config/nvim/TERMUX_HELP.md" << 'EOF'
# Neovim on Termux - Quick Help

## Basic Commands
- `:w` - Save file
- `:q` - Quit
- `:wq` - Save and quit
- `:q!` - Quit without saving
- `:e filename` - Open file

## Custom Key Mappings
- `<leader>w` - Save (leader is spacebar)
- `<leader>q` - Quit
- `<leader>e` - Open file explorer
- `<leader>t` - Open terminal
- `Ctrl + h/j/k/l` - Navigate between splits
- `j/k` - Move by visual lines (wrapped text)

## Plugin Management
- `:Lazy` - Open plugin manager
- `:Lazy sync` - Install/update plugins
- `:Lazy clean` - Remove unused plugins

## Tips for Touch Keyboard
- Use the extra keys row (ESC, CTRL, ALT, arrow keys)
- Double-tap for special characters
- Volume keys can move cursor (if configured)

## Performance Tips
- Keep plugin list minimal
- Use mini.nvim plugins (already configured)
- Disable treesitter for large files
- Use `:Lazy profile` to check plugin load times

## File Locations
- Config: ~/.config/nvim/init.lua
- Plugins: ~/.config/nvim/lua/plugins/
- Data: ~/.local/share/nvim/
EOF

    print_msg "Help file created at ~/.config/nvim/TERMUX_HELP.md"
}

# Main installation function
main() {
    clear
    echo "======================================"
    echo "   Neovim Installer for Termux"
    echo "   Optimized for Android"
    echo "======================================"
    echo ""
    
    check_termux
    update_packages
    install_dependencies
    setup_storage
    setup_config_dir
    create_init_lua
    create_plugin_config
    setup_termux_properties
    create_aliases
    create_help_file
    
    print_msg ""
    print_msg "======================================"
    print_msg "Neovim installation complete!"
    print_msg "======================================"
    print_msg ""
    print_msg "Next steps:"
    print_msg "1. Restart Termux: Exit and reopen the app"
    print_msg "2. Run 'nvim' to start Neovim"
    print_msg "3. Wait for plugins to install (first launch only)"
    print_msg "4. View help: :help or read ~/.config/nvim/TERMUX_HELP.md"
    print_msg ""
    print_msg "Tips:"
    print_msg "- Use the extra keyboard row (ESC, CTRL, arrows)"
    print_msg "- Volume keys can move cursor (if configured)"
    print_msg "- Long press for special characters"
    print_msg ""
    
    # Apply termux properties
    termux-reload-settings 2>/dev/null || print_warning "Please restart Termux to apply keyboard settings"
}

# Run main function
main