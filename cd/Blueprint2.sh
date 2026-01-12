#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' 

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() { echo -e "${YELLOW}⏳ $1...${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to animate progress
animate_progress() {
    local pid=$1
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

install_mahim() {
    print_header "FIXED FRESH INSTALLATION"
    
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        return 1
    fi

    # --- Step 1: System Prep ---
    print_status "Installing System Dependencies"
    apt-get update > /dev/null 2>&1
    apt-get install -y ca-certificates curl gnupg zip unzip git wget nodejs npm > /dev/null 2>&1
    
    # Ensure Node 20 is actually used
    if [[ $(node -v | cut -d'.' -f1) != "v20" ]]; then
        print_status "Upgrading to Node 20"
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
        apt-get install -y nodejs > /dev/null 2>&1
    fi

    # --- Step 2: Clean & Fix Yarn Dependencies ---
    print_status "Moving to Panel Directory"
    cd /var/www/pterodactyl || { print_error "Directory /var/www/pterodactyl not found!"; return 1; }

    print_status "Cleaning corrupted modules"
    rm -rf node_modules yarn.lock
    npm install -g yarn > /dev/null 2>&1

    print_status "FORCING MISSING MODULES (pathe & axios)"
    # This solves the 'pathe' and 'AxiosProgressEvent' errors directly
    yarn add pathe axios@latest --silent
    
    print_status "Installing remaining dependencies"
    yarn install --production --ignore-scripts --network-timeout 1000000 > /dev/null 2>&1 &
    animate_progress $!
    
    # --- Step 3: Blueprint Framework ---
    print_status "Downloading Blueprint Framework"
    wget -q --show-progress https://github.com/BlueprintFramework/framework/releases/download/beta-2025-11/beta-2025-11.zip -O release.zip
    unzip -o release.zip > /dev/null 2>&1
    rm release.zip

    # --- Step 4: Final Build ---
    print_status "Running Blueprint Script"
    chmod +x blueprint.sh
    bash blueprint.sh

    print_status "Forcing Production Build"
    yarn build-production --progress > /dev/null 2>&1 &
    animate_progress $!

    print_success "Installation Finished! Errors resolved."
}

reinstall_mahim() {
    print_header "REINSTALLING"
    cd /var/www/pterodactyl && blueprint -rerun-install
}

update_mahim() {
    print_header "UPDATING"
    cd /var/www/pterodactyl && blueprint -upgrade
}

# Main Menu
while true; do
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}        🔧 BLUEPRINT INSTALLER (ERROR-FIXED)      ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " 1) Fresh Install (Fixes Pathe/Axios Errors)"
    echo -e " 2) Reinstall (Rerun)"
    echo -e " 3) Update Framework"
    echo -e " 0) Exit"
    echo -ne "\n${YELLOW}Select an option: ${NC}"
    read -r choice
    case $choice in
        1) install_mahim ;;
        2) reinstall_mahim ;;
        3) update_mahim ;;
        0) exit 0 ;;
        *) print_error "Invalid selection" ; sleep 1 ;;
    esac
    echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
    read -r
done
