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
  if ! hash 'tree' 2>/dev/null; then
    echo 'The command-line \"tree\" is not available in your path' >&2
    return 1
  fi

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

  if [ -s "${file_name}" ]; then
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
    find "${directory_path}" -maxdepth 1 -type d ! -path "${directory_path}" | sort -u
  )
}

## Open files or URLs using the default pre-configured OS application
##
## e.g. o <filename>
function o() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx system open "${*}"
}

## [Browser Open] Open files or URLs using the default browser
##
## e.g. bo <filename>
function bo() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx browser open "${*}"
}

## Extract content of compressed files
##
## e.g. extract <path-to-compressed-file>
## e.g. extract test.tar.gz
## e.g. extract test.zip
function extract() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx fs extract "${*}"
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

## Creates a REPL for the given command running it against stdin and displaying
## the result in the preview window
##
## e.g. replfy <command> <start-query>
## e.g. echo 'Hello world!' | replfy 'awk {q}' '{print}'
## e.g. echo '{"field":"value"}' | replfy 'jq -r'
##
## Credits: https://github.com/DanielFGray/fzf-scripts/blob/master/fzrepl
function replfy() {
  if ! hash 'fzf' 2>/dev/null; then
    echo 'The command-line \"fzf\" is not available in your path' >&2
    return 1
  fi

  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r user_cmd="${1}"
  local -r user_query="${2}"

  if [ -z "${user_cmd}" ]; then
    echo '!!! This function needs a command as first argument' >&2
    echo '!!!' >&2
    echo "!!! ${func_name} <command> <start-query>" >&2
    echo '!!!' >&2
    echo "!!! e.g. echo '{\"field\":\"value\"}' | ${func_name} 'jq -r' '.field'" >&2
    return 1
  fi

  if [ -t 0 ]; then
    echo '!!! This function can only be used with a pipe' >&2
    echo '!!!' >&2
    echo "!!! ${func_name} <command> <start-query>" >&2
    echo '!!!' >&2
    echo "!!! e.g. echo '{\"field\":\"value\"}' | ${func_name} 'jq -r' '.field'" >&2
    return 1
  fi

  if [ -z "${user_query}" ]; then
    local -r query=''
  else
    local -r query="${user_query}"
  fi

  if [[ "${user_cmd}" == *'{q}'* ]]; then
    local -r cmd="${user_cmd}"
  else
    local -r cmd="${user_cmd} {q}"
  fi

  local -r temp_file="$(mktemp)"

  tee "${temp_file}" </dev/stdin | fzf \
    --sync \
    --ansi \
    --disabled \
    --height=100% \
    --print-query \
    --query="${query}" \
    --preview="${cmd} < '${temp_file}'"
}

## Creates a REPL for jq
##
## e.g. jqrepl <start-query>
## e.g. echo '{"field":"value"}' | jqrepl
## e.g. echo '{"field":"value"}' | jqrepl '.field'
function jqrepl() {
  local -r user_query="${1}"

  if [ -z "${user_query}" ]; then
    local -r query='.'
  else
    local -r query="${user_query}"
  fi

  replfy "jq --color-output ${JQ_REPL_ARGS:-}" "${query}"
}
