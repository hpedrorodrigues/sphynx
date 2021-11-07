#!/usr/bin/env bash

## Create a directory supporting multiple paths and enter it
##
## e.g. mkd a/b/c
function mkd() {
  mkdir -p "${*}" && cd "${_}" || return 1
}

## Create a temporary directory and enter it
##
## e.g. tmpd
function tmpd() {
  cd "$(mktemp -d)" && cd "${_}" || return 1
}

## List contents of directories in a tree-like format ignoring useless paths
##
## e.g. dag .
function dag() {
  tree \
    -aC \
    -I '.DS_Store|.git|.idea|build|node_modules|target|vendor|__pycache__' \
    --dirsfirst "${*:-.}"
}

## [Touch Executable] Creates an executable bash file with some checks
##
## e.g. te my-script.sh
function te() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r file_name="${1}"

  if [ -z "${file_name}" ]; then
    echo '!!! This function needs a file name as first argument' >&2
    echo "!!! e.g. ${func_name} new_executable_file" >&2
    return 1
  fi

  if [ -f "${file_name}" ]; then
    echo "!!! File \"${file_name}\" already exists" >&2
    return 1
  fi

  echo -e '#!/usr/bin/env bash\n' >"${file_name}" \
    && chmod +x "${file_name}"
}

## Go up n directories
##
## e.g. up 3
function up() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r n="${1}"

  if [ -z "${n}" ] || ! [[ ${n} =~ ^[0-9]+$ ]]; then
    echo '!!! You should pass a number to this function' >&2
    echo "!!! e.g. ${func_name} 3 (to navigate up 3 directories)" >&2
    return 1
  fi

  # shellcheck disable=SC2086  # quote this to prevent word splitting
  # shellcheck disable=SC2051  # bash doesn't support variables in brace range expansions
  cd "$(printf '../'%.0s {1..${1:-1}})" || return 1
}

## Print the total size of a file (or directory) in a human-readable format
##
## e.g. fs
## e.g. fs my-file.sh
function fs() {
  if du -b /dev/null >/dev/null 2>&1; then
    local -r args='-sbh'
  else
    local -r args='-sh'
  fi

  if [[ -n ${*} ]]; then
    du "${args}" -- "${@}"
  else
    du "${args}" .[^.]* ./*
  fi
}

## Run a command over all subdirectories of the provided path (defaults to current directory)
##
## e.g. eachdir <command> <path-to-directory>
## e.g. eachdir 'ls -la' .
function eachdir() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r command="${1}"
  local -r directory_path="${2:-.}"

  if [ -z "${command}" ]; then
    echo '!!! This function needs a command as first argument' >&2
    echo "!!! e.g. ${func_name} 'ls -la'" >&2
    return 1
  fi

  while IFS= read -r directory; do
    if [ -d "${directory}" ]; then
      (
        cd "${directory}" \
          && echo -e "\n|-- \"${directory}\"\n" \
          && ${SHELL} -i -c "${command}; exit \$?"
      )
    else
      echo "!!! No such directory \"${directory}\"" >&2
    fi
  done < <(
    find "${directory_path}" -maxdepth 1 -type d ! -path "${directory_path}"
  )
}

## Open files or URLs using the default pre-configured OS application
##
## e.g. o <filename>
function o() {
  sx system open "${*}"
}

## [Browser Open] Open files or URLs using the default browser
##
## e.g. bo <filename>
function bo() {
  sx browser open "${*}"
}

## Read .csv files and print their content in a tabular format
##
## e.g. csv <csv-file>
function csv() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r file_name="${1}"

  if [ -z "${file_name}" ]; then
    echo '!!! This function needs a file as first argument' >&2
    echo "!!! e.g. ${func_name} test.csv" >&2
    return 1
  fi

  if ! [ -f "${file_name}" ]; then
    echo "!!! No such file \"${file_name}\"" >&2
    return 1
  fi

  if ! [ -s "${file_name}" ]; then
    echo "!!! Empty file \"${file_name}\"" >&2
    return 1
  fi

  sed <"${file_name}" 's/"//g' | column -t -s ','
}
