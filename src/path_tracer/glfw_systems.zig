const std = @import("std");
const glfw = @import("mach-glfw");

const common = @import("../common/common.zig");
const logger = common.logger;

pub const CmdCreateWindow = struct {
    id: u64,
    width: i32,
    height: i32,
    title: [:0]const u8,
};

pub const CreateWindowSystem = struct
{
    cmd_create_window_queue: std.ArrayList(CmdCreateWindow),

    pub fn run(self: *CreateWindowSystem) void 
    {
        for (self.cmd_create_window_queue.items) |value| 
        {
            _ = value; // autofix
            _ = glfw.Window.create(640, 480, "Hello, mach-glfw!", null, null, .{}) orelse 
            {
                logger.err("failed to create GLFW window: {?s}", .{ glfw.getErrorString() });
            };
        }
        self.cmd_create_window_queue.clearRetainingCapacity();
    }
};

fn error_callback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn glfw_init() void {
    glfw.setErrorCallback(error_callback);
    if (!glfw.init(.{})) {
        logger.err("Failed to initialize GLFW", .{});
        std.process.exit(1);
    }
    logger.info("Initialized GLFW", .{});
}