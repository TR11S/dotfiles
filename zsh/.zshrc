# ~/.config/zsh/.zshrc — interactive zsh config (found via ZDOTDIR in ~/.zshenv)

# --- Environment -------------------------------------------------------------
export EDITOR=micro
export NNN_OPTS="eH"                  	# type-to-nav + show hidden files
typeset -U path                      	# keep PATH free of duplicates
path=(~/.pi/agent/bin ~/.local/bin $path)

# --- Options -----------------------------------------------------------------
setopt AUTO_CD                       	# type a directory name to cd into it
setopt INTERACTIVE_COMMENTS         	# allow # comments at the prompt
setopt NO_BEEP							# disable backspace beep sound
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS		# cd keeps a stack: `cd -<Tab>` lists recent dirs
setopt CORRECT							# Autocorrection on mistyped commands
setopt PUSHD_SILENT						# don't print the dir stack on every cd
setopt NO_FLOW_CONTROL					# free Ctrl+S / Ctrl+Q
WORDCHARS=${WORDCHARS//\/}				# Ctrl+W / Ctrl+Backspace stop at path segments

# --- History -----------------------------------------------------------------
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h}
setopt EXTENDED_HISTORY              	# store timestamps (matches imported fish history)
setopt SHARE_HISTORY                 	# share history live between shells
setopt HIST_IGNORE_ALL_DUPS          	# like fish: each command kept once (older copy dropped)
setopt HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt HIST_VERIFY                   	# !! / !$ expand into the line instead of running blindly

# --- Completion --------------------------------------------------------------
_zcache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $_zcache ]] || mkdir -p $_zcache
# Full security audit + rebuild at most once a day; otherwise trust the cached dump (-C).
# The dump is zcompiled in the background so later shells load the .zwc.
autoload -Uz compinit
_zdump="$_zcache/zcompdump"
_zstale=($_zdump(N.mh+24))
if [[ ! -s $_zdump || -n $_zstale ]]; then
  compinit -d $_zdump && touch $_zdump
else
  compinit -C -d $_zdump
fi
{ [[ -s $_zdump && ( ! -s $_zdump.zwc || $_zdump -nt $_zdump.zwc ) ]] && zcompile $_zdump } &!
unset _zdump _zstale
setopt COMPLETE_IN_WORD ALWAYS_TO_END                 # complete mid-word, cursor to end after
zstyle ':completion:*' menu select                    # arrow-key menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*'  # case-insensitive + partial words
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''                  # group matches by type
zstyle ':completion:*' use-cache yes                  # cache slow completions (pacman, etc.)
zstyle ':completion:*' cache-path "$_zcache/zcompcache"
zstyle ':completion:*' rehash true                    # see newly installed binaries without `rehash`
zstyle ':completion:*' special-dirs ..                # complete ../
zstyle ':completion:*' squeeze-slashes true           # a//b -> a/b

# --- Key bindings (emacs-style, foot key codes) ------------------------------
bindkey -e
bindkey '^[[H'  beginning-of-line              # Home / End / Delete
bindkey '^[[F'  end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word                 # Ctrl+Left/Right
bindkey '^[[1;5D' backward-word
bindkey '^H'      backward-kill-word           # Ctrl+Backspace
bindkey '^[[3;5~' kill-word                    # Ctrl+Delete
bindkey ' '       magic-space                  # expand !! / !$ inline on space
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E'    edit-command-line            # Ctrl+X Ctrl+E: edit the line in $EDITOR

# Tab: accept the autosuggestion if there is one, otherwise complete
# (fish: `bind \t accept-autosuggestion`)
_tab_accept_or_complete() {
  if [[ -n $POSTDISPLAY ]]; then
    zle autosuggest-accept
  else
    zle expand-or-complete
  fi
}
zle -N _tab_accept_or_complete
bindkey '^I' _tab_accept_or_complete
bindkey '^[[Z' reverse-menu-complete           # Shift+Tab: previous menu entry

# --- Prompt: ~/dir (git-branch) [last-exit-code] > ---------------------------
autoload -Uz vcs_info add-zsh-hook
add-zsh-hook precmd vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{magenta}(%b)%f'
setopt PROMPT_SUBST
PROMPT='%F{blue}%~%f${vcs_info_msg_0_} %(?..%F{red}[%?]%f )> '

# Right prompt: how long the last command took (only if >= 3s)
zmodload zsh/datetime
_cmd_start() { _cmd_t0=$EPOCHREALTIME }
_cmd_end() {
  RPROMPT=
  [[ -n $_cmd_t0 ]] || return
  local -i d=$(( EPOCHREALTIME - _cmd_t0 ))
  (( d >= 3 )) && RPROMPT="%F{8}${d}s%f"
  unset _cmd_t0
}
add-zsh-hook preexec _cmd_start
add-zsh-hook precmd _cmd_end

# --- Aliases & functions -----------------------------------------------------
alias ls='eza --group-directories-first'
alias ll='eza -lah --group-directories-first --git'
alias lt='eza --tree --level=2 --group-directories-first'   # tree view
alias cat='bat -p --paging=never'                            # syntax-highlighted cat
alias grep='grep --color=auto'
alias c='clear'
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"  # colored man pages (strip groff's own escapes first)

# zoxide: `z foo` jumps to the best-matching frecent dir, `zi` picks with fzf
# (init script cached; regenerated only when the zoxide binary is updated)
_zox="$_zcache/zoxide.zsh"
[[ -s $_zox && $_zox -nt ${commands[zoxide]} ]] || zoxide init zsh >| $_zox
source $_zox
unset _zox

# fzf: Ctrl+R history, Ctrl+T file picker, Alt+C cd into subdir
export FZF_DEFAULT_COMMAND='fd --hidden --exclude .git'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range=:200 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=1 --color=always {}'"
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border'
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:hidden:wrap --bind '?:toggle-preview'"  # ? shows long commands
[[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
# Auto-ls: list the directory after every cd (capped so huge dirs don't flood the screen)
_auto_ls() { eza --color=always --grid --width=$COLUMNS --group-directories-first . | head -n 30 }
add-zsh-hook chpwd _auto_ls

# edit: fuzzy-find & open any file in $HOME → ~/.local/bin/edit
alias e='edit'

# cfg: commit & push all ~/.config changes.  Usage: cfg [message]
# Without a message, it names the changed dirs, e.g. "update: mango zsh".
cfg() {
  local -a g=(git -C ~/.config)
  local changes=$($g status --porcelain)
  [[ -z $changes ]] && { echo "config: nothing to commit"; return }
  $g status --short
  local msg=${*:-"update: $(print -r -- $changes | awk '{print $2}' | cut -d/ -f1 | sort -u | paste -sd' ')"}
  $g add -A && $g commit -qm "$msg" && $g push -q && echo "pushed: $msg"
}

# get: fuzzy-pick packages from pacman repos, AUR (when a query is given) and Flathub.
# TAB multi-selects, ENTER installs each with the right tool.  Usage: get [query]
get() {
  local picks cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/flathub.tsv"
  # Flathub list is slow (~2.5s): cache it and rebuild when older than a day
  if [[ ! -s $cache || -n $(find $cache -mmin +1440) ]]; then
    flatpak remote-ls flathub --app --columns=application,name,description 2>/dev/null \
      | awk -F'\t' '$1 !~ /\.(BaseApp|Platform|Sdk)/ {printf "flatpak\t%s\t%s - %s\n", $1, $2, $3}' >| $cache
  fi
  # Source tags are padded to equal width (7) so they can't skew the begin tiebreak;
  # equal matches then fall back to input order: flatpak > pacman > AUR.
  # Process substitutions run in parallel; fzf starts showing lines as they arrive.
  picks=$(cat \
      $cache \
      <(pacman -Sl | awk '{printf "pacman \t%s\t%s %s [%s]\n", $2, $2, $3, $1}') \
      <(paru -Ssaq "$@" 2>/dev/null | awk '{printf "aur    \t%s\t%s (AUR)\n", $1, $1}') \
    | fzf -m -e --delimiter=$'\t' --with-nth=1,3 --tiebreak=begin,index --query="$*" \
          --header='TAB: multi-select, ENTER: install') || return
  local -a native flat
  native=(${(f)"$(print -r -- $picks | awk -F'\t' '$1!="flatpak"{print $2}')"})
  flat=(${(f)"$(print -r -- $picks | awk -F'\t' '$1=="flatpak"{print $2}')"})
  (( $#native )) && paru -S --needed $native
  (( $#flat ))   && flatpak install flathub $flat
}

# nnn: defines `n`, which cd's to nnn's last directory on quit
[[ -r /usr/share/nnn/quitcd/quitcd.bash_sh_zsh ]] && source /usr/share/nnn/quitcd/quitcd.bash_sh_zsh

# --- Plugins (fish built-ins: autosuggestions + syntax highlighting) --------
# sudo pacman -S zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
ZSH_AUTOSUGGEST_STRATEGY=(history completion)         # fish: history first, then completions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'                # dim gray like fish
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Up/Down: match typed text anywhere in history (must load after syntax-highlighting)
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down
unset _zcache
