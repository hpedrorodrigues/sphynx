#!/usr/bin/env bash

# Hashing functions

## Run md5 algorithm against files or content in stdin
##
## e.g. echo 'test' | md5
## e.g. md5 <filename>
function md5() {
  sx security hash md5 "${*}"
}

## Run sha1 algorithm against files or content in stdin
##
## e.g. echo 'test' | sha1
## e.g. sha1 <filename>
function sha1() {
  sx security hash sha1 "${*}"
}

## Run sha256 algorithm against files or content in stdin
##
## e.g. echo 'test' | sha256
## e.g. sha256 <filename>
function sha256() {
  sx security hash sha256 "${*}"
}

# Translation functions

## Translate from English to Portuguese (Brazil)
## https://github.com/soimort/translate-shell
##
## e.g. tle 'abysmal'
function tle() {
  # shellcheck disable=SC2068  # Double quote array expansions
  trans en:pt ${@}
}

## Translate from English to Portuguese (Brazil) and listen to the original text
## https://github.com/soimort/translate-shell
##
## e.g. tles 'atrocious'
function tles() {
  # shellcheck disable=SC2068  # Double quote array expansions
  trans en:pt ${@} --speak
}

# Filesystem functions

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

# Encoding/Decoding functions

## [Base64 Encode] Encode arguments or content in stdin using Base64 encoding
##
## e.g. e64 'test'
## e.g. cat <filename> | e64
function e64() {
  if [ "${#}" -gt 0 ]; then
    echo -n "${@}" | base64
  else
    base64
  fi
}

## [Base64 Decode] Decode arguments or content in stdin using Base64 encoding
##
## e.g. d64 'dGVzdAo='
## e.g. cat <filename> | d64
function d64() {
  if [ "${#}" -gt 0 ]; then
    echo -n "${@}" | base64 --decode
  else
    base64 --decode
  fi
}

# System Integration functions

## Tail (and filter) System logs
##
## e.g. syslog
## e.g. syslog 'error'
function syslog() {
  local -r selector="${1:-.*}"
  local -r n_lines='100'
  local -r log_files=(
    '/var/log/system.log'
    '/var/log/syslog'
  )

  for log_file in "${log_files[@]}"; do
    if [ -f "${log_file}" ]; then
      command tail -"${n_lines}" -f "${log_file}" | grep -E "${selector}"
    fi
  done
}

## Send desktop notifications using the OS-provided API
##
## e.g. ntf 'See server logs when you come back'
function ntf() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r title='Sphynx'
  local -r message="${*}"

  if [ -z "${message}" ]; then
    echo '!!! This function needs a message as argument' >&2
    echo "!!! e.g. ${func_name} You are awesome!" >&2
    return 1
  fi

  if [ "$(uname)" = 'Darwin' ]; then
    if hash 'osascript' 2>/dev/null; then
      osascript -e "display notification \"${message}\" with title \"${title}\""
    else
      echo "!!! No OS utility found to send notifications" >&2
      return 1
    fi
  elif [ "$(uname)" = 'Linux' ]; then
    if hash 'sw-notify-send' 2>/dev/null; then
      sw-notify-send "${title}" "${message}"
    elif hash 'notify-send' 2>/dev/null; then
      notify-send "${title}" "${message}"
    else
      echo "!!! No OS utility found to send notifications" >&2
      return 1
    fi
  else
    echo "!!! Unsupported OS" >&2
    return 1
  fi
}

## Overload all CPU cores at once
## https://github.com/paulmillr/dotfiles/blob/a26c445aea4097bb8b3c0ea95019544cd66ac9c8/home/.zshrc.sh#L293
##
## e.g. overload_cores
function overload_cores() {
  if [ "$(uname)" = 'Darwin' ]; then
    local -r n_cores="$(sysctl -n hw.ncpu)"
  else
    local -r n_cores="$(grep -c '^processor' /proc/cpuinfo | tr -d ' ')"
  fi

  # shellcheck disable=SC2051  # bash doesn't support variables in brace range expansions
  for _ in {1..${n_cores}}; do
    yes >/dev/null &
  done

  echo "${n_cores} cores loaded. To stop: 'killall yes'."
}

## Print how much RAM an application is currently using
## https://github.com/paulmillr/dotfiles/blob/a26c445aea4097bb8b3c0ea95019544cd66ac9c8/home/.zshrc.sh#L232
##
## e.g. ram chrome
## e.g. ram alacritty
function ram() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r application="${1}"

  if [ -z "${application}" ]; then
    echo '!!! This function needs an application name as first argument' >&2
    echo "!!! e.g. ${func_name} chrome" >&2
    return 1
  fi

  # shellcheck disable=SC2009  # Consider using pgrep instead of grepping ps output
  local -r processes="$(ps aux | grep -i "${application}" | grep -v 'grep')"
  if [ -z "${processes}" ]; then
    echo "!!! No active processes found for \"${application}\"" >&2
    return 1
  fi

  local sum='0'
  for i in $(echo -e "${processes}" | awk '{print $6}'); do
    sum="$((i + sum))"
  done
  sum="$(echo "scale=2; ${sum} / 1024.0" | bc)"

  echo "${application} uses ${sum}MBs of RAM"
}

# Terminal Integration functions

## Run commands in background ignoring its output (stdout and stderr)
## https://github.com/thiagokokada/dotfiles/blob/ef2da95a322c648a59138f3624caaa86654ad191/zsh/.zshrc#L76
##
## e.g. runbg 'gitk'
function runbg() {
  "${@}" </dev/null &>/dev/null &
}

## Switch the selected job running in background (when available) into the
## foreground
##
## e.g. fgpick
function fgpick() {
  local -r n_jobs="$(jobs | wc -l | tr -d ' ')"

  if [ "${n_jobs}" -eq 0 ]; then
    echo '!!! No background jobs found' >&2
    return 1
  elif [ "${n_jobs}" -eq 1 ]; then
    fg
  else
    local -r job_id="$(jobs | fzf | sed 's/\[\([0-9]*\)\].*/\1/')"
    fg "%${job_id}"
  fi
}

## Execute a program periodically running the current shell interactively
##
## e.g. loop 'ls -la'
function loop() {
  watch "${SHELL} -i -c '${*}'"
}

## Remove ANSI color escape codes
##
## e.g. ts | decolorize
function decolorize() {
  sed -E $'s|\x1b\\[[0-\\?]*[ -/]*[@-~]||g;
         s|\x1b[PX^_][^\x1b]*\x1b\\\\||g;
         s:\x1b\\][^\x07]*(\x07|\x1b\\\\)::g;
         s|\x1b[@-_]||g'
}

## Format and display the on-line manual pages (but with colors)
##
## e.g. man 'ls'
function man() {
  env \
    LESS_TERMCAP_mb="$(printf "\e[1;31m")" \
    LESS_TERMCAP_md="$(printf "\e[1;31m")" \
    LESS_TERMCAP_me="$(printf "\e[0m")" \
    LESS_TERMCAP_se="$(printf "\e[0m")" \
    LESS_TERMCAP_so="$(printf "\e[1;44;33m")" \
    LESS_TERMCAP_ue="$(printf "\e[0m")" \
    LESS_TERMCAP_us="$(printf "\e[1;32m")" \
    /usr/bin/man "${*}"
}

# English learning functions

## Create a PNG image file with the meaning of a single provided word
##
## e.g. download_meaning 'steep'
function download_meaning() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r word="${1}"

  if [ -z "${word}" ]; then
    echo '!!! This function needs a word as first argument' >&2
    echo "!!! e.g. ${func_name} struggle" >&2
    return 1
  fi

  p2i \
    --url "https://www.google.com/search?q=${word}+meaning" \
    --selector '.lr_container' \
    --filename "${word}.png"
}

## The same as {@download_meaning} but it reads the words from the provided file
##
## e.g. download_meaning_batch 'words.txt'
function download_meaning_batch() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r file_path="${1}"

  if [ -z "${file_path}" ]; then
    echo '!!! This function needs a file path as first argument' >&2
    echo "!!! e.g. ${func_name} words.txt" >&2
    return 1
  fi

  if ! [ -f "${file_path}" ]; then
    echo "!!! No such file \"${file_path}\"" >&2
    return 1
  fi

  if ! [ -s "${file_path}" ]; then
    echo "!!! Empty file \"${file_path}\"" >&2
    return 1
  fi

  local -r file_content="$(tr '[:upper:]' '[:lower:]' <"${file_path}" | sort -u)"
  echo "${file_content}" | tee "${file_path}"
  echo -e "\n> $(echo "${file_content}" | wc -l | tr -d ' ') words"

  echo

  while IFS= read -r word; do
    download_meaning "${word}"
  done <"${file_path}"
}

# Utility functions

## Simple Calculator
##
## e.g. = 2 + 1
## e.g. = 10 / 3
function = {
  echo "${*}" | tr , \\012 | tr x '*' | bc -l
}

## Create a new Go workspace using the provided directory or a temporary one
##
## e.g. ngw
## e.g. ngw my-project
function ngw() {
  local -r workspace_folder="${1:-$(mktemp -d)}"

  if ! [ -d "${workspace_folder}" ]; then
    mkdir -p "${workspace_folder}"
  fi

  echo -e 'package main\n\nfunc main() {\n\n}\n' \
    >"${workspace_folder}/main.go"
  echo -e 'package main\n\nimport "testing"\n\nfunc Test(t *testing.T) {\n\n}\n\n' \
    >"${workspace_folder}/main_test.go"

  cd "${workspace_folder}" \
    && go mod init "$(basename "${workspace_folder}")" \
    && code . \
    && echo "${workspace_folder}"
}

## [AWS Load Profile] Set the env var AWS_PROFILE to the provided profile
## checking it with the definitions in ~/.aws/config
##
## e.g. awslp <profile-name>
function awslp() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r profile="${1}"

  if [ -z "${profile}" ]; then
    echo '!!! This function needs an aws profile as first argument' >&2
    echo "!!! e.g. ${func_name} your_profile" >&2
    return 1
  fi

  if ! [ -f "${HOME}/.aws/config" ]; then
    echo '!!! No such file: ~/.aws/config' >&2
    return 1
  fi

  if ! grep -q "\[profile ${profile}\]" "${HOME}/.aws/config" 2>/dev/null; then
    local -r available_profiles="$(
      grep -E '[profile [a-z]]' "${HOME}/.aws/config" \
        | sed 's/\[profile //g' \
        | sed 's/\]//g'
    )"

    if [ -z "${available_profiles}" ]; then
      echo '!!! No profiles declared in ~/.aws/config' >&2
    else
      echo '!!! This profile is not declared in file ~/.aws/config' >&2
      echo >&2
      echo '    Available profiles:' >&2
      echo -e "${available_profiles}" | xargs -I % echo '    - %' >&2
    fi

    return 1
  fi

  export AWS_PROFILE="${profile}"
}

## Set the env var JAVA_HOME with the provided version using other
## pre-configured env vars (e.g. JAVA11_HOME, JAVA13_HOME) or the script
## /usr/libexec/java_home when available
##
## e.g. j 11
## e.g. j 13
function j() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r version="${1:-}"

  if [ -z "${version}" ]; then
    if [ -z "${JAVA_HOME}" ]; then
      echo 'JAVA_HOME is not set' >&2
    elif [ -d "${JAVA_HOME}" ]; then
      echo "JAVA_HOME=${JAVA_HOME}"

      local -r jdk_paths=(
        "${HOME}/Library/Java/JavaVirtualMachines"
        '/Library/Java/JavaVirtualMachines'
      )

      for jdk_path in "${jdk_paths[@]}"; do
        echo -e "\nInstalled JDKs on \"${jdk_path}\""
        # shellcheck disable=SC2038  # Use -print0/-0 or find -exec + to allow for non-alphanumeric filenames
        find "${jdk_path}" \
          ! -path "${jdk_path}" \
          \( -type d -o -type l \) \
          -maxdepth 1 \
          | xargs -I {} basename {} \
          | xargs -I {} echo '- {}' \
          | sort -V
      done
    else
      echo "JAVA_HOME=${JAVA_HOME}" >&2
      echo 'JAVA_HOME is pointing to an invalid location' >&2
    fi

    return 0
  fi

  local -r env_value="$(eval echo "\${JAVA${version}_HOME}")"

  if [ -n "${env_value}" ]; then
    local -r new_version="${env_value}"
  elif [ -f '/usr/libexec/java_home' ] \
    && [ -n "$(/usr/libexec/java_home --version "${version}" --failfast 2>/dev/null)" ]; then
    local -r new_version="$(/usr/libexec/java_home -v "${version}")"
  else
    echo "!!! There's no environment variable set or cli tool available for java version: ${version}." >&2
    return 1
  fi

  export JAVA_HOME="${new_version}"
  echo "JAVA_HOME=${JAVA_HOME}"
}

## Decode a Json Web Token
##
## e.g. jwtd <json-web-token>
function jwtd() {
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r token="${1:-}"

  if [ -z "${token}" ]; then
    echo '!!! This function needs a json web token as an argument' >&2
    echo "!!! e.g. ${func_name} '<json-web-token>'" >&2
    return 1
  fi

  jq --raw-input 'split(".") | {
    "header": (.[0] | @base64d | fromjson),
    "payload": (.[1] | @base64d | fromjson),
    "signature": .[2]
  }' <<<"${token}"
}