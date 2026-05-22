#!/bin/bash

# Android SDK and NDK installer script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# URLs
SDK_URL="https://github.com/Keyaru-code/android-sdk-termux/releases/download/35.0.0/android-sdk.7z"
NDK_URL="https://github.com/Keyaru-code/android-sdk-termux/releases/download/35.0.0/android-ndk.7z"

# Directories
TMP_DIR="$TMPDIR/android-sdk-install"
INSTALL_DIR="$PREFIX/opt"
SDK_DIR="$INSTALL_DIR/android-sdk"
NDK_DIR="$INSTALL_DIR/android-ndk"

# Java Home - Correct Termux OpenJDK path
JAVA_HOME_DIR="$PREFIX/lib/jvm/java-21-openjdk"

# Shell configuration files
BASHRC="$PREFIX/etc/bash.bashrc"
ZSHRC="$HOME/.zshrc"
FISH_CONFIG="$HOME/.config/fish/config.fish"

# Dependencies
DEPS=("openjdk-21" "gradle" "p7zip")

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_dependencies() {
    log_info "Checking dependencies..."

    for dep in "${DEPS[@]}"; do
        if pkg list-installed | grep -q "$dep"; then
            log_info "✓ $dep is installed"
        else
            log_warning "$dep is not installed, installing..."
            pkg install -y "$dep" || log_error "Failed to install $dep"
        fi
    done

    # Verify Java installation
    if [ ! -d "$JAVA_HOME_DIR" ]; then
        log_error "Java installation not found at $JAVA_HOME_DIR"
    fi
}

download_and_extract() {
    local url="$1"
    local output_dir="$2"
    local filename
    local tmp_file
    
    filename=$(basename "$url")
    tmp_file="$TMP_DIR/$filename"

    log_info "Downloading $filename..."
    curl -L "$url" -o "$tmp_file" || log_error "Failed to download $filename"

    log_info "Extracting $filename to $output_dir..."
    7z x "$tmp_file" -o"$output_dir" -y > /dev/null || log_error "Failed to extract $filename"

    rm -f "$tmp_file"
}

setup_environment() {
    log_info "Setting up environment variables..."

    # Common environment variables
    export ANDROID_HOME="$SDK_DIR"
    export ANDROID_NDK_HOME="$NDK_DIR"
    export ANDROID_NDK_ROOT="$NDK_DIR"
    export JAVA_HOME="$JAVA_HOME_DIR"
    export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_NDK_HOME:$PATH"

    # Detect shell and update configuration files
    detect_shell_and_update
}

detect_shell_and_update() {
    # Always update Termux bashrc
    update_shell_config "$BASHRC" "bash"

    # Update other shells if they exist
    if [ -f "$ZSHRC" ]; then
        update_shell_config "$ZSHRC" "zsh"
    fi

    if [ -f "$FISH_CONFIG" ]; then
        update_shell_config "$FISH_CONFIG" "fish"
    fi
}

update_shell_config() {
    local config_file="$1"
    local shell_name="$2"

    # Remove existing Android/Java environment variables
    remove_existing_env "$config_file" "$shell_name"

    # Add new environment variables using a single redirect
    {
        echo ""
        echo "# Android SDK and NDK paths"
        
        if [ "$shell_name" = "fish" ]; then
            echo "set -x ANDROID_HOME \"$SDK_DIR\""
            echo "set -x ANDROID_NDK_HOME \"$NDK_DIR\""
            echo "set -x ANDROID_NDK_ROOT \"$NDK_DIR\""
            echo "set -x JAVA_HOME \"$JAVA_HOME_DIR\""
            echo "set -x PATH \"\$JAVA_HOME/bin\" \$PATH"
            echo "set -x PATH \"\$ANDROID_HOME/cmdline-tools/latest/bin\" \$PATH"
            echo "set -x PATH \"\$ANDROID_HOME/platform-tools\" \$PATH"
            echo "set -x PATH \"\$ANDROID_NDK_HOME\" \$PATH"
        else
            echo "export ANDROID_HOME=\"$SDK_DIR\""
            echo "export ANDROID_NDK_HOME=\"$NDK_DIR\""
            echo "export ANDROID_NDK_ROOT=\"$NDK_DIR\""
            echo "export JAVA_HOME=\"$JAVA_HOME_DIR\""
            echo "export PATH=\"\$JAVA_HOME/bin:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_NDK_HOME:\$PATH\""
        fi
    } >> "$config_file"

    log_info "Updated $config_file with Android and Java environment variables"
}

remove_existing_env() {
    local config_file="$1"
    local shell_name="$2"

    if [ ! -f "$config_file" ]; then
        return 0
    fi

    # Create temporary file without Android/Java environment variables
    grep -v -E "ANDROID_(HOME|NDK_HOME|NDK_ROOT)|JAVA_HOME|Android SDK and NDK paths|\$(ANDROID|JAVA)" "$config_file" > "${config_file}.tmp"

    # Replace original file with cleaned version
    mv "${config_file}.tmp" "$config_file"
}

verify_installation() {
    log_info "Verifying installation..."

    if [ -d "$SDK_DIR" ] && [ -d "$NDK_DIR" ] && [ -d "$JAVA_HOME_DIR" ]; then
        log_success "Android SDK, NDK and Java installed successfully!"

        echo ""
        echo -e "${GREEN}Installation Summary:${NC}"
        echo "Android SDK: $SDK_DIR"
        echo "Android NDK: $NDK_DIR"
        echo "Java Home: $JAVA_HOME_DIR"
        echo "ANDROID_HOME: $ANDROID_HOME"
        echo "ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
        echo "JAVA_HOME: $JAVA_HOME"
        echo ""
        echo -e "${YELLOW}Please restart Termux or run:${NC}"
        echo "source $BASHRC"
        echo ""
        echo -e "${YELLOW}To verify, run:${NC}"
        echo "sdkmanager --list"
        echo "ndk-build --version"
        echo "java -version"
        echo "javac -version"

    else
        log_error "Installation verification failed"
        # These lines will only execute if log_error doesn't exit
        echo "SDK exists: $( [ -d "$SDK_DIR" ] && echo "Yes" || echo "No" )"
        echo "NDK exists: $( [ -d "$NDK_DIR" ] && echo "Yes" || echo "No" )"
        echo "Java exists: $( [ -d "$JAVA_HOME_DIR" ] && echo "Yes" || echo "No" )"
    fi
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
}

main() {
    echo -e "${GREEN}Android SDK and NDK Installer${NC}"
    echo "======================================"

    # Create temporary directory
    mkdir -p "$TMP_DIR"

    # Check and install dependencies
    check_dependencies

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Remove existing installations if they exist
    if [ -d "$SDK_DIR" ]; then
        log_warning "Removing existing Android SDK..."
        rm -rf "$SDK_DIR"
    fi

    if [ -d "$NDK_DIR" ]; then
        log_warning "Removing existing Android NDK..."
        rm -rf "$NDK_DIR"
    fi

    # Download and extract SDK
    download_and_extract "$SDK_URL" "$INSTALL_DIR"

    # Download and extract NDK
    download_and_extract "$NDK_URL" "$INSTALL_DIR"

    # Setup environment
    setup_environment

    # Verify installation
    verify_installation

    # Cleanup
    cleanup

    log_success "Installation completed successfully!"
}

# Run main function
main "$@"