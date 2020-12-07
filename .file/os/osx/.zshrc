### ZSH Settings

# It is not loading files if not running interactively
case $- in
  *i*) ;;
  *) return ;;
esac

# Setting language environment
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# Loading custom scripts
source "${HOME}/.commonrc"
source "${HOME}/.common_zshrc"

#|> zgen
# Don't move this block to .common_zshrc
if [ -f "${HOME}/.zgen/zgen.zsh" ]; then
  source "${HOME}/.zgen/zgen.zsh"

  if ! zgen saved; then
    zgen load zsh-users/zsh-autosuggestions
    zgen load agkozak/zsh-z

    zgen save
  fi
fi

if hash sx &>/dev/null; then
  # Regenerating .zcompdump file when sphynx completions were not loaded
  if ! grep -q 'sx' "${HOME}/.zcompdump"; then
    autoload -U compinit && compinit
  fi

  # Load the tmux "hack" session on zsh startup
  # Notes:
  # - not loading tmux in sphynx benchmarks because it's not important for it
  # - not loading tmux if a screen session is currently active
  # - loading the tmux session only when using Alacritty
  if [ -z "${SX_SHELL_BENCHMARK}" ] \
    && [ -z "${STY}" ] \
    && [ -z "${TMUX}" ] \
    && [ -n "${ALACRITTY_LOG}" ]; then
    sx terminal tmux force-attach hack
  fi
fi
