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
    std.debug.print("Unknown command: {s}\nUse: home | demo [cvl|administration] | golden | group-demo\n", .{command});
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
        \\
        \\The executable slice records evidence requests, beliefs, risks,
        \\procedure comparison, concurrent workstreams, appointments, asset and
        \\record protection, investigation, assessment, consequences and a
        \\tamper-evident certificate envelope.
        \\
    , .{ sim.scenario_id, sim.authority_cut_off, sim.rule_pack_id, sim.rule_pack_version });
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
