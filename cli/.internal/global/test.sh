#!/usr/bin/env bash

# Core function

function sx::self::test() {
  sx::log::info '\n\n>> Running tests\n\n'

  sx::for_all::run_test \
    test::for_all::check_global_flags \
    'Commands should return exit-code 0 when used with global flags'

  sx::for_all::run_test \
    test::for_all::check_unsupported_flag \
    'Commands should not return exit-code 0 when used with an unsupported flag'

  sx::log::info 'Done! :)'
}

# Helper functions

function sx::for_all::run_test() {
  local -r test_function="${1}"
  local -r test_name="${2}"

  sx::log::info "> ${test_name}\n"
  while IFS='' read -r commands; do
    local full_command="${SPHYNX_EXEC} ${commands}"

    if eval "${test_function} ${full_command}" &>/dev/null; then
      sx::log::info "|-- OK: ${SPHYNX_EXEC_NAME} ${commands}"
    else
      sx::log::fatal "|-- FAIL: ${SPHYNX_EXEC_NAME} ${commands}"
    fi
  done < <(
    find "${SPHYNXC_DIR}" \
      -maxdepth 2 \
      ! -path "${SPHYNXC_DIR}" \
      ! -path '*?/.*?' \
      -a -type f -a \( -perm -u=x -o -perm -g=x -o -perm -o=x \) \
      | sed "s#${SPHYNXC_DIR}/##g" \
      | sed 's#/# #g' \
      | sort
  )

  echo
}

# tests

function test::for_all::check_global_flags() {
  local -r commands="${*}"

  eval "${commands} --help" \
    && eval "${commands} --raw"
}

function test::for_all::check_unsupported_flag() {
  local -r commands="${*}"

  ! eval "${commands} --unsupported-flag"
}
