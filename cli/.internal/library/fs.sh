#!/usr/bin/env bash

function sx::fs::fullpath() {
  local -r relative_path="${1}"

  perl -e 'use Cwd "abs_path";print abs_path(shift)' "${relative_path}"
}
