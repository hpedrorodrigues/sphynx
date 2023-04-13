#!/usr/bin/env bash

function sx::self::lint() {
  sx::log::info '\n\n>> Running linters\n\n'

  sx::self::lint::run_shfmt
  sx::self::lint::run_shellcheck
  sx::self::lint::run_hadolint
  sx::self::lint::run_prettier
}

function sx::self::lint::run_shfmt() {
  sx::require 'shfmt'

  sx::log::info '> Shfmt (Shell parser, formatter and interpreter)\n'

  cd "${SPHYNX_DIR}" || exit 1

  shfmt -d .
}

function sx::self::lint::run_shellcheck() {
  sx::require 'shellcheck'

  sx::log::info '> ShellCheck (Static analysis tool for shell scripts)\n'

  cd "${SPHYNX_DIR}" || exit 1

  export SHELLCHECK_OPTS='--color=always -e SC1090 -e SC1091 -e SC2155'

  # shellcheck disable=SC2046  # Quote this to prevent word splitting
  shellcheck $(
    find '.' -type f -not -path '*.git*' \
      | sort -u \
      | xargs -I % sh -c "file % | grep --quiet 'shell script' && echo %"
  )
}

function sx::self::lint::run_hadolint() {
  sx::require 'hadolint'

  sx::log::info '> Hadolint (Haskell Dockerfile Linter)\n'

  cd "${SPHYNX_DIR}" || exit 1

  while IFS= read -r -d '' dockerfile; do
    sx::log::info "${dockerfile}"
    hadolint --format=tty <"${dockerfile}"
  done < <(find . -name 'Dockerfile' -print0)
}

function sx::self::lint::run_prettier() {
  sx::require 'prettier'

  sx::log::info '> Prettier\n'

  cd "${SPHYNX_DIR}" || exit 1

  prettier --check '*/**/*.{yml,yaml}'
  prettier --check '*/**/*.json'
  prettier --single-quote --check '*/**/*.js'
}
