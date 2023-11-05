#!/usr/bin/env bash

# Hashing functions

## Run md5 algorithm against files or content in stdin
##
## e.g. echo 'test' | md5
## e.g. md5 <filename>
function md5() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx security hash md5 "${*}"
}

## Run sha1 algorithm against files or content in stdin
##
## e.g. echo 'test' | sha1
## e.g. sha1 <filename>
function sha1() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx security hash sha1 "${*}"
}

## Run sha256 algorithm against files or content in stdin
##
## e.g. echo 'test' | sha256
## e.g. sha256 <filename>
function sha256() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx security hash sha256 "${*}"
}

# Encoding/Decoding functions

## [Base64 Encode] Encode arguments or content in stdin using Base64 encoding
##
## e.g. e64 'test'
## e.g. cat <filename> | e64
function e64() {
  if ! hash 'base64' 2>/dev/null; then
    echo 'The command-line \"base64\" is not available in your path' >&2
    return 1
  fi

  if [ "${#}" -gt '0' ]; then
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
  if ! hash 'base64' 2>/dev/null; then
    echo 'The command-line \"base64\" is not available in your path' >&2
    return 1
  fi

  if [ "${#}" -gt '0' ]; then
    echo -n "${@}" | base64 --decode
  else
    base64 --decode
  fi
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

  if ! hash 'jq' 2>/dev/null; then
    echo 'The command-line \"jq\" is not available in your path' >&2
    return 1
  fi

  jq --raw-input 'split(".") | {
    "header": (.[0] | @base64d | fromjson),
    "payload": (.[1] | @base64d | fromjson),
    "signature": .[2]
  }' <<<"${token}"
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

## Prints the current CPU usage
##
## e.g. cpu
function cpu() {
  if ! hash 'top' 2>/dev/null; then
    echo 'The command-line \"top\" is not available in your path' >&2
    return 1
  fi

  if ! hash 'sysctl' 2>/dev/null; then
    echo 'The command-line \"sysctl\" is not available in your path' >&2
    return 1
  fi

  echo '> CPU Usage'
  echo
  top -l 1 | head -n 4 | tail -n 1 | cut -d ':' -f 2

  echo
  echo '> Load Average'
  echo
  sysctl -n vm.loadavg \
    | tr -d '{}' \
    | awk -F ' ' '{ print " 1 min,5 min,15 min"; print " " $1 "," $2 "," $3 }' \
    | column -t -s ','
}

## Prints the current battery usage
##
## e.g. battery
function battery() {
  if ! hash 'pmset' 2>/dev/null; then
    echo 'The command-line \"pmset\" is not available in your path' >&2
    return 1
  fi

  pmset -g ps \
    | sed -n 's/.*[[:blank:]]+*\(.*%\).*/\1/p' \
    | awk '{printf "%2d%%\n", $1}'
}

# Terminal Integration functions

## Switch the selected job running in background (when available) into the
## foreground
##
## e.g. fgpick
function fgpick() {
  if ! hash 'fzf' 2>/dev/null; then
    echo 'The command-line \"fzf\" is not available in your path' >&2
    return 1
  fi

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
  if ! hash 'code' 2>/dev/null; then
    echo 'The command-line \"code\" is not available in your path' >&2
    return 1
  fi

  if ! hash 'go' 2>/dev/null; then
    echo 'The command-line \"go\" is not available in your path' >&2
    return 1
  fi

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

## [AWS Profile Switch] Change the current AWS profile
##
## e.g. aps <query>
function aps() {
  eval "$(sx aws profile --switch)"
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
      echo 'JAVA_HOME is pointing to an invalid location!' >&2
    fi

    return 0
  fi

  local -r env_value="$(eval echo "\${JAVA${version}_HOME}")"

  if [ -n "${env_value}" ]; then
    local -r new_version="${env_value}"
  elif [ -s '/usr/libexec/java_home' ] \
    && [ -n "$(/usr/libexec/java_home --version "${version}" --failfast 2>/dev/null)" ]; then
    local -r new_version="$(/usr/libexec/java_home -v "${version}")"
  else
    echo "!!! There's no environment variable set or cli tool available for java version: ${version}." >&2
    return 1
  fi

  export JAVA_HOME="${new_version}"
  echo "JAVA_HOME=${JAVA_HOME}"

  if ! [ -d "${JAVA_HOME}" ]; then
    echo 'JAVA_HOME is now pointing to an invalid location!' >&2
  fi
}
