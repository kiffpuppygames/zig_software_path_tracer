const std = @import("std");
const vkgen = @import("vulkan_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vkzig_dep = b.dependency("vulkan_zig", .{
        .registry = @as([]const u8, b.pathFromRoot("D:/Development/vulkan_sdk/latest/share/vulkan/registry/vk.xml")),
    });
    const vkzig_bindings = vkzig_dep.module("vulkan-zig");
    
    const glfw_dep = b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    });

    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });
    
    const zmath = b.dependency("zmath", .{});
    

    const lib = b.addStaticLibrary(.{
        .name = "path_tracer",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));
    lib.root_module.addImport("vulkan", vkzig_bindings);
    lib.linkLibC();
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "path_tracer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    
    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("zigimg", zigimg_dependency.module("zigimg"));
    exe.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));
    exe.root_module.addImport("vulkan", vkzig_bindings);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_unit_tests.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));
    lib_unit_tests.root_module.addImport("vulkan", vkzig_bindings);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    var test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
