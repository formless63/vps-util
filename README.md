# VPS Utility & Initialization

Automated bootstrap script for Ubuntu 24.04 VPS instances. 
Sets up Docker, Tailscale, Zsh (Oh-My-Zsh), and a master alias set.

##  Quick Start

Run this on a fresh Ubuntu 24.04 install to provision the environment:

```bash
curl -sL https://raw.githubusercontent.com/formless63/vps-util/main/bootstrap.sh | sudo bash
```

###  What this does:
- System: Updates apt and upgrades packages.
- Utilities: Installs btop, ncdu, fzf, eza, tmux, micro, ufw, and fail2ban.
- Docker: Removes old versions and installs the official Docker Engine + Compose plugin.
- Tailscale: Installs and prepares Tailscale for login.
- Shell: Installs Zsh, Oh-My-Zsh, and productivity plugins (autosuggestions/highlighting).
- Sync: Clones this repo to ~/.dotfiles and symlinks .common_aliases.

##  Updating Aliases
Since the alias file is symlinked to the git repo in ~/.dotfiles, updating is easy:

Edit .common_aliases in this repo and push changes.

On the VPS, run: cd ~/.dotfiles && git pull


---

Make sure the variables at the top of your `bootstrap.sh` match your actual GitHub details so you don't have to pass them manually:

```bash
# --- Variables ---
GITHUB_USER="${GH_USER:-formless63}" 
REPO_NAME="${GH_REPO:-vps-util}"
BRANCH="${GH_BRANCH:-main}"
```
