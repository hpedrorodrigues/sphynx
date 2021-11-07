#!/usr/bin/env bash

## Aliases

# System

alias ls='gls --color=tty --group-directories-first --human-readable'

# Updates

alias uposx='sudo softwareupdate --install --all'

# shellcheck disable=SC1004  # This backslash+linefeed is literal
alias upbrew='brew update \
                && brew upgrade \
                && brew cleanup -s --prune 30'

alias upbrewcask='brew update && brew upgrade --cask --greedy --force'

# shellcheck disable=SC1004  # This backslash+linefeed is literal
alias upnpm='npm install --global npm \
              && npm --global cache clean --force \
              && npm --global update'

alias upall='uposx && upbrew && upbrewcask && upnpm'
