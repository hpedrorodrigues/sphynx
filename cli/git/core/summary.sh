#!/usr/bin/env bash

function sx::git::summary::full_period() {
  local -r period="${1}"

  if [ "${period}" = 'd' ]; then
    echo 'day'
  elif [ "${period}" = 'w' ]; then
    echo 'week'
  elif [ "${period}" = 'm' ]; then
    echo 'month'
  else
    echo 'year'
  fi
}

function sx::git::summary::repository() {
  sx::git::check_requirements

  local -r period="${1}"

  if [ "${period}" != 'd' ] \
    && [ "${period}" != 'w' ] \
    && [ "${period}" != 'm' ] \
    && [ "${period}" != 'y' ]; then
    sx::log::fatal "Unsupported period: ${period}"
  fi

  local -r full_period="$(sx::git::summary::full_period "${period}")"
  local -r date_format='+%d/%m/%y'
  local -r last_period="$(if sx::os::is_osx; then
    date "-v-1${period}" "${date_format}"
  else
    date --date="-1 ${full_period}" "${date_format}"
  fi)"
  local -r git_stats="$(git log --since="1.${full_period}" --oneline \
    | tail -n 1 \
    | awk '{ print $1 }' \
    | xargs git diff --shortstat)"
  local -r features="$(git log --since="1.${full_period}" --oneline \
    | grep -E 'Merge (pull request|#\d[0-9]*)' \
    | grep -v 'Revert ')"
  local -r n_features="$(echo -e "${features}" \
    | sed '/^\s*$/d' \
    | wc -l \
    | tr -d ' ')"

  sx::log::info "Status (${last_period} - Today)"
  sx::log::info '---------------------'
  sx::log::info "${git_stats}\n"
  sx::log::info "Features (${n_features})"
  sx::log::info '---------------'
  sx::log::info "${features}"
}
