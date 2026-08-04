#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
# Adversarial validation of check-hidden-truth.sh: seed one leak per channel
# into a scratch tree and require the scanner to fail; require it to pass on
# the untouched copy. A scanner that cannot fail is not a gate.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scanner="${root}/tools/check-hidden-truth.sh"
passes=0
total=8

stage() { # $1 = destination; copy the minimal tree the scanner needs
  mkdir -p "$1"
  cp -R "${root}/scenarios" "${root}/shell" "${root}/rule-packs" \
    "${root}/tools" "${root}/zig" "$1/"
  mkdir -p "$1/dist"
  cp -R "${root}/dist/sim-insolvency-learner" "$1/dist/"
}

expect_pass() { # $1 root, $2 label
  if "${scanner}" "$1" > /dev/null 2>&1; then
    passes=$((passes + 1)); printf 'canary ok (clean pass): %s\n' "$2"
  else
    printf 'CANARY FAILED: scanner rejected clean tree: %s\n' "$2" >&2; exit 1
  fi
}
expect_fail() { # $1 root, $2 label
  if "${scanner}" "$1" > /dev/null 2>&1; then
    printf 'CANARY FAILED: scanner passed seeded leak: %s\n' "$2" >&2; exit 1
  else
    passes=$((passes + 1)); printf 'canary ok (leak caught): %s\n' "$2"
  fi
}

scratch="$(mktemp -d)"
trap 'rm -rf "${scratch}"' EXIT
bundle_scenario="dist/sim-insolvency-learner/scenarios/morrow-engineering-001"

# 1. Clean copy must pass.
stage "${scratch}/clean"
expect_pass "${scratch}/clean" "untouched tree"

# 2. Files channel: reality phrase appended to a shipped evidence file.
stage "${scratch}/files"
echo "payment-occurred" >> "${scratch}/files/${bundle_scenario}/evidence/cash-summary.adoc"
expect_fail "${scratch}/files" "files: token in shipped adoc"

# 3. Structure channel: rogue reality/ inside the learner bundle.
stage "${scratch}/structure"
mkdir -p "${scratch}/structure/${bundle_scenario}/reality"
cp "${root}/scenarios/morrow-engineering-001/reality/reality.a2ml" \
  "${scratch}/structure/${bundle_scenario}/reality/"
expect_fail "${scratch}/structure" "structure: reality/ shipped to learner"

# 4. Binary channel: token appended to a copy of the shipped binary.
stage "${scratch}/binary"
printf '\nsecured-creditor-intent\n' >> "${scratch}/binary/dist/sim-insolvency-learner/bin/sim-insolvency"
expect_fail "${scratch}/binary" "binary: token embedded in binary"

# 5. Runtime channel: stub binary leaks a token only at run time
#    (printf assembles it, so the file itself contains no full token).
stage "${scratch}/runtime"
cat > "${scratch}/runtime/dist/sim-insolvency-learner/bin/sim-insolvency" <<'EOF'
#!/bin/sh
printf 'payment%s\n' '-occurred'
EOF
chmod 0755 "${scratch}/runtime/dist/sim-insolvency-learner/bin/sim-insolvency"
expect_fail "${scratch}/runtime" "runtime: token emitted at run time only"

# 6. Vacuity guard: a reality file that derives zero tokens must abort.
stage "${scratch}/vacuous"
tr -d '-' < "${root}/scenarios/morrow-engineering-001/reality/reality.a2ml" \
  > "${scratch}/vacuous/scenarios/morrow-engineering-001/reality/reality.a2ml"
expect_fail "${scratch}/vacuous" "vacuity: empty deny-list aborts"

# 7. Allowlist hygiene: an entry matching nothing must fail.
stage "${scratch}/allow"
echo "bogus-unused-phrase-zzz" >> "${scratch}/allow/tools/hidden-truth-allowlist.txt"
expect_fail "${scratch}/allow" "allowlist: unused entry rejected"

# 8. Drift channel: kernel constant diverging from reality must fail.
stage "${scratch}/drift"
sed -i 's/communication-risk-minute = 240/communication-risk-minute = 999/' \
  "${scratch}/drift/scenarios/morrow-engineering-001/reality/reality.a2ml"
expect_fail "${scratch}/drift" "drift: kernel constant diverges from reality"

printf 'PASS hidden-truth canaries: %d/%d\n' "${passes}" "${total}"
