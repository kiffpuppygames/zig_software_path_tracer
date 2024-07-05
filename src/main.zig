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

const WIDTH: u32 = 800;
const HEIGHT: u32 = 600;

const MAX_FRAMES_IN_FLIGHT: u32 = 2;

const InitError = error{
    CreateWindowSurfaceFailed,
    GLFWInitFailed,
};

const HelloTriangleApplication = struct {
    const Self = @This();

    renderer_context: renderer.renderer_context.RendererContext = undefined,
    logical_device: renderer.logical_device.LogicalDevice = undefined,
    render_target: renderer.render_target.RenderTarget = undefined,
    
    swap_chain_framebuffers: ?[]vk.Framebuffer = null,
    render_pass: vk.RenderPass = .null_handle,
    
    pipeline_layout: vk.PipelineLayout = .null_handle,
    graphics_pipeline: vk.Pipeline = .null_handle,

    command_pool: vk.CommandPool = .null_handle,
    command_buffer: vk.CommandBuffer = .null_handle,

    image_available_semaphore: vk.Semaphore = .null_handle,
    render_finished_semaphore: vk.Semaphore = .null_handle,
    in_flight_fence: vk.Fence = .null_handle,

    pub fn init(allocator: *std.mem.Allocator) !Self 
    {
        var app = Self{ };

        glfw.setErrorCallback(glfw_error_callback);
        if (!glfw.init(.{})) 
        {
            return error.GLFWInitFailed;
        }

        app.renderer_context = try renderer.renderer_context.RendererContext.create_renderer_context(allocator);
        
        const glfw_window = glfw.Window.create(WIDTH, HEIGHT, "Vulkan", null, null, .{ .client_api = .no_api, .resizable = false, }).?;
        
        var surface: vk.SurfaceKHR = .null_handle;
        if (glfw.createWindowSurface(app.renderer_context.instance.handle, glfw_window, null, &surface) != @intFromEnum(vk.Result.success)) 
        {
            return InitError.CreateWindowSurfaceFailed;
        }

        const pick_device_result = try app.pick_physical_device(allocator, surface);
        app.logical_device = try renderer.logical_device.LogicalDevice.create_logical_device(&app.renderer_context, allocator, pick_device_result[0], pick_device_result[1], surface);

        app.render_target = try renderer.render_target.RenderTarget.create_render_target(allocator, &app.renderer_context, &app.logical_device, renderer.Window{ .glfw_window = glfw_window, .surface = surface });

        try app.createRenderPass();
        try app.createGraphicsPipeline();
        try app.createFramebuffers(allocator);
        try app.createCommandPool(allocator);
        try app.createCommandBuffer();
        try app.createSyncObjects();

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

    pub fn deinit(self: *Self, allocator: *std.mem.Allocator) void {
        if (self.render_finished_semaphore != .null_handle) self.logical_device.vk_device.destroySemaphore( self.render_finished_semaphore, null);
        if (self.image_available_semaphore != .null_handle) self.logical_device.vk_device.destroySemaphore( self.image_available_semaphore, null);
        if (self.in_flight_fence != .null_handle) self.logical_device.vk_device.destroyFence( self.in_flight_fence, null);

        if (self.command_pool != .null_handle) self.logical_device.vk_device.destroyCommandPool( self.command_pool, null);

        if (self.swap_chain_framebuffers != null) {
            for (self.swap_chain_framebuffers.?) |framebuffer| {
                self.logical_device.vk_device.destroyFramebuffer( framebuffer, null);
            }
            allocator.free(self.swap_chain_framebuffers.?);
        }

        if (self.graphics_pipeline != .null_handle) self.logical_device.vk_device.destroyPipeline( self.graphics_pipeline, null);
        if (self.pipeline_layout != .null_handle) self.logical_device.vk_device.destroyPipelineLayout( self.pipeline_layout, null);
        if (self.render_pass != .null_handle) self.logical_device.vk_device.destroyRenderPass( self.render_pass, null);

        for (self.render_target.image_views) |image_view| 
        {
            self.logical_device.vk_device.destroyImageView( image_view, null);
        }
        allocator.free(self.render_target.image_views);

        allocator.free(self.render_target.images);
        if (self.render_target.swapchain != .null_handle) self.logical_device.vk_device.destroySwapchainKHR( self.render_target.swapchain, null);
        
        self.renderer_context.instance.destroySurfaceKHR(self.render_target.window.surface, null);
        self.render_target.window.glfw_window.destroy();
        self.logical_device.deinit(allocator);
        self.renderer_context.deinit(allocator);
                
        glfw.terminate();
    }

    fn pick_physical_device(self: *Self, allocator: *std.mem.Allocator, surface: vk.SurfaceKHR) !struct { vk.PhysicalDevice, renderer.SwapChainSupportDetails } {
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
                return .{ device, result[1] };
            }
        }
        return error.NoSuitableDevice;
    }

    fn createRenderPass(self: *Self) !void {
        const color_attachment = [_]vk.AttachmentDescription{.{
            .flags = .{},
            .format = self.render_target.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .@"undefined",
            .final_layout = .present_src_khr,
        }};

        const color_attachment_ref = [_]vk.AttachmentReference{.{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        }};

        const subpass = [_]vk.SubpassDescription{.{
            .flags = .{},
            .pipeline_bind_point = .graphics,
            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .color_attachment_count = color_attachment_ref.len,
            .p_color_attachments = &color_attachment_ref,
            .p_resolve_attachments = null,
            .p_depth_stencil_attachment = null,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        }};

        const dependencies = [_]vk.SubpassDependency{.{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true },
            .dependency_flags = .{},
        }};

        self.render_pass = try self.logical_device.vk_device.createRenderPass( &.{
            .flags = .{},
            .attachment_count = color_attachment.len,
            .p_attachments = &color_attachment,
            .subpass_count = subpass.len,
            .p_subpasses = &subpass,
            .dependency_count = dependencies.len,
            .p_dependencies = &dependencies,
        }, null);
    }

    fn createGraphicsPipeline(self: *Self) !void 
    {
        const vert_shader_code align(4) = @embedFile("shaders/vert.spv").*;
        const vert_shader_module: vk.ShaderModule = self.create_shader_module(&vert_shader_code);
        defer self.logical_device.vk_device.destroyShaderModule( vert_shader_module, null);

        const frag_shader_code align(4) = @embedFile("shaders/frag.spv").*;
        const frag_shader_module: vk.ShaderModule = self.create_shader_module(&frag_shader_code);
        defer self.logical_device.vk_device.destroyShaderModule( frag_shader_module, null);

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .flags = .{},
                .stage = .{ .vertex_bit = true },
                .module = vert_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .flags = .{},
                .stage = .{ .fragment_bit = true },
                .module = frag_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
        };

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .flags = .{},
            .vertex_binding_description_count = 0,
            .p_vertex_binding_descriptions = undefined,
            .vertex_attribute_description_count = 0,
            .p_vertex_attribute_descriptions = undefined,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .flags = .{},
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = undefined,
            .scissor_count = 1,
            .p_scissors = undefined,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .flags = .{},
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true },
            .front_face = .clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .flags = .{},
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 1,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const color_blend_attachment = [_]vk.PipelineColorBlendAttachmentState{.{
            .blend_enable = vk.FALSE,
            .src_color_blend_factor = .one,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        }};

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .flags = .{},
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = color_blend_attachment.len,
            .p_attachments = &color_blend_attachment,
            .blend_constants = [_]f32{ 0, 0, 0, 0 },
        };
        const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .flags = .{},
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        self.pipeline_layout = try self.logical_device.vk_device.createPipelineLayout( &.{
            .flags = .{},
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        }, null);

        const pipeline_info = [_]vk.GraphicsPipelineCreateInfo{.{
            .flags = .{},
            .stage_count = shader_stages.len,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_info,
            .p_input_assembly_state = &input_assembly,
            .p_tessellation_state = null,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterizer,
            .p_multisample_state = &multisampling,
            .p_depth_stencil_state = null,
            .p_color_blend_state = &color_blending,
            .p_dynamic_state = &dynamic_state,
            .layout = self.pipeline_layout,
            .render_pass = self.render_pass,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        }};

        _ = try self.logical_device.vk_device.createGraphicsPipelines(
            .null_handle,
            pipeline_info.len,
            &pipeline_info,
            null,
            @ptrCast(&self.graphics_pipeline),
        );
    }

    fn createFramebuffers(self: *Self, allocator: *std.mem.Allocator) !void {
        self.swap_chain_framebuffers = try allocator.alloc(vk.Framebuffer, self.render_target.image_views.len);

        for (self.swap_chain_framebuffers.?, 0..) |*framebuffer, i| {
            const attachments = [_]vk.ImageView{self.render_target.image_views[i]};

            framebuffer.* = try self.logical_device.vk_device.createFramebuffer( &.{
                .flags = .{},
                .render_pass = self.render_pass,
                .attachment_count = attachments.len,
                .p_attachments = &attachments,
                .width = self.render_target.extent.width,
                .height = self.render_target.extent.height,
                .layers = 1,
            }, null);
        }
    }

    fn createCommandPool(self: *Self, allocator: *std.mem.Allocator) !void 
    {
        const queue_family_indices = try renderer.find_queue_families(&self.renderer_context.instance, allocator, self.logical_device.physical_device, self.render_target.window.surface);

        self.command_pool = try self.logical_device.vk_device.createCommandPool( &.{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = queue_family_indices.graphics_family.?,
        }, null);
    }

    fn createCommandBuffer(self: *Self) !void {
        try self.logical_device.vk_device.allocateCommandBuffers( &.{
            .command_pool = self.command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        }, @ptrCast(&self.command_buffer));
    }

    fn recordCommandBuffer(self: *Self, command_buffer: vk.CommandBuffer, image_index: u32) !void {
        try self.logical_device.vk_device.beginCommandBuffer(command_buffer, &.{
            .flags = .{},
            .p_inheritance_info = null,
        });

        const clear_values = [_]vk.ClearValue{.{
            .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
        }};

        const render_pass_info = vk.RenderPassBeginInfo{
            .render_pass = self.render_pass,
            .framebuffer = self.swap_chain_framebuffers.?[image_index],
            .render_area = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.render_target.extent,
            },  
            .clear_value_count = clear_values.len,
            .p_clear_values = &clear_values,
        };

        self.logical_device.vk_device.cmdBeginRenderPass(command_buffer, &render_pass_info, .@"inline");
        {
            self.logical_device.vk_device.cmdBindPipeline(command_buffer, .graphics, self.graphics_pipeline);

            const viewports = [_]vk.Viewport{.{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(self.render_target.extent.width),
                .height = @floatFromInt(self.render_target.extent.height),
                .min_depth = 0,
                .max_depth = 1,
            }};
            self.logical_device.vk_device.cmdSetViewport(command_buffer, 0, viewports.len, &viewports);

            const scissors = [_]vk.Rect2D{.{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.render_target.extent,
            }};
            self.logical_device.vk_device.cmdSetScissor(command_buffer, 0, scissors.len, &scissors);

            self.logical_device.vk_device.cmdDraw(command_buffer, 3, 1, 0, 0);
        }
        self.logical_device.vk_device.cmdEndRenderPass(command_buffer);

        try self.logical_device.vk_device.endCommandBuffer(command_buffer);
    }

    fn createSyncObjects(self: *Self) !void {
        self.image_available_semaphore = try self.logical_device.vk_device.createSemaphore( &.{ .flags = .{} }, null);
        self.render_finished_semaphore = try self.logical_device.vk_device.createSemaphore( &.{ .flags = .{} }, null);
        self.in_flight_fence = try self.logical_device.vk_device.createFence( &.{ .flags = .{ .signaled_bit = true } }, null);
    }

    fn drawFrame(self: *Self) !void {
        _ = try self.logical_device.vk_device.waitForFences( 1, @ptrCast(&self.in_flight_fence), vk.TRUE, std.math.maxInt(u64));
        try self.logical_device.vk_device.resetFences( 1, @ptrCast(&self.in_flight_fence));

        const result = try self.logical_device.vk_device.acquireNextImageKHR( self.render_target.swapchain, std.math.maxInt(u64), self.image_available_semaphore, .null_handle);

        try self.logical_device.vk_device.resetCommandBuffer(self.command_buffer, .{});
        try self.recordCommandBuffer(self.command_buffer, result.image_index);

        const wait_semaphores = [_]vk.Semaphore{self.image_available_semaphore};
        const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        const signal_semaphores = [_]vk.Semaphore{self.render_finished_semaphore};

        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = wait_semaphores.len,
            .p_wait_semaphores = &wait_semaphores,
            .p_wait_dst_stage_mask = &wait_stages,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&self.command_buffer),
            .signal_semaphore_count = signal_semaphores.len,
            .p_signal_semaphores = &signal_semaphores,
        };
        _ = try self.logical_device.vk_device.queueSubmit(self.logical_device.graphics_queue.vk_queue, 1, &[_]vk.SubmitInfo{submit_info}, self.in_flight_fence);

        _ = try self.logical_device.vk_device.queuePresentKHR(self.logical_device.present_queue.vk_queue, &.{
            .wait_semaphore_count = signal_semaphores.len,
            .p_wait_semaphores = &signal_semaphores,
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.render_target.swapchain),
            .p_image_indices = @ptrCast(&result.image_index),
            .p_results = null,
        });
    }

    fn create_shader_module(self: *Self, code: []align(@alignOf(u32)) const u8) vk.ShaderModule {
        
        const vert_mod_create_info = vk.ShaderModuleCreateInfo {
            .code_size = code.len,
            .p_code = std.mem.bytesAsSlice(u32, code).ptr,
        };
        const vert_shader_mod: vk.ShaderModule = self.logical_device.vk_device.createShaderModule( &vert_mod_create_info, null) catch unreachable;
        return vert_shader_mod;
    }

    
};

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == std.heap.Check.leak) logger.err("MemLeak", .{});
    }
    const allocator = gpa.allocator();

    var app = HelloTriangleApplication.init(@constCast(&allocator)) catch |err| {
        logger.err("application exited with error: {any}", .{err});
        return;
    };
    defer app.deinit(@constCast(&allocator));
    
    app.run() catch |err| {
        std.log.err("application exited with error: {any}", .{err});
        return;
    };
}