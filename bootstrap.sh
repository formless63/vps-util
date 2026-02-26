#!/bin/bash
# Optimized for Ubuntu 24.04 - "Zero-Edit" Version

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
    sudo -u $REAL_USER sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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

# 6. Configure Zsh
# Enable plugins and source the alias file
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$USER_HOME/.zshrc"
if ! grep -q "source ~/.common_aliases" "$USER_HOME/.zshrc"; then
    echo "[[ -f ~/.common_aliases ]] && source ~/.common_aliases" >> "$USER_HOME/.zshrc"
fi

# Clone Zsh Plugins
ZSH_CUSTOM="$USER_HOME/.oh-my-zsh/custom"
sudo -u $REAL_USER git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions || true
sudo -u $REAL_USER git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting || true

# Change shell
chsh -s $(which zsh) $REAL_USER

# --- Interactive Hostname Setup ---
if [ -t 0 ]; then
    echo ""
    read -p "Do you want to set the hostname now? (y/N): " SET_HOST
    if [[ "$SET_HOST" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        read -p "Enter new hostname (e.g., vps-prod-01): " NEW_HOSTNAME
        if [ -n "$NEW_HOSTNAME" ]; then
            echo "Setting hostname to $NEW_HOSTNAME..."
            
            # 1. Set the static hostname
            hostnamectl set-hostname "$NEW_HOSTNAME"
            
            # 2. Update /etc/hosts to prevent sudo resolution delays
            if grep -q "127.0.1.1" /etc/hosts; then
                sed -i "s/^127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
            else
                echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
            fi
            
            # 3. Optional Metadata
            read -p "Enter Pretty Name (e.g., Will's Web Server) [Optional]: " PRETTY_NAME
            [ -n "$PRETTY_NAME" ] && hostnamectl set-hostname "$PRETTY_NAME" --pretty
            
            read -p "Enter Icon Name (e.g., computer-vm, server) [Optional]: " ICON_NAME
            [ -n "$ICON_NAME" ] && hostnamectl set-hostname "$ICON_NAME" --icon-name
            
            echo "Hostname configured. Changes will reflect on next login."
        fi
    fi

    # Reboot Prompt
    read -p "Recommended: Reboot now to apply kernel updates and hostname? (y/N): " REBOOT_NOW
    if [[ "$REBOOT_NOW" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        reboot
    fi
fi

echo "--- Setup Complete! Log out and back in. ---"
