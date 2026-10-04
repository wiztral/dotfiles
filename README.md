# Wiztral's Dotfiles

Wiztral's dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

One command sets up a fresh machine. The same command brings an already
set-up machine up to date: finished steps are skipped.

## Windows

Run in a normal (non-elevated) PowerShell window, version 5.1 or later:

```powershell
irm https://raw.githubusercontent.com/wiztral/dotfiles/main/install.ps1 | iex
```

## Linux/macOS

Run as your normal user (not root):

```shell
curl -fsSL https://raw.githubusercontent.com/wiztral/dotfiles/main/install.sh | sh
```

On Linux the system prerequisites are installed with `apt-get`, `dnf` or
`pacman`; everything else comes from Homebrew.

## What the scripts do

Both scripts ask their questions first (name, email, a passphrase for a new
SSH key, and the sudo password on Linux/macOS) and then run unattended until
the SSH key has to be added to GitHub. On Linux/macOS the sudo password is
asked once more when zsh becomes the login shell, because Homebrew clears the
cached credential.

| Step | Windows (`install.ps1`) | Linux/macOS (`install.sh`) |
| --- | --- | --- |
| Prerequisites | Execution policy `RemoteSigned`, PowerShell 7 (winget, Scoop as fallback) | Compiler, `curl`, `git`, Homebrew |
| System settings | Developer Mode, long paths, `ssh-agent` service (one UAC prompt) | zsh as login shell |
| Dotfiles | `chezmoi init --apply`, or `chezmoi update` on an existing checkout | same |
| SSH | Creates `~/.ssh/id_ed25519` if missing, waits for it to be added to GitHub, then switches the dotfiles remote to SSH | same; skipped inside WSL, which reuses the Windows key through `ssh.exe` |

A step that cannot be completed (for example when the UAC prompt is declined)
does not stop the run. It is listed at the end under "Left for you to do".

Set `DOTFILES_BRANCH` before running to initialise from a branch other than
`main`. It only applies to the first initialisation.

## After setup

- **Windows:** WSL is not installed by the script. Run `wsl --install -d Ubuntu`
  from an elevated prompt, reboot, then run the Linux command inside it.
- Open a new terminal to pick up PATH and environment changes. On Windows,
  `refreshenv` reloads them in an existing PowerShell 7 window.

## Changing things later

- Packages: edit `home/.chezmoidata/packages.yaml`, then `chezmoi apply`.
- Windows environment variables and PATH entries: edit
  `home/.chezmoidata/env.yaml`, then `chezmoi apply`.
