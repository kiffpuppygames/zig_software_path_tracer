const std = @import("std");

const glfw = @import("mach-glfw");

const common = @import("common/common.zig");
const logger = common.logger;

const hello_triangle_app = @import("hello_triangle_app.zig");
const path_tracer_app = @import("path_tracer_app.zig");

pub fn main() void 
{   
    //run_hello_triangle_app(allocator);
    run_cpu_path_tracer();
}

fn run_cpu_path_tracer() void 
{
    logger.debug("App Start", .{});
    var app = path_tracer_app.PathTracerApp.init(1920, 16.0 / 9.0) catch |err| 
    {
        logger.err("application exited with error: {any}", .{err});
        return;
    };
    defer app.deinit();
    
    app.run() catch |err| 
    {
        logger.err("application exited with error: {any}", .{err});
        return;
    };
}

fn run_hello_triangle_app(allocator: *std.mem.Allocator) void 
{
    var app = hello_triangle_app.HelloTriangleApplication.init(&allocator) catch |err| 
    {
        logger.err("application exited with error: {any}", .{err});
        return;
    };
    defer app.deinit(&allocator);
    
    app.run() catch |err| 
    {
        logger.err("application exited with error: {any}", .{err});
        return;
    };
}