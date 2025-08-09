#!/usr/bin/env bash
set -euo pipefail

# ======= CONFIG =======
INSTALL_FLAGS="$*"
USER_NAME="$(logname)"   # Auto-detect logged-in user
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
MAIN_DIR="$HOME/.local/share/caelestia"
SHELL_DIR="$XDG_CONFIG_HOME/quickshell/caelestia"
TMP_DIR="/tmp/caelestia-install"
FAILED=()

# ======= FUNCTIONS =======
step() { echo -e "\n\033[1;32m==> $1\033[0m"; }
fail() { FAILED+=("$1"); echo -e "\033[1;31m[FAIL]\033[0m $1"; }

# ======= 1. DEPENDENCIES =======
step "Installing dependencies..."
sudo pacman -Syu --needed --noconfirm git fish base-devel \
  python-build python-installer python-hatch python-hatch-vcs \
  pipewire pipewire-headers aubio aubio-tools pkgconf cmake

# Install paru if missing
if ! command -v paru &>/dev/null; then
  step "Installing paru (AUR helper)..."
  rm -rf /tmp/paru
  git clone https://aur.archlinux.org/paru.git /tmp/paru
  (cd /tmp/paru && makepkg -si --noconfirm)
  rm -rf /tmp/paru
fi

# ======= 2. CAELESTIA META =======
step "Installing caelestia-meta package..."
paru -S --needed --noconfirm caelestia-meta || fail "caelestia-meta install"

# ======= 3. MAIN DOTFILES =======
step "Cloning Caelestia main repo..."
rm -rf "$MAIN_DIR"
git clone --depth=1 https://github.com/caelestia-dots/caelestia.git "$MAIN_DIR" || fail "main repo clone"

step "Running main install.fish..."
(cd "$MAIN_DIR" && fish install.fish $INSTALL_FLAGS) || fail "install.fish"

# ======= 4. SHELL =======
step "Setting up Caelestia Shell..."
rm -rf "$SHELL_DIR"
git clone --depth=1 https://github.com/caelestia-dots/shell.git "$SHELL_DIR" || fail "shell repo clone"

if [ -f "$SHELL_DIR/assets/beat_detector.cpp" ]; then
  step "Compiling beat_detector..."
  g++ -std=c++17 -Wall -Wextra \
    -I/usr/include/pipewire-0.3 -I/usr/include/spa-0.2 -I/usr/include/aubio \
    -o beat_detector "$SHELL_DIR/assets/beat_detector.cpp" -lpipewire-0.3 -laubio \
    || fail "beat_detector compile"
  sudo mkdir -p /usr/lib/caelestia
  sudo mv beat_detector /usr/lib/caelestia/beat_detector || fail "beat_detector move"
fi

# ======= 5. CLI =======
step "Installing CLI..."
rm -rf "$TMP_DIR"
git clone --depth=1 https://github.com/caelestia-dots/cli.git "$TMP_DIR" || fail "cli repo clone"

(cd "$TMP_DIR" && python -m build --wheel) || fail "cli python build"
sudo python -m installer "$TMP_DIR"/dist/*.whl || fail "cli install"
sudo mkdir -p /usr/share/fish/vendor_completions.d
sudo cp "$TMP_DIR"/completions/caelestia.fish /usr/share/fish/vendor_completions.d/ || fail "cli fish completion install"
rm -rf "$TMP_DIR"

# ======= 6. SUMMARY =======
step "Installation complete."
if [ ${#FAILED[@]} -eq 0 ]; then
  echo -e "\033[1;32mAll components installed successfully!\033[0m"
  echo "Reboot or log out to start using Caelestia."
else
  echo -e "\033[1;31mSome components failed:\033[0m"
  for item in "${FAILED[@]}"; do echo " - $item"; done
  echo "You can re-run the script to retry."
fi

