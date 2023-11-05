#!/usr/bin/env bash

## Like cURL but only prints timing details
##
## e.g. curltime google.com
##
## References:
## - https://blog.josephscott.org/2011/10/14/timing-details-with-curl
## - https://curl.se/docs/manpage.html
## - https://stackoverflow.com/a/22625150/3691240
function curltime() {
  if ! hash 'curl' 2>/dev/null; then
    echo 'The command-line \"curl\" is not available in your path' >&2
    return 1
  fi

  local -r tool_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r template="$(
    cat <<EOF
\n
           Name lookup time: %{time_namelookup}\n
  Establish connection time: %{time_connect}\n
 SSL/SSH/etc handshake time: %{time_appconnect}\n
     Pre-file-transfer time: %{time_pretransfer}\n
              Redirect time: %{time_redirect}\n
         Time to first byte: %{time_starttransfer}\n
                  HTTP Code: %{http_code}\n
                     -------\n
                 Total time: %{time_total}\n\n\n

Note: The times are displayed in seconds.\n
EOF
  )"

  curl \
    --silent \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "User-Agent: sphynx/${tool_name}" \
    --write-out @- \
    --output /dev/null \
    "${@}" <<<"${template}"
}

## Run a query against a Prometheus API address
##
## e.g. promql 'http://localhost:9090' 'avg(up) by (job)'
##
## References:
## - https://prometheus.io/docs/prometheus/latest/querying/api
function promql() {
  if ! hash 'curl' 2>/dev/null; then
    echo 'The command-line \"curl\" is not available in your path' >&2
    return 1
  fi

  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r server="${1}"
  local -r query="${2}"

  if [ -z "${server}" ] || [ -z "${query}" ]; then
    echo '!!! This function needs a Prometheus server address and a query as arguments' >&2
    echo "!!! e.g. ${func_name} 'http://localhost:9090' 'avg(up) by (job)'" >&2
    return 1
  fi

  curl \
    --silent \
    --get \
    --data-urlencode "query=${query}" \
    "${server}/api/v1/query" \
    | jq
}

## Generate a self-signed certificate
##
## e.g. gen_self_signed_cert example.com
##
## References:
## - https://stackoverflow.com/a/31984753/3691240
function gen_self_signed_cert() {
  if ! hash 'openssl' 2>/dev/null; then
    echo 'The command-line \"openssl\" is not available in your path' >&2
    return 1
  fi

  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r domain="${1}"

  if [ -z "${domain}" ]; then
    echo '!!! This function needs a domain as first argument' >&2
    echo "!!! e.g. ${func_name} example.com" >&2
    return 1
  fi

  local -r file_prefix="${domain//./-}"

  local -r keyfile_name="${file_prefix}.key"
  local -r signing_request_name="${file_prefix}.csr"
  local -r certificate_name="${file_prefix}.crt"

  if ! [ -s "${keyfile_name}" ]; then
    openssl genrsa -out "${keyfile_name}" 4096
    openssl rsa -in "${keyfile_name}" -out "${keyfile_name}"
  fi

  if ! [ -s "${signing_request_name}" ]; then
    openssl req -sha256 -new -key "${keyfile_name}" -out "${signing_request_name}" -subj "/CN=${domain}"
  fi

  if ! [ -s "${certificate_name}" ]; then
    openssl x509 -req -sha256 -days 365 -in "${signing_request_name}" -signkey "${keyfile_name}" -out "${certificate_name}"
  fi
}
