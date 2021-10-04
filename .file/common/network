#!/usr/bin/env bash

alias dns='sx system dns --query'

alias cert='sx security certificate --get --host'
alias certsans='sx security certificate --sans --host'

alias public_ip='sx system ip --public'
alias private_ip='sx system ip --private'
alias gateway_ip='sx system ip --gateway'

function akamai() {
  curl \
    -I \
    -H 'Pragma: akamai-x-cache-on, akamai-x-cache-remote-on, akamai-x-check-cacheable, akamai-x-get-cache-key, akamai-x-get-extracted-values, akamai-x-get-nonces, akamai-x-get-ssl-client-session-id, akamai-x-get-true-cache-key, akamai-x-serial-no' \
    "${@}"
}

# Reference: https://stackoverflow.com/a/22625150/3691240
function curltime() {
  local -r template="$(
    cat <<EOF
\n
           Name lookup time: %{time_namelookup}\n
  Establish connection time: %{time_connect}\n
 SSL/SSH/etc handshake time: %{time_appconnect}\n
     Pre-file-transfer time: %{time_pretransfer}\n
              Redirect time: %{time_redirect}\n
         Time to first byte: %{time_starttransfer}\n
              HTTP/FTP Code: %{http_code}\n
                     -------\n
                 Total time: %{time_total}\n\n\n

Note: The times are displayed in seconds.\n
EOF
  )"

  curl \
    --silent \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "User-Agent: curltime/sphynx ($(uname))" \
    --write-out @- \
    --output /dev/null \
    "${@}" <<<"${template}"
}

# Reference:
# - https://prometheus.io/docs/prometheus/latest/querying/api
function promql() {
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
