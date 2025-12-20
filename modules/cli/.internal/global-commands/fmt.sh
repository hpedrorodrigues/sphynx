#!/usr/bin/env bash

function sx::self::fmt() {
  sx::log::info '\n\n>> Running formatters\n\n'

  sx::self::fmt::run_shfmt
  sx::self::fmt::run_prettier
}

function sx::self::fmt::run_shfmt() {
  sx::require 'shfmt'

  (
    sx::log::info '> Shfmt (Shell parser, formatter and interpreter)\n'

    cd "${SPHYNX_DIR}" || exit 1

    shfmt -w .
  )
}

function sx::self::fmt::run_prettier() {
  sx::require 'prettier'

  (
    sx::log::info '> Prettier\n'

    cd "${SPHYNX_DIR}" || exit 1

    prettier --single-quote --write '*/**/*.{yml,yaml}'
    prettier --single-quote --write '*/**/*.js'
    prettier --write '*/**/*.json'
  )
}
