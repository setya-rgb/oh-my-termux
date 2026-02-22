#!/bin/bash

# setup.sh - Complete Termux Setup with XFCE Desktop + myTermux Beautification
# Author: Based on myTermux by mayTermux
# Description: Interactive script to setup Termux with desktop environment and beautiful terminal

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"

# Function to print colored output
print_color() {
	echo -e "${2}${1}${NC}"
}

# Function to print banner
print_banner() {
	clear
	print_color "╔══════════════════════════════════════════════════════════════╗" "$CYAN"
	print_color "║                                                              ║" "$CYAN"
	print_color "║           Termux Complete Setup - XFCE + myTermux           ║" "$CYAN"
	print_color "║                      Version $VERSION                          ║" "$CYAN"
	print_color "║                                                              ║" "$CYAN"
	print_color "╚══════════════════════════════════════════════════════════════╝" "$CYAN"
	echo ""
}

# Function to check Termux environment
check_environment() {
	print_color "[*] Checking Termux environment..." "$YELLOW"

	# Check if running in Termux
	if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
		print_color "[!] This script must be run in Termux!" "$RED"
		exit 1
	fi

	# Check for storage permission
	if [ ! -d ~/storage ]; then
		print_color "[!] Storage permission not granted. Requesting..." "$YELLOW"
		termux-setup-storage
		sleep 5
	fi

	print_color "[✓] Environment check passed" "$GREEN"
}

# Function to update and upgrade packages
update_system() {
	print_color "[*] Updating package repositories..." "$YELLOW"
	pkg update -y && pkg upgrade -y

	if [ $? -eq 0 ]; then
		print_color "[✓] System updated successfully" "$GREEN"
	else
		print_color "[!] Update failed. Please check your internet connection." "$RED"
		exit 1
	fi
}

# Function to install myTermux
install_mytermux() {
	print_color "\n[*] Installing myTermux beautification..." "$PURPLE"

	# Install required packages
	print_color "[*] Installing dependencies..." "$YELLOW"
	pkg install -y git bc curl wget zsh neovim

	# Clone myTermux repository
	if [ -d "$HOME/myTermux" ]; then
		print_color "[*] myTermux directory exists. Updating..." "$YELLOW"
		cd ~/myTermux
		git pull
	else
		print_color "[*] Cloning myTermux repository..." "$YELLOW"
		git clone --depth=1 https://github.com/mayTermux/myTermux.git ~/myTermux
	fi

	# Run myTermux installer
	cd ~/myTermux
	export COLUMNS LINES

	# Check if terminal size is sufficient
	if [ $COLUMNS -lt 40 ] || [ $LINES -lt 15 ]; then
		print_color "[!] Terminal too small. Please zoom out and increase terminal size." "$RED"
		print_color "[!] Current size: ${COLUMNS}x${LINES}. Minimum required: 40x15" "$YELLOW"
		exit 1
	fi

	print_color "[*] Running myTermux installer..." "$YELLOW"
	chmod +x install.sh
	./install.sh

	if [ $? -eq 0 ]; then
		print_color "[✓] myTermux installed successfully!" "$GREEN"
	else
		print_color "[!] myTermux installation encountered issues." "$RED"
		return 1
	fi
}

# Function to install XFCE desktop
install_xfce_desktop() {
	print_color "\n[*] Installing XFCE Desktop Environment..." "$BLUE"

	# Install X11 repository
	print_color "[*] Adding X11 repository..." "$YELLOW"
	pkg install -y x11-repo

	# Install XFCE and essential packages
	print_color "[*] Installing XFCE4 and components..." "$YELLOW"
	pkg install -y \
		xfce4 \
		xfce4-terminal \
		tigervnc \
		termux-x11-nightly \
		firefox \
		audacious \
		ristretto \
		mousepad \
		thunar \
		leafpad \
		geany \
		htop \
		evince \
		galculator

	# Install additional themes and icons
	print_color "[*] Installing additional themes and icons..." "$YELLOW"
	pkg install -y \
		arc-theme \
		papirus-icon-theme \
		plank

	print_color "[✓] XFCE Desktop installed successfully!" "$GREEN"
}

# Function to setup VNC server
setup_vnc() {
	print_color "\n[*] Setting up VNC Server..." "$PURPLE"

	# Create .vnc directory
	mkdir -p ~/.vnc

	# Create VNC passwd file if it doesn't exist
	if [ ! -f ~/.vnc/passwd ]; then
		print_color "[*] Setting VNC password..." "$YELLOW"
		vncpasswd
	fi

	# Create xstartup file
	cat >~/.vnc/xstartup <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
export PULSE_SERVER=127.0.0.1
export DISPLAY=:1
xfce4-session &
EOF

	chmod +x ~/.vnc/xstartup

	print_color "[✓] VNC Server configured" "$GREEN"
}

# Function to setup Termux-X11
setup_termux_x11() {
	print_color "\n[*] Setting up Termux:X11..." "$PURPLE"

	# Create start script for Termux:X11
	cat >~/start-termux-x11.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Start Termux:X11
termux-x11 :1 -xstartup "xfce4-session"
EOF

	chmod +x ~/start-termux-x11.sh

	# Create start script for VNC
	cat >~/start-vnc.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Start VNC Server
vncserver -localhost -geometry 1280x720 :1
echo "VNC server started on localhost:5901"
echo "Connect using a VNC client to localhost:5901"
EOF

	chmod +x ~/start-vnc.sh

	# Create stop script for VNC
	cat >~/stop-vnc.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Stop VNC Server
vncserver -kill :1
echo "VNC server stopped"
EOF

	chmod +x ~/stop-vnc.sh

	print_color "[✓] Termux:X11 and VNC scripts created in ~/" "$GREEN"
}

# Function to install Alpine Linux with proot (optional)
install_alpine_proot() {
	print_color "\n[*] Installing Alpine Linux in proot..." "$PURPLE"

	# Install proot-distro
	pkg install -y proot-distro

	# Install Alpine Linux
	print_color "[*] Installing Alpine Linux (this may take a while)..." "$YELLOW"
	proot-distro install alpine

	# Create login script
	cat >~/login-alpine.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Login to Alpine Linux
proot-distro login alpine
EOF

	chmod +x ~/login-alpine.sh

	# Setup Alpine with XFCE
	print_color "[*] Setting up Alpine with XFCE..." "$YELLOW"
	proot-distro login alpine <<'INNEREOF'
    apk update
    apk add --no-cache xfce4 xfce4-terminal firefox dbus-x11 sudo
    adduser -D termuser
    echo "termuser ALL=(ALL:ALL) ALL" >> /etc/sudoers
    echo "Setup complete in Alpine. Login with: proot-distro login alpine"
    exit
INNEREOF

	print_color "[✓] Alpine Linux with XFCE installed in proot" "$GREEN"
}

# Function to show completion message
show_completion() {
	print_color "\n╔══════════════════════════════════════════════════════════════╗" "$CYAN"
	print_color "║                    SETUP COMPLETE!                           ║" "$CYAN"
	print_color "╚══════════════════════════════════════════════════════════════╝" "$CYAN"
	echo ""
	print_color "Available commands:" "$GREEN"
	echo ""
	print_color "  • Start Termux:X11 desktop:" "$YELLOW"
	print_color "    ~/start-termux-x11.sh" "$NC"
	echo ""
	print_color "  • Start VNC server:" "$YELLOW"
	print_color "    ~/start-vnc.sh" "$NC"
	print_color "    ~/stop-vnc.sh" "$NC"
	echo ""
	print_color "  • Access Alpine Linux (if installed):" "$YELLOW"
	print_color "    ~/login-alpine.sh" "$NC"
	echo ""
	print_color "  • Change themes in myTermux:" "$YELLOW"
	print_color "    chcolor  - Change color scheme" "$NC"
	print_color "    chfont   - Change font" "$NC"
	print_color "    chzsh    - Change ZSH theme" "$NC"
	echo ""
	print_color "Notes:" "$PURPLE"
	print_color "  • For Termux:X11, install the app from F-Droid" "$NC"
	print_color "  • For VNC, use any VNC client to connect to localhost:5901" "$NC"
	print_color "  • Default resolution for VNC is 1280x720" "$NC"
	echo ""
	print_color "⚠️  Restart Termux or run 'source ~/.zshrc' to apply changes" "$YELLOW"
}

# Main menu function
show_menu() {
	print_banner
	print_color "Please select installation options:" "$GREEN"
	echo ""
	print_color "1. Full Installation (myTermux + XFCE Desktop + VNC/Termux:X11)" "$BLUE"
	print_color "2. Minimal Installation (myTermux only)" "$BLUE"
	print_color "3. Desktop Only (XFCE Desktop + VNC/Termux:X11)" "$BLUE"
	print_color "4. Proot Installation (Alpine Linux with XFCE)" "$BLUE"
	print_color "5. Custom Installation (Choose components)" "$BLUE"
	print_color "6. Exit" "$RED"
	echo ""
	read -p "Enter your choice [1-6]: " choice

	case $choice in
	1)
		print_color "\n[*] Starting Full Installation..." "$GREEN"
		check_environment
		update_system
		install_mytermux
		install_xfce_desktop
		setup_vnc
		setup_termux_x11
		show_completion
		;;
	2)
		print_color "\n[*] Starting Minimal Installation..." "$GREEN"
		check_environment
		update_system
		install_mytermux
		print_color "[✓] Minimal installation complete!" "$GREEN"
		print_color "Run 'chcolor', 'chfont', or 'chzsh' to customize your terminal" "$YELLOW"
		;;
	3)
		print_color "\n[*] Starting Desktop Only Installation..." "$GREEN"
		check_environment
		update_system
		install_xfce_desktop
		setup_vnc
		setup_termux_x11
		show_completion
		;;
	4)
		print_color "\n[*] Starting Proot Installation..." "$GREEN"
		check_environment
		update_system
		install_alpine_proot
		print_color "[✓] Proot installation complete!" "$GREEN"
		print_color "Run '~/login-alpine.sh' to access Alpine Linux" "$YELLOW"
		;;
	5)
		custom_installation
		;;
	6)
		print_color "Exiting..." "$RED"
		exit 0
		;;
	*)
		print_color "Invalid choice. Please try again." "$RED"
		sleep 2
		show_menu
		;;
	esac
}

# Custom installation function
custom_installation() {
	print_banner
	print_color "Custom Installation - Select components:" "$GREEN"
	echo ""

	install_mytermux_custom="n"
	install_xfce_custom="n"
	install_alpine_custom="n"
	setup_vnc_custom="n"
	setup_x11_custom="n"

	read -p "Install myTermux beautification? (y/n): " install_mytermux_custom
	read -p "Install XFCE Desktop? (y/n): " install_xfce_custom
	read -p "Install Alpine Linux in proot? (y/n): " install_alpine_custom
	if [ "$install_xfce_custom" = "y" ]; then
		read -p "Setup VNC Server? (y/n): " setup_vnc_custom
		read -p "Setup Termux:X11? (y/n): " setup_x11_custom
	fi

	print_color "\n[*] Starting Custom Installation..." "$GREEN"
	check_environment
	update_system

	[ "$install_mytermux_custom" = "y" ] && install_mytermux
	[ "$install_xfce_custom" = "y" ] && install_xfce_desktop
	[ "$setup_vnc_custom" = "y" ] && setup_vnc
	[ "$setup_x11_custom" = "y" ] && setup_termux_x11
	[ "$install_alpine_custom" = "y" ] && install_alpine_proot

	show_completion
}

# Main execution
main() {
	# Check if running in Termux
	if [ ! -d /data/data/com.termux ]; then
		echo "This script must be run in Termux!"
		exit 1
	fi

	# Show menu
	show_menu
}

# Run main function
main
