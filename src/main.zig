const std = @import("std");

const glfw = @import("mach-glfw");

const common = @import("common/common.zig");
const logger = common.logger;

const cmd_ecs = @import("cmd_ecs/cmd_ecs.zig");

const path_tracer = @import("path_tracer/path_tracer.zig");
const PathTracer = path_tracer.PathTracer;

pub fn main() !void {
    var app = PathTracer.instance();

    app.run() catch |err| {
        return err;
    };
}
// pub fn main() !void {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

//     glfw_init();

//     const glfw_exts = glfw.getRequiredInstanceExtensions() orelse return blk: {
//         const err = glfw.mustGetError();
//         std.log.err("failed to get required vulkan instance extensions: error={s}", .{err.description});
//         break :blk error.code;
//     };

//     var instance_extensions = try std.ArrayList([*:0]const u8).initCapacity(arena.allocator(), glfw_exts.len + 1);
//     try instance_extensions.appendSlice(glfw_exts);

//     _ = renderer.Renderer.init(&arena, instance_extensions);
//     logger.info("Renderer created", .{});
// }

// fn error_callback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
//     std.log.err("glfw: {}: {s}\n", .{ error_code, description });
// }

// pub fn glfw_init() void {
//     glfw.setErrorCallback(error_callback);
//     if (!glfw.init(.{})) {
//         logger.err("Failed to initialize GLFW", .{});
//         std.process.exit(1);
//     }
// }
