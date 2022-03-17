#!/usr/bin/env bash

function sx::system::clipboard::copy() {
  sx::require_supported_os

  if sx::os::is_command_available 'xclip'; then
    xclip -in -selection clipboard
  elif sx::os::is_command_available 'xsel'; then
    xsel --input --clipboard
  elif sx::os::is_command_available 'pbcopy'; then
    # this xargs is necessary to strip the last linefeed character from input
    xargs echo -n | pbcopy
  else
    sx::log::fatal 'No clipboard copy command-line utility available'
  fi
}

function sx::system::clipboard::paste() {
  sx::require_supported_os

  if sx::os::is_command_available 'xclip'; then
    xclip -out -selection clipboard
  elif sx::os::is_command_available 'xsel'; then
    xsel --output --clipboard
  elif sx::os::is_command_available 'pbpaste'; then
    pbpaste
  else
    sx::log::fatal 'No clipboard paste command-line utility available'
  fi
}
