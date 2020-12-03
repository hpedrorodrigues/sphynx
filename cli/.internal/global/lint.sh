#!/usr/bin/env bash

function sx::self::lint::print_linter_name() {
  sx::log::info "\n>>===|> ${*}\n"
}

function sx::self::lint::run_hadolint() {
  sx::self::lint::print_linter_name 'Hadolint (Haskell Dockerfile Linter)'

  cd "${SPHYNX_DIR}" || exit 1

  while IFS= read -r -d '' dockerfile; do
    hadolint <"${dockerfile}"
  done < <(find . -name 'Dockerfile' -print0)
}

function sx::self::lint::run_prettier() {
  sx::self::lint::print_linter_name 'Prettier'

  cd "${SPHYNX_DIR}" || exit 1

  prettier --check '*/**/*.{yml,yaml}'
  prettier --check '*/**/*.json'
  prettier --single-quote --check '*/**/*.js'
}

function sx::self::lint::run_shfmt() {
  sx::self::lint::print_linter_name 'Shfmt (Shell parser, formatter and interpreter)'

  cd "${SPHYNX_DIR}" || exit 1

  shfmt -d .
}

function sx::self::lint::run_shellcheck() {
  sx::self::lint::print_linter_name 'ShellCheck (Static analysis tool for shell scripts)'

  cd "${SPHYNX_DIR}" || exit 1

  export SHELLCHECK_OPTS='-e SC1090 -e SC2155'

  # shellcheck disable=SC2046  # Quote this to prevent word splitting
  shellcheck $(find '.' -type f -not -path '*.git*' \
    | sort -u \
    | xargs -I % sh -c "file % | grep --quiet 'shell script' && echo %")
}

function sx::self::lint() {
  sx::self::lint::run_shfmt
  sx::self::lint::run_shellcheck
  sx::self::lint::run_hadolint
  sx::self::lint::run_prettier
}
