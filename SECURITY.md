<!-- SPDX-License-Identifier: PMPL-2.0-or-later -->
# Security Policy

Do not include live insolvency data, learner secrets, signing keys or hidden
scenario reality in reports. Report vulnerabilities privately through the
security contact configured for the `metadatastician` estate. Include the
affected revision, reproduction and whether hidden truth, ledger integrity,
certificate integrity, authority-pack identity, Burble input or FFI memory is
affected. See `docs/architecture/threat-model.adoc`.

Certificate signing is development-only: without `SIM_INSOLVENCY_CERT_KEY` set
in the environment, the binary signs with a published dev key and marks the
certificate `key-id = "phase-a-development"`; an operator-supplied key is
marked `key-id = "operator-supplied"`. Neither makes certificates
production-grade credentials.

## Secret scanning

CI runs gitleaks (via the estate's shared `secret-scanner-reusable.yml`
workflow) on every push and pull request. If the scanner fires, treat the
matched material as exposed immediately: rotate the credential right away,
do not merely delete the offending line or commit, since prior history still
retains it until a separate history-rewrite/purge decision is made. Report
the finding through the security contact above so rotation and any required
purge can be tracked.

## Supported versions

This project is pre-alpha (`0.1.0-phase-a`). Only `main` is supported; there
are no maintained release branches and no backports. Report issues against
the current `main`.
