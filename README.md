# dotfiles

`~/.config` for Arch Linux + MangoWM (Wayland): foot, fuzzel, mangobar, mako, swaylock, micro, zsh. Colors come from the wallpaper via wallust.

## Restore

```sh
git clone git@github.com:TR11S/dotfiles.git ~/.config
ln -s ~/.config/bin/* ~/.local/bin/
echo 'export ZDOTDIR="$HOME/.config/zsh"' >> ~/.zshenv
wallust run <wallpaper>    # generates the untracked color files
```

## Notes

- `.gitignore` is an allowlist: add `!/appname/` there before tracking a new config.
- Scripts in `bin/` are symlinked into `~/.local/bin`.
