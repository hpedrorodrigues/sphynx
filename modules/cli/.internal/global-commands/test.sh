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

  sx::for_all::run_test \
    test::for_all::check_help_template \
    'Commands should follow the help template conventions'

  sx::for_all::run_test \
    test::for_all::check_function_references \
    'Commands should only call functions that their sourced files define'

  sx::behavior::test_library
  sx::behavior::test_dispatcher

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
    find "${SPHYNX_CLI_DIR}" \
      -maxdepth 2 \
      ! -path "${SPHYNX_CLI_DIR}" \
      ! -path '*/.library*' \
      ! -path '*/.internal*' \
      -a -type f -a \( -perm -u=x -o -perm -g=x -o -perm -o=x \) \
      | sed "s#${SPHYNX_CLI_DIR}/##g" \
      | sed 's#/# #g' \
      | sort
  )

  echo
}

function sx::behavior::assert_output() {
  local -r expected_output="${1}"
  local -r command_text="${2}"
  local actual_output

  actual_output="$(eval "${command_text}" 2>/dev/null)" || true

  if [ "${actual_output}" = "${expected_output}" ]; then
    sx::log::info "|-- OK: ${command_text}"
  else
    sx::log::fatal "|-- FAIL: ${command_text} (expected \"${expected_output}\", got \"${actual_output}\")"
  fi
}

function sx::behavior::assert_output_contains() {
  local -r expected_text="${1}"
  local -r command_text="${2}"
  local actual_output

  actual_output="$(eval "${command_text}" 2>&1)" || true

  if [[ ${actual_output} == *"${expected_text}"* ]]; then
    sx::log::info "|-- OK: ${command_text}"
  else
    sx::log::fatal "|-- FAIL: ${command_text} (expected the output to contain \"${expected_text}\")"
  fi
}

function sx::behavior::assert_exit_code() {
  local -r expected_exit_code="${1}"
  local -r command_text="${2}"
  local actual_exit_code='0'

  (eval "${command_text}") &>/dev/null || actual_exit_code="${?}"

  if [ "${actual_exit_code}" = "${expected_exit_code}" ]; then
    sx::log::info "|-- OK: ${command_text}"
  else
    sx::log::fatal "|-- FAIL: ${command_text} (expected exit-code ${expected_exit_code}, got ${actual_exit_code})"
  fi
}

# tests

function sx::behavior::test_library() {
  sx::log::info '> Library functions should return the expected values\n'

  sx::behavior::assert_output 'abc def' "sx::string::lowercase 'ABC Def'"
  sx::behavior::assert_output 'abc' "echo 'ABC' | sx::string::lowercase"
  sx::behavior::assert_output 'ABC DEF' "sx::string::uppercase 'abc Def'"
  sx::behavior::assert_output 'ABC' "echo 'abc' | sx::string::uppercase"
  sx::behavior::assert_output 'a-b-c' "sx::string::kebabcase 'a_b_c'"
  sx::behavior::assert_output 'a-b' "echo 'a_b' | sx::string::kebabcase"

  sx::behavior::assert_output '1' 'sx::math::min 1 2'
  sx::behavior::assert_output '1' 'sx::math::min 2 1'
  sx::behavior::assert_output '-3' 'sx::math::min -3 2'
  sx::behavior::assert_output '2' 'sx::math::min 2 2'
  sx::behavior::assert_output '2' 'sx::math::max 1 2'
  sx::behavior::assert_output '2' 'sx::math::max 2 1'
  sx::behavior::assert_output '2' 'sx::math::max -3 2'
  sx::behavior::assert_exit_code '1' 'sx::math::min 1'
  sx::behavior::assert_exit_code '1' 'sx::math::max'

  sx::behavior::assert_output 'a+b%26c' "sx::url::encode 'a b&c'"
  sx::behavior::assert_output 'x%2Fy%3Fz%3D1' "sx::url::encode 'x/y?z=1'"

  echo
}

function sx::behavior::test_dispatcher() {
  sx::log::info '> The dispatcher should resolve namespaces and reject wrong input\n'

  sx::behavior::assert_exit_code '0' "${SPHYNX_EXEC}"
  sx::behavior::assert_exit_code '0' "${SPHYNX_EXEC} --help"
  sx::behavior::assert_exit_code '0' "${SPHYNX_EXEC} --namespaces"
  sx::behavior::assert_exit_code '0' "${SPHYNX_EXEC} --commands"
  sx::behavior::assert_output_contains '> kubernetes' "${SPHYNX_EXEC} --namespaces"

  sx::behavior::assert_exit_code '1' "${SPHYNX_EXEC} no-such-namespace"
  sx::behavior::assert_output_contains 'No namespace matches' "${SPHYNX_EXEC} no-such-namespace"

  sx::behavior::assert_exit_code '1' "${SPHYNX_EXEC} fl"
  sx::behavior::assert_output_contains 'More than one match found' "${SPHYNX_EXEC} fl"

  sx::behavior::assert_exit_code '1' "${SPHYNX_EXEC} kubernetes"
  sx::behavior::assert_exit_code '1' "${SPHYNX_EXEC} kubernetes no-such-command"
  sx::behavior::assert_output_contains 'does not exist at namespace' "${SPHYNX_EXEC} kubernetes no-such-command"

  sx::behavior::assert_output "$("${SPHYNX_EXEC}" test --help)" "${SPHYNX_EXEC} tes --help"
  sx::behavior::assert_output_contains '|-- ' "${SPHYNX_EXEC} kube"

  echo
}

function test::for_all::check_global_flags() {
  local -r commands="${*}"

  eval "${commands} --help" \
    && eval "${commands} --raw"
}

function test::for_all::check_unsupported_flag() {
  local -r commands="${*}"

  ! eval "${commands} --unsupported-flag"
}

function test::for_all::check_help_template() {
  local -r script_file="${SPHYNX_CLI_DIR}/$(echo "${*:2}" | tr ' ' '/')"

  sx::python "${SPHYNX_CLI_DIR}/.internal/docopt/docopt_lint.py" "${script_file}"
}

function test::for_all::check_function_references() {
  local -r relative_path="$(echo "${*:2}" | tr ' ' '/')"
  local -r script_file="${SPHYNX_CLI_DIR}/${relative_path}"

  SPHYNX_NAMESPACE_DIR="${SPHYNX_CLI_DIR}/$(dirname "${relative_path}")" bash -c "
    $(grep '^source ' "${script_file}")

    while IFS='' read -r fn; do
      declare -F \"\${fn}\" >/dev/null || exit 1
    done < <(grep -oE 'sx::[a-z0-9_:]+' '${script_file}' | sort -u)
  "
}
