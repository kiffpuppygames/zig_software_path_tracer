const std = @import("std");
const glfw = @import("mach-glfw");

const common = @import("../common/common.zig");
const cmd_ecs = @import("../cmd_ecs/cmd_ecs.zig");

const Pathtracer = @import("../path_tracer/path_tracer.zig").PathTracer;

const logger = common.logger;

pub const CmdCreateWindow = struct {
    id: u64,
    width: i32,
    height: i32,
    title: [:0]const u8,
};

pub const CmdCreateWindowComponent = struct {
    id: u64,
    window: glfw.Window,
};

pub const CmdExitApp = struct {
    id: u64,
};

pub const Window = struct {
    id: u64,
    window: *glfw.Window,
};

pub const WindowSystem = struct {
    cmd_create_window_queue: std.ArrayList(CmdCreateWindow),
    cmd_create_window_component_queue: std.ArrayList(CmdCreateWindowComponent),
    cmd_exit_app: std.ArrayList(CmdExitApp),
    id_provider: *cmd_ecs.id_provider.IdProvider,

    pub fn run(self: *WindowSystem) void {
        for (self.cmd_create_window_queue.items) |value| {
            
            const win = glfw.Window.create(@intCast(value.width), @intCast(value.height), value.title, null, null, .{ .client_api = .no_api}) orelse
                {                    
                logger.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
                std.process.exit(1);
            };
            self.cmd_create_window_component_queue.append(CmdCreateWindowComponent{ .id = self.id_provider.get_id(), .window = win }) catch unreachable;
        }
        self.cmd_create_window_queue.clearRetainingCapacity();
    }

    pub fn shutdown(self: *WindowSystem) void {
        self.cmd_create_window_component_queue.deinit();
        self.cmd_create_window_queue.deinit();
        self.cmd_exit_app.deinit();

        glfw.terminate();
    }
};

fn error_callback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    logger.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn glfw_init() void {
    glfw.setErrorCallback(error_callback);
    if (!glfw.init(.{})) {
        logger.err("Failed to initialize GLFW", .{});
        std.process.exit(1);
    }
}
