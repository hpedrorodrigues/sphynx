#!/usr/bin/env bash

## Open the Explain Shell website with the given expression
##
## e.g. explainshell '[ -z "${a}" ] && echo 1'
function explainshell() {
  if ! hash 'sx' 2>/dev/null; then
    echo 'The command-line \"sx\" is not available in your path' >&2
    return 1
  fi

  sx browser open "https://explainshell.com/explain/${*}?args="
}

# Translation functions

## Translate from English to Portuguese (Brazil)
## https://github.com/soimort/translate-shell
##
## e.g. tle 'abysmal'
function tle() {
  if ! hash 'trans' 2>/dev/null; then
    echo 'The command-line \"trans\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2068  # Double quote array expansions
  trans en:pt ${@}
}

## Translate from English to Portuguese (Brazil) and listen to the original text
## https://github.com/soimort/translate-shell
##
## e.g. tles 'atrocious'
function tles() {
  if ! hash 'trans' 2>/dev/null; then
    echo 'The command-line \"trans\" is not available in your path' >&2
    return 1
  fi

  # shellcheck disable=SC2068  # Double quote array expansions
  trans en:pt ${@} --speak
}
