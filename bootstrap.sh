#!/usr/bin/env bash
set -euo pipefail

NAME=""
EMAIL=""

# --- Feature flags ---
INSTALL_GAMES=false
INSTALL_COMS=true
IS_GUI=true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ensure_flatpak() {
  if ! command -v flatpak &> /dev/null; then
    sudo apt-get install -y flatpak gnome-software-plugin-flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

ensure_node() {
  if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global"
  if ! grep -q "npm-global" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
  fi
  export PATH="$HOME/.npm-global/bin:$PATH"
}

flatpak_install() {
  local app_id="$1"
  if ! flatpak list --app | grep -q "$app_id"; then
    flatpak install -y flathub "$app_id"
  fi
}

# ---------------------------------------------------------------------------
# System update & base packages
# ---------------------------------------------------------------------------

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y git vim curl htop tmux ffmpeg wget openssh-server

if $IS_GUI; then
  sudo apt-get install -y emacs syncthing vlc
  sudo apt-get install -y fonts-hack
  if [ ! -d "$HOME/.local/share/fonts/SourceSans" ]; then
    mkdir -p "$HOME/.local/share/fonts/SourceSans"
    source_sans_url=$(curl -s "https://api.github.com/repos/adobe-fonts/source-sans/releases/latest" \
      | grep "browser_download_url" | grep -i "^.*OTF.*\.zip" -o | tr -d '"')
    wget -q --show-progress -O /tmp/SourceSans.zip "$source_sans_url"
    unzip -j /tmp/SourceSans.zip "*.otf" -d "$HOME/.local/share/fonts/SourceSans"
    rm /tmp/SourceSans.zip
    fc-cache -f "$HOME/.local/share/fonts/SourceSans"
  fi
fi

# ---------------------------------------------------------------------------
# sshd configuration
# ---------------------------------------------------------------------------

sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowUsers josterpi" | sudo tee -a /etc/ssh/sshd_config > /dev/null
echo "TODO: once keys are pushed from other devices, set PasswordAuthentication no in /etc/ssh/sshd_config"
sudo systemctl enable ssh
sudo systemctl restart ssh

# ---------------------------------------------------------------------------
# GitHub CLI
# ---------------------------------------------------------------------------

if ! command -v gh &> /dev/null; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  out=$(mktemp)
  wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  rm "$out"
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y gh
fi

# ---------------------------------------------------------------------------
# VS Code
# ---------------------------------------------------------------------------

if $IS_GUI && ! command -v code &> /dev/null; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y code
fi

# ---------------------------------------------------------------------------
# Dotfiles
# ---------------------------------------------------------------------------

# .inputrc — incremental history search
if ! grep -q "history-search-backward" "$HOME/.inputrc" 2>/dev/null; then
  cat >> "$HOME/.inputrc" << 'EOF'

#incremental search with up and down
"\e[A": history-search-backward
"\e[B": history-search-forward
# Old behaviour still available with Ctrl+P and Ctrl+N
EOF
fi

# .tmux.conf
if [ ! -f "$HOME/.tmux.conf" ]; then
  cat > "$HOME/.tmux.conf" << 'EOF'
unbind-key C-b
# Set prefix key to Insert
set -g prefix ic
bind-key ic send-prefix

bind-key -n F7 previous-window
bind-key -n F8 next-window

# Make the current window pop a bit more
setw -g window-status-current-style fg=red

# I'd like to name windows myself: <prefix> ,
set-option -g allow-rename off

# Allow mouse scrolling
setw -g mouse on
EOF
fi

# ---------------------------------------------------------------------------
# Git config
# ---------------------------------------------------------------------------

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global core.editor vim

# ---------------------------------------------------------------------------
# SSH key
# ---------------------------------------------------------------------------

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
fi

# ---------------------------------------------------------------------------
# Syncthing service
# ---------------------------------------------------------------------------

if $IS_GUI; then
  systemctl --user enable syncthing.service
  systemctl --user start syncthing.service 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# uv (Python)
# ---------------------------------------------------------------------------

if ! command -v uv &> /dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# ---------------------------------------------------------------------------
# Node / Claude Code
# ---------------------------------------------------------------------------

if $IS_GUI; then
  ensure_node
  if ! command -v claude &> /dev/null; then
    npm install -g @anthropic-ai/claude-code
  fi
fi

# ---------------------------------------------------------------------------
# Steam
# ---------------------------------------------------------------------------

if $INSTALL_GAMES && ! command -v steam &> /dev/null; then
  wget -O /tmp/steam.deb "https://cdn.akamai.steamstatic.com/client/installer/steam.deb"
  sudo dpkg -i /tmp/steam.deb || sudo apt-get install -f -y
  rm /tmp/steam.deb
fi

# ---------------------------------------------------------------------------
# Flatpak apps
# ---------------------------------------------------------------------------

if $INSTALL_GAMES; then
  ensure_flatpak
  flatpak_install com.mojang.Minecraft
fi

if $INSTALL_COMS; then
  ensure_flatpak
  flatpak_install com.slack.Slack
  flatpak_install com.discordapp.Discord
fi

# --- Signal ---
if $INSTALL_COMS; then
  curl -fsSL https://updates.signal.org/desktop/apt/keys.asc | sudo gpg --dearmor -o /usr/share/keyrings/signal-desktop-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" | sudo tee /etc/apt/sources.list.d/signal-xenial.list
  sudo apt-get update
  sudo apt-get install -y signal-desktop
fi

# ---------------------------------------------------------------------------
# Interactive steps — run at the end so everything else is already in place
# ---------------------------------------------------------------------------

echo ""
echo "========================================================"
echo " Interactive setup steps"
echo "========================================================"

# 1. GitHub auth + SSH key upload
echo ""
echo ">>> Step 1: GitHub authentication"
if ! gh auth status &> /dev/null; then
  gh auth login
else
  echo "    Already authenticated, skipping."
fi
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)" 2>/dev/null || true

# 2. Clone repos (requires SSH auth to be complete)
echo ""
echo ">>> Step 2: Cloning repos"
[ ! -d "$HOME/.emacs.d" ] && git clone git@github.com:josterpi/emacs.d.git "$HOME/.emacs.d" || echo "    .emacs.d already exists, skipping."
[ ! -d "$HOME/org" ]     && git clone git@github.com:josterpi/org.git "$HOME/org"         || echo "    org already exists, skipping."

# 3. Tailscale
echo ""
echo ">>> Step 3: Tailscale"
if ! command -v tailscale &> /dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
if ! tailscale status &> /dev/null; then
  sudo tailscale up
else
  echo "    Tailscale already connected, skipping."
fi

# 4. Claude Code auth
if $IS_GUI; then
  echo ""
  echo ">>> Step 4: Claude Code — run 'claude' in a new shell to complete authentication"
  echo "    Press Enter to continue..."
  read -r
fi

echo ""
echo "========================================================"
echo " Bootstrap complete!"
echo "========================================================"

