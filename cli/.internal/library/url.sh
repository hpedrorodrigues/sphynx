#!/usr/bin/env bash

function sx::url::encode() {
  sx::require 'python'

  python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1]);" "${@}"
}
