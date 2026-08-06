# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal dotfiles repository managed by [chezmoi](https://www.chezmoi.io/), targeting Windows, macOS, Linux (Ubuntu), and WSL from one source tree. There is no build or test suite — the "build" is `chezmoi apply`.

The working directory is the chezmoi **source directory** itself (`~/.local/share/chezmoi`). Edit files here, then apply; never edit the generated files in `$HOME` directly, since `chezmoi apply` will overwrite them.

## Source root: `home/`

`.chezmoiroot` contains `home`, so chezmoi treats `home/` as the source root and ignores everything above it. Consequences:

- Anything added under `home/` becomes a deployed dotfile.
- Repo-only files (this file, `README.md`) belong at the repo root, where chezmoi never sees them.
- Paths in chezmoi docs that say "source directory" map to `home/` here.

## Common commands

```shell
chezmoi diff                    # preview what apply would change
chezmoi apply -v                # deploy to $HOME
chezmoi apply -n -v             # dry run
chezmoi apply ~/.config/nvim    # apply a single target
chezmoi cd                      # shell in the source dir (pwsh on Windows)
chezmoi doctor                  # environment sanity check
chezmoi execute-template < home/dot_zshrc.tmpl   # render a template to stdout
chezmoi data                    # dump the template variables (.osId, .user, .packages)
chezmoi init                    # regenerate ~/.config/chezmoi/chezmoi.toml after editing .chezmoi.toml.tmpl
chezmoi state delete-bucket --bucket=scriptState  # forget run_once_/run_onchange_ state so scripts re-run
```

Neovim Lua is formatted with stylua (`home/dot_config/exact_nvim/stylua.toml`: 2 spaces, 120 columns).

Zebar bar widget (`home/dot_glzr/zebar/wiztral-zb/glazewm-bar/`) is a real Vite + React + TS project:

```shell
pnpm dev      # vite dev server
pnpm build    # tsc -b && vite build  — REQUIRED, dist/ is committed
pnpm lint     # eslint .
```

Its `dist/` is checked in on purpose: `zpack.json` points the widget at `./glazewm-bar/dist/index.html`, so a source change is only live after `pnpm build` and committing the rebuilt `dist/`.

## Naming conventions (chezmoi attributes)

File and directory names encode behavior. Renaming a file changes what it does.

| Prefix/suffix | Meaning |
|---|---|
| `dot_foo` | deploys as `.foo` |
| `exact_dir` | chezmoi **deletes** files in the target dir that aren't in source |
| `foo.tmpl` | rendered as a Go text/template |
| `modify_dot_foo` | script whose stdout replaces the target; receives current contents on stdin |
| `run_once_*` | runs once, tracked by script hash in chezmoi state |
| `run_onchange_*` | re-runs whenever the rendered script content changes |
| `*_before_*` / `*_after_*` | ordering relative to the apply phase |

## Cross-platform architecture

**`.osId` is the central switch.** `home/.chezmoi.toml.tmpl` computes it once and exposes it as `.osId`: `windows`, `darwin`, `linux-<distro id>`, or `wsl-<distro id>` (WSL detected by `microsoft` in the kernel osrelease). Every OS branch elsewhere keys off `.osId`, not `.chezmoi.os`.

**OS gating happens in two layers, and both must agree:**

1. `home/.chezmoiignore.tmpl` decides which *files* exist for this OS — e.g. on non-Windows it ignores `AppData/`, `Documents/`, `.glaze-wm/`, `quick-cmds/`; on Windows it ignores `.config/tmux/` and `.zshrc`. Note it lists **target** paths (`.zshrc`), not source names (`dot_zshrc.tmpl`).
2. `home/.chezmoiscripts/{linux_darwin,windows}/` splits the provisioning scripts, and `.chezmoiignore.tmpl` also ignores the irrelevant script directory.

Adding a config for one OS means touching both.

## Package management

`home/.chezmoidata/packages.yaml` is the single source of truth, with three lists: `brews` (Linux/macOS), `scoops` (Windows, `bucket/name` form), `wingets` (currently empty).

The install scripts are `run_onchange_after_install_packages.{sh,ps1}.tmpl`; they template the package list directly into the script body, so **editing `packages.yaml` changes the script hash and triggers reinstall on the next apply**. That's the intended mechanism — no separate step.

Bootstrap ordering per OS:

- Linux/macOS: `run_once_before_install_homebrew` (apt prereqs on Linux, then Homebrew) → `run_once_install_zsh` (brew zsh, register in `/etc/shells`, `chsh`, oh-my-zsh) → `run_onchange_after_install_packages` (`brew bundle` from a heredoc). Every script re-evals `brew shellenv` from the three possible prefixes (`/opt/homebrew`, `/usr/local`, `/home/linuxbrew/.linuxbrew`) because PATH isn't inherited between scripts.
- Windows: `run_once_before_install_scoop` (install scoop, git, add `extras`/`java`/`nerd-fonts` buckets) → `run_onchange_after_install_packages` (one batched `scoop install`) plus `run_onchange_before_set_env_variables` (`XDG_CONFIG_HOME`, `EDITOR`) and `run_onchange_set_user_path` (appends `~/quick-cmds` to the user PATH).

PowerShell scripts use `Set-StrictMode -Version 3.0`, `$ErrorActionPreference = "Stop"`, and explicit `if ($LASTEXITCODE -ne 0) { throw ... }` after native commands — native exit codes don't trip `$ErrorActionPreference`. Bash scripts use `set -euo pipefail`. Match this when adding scripts.

`home/.chezmoiexternal.toml.tmpl` pulls git repos not tracked here: tpm (tmux plugin manager) on non-Windows, catppuccin rio theme on Windows, both with a 168h refresh.

## Git config: the two-file pattern

The user's `~/.gitconfig` is not owned by chezmoi. Instead:

- `home/dot_gitconfig.base.tmpl` → managed `~/.gitconfig.base` (name/email from `.user`, `init.defaultBranch = main`, plus Windows-only `core.sshCommand` found via `findExecutable` and the `credential manager` helper).
- `home/modify_dot_gitconfig` is a `chezmoi:modify-template` script that reads the existing `~/.gitconfig` on stdin and idempotently injects an `[include] path = .gitconfig.base` block between `# Start Include Base` / `# End Include Base` markers, preserving everything else.

So machine-specific git settings survive in `~/.gitconfig` while shared settings live here. Don't convert this to a plain managed `dot_gitconfig`.

## Neovim config

`home/dot_config/exact_nvim/` is a LazyVim starter. Because of `exact_`, any file present in `~/.config/nvim` but absent here is deleted on apply.

- `lua/config/lazy.lua` — bootstrap; imports `lazyvim.plugins` then the local `plugins` module.
- `lua/exact_plugins/*.lua` — per-topic plugin specs/overrides (colorscheme, deno, eslint, kotlin, neogit, oil, prettier, snacks, tailwindcss, tinymist). Add a new file per plugin; the directory is auto-imported.
- `lazyvim.json` — the enabled LazyVim extras list. Adding language support usually means adding an entry here rather than writing a spec.
- `lua/custom/commands/*.lua` — standalone user commands, wired up by `require` calls at the bottom of `lua/config/autocmds.lua`.
- `lazy-lock.json` — plugin lockfile; update it via `:Lazy update` inside nvim, commit as `chore(nvim): update deps`.

Note the directory holds both `.gitignore` and `dot_gitignore` (and `.neoconf.json` / `dot_neoconf.json`) with identical contents. chezmoi ignores source entries starting with `.`, so the dot-prefixed copies are the ones deployed and the literal ones apply to this repo. Edit both if you change one.

## Shell configuration

- `home/dot_zshrc.tmpl` — oh-my-zsh, `EDITOR=nvim`, brew shellenv probe, fnm (`--use-on-cd`, recursive version-file strategy), fzf, pyenv. The `wsl-ubuntu` branch adds `ssh.exe` aliasing, an OSC-9 precmd so Windows Terminal keeps the cwd on tab duplication, and conditional VcXsrv launch via `config.xlaunch`.
- `home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1` — PSFzf bindings (Tab completion, `Ctrl+t`, `Ctrl+r`), fnm, oh-my-posh with `~/.config/ohmyposh/base.toml`.

Not a template, so it can't branch on `.osId` — it is Windows-only by way of `.chezmoiignore.tmpl` ignoring `Documents/`.

## Commit conventions

Conventional commits with an optional component scope, matching existing history: `feat(nvim):`, `chore(nvim): update deps`, `fix(zebar):`, `refactor(nvim):`, `feat(packages):`, `feat(chezmoi):`, `feat(scripts):`, `feat(glazewm):`, `feat(PowerShell):`.
