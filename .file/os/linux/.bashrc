#!/usr/bin/env bash

# It is not loading files if not running interactively
case $- in
  *i*) ;;
  *) return ;;
esac

### Loading custom scripts
source "${HOME}/.commonrc"
source "${HOME}/.common_bashrc"

#|> Linuxbrew
export LINUXBREW_HOME="${HOME}/.linuxbrew"
export LINUXBREW_BIN="${LINUXBREW_HOME}/bin/brew"

export LINUXBREW_USER_HOME='/home/linuxbrew/.linuxbrew'
export LINUXBREW_USER_BIN="${LINUXBREW_USER_HOME}/bin/brew"

[ -d "${LINUXBREW_HOME}" ] && [ -f "${LINUXBREW_BIN}" ] \
  && eval "$("${LINUXBREW_BIN}" shellenv)"

[ -d "${LINUXBREW_USER_HOME}" ] && [ -f "${LINUXBREW_USER_BIN}" ] \
  && eval "$("${LINUXBREW_USER_BIN}" shellenv)"

hash brew 2>/dev/null \
  && eval "$("$(brew --prefix)/bin/brew" shellenv)"
