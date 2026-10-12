#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_PLAN="${SCRIPT_DIR}/chub-test.jmx"

# Read parameters from CLI arguments or environment variables, falling back to defaults
RAW_HOST="${1:-${TEST_HOST:-app-chub-test-weu-01-fad6buf3ejgffnh9.westeurope-01.azurewebsites.net}}"
USERNAME="${2:-${TEST_USER:-fatima.alzubaidi@dge.gov.ae}}"
PASSWORD="${3:-${TEST_PASS:-Testing123!}}"
THREADS="${THREADS:-500}"
RAMPUP="${RAMPUP:-500}"

# Parse protocol and port if present
PROTOCOL="https"
PORT="443"

if [[ "${RAW_HOST}" =~ ^http:// ]]; then
  PROTOCOL="http"
  PORT="80"
  HOST="${RAW_HOST#http://}"
elif [[ "${RAW_HOST}" =~ ^https:// ]]; then
  PROTOCOL="https"
  PORT="443"
  HOST="${RAW_HOST#https://}"
else
  HOST="${RAW_HOST}"
fi

HOST="${HOST%/}"

if [[ "${HOST}" =~ :([0-9]+)$ ]]; then
  PORT="${BASH_REMATCH[1]}"
  HOST="${HOST%:*}"
fi

PROTOCOL="${TEST_PROTOCOL:-${PROTOCOL}}"
PORT="${TEST_PORT:-${PORT}}"

# Ensure '@' is URL-encoded for form body
ENCODED_USER="${USERNAME//@/%40}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${SCRIPT_DIR}/results/${TIMESTAMP}"
REPORT_DIR="${REPORT_DIR:-${OUTPUT_DIR}/report}"
mkdir -p "${OUTPUT_DIR}"

RESULTS_FILE="${OUTPUT_DIR}/results.jtl"
LOG_FILE="${OUTPUT_DIR}/jmeter.log"

echo "=========================================="
echo "Starting JMeter Test"
echo "Host:     ${PROTOCOL}://${HOST}:${PORT}"
echo "Username: ${USERNAME}"
echo "Threads:  ${THREADS} (Ramp-up: ${RAMPUP}s)"
echo "Test:     ${TEST_PLAN}"
echo "Results:  ${RESULTS_FILE}"
echo "Report:   ${REPORT_DIR}"
echo "Log:      ${LOG_FILE}"
echo "=========================================="

jmeter -n \
  -t "${TEST_PLAN}" \
  -Jhost="${HOST}" \
  -Jprotocol="${PROTOCOL}" \
  -Jport="${PORT}" \
  -Jusername="${ENCODED_USER}" \
  -Jpassword="${PASSWORD}" \
  -Jthreads="${THREADS}" \
  -Jrampup="${RAMPUP}" \
  -l "${RESULTS_FILE}" \
  -j "${LOG_FILE}" \
  -e -o "${REPORT_DIR}"

echo "=========================================="
echo "Test execution completed."
echo "Results saved to:     ${OUTPUT_DIR}"
echo "HTML Report saved to: ${REPORT_DIR}/index.html"
echo "=========================================="
