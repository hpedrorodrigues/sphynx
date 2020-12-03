#!/usr/bin/env bash

# Kill all the tabs in Chrome to free up memory
# [C] explained: http://www.commandlinefu.com/commands/view/402/exclude-grep-from-your-grepped-output-of-ps-alias-included-in-description
function sx::browser::kill_tabs::chrome() {
  if sx::os::is_osx; then
    local -r output="$(pgrep \
      -ifl \
      '[C]hrome.*--type=renderer')"
  elif sx::os::is_linux; then
    local -r output="$(pgrep \
      --ignore-case \
      --full \
      --list-full \
      '[C]hrome.*--type=renderer')"
  else
    sx::log::fatal 'Unsupported OS'
  fi

  echo -e "${output}" \
    | grep -v -- '--extension-process' \
    | cut -d ' ' -f1 \
    | xargs -I % kill %
}

function sx::browser::kill_tabs::firefox() {
  if sx::os::is_osx; then
    local -r output="$(pgrep \
      -ifl \
      '[F]irefox.*-isForBrowser')"
  elif sx::os::is_linux; then
    local -r output="$(pgrep \
      --ignore-case \
      --full \
      --list-full \
      '[F]irefox.*-isForBrowser')"
  else
    sx::log::fatal 'Unsupported OS'
  fi

  echo -e "${output}" \
    | cut -d ' ' -f1 \
    | xargs -I % kill %
}
