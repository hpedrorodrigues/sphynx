#!/usr/bin/env bash

function sx::url::encode() {
  sx::python -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]));" "${@}"
}
