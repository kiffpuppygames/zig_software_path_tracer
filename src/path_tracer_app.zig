const std = @import("std");

const zm = @import("zmath");
const glfw = @import("mach-glfw");
const vk = @import("vulkan");

const logger = @import("common/logger.zig");
const renderer = @import("renderer/renderer.zig");
const image_pipeline = @import("renderer/image_pipeline.zig");

const software_ray_tracer = @import("ray_tracing_in_a_weekend/software_ray_tracer.zig");

const MAX_FRAMES_IN_FLIGHT: u32 = 2;

const InitError = error{
    CreateWindowSurfaceFailed,
    GLFWInitFailed,
};

pub const PathTracerApp = struct {
    
    gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined,
    renderer_context: renderer.renderer_context.RendererContext = undefined,
    logical_device: renderer.logical_device.LogicalDevice = undefined,
    render_target: renderer.render_target.RenderTarget = undefined,
    render_pass: renderer.render_pass.RenderPass = undefined,
    graphics_pipeline: image_pipeline.ImagePipeline = undefined,
    width: u32 = 0,
    height: u32 = 0,
    aspect_ratio: f32 = 0.0,

    pub fn init(width: u32, aspect_ratio: f32) !PathTracerApp 
    {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();

        const f_width: f32 = @floatFromInt(width);

        const height: u32 = @intFromFloat( f_width / aspect_ratio);

        glfw.setErrorCallback(glfw_error_callback);
        if (!glfw.init(.{})) {
            return error.GLFWInitFailed;
        }

        const ctx = try renderer.renderer_context.RendererContext.create_renderer_context(&allocator);

        const glfw_window = glfw.Window.create(width, height, "Vulkan", null, null, .{
            .client_api = .no_api,
            .resizable = false,
        }).?;
        var surface: vk.SurfaceKHR = .null_handle;
        if (glfw.createWindowSurface(ctx.instance.handle, glfw_window, null, &surface) != @intFromEnum(vk.Result.success)) {
            return InitError.CreateWindowSurfaceFailed;
        }
        const physical_device = try pick_physical_device(&gpa.allocator(), &ctx, surface);

        const logical_device = try renderer.logical_device.LogicalDevice.create_logical_device(&ctx,&gpa.allocator(), physical_device);
        const render_target = try renderer.render_target.RenderTarget.create_render_target(&gpa.allocator(), &logical_device, renderer.Window{ .glfw_window = glfw_window, .surface = surface });
        const render_pass = try renderer.render_pass.RenderPass.create_render_pass(&gpa.allocator(), &render_target, &logical_device.vk_device);
        const graphics_pipeline = try image_pipeline.ImagePipeline.create_pipeline(&gpa.allocator(), &ctx, &logical_device, &render_target, &render_pass);

        return PathTracerApp
        {
            .gpa = gpa,
            .renderer_context = ctx,
            .logical_device = logical_device,
            .render_target = render_target,
            .render_pass = render_pass,
            .graphics_pipeline = graphics_pipeline,
            .width = width,
            .height = height,
            .aspect_ratio = aspect_ratio,
        };
    }

    pub fn run(self: *PathTracerApp) !void { 
        try self.mainLoop();
    }

    fn glfw_error_callback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
        logger.err("glfw: {?}: {s}\n", .{ error_code, description });
    }

    fn mainLoop(self: *PathTracerApp) !void 
    {
        var frame_counter: u32 = 0;

        var pathtracer = software_ray_tracer.SoftwarePathTracer.init(self.width, self.height, self.aspect_ratio, 1.0, zm.Vec { 0, 0, 0, 1 });
        const frame = try pathtracer.generate_frame(&self.gpa.allocator());
        defer frame.pixels.deinit(); 

        while (!self.render_target.window.glfw_window.shouldClose()) {
            glfw.pollEvents();
            try self.drawFrame(frame, frame_counter);
            frame_counter += 1;
        }

        _ = try self.logical_device.vk_device.deviceWaitIdle();
    }

    fn pick_physical_device(allocator: *const std.mem.Allocator, ctx: *const renderer.renderer_context.RendererContext, surface: vk.SurfaceKHR) !renderer.PhysicalDevice {
        var device_count: u32 = undefined;  
        _ = try ctx.instance.enumeratePhysicalDevices(&device_count, null);

        if (device_count == 0) {
            return error.NoGPUsSupportVulkan;
        }

        const devices = try allocator.alloc(vk.PhysicalDevice, device_count);
        defer allocator.free(devices);
        _ = try ctx.instance.enumeratePhysicalDevices(&device_count, devices.ptr);

        for (devices) |device| 
        {
            const result = try ctx.is_device_suitable(allocator, device, surface);
            if (result[0] == true) {
                return result[1];
            }
        }
        return error.NoSuitableDevice;
    }

    fn drawFrame(self: *PathTracerApp, frame: software_ray_tracer.Image, fame_counter: u32) !void 
    {
        _ = try self.logical_device.vk_device.waitForFences(1, @ptrCast(&self.graphics_pipeline.in_flight_fence), vk.TRUE, std.math.maxInt(u64));
        try self.logical_device.vk_device.resetFences(1, @ptrCast(&self.graphics_pipeline.in_flight_fence));

        const result = try self.logical_device.vk_device.acquireNextImageKHR(self.render_target.swapchain, std.math.maxInt(u64), self.graphics_pipeline.image_available_semaphore, .null_handle);

        try self.logical_device.vk_device.resetCommandBuffer (self.graphics_pipeline.command_buffers[0], .{});
        try self.graphics_pipeline.record_commandbuffer (
            &self.logical_device, 
            &self.render_target, 
            &self.render_pass, 
            frame, 
            fame_counter, 
            result.image_index );

        const wait_semaphores = [_]vk.Semaphore{self.graphics_pipeline.image_available_semaphore};
        const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        const signal_semaphores = [_]vk.Semaphore{self.graphics_pipeline.render_finished_semaphore};

        const submit_info = vk.SubmitInfo
        {
            .wait_semaphore_count = wait_semaphores.len,
            .p_wait_semaphores = &wait_semaphores,
            .p_wait_dst_stage_mask = &wait_stages,
            .command_buffer_count = 1,
            .p_command_buffers = self.graphics_pipeline.command_buffers.ptr,
            .signal_semaphore_count = signal_semaphores.len,
            .p_signal_semaphores = &signal_semaphores,
        };
        _ = try self.logical_device.vk_device.queueSubmit(self.logical_device.graphics_queue.vk_queue, 1, &[_]vk.SubmitInfo{ submit_info }, self.graphics_pipeline.in_flight_fence);

        _ = try self.logical_device.vk_device.queuePresentKHR(self.logical_device.graphics_queue.vk_queue, &.{
            .wait_semaphore_count = signal_semaphores.len,
            .p_wait_semaphores = &signal_semaphores,
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.render_target.swapchain),
            .p_image_indices = @ptrCast(&result.image_index),
            .p_results = null,
        });
    }

    pub fn deinit(self: *PathTracerApp) void 
    {
        defer 
        {
            const leaked = self.gpa.deinit();
            if (leaked == std.heap.Check.leak) logger.err("MemLeak", .{});
        }

        self.graphics_pipeline.deinit(&self.gpa.allocator(), &self.logical_device.vk_device);
        self.render_pass.deinit(@constCast(&self.gpa.allocator()), &self.logical_device.vk_device);
        self.render_target.deinit(@constCast(&self.gpa.allocator()), &self.renderer_context.instance, &self.logical_device.vk_device);
        self.logical_device.deinit(@constCast(&self.gpa.allocator()));
        self.renderer_context.deinit(@constCast(&self.gpa.allocator()));
        glfw.terminate();
    }
};
