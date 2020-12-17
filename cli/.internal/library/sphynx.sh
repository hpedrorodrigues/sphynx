#!/usr/bin/env bash

function sx::parse_arguments() {
  local -r script_file="${0}"
  local -r help=$(grep '^##?' "${script_file}" | cut -c 5-)
  local -r docopts="${SPHYNXC_DIR}/.internal/docopt/docopts"
  local -r sphynxd="$(basename "${SPHYNXC_DIR}")"

  if [[ ${*} == *'--help'* ]]; then
    eval "$(${docopts} -h "${help}" : '--help')"
    exit 0
  elif [[ ${*} == *'--raw'* ]]; then
    local -r file_dir="$(dirname "${script_file}")"
    local -r file_name="$(basename "${script_file}")"

    if sx::os::is_command_available 'bat'; then
      local -r printer='bat --plain --paging never --language bash'
    else
      local -r printer='cat'
    fi

    local -r cmd_definition="${script_file}"
    local -r cmd_implementation="${file_dir}/core/${file_name}.sh"
    if [ -f "${cmd_definition}" ] && [ -f "${cmd_implementation}" ]; then
      sx::log::info '\n> Definition\n'
      command ${printer} "${cmd_definition}"

      sx::log::info '\n\n\n> Implementation\n'
      command ${printer} "${cmd_implementation}"
      exit 0
    fi

    local -r global_cmd_definition="${script_file}"
    local -r global_cmd_implementation="${file_dir}/.internal/global/${file_name}.sh"
    if [ -f "${global_cmd_definition}" ] && [ -f "${global_cmd_implementation}" ]; then
      sx::log::info '\n> Definition\n'
      command ${printer} "${global_cmd_definition}"

      sx::log::info '\n\n\n> Implementation\n'
      command ${printer} "${global_cmd_implementation}"
      exit 0
    fi

    sx::log::fatal 'No such file'
  elif [[ ${*} == *'--github'* ]]; then
    sx::require_env 'GITHUB_USER'

    local -r file_dir="$(dirname "${script_file}")"
    local -r file_name="$(basename "${script_file}")"
    local -r branch="$(cd "${SPHYNX_DIR}" && sx::git::current_branch)"
    local -r base_url="${GITHUB_BROWSER_API_URL}${GITHUB_USER}/sphynx/blob/${branch:-main}/${sphynxd}"

    if [[ ${file_dir} == *"${sphynxd}" ]]; then
      local -r url="${base_url}/${file_name}"
    else
      local -r url="${base_url}/$(basename "${file_dir}")/${file_name}"
    fi

    sx::os::browser::open "${url}"
    exit 0
  else
    eval "$(${docopts} -h "${help}" : "${@:1}")"
  fi
}
