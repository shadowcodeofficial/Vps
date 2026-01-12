#!/bin/bash
# =============================================================================
# Blueprint Framework Installer for Pterodactyl Panel
# Fully Remastered, Redesigned & Colorful – Updated January 2026
# Fixes for 'path' / 'pathe' / 'join' module not found errors
# =============================================================================
set -euo pipefail

# ----------------------------- Color Definitions -----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# ----------------------------- Logging Functions -----------------------------
banner() {
    echo -e "${PURPLE}${BOLD}"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '='
    echo " $1"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '='
    echo -e "${NC}"
}

log() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARNING]${NC} $*"; }
error() { echo -e "${RED}${BOLD}[ERROR]${NC} $*" >&2; }
step() { echo -e "${CYAN}${BOLD}>>>${NC} ${WHITE}$*${NC}"; }

# ----------------------------- Configuration ---------------------------------
PTERODACTYL_DIRECTORY="/var/www/pterodactyl"
BLUEPRINT_REPO="BlueprintFramework/framework"
NODE_VERSION="20"

# ----------------------------- Welcome Banner --------------------------------
clear
banner "Blueprint Framework Installer - 2026 Fixed Edition"
echo

# ----------------------------- Root & Directory Check ------------------------
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)."
    exit 1
fi

if [[ ! -d "$PTERODACTYL_DIRECTORY" ]]; then
    error "Pterodactyl directory not found at: $PTERODACTYL_DIRECTORY"
    error "Ensure Pterodactyl Panel is installed correctly before proceeding."
    exit 1
fi

cd "$PTERODACTYL_DIRECTORY" || exit 1

# ----------------------------- Clean previous broken installation ------------
step "Cleaning previous node_modules & lockfile (prevents most path errors)"
rm -rf node_modules .yarn/cache yarn.lock 2>/dev/null || true
yarn cache clean --all 2>/dev/null || true
log "Cleaned old dependencies"

# ----------------------------- Install System Dependencies -------------------
step "Updating package index and installing system dependencies"
apt update --quiet -y >/dev/null
apt install -y ca-certificates curl wget unzip git gnupg zip >/dev/null 2>&1
log "System dependencies installed"

# ----------------------------- Install Node.js 20 -----------------------------
step "Configuring NodeSource repository for Node.js $NODE_VERSION"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg >/dev/null

cat > /etc/apt/sources.list.d/nodesource.list <<EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main
EOF

apt update --quiet -y >/dev/null
apt install -y nodejs >/dev/null 2>&1

node_ver=$(node -v)
npm_ver=$(npm -v)
log "Node.js $node_ver and npm $npm_ver installed"

# Install Yarn globally if missing
if ! command -v yarn >/dev/null 2>&1; then
    step "Installing Yarn package manager globally"
    npm install -g yarn >/dev/null 2>&1
    log "Yarn installed"
else
    info "Yarn already installed"
fi

# ----------------------------- Critical Fix: Install missing packages --------
step "Installing missing packages that fix 'path' / 'join' errors"
yarn add path --force
yarn add -D @types/node @types/react @types/react-dom --force
log "Added path + TypeScript types"

# ----------------------------- Download Latest Release -----------------------
step "Fetching latest Blueprint Framework release"
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/${BLUEPRINT_REPO}/releases/latest" \
    | grep "browser_download_url.*\.zip" \
    | cut -d '"' -f 4 \
    | head -n 1)

if [[ -z "$DOWNLOAD_URL" ]]; then
    error "Could not find latest release download URL"
    error "Check internet connection or visit: https://github.com/${BLUEPRINT_REPO}/releases"
    exit 1
fi

info "Download URL: $DOWNLOAD_URL"
wget --quiet --show-progress -O release.zip "$DOWNLOAD_URL"

step "Extracting files..."
unzip -o release.zip >/dev/null 2>&1
rm -f release.zip
log "Release extracted"

# ----------------------------- Install ALL dependencies ----------------------
step "Installing complete project dependencies (this may take 2-5 minutes)"
yarn install --force --check-files --network-timeout 100000 >/dev/null 2>&1
log "Dependencies installed successfully"

# ----------------------------- Create .blueprintrc ---------------------------
step "Creating .blueprintrc configuration"
cat > .blueprintrc << 'EOF'
WEBUSER="www-data"
OWNERSHIP="www-data:www-data"
USERSHELL="/bin/bash"
EOF
log ".blueprintrc created"

# Make blueprint.sh executable
if [[ -f "blueprint.sh" ]]; then
    chmod +x blueprint.sh
    log "blueprint.sh is now executable"
else
    error "blueprint.sh not found after extraction!"
    exit 1
fi

# ----------------------------- Run Blueprint Installer -----------------------
banner "Starting Blueprint Framework Setup"
echo
bash ./blueprint.sh

# ----------------------------- Final Steps & Messages ------------------------
clear
banner "Installation Finished Successfully!"
echo

log "Blueprint Framework should now be installed"
warn "Recommended final steps:"
echo "  1. Clear caches:"
echo "     php artisan view:clear"
echo "     php artisan config:cache"
echo "     php artisan optimize"
echo "  2. Rebuild assets (very important after path fix):"
echo "     yarn build"
echo "  3. Refresh your browser (or use incognito mode)"
echo

info "If you still see errors → run 'yarn build' manually and share the output"
info "Enjoy your enhanced Pterodactyl Panel! 🚀"
echo

exit 0
