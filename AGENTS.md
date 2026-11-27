# System & config facts
## System Philosophy
- Simplicity & performance (keeping every managable makes housekeeping & control easier & leaves performance gains to essential work)
- Shell scripts (e.g. in `~/.local/bin`) get edited by hand later: keep them minimal, simple to read & edit.

## Machine
- Arch Linux (rolling), Intel i5-8365U / UHD 620.
- Wayland only. Compositor: **MangoWM** (wlroots, dwm-like tiling)
- `paru` for AUR, `pacman` otherwise. No Node/npm/bun; Python via `uv`; Rust toolchain installed.

## Shell & tools
- Interactive shell: **zsh** (`foot.ini` sets `shell=/usr/bin/zsh`). Login shell in passwd is bash;
- `EDITOR=micro`; also nnn, btop, fzf, ripgrep, git.
- `~/.secrets` (mode 600) holds API keys and is sourced by `.bashrc` and `zsh/.zshrc`. Never read, print, or commit its contents.

## Desktop stack
- `foot` terminal (server mode), `fuzzel` launcher, `mangobar` bar, micro editor.
- `fuzzel-settings` — central menu for wifi, bluetooth, sound, brightness, appearance, wallpaper, night light, time, power.
- Screenshots: grim/slurp
- clipboard: wl-clipboard
- Wallpaper: `awww` daemon; `wallust` regenerates colors from the wallpaper. don't hand-edit colors.
- Screenlock + idle: Swaylock + Swayidle
- Notification daemon: mako + libnotify
- OOM: earlyoom (`/etc/default/earlyoom`); systemd-oomd disabled

## Local LLM
- llama.cpp servers as user units (start on demand): llama-qwen35 (:8081), llama-minicpm (:8080), llama-lfm3 (:8082); models under `~/models/llama.cpp`; launch scripts in `~/.local/bin/{qwen35,minicpm,lfm3}{,-server}`.

## Checks
-  mango: `mango -p`; foot: `foot --check-config` (if asked to verify).
- After config changes: reload mango with `SUPER+SHIFT+r`

## Repo
- `~/.config` is a git repo with an allowlist `.gitignore` (add new dirs there explicitly). wallust outputs are not tracked.
- `bin/` holds tracked scripts, symlinked into `~/.local/bin`.
