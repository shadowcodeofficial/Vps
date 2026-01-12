#!/usr/bin/env bash
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

print_status()  { echo -e "${YELLOW}⏳ $1...${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; exit 1; }

# Improved spinner (fixed logic)
animate_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    wait "$pid" && return 0 || return 1
}

install_mahim() {
    print_header "FIXED FRESH BLUEPRINT INSTALLATION"

    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
    fi

    local PTERO_DIR="/var/www/pterodactyl"

    # --- Step 1: System Preparation ---
    print_status "Updating package list and installing base dependencies"
    apt-get update -y || print_error "apt update failed"
    apt-get install -y ca-certificates curl gnupg zip unzip git wget || print_error "Failed to install base packages"

    # Node.js 20 (recommended in recent Pterodactyl + Blueprint setups)
    print_status "Setting up Node.js 20"
    if ! curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || ! apt-get install -y nodejs; then
        print_error "Node.js 20 installation failed"
    fi

    # Yarn global
    print_status "Installing Yarn"
    npm install -g yarn || print_error "Yarn global install failed"

    # --- Step 2: Panel Directory & Dependencies ---
    print_status "Changing to Pterodactyl directory"
    cd "$PTERO_DIR" || print_error "Directory $PTERO_DIR not found! Is Pterodactyl installed?"

    print_status "Cleaning old node_modules & lockfile"
    rm -rf node_modules yarn.lock .yarn/install-target 2>/dev/null || true

    print_status "Installing pathe + latest axios (common Blueprint error fix)"
    yarn add pathe axios@latest --silent || print_warning "pathe/axios install had warnings (non-fatal)"

    print_status "Installing remaining dependencies (this may take a while)"
    yarn install --production --network-timeout 1000000 &
    local yarn_pid=$!
    animate_progress $yarn_pid
    wait $yarn_pid || print_error "yarn install failed!"

    # --- Step 3: Download latest Blueprint ---
    print_status "Downloading latest Blueprint release"
    local release_url
    release_url=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest \
        | grep "browser_download_url.*release\.zip" \
        | cut -d '"' -f 4)

    if [ -z "$release_url" ]; then
        print_error "Could not find latest release.zip URL from GitHub"
    fi

    wget -q --show-progress "$release_url" -O release.zip || print_error "Download failed"

    print_status "Extracting Blueprint files"
    unzip -o release.zip || print_error "Unzip failed"
    rm -f release.zip

    if [ ! -f "blueprint.sh" ]; then
        print_error "blueprint.sh not found after extraction — download may be corrupt"
    fi

    # --- Step 4: Run Blueprint installer ---
    print_status "Running Blueprint installation script"
    chmod +x blueprint.sh
    bash blueprint.sh || print_error "blueprint.sh failed!"

    print_status "Building production assets (may take several minutes)"
    yarn build-production --progress &
    local build_pid=$!
    animate_progress $build_pid
    wait $build_pid || print_error "Production build failed!"

    print_success "Fresh Blueprint installation should now be complete!"
    echo -e "  → Visit your panel and check if everything loads correctly"
    echo -e "  → If issues remain → try:   yarn cache clean && yarn install && yarn build-production"
}

reinstall_mahim() {
    print_header "RE-INSTALLING BLUEPRINT"
    cd /var/www/pterodactyl || print_error "Cannot cd to /var/www/pterodactyl"
    if [ ! -f blueprint ]; then
        print_error "blueprint command not found — is Blueprint installed?"
    fi
    ./blueprint -rerun-install || print_error "Reinstall failed"
    print_success "Re-installation triggered."
}

update_mahim() {
    print_header "UPDATING BLUEPRINT"
    cd /var/www/pterodactyl || print_error "Cannot cd to /var/www/pterodactyl"
    if [ ! -f blueprint ]; then
        print_error "blueprint command not found — is Blueprint installed?"
    fi
    ./blueprint -upgrade || print_error "Update failed"
    print_success "Update finished — you may want to run yarn build-production"
}

# ────────────────────────────────────────────────
# Main Menu
# ────────────────────────────────────────────────

while true; do
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}       🔧 BLUEPRINT HELPER (2026 FIXED)       ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    echo -e "  1) Fresh Install (recommended for new setups)"
    echo -e "  2) Re-run Blueprint install"
    echo -e "  3) Update Blueprint to latest version"
    echo -e "  0) Exit"
    echo -e ""
    echo -ne "${YELLOW}Select an option → ${NC}"
    read -r choice

    case $choice in
        1) install_mahim ;;
        2) reinstall_mahim ;;
        3) update_mahim ;;
        0) echo -e "\n${GREEN}Goodbye!${NC}" ; exit 0 ;;
        *) print_error "Invalid choice" ; sleep 1 ;;
    esac

    echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
    read -r
done
