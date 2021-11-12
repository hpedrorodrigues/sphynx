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

  if ! hash 'curl' 2>/dev/null; then
    echo 'The command-line \"curl\" is not available in your path' >&2
    return 1
  fi

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
  local -r func_name="${FUNCNAME[0]:-${funcstack[1]}}"
  local -r server="${1}"
  local -r query="${2}"

  if [ -z "${server}" ] || [ -z "${query}" ]; then
    echo '!!! This function needs a Prometheus server address and a query as arguments' >&2
    echo "!!! e.g. ${func_name} 'http://localhost:9090' 'avg(up) by (job)'" >&2
    return 1
  fi

  if ! hash 'curl' 2>/dev/null; then
    echo 'The command-line \"curl\" is not available in your path' >&2
    return 1
  fi

  curl \
    --silent \
    --get \
    --data-urlencode "query=${query}" \
    "${server}/api/v1/query" \
    | jq
}
