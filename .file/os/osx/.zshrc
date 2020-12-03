### ZSH Settings

# It is not loading files and if not running interactively
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
    zgen oh-my-zsh kubectl
    zgen oh-my-zsh gcloud
    zgen load zsh-users/zsh-autosuggestions
    zgen load agkozak/zsh-z

    zgen save
  fi

  # Force regenerate the .zcompdump file with the sphynx completions
  # if they were not included before
  if ! grep -q sx "${HOME}/.zcompdump"; then
    autoload -U compinit && compinit
  fi
fi

# Load the tmux "hack" session on zsh startup
# Note: not loading tmux in sphynx benchmarks because it's not important for it
if [[ $- == *i* ]] \
  && hash sx &>/dev/null \
  && [ -z "${SX_SHELL_BENCHMARK}" ] \
  && [ -z "${STY}" ] \
  && [ -z "${TMUX}" ]; then
  sx terminal tmux force-attach hack
fi
