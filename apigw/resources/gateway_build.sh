#!/usr/bin/env bash
set -euo pipefail

##############################################################################
# INIT
##############################################################################

__lib_file="${BASH_SOURCE[0]}"
BIN_DIR="$(cd "$(dirname "$__lib_file")" && pwd)"
ROOT_DIR="$(cd "$BIN_DIR/.." && pwd)"

##############################################################################
# CURL COMMON
##############################################################################

_curl_common_args() {
  local args=(-sS)
  [ "${APIGW_INSECURE:-false}" = "true" ] && args+=(-k)
  echo "${args[@]}"
}

##############################################################################
# PRECHECK
##############################################################################

validate_gateway_up() {
  local url="$1"
  local username="$2"
  local password="$3"

  echo "Checking Gateway health: $url"

  local http_code
  http_code=$(curl $(_curl_common_args) \
    -u "${username}:${password}" \
    -o /dev/null \
    -w "%{http_code}" \
    "${url}/rest/apigateway/health" || true)

  echo "Health HTTP Status: ${http_code}"

  if [ "$http_code" != "200" ]; then
    echo "❌ Gateway health check FAILED"
    return 1
  fi

  echo "✅ Gateway is UP"
}

##############################################################################
# API RESOLVE
##############################################################################

resolve_api_id_by_name() {
  local api_name="$1"
  local url="$2"
  local username="$3"
  local password="$4"

  local payload
  payload=$(cat <<EOF
{"types":["api"],"condition":"and","scope":[{"attributeName":"apiName","keyword":"${api_name}"}]}
EOF
)

  curl $(_curl_common_args) -u "${username}:${password}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${url}/rest/apigateway/search" \
    | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4 || true
}

##############################################################################
# BACKUP
##############################################################################

backup_api() {
  local api_project="$1"
  local url="$2"
  local username="$3"
  local password="$4"

  echo "🔄 Backup API: $api_project"

  local api_id
  api_id=$(resolve_api_id_by_name "$api_project" "$url" "$username" "$password")

  local BACKUP_FILE="$ROOT_DIR/${api_project}_backup.zip"

  curl $(_curl_common_args) -G \
    -u "${username}:${password}" \
    -H "Accept: application/octet-stream" \
    --data-urlencode "apis=${api_id}" \
    --data-urlencode "include-registered-applications=true" \
    --data-urlencode "include-users=true" \
    --data-urlencode "include-groups=true" \
    -o "$BACKUP_FILE" \
    "$url/rest/apigateway/archive"

  echo "✅ Backup saved: $BACKUP_FILE"
}

##############################################################################
# IMPORT
##############################################################################

import_api() {
  local api_project="$1"
  local url="$2"
  local username="$3"
  local password="$4"

  echo "🚀 Import API: $api_project"

  local API_DIR="$ROOT_DIR/apis/$api_project"
  local ZIP_FILE="$ROOT_DIR/${api_project}.zip"
  local RESP_FILE="$ROOT_DIR/import_response.txt"

  ( cd "$API_DIR" && zip -qr "$ZIP_FILE" . )

  local http_code
  http_code=$(curl $(_curl_common_args) \
    -u "${username}:${password}" \
    -H "Content-Type:application/zip" \
    -H "Accept:application/json" \
    --data-binary @"$ZIP_FILE" \
    -o "$RESP_FILE" \
    -w "%{http_code}" \
    "${url}/rest/apigateway/archive?overwrite=apis,policies,policyactions" || true)

  echo "Import HTTP Status: ${http_code}"

  if [[ "$http_code" != "200" && "$http_code" != "201" ]]; then
    echo "❌ Import FAILED"
    cat "$RESP_FILE"
    return 1
  fi

  echo "✅ Import SUCCESS"
}

##############################################################################
# POSTCHECK
##############################################################################

validate_api_exists() {
  local api_project="$1"
  local url="$2"
  local username="$3"
  local password="$4"

  echo "🔍 Validating API exists: $api_project"

  local resp
  resp=$(curl $(_curl_common_args) \
    -u "${username}:${password}" \
    -H "Content-Type: application/json" \
    -d "{\"types\":[\"api\"],\"condition\":\"and\",\"scope\":[{\"attributeName\":\"apiName\",\"keyword\":\"${api_project}\"}]}" \
    "${url}/rest/apigateway/search")

  local id
  id=$(echo "$resp" | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4)

  if [ -z "$id" ]; then
    echo "❌ API not found!"
    return 1
  fi

  echo "✅ API exists (id=$id)"
}

##############################################################################
# CLI ENTRYPOINT (NO SOURCE NEEDED)
##############################################################################

case "${1:-}" in
  validate_gateway_up) shift; validate_gateway_up "$@" ;;
  resolve_api_id_by_name) shift; resolve_api_id_by_name "$@" ;;
  backup_api) shift; backup_api "$@" ;;
  import_api) shift; import_api "$@" ;;
  validate_api_exists) shift; validate_api_exists "$@" ;;
  *)
    echo "Usage:"
    echo "  $0 validate_gateway_up <url> <user> <pass>"
    echo "  $0 backup_api <api> <url> <user> <pass>"
    echo "  $0 import_api <api> <url> <user> <pass>"
    echo "  $0 validate_api_exists <api> <url> <user> <pass>"
    exit 1
    ;;
esac