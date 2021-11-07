#!/usr/bin/env bash

## Open the Explain Shell website with the given expression
##
## e.g. explainshell '[ -z "${a}" ] && echo 1'
function explainshell() {
  sx browser open "https://explainshell.com/explain/${*}?args="
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
