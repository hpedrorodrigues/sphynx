#!/usr/bin/env bash

function sx::shell::reload_completion::zsh() {
  sx::shell::check_requirements
  sx::require 'zsh'

  if [ -f "${HOME}/.zcompdump" ]; then
    rm -f "${HOME}/.zcompdump"*
  fi

  # References:
  # - http://zsh.sourceforge.net/Doc/Release/Completion-System.html
  zsh -c 'autoload -U compinit -U bashcompinit && compinit && bashcompinit'
}
