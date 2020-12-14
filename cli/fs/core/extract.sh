#!/usr/bin/env bash

function sx::fs::extract() {
  sx::fs::check_requirements

  local -r file_path="${1}"

  if ! [ -f "${file_path}" ]; then
    sx::log::fatal "No such file \"${file_path}\""
  fi

  local -r extraction_data=(
    '.tar,tar,tar xf'
    '.tar.bz2,tar,tar xjf'
    '.tb2,tar,tar xjf'
    '.tbz,tar,tar xjf'
    '.tbz2,tar,tar xjf'
    '.tar.gz,tar,tar xzf'
    '.tar.Z,tar,tar xzf'
    '.taz,tar,tar xzf'
    '.tgz,tar,tar xzf'
    '.tar.xz,tar,tar Jxvf'
    '.txz,tar,tar Jxvf'
    '.zip,unzip,unzip'
    '.rar,unrar,unrar'
    '.gz,gunzip,gunzip'
    '.bz2,bunzip2,bunzip2'
    '.7z,7z,7z x'
  )

  for data in "${extraction_data[@]}"; do
    local extension="$(echo "${data}" | cut -d ',' -f 1)"

    if echo "${file_path}" | grep -qE "${extension}\$"; then
      local -r required_cli="$(echo "${data}" | cut -d ',' -f 2)"
      sx::require "${required_cli}"

      local -r file_name="$(basename "${file_path}")"
      local -r directory_name="${file_name//${extension}/}"

      if [ -d "${directory_name}" ]; then
        sx::log::fatal "The directory \"${directory_name}\" already exists"
      fi

      local -r command_prefix="$(echo "${data}" | cut -d ',' -f 3)"

      mkdir -p "${directory_name}" \
        && cd "${directory_name}" \
        || exit 1

      eval "${command_prefix} ../${file_path}"

      exit "${?}"
    fi
  done

  sx::log::fatal "Cannot extract file \"${file_path}\""
}
