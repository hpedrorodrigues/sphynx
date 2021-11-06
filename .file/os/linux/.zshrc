### ZSH Settings

# It is not loading files if not running interactively
case $- in
  *i*) ;;
  *) return ;;
esac

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
fi
