#!/usr/bin/env bash
##############################################################################
# common.sh - Structured Enterprise Version
##############################################################################

__lib_file=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  __lib_file="${BASH_SOURCE[0]}"
else
  __lib_file="${(%):-%x}"
fi

BIN_DIR="$(cd "$(dirname "$__lib_file")" && pwd)"
ROOT_DIR="$(cd "$BIN_DIR/.." && pwd)"

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
  echo "Checking Gateway health..."

  local http_code
  http_code=$(curl $(_curl_common_args) \
    -u "${username}:${password}" \
    -o /dev/null \
    -w "%{http_code}" \
    "${url}/rest/apigateway/health" || true)

  echo "Health HTTP Status: ${http_code}"

  if [ "$http_code" != "200" ]; then
    echo "Gateway health check FAILED"
    return 1
  fi

  echo "Gateway is UP"
}

validate_newman_installed() {
  if ! command -v newman >/dev/null 2>&1; then
    echo "Newman not installed"
    return 1
  fi
}

##############################################################################
# APP RESOLVE
##############################################################################

resolve_application_id_by_name() {
  local application_name="$1"
  local url="$2"
  local username="$3"
  local password="$4"

  local payload
  payload=$(cat <<EOF
{"types":["application"],"condition":"and","scope":[{"attributeName":"name","keyword":"${application_name}"}]}
EOF
)

  local resp
  resp="$(curl $(_curl_common_args) -u "${username}:${password}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${url}/rest/apigateway/search")"
  
  local status=$?
  if [ $status -ne 0 ]; then
    echo "request resolve Application to Gateway FAILED" >&2
    return 1
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import sys, json
application_name = sys.argv[1]
d = json.load(sys.stdin)
items = d.get("application", []) or []

exact = [x for x in items if x.get("name") == application_name]
if exact:
    print(exact[0].get("applicationID",""))
    raise SystemExit(0)

if len(items) == 1:
    print(items[0].get("applicationID",""))
    raise SystemExit(0)

if len(items) == 0:
    print("")
    raise SystemExit(0)

cands=[]
for x in items:
    cands.append(
        str(x.get("name")) +
        "(id=" + str(x.get("applicationID")) + ")"
    )
sys.stderr.write("APP name not unique / not exact match. Kandidat:\n- " + "\n- ".join(cands) + "\n")
print("")
' "$application_name" <<<"$resp"
    return 0
  fi

  echo "$resp" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -n 1
}

get_app() {
  local application_id="$1"
  local url="$2"
  local username="$3"
  local password="$4"

  local resp_file
  resp_file=$(mktemp)

  local http_code
  http_code=$(curl $(_curl_common_args) \
    -u "${username}:${password}" \
    -H "Content-Type:application/json" \
    -H "Accept:application/json" \
    -o "$resp_file" \
    -w "%{http_code}" \
    "${url}/rest/apigateway/applications/${application_id}")

  local status=$?
  if [ $status -ne 0 ]; then
    echo "[ERROR] get application request failed for '${application_id}'" >&2
    return 1
  fi

  echo "Get App HTTP Status: ${http_code}"

  if [ "$http_code" != "200" ]; then
    echo "[ERROR] Get App FAILED (HTTP $http_code)" >&2
    cat "$resp_file" >&2
    rm -f "$resp_file" || true
    return 1
  fi

  echo "$resp_file"
}

##############################################################################
# BACKUP
##############################################################################

backup_app() {
  local application_name="$1"
  local url="$2"
  local username="$3"
  local password="$4"

  local application_id
  application_id=$(resolve_application_id_by_name "$application_name" "$url" "$username" "$password")
  local status=$?

  if [ $status -ne 0 ]; then
    return 1
  fi

  if [ -z "$application_id" ]; then
    echo "Application not found, skipping backup" >&2
    echo ""
    return 0
  fi

  local backup_file
  backup_file="$ROOT_DIR/${application_name}_backup_$(date +%Y%m%d%H%M%S).zip"

  curl $(_curl_common_args) -G \
    -u "${username}:${password}" \
    -H "Accept: application/octet-stream" \
    --data-urlencode "applications=${application_id}" \
    --data-urlencode "include-users=true" \
    --data-urlencode "include-groups=true" \
    -o "$backup_file" \
    "$url/rest/apigateway/archive"

  status=$?
  if [ $status -ne 0 ]; then
    echo "[ERROR] Backup request failed for '${application_name}'" >&2
    return 1
  fi

  if [ ! -f "$backup_file" ] || [ ! -s "$backup_file" ]; then
    echo "[ERROR] Backup file missing or empty" >&2
    return 1
  fi

  echo "$backup_file"
}

##############################################################################
# ROLLBACK
##############################################################################

rollback_app() {
  local backup_file="$1"
  local application_name="$2"
  local url="$3"
  local username="$4"
  local password="$5"

  local RESP_FILE
  RESP_FILE=$(mktemp)

  echo "[INFO] Rolling back '${application_name}' using: $backup_file"

  if [ ! -f "$backup_file" ]; then
    echo "[ERROR] Rollback FAILED: backup file not found: $backup_file" >&2
    return 1
  fi

  local http_code
  http_code=$(curl $(_curl_common_args) \
    -u "${username}:${password}" \
    -H "Content-Type:application/zip" \
    -H "Accept:application/json" \
    --data-binary @"$backup_file" \
    -o "$RESP_FILE" \
    -w "%{http_code}" \
    "${url}/rest/apigateway/archive?overwrite=applications_base,application_strategies,application_strategy_credentials,application_apiKeys&fixingMissingVersions=false")

  local status=$?
  if [ $status -ne 0 ]; then
    echo "[ERROR] Rollback request failed for '${application_name}'" >&2
    rm -f "$RESP_FILE" || true
    return 1
  fi

  echo "Rollback HTTP Status: ${http_code}"

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    echo "[ERROR] Rollback FAILED (HTTP $http_code)" >&2
    cat "$RESP_FILE" >&2
    rm -f "$RESP_FILE" || true
    return 1
  fi

  echo "Rollback SUCCESS"
  rm -f "$RESP_FILE" || true
  return 0
}

##############################################################################
# IMPORT
##############################################################################

import_app() {
  local application_name="$1"
  local url="$2"
  local masterGw="$3"
  local username="$4"
  local password="$5"

  local ZIP_FILE
  ZIP_FILE=$(backup_app "$application_name" "$masterGw" "$username" "$password")
  local status=$?

  if [ $status -ne 0 ]; then
    return 1
  fi

  if [ -z "$ZIP_FILE" ]; then
    echo "Master Application not found" >&2
    return 1
  fi

  local RESP_FILE
  RESP_FILE=$(mktemp)

  local http_code
  http_code=$(curl $(_curl_common_args) \
    -u "${username}:${password}" \
    -H "Content-Type:application/zip" \
    -H "Accept:application/json" \
    --data-binary @"$ZIP_FILE" \
    -o "$RESP_FILE" \
    -w "%{http_code}" \
    "${url}/rest/apigateway/archive?overwrite=applications_base,application_strategies,application_strategy_credentials,application_apiKeys&fixingMissingVersions=false")

  status=$?
  if [ $status -ne 0 ]; then
    echo "[ERROR] Import request failed for '${application_name}'" >&2
    rm -f "$RESP_FILE" || true
    return 1
  fi

  echo "Import HTTP Status: ${http_code}"

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    echo "[ERROR] Import FAILED (HTTP $http_code)" >&2
    cat "$RESP_FILE" >&2
    rm -f "$RESP_FILE" || true
    return 1
  fi

  echo "Import SUCCESS"
  rm -f "$RESP_FILE" || true
  return 0
}

##############################################################################
# POSTCHECK
##############################################################################
validate_application() {
  local application_name="$1"
  local url="$2"
  local masterGw="$3"
  local username="$4"
  local password="$5"

  local application_id
  application_id=$(resolve_application_id_by_name "$application_name" "$masterGw" "$username" "$password")
  local status=$?

  if [ $status -ne 0 ] || [ -z "$application_id" ]; then
    echo "Master Application not found" >&2
    return 1
  fi

  local application
  application=$(get_app "$application_id" "$masterGw" "$username" "$password")
  status=$?
  if [ $status -ne 0 ] || [ -z "$application" ]; then
    echo "[ERROR] Failed to retrieve master application data" >&2
    return 1
  fi

  local resp_file=$(mktemp)

  local http_code
  http_code=$(curl -sS \
    -u "${username}:${password}" \
    -H "Content-Type: application/json" \
    --data @"$application" \
    -o "$resp_file" \
    -w "%{http_code}" \
    "${url}/invoke/PegadaianPipeline.services:validateSyncApplication")
  
  status=$?
  if [ $status -ne 0 ]; then
    echo "[ERROR] Validate Sync App request failed" >&2
    rm -f "$resp_file" "$application" || true
    return 1
  fi

  echo "Validate Sync App HTTP Status: $http_code" >&2

  if [ "$http_code" != "200" ]; then
    echo "[ERROR] Validate Sync App FAILED (HTTP $http_code)" >&2
    cat "$resp_file" >&2
    rm -f "$resp_file" "$application" || true
    return 1
  fi

  local isAppFound
  local isAppSync
  isAppFound=$(grep -o '"isAppFound":[^,}]*' "$resp_file" | cut -d':' -f2 | tr -d ' ')
  isAppSync=$(grep -o '"isAppSync":[^,}]*' "$resp_file" | cut -d':' -f2 | tr -d ' ')

  echo "isAppFound=$isAppFound" >&2
  echo "isAppSync=$isAppSync" >&2

  if [ "$isAppFound" = "false" ]; then
    echo "APP not found!"
    rm -f "$resp_file" "$application" || true
    return 1
  fi

  if [ "$isAppSync" = "false" ]; then
    echo "VALIDATION WARNING (APPLICATION NOT MATCHED)" >&2
  fi

  rm -f "$resp_file" "$application" || true
  return 0
}

##############################################################################
# TEST SUITE
##############################################################################

run_test_suite() {
  local test_suite="$1"
  local environment_file_location="$2"
  local apigateway_server_url="$3"
  local result_folder="$4"

  [ -d "$result_folder" ] && rm -rf "$result_folder"
  mkdir -p "$result_folder"

  local CURR_DIR="../"
  local API_DIR="${CURR_DIR}/apigw-pipeline/tests/test-suites/"

  echo "Running tests for API gateway"

  if [ "$test_suite" = "all" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
      setopt local_options null_glob
    fi

    for file in "${API_DIR}"*; do
      [ -f "$file" ] || continue
      run_test "$file" "$environment_file_location" "httpInvokeUrl=${apigateway_server_url}" "$result_folder"
    done
    return 0
  fi

  run_test "$test_suite" "$environment_file_location" "httpInvokeUrl=${apigateway_server_url}" "$result_folder"
}

##############################################################################
# DISPATCHER — allows: ./common.sh <function_name> [args...]
##############################################################################

_usage() {
  echo "Usage:"
  echo "  ./common.sh validate_gateway_up <url> <user> <pass>"
  echo "  ./common.sh validate_newman_installed"
  echo "  ./common.sh backup_app <app> <url> <user> <pass>"
  echo "  ./common.sh rollback_app <backup_file> <app> <url> <user> <pass>"
  echo "  ./common.sh import_app <app> <url> <masterUrl> <user> <pass>"
  echo "  ./common.sh validate_application <app> <url> <masterUrl> <user> <pass>"
  echo "  ./common.sh run_test_suite <suite> <env_file> <gw_url> <result_folder>"
  exit 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  ROOT_DIR="$(pwd)"   # ← tambah ini

  COMMAND="${1:-}"
  shift || true

  case "$COMMAND" in
    validate_gateway_up)       validate_gateway_up "$@" ;;
    validate_newman_installed) validate_newman_installed "$@" ;;
    backup_app)                backup_app "$@" ;;
    rollback_app)              rollback_app "$@" ;;
    import_app)                import_app "$@" ;;
    validate_application)      validate_application "$@" ;;
    run_test_suite)            run_test_suite "$@" ;;
    *)                         _usage ;;
  esac
fi