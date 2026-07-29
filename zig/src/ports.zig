// SPDX-License-Identifier: PMPL-2.0-or-later
const std = @import("std");

pub const abi_version: u32 = 1;

pub const Status = enum(u32) {
    ok = 0,
    invalid_version = 1,
    invalid_length = 2,
    invalid_encoding = 3,
    not_authorised = 4,
    not_available = 5,
    not_supported = 6,
    conflict = 7,
    integrity_failure = 8,
    resource_exhausted = 9,
    internal_failure = 10,
};

pub const HexadecaPort = struct {
    pub fn dispatch(_: *HexadecaPort, version: u32, _: []const u8, _: []u8) Status {
        if (version != abi_version) return .invalid_version;
        return .not_supported;
    }
};

pub const VeriSimPort = struct {
    mode: enum { offline_file, local_http },

    pub fn endpoint(self: VeriSimPort) []const u8 {
        return switch (self.mode) {
            .offline_file => "offline://portable-ledger",
            .local_http => "http://127.0.0.1:8080/api/v1",
        };
    }

    pub fn putEnvelope(self: VeriSimPort, version: u32, envelope: []const u8) Status {
        if (version != abi_version) return .invalid_version;
        if (envelope.len == 0 or envelope.len > 64 * 1024) return .invalid_length;
        return switch (self.mode) {
            .offline_file => .ok,
            .local_http => .not_available,
        };
    }
};

pub const CollaborationKind = enum {
    discussion,
    proposal,
    vote,
    reveal_request,
    authoritative_command,
};

pub const BurblePort = struct {
    pub fn receive(_: *BurblePort, version: u32, kind: CollaborationKind, body: []const u8) Status {
        if (version != abi_version) return .invalid_version;
        if (body.len == 0 or body.len > 4096) return .invalid_length;
        if (kind == .authoritative_command) return .not_authorised;
        return .ok;
    }
};

pub const GossamerPort = struct {
    pub fn projection(_: *GossamerPort, version: u32, output: []u8) Status {
        if (version != abi_version) return .invalid_version;
        const text = "SIMULATION ONLY|morrow-engineering-001|assessment";
        if (output.len < text.len) return .resource_exhausted;
        @memcpy(output[0..text.len], text);
        return .ok;
    }
};

pub const ProofVerdict = enum(u8) {
    unknown = 0,
    proved = 1,
    disproved = 2,
    timeout = 3,
    error_total = 4,
};

/// Stable, transport-neutral contract matching the fields needed to create an
/// ECHIDNA ProofGoal. It deliberately embeds neither Cap'n Proto nor a prover.
pub const EchidnaProofPort = struct {
    pub const max_goal_bytes = 16 * 1024;
    pub const max_context_bytes = 48 * 1024;

    pub fn submit(
        _: *EchidnaProofPort,
        version: u32,
        request_id: []const u8,
        goal: []const u8,
        context: []const u8,
        timeout_ms: u32,
    ) Status {
        if (version != abi_version) return .invalid_version;
        if (request_id.len == 0 or request_id.len > 128) return .invalid_length;
        if (goal.len == 0 or goal.len > max_goal_bytes) return .invalid_length;
        if (context.len > max_context_bytes) return .invalid_length;
        if (timeout_ms == 0 or timeout_ms > 300_000) return .invalid_length;
        // Phase A records proof obligations but does not pretend a prover ran.
        return .not_available;
    }

    pub fn acceptReceipt(
        _: *EchidnaProofPort,
        version: u32,
        attempt_id: []const u8,
        verdict: ProofVerdict,
        prover_binary_hash: []const u8,
        certificate_digest: []const u8,
    ) Status {
        if (version != abi_version) return .invalid_version;
        if (attempt_id.len == 0 or attempt_id.len > 128) return .invalid_length;
        if (prover_binary_hash.len != 32) return .invalid_length;
        if (verdict == .proved and certificate_digest.len != 32)
            return .integrity_failure;
        if (certificate_digest.len != 0 and certificate_digest.len != 32)
            return .invalid_length;
        return .ok;
    }
};

test "ABI status ordinals match Idris2 neutral manifest" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(Status.ok));
    try std.testing.expectEqual(@as(u32, 6), @intFromEnum(Status.not_supported));
    try std.testing.expectEqual(@as(u32, 10), @intFromEnum(Status.internal_failure));
}

test "Burble cannot directly mutate authoritative state" {
    var port: BurblePort = .{};
    try std.testing.expectEqual(Status.not_authorised, port.receive(1, .authoritative_command, "append-event"));
    try std.testing.expectEqual(Status.ok, port.receive(1, .proposal, "select administration"));
}

test "ports are version and length safe" {
    var hex: HexadecaPort = .{};
    var out: [8]u8 = undefined;
    try std.testing.expectEqual(Status.invalid_version, hex.dispatch(2, "x", &out));
    try std.testing.expectEqual(Status.not_supported, hex.dispatch(1, "x", &out));
    const store: VeriSimPort = .{ .mode = .offline_file };
    try std.testing.expectEqual(Status.invalid_length, store.putEnvelope(1, ""));
}

test "ECHIDNA port is proof-ready without claiming a proof" {
    var proof: EchidnaProofPort = .{};
    try std.testing.expectEqual(
        Status.not_available,
        proof.submit(1, "proof-event-chain-001", "event_chain_intact ledger", "", 30_000),
    );
    try std.testing.expectEqual(
        Status.integrity_failure,
        proof.acceptReceipt(1, "attempt-001", .proved, &([_]u8{0xA5} ** 32), ""),
    );
    try std.testing.expectEqual(
        Status.ok,
        proof.acceptReceipt(
            1,
            "attempt-001",
            .proved,
            &([_]u8{0xA5} ** 32),
            &([_]u8{0x5A} ** 32),
        ),
    );
}
