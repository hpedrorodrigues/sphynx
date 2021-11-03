#!/usr/bin/env bash

function sx::fs::extract() {
  sx::fs::check_requirements

  IFS="$(printf '\n\t')"

  local -r compressed_file="${1:-}"

  if [ -z "${compressed_file}" ]; then
    sx::log::fatal 'No file provided to extract its content'
  fi

  if ! [ -s "${compressed_file}" ]; then
    sx::log::fatal 'No such file'
  fi

  local -r directory_name="${compressed_file%%.*}"

  mkdir -p "${directory_name}" \
    && cd "${directory_name}" \
    || exit 1

  local -r relative_path="../${compressed_file}"

  case "${relative_path%,}" in
    *.cbt | *.tar.bz2 | *.tar.gz | *.tar.xz | *.tbz2 | *.tgz | *.txz | *.tar)
      tar xvf "${relative_path}"
      ;;
    *.lzma) unlzma "${relative_path}" ;;
    *.bz2) bunzip2 "${relative_path}" ;;
    *.cbr | *.rar) unrar x -ad "${relative_path}" ;;
    *.gz) gunzip "${relative_path}" ;;
    *.cbz | *.epub | *.zip) unzip "${relative_path}" ;;
    *.z) uncompress "${relative_path}" ;;
    *.7z | *.apk | *.arj | *.cab | *.cb7 | *.chm | *.deb | *.dmg | *.iso | *.lzh | *.msi | *.pkg | *.rpm | *.udf | *.wim | *.xar)
      7z x "${relative_path}"
      ;;
    *.xz) unxz "${relative_path}" ;;
    *.cba | *.ace) unace x "${relative_path}" ;;
    *.zpaq) zpaq x "${relative_path}" ;;
    *) sx::log::fatal "Cannot extract file \"${compressed_file}\"" ;;
  esac
}
