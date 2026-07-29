#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${root}/schemas/generated/abi-v1.manifest"
zig="${root}/zig/src/ports.zig"
idris="${root}/idris2/SimInsolvency/ABI/Conformance.idr"

grep -q 'abi.version=1' "${manifest}"
grep -q 'status.not-supported=6' "${manifest}"
grep -q 'not_supported = 6' "${zig}"
grep -q 'statusOrdinal NotSupported = 6' "${idris}"
grep -q 'ownership.output=caller-allocated' "${manifest}"
grep -q 'proof.verdict.proved=1' "${manifest}"
grep -q 'proved = 1' "${zig}"
grep -q 'record ProofGoal' "${root}/idris2/SimInsolvency/ABI/Proof.idr"
grep -q 'sim_echidna_submit' "${root}/affinescript/shell/Ports.affine"
printf '%s\n' 'PASS AffineScript, Idris2, Zig and neutral ABI manifest agree on v1/status/ownership/proof'
