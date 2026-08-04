#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
# Hidden-truth leak gate (KEY-003, G4): derives a deny-list from scenario
# reality and scans bundle structure, shipped files, binary strings and
# runtime output. tools/test-hidden-truth-scanner.sh proves this gate fires.
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
scenario="${root}/scenarios/morrow-engineering-001"
reality="${scenario}/reality/reality.a2ml"
learner="${root}/dist/sim-insolvency-learner"
facilitator="${root}/dist/sim-insolvency-facilitator"
allowlist_file="${root}/tools/hidden-truth-allowlist.txt"

fail() { printf 'FAIL hidden-truth: %s\n' "$1" >&2; exit 1; }
[[ -s "${reality}" ]] || { printf 'missing reality file: %s\n' "${reality}" >&2; exit 2; }
[[ -d "${learner}" ]] || { printf 'missing learner bundle: %s\n' "${learner}" >&2; exit 2; }

# 1. Derive deny tokens from the hidden sections of reality.a2ml.
mapfile -t tokens < <(awk '
  /^\[/ { insec = ($0 == "[fixed-history]" || $0 == "[deterministic-consequences]") }
  insec && /=/ {
    key = $1
    if (key ~ /-/) print key
    if (match($0, /"[^"]*"/)) {
      val = substr($0, RSTART + 1, RLENGTH - 2)
      n = split(val, parts, /[^a-zA-Z0-9-]+/)
      for (i = 1; i <= n; i++)
        if (parts[i] ~ /-/ && parts[i] ~ /^[a-z]/) print parts[i]
    }
  }' "${reality}" | sort -u)
(( ${#tokens[@]} > 0 )) || fail "derived deny-list is empty (vacuous gate)"

allow=()
[[ -f "${allowlist_file}" ]] &&
  mapfile -t allow < <(grep -v -e '^#' -e '^[[:space:]]*$' "${allowlist_file}" || true)

mask() { # stdin -> stdout with allowlisted phrases blanked
  local args=()
  local phrase
  for phrase in "${allow[@]}"; do args+=(-e "s/${phrase}/ALLOWED-PHRASE/g"); done
  if (( ${#args[@]} )); then sed "${args[@]}"; else cat; fi
}

scan_stream() { # $1 channel label, $2 origin label; stdin = text to scan
  local masked token
  masked="$(mask)"
  for token in "${tokens[@]}"; do
    if grep -qF "${token}" <<<"${masked}"; then
      fail "$1 channel: token '${token}' in $2"
    fi
  done
}

# 2. Structure channel: profiles must provably differ.
for forbidden in \
  "${learner}/scenarios/morrow-engineering-001/reality" \
  "${learner}/scenarios/morrow-engineering-001/assessment" \
  "${learner}/scenarios/morrow-engineering-001/evidence/requestable-evidence.a2ml"
do
  [[ -e "${forbidden}" ]] && fail "structure channel: learner bundle contains ${forbidden#"${root}"/}"
done
if [[ -d "${facilitator}" ]]; then
  [[ -d "${facilitator}/scenarios/morrow-engineering-001/reality" ]] ||
    fail "structure channel: facilitator bundle lacks reality/ (profiles identical?)"
fi

# 3. Files channel: learner bundle plus the source-side shipped set.
shipped=("${learner}" "${root}/shell" "${root}/rule-packs"
  "${scenario}/manifest" "${scenario}/actors" "${scenario}/procedures"
  "${scenario}/evidence/engagement-email.adoc"
  "${scenario}/evidence/cash-summary.adoc"
  "${scenario}/evidence/director-statements.adoc")
while IFS= read -r -d '' file; do
  grep -Iq . "${file}" || continue   # skip binaries here; Task 5 covers them
  scan_stream "files" "${file#"${root}"/}" < "${file}"
done < <(find "${shipped[@]}" -type f -print0)

printf 'PASS hidden-truth: %d tokens; structure, files\n' "${#tokens[@]}"
