#!/usr/bin/env bash

## Aliases

# System

alias ls='ls --color=tty'

# Packaging Tool

alias aptu='sudo apt-get update -y'
alias apti='sudo apt-get install -y'
alias aptr='sudo apt-get remove'
alias apts='sudo apt-cache search'

# Updates

alias up_os='sudo apt update -y && sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y && sudo apt clean -y'
alias up_snap='sudo snap refresh'
alias up_brew='brew update && brew upgrade && brew autoremove && brew cleanup -s --prune 30 && brew services cleanup'

alias up_all='up_os && up_snap && up_brew'
