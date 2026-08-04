// SPDX-License-Identifier: PMPL-2.0-or-later
//! Deterministic consequence timings for morrow-engineering-001.
//! Values mirror scenarios/morrow-engineering-001/reality/reality.a2ml
//! ([deterministic-consequences]); tools/check-hidden-truth.sh fails on drift.
//! Comptime integers leave no strings in shipped binaries.

pub const communication_risk_minute: u32 = 240;
pub const asset_deterioration_minute: u32 = 480;
pub const external_petition_consequence_minute: u32 = 720;
