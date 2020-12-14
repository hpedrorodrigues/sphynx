#!/usr/bin/env bash

function sx::sqlite::check_requirements() {
  sx::require_supported_os
  sx::require 'sqlite3'
}
