#!/usr/bin/env bash
set -uo pipefail

# Unit tests for classify_gpus() (see gpu-classify.sh, concatenated ahead of
# this file at build time) using simulated vendor lists - no PCI/sysfs
# access, no test framework. Each case: input vendors, expected `mode`,
# expected `ambiguous`. Run directly: `detect-gpu-selftest`.

failures=0
cases=0

check() {
  local desc="$1"; shift
  local expected_mode="$1"; shift
  local expected_ambiguous="$1"; shift
  local out status=0
  out=$(classify_gpus "$@") || status=$?
  cases=$((cases + 1))

  local mode ambiguous
  mode=$(printf '%s\n' "$out" | sed -n 's/^mode=//p')
  ambiguous=$(printf '%s\n' "$out" | sed -n 's/^ambiguous=//p')

  local ok=true
  [ "$mode" = "$expected_mode" ] || ok=false
  [ "$ambiguous" = "$expected_ambiguous" ] || ok=false
  if [ "$expected_ambiguous" = true ] && [ "$status" -eq 0 ]; then
    ok=false
  fi
  if [ "$expected_ambiguous" = false ] && [ "$status" -ne 0 ]; then
    ok=false
  fi

  if [ "$ok" = true ]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc (got mode=$mode ambiguous=$ambiguous status=$status, want mode=$expected_mode ambiguous=$expected_ambiguous)"
    failures=$((failures + 1))
  fi
}

check "Intel only"            integrated false intel
check "AMD only"               discrete  false amd
check "NVIDIA only"            discrete  false nvidia
check "Intel + NVIDIA"         hybrid    false intel nvidia
check "Intel + AMD"            hybrid    false intel amd
check "AMD + NVIDIA"           unknown   true  amd nvidia
check "Intel + AMD + NVIDIA"   unknown   true  intel amd nvidia

echo "---"
echo "$cases cases, $failures failed"
[ "$failures" -eq 0 ]
