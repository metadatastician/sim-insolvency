<!-- SPDX-License-Identifier: PMPL-2.0-or-later -->
# Hidden-truth adversarial validation — design

**Date:** 2026-08-04 · **Issue:** KEY-003 (critical, gate G4) · **Status:** approved

## Problem

G4's decision test requires "golden runs complete without learner-visible hidden
truth", but the current control is a single grep for three hand-curated tokens
in `tools/validate-scenario.sh`, scanned only against `shell/` and
`manifest/public.a2ml`. It misses six of the nine hidden items in
`scenarios/morrow-engineering-001/reality/reality.a2ml`, never scans the shipped
`dist/` bundle, ignores the binary and its runtime output (the consequence
timings 240/480/720 are compiled into the learner binary), and nothing proves
the check would fire if a leak existed — the estate's fake-gate anti-pattern.

## Design

### Components

1. **`tools/check-hidden-truth.sh`** — the scanner (gate).
2. **`tools/test-hidden-truth-scanner.sh`** — canary suite proving the gate can fail.
3. **`zig/src/consequences.zig`** — reality-derived timings behind one named boundary, plus kernel-level Zig tests.
4. Wiring: Justfile recipes `hidden-truth` and `test-hidden-truth-gate`, both in `just check` and `.github/workflows/quality.yml`.

### Deny-list derivation

The scanner derives tokens from `scenarios/*/reality/reality.a2ml` at run time:

- every key name under `[fixed-history]` and `[deterministic-consequences]`;
- every hyphenated value phrase (e.g. `considering-action-not-yet-committed`,
  `payment-occurred`, `legal-characterisation-not-authored-as-a-visible-fact`).

Only hyphenated tokens are matched, exact-phrase, so single common words
(`severe`, `incomplete`) are excluded by construction and neutral learner
strings ("cash pressure is evidenced") cannot collide with reality keys
(`cash-pressure`). A checked-in allowlist file
(`tools/hidden-truth-allowlist.txt`) handles future sanctioned overlaps. The
scanner **hard-fails** if: the reality file is missing, the derived list is
empty, the learner bundle is missing, or any allowlist entry matches nothing —
a format drift can never produce a vacuous pass.

### Channel scans (one scanner run covers all)

| Channel | Check |
|---|---|
| Structure | Learner bundle must NOT contain `reality/`, `assessment/`, or `evidence/requestable-evidence.a2ml`; a facilitator bundle, when present, MUST contain them (profiles provably differ). |
| Files | Token grep over the learner bundle and the source-side shipped set (`shell/`, `rule-packs/`, scenario `manifest/`, `actors/`, `procedures/`, `evidence/` minus the facilitator-only file) — catches authoring leaks pre-packaging. |
| Binary | `strings` over `dist/.../bin/sim-insolvency` and the wasm artefact, token grep. |
| Runtime | Execute every learner CLI command from the bundle binary (`home`, `demo cvl`, `demo administration`, `group-demo`, `golden`, `certificate learner-pseudonym`); token grep over combined stdout+stderr. |
| Drift | Timing values in `zig/src/consequences.zig` must equal the `[deterministic-consequences]` values in `reality.a2ml` (single source of truth, verified by text comparison). |

### Kernel refactor

Move `240`/`480`/`720` from `kernel.zig` (consequence emission ~422–432 and
scoring reuse ~467–468) into `zig/src/consequences.zig` as named comptime
constants. Comptime ints leave no strings in the binary; Zig underscore
identifiers can never match hyphenated deny-list phrases. Behaviour is
identical — a move, not a change; `zig build test` must agree before/after.

New inline Zig tests: run all 8 golden runs, walk every ledger event payload
and the certificate text, assert no reality phrase appears. The Zig-side phrase
list is a commented copy pointing at `reality.a2ml`; the shell scanner's
derived list is authoritative (accepted limitation, mitigated by the drift
check).

### Canary self-tests

`tools/test-hidden-truth-scanner.sh` builds trap-cleaned scratch copies and
asserts the scanner exits nonzero for each seeded leak, and zero on the
untouched copy:

- a reality phrase appended to a shipped `.adoc` (files channel);
- a token appended to a copy of the binary (binary channel);
- a rogue `reality/` directory inside the scratch learner bundle (structure);
- a stub binary echoing a token (runtime channel);
- an empty deny-list simulation must abort loudly (vacuity guard).

### Error handling

Both scripts: `set -euo pipefail`, explicit FAIL messages naming the channel
and token, `mktemp` scratch dirs removed via `trap`. Scanner exit codes:
0 clean, 1 leak/vacuity, 2 usage/missing-precondition.

### Testing and verification

- Canary suite is the scanner's own test; runs in `just check` and CI.
- Kernel tests run under `zig build test` as today.
- End-to-end: full local gate suite green (`just lint && just check`), then one
  manual seeded leak demonstrating the gate goes red before final cleanup.

### Documentation

One-line updates to `docs/architecture/threat-model.adoc` (control becomes
"derived deny-list + canary-verified scanner over shipped artefacts, binary and
runtime output") and `CHANGELOG.adoc`.

## Out of scope (deliberate)

- Facilitator-bundle generation (none committed; scanner treats it as optional).
- DWARF/debug-info identifier noise in the binary (reality *phrases* cannot
  appear as Zig identifiers; documented).
- Typed-wasm producer work or any learner/facilitator build split (G3 topic).
- Changes to `validate-scenario.sh` beyond leaving its existing checks in place
  (the new scanner supersedes its leak grep; the old grep stays as
  defence-in-depth).
