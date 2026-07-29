// SPDX-License-Identifier: PMPL-2.0-or-later
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addModule("sim_insolvency", .{
        .root_source_file = b.path("zig/src/kernel.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "sim-insolvency",
        .root_module = b.createModule(.{
            .root_source_file = b.path("zig/src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "sim_insolvency", .module = kernel }},
        }),
    });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run the local assessment shell");
    run_step.dependOn(&run.step);

    const unit_tests = b.addTest(.{ .root_module = kernel });
    const run_unit = b.addRunArtifact(unit_tests);
    const port_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("zig/src/ports.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_ports = b.addRunArtifact(port_tests);
    const test_step = b.step("test", "Run kernel, scenario, replay and certificate tests");
    test_step.dependOn(&run_unit.step);
    test_step.dependOn(&run_ports.step);

    const wasm = b.addExecutable(.{
        .name = "sim_insolvency_kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("zig/src/wasm.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
                .abi = .none,
            }),
            .optimize = optimize,
            .imports = &.{.{ .name = "sim_insolvency", .module = kernel }},
        }),
    });
    wasm.entry = .disabled;
    const install_wasm = b.addInstallArtifact(wasm, .{});
    const wasm_step = b.step("wasm", "Build the explicitly untyped wasm fallback");
    wasm_step.dependOn(&install_wasm.step);
}
