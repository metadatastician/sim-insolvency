#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
estate_root="$(cd "${repo_root}/../.." && pwd)"
failures=0

check_tool() {
  local name="$1"
  local required="$2"
  if command -v "${name}" >/dev/null 2>&1; then
    if [[ "${name}" == "zig" ]]; then
      printf 'OK       %-18s %s\n' "${name}" "$("${name}" version 2>&1 | head -n 1)"
    else
      printf 'OK       %-18s %s\n' "${name}" "$("${name}" --version 2>&1 | head -n 1)"
    fi
  else
    printf '%-8s %-18s missing\n' "${required}" "${name}"
    if [[ "${required}" == "REQUIRED" ]]; then failures=$((failures + 1)); fi
  fi
}

check_repo() {
  local label="$1"
  local path="$2"
  local required="$3"
  if [[ -d "${path}/.git" ]]; then
    printf 'OK       %-18s %s\n' "${label}" "$(git -C "${path}" rev-parse --short=12 HEAD)"
  else
    printf '%-8s %-18s not found at %s\n' "${required}" "${label}" "${path}"
    if [[ "${required}" == "REQUIRED" ]]; then failures=$((failures + 1)); fi
  fi
}

printf '%s\n' 'Sim Insolvency doctor — no dependencies are installed automatically'
check_tool just REQUIRED
check_tool zig REQUIRED
check_tool idris2 REQUIRED
check_tool guix OPTIONAL
check_tool dune OPTIONAL
check_tool nerdctl OPTIONAL
check_tool buildkitd OPTIONAL

check_repo affinescript "${estate_root}/hyper-repos/_LANGUAGES _SET/_NEXTGEN_LANGUAGES _SET/affinescript" OPTIONAL
check_repo typed-wasm "${estate_root}/hyper-repos/_LANGUAGES _SET/_NEXTGEN_LANGUAGES _SET/typed-wasm" OPTIONAL
check_repo verisimdb "${estate_root}/hyper-repos/_DATABASE _SET/verisimdb" OPTIONAL
check_repo gossamer "${estate_root}/meta-repos/gossamer" OPTIONAL
check_repo burble "${estate_root}/meta-repos/burble" OPTIONAL
check_repo proven-tests "${estate_root}/hyper-repos/proven-tests-and-benches" OPTIONAL
check_repo echidna "${estate_root}/hyper-repos/echidna" OPTIONAL
check_repo stapeln "${estate_root}/meta-repos/stapeln" OPTIONAL
check_repo palimpsest "${estate_root}/hyper-repos/palimpsest-license" OPTIONAL

if command -v affinescript >/dev/null 2>&1; then
  printf 'OK       %-18s available\n' 'AffineScript build'
else
  printf 'BLOCKED  %-18s compiler not on PATH; Zig fallback is explicit\n' 'AffineScript build'
fi

if command -v guix >/dev/null 2>&1; then
  printf 'OK       %-18s manifest can be evaluated\n' 'Guix'
else
  printf 'BLOCKED  %-18s build/guix.scm is authoritative but Guix is unavailable\n' 'Guix'
fi

printf 'BLOCKED  %-18s canonical unified-hexadeca-api repository not located\n' 'Hexadeca'
printf 'OPTIONAL %-18s local service profile uses http://127.0.0.1:8080/api/v1\n' 'VeriSimDB runtime'
printf 'OPTIONAL %-18s native graphical launch requires Gossamer/Ephapax/webview libraries\n' 'Gossamer runtime'
printf 'OPTIONAL %-18s group mode requires explicit Burble opt-in\n' 'Burble runtime'
printf 'OPTIONAL %-18s future proof dispatch; Phase A checks Idris2 locally\n' 'ECHIDNA runtime'

if command -v nerdctl >/dev/null 2>&1; then
  if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containerd-rootless/containerd.sock" ]]; then
    printf 'OK       %-18s rootless containerd socket available\n' 'nerdctl runtime'
  else
    printf 'BLOCKED  %-18s client installed; rootless containerd socket unavailable\n' 'nerdctl runtime'
  fi
fi
if ! command -v buildkitd >/dev/null 2>&1; then
  printf 'BLOCKED  %-18s required by nerdctl build; Containerfile remains test-unbuilt\n' 'BuildKit'
fi

if (( failures > 0 )); then
  printf 'FAIL     required tool failures: %d\n' "${failures}"
  exit 1
fi
printf '%s\n' 'PASS     required local fallback toolchain is available'
