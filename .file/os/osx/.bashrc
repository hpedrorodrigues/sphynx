#!/usr/bin/env bash

# It is not loading files if not running interactively
case $- in
  *i*) ;;
  *) return ;;
esac

### Loading custom scripts
source "${HOME}/.commonrc"
source "${HOME}/.common_bashrc"
