// const std = @import("std");

// const glfw = @import("mach-glfw");

// const common = @import("common/common.zig");
// const logger = common.logger;

// const cmd_ecs = @import("cmd_ecs/cmd_ecs.zig");

// const path_tracer = @import("path_tracer/path_tracer.zig");
// const PathTracer = path_tracer.PathTracer;

// pub fn main() !void {
//     var app = PathTracer.instance();

//     app.run() catch |err| {
//         return err;
//     };
// }
// // pub fn main() !void {
// //     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

// //     glfw_init();

// //     const glfw_exts = glfw.getRequiredInstanceExtensions() orelse return blk: {
// //         const err = glfw.mustGetError();
// //         std.log.err("failed to get required vulkan instance extensions: error={s}", .{err.description});
// //         break :blk error.code;
// //     };

// //     var instance_extensions = try std.ArrayList([*:0]const u8).initCapacity(arena.allocator(), glfw_exts.len + 1);
// //     try instance_extensions.appendSlice(glfw_exts);

// //     _ = renderer.Renderer.init(&arena, instance_extensions);
// //     logger.info("Renderer created", .{});
// // }

// // fn error_callback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
// //     std.log.err("glfw: {}: {s}\n", .{ error_code, description });
// // }

// // pub fn glfw_init() void {
// //     glfw.setErrorCallback(error_callback);
// //     if (!glfw.init(.{})) {
// //         logger.err("Failed to initialize GLFW", .{});
// //         std.process.exit(1);
// //     }
// // }


const std = @import("std");

const glfw = @import("mach-glfw");
const vk = @import("vulkan");

const logger = @import("common/logger.zig");
const renderer = @import("renderer/renderer.zig");

const MAX_FRAMES_IN_FLIGHT: u32 = 2;

const InitError = error{
    CreateWindowSurfaceFailed,
    GLFWInitFailed,
};

pub const HelloTriangleApplication = struct {
    const Self = @This();

    renderer_context: renderer.renderer_context.RendererContext = undefined,
    logical_device: renderer.logical_device.LogicalDevice = undefined,
    render_target: renderer.render_target.RenderTarget = undefined,
    render_pass: renderer.render_pass.RenderPass = undefined,
    graphics_pipeline: renderer.pipeline.Pipeline = undefined,

    pub fn init(allocator: *std.mem.Allocator) !Self 
    {
        var app = Self{ };

        glfw.setErrorCallback(glfw_error_callback);
        if (!glfw.init(.{})) 
        {
            return error.GLFWInitFailed;
        }

        app.renderer_context = try renderer.renderer_context.RendererContext.create_renderer_context(allocator);

        const glfw_window = glfw.Window.create(800, 600, "Vulkan", null, null, .{ .client_api = .no_api, .resizable = false, }).?;        
        var surface: vk.SurfaceKHR = .null_handle;
        if (glfw.createWindowSurface(app.renderer_context.instance.handle, glfw_window, null, &surface) != @intFromEnum(vk.Result.success)) 
        {
            return InitError.CreateWindowSurfaceFailed;
        } 
        const physical_device = try app.pick_physical_device(allocator, surface);
        
        app.logical_device = try renderer.logical_device.LogicalDevice.create_logical_device(&app.renderer_context, allocator, physical_device);
        app.render_target = try renderer.render_target.RenderTarget.create_render_target(allocator, &app.logical_device, renderer.Window{ .glfw_window = glfw_window, .surface = surface });
        app.render_pass = try renderer.render_pass.RenderPass.create_render_pass(allocator, &app.render_target, &app.logical_device.vk_device);
        app.graphics_pipeline = try renderer.pipeline.Pipeline.create_pipeline(allocator, &app.logical_device, &app.render_pass);

        return app;
    }

    pub fn run(self: *Self) !void {        
        try self.mainLoop();
    }

    fn glfw_error_callback(error_code: glfw.ErrorCode, description: [:0]const u8) void
    {
        logger.err("glfw: {?}: {s}\n", .{ error_code, description });
    }

    fn mainLoop(self: *Self) !void {
        while (!self.render_target.window.glfw_window.shouldClose()) {
            glfw.pollEvents();
            try self.drawFrame();
        }

        _ = try self.logical_device.vk_device.deviceWaitIdle();
    }

    pub fn deinit(self: *Self, allocator: *std.mem.Allocator) void 
    {
        self.graphics_pipeline.deinit(&self.logical_device.vk_device);        
        self.render_pass.deinit(allocator, &self.logical_device.vk_device);
        self.render_target.deinit(allocator, &self.renderer_context.instance, &self.logical_device.vk_device);
        self.logical_device.deinit(allocator);
        self.renderer_context.deinit(allocator);                
        glfw.terminate();
    }

    fn pick_physical_device(self: *Self, allocator: *std.mem.Allocator, surface: vk.SurfaceKHR) !renderer.PhysicalDevice {
        var device_count: u32 = undefined;
        _ = try self.renderer_context.instance.enumeratePhysicalDevices( &device_count, null);

        if (device_count == 0) {
            return error.NoGPUsSupportVulkan;
        }

        const devices = try allocator.alloc(vk.PhysicalDevice, device_count);
        defer allocator.free(devices);
        _ = try self.renderer_context.instance.enumeratePhysicalDevices(&device_count, devices.ptr);

        for (devices) |device| {
            const result = try self.renderer_context.is_device_suitable(allocator, device, surface);
            if (result[0] == true)
            {
                return result[1];
            }
        }
        return error.NoSuitableDevice;
    }

    fn drawFrame(self: *Self) !void {
        _ = try self.logical_device.vk_device.waitForFences( 1, @ptrCast(&self.graphics_pipeline.in_flight_fence), vk.TRUE, std.math.maxInt(u64));
        try self.logical_device.vk_device.resetFences( 1, @ptrCast(&self.graphics_pipeline.in_flight_fence));

        const result = try self.logical_device.vk_device.acquireNextImageKHR( self.render_target.swapchain, std.math.maxInt(u64), self.graphics_pipeline.image_available_semaphore, .null_handle);

        try self.logical_device.vk_device.resetCommandBuffer(self.graphics_pipeline.command_buffer, .{});
        try self.graphics_pipeline.record_commandbuffer(&self.logical_device.vk_device, &self.render_pass, &self.render_target.extent, result.image_index);

        const wait_semaphores = [_]vk.Semaphore{self.graphics_pipeline.image_available_semaphore};
        const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        const signal_semaphores = [_]vk.Semaphore{self.graphics_pipeline.render_finished_semaphore};

        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = wait_semaphores.len,
            .p_wait_semaphores = &wait_semaphores,
            .p_wait_dst_stage_mask = &wait_stages,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&self.graphics_pipeline.command_buffer),
            .signal_semaphore_count = signal_semaphores.len,
            .p_signal_semaphores = &signal_semaphores,
        };
        _ = try self.logical_device.vk_device.queueSubmit(self.logical_device.queues.get(renderer.QueueType.Graphics).?.vk_queue, 1, &[_]vk.SubmitInfo{submit_info}, self.graphics_pipeline.in_flight_fence);

        _ = try self.logical_device.vk_device.queuePresentKHR(self.logical_device.queues.get(renderer.QueueType.Present).?.vk_queue, &.{
            .wait_semaphore_count = signal_semaphores.len,
            .p_wait_semaphores = &signal_semaphores,
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.render_target.swapchain),
            .p_image_indices = @ptrCast(&result.image_index),
            .p_results = null,
        });
    }
};