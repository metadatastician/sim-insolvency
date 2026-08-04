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

mask() { # stdin -> stdout with allowlisted phrases blanked (literal, no regex)
  local text phrase
  text="$(cat)"
  for phrase in "${allow[@]}"; do
    text="${text//"${phrase}"/ALLOWED-PHRASE}"
  done
  printf '%s\n' "${text}"
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
for path in "${shipped[@]}"; do
  [[ -e "${path}" ]] || fail "files channel: missing input ${path#"${root}"/}"
done
while IFS= read -r -d '' file; do
  grep -Iq . "${file}" || continue   # skip binaries here; Task 5 covers them
  scan_stream "files" "${file#"${root}"/}" < "${file}"
done < <(find "${shipped[@]}" -type f -print0)

# 4. Binary channel: strings over the shipped binary and wasm artefact.
scan_stream "binary" "dist learner binary" < <(strings "${learner}/bin/sim-insolvency")
wasm_artifact="${root}/zig-out/bin/sim_insolvency_kernel.wasm"
if [[ -f "${wasm_artifact}" ]]; then
  scan_stream "binary" "wasm artefact" < <(strings "${wasm_artifact}")
fi

# 5. Runtime channel: every learner CLI command from the shipped binary.
bundle_bin="${learner}/bin/sim-insolvency"
[[ -x "${bundle_bin}" ]] || fail "runtime channel: bundle binary not executable"
runtime_output="$(
  { "${bundle_bin}" home; "${bundle_bin}" demo cvl; "${bundle_bin}" demo administration;
    "${bundle_bin}" group-demo; "${bundle_bin}" golden;
    "${bundle_bin}" certificate learner-pseudonym; } 2>&1 || true
)"
scan_stream "runtime" "learner CLI output" <<<"${runtime_output}"

# 6. Drift channel: kernel timing constants must equal reality values.
consequences_src="${root}/zig/src/consequences.zig"
[[ -s "${consequences_src}" ]] || fail "drift channel: missing ${consequences_src#"${root}"/}"
while IFS='=' read -r key value; do
  key="$(echo "${key}" | tr -d ' ')"
  value="$(echo "${value}" | tr -d ' ')"
  [[ -n "${key}" && "${key}" != \#* ]] || continue
  zig_name="$(echo "${key}" | tr '-' '_')"
  grep -qE "pub const ${zig_name}: u32 = ${value};" "${consequences_src}" ||
    fail "drift channel: ${key} = ${value} not mirrored as ${zig_name} in consequences.zig"
done < <(awk '/^\[deterministic-consequences\]/{f=1;next} /^\[/{f=0} f&&/=/' "${reality}")

# 7. Allowlist hygiene: every entry must occur somewhere in the scanned corpus.
for phrase in "${allow[@]}"; do
  found=0
  grep -RFq "${phrase}" "${shipped[@]}" 2>/dev/null && found=1
  strings "${learner}/bin/sim-insolvency" | grep -qF "${phrase}" && found=1
  grep -qF "${phrase}" <<<"${runtime_output}" && found=1
  (( found )) || fail "unused allowlist entry: ${phrase}"
done

printf 'PASS hidden-truth: %d tokens; structure, files, binary, runtime, drift\n' "${#tokens[@]}"
