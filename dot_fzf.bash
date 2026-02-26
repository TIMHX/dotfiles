# Setup fzf
# ---------
if [[ ! "$PATH" == */home/xing/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/xing/.fzf/bin"
fi

eval "$(fzf --bash)"
