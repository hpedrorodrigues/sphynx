#!/usr/bin/env bash

function sx::shell::run_tests() {
  sx::shell::check_requirements

  local -r sh="${1}"

  if sx::os::is_macos; then
    sw_vers
    echo
  fi

  if sx::os::is_command_available 'hyperfine'; then
    sx::log::info '> Hyperfine\n'
    hyperfine --warmup 3 "${sh} -i -c exit"
  fi

  if sx::os::is_command_available 'bench'; then
    sx::log::info '> Bench\n'
    bench "${sh} -i -c exit"
  fi

  sx::log::info "> Time\n"
  sx::log::info "/usr/bin/time ${sh} -i -c exit (5x)"
  for _ in {1..5}; do
    /usr/bin/time "${sh}" -i -c 'exit &>/dev/null'
  done
}

function sx::shell::benchmark() {
  sx::shell::check_requirements

  local -r sh="${1}"

  if [ "${sh}" = 'zsh' ] || [ "${sh}" = 'bash' ]; then
    sx::shell::run_tests "${sh}"
  else
    sx::log::fatal 'Unsupported shell'
  fi
}
