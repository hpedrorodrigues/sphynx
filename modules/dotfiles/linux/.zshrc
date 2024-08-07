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
if [ -f "${HOME}/.zgenom/zgenom.zsh" ]; then
  source "${HOME}/.zgenom/zgenom.zsh"

  zgenom autoupdate

  if ! zgenom saved; then
    zgenom load zsh-users/zsh-autosuggestions

    zgenom save
  fi
fi

if hash sx &>/dev/null; then
  # Regenerating .zcompdump file when sphynx completions were not loaded
  if ! grep -q 'sx' "${HOME}/.zcompdump"; then
    autoload -U compinit && compinit
  fi
fi
