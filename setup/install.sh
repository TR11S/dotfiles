#!/usr/bin/env bash
# install.sh — bring a machine to my setup: choose → review changes → y/n → apply.
#
#   ./install.sh                  menu → summary → y/n → apply
#   ./install.sh scripts system   skip the menu (still shows the summary and asks)
#   ./install.sh -y system        no questions at all (re-runs)
#   ./install.sh --diff           read-only: what's on THIS machine but not in the setup yet
#
# ── Maintaining: most changes are data, not code ─────────────────────────────
#   New package ...... only if a tracked config or script needs it: add it to <distro>/packages.txt
#                      (everything else, apps and Flatpaks included, you install by hand)
#   New /etc file .... cp /etc/foo/bar common/etc/foo/bar   (distro-only: <distro>/etc/foo/bar)
#   New service ...... add it to SERVICES below             (distro-only: DISTRO_SERVICES)
#   New script ....... put it in ~/.config/bin — it gets linked automatically
#   New config dir ... allow it in ~/.config/.gitignore — it comes with the repo
#   Anything else .... one `ensure` line in the matching step_* function (see below),
#                      e.g. a gsettings key (example in step_dotfiles)
#   New desktop/WM ... edit the Desktop part of <distro>/packages.txt; drop step_theme if you drop wallust
#   New step ......... write step_foo(), add foo to STEPS and DESC at the bottom
#   Not sure? ........ run ./install.sh --diff after changing your system
# Removing a name from a list never uninstalls anything; it just stops installing it.
#
# ── How steps work ───────────────────────────────────────────────────────────
# A step is a function made only of these lines:
#   ensure      "what it does"  'CHECK'  'FIX'     CHECK true = already done
#   ensure_each "what it does"  LIST_FN  FIX_FN    LIST_FN prints missing items, FIX_FN gets them
# Each chosen step runs twice. Plan mode: only the CHECKs/LIST_FNs run and every unmet one
# prints its description — that's the summary. Apply mode (after your y): the FIXes run
# for whatever is still unmet, in order. So CHECKs and LIST_FNs must be read-only.
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as your normal user (the script uses sudo)."; exit 1; }

# ── Settings ─────────────────────────────────────────────────────────────────
REPO=https://github.com/TR11S/dotfiles.git     # checked out into ~/.config
TIMEZONE=Europe/Berlin
LOCALE=en_US.UTF-8
KEYMAP=de
# System units enabled at boot (nothing is started now: reboot after).
SERVICES=(NetworkManager nftables systemd-timesyncd earlyoom tlp tlp-pd greetd
          fstrim.timer snapper-timeline.timer snapper-cleanup.timer)
# --diff ignores these enabled units (pulled in automatically by NetworkManager)
UNITS_IGNORE=(NetworkManager-dispatcher.service NetworkManager-wait-online.service)

# ── Engine (no need to touch this for normal maintenance) ────────────────────
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODE=plan
ensure() {  # ensure DESC CHECK FIX
  eval "$2" &>/dev/null && return 0
  if [[ $MODE == plan ]]; then echo "• $1"; else echo "  → $1"; eval "$3"; fi
}
ensure_each() {  # ensure_each DESC LIST_FN FIX_FN
  local items; mapfile -t items < <("$2")
  (( ${#items[@]} )) || return 0
  if [[ $MODE == plan ]]; then words "$1" "${items[@]}"; else echo "  → $1"; "$3" "${items[@]}"; fi
}
words() {  # words TITLE ITEM...  → "• TITLE (n):" then the items, wrapped
  local t=$1; shift
  printf '• %s (%d):\n' "$t" $#
  if printf '%s\n' "$@" | grep -q ' '; then printf '    %s\n' "$@"   # items with spaces: one per line
  else fold -s -w 72 <<<"$*" | sed 's/^/    /'; fi
}
note() { gum style --foreground 214 "  $*"; }
list() { sed 's/#.*//' "$@" | grep -oE '\S+' || true; }      # names from list files
sec()  { local out; out=$(cat); [[ -z $out ]] || { gum style --bold --foreground 212 "$1"; sed 's/^/  /' <<<"$out"; }; }

# ── Distro plugin: <distro>/<distro>.sh (contract documented in arch/arch.sh) ──
DISTRO= DISTRO_SERVICES=()
read -ra ids < <(. /etc/os-release; echo "$ID ${ID_LIKE:-}")   # e.g. "endeavouros arch"
for id in "${ids[@]}"; do [[ -f $HERE/$id/$id.sh ]] && { DISTRO=$id; break; }; done
if [[ -n $DISTRO ]]; then
  source "$HERE/$DISTRO/$DISTRO.sh"
else
  echo "No $HERE/<distro>/ for '${ids[*]}': package and distro steps hidden."
  pkg_install() { echo "Install manually: $*"; return 1; }
fi
command -v gum >/dev/null || { echo "Installing gum (needed for the menu)…"; pkg_install gum; }

# ════════════════════════════════════════════════════════════════════════════
# Steps
# ════════════════════════════════════════════════════════════════════════════

# ── distro: extras from <distro>/<distro>.sh ─────────────────────────────────
step_distro() { distro_step; }

# ── packages: what the configs need (+ Intel extras on Intel CPUs) ────────────
pkgs_wanted() {
  list "$HERE/$DISTRO/packages.txt"
  if grep -q GenuineIntel /proc/cpuinfo; then list "$HERE/$DISTRO/packages-intel.txt"; fi
}
repo_todo()   { local p; for p in $(pkg_missing $(pkgs_wanted)); do pkg_is_aur "$p" || echo "$p"; done; }
aur_todo()    { local p; for p in $(pkg_missing $(pkgs_wanted)); do pkg_is_aur "$p" && echo "$p"; done; return 0; }

step_packages() {
  ensure_each "install from repos (with full system upgrade)" repo_todo pkg_install
  ensure_each "build from AUR — paru asks you to review each" aur_todo  pkg_install
}

# ── dotfiles: ~/.config repo, shell init, dark mode, XDG dirs ────────────────
ZDOTDIR_LINE='export ZDOTDIR="$HOME/.config/zsh"'
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
SECRETS_LINE='[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"'
clone_dotfiles() {  # works on a non-empty ~/.config: tracked files win, untracked ones stay
  mkdir -p ~/.config
  git -C ~/.config init -q -b main
  git -C ~/.config remote add origin "$REPO"
  git -C ~/.config fetch -q origin
  git -C ~/.config checkout -qf -B main origin/main
}

step_dotfiles() {
  ensure "check out $REPO into ~/.config (tracked files replace existing ones)" \
         '[[ -d ~/.config/.git ]]'               'clone_dotfiles'
  ensure "~/.zshenv: zsh reads its config from ~/.config/zsh" \
         'grep -qxF "$ZDOTDIR_LINE" ~/.zshenv'   'echo "$ZDOTDIR_LINE" >> ~/.zshenv'
  ensure "~/.bashrc: add ~/.local/bin to PATH" \
         'grep -q "\.local/bin" ~/.bashrc'       'echo "$PATH_LINE" >> ~/.bashrc'
  ensure "~/.bashrc: source ~/.secrets" \
         'grep -qxF "$SECRETS_LINE" ~/.bashrc'   'echo "$SECRETS_LINE" >> ~/.bashrc'
  ensure "create empty ~/.secrets (mode 600)" \
         '[[ -e ~/.secrets ]]'                   'install -m600 /dev/null ~/.secrets'
  ensure "dark mode for GTK/libadwaita apps (gsettings)" \
         'gsettings get org.gnome.desktop.interface color-scheme | grep -q prefer-dark' \
         'gsettings set org.gnome.desktop.interface color-scheme prefer-dark'
  ensure "create XDG user dirs (~/Documents, ~/Pictures, …)" \
         '[[ -f ~/.config/user-dirs.dirs ]]'     'xdg-user-dirs-update'
  ensure "ssh-agent as a user socket (zshrc points SSH_AUTH_SOCK at it)" \
         'systemctl --user is-enabled -q ssh-agent.socket'  'systemctl --user enable -q ssh-agent.socket'
}

# ── theme: wallust colors + matching GTK3 theme ──────────────────────────────
# Everything wallust-specific lives here. Switching to a desktop that does its own
# theming? Delete this block and "theme" from STEPS/DESC at the bottom.
WALLPAPER_DIR=~/Pictures/Wallpapers
GTK_THEME=~/.local/share/themes/wallust/gtk-3.0/gtk.css
gtk_css() {  # "wallust" GTK3 theme = adw-gtk3-dark + wallust colors (wallust's gtk3 hook reloads it)
  printf '@import url("/usr/share/themes/adw-gtk3-dark/gtk-3.0/gtk.css");\n@import url("%s/.config/gtk-3.0/colors.css");\n' "$HOME"
}
first_colors() {  # wallust outputs are untracked: generate them once from the first wallpaper
  mkdir -p "$WALLPAPER_DIR"
  local wp; wp=$(find -L "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | head -n1)
  if [[ -n $wp ]] && command -v wallust >/dev/null; then wallust run "$wp"
  else note "No colors yet: put a wallpaper in $WALLPAPER_DIR, then pick it in fuzzel-settings."; fi
}

step_theme() {
  ensure "GTK3 theme 'wallust' in ~/.local/share/themes" \
         'gtk_css | cmp -s - "$GTK_THEME"'       'mkdir -p "${GTK_THEME%/*}"; gtk_css > "$GTK_THEME"'
  ensure "use it: gsettings gtk-theme wallust" \
         'gsettings get org.gnome.desktop.interface gtk-theme | grep -q wallust' \
         'gsettings set org.gnome.desktop.interface gtk-theme wallust'
  ensure "generate wallust colors from the first image in $WALLPAPER_DIR" \
         '[[ -f ~/.config/foot/colors.ini ]]'    'first_colors'
}

# ── scripts: ~/.config/bin/* → ~/.local/bin ─────────────────────────────────
links_todo() {  # missing or wrong links; a real file in the way is left alone (see --diff)
  local f n dst
  for f in "$HERE"/../bin/*; do
    [[ -e $f ]] || continue
    n=${f##*/} dst=~/.local/bin/${f##*/}
    [[ -e $dst && ! -L $dst ]] && continue
    [[ $(readlink "$dst") == "$HOME/.config/bin/$n" ]] || echo "$n"
  done
}
link_scripts() { mkdir -p ~/.local/bin; local n; for n; do ln -sfn ~/.config/bin/"$n" ~/.local/bin/"$n"; done; }

step_scripts() {
  ensure_each "link into ~/.local/bin" links_todo link_scripts
}

# ── system: /etc files, locale, keyboard, time, services, snapshots ──────────
etc_todo() {  # overlay files (relative to setup/) that differ from /etc
  local d f
  for d in common/etc ${DISTRO:+"$DISTRO/etc"}; do
    [[ -d $HERE/$d ]] || continue
    while IFS= read -r -d '' f; do
      f=${f#"$HERE"/}; cmp -s "$HERE/$f" "/etc/${f#*/etc/}" || echo "$f"
    done < <(find "$HERE/$d" -type f -print0 | sort -z)
  done
}
etc_install() { local f; for f; do sudo install -bDm644 "$HERE/$f" "/etc/${f#*/etc/}"; done; sudo sysctl --system >/dev/null; }
units_todo()   { local u; for u in "${SERVICES[@]}" "${DISTRO_SERVICES[@]}"; do systemctl is-enabled -q "$u" 2>/dev/null || echo "$u"; done; }
units_enable() { local u; for u; do if systemctl cat "$u" &>/dev/null; then sudo systemctl enable -q "$u"; else note "$u not installed — skipped"; fi; done; }
oomd_off()     { ! systemctl is-enabled -q systemd-oomd.service systemd-oomd.socket && ! systemctl is-active -q systemd-oomd; }
snapper_ok()   { [[ $(findmnt -no FSTYPE "$1") != btrfs || -f /etc/snapper/configs/$2 ]]; }   # snapper_ok MOUNT NAME

step_system() {
  ensure_each "copy into /etc (a replaced file is kept as file~)" etc_todo etc_install
  ensure "generate locale $LOCALE" \
         '[[ ! -f /etc/locale.gen ]] || grep -q "^$LOCALE" /etc/locale.gen' \
         'sudo sed -i "s/^#\s*\($LOCALE\)/\1/" /etc/locale.gen && sudo locale-gen'
  ensure "locale: LANG=$LOCALE" \
         'grep -qx "LANG=$LOCALE" /etc/locale.conf'  'sudo localectl set-locale "LANG=$LOCALE"'
  ensure "keyboard: $KEYMAP (console + XKB)" \
         'grep -qx "KEYMAP=$KEYMAP" /etc/vconsole.conf && grep -qx "XKBLAYOUT=$KEYMAP" /etc/vconsole.conf' \
         'sudo localectl set-keymap --no-convert "$KEYMAP"
          sudo localectl set-x11-keymap --no-convert "$KEYMAP" pc105 "" terminate:ctrl_alt_bksp'
  ensure "timezone: $TIMEZONE" \
         '[[ $(timedatectl show -p Timezone --value) == "$TIMEZONE" ]]'  'sudo timedatectl set-timezone "$TIMEZONE"'
  ensure_each "enable at boot" units_todo units_enable
  ensure "disable systemd-oomd (earlyoom replaces it)" \
         'oomd_off'  'sudo systemctl disable -q --now systemd-oomd.service systemd-oomd.socket'
  ensure "snapper config for /"     'snapper_ok /     root'  'sudo snapper -c root create-config /'
  ensure "snapper config for /home" 'snapper_ok /home home'  'sudo snapper -c home create-config /home'
}

# ── Reminders: shown in the summary while they still apply; never automated ──
remind() { eval "$2" &>/dev/null || echo "• $1"; }   # remind DESC CHECK
reminders() {
  remind "kernel cmdline: add zswap.enabled=0 (zram is used instead)"  'grep -q zswap.enabled=0 /proc/cmdline'
  remind "kernel cmdline: add :allow-discards to cryptdevice= (else no TRIM)" \
         '! grep -q cryptdevice= /proc/cmdline || grep -q allow-discards /proc/cmdline'
  remind "fstab: add compress=zstd:3 to the btrfs mounts" \
         '[[ $(findmnt -no FSTYPE /) != btrfs ]] || findmnt -no OPTIONS / | grep -q compress'
  remind "copy ~/.ssh, then: git -C ~/.config remote set-url origin git@github.com:TR11S/dotfiles.git" \
         'compgen -G "$HOME/.ssh/id_*"'
  remind "fill ~/.secrets (API keys)"            '[[ -s ~/.secrets ]]'
}

# ── --diff: what this machine has that the setup doesn't know about ──────────
diff_report() {
  # enabled units whose vendor preset is "disabled" = enabled by you
  comm -23 <(systemctl list-unit-files --state=enabled --no-legend | awk '$3=="disabled"{print $1}' | sort -u) \
           <(printf '%s\n' "${SERVICES[@]}" "${DISTRO_SERVICES[@]}" "${UNITS_IGNORE[@]}" | sed '/\./!s/$/.service/' | sort -u) \
    | sec "Enabled services not in SERVICES"
  etc_todo | while read -r f; do
    if [[ -e /etc/${f#*/etc/} ]]; then echo "/etc/${f#*/etc/}  → if the live one is right: cp /etc/${f#*/etc/} $HERE/$f"
    else echo "/etc/${f#*/etc/}  (not on this machine yet)"; fi
  done | sec "/etc differs from the setup copy (install would replace the live file)"
  find ~/.local/bin -maxdepth 1 -type f -printf '%f\n' | sort \
    | sec "Files in ~/.local/bin not from the repo → mv ~/.local/bin/NAME ~/.config/bin/ && ./install.sh scripts"
  git -C ~/.config status --short 2>/dev/null | sec "Uncommitted in ~/.config → commit and push"
  return 0
}

# ════════════════════════════════════════════════════════════════════════════
# Main: choose → summary → y/n → apply
# ════════════════════════════════════════════════════════════════════════════
STEPS=(distro packages dotfiles theme scripts system)   # menu and apply order
declare -A DESC=(
  [distro]="${DISTRO_DESC:-}"
  [packages]="Packages: what the configs need ($DISTRO/packages.txt)"
  [dotfiles]="Dotfiles: ~/.config repo, zsh/bash init, dark mode, XDG dirs"
  [theme]="Theme: wallust colors + matching GTK3 theme"
  [scripts]="Scripts: link ~/.config/bin into ~/.local/bin"
  [system]="System: /etc files, locale, timezone, services, snapper"
)
[[ -n $DISTRO ]] || DESC[packages]=          # empty description = step hidden
chosen() { [[ " ${picked[*]} " == *" $1 "* && -n ${DESC[$1]} ]]; }

YES=0 picked=()
for a; do
  case $a in
    -y) YES=1 ;;
    --diff) diff_report; exit 0 ;;
    *) [[ -n ${DESC[$a]:-} ]] && picked+=("$a") || note "unknown step '$a' (have: ${STEPS[*]})" ;;
  esac
done

# 1. Choose
gum style --border rounded --padding "0 2" --bold "Post-install · ${DISTRO:-unknown distro}"
if (( ! ${#picked[@]} )); then
  items=(); for s in "${STEPS[@]}"; do [[ -n ${DESC[$s]} ]] && items+=("$(printf '%-9s %s' "$s" "${DESC[$s]}")"); done
  mapfile -t picked < <(gum choose --no-limit --selected='*' --header "What to set up (space toggles, enter continues)" "${items[@]}" | awk '{print $1}')
fi
(( ${#picked[@]} )) || { echo "Nothing selected."; exit 0; }
sudo -v

# 2. Summary (plan mode: read-only)
echo; todo=()
for s in "${STEPS[@]}"; do
  chosen "$s" || continue
  out=$("step_$s") || true
  gum style --bold --foreground 212 "${DESC[$s]}"
  if [[ -n $out ]]; then sed 's/^/  /' <<<"$out"; todo+=("$s"); else echo "  already done"; fi
done
reminders | sec "Manual, not done by this script"
echo
(( ${#todo[@]} )) || { gum style --foreground 42 "Nothing to do."; exit 0; }

# 3. Confirm
(( YES )) || gum confirm "Apply these changes?" || { echo "Nothing changed."; exit 0; }

# 4. Apply
MODE=apply
for s in "${todo[@]}"; do
  gum style --bold --foreground 212 "▶ ${DESC[$s]}"
  # Subshell with its own set -e: a failing command aborts only this step.
  # (Plain `step || …` would silently disable set -e inside the step.)
  set +e; ( set -e; "step_$s" ); rc=$?; set -e
  (( rc == 0 )) || gum style --foreground 196 "✗ $s failed (exit $rc) — continuing"
done
gum style --bold --foreground 42 "Done. Reboot, then check: systemctl --failed, swapon --show"
