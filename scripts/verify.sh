#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost}"

echo "== Running containers =="
docker compose ps

echo "== Application health =="
curl --fail --silent --show-error "${BASE_URL}/health"
echo

echo "== Creating a persistent test record =="
before_json="$(curl --fail --silent --show-error "${BASE_URL}/data")"
echo "${before_json}"
before_id="$(printf '%s' "${before_json}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["new_record"]["id"])')"

echo "== Restarting the stack without deleting its volume =="
docker compose down
docker compose up -d --build --wait

echo "== Verifying health after restart =="
curl --fail --silent --show-error "${BASE_URL}/health"
echo

echo "== Verifying persisted data =="
after_json="$(curl --fail --silent --show-error "${BASE_URL}/data")"
echo "${after_json}"
after_id="$(printf '%s' "${after_json}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["new_record"]["id"])')"

if (( after_id <= before_id )); then
  echo "Persistence check failed: new id ${after_id} is not greater than ${before_id}" >&2
  exit 1
fi

echo "Persistence check passed: record id advanced from ${before_id} to ${after_id}."

echo "== Image size =="
docker images devops-test-project-web --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'
