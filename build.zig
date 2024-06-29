const std = @import("std");
pub fn build(b: *std.Build) void 
{    
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // b.add
   
    // const common = b.addModule("common", .{ 
    //     .root_source_file = b.path("src/common/common.zig"),
    //     .target = target,
    //     .optimize = optimize});

    // var cmd_ecs = b.addModule("cmd_ecs", .{ 
    //     .root_source_file = b.path("src/cmd_ecs/cmd_ecs.zig"),
    //     .target = target,
    //     .optimize = optimize});
    // cmd_ecs.addImport("common", common);
   
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    // var cmd_ecs_tests = b.addTest(.{
    //     .root_source_file = b.path("src/cmd_ecs/tests.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // cmd_ecs_tests.root_module.addImport("common", common);
    // cmd_ecs_tests.root_module.addImport("cmd_ecs", cmd_ecs);
    // var run_cmd_ecs_tests = b.addRunArtifact(cmd_ecs_tests);
    // run_cmd_ecs_tests.addPackagePath("cmd_ecs", "cmd_ecs/cmd_ecs.zig");

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // exe.root_module.addImport("common", common);
    // exe.root_module.addImport("cmd_ecs", cmd_ecs);
    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    var test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
    //test_step.dependOn(&run_cmd_ecs_tests.step);
}