<!-- SPDX-License-Identifier: PMPL-2.0-or-later -->
# Hidden-Truth Adversarial Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a canary-verified leak gate proving scenario hidden truth never reaches learner-visible artefacts, binaries, or runtime output (KEY-003, gate G4).

**Architecture:** A shell scanner derives its deny-list from `reality.a2ml` and scans four channels (bundle structure, shipped files, binary strings, CLI runtime output) plus a kernel↔reality drift check; a canary suite seeds leaks into scratch copies and asserts the scanner fires; the Zig kernel gets reality-derived timings extracted into one module and leak-assertion tests over all golden runs.

**Tech Stack:** bash (+awk/sed/grep/strings), Zig 0.16, just, GitHub Actions (no new actions).

**Spec:** `docs/superpowers/specs/2026-08-04-hidden-truth-adversarial-validation-design.md`

## Global Constraints

- Work in `/home/hyperpolymath/developer/meta-repos/sim-insolvency` on branch `agent/hidden-truth-gate` (exists, tracks origin/main, spec already committed).
- Languages: bash and Zig only. Python/TypeScript/JS/C/C++ are banned repo-wide (`check-no-prohibited-stack.sh` enforces).
- Every new file starts with `# SPDX-License-Identifier: PMPL-2.0-or-later` (or `//` form for Zig) on **line 1**.
- Zig 0.16 (`mise` toolchain on PATH). `zig fmt --check build.zig zig` must stay clean — it covers new files automatically.
- Commit messages: short imperative subject, no type prefix (repo style: "Add verifiable certificate envelopes"), body optional, end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Gates must be honest: any check must demonstrably fail when its condition fails (that is what the canary suite proves). Never write a check that exits 0 when its tool or input is missing.
- The committed `dist/sim-insolvency-learner/` bundle is what ships; its binary is slightly stale vs source (built before the cert key-id change) — scan it as-is, do NOT rebuild or modify anything under `dist/` in this plan.
- The repo owner insta-merges open PRs, including drafts. Do NOT open the PR until every task is complete and `just check` is green.
- **If the scanner FAILS on the clean tree at any point, that is a potential real leak discovery, not a test bug. Stop, record the exact token/file/channel, and report to the operator before changing any allowlist.**
- Known-good pre-flight facts (measured 2026-08-04): the 12-token derived scan is clean on all channels EXCEPT `strings` over the shipped binary matching `connected-payment` inside the legitimate literal `connected-payment-records` — the allowlist masking in Task 4 exists precisely for this. Expect exactly that one masking case.

---

### Task 1: Extract consequence timings into `consequences.zig`

**Files:**
- Create: `zig/src/consequences.zig`
- Modify: `zig/src/kernel.zig` (~line 3 import; lines 422, 426, 432 in `applyTimedEvents`; lines 467–468 in `assess`)

**Interfaces:**
- Produces: module `consequences` (imported from kernel.zig as `@import("consequences.zig")`) with `pub const communication_risk_minute: u32 = 240`, `pub const asset_deterioration_minute: u32 = 480`, `pub const external_petition_consequence_minute: u32 = 720`. Task 5's drift check greps these exact declarations; keep the `pub const <name>: u32 = <value>;` shape.

- [ ] **Step 1: Record the pre-refactor baseline**

Run: `cd /home/hyperpolymath/developer/meta-repos/sim-insolvency && zig build test && echo BASELINE-GREEN`
Expected: `BASELINE-GREEN` (existing determinism tests pass; their digests pin behaviour).

- [ ] **Step 2: Create the module**

`zig/src/consequences.zig`:

```zig
// SPDX-License-Identifier: PMPL-2.0-or-later
//! Deterministic consequence timings for morrow-engineering-001.
//! Values mirror scenarios/morrow-engineering-001/reality/reality.a2ml
//! ([deterministic-consequences]); tools/check-hidden-truth.sh fails on drift.
//! Comptime integers leave no strings in shipped binaries.

pub const communication_risk_minute: u32 = 240;
pub const asset_deterioration_minute: u32 = 480;
pub const external_petition_consequence_minute: u32 = 720;
```

- [ ] **Step 3: Use it in kernel.zig**

Add after `pub const ports = @import("ports.zig");` (line 3):

```zig
pub const consequences = @import("consequences.zig");
```

In `applyTimedEvents` replace the three magic numbers:

```zig
        if (self.logical_minute >= consequences.communication_risk_minute and self.communications == 0) {
```
```zig
        if (self.logical_minute >= consequences.asset_deterioration_minute and !self.protected_assets) {
```
```zig
        if (self.logical_minute >= consequences.external_petition_consequence_minute and self.procedure == .undecided) {
```

In `assess` replace lines 467–468:

```zig
        result.prioritisation = if (self.protected_assets) 3 else if (self.logical_minute < consequences.asset_deterioration_minute) 2 else 0;
        result.timeliness = if (self.logical_minute < consequences.asset_deterioration_minute) 3 else if (self.logical_minute < consequences.external_petition_consequence_minute) 2 else 0;
```

- [ ] **Step 4: Verify behaviour identical**

Run: `zig fmt --check build.zig zig && zig build test && echo REFACTOR-GREEN`
Expected: `REFACTOR-GREEN`. The determinism tests ("ledger replay chain…", "all eight golden runs…") recompute digests over the same event stream — any behavioural drift fails them.

- [ ] **Step 5: Commit**

```bash
git add zig/src/consequences.zig zig/src/kernel.zig
git commit -m "Extract consequence timings into a reality-boundary module

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Split `runGolden` so tests can walk the ledger

**Files:**
- Modify: `zig/src/kernel.zig` (function `runGolden`, lines ~604–661)

**Interfaces:**
- Produces: `fn playGolden(run: GoldenRun) CommandError!Session` (file-private; returns the session after the scripted play, BEFORE `assess`/`close`). Task 3's sweep test calls it, then calls `assess()`/`close()` itself so the walked ledger includes assessment events.
- `runGolden` keeps its exact public signature and behaviour.

- [ ] **Step 1: Extract the play script**

Rename the body: everything in `runGolden` from `var session = try Session.init(...)` down to (and including) the `try session.completeBranch();` / `try session.advance(760);` branching becomes:

```zig
fn playGolden(run: GoldenRun) CommandError!Session {
    var session = try Session.init(@as(u64, 0x4d4f52524f57) + @as(u64, @intFromEnum(run)));
    // ... UNCHANGED lines 606-651 from the current runGolden body ...
    return session;
}
```

and `runGolden` becomes:

```zig
pub fn runGolden(run: GoldenRun) CommandError!GoldenOutcome {
    var session = try playGolden(run);
    const result = try session.assess();
    try session.close();
    return .{
        .run = run,
        .result = result,
        .consequence = session.consequence,
        .digest = session.ledger.headDigest(),
        .event_count = session.ledger.len,
    };
}
```

Copy lines 606–651 verbatim — do not retype them.

- [ ] **Step 2: Verify digests unchanged**

Run: `zig fmt --check build.zig zig && zig build test && echo SPLIT-GREEN`
Expected: `SPLIT-GREEN` (determinism tests prove the event stream is byte-identical).

- [ ] **Step 3: Commit**

```bash
git add zig/src/kernel.zig
git commit -m "Split golden-run play from assessment for ledger inspection

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Kernel-level leak-assertion tests

**Files:**
- Modify: `zig/src/kernel.zig` (append after the existing `test` blocks at end of file)

**Interfaces:**
- Consumes: `playGolden` (Task 2), `runGolden`, `certificateForOutcome(outcome, learner, key)`.
- Produces: `fn containsHiddenTruth(text: []const u8) bool` (file-private) — masks allowlisted phrases, then substring-matches deny tokens.

- [ ] **Step 1: Write the positive-control test (failing)**

Append to `zig/src/kernel.zig`:

```zig
test "hidden-truth detector positive control" {
    try std.testing.expect(containsHiddenTruth("note: payment-occurred at month end"));
    try std.testing.expect(containsHiddenTruth("secured-creditor-intent"));
    try std.testing.expect(containsHiddenTruth("connected-payment = made"));
    try std.testing.expect(!containsHiddenTruth("connected-payment-records"));
    try std.testing.expect(!containsHiddenTruth("cash pressure is evidenced"));
    try std.testing.expect(!containsHiddenTruth("secured-creditor-response-window"));
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `zig build test 2>&1 | tail -5`
Expected: compile error — `containsHiddenTruth` is undefined.

- [ ] **Step 3: Implement the detector**

Insert immediately above the new test:

```zig
// Mirrors the hyphenated tokens of reality.a2ml [fixed-history] and
// [deterministic-consequences]; tools/check-hidden-truth.sh derives the
// authoritative list from the file itself.
const hidden_truth_tokens = [_][]const u8{
    "cash-pressure",
    "management-information",
    "secured-creditor-intent",
    "connected-payment",
    "communication-risk-minute",
    "asset-deterioration-minute",
    "external-petition-consequence-minute",
    "considering-action-not-yet-committed",
    "interested-but-funding-not-verified",
    "differing-recollections-and-incentives",
    "payment-occurred",
    "legal-characterisation-not-authored-as-a-visible-fact",
};
const hidden_truth_allow = [_][]const u8{
    "connected-payment-records",
};

fn containsHiddenTruth(text: []const u8) bool {
    var buf: [2 * max_payload]u8 = undefined;
    if (text.len > buf.len) return true;
    @memcpy(buf[0..text.len], text);
    const masked = buf[0..text.len];
    for (hidden_truth_allow) |phrase| {
        var start: usize = 0;
        while (std.mem.indexOfPos(u8, masked, start, phrase)) |idx| {
            @memset(masked[idx .. idx + phrase.len], 'x');
            start = idx + phrase.len;
        }
    }
    for (hidden_truth_tokens) |token| {
        if (std.mem.indexOf(u8, masked, token) != null) return true;
    }
    return false;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `zig build test && echo DETECTOR-GREEN`
Expected: `DETECTOR-GREEN`.

- [ ] **Step 5: Write the golden-run sweep test**

Append:

```zig
test "golden runs never expose hidden truth in ledger or certificate" {
    const runs = [_]GoldenRun{
        .cvl_competent_standard,
        .cvl_competent_alternative,
        .administration_competent_standard,
        .administration_competent_alternative,
        .threshold_borderline,
        .critical_error,
        .deadline_failure,
        .group_session_with_dissent,
    };
    for (runs) |run| {
        var session = try playGolden(run);
        _ = try session.assess();
        try session.close();
        for (session.ledger.events[0..session.ledger.len]) |*event| {
            try std.testing.expect(!containsHiddenTruth(event.payloadSlice()));
            try std.testing.expect(!containsHiddenTruth(event.actorSlice()));
        }
        const outcome = try runGolden(run);
        const certificate = try certificateForOutcome(outcome, "learner-pseudonym", "test-key");
        try std.testing.expect(!containsHiddenTruth(certificate.result_class));
    }
}
```

- [ ] **Step 6: Run all tests, then commit**

Run: `zig fmt --check build.zig zig && zig build test && echo LEAK-TESTS-GREEN`
Expected: `LEAK-TESTS-GREEN`. If the sweep test fails, apply the Global Constraints leak-discovery rule (stop and report).

```bash
git add zig/src/kernel.zig
git commit -m "Assert golden runs expose no hidden truth in ledger or certificate

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Scanner — derivation, vacuity, structure and files channels

**Files:**
- Create: `tools/check-hidden-truth.sh` (mode 0755), `tools/hidden-truth-allowlist.txt`

**Interfaces:**
- Produces: `tools/check-hidden-truth.sh [root]` — arg 1 optionally overrides the repo root (the canary suite in Task 6 depends on this). Exit 0 clean, 1 leak/vacuity/unused-allowlist, 2 missing preconditions. Prints `PASS hidden-truth: <n> tokens; structure, files, binary, runtime, drift` on success (binary/runtime/drift arrive in Task 5).

- [ ] **Step 1: Write the allowlist file**

`tools/hidden-truth-allowlist.txt`:

```
# SPDX-License-Identifier: PMPL-2.0-or-later
# Sanctioned phrases that contain a hidden-truth token as a substring.
# Each entry must occur in the scanned corpus or the scanner fails (hygiene).
connected-payment-records
```

- [ ] **Step 2: Write the scanner (first four sections)**

`tools/check-hidden-truth.sh`:

```bash
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
```

- [ ] **Step 3: Make it executable and run on the clean tree**

Run: `chmod 0755 tools/check-hidden-truth.sh && ./tools/check-hidden-truth.sh && shellcheck tools/check-hidden-truth.sh && echo SCAN-V1-GREEN`
Expected: `PASS hidden-truth: 12 tokens; structure, files` then `SCAN-V1-GREEN`. A FAIL here = leak discovery: stop and report.

- [ ] **Step 4: Verify it can fail (throwaway check)**

Run:
```bash
tmp=$(mktemp -d) && cp -R scenarios shell rule-packs tools dist "$tmp/" \
  && echo "payment-occurred" >> "$tmp/dist/sim-insolvency-learner/scenarios/morrow-engineering-001/evidence/cash-summary.adoc" \
  && if ./tools/check-hidden-truth.sh "$tmp"; then echo "BUG: scanner passed seeded leak"; else echo SEEDED-LEAK-CAUGHT; fi; rm -rf "$tmp"
```
Expected: `FAIL hidden-truth: files channel: token 'payment-occurred' in ...` then `SEEDED-LEAK-CAUGHT`.

- [ ] **Step 5: Commit**

```bash
git add tools/check-hidden-truth.sh tools/hidden-truth-allowlist.txt
git commit -m "Add hidden-truth scanner: derived deny-list, structure and files channels

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Scanner — binary, runtime, drift channels and allowlist hygiene

**Files:**
- Modify: `tools/check-hidden-truth.sh` (insert before the final `printf 'PASS ...'`, and replace that line)

**Interfaces:**
- Consumes: `mask`, `scan_stream`, `tokens`, `allow`, `learner`, `root` from Task 4.
- Produces: final PASS line `PASS hidden-truth: <n> tokens; structure, files, binary, runtime, drift` (Task 6 and Task 7 rely on scanner exit codes only, not this text).

- [ ] **Step 1: Add the remaining channels**

Insert before the final `printf`:

```bash
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
```

Replace the final line with:

```bash
printf 'PASS hidden-truth: %d tokens; structure, files, binary, runtime, drift\n' "${#tokens[@]}"
```

- [ ] **Step 2: Run on the clean tree**

Run: `./tools/check-hidden-truth.sh && shellcheck tools/check-hidden-truth.sh && echo SCAN-V2-GREEN`
Expected: `PASS hidden-truth: 12 tokens; structure, files, binary, runtime, drift` then `SCAN-V2-GREEN`. The binary channel passes only because masking blanks `connected-payment-records` first — if it fails on `connected-payment`, the mask ordering broke.

- [ ] **Step 3: Commit**

```bash
git add tools/check-hidden-truth.sh
git commit -m "Extend hidden-truth scanner to binary, runtime and drift channels

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Canary suite — prove the gate fires

**Files:**
- Create: `tools/test-hidden-truth-scanner.sh` (mode 0755)

**Interfaces:**
- Consumes: `tools/check-hidden-truth.sh [root]` exit codes (0 clean, nonzero on any defect).
- Produces: `tools/test-hidden-truth-scanner.sh` — exit 0 with `PASS hidden-truth canaries: 7/7` when every seeded leak is caught AND the clean copy passes.

- [ ] **Step 1: Write the canary suite**

`tools/test-hidden-truth-scanner.sh`:

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-2.0-or-later
# Adversarial validation of check-hidden-truth.sh: seed one leak per channel
# into a scratch tree and require the scanner to fail; require it to pass on
# the untouched copy. A scanner that cannot fail is not a gate.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scanner="${root}/tools/check-hidden-truth.sh"
passes=0
total=7

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

printf 'PASS hidden-truth canaries: %d/%d\n' "${passes}" "${total}"
```

- [ ] **Step 2: Run it**

Run: `chmod 0755 tools/test-hidden-truth-scanner.sh && ./tools/test-hidden-truth-scanner.sh && shellcheck tools/test-hidden-truth-scanner.sh && echo CANARIES-GREEN`
Expected: seven `canary ok` lines, `PASS hidden-truth canaries: 7/7`, `CANARIES-GREEN`.

- [ ] **Step 3: Commit**

```bash
git add tools/test-hidden-truth-scanner.sh
git commit -m "Prove the hidden-truth gate fires with per-channel canaries

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Wire into just and CI

**Files:**
- Modify: `Justfile` (line 45 `check:` recipe; append two recipes near `docs-health`)
- Modify: `.github/workflows/quality.yml` (append two steps after `check-wiki-health.sh`)

**Interfaces:**
- Consumes: both tools from Tasks 4–6.
- Produces: `just hidden-truth`, `just test-hidden-truth-gate`, both in `just check`; CI runs both scripts.

- [ ] **Step 1: Justfile**

Change line 45 to:

```
check: lint typecheck prove test hidden-truth test-hidden-truth-gate
```

Append after the `docs-health` recipe:

```
hidden-truth:
    ./tools/check-hidden-truth.sh

test-hidden-truth-gate:
    ./tools/test-hidden-truth-scanner.sh
```

- [ ] **Step 2: quality.yml**

Append after `- run: ./tools/check-wiki-health.sh` exactly:

```yaml
      - run: ./tools/check-hidden-truth.sh
      - run: ./tools/test-hidden-truth-scanner.sh
```

(No new `uses:` entries, so `.github/workflows/actions.lock` needs no change; confirm with the verify step below.)

- [ ] **Step 3: Verify everything**

Run: `just check && gh actions-lock --no-fix --json | grep -m1 '"valid"' && echo WIRED-GREEN`
Expected: full chain green (lint, typecheck BLOCKED-soft, prove, test, hidden-truth, canaries), `"valid": true,`, `WIRED-GREEN`.

- [ ] **Step 4: Commit**

```bash
git add Justfile .github/workflows/quality.yml
git commit -m "Gate just check and CI on hidden-truth scanner and canaries

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Docs, end-to-end red demo, PR

**Files:**
- Modify: `docs/architecture/threat-model.adoc` (the "Hidden truth leakage" entry), `CHANGELOG.adoc`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Update threat model**

Replace the `Hidden truth leakage::` body line:

```
Hidden truth leakage::
Reality excluded from learner bundles; opaque identifiers; no debug projection;
sealed/facilitator-controlled reveal; canary-verified scanner with a deny-list
derived from scenario reality, covering bundle structure, shipped files,
binary strings and runtime output, plus kernel timing drift.
```

- [ ] **Step 2: Update changelog**

Append to the `== 0.1.0-phase-a — unreleased` bullet list:

```
* Added a canary-verified hidden-truth leak gate over bundle structure,
  shipped files, binary strings, runtime output and kernel timing drift.
```

- [ ] **Step 3: End-to-end red demo (throwaway, then revert)**

Prove the WIRED gate goes red on a real leak:

```bash
echo "considering-action-not-yet-committed" >> shell/index.html
if just hidden-truth; then echo "BUG: gate green on live leak"; else echo E2E-RED-CONFIRMED; fi
git checkout -- shell/index.html
just hidden-truth && echo E2E-GREEN-RESTORED
```
Expected: `E2E-RED-CONFIRMED` then `E2E-GREEN-RESTORED`.

- [ ] **Step 4: Final full verification**

Run: `just lint && just check && zig build wasm && echo ALL-GREEN`
Expected: `ALL-GREEN`. Working tree clean except the two doc files.

- [ ] **Step 5: Commit docs, push, open the PR (only now — owner insta-merges)**

```bash
git add docs/architecture/threat-model.adoc CHANGELOG.adoc
git commit -m "Record hidden-truth gate in threat model and changelog

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push -u origin agent/hidden-truth-gate
gh pr create --repo metadatastician/sim-insolvency --base main \
  --title "Canary-verified hidden-truth leak gate (KEY-003, G4)" \
  --body "$(cat <<'PRBODY'
Implements docs/superpowers/specs/2026-08-04-hidden-truth-adversarial-validation-design.md.

- Deny-list derived from reality.a2ml (12 tokens) — scanner can never drift from scenario authoring; empty derivation aborts (vacuity guard).
- Four channels: bundle structure, shipped files, binary strings, learner CLI runtime output; plus kernel↔reality timing drift check.
- Canary suite seeds a leak per channel and requires the scanner to fail: 7/7.
- Kernel: consequence timings extracted to zig/src/consequences.zig (comptime ints — no strings in the binary); golden-run leak-assertion tests over all 8 runs' ledgers and certificates.
- Wired into `just check` and quality.yml (no new actions; lockfile unchanged).

Verification: `just check` green end-to-end; canaries 7/7; seeded-leak red demo confirmed then reverted; `gh actions-lock --no-fix` valid. CI on this PR runs the new gates live.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
```

- [ ] **Step 6: Watch the PR's CI run**

Run: `gh run list --repo metadatastician/sim-insolvency --branch agent/hidden-truth-gate --limit 2`
Expected: quality runs execute and succeed (real jobs, ~40s+, not 0s). Use `gh run list`, never `gh pr checks`.

---

## Self-review notes

- Spec coverage: derivation+vacuity (T4), allowlist+hygiene (T4/T5), four channels (T4/T5), drift (T5), canaries incl. vacuity (T6), kernel module (T1), playGolden+Zig tests (T2/T3), wiring (T7), docs+e2e (T8). Spec's "certificate text" is covered by the runtime channel (full cert text via CLI) plus `result_class` kernel-side, as the spec's kernel section allows.
- Type consistency: `containsHiddenTruth`, `playGolden`, `consequences.*` names match across tasks; scanner arg contract `[root]` matches canary usage.
