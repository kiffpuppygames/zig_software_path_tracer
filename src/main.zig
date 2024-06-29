const std = @import("std");
const glfw = @import("mach-glfw");

const cmd_ecs = @import("cmd_ecs/cmd_ecs.zig");
const common = @import("common/common.zig");

const path_tracer = @import("path_tracer/path_tracer.zig");
const PathTracer = path_tracer.PathTracer;

pub fn main() !void {
    var app = PathTracer.instance();

    app.run() catch |err| {
        return err;
    };
}
