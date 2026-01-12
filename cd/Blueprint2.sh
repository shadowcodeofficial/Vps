#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Function to print status messages
print_status() {
    echo -e "${YELLOW}⏳ $1...${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
        return 0
    else
        print_error "$2"
        return 1
    fi
}

# Function to animate progress
animate_progress() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Welcome animation
welcome_animation() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}           Blueprint Installer Fixed             ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 1
}

# Function: Install (Fresh Setup)
install_mahim() {
    print_header "FRESH INSTALLATION"
    
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root or with sudo"
        return 1
    fi

    # --- Step 1: Install Node.js 20.x ---
    print_status "Installing Node.js 20 & System Dependencies"
    apt-get update > /dev/null 2>&1
    apt-get install -y ca-certificates curl gnupg zip unzip git wget > /dev/null 2>&1
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes > /dev/null 2>&1
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list > /dev/null 2>&1
    
    apt-get update > /dev/null 2>&1
    apt-get install -y nodejs > /dev/null 2>&1
    check_success "Node.js 20 installed" "Failed to install Node.js"

    # --- Step 2: Install Yarn & Dependencies ---
    print_status "Installing Yarn"
    npm i -g yarn > /dev/null 2>&1
    
    cd /var/www/pterodactyl || { print_error "Panel directory not found!"; return 1; }
    
    # CRITICAL FIX: Installing the missing pathe and axios versions that caused your build error
    print_status "Fixing missing dependencies (pathe & axios)"
    yarn add pathe axios@latest --dev > /dev/null 2>&1 &
    animate_progress $! "Patching dependencies"

    print_status "Running main Yarn install"
    yarn install --production --ignore-scripts > /dev/null 2>&1 &
    animate_progress $! "Installing Yarn dependencies"
    check_success "Dependencies ready" "Yarn install failed"

    # --- Step 3: Download Release ---
    print_header "DOWNLOADING BLUEPRINT"
    print_status "Fetching beta-2025-11"
    wget -q --show-progress https://github.com/BlueprintFramework/framework/releases/download/beta-2025-11/beta-2025-11.zip -O release.zip
    
    print_status "Extracting files"
    unzip -o release.zip > /dev/null 2>&1
    rm release.zip
    check_success "Files extracted" "Failed to extract files"

    # --- Step 4: Run Installer ---
    print_header "RUNNING BLUEPRINT"
    if [ ! -f "blueprint.sh" ]; then
        print_error "blueprint.sh not found!"
        return 1
    fi

    chmod +x blueprint.sh
    print_status "Starting Blueprint script..."
    bash blueprint.sh
}

reinstall_mahim() {
    print_header "REINSTALLING"
    cd /var/www/pterodactyl && blueprint -rerun-install
}

update_mahim() {
    print_header "UPDATING"
    cd /var/www/pterodactyl && blueprint -upgrade
}

show_menu() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}            🔧 BLUEPRINT INSTALLER               ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}1)${NC} Fresh Install (Fixes Pathe/Axios Errors)"
    echo -e "${GREEN}2)${NC} Reinstall (Rerun Only)"
    echo -e "${GREEN}3)${NC} Update"
    echo -e "${RED}0)${NC} Exit"
    echo -ne "${YELLOW}Select an option: ${NC}"
}

# Main execution loop
welcome_animation
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_mahim ;;
        2) reinstall_mahim ;;
        3) update_mahim ;;
        0) exit 0 ;;
        *) print_error "Invalid option!" ; sleep 1 ;;
    esac
done
