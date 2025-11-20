const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Note: Main executable build temporarily commented out due to libvaxis dependency issues
    // Uncomment when HTTP redirect issues are resolved
    // const exe = b.addExecutable(.{
    //     .name = "semantic-graph-tui",
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const libvaxis = b.dependency("libvaxis", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // exe.root_module.addImport("vaxis", libvaxis.module("vaxis"));
    // b.installArtifact(exe);

    // const run_cmd = b.addRunArtifact(exe);
    // run_cmd.step.dependOn(b.getInstallStep());

    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }

    // const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);

    // Test configuration
    const test_step = b.step("test", "Run unit tests");

    // Create modules for source files with proper dependencies
    const validation_module = b.createModule(.{
        .root_source_file = b.path("src/validation.zig"),
    });

    const graph_module = b.createModule(.{
        .root_source_file = b.path("src/graph.zig"),
    });
    graph_module.addImport("validation", validation_module);

    const llm_module = b.createModule(.{
        .root_source_file = b.path("src/llm.zig"),
    });
    llm_module.addImport("graph", graph_module);

    const analysis_service_module = b.createModule(.{
        .root_source_file = b.path("src/analysis_service.zig"),
    });
    analysis_service_module.addImport("graph", graph_module);
    analysis_service_module.addImport("llm", llm_module);

    const ui_module = b.createModule(.{
        .root_source_file = b.path("src/ui.zig"),
    });
    ui_module.addImport("graph", graph_module);
    ui_module.addImport("llm", llm_module);
    ui_module.addImport("validation", validation_module);
    ui_module.addImport("analysis_service", analysis_service_module);

    // Graph module tests
    const graph_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit/graph_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    graph_tests.root_module.addImport("graph", graph_module);
    graph_tests.root_module.addImport("validation", validation_module);
    const run_graph_tests = b.addRunArtifact(graph_tests);
    test_step.dependOn(&run_graph_tests.step);

    // LLM module tests
    const llm_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit/llm_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    llm_tests.root_module.addImport("llm", llm_module);
    llm_tests.root_module.addImport("graph", graph_module);
    llm_tests.root_module.addImport("validation", validation_module);
    const run_llm_tests = b.addRunArtifact(llm_tests);
    test_step.dependOn(&run_llm_tests.step);

    // UI module tests
    const ui_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit/ui_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    ui_tests.root_module.addImport("ui", ui_module);
    ui_tests.root_module.addImport("graph", graph_module);
    ui_tests.root_module.addImport("validation", validation_module);
    const run_ui_tests = b.addRunArtifact(ui_tests);
    test_step.dependOn(&run_ui_tests.step);

    // Architecture tests
    const arch_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit/architecture_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    arch_tests.root_module.addImport("graph", graph_module);
    arch_tests.root_module.addImport("llm", llm_module);
    arch_tests.root_module.addImport("ui", ui_module);
    arch_tests.root_module.addImport("validation", validation_module);
    arch_tests.root_module.addImport("analysis_service", analysis_service_module);
    const run_arch_tests = b.addRunArtifact(arch_tests);
    test_step.dependOn(&run_arch_tests.step);

    // Integration tests
    const integration_tests = b.addTest(.{
        .root_source_file = b.path("tests/integration/workflow_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_tests.root_module.addImport("graph", graph_module);
    integration_tests.root_module.addImport("llm", llm_module);
    integration_tests.root_module.addImport("analysis_service", analysis_service_module);
    integration_tests.root_module.addImport("validation", validation_module);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    test_step.dependOn(&run_integration_tests.step);
}
