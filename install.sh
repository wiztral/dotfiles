#!/bin/sh
# Set up a Linux or macOS machine from these dotfiles with a single command:
#
#   curl -fsSL https://raw.githubusercontent.com/wiztral/dotfiles/main/install.sh | sh
#
# It is safe to re-run: steps that are already done are skipped, and an
# existing checkout is updated instead of re-initialised.
#
# Optional environment variables:
#   DOTFILES_REPO    GitHub user or repo to initialise from (default: wiztral)
#   DOTFILES_BRANCH  branch to check out on first initialisation

set -eu

REPO="${DOTFILES_REPO:-wiztral}"
BRANCH="${DOTFILES_BRANCH:-}"
KEY_PATH="$HOME/.ssh/id_ed25519"
SOURCE_DIR="$HOME/.local/share/chezmoi"
NOTES=""

step() {
  printf '\n\033[36m==> %s\033[0m\n' "$1"
}

warn() {
  printf '\033[33m%s\033[0m\n' "$1"
}

note() {
  NOTES="${NOTES}  - $1
"
}

has() {
  command -v "$1" >/dev/null 2>&1
}

# The script itself arrives on stdin when piped from curl, so every question
# has to be read from the terminal.
ask() {
  printf '%s: ' "$1" >/dev/tty
  IFS= read -r REPLY </dev/tty
}

ask_secret() {
  printf '%s: ' "$1" >/dev/tty
  stty -echo </dev/tty
  IFS= read -r REPLY </dev/tty || true
  stty echo </dev/tty
  printf '\n' >/dev/tty
}

load_brew() {
  for brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [ -x "$brew" ]; then
      eval "$("$brew" shellenv)"
      return 0
    fi
  done
  return 1
}

github_accepts_key() {
  # ssh -T exits non-zero even on success, so match on the greeting.
  "$SSH" -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 git@github.com 2>&1 |
    grep -q 'successfully authenticated'
}

# Everything runs inside a function so the shell has read the whole script
# before any command gets a chance to consume the rest of it from stdin.
main() {
  OS="$(uname -s)"
  IS_WSL=false
  if [ "$OS" = "Linux" ] && grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
  fi

  if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not as root: Homebrew refuses to install as root." >&2
    exit 1
  fi

  # --- 1. Questions, all up front ----------------------------------------------

  step "A few questions before the unattended part"

  NAME=""
  EMAIL=""
  if [ -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
    echo "chezmoi is already configured; keeping the existing name and email."
  else
    while [ -z "$NAME" ]; do ask "Your name"; NAME="$REPLY"; done
    while [ -z "$EMAIL" ]; do ask "Your email address"; EMAIL="$REPLY"; done
  fi

  GENERATE_KEY=false
  PASSPHRASE=""
  if $IS_WSL; then
    echo "WSL shares the SSH key and agent of Windows (ssh.exe); not creating a key here."
  elif [ -f "$KEY_PATH" ]; then
    echo "SSH key already exists at $KEY_PATH; keeping it."
  else
    GENERATE_KEY=true
    while :; do
      ask_secret "Passphrase for a new SSH key (empty for none)"; PASSPHRASE="$REPLY"
      ask_secret "Repeat the passphrase"
      [ "$PASSPHRASE" = "$REPLY" ] && break
      warn "Passphrases do not match, try again."
    done
  fi

  echo "Administrator rights are needed for system packages and the login shell."
  sudo -v </dev/tty

  # Keep the sudo credential fresh until this script exits, so the long package
  # installs further down never stop to ask again.
  (
    while kill -0 "$$" 2>/dev/null; do
      sudo -n true 2>/dev/null || exit
      sleep 50
    done
  ) &
  SUDO_KEEPALIVE=$!
  ASKPASS=""
  STARTED_AGENT=false
  cleanup() {
    kill "$SUDO_KEEPALIVE" 2>/dev/null || true
    [ -n "$ASKPASS" ] && rm -f "$ASKPASS"
    if $STARTED_AGENT; then ssh-agent -k >/dev/null 2>&1 || true; fi
  }
  trap cleanup EXIT

  # --- 2. System prerequisites for Homebrew ------------------------------------

  if [ "$OS" = "Linux" ]; then
    step "System prerequisites"
    if has apt-get; then
      sudo apt-get update
      sudo apt-get install -y build-essential procps curl file git
    elif has dnf; then
      # curl is left out on purpose: it is already present, and installing it
      # conflicts with the curl-minimal package of recent Fedora releases.
      sudo dnf install -y gcc gcc-c++ make procps-ng file git
    elif has pacman; then
      sudo pacman -Syu --needed --noconfirm base-devel procps-ng curl file git
    else
      echo "Unsupported distribution: none of apt-get, dnf or pacman was found." >&2
      exit 1
    fi
  fi

  # --- 3. Homebrew --------------------------------------------------------------

  step "Homebrew"
  if load_brew; then
    echo "Already installed."
  else
    # On macOS this also installs the Xcode Command Line Tools.
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew
  fi

  # --- 4. chezmoi ---------------------------------------------------------------

  step "chezmoi"
  has chezmoi || brew install chezmoi

  if [ -d "$SOURCE_DIR/.git" ]; then
    echo "Updating the existing checkout in $SOURCE_DIR"
    chezmoi update --init </dev/tty
  else
    set -- init --apply
    [ -n "$BRANCH" ] && set -- "$@" --branch "$BRANCH"
    [ -n "$NAME" ] && set -- "$@" --promptString "Your name=$NAME" --promptString "Your email address=$EMAIL"
    chezmoi "$@" "$REPO" </dev/tty
  fi

  # --- 5. SSH key and GitHub ----------------------------------------------------

  step "SSH key"
  SSH=ssh
  if $IS_WSL; then
    SSH=ssh.exe
  fi

  if ! has "$SSH"; then
    if $IS_WSL; then
      note "ssh.exe was not found on PATH. Run install.ps1 on the Windows side first; WSL reuses its SSH key."
    else
      note "ssh was not found, so no SSH key was set up."
    fi
  else
    if $GENERATE_KEY; then
      [ -n "$EMAIL" ] || EMAIL="$(chezmoi execute-template '{{ .user.email }}')"
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      ssh-keygen -q -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N "$PASSPHRASE"
      echo "Created $KEY_PATH"

      if [ "$OS" = "Darwin" ] && ! grep -qs 'UseKeychain' "$HOME/.ssh/config"; then
        # Load the key from the keychain automatically after a reboot.
        printf 'Host *\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile ~/.ssh/id_ed25519\n' >>"$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
      fi

      if [ -z "${SSH_AUTH_SOCK:-}" ]; then
        # No agent in this session: use a temporary one for the GitHub check.
        eval "$(ssh-agent -s)" >/dev/null
        STARTED_AGENT=true
      fi

      # Hand the passphrase to ssh-add through SSH_ASKPASS so it is not asked
      # for a second time.
      ASKPASS="$(mktemp)"
      printf '#!/bin/sh\nprintf "%%s\\n" "$DOTFILES_SSH_PASSPHRASE"\n' >"$ASKPASS"
      chmod 700 "$ASKPASS"
      if [ "$OS" = "Darwin" ]; then
        set -- --apple-use-keychain "$KEY_PATH"
      else
        set -- "$KEY_PATH"
      fi
      if ! DOTFILES_SSH_PASSPHRASE="$PASSPHRASE" SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force \
        ssh-add "$@" </dev/null >/dev/null 2>&1; then
        # Older OpenSSH releases ignore SSH_ASKPASS_REQUIRE; ask directly.
        ssh-add "$@" </dev/tty || note "The new key could not be added to ssh-agent. Run: ssh-add $KEY_PATH"
      fi
    fi

    AUTHENTICATED=false
    if github_accepts_key; then
      AUTHENTICATED=true
    elif $IS_WSL; then
      note "GitHub does not accept the Windows SSH key yet. Finish install.ps1 on the Windows side, then re-run this script."
    else
      {
        printf '\n'
        warn "Add this public key to GitHub:"
        printf '  https://github.com/settings/ssh/new\n\n'
        cat "$KEY_PATH.pub"
        printf '\n'
      } >/dev/tty
      while :; do
        ask "Press Enter once the key is added, or type 'skip'"
        [ "$REPLY" = "skip" ] && break
        if github_accepts_key; then
          AUTHENTICATED=true
          break
        fi
        warn "GitHub did not accept the key yet."
      done
      $AUTHENTICATED || note "GitHub does not accept the SSH key yet. Add $KEY_PATH.pub at https://github.com/settings/ssh/new and re-run this script to switch the dotfiles remote to SSH."
    fi

    if $AUTHENTICATED; then
      echo "GitHub accepts the SSH key."
      ORIGIN="$(git -C "$SOURCE_DIR" remote get-url origin)"
      case "$ORIGIN" in
        https://github.com/*)
          REPO_PATH="${ORIGIN#https://github.com/}"
          REPO_PATH="${REPO_PATH%/}"
          REPO_PATH="${REPO_PATH%.git}"
          git -C "$SOURCE_DIR" remote set-url origin "git@github.com:$REPO_PATH.git"
          echo "Dotfiles remote switched to git@github.com:$REPO_PATH.git"
          ;;
      esac
    fi
  fi

  # --- 6. Summary ---------------------------------------------------------------

  step "Done"
  note "Log out and back in (or run 'exec zsh') to start using zsh with the new configuration."
  echo "Left for you to do:"
  printf '%s' "$NOTES"
}

main "$@"
