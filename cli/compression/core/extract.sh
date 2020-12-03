#!/usr/bin/env bash

function sx::compression::extract() {
  local -r file_path="${1}"

  if [ ! -f "${file_path}" ]; then
    sx::log::fatal "The file \"${file_path}\" doesn't exist"
  fi

  local -r file_name="$(basename "${file_path}")"
  local -r folder_name="${file_name%%.*}"
  local -r full_path="$(sx::fs::fullpath "${file_path}")"
  local -r did_folder_exist="$([ -d "${folder_name}" ] && echo 'yes')"

  if [ "${did_folder_exist}" ]; then
    read -r -p "${folder_name} already exists, do you want to overwrite it? (y/n) " -n 1

    echo

    if [[ $REPLY =~ ^[Nn]$ ]]; then
      return
    fi
  fi

  mkdir -p "${folder_name}" && cd "${folder_name}" || exit

  case "${file_path}" in
    *.tar)
      tar xf "${full_path}"
      ;;
    *.tar.bz2 | *.tb2 | *.tbz | *.tbz2)
      tar xjf "${full_path}"
      ;;
    *.tar.gz | *.tar.Z | *.taz | *.tgz)
      tar xzf "${full_path}"
      ;;
    *.tar.xz | *.txz)
      tar Jxvf "${full_path}"
      ;;
    *.zip)
      unzip "${full_path}"
      ;;
    *.rar)
      unrar "${full_path}"
      ;;
    *.gz)
      gunzip "${full_path}"
      ;;
    *)
      local -r file_extension="${file_name##*.}"

      sx::log::err "Unsupported extension (${file_extension}): \"${file_path}\" cannot be extracted"

      cd .. && [ ! "${did_folder_exist}" ] && rm -r "${folder_name}"
      ;;
  esac
}
