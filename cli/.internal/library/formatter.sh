#!/usr/bin/env bash

function sx::yaml() {
  if sx::os::is_command_available 'yq'; then
    cat | yq --prettyPrint --colors 'eval'
  elif sx::os::is_command_available 'yh'; then
    cat | yh
  elif sx::os::is_command_available 'bat'; then
    cat | bat --language 'yaml'
  elif sx::os::is_command_available 'pygmentize'; then
    cat | pygmentize -l 'yaml'
  else
    cat
  fi
}

function sx::json() {
  if sx::os::is_command_available 'jq'; then
    cat | jq
  elif sx::os::is_command_available 'bat'; then
    cat | bat --language 'json'
  elif sx::os::is_command_available 'pygmentize'; then
    cat | pygmentize -l 'json'
  else
    cat
  fi
}
