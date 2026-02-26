#!/bin/bash
# Optimized for Ubuntu 24.04 - "Zero-Edit" Version
# Repo: https://github.com/formless63/vps-util

set -e 

# --- Variables (Overridable via CLI) ---
GITHUB_USER="${GH_USER:-formless63}" 
REPO_NAME="${GH_REPO:-vps-util}"
BRANCH="${GH_BRANCH:-main}"

if [ "$EUID" -ne 0 ]; then 
  echo "Error: Please run as root (sudo)"
  exit 1
fi

echo "--- Starting Ubuntu 24.04 Bootstrap ---"

# 1. Core Updates & Utils
apt-get update && apt-get upgrade -y
apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true
apt-get install -y ca-certificates curl gnupg git zsh btop ncdu fzf eza tmux micro ufw fail2ban

# 2. Docker Engine (Official)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc" | tee /etc/apt/sources.list.d/docker.sources

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 4. User-Specific Setup
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$REAL_USER)

# Install Oh My Zsh if missing
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh (Unattended)..."
    # RUNZSH=no prevents the installer from starting a new shell and killing this script
    # CHSH=no prevents the installer from asking to change shell interactively
    sudo -u $REAL_USER RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 5. The "Dotfiles" Sync (Clone the repo)
DOTFILES_DIR="$USER_HOME/.dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning setup repo from GitHub..."
    sudo -u $REAL_USER git clone -b "$BRANCH" "https://github.com/$GITHUB_USER/$REPO_NAME.git" "$DOTFILES_DIR"
else
    echo "Dotfiles already exist, pulling latest..."
    cd "$DOTFILES_DIR" && sudo -u $REAL_USER git pull
fi

# Symlink the alias file
sudo -u $REAL_USER ln -sf "$DOTFILES_DIR/.common_aliases" "$USER_HOME/.common_aliases"

# 6. Configure Zsh Plugins & Aliases
# We modify .zshrc after OMZ is installed
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_HOME/.zshrc"
if ! grep -q "source ~/.common_aliases" "$USER_HOME/.zshrc"; then
    echo "[[ -f ~/.common_aliases ]] && source ~/.common_aliases" >> "$USER_HOME/.zshrc"
fi

# Clone Zsh Plugins
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] && sudo -u $REAL_USER git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ] && sudo -u $REAL_USER git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting

# Change shell
chsh -s $(which zsh) $REAL_USER

echo "--- Setup Complete! Please reboot now. ---"
