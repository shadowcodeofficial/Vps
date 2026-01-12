#!/bin/bash
# =============================================================================
# Blueprint Framework Installer for Pterodactyl Panel
# 2026 Edition - NOW with Node.js 22 support (required for Pterodactyl v1.12+)
# Fixes path/join + engine incompatibility errors
# =============================================================================
set -euo pipefail

# ----------------------------- Colors -----------------------------
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m'
PURPLE='\033[0;35m' CYAN='\033[0;36m' WHITE='\033[1;37m' BOLD='\033[1m' NC='\033[0m'

banner() { echo -e "${PURPLE}${BOLD}\n$(printf '%*s' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '=')\n $1\n$(printf '%*s' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '=')\n${NC}"; }
log() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARNING]${NC} $*"; }
error() { echo -e "${RED}${BOLD}[ERROR]${NC} $*" >&2; }
step() { echo -e "${CYAN}${BOLD}>>>${NC} ${WHITE}$*${NC}"; }

# ----------------------------- Config -----------------------------
PTERODACTYL_DIRECTORY="/var/www/pterodactyl"
BLUEPRINT_REPO="BlueprintFramework/framework"

# ----------------------------- Start -----------------------------
clear
banner "Blueprint Installer - Node 22 Fixed Edition (Jan 2026)"

if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)"; exit 1; fi
if [[ ! -d "$PTERODACTYL_DIRECTORY" ]]; then error "Pterodactyl dir not found: $PTERODACTYL_DIRECTORY"; exit 1; fi

cd "$PTERODACTYL_DIRECTORY" || exit 1

# ----------------------------- Clean old broken stuff -----------------------------
step "Aggressive clean of old node_modules / yarn.lock / cache"
rm -rf node_modules .yarn/cache yarn.lock 2>/dev/null || true
yarn cache clean --all 2>/dev/null || true
log "Clean completed"

# ----------------------------- System deps -----------------------------
step "Updating apt & installing basics"
apt update --quiet -y >/dev/null
apt install -y ca-certificates curl wget unzip git gnupg zip >/dev/null 2>&1
log "System deps ready"

# ----------------------------- Node.js 22 (critical!) -----------------------------
step "Installing Node.js 22.x (required for current Pterodactyl + Blueprint)"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg >/dev/null

cat > /etc/apt/sources.list.d/nodesource.list <<EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main
EOF

apt update --quiet -y >/dev/null
apt install -y nodejs >/dev/null 2>&1

node_ver=$(node -v)
npm_ver=$(npm -v)
log "Node.js $node_ver | npm $npm_ver installed"

if [[ ! "$node_ver" =~ ^v22 ]]; then
    error "Node.js is NOT 22.x! (got $node_ver)"
    error "Check /etc/apt/sources.list.d/nodesource.list and try again."
    exit 1
fi

# Yarn global
if ! command -v yarn >/dev/null 2>&1; then
    step "Installing Yarn globally"
    npm install -g yarn >/dev/null 2>&1
    log "Yarn installed"
else
    info "Yarn already present"
fi

# ----------------------------- Fix path/join packages -----------------------------
step "Adding missing packages (path + TS types)"
yarn add path --force
yarn add -D @types/node @types/react @types/react-dom --force
log "Path + types added"

# ----------------------------- Download & extract Blueprint -----------------------------
step "Fetching latest Blueprint release"
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/${BLUEPRINT_REPO}/releases/latest" | grep "browser_download_url.*\.zip" | cut -d '"' -f 4 | head -n 1)

if [[ -z "$DOWNLOAD_URL" ]]; then error "Failed to get Blueprint download URL"; exit 1; fi

info "URL: $DOWNLOAD_URL"
wget --quiet --show-progress -O release.zip "$DOWNLOAD_URL"
unzip -o release.zip >/dev/null 2>&1
rm -f release.zip
log "Blueprint extracted"

# ----------------------------- Install deps (long timeout) -----------------------------
step "Installing ALL dependencies (this takes 2-6 minutes)"
yarn install --force --check-files --network-timeout 120000 >/dev/null 2>&1
log "Dependencies installed"

# ----------------------------- Config & executable -----------------------------
step "Creating .blueprintrc"
cat > .blueprintrc << 'EOF'
WEBUSER="www-data"
OWNERSHIP="www-data:www-data"
USERSHELL="/bin/bash"
EOF
log ".blueprintrc created"

chmod +x blueprint.sh 2>/dev/null && log "blueprint.sh executable" || error "blueprint.sh missing!"

# ----------------------------- Run Blueprint -----------------------------
banner "Launching Blueprint Setup"
bash ./blueprint.sh

# ----------------------------- Finish -----------------------------
clear
banner "Installation Complete!"
log "Blueprint should be ready."
warn "Final steps:"
echo "  • Run:   yarn build   (or yarn build:production)"
echo "  • Clear cache:"
echo "      php artisan view:clear && php artisan config:cache && php artisan optimize"
echo "  • Refresh browser (incognito recommended)"
info "If build still fails → share 'yarn build' output"
echo
exit 0
