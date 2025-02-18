### ZSH Settings

# It is not loading files if not running interactively
case $- in
  *i*) ;;
  *) return ;;
esac

# Loading custom scripts
source "${HOME}/.commonrc"
source "${HOME}/.common_zshrc"

# Initialize completion system
autoload -Uz compinit
compinit -d "${ZDOTDIR:-${HOME}}/.zcompdump" &!
