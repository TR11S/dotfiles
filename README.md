# dotfiles

`~/.config` for Arch Linux + MangoWM (Wayland): foot, fuzzel, mangobar, mako, swaylock, micro, zsh. Colors come from the wallpaper via wallust.

## Restore

On a fresh install (any distro with a `setup/<distro>/` folder; Arch today):

```sh
git clone https://github.com/TR11S/dotfiles.git /tmp/dotfiles
/tmp/dotfiles/setup/install.sh      # menu; checks ~/.config out from the repo itself
```

Re-run any step later with `~/.config/setup/install.sh <step>` (`distro packages dotfiles theme scripts system`).
Packages the configs need live in `setup/arch/packages.txt` (apps: install by hand), system files in `setup/common/etc/` and `setup/arch/etc/` (mirror `/etc`).
After changing the system, `setup/install.sh --diff` lists what isn't captured yet (cheat sheet at the top of `install.sh`).

## Notes

- `.gitignore` is an allowlist: add `!/appname/` there before tracking a new config.
- Scripts in `bin/` are symlinked into `~/.local/bin`.
