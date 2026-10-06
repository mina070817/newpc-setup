# Setup fzf
# ---------
if [[ ! "$PATH" == *__HOME__/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}__HOME__/.fzf/bin"
fi

source <(fzf --zsh)
