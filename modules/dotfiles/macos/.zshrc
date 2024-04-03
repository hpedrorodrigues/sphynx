### ZSH Settings

# It is not loading files if not running interactively
case $- in
  *i*) ;;
  *) return ;;
esac

# Loading custom scripts
source "${HOME}/.commonrc"
source "${HOME}/.common_zshrc"

# Regenerate .zcompdump file if sphynx completions are not loaded
if hash sx &>/dev/null && ! grep -q 'sx' "${HOME}/.zcompdump"; then
  autoload -U compinit && compinit
fi
