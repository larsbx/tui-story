const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "semantic-graph-tui",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const libvaxis = b.dependency("libvaxis", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("vaxis", libvaxis.module("vaxis"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test configuration
    const test_step = b.step("test", "Run unit tests");

    // Graph module tests
    const graph_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit/graph_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_graph_tests = b.addRunArtifact(graph_tests);
    test_step.dependOn(&run_graph_tests.step);

    // LLM module tests
    const llm_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit/llm_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_llm_tests = b.addRunArtifact(llm_tests);
    test_step.dependOn(&run_llm_tests.step);

    // UI module tests
    const ui_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit/ui_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_ui_tests = b.addRunArtifact(ui_tests);
    test_step.dependOn(&run_ui_tests.step);
}
