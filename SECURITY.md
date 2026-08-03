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
