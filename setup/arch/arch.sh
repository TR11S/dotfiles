# arch.sh — Arch-only parts, sourced by install.sh (also used on Arch derivatives via ID_LIKE).
# packages.txt = what the tracked configs need; packages-intel.txt is added on Intel CPUs.
# Arch-only /etc files live in arch/etc/ (copied by the system step), e.g. the Limine hook.
#
# Plugin contract — a new distro's <distro>/<distro>.sh defines the same names:
#   DISTRO_DESC          menu label for the distro extras step
#   DISTRO_SERVICES=()   extra units the system step enables
#   pkg_missing PKG...   print the packages not installed yet        (read-only)
#   pkg_is_aur PKG       true if PKG is not in the official repos     (read-only)
#   pkg_install PKG...   install packages
#   distro_step          ensure lines, like any step in install.sh

DISTRO_DESC="Arch extras: pacman.conf (color, parallel downloads)"
DISTRO_SERVICES=(paccache.timer)   # weekly cache cleanup (keeps 3 versions)

# ── Packages ─────────────────────────────────────────────────────────────────
pkg_missing()  { (( $# )) || return 0; pacman -T "$@" || true; }
_repo=
pkg_is_aur()   { [[ -n $_repo ]] || _repo=$(pacman -Slq); ! grep -qxF "$1" <<<"$_repo"; }

# Repo packages via pacman (with full upgrade, no partial upgrades), the rest via paru.
# paru is built on first use; it stays interactive on purpose: you review each AUR build.
pkg_install() {
  local repo=() aur=() p
  for p; do if pkg_is_aur "$p"; then aur+=("$p"); else repo+=("$p"); fi; done
  if (( ${#repo[@]} )); then sudo pacman -Syu --needed --noconfirm "${repo[@]}"; fi
  if (( ${#aur[@]} )); then
    command -v paru >/dev/null || install_paru
    paru -S --needed "${aur[@]}"
  fi
}

install_paru() {
  sudo pacman -S --needed --noconfirm base-devel git
  local d; d=$(mktemp -d)
  git clone -q https://aur.archlinux.org/paru-bin.git "$d"
  (cd "$d" && makepkg -si --noconfirm)
  rm -rf "$d"
}

# ── Step ─────────────────────────────────────────────────────────────────────
distro_step() {
  ensure "/etc/pacman.conf: Color, ParallelDownloads = 5" \
         'grep -q "^Color" /etc/pacman.conf && grep -q "^ParallelDownloads" /etc/pacman.conf' \
         'sudo sed -i "s/^#Color/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 5/" /etc/pacman.conf'
}
