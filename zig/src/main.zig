// SPDX-License-Identifier: PMPL-2.0-or-later
const std = @import("std");
const sim = @import("sim_insolvency");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const command = if (args.len > 1) args[1] else "home";
    if (std.mem.eql(u8, command, "home") or std.mem.eql(u8, command, "run")) {
        showHome();
        return;
    }
    if (std.mem.eql(u8, command, "golden")) {
        try showGolden();
        return;
    }
    if (std.mem.eql(u8, command, "demo")) {
        const branch = if (args.len > 2) args[2] else "cvl";
        const run: sim.GoldenRun = if (std.mem.eql(u8, branch, "administration"))
            .administration_competent_standard
        else
            .cvl_competent_standard;
        try showOutcome(try sim.runGolden(run));
        return;
    }
    if (std.mem.eql(u8, command, "group-demo")) {
        try showOutcome(try sim.runGolden(.group_session_with_dissent));
        return;
    }
    if (std.mem.eql(u8, command, "certificate")) {
        const learner = if (args.len > 2) args[2] else "learner-pseudonym";
        try showCertificate(init.io, learner, certificateKey(init));
        return;
    }
    if (std.mem.eql(u8, command, "verify-digest")) {
        if (args.len != 5) {
            std.debug.print("Use: verify-digest <certificate-digest-hex> <signature-hex> <key>\n", .{});
            std.process.exit(2);
        }
        if (!verifyDigest(args[2], args[3], args[4])) std.process.exit(1);
        try std.Io.File.stdout().writeStreamingAll(init.io, "VALID development certificate signature\n");
        return;
    }
    if (std.mem.eql(u8, command, "verify-certificate")) {
        if (args.len != 4 or !try verifyCertificateFile(init, args[2], args[3]))
            std.process.exit(1);
        try std.Io.File.stdout().writeStreamingAll(init.io, "VALID certificate envelope\n");
        return;
    }
    std.debug.print("Unknown command: {s}\nUse: home | demo [cvl|administration] | golden | group-demo | certificate [learner] | verify-certificate <file> <key>\n", .{command});
    std.process.exit(2);
}

fn showHome() void {
    std.debug.print(
        \\SIMULATION — NOT LEGAL ADVICE OR A PROFESSIONAL QUALIFICATION
        \\
        \\Sim Insolvency — Phase A local assessment shell
        \\Scenario: Morrow Engineering Ltd ({s})
        \\Jurisdiction: England and Wales / corporate insolvency
        \\Authority cut-off: {s}
        \\Rule pack: {s} {s} — PROVISIONAL/UNREVIEWED
        \\
        \\Commands:
        \\  zig-out/bin/sim-insolvency demo cvl
        \\  zig-out/bin/sim-insolvency demo administration
        \\  zig-out/bin/sim-insolvency group-demo
        \\  zig-out/bin/sim-insolvency golden
        \\  zig-out/bin/sim-insolvency certificate learner-pseudonym
        \\
        \\The executable slice records evidence requests, beliefs, risks,
        \\procedure comparison, concurrent workstreams, appointments, asset and
        \\record protection, investigation, assessment, consequences and a
        \\tamper-evident certificate envelope.
        \\
    , .{ sim.scenario_id, sim.authority_cut_off, sim.rule_pack_id, sim.rule_pack_version });
}

const CertificateKey = struct {
    key: []const u8,
    id: []const u8,
};

fn certificateKey(init: std.process.Init) CertificateKey {
    if (init.environ_map.get("SIM_INSOLVENCY_CERT_KEY")) |key| {
        if (key.len > 0) return .{ .key = key, .id = "operator-supplied" };
    }
    return .{
        .key = "phase-a-development-key-not-for-production",
        .id = "phase-a-development",
    };
}

fn showCertificate(io: std.Io, learner: []const u8, cert_key: CertificateKey) !void {
    const outcome = try sim.runGolden(.cvl_competent_standard);
    const certificate = try sim.certificateForOutcome(outcome, learner, cert_key.key);
    const ledger_hex = std.fmt.bytesToHex(certificate.ledger_digest, .lower);
    const certificate_hex = std.fmt.bytesToHex(certificate.certificate_digest, .lower);
    const signature_hex = std.fmt.bytesToHex(certificate.signature, .lower);
    var buffer: [4096]u8 = undefined;
    const text = try std.fmt.bufPrint(&buffer,
        \\# SIMULATION — CERTIFICATE OF COMPLETION AND ASSESSED PERFORMANCE
        \\schema = 1
        \\learner = "{s}"
        \\scenario = "{s}"
        \\scenario-version = "{s}"
        \\rule-pack = "{s}@{s}"
        \\authority-cut-off = "{s}"
        \\rubric-version = "{s}"
        \\application-version = "{s}"
        \\result-class = "{s}"
        \\critical-error = {}
        \\information-gathering = {d}
        \\procedure-comparison = {d}
        \\evidence-use = {d}
        \\uncertainty-handling = {d}
        \\prioritisation = {d}
        \\timeliness = {d}
        \\record-quality = {d}
        \\ethical-reasoning = {d}
        \\elapsed-minutes = {d}
        \\ledger-digest = "{s}"
        \\certificate-digest = "{s}"
        \\signature-algorithm = "HMAC-SHA-256-DEVELOPMENT-ONLY"
        \\key-id = "{s}"
        \\signature = "{s}"
        \\verify = "sim-insolvency verify-digest <certificate-digest> <signature> <trusted-key>"
        \\disclaimer = "{s}"
        \\
    , .{
        learner,
        sim.scenario_id,
        sim.scenario_version,
        sim.rule_pack_id,
        sim.rule_pack_version,
        sim.authority_cut_off,
        sim.rubric_version,
        sim.app_version,
        certificate.result_class,
        certificate.critical_error,
        outcome.result.information_gathering,
        outcome.result.procedure_comparison,
        outcome.result.evidence_use,
        outcome.result.uncertainty_handling,
        outcome.result.prioritisation,
        outcome.result.timeliness,
        outcome.result.record_quality,
        outcome.result.ethical_reasoning,
        outcome.consequence.elapsed_minutes,
        &ledger_hex,
        &certificate_hex,
        cert_key.id,
        &signature_hex,
        sim.disclaimer,
    });
    try std.Io.File.stdout().writeStreamingAll(io, text);
}

fn verifyDigest(digest_text: []const u8, signature_text: []const u8, key: []const u8) bool {
    if (digest_text.len != 64 or signature_text.len != 64 or key.len == 0) return false;
    var digest: [32]u8 = undefined;
    var signature: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&digest, digest_text) catch return false;
    _ = std.fmt.hexToBytes(&signature, signature_text) catch return false;
    const certificate: sim.Certificate = .{
        .result_class = "externally-parsed",
        .ledger_digest = sim.zero_digest,
        .certificate_digest = digest,
        .signature = signature,
        .critical_error = false,
    };
    return sim.verifyCertificate(certificate, key);
}

fn verifyCertificateFile(init: std.process.Init, path: []const u8, key: []const u8) !bool {
    const content = std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.arena.allocator(),
        .limited(64 * 1024),
    ) catch return false;
    const required = [_][]const u8{
        "scenario = \"morrow-engineering-001\"",
        "scenario-version = \"0.1.0\"",
        "rule-pack = \"england-wales-corporate-provisional@0.1.0\"",
        "authority-cut-off = \"2026-07-01\"",
        "rubric-version = \"0.1.0\"",
        "application-version = \"0.1.0-phase-a\"",
        "signature-algorithm = \"HMAC-SHA-256-DEVELOPMENT-ONLY\"",
        sim.disclaimer,
    };
    for (required) |needle| if (std.mem.indexOf(u8, content, needle) == null) return false;

    const learner = quotedValue(content, "learner") orelse return false;
    const digest_text = quotedValue(content, "certificate-digest") orelse return false;
    const signature_text = quotedValue(content, "signature") orelse return false;
    const ledger_text = quotedValue(content, "ledger-digest") orelse return false;
    var digest: [32]u8 = undefined;
    var signature: [32]u8 = undefined;
    var ledger: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&digest, digest_text) catch return false;
    _ = std.fmt.hexToBytes(&signature, signature_text) catch return false;
    _ = std.fmt.hexToBytes(&ledger, ledger_text) catch return false;

    const result: sim.CompetencyResult = .{
        .information_gathering = numberValue(content, "information-gathering") orelse return false,
        .procedure_comparison = numberValue(content, "procedure-comparison") orelse return false,
        .evidence_use = numberValue(content, "evidence-use") orelse return false,
        .uncertainty_handling = numberValue(content, "uncertainty-handling") orelse return false,
        .prioritisation = numberValue(content, "prioritisation") orelse return false,
        .timeliness = numberValue(content, "timeliness") orelse return false,
        .record_quality = numberValue(content, "record-quality") orelse return false,
        .ethical_reasoning = numberValue(content, "ethical-reasoning") orelse return false,
        .critical_error = std.mem.indexOf(u8, content, "critical-error = true") != null,
    };
    const computed = sim.certificateFromFields(ledger, result, learner, key) catch return false;
    return std.crypto.timing_safe.eql([32]u8, computed.certificate_digest, digest) and
        std.crypto.timing_safe.eql([32]u8, computed.signature, signature);
}

fn quotedValue(content: []const u8, name: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, name) or line.len <= name.len + 2 or
            !std.mem.eql(u8, line[name.len .. name.len + 3], " = ")) continue;
        const first = std.mem.indexOfScalar(u8, line, '"') orelse return null;
        const last = std.mem.lastIndexOfScalar(u8, line, '"') orelse return null;
        if (last <= first) return null;
        return line[first + 1 .. last];
    }
    return null;
}

fn numberValue(content: []const u8, name: []const u8) ?u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, name) or line.len <= name.len + 2 or
            !std.mem.eql(u8, line[name.len .. name.len + 3], " = ")) continue;
        const equals = std.mem.indexOfScalar(u8, line, '=') orelse return null;
        return std.fmt.parseInt(u8, std.mem.trim(u8, line[equals + 1 ..], " "), 10) catch null;
    }
    return null;
}

fn showGolden() !void {
    const runs = [_]sim.GoldenRun{
        .cvl_competent_standard,
        .cvl_competent_alternative,
        .administration_competent_standard,
        .administration_competent_alternative,
        .threshold_borderline,
        .critical_error,
        .deadline_failure,
        .group_session_with_dissent,
    };
    for (runs) |run| try showOutcome(try sim.runGolden(run));
}

fn showOutcome(outcome: sim.GoldenOutcome) !void {
    var digest_text: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&digest_text, "{x}", .{outcome.digest}) catch unreachable;
    std.debug.print(
        "{s}: events={d} threshold={} critical={} continuity={d} assets={d} digest={s}\n",
        .{
            @tagName(outcome.run),
            outcome.event_count,
            outcome.result.threshold(),
            outcome.result.critical_error,
            outcome.consequence.business_continuity,
            outcome.consequence.assets_preserved,
            &digest_text,
        },
    );
}
