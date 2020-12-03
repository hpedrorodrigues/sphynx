#!/usr/bin/env bash

function sx::self::fmt::print_formatter_name() {
  sx::log::info "\n>>===|> ${*}\n"
}

function sx::self::fmt::run_prettier() {
  (
    sx::self::fmt::print_formatter_name 'Prettier'

    cd "${SPHYNX_DIR}" || exit 1

    prettier --write '*/**/*.{yml,yaml}'
    prettier --write '*/**/*.json'
    prettier --single-quote --write '*/**/*.js'
  )
}

function sx::self::fmt::run_shfmt() {
  (
    sx::self::fmt::print_formatter_name 'Shfmt (Shell parser, formatter and interpreter)'

    cd "${SPHYNX_DIR}" || exit 1

    shfmt -w .
  )
}

function sx::self::fmt() {
  sx::self::fmt::run_shfmt
  sx::self::fmt::run_prettier
}
