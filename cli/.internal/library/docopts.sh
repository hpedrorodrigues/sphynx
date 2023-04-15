#!/usr/bin/env bash

function sx::docopts() {
  local -r docopts_script="${SPHYNX_COMMAND_DIR}/.internal/docopt/docopts"

  sx::python "${docopts_script}" "${@}"
}

function sx::python() {
  local -r supported_python_commands=(
    'python3'
    'python'
    'python2'
  )

  for supported_python_command in "${supported_python_commands[@]}"; do
    if sx::os::is_command_available "${supported_python_command}"; then
      command "${supported_python_command}" "${@}"
      return ${?}
    fi
  done

  sx::log::fatal 'Python interpreter not found!'
}
