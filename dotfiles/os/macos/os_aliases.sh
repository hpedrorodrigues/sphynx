#!/usr/bin/env bash

## Aliases

# System

alias ls='gls --color=tty --group-directories-first --human-readable'

# Updates

alias up_os='sudo softwareupdate --install --all'
alias up_brew='brew update && brew upgrade && brew autoremove && brew cleanup -s --prune 30 && brew services cleanup'
alias up_cask='brew update && brew upgrade --cask --greedy --force'

alias up_all='up_os && up_brew && up_cask'
