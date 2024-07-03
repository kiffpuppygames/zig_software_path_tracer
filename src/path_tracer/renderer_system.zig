const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("mach-glfw");

const logger = @import("../common/logger.zig");

const renderer_system = @import("renderer_system.zig");

const api = vk.ApiInfo{
    .base_commands = .{
        .createInstance = true,
        .getInstanceProcAddr = true,
    },
    .instance_commands = .{
        .destroyInstance = true,
        .enumeratePhysicalDevices = true,
        .getPhysicalDeviceProperties = true,
        .getPhysicalDeviceQueueFamilyProperties = true,
        .destroySurfaceKHR = true,   
        .getDeviceProcAddr = true,     
        .createDevice = true,
    },
    .device_commands = .{
        .destroyDevice = true,
        .getDeviceQueue = true,
        .createSwapchainKHR = true,
        .destroySwapchainKHR = true,
        .getSwapchainImagesKHR = true,
        .createImageView = true,
        .destroyImageView = true,    
        .createShaderModule = true,
        .destroyShaderModule = true,
        .createPipelineLayout = true,
        .destroyPipelineLayout = true,
        .createRenderPass = true,
        .destroyRenderPass = true,
        .createGraphicsPipelines = true,
        .destroyPipeline = true,
        .createFramebuffer = true,
        .destroyFramebuffer = true,
        .createCommandPool = true,
        .destroyCommandPool = true,
        .beginCommandBuffer = true,
        .cmdBeginRenderPass = true,
        .cmdBindPipeline = true,
        .cmdDraw = true,
        .cmdSetScissor = true,
        .cmdSetViewport = true,
        .endCommandBuffer = true,
        .allocateCommandBuffers = true,
        .cmdEndRenderPass = true,
        .createFence = true,
        .waitForFences = true,
        .resetFences = true,
        .createSemaphore = true,
        .acquireNextImageKHR = true,
        

        .createBuffer = true,
        .getBufferMemoryRequirements = true,
        .allocateMemory = true,
        .bindBufferMemory = true,
    }
};

const apis: []const vk.ApiInfo = &.{api};

const BaseDispatch = vk.BaseWrapper(apis);
const InstanceDispatch = vk.InstanceWrapper(apis);
const DeviceDispatch = vk.DeviceWrapper(apis);

pub const Instance = vk.InstanceProxy(apis);
pub const Device = vk.DeviceProxy(apis);

pub const CmdInitRenderer = struct {
    id: u64
};

pub const CmdCreateLogicalDevice = struct {
    id: u64
};

pub const CmdCreateRenderTarget = struct {
    id: u64,
    window: *glfw.Window,
};

pub const RendererContext = struct {
    arena: *std.heap.ArenaAllocator,
    vkb: BaseDispatch,
    instance: Instance,
    physical_devices: std.ArrayList(vk.PhysicalDevice),
};

pub const LogicalDevice = struct {
    device: Device,
    physical_device: vk.PhysicalDevice,
    graphics_queue: u8,
};

const RenderTarget = struct {
    surface: vk.SurfaceKHR,
    swapchain: vk.SwapchainKHR,
    images: std.ArrayList(vk.Image),
    image_views: std.ArrayList(vk.ImageView),
    format: vk.Format,
    extent: vk.Extent2D,
};

pub const RenderPassGroup = struct {
    render_pass: vk.RenderPass,
    framebuffers: std.ArrayList(vk.Framebuffer),

    pub fn init(allocator: std.mem.Allocator, device: *renderer_system.Device, format: vk.Format, views: *std.ArrayList(vk.ImageView)) RenderPassGroup
    {
        const color_attachment = [_]vk.AttachmentDescription{.{
            .flags = .{},
            .format = format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .dont_care, //Hmmm...
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

        const subpass_description = vk.SubpassDescription {
            .flags = .{},
            .pipeline_bind_point = .graphics,
            .input_attachment_count = 0,
            .p_input_attachments = null,
            .color_attachment_count = color_attachment_ref.len,
            .p_color_attachments = &color_attachment_ref,
            .p_resolve_attachments = null,
            .p_depth_stencil_attachment = null,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = null,
        };
        const sub_pass_descriptions = [1]vk.SubpassDescription{ subpass_description };

        const render_pass_info = vk.RenderPassCreateInfo {
            .attachment_count = color_attachment.len,
            .p_attachments = &color_attachment,
            .subpass_count = sub_pass_descriptions.len,
            .p_subpasses = &sub_pass_descriptions,
            .dependency_count = 0,
            .p_dependencies = null,
        };

        const render_pass = device.createRenderPass(&render_pass_info, null) catch unreachable;

        var framebuffers = std.ArrayList(vk.Framebuffer).init(allocator);
        for (views.items) |view, | 
        {
            const attachments = [_]vk.ImageView{ view };

            const framebuffer_info = vk.FramebufferCreateInfo {
                .flags = .{},
                .render_pass = render_pass,
                .attachment_count = 1,
                .p_attachments = &attachments,
                .width = 800,
                .height = 600,
                .layers = 1,
            };

            const framebuffer = device.createFramebuffer(&framebuffer_info, null) catch unreachable;
            framebuffers.append(framebuffer) catch unreachable;
        }

        return RenderPassGroup {
            .render_pass = render_pass,
            .framebuffers = framebuffers,
        };
    }
};

pub const Renderer = struct {
    context: ?RendererContext,
    logical_device: ?LogicalDevice,
    render_target: ?RenderTarget,
    create_logical_device_cmd_queue: std.ArrayList(CmdCreateLogicalDevice),
    create_render_target_cmd_queue: std.ArrayList(CmdCreateRenderTarget), 

    pub fn init(alloc: *std.heap.ArenaAllocator) Renderer 
    {
        const glfw_exts = glfw.getRequiredInstanceExtensions();
        var instance_extensions = std.ArrayList([*:0]const u8).initCapacity(alloc.allocator(), glfw_exts.?.len + 1) catch unreachable;
        instance_extensions.appendSlice(glfw_exts.?) catch unreachable;

        instance_extensions.append("VK_EXT_debug_utils") catch unreachable;

        var vkb = BaseDispatch.load(@as(vk.PfnGetInstanceProcAddr, @ptrCast(&glfw.getInstanceProcAddress))) catch unreachable;

        const debug_create_info = vk.DebugUtilsMessengerCreateInfoEXT { 
            .flags = .{}, 
            .message_severity = .{ 
                .verbose_bit_ext = true, 
                .warning_bit_ext = true, 
                .error_bit_ext = true }, 
                .message_type = .{
                    .general_bit_ext = true,
                    .validation_bit_ext = true,
                    .performance_bit_ext = true,
                }, 
            .pfn_user_callback = debug_callback, 
            .p_user_data = null 
        };

        const app_info = vk.ApplicationInfo { 
            .p_application_name = "Path Tracer", 
            .application_version = vk.makeApiVersion(0, 0, 0, 0), 
            .p_engine_name = "Path Tracer", 
            .engine_version = vk.makeApiVersion(0, 0, 0, 0), 
            .api_version = vk.API_VERSION_1_3, 
        };

        const layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

        const _instance = vkb.createInstance(&.{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(instance_extensions.items.len),
            .pp_enabled_extension_names = instance_extensions.items.ptr,
            .enabled_layer_count = @intCast(layers.len),
            .pp_enabled_layer_names = &layers,
            .p_next = &debug_create_info,
        }, null) catch unreachable;

        const vki = alloc.allocator().create(InstanceDispatch) catch unreachable;
        vki.* = InstanceDispatch.load(_instance, vkb.dispatch.vkGetInstanceProcAddr) catch unreachable;
        var instance = Instance.init(_instance, vki);
        const physical_devices = instance.enumeratePhysicalDevicesAlloc(alloc.allocator()) catch unreachable;

        var device_list = std.ArrayList(vk.PhysicalDevice).init(alloc.allocator());
        device_list.appendSlice(physical_devices) catch unreachable;

        return Renderer {
            .context = RendererContext{ 
                .arena = alloc, 
                .vkb = vkb, 
                .instance = instance, 
                .physical_devices = device_list },
            .logical_device = null,
            .create_logical_device_cmd_queue = std.ArrayList(CmdCreateLogicalDevice).init(alloc.allocator()),
            .create_render_target_cmd_queue = std.ArrayList(CmdCreateRenderTarget).init(alloc.allocator()),
            .render_target = null,
        };
    }

    pub fn draw_frame(self: *Renderer, command_buffer: vk.CommandBuffer,  inflight_fence: vk.Fence, image_available_semaphore: vk.Semaphore, render_finished_semaphore: vk.Semaphore) void
    {
        _ = render_finished_semaphore; // autofix
        _ = self.logical_device.?.device.waitForFences(1, @ptrCast(&inflight_fence), vk.TRUE, std.math.maxInt(u64)) catch unreachable;
        self.logical_device.?.device.resetFences(1, @ptrCast(&inflight_fence)) catch unreachable;

        const result = self.logical_device.?.device.acquireNextImageKHR(self.render_target.?.swapchain, std.math.maxInt(u64), image_available_semaphore, .null_handle) catch unreachable;

        self.logical_device.?.device.resetCommandBuffer(command_buffer, .{}) catch unreachable;
        self.logical_device.?.device.recordCommandBuffer(command_buffer, result.image_index) catch unreachable;

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
        _ = try self.vkd.queueSubmit(self.graphics_queue, 1, &[_]vk.SubmitInfo{submit_info}, self.in_flight_fence) catch unreachable;

        _ = try self.vkd.queuePresentKHR(self.present_queue, &.{
            .wait_semaphore_count = signal_semaphores.len,
            .p_wait_semaphores = &signal_semaphores,
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.render_target.?.swap_chain),
            .p_image_indices = @ptrCast(&result.image_index),
            .p_results = null,
        }) catch unreachable;
    }

    pub fn handle_create_logical_device_cmds(self: *Renderer) void
    {
        for (self.create_logical_device_cmd_queue.items) |_| 
        {
            const physical_device = self.context.?.physical_devices.items[0];
            const graphics_queue: u32 = 0;

            const queue_priorities = [_]f32{1.0};
            const queue_create_info = vk.DeviceQueueCreateInfo {
                .queue_family_index = graphics_queue,
                .queue_count = 1,
                .p_queue_priorities = &queue_priorities
            };

            var device_extensions = std.ArrayList([*:0]const u8).init(self.context.?.arena.allocator());
            device_extensions.append("VK_KHR_swapchain") catch unreachable;

            const device_features = vk.PhysicalDeviceFeatures{};
            _ = device_features; // autofix

            const vk_queue_create_infos = [_]vk.DeviceQueueCreateInfo{ queue_create_info };
            const device_create_info = vk.DeviceCreateInfo {
                .queue_create_info_count = 1,
                .p_queue_create_infos = &vk_queue_create_infos,
                .enabled_extension_count = @intCast(device_extensions.items.len),
                .pp_enabled_extension_names = device_extensions.items.ptr,
                .enabled_layer_count = 0,
            };

            const _device = self.context.?.instance.createDevice(physical_device, &device_create_info, null) catch unreachable;

            const vkd = self.context.?.arena.allocator().create(DeviceDispatch) catch unreachable;
            vkd.* = DeviceDispatch.load(_device, self.context.?.instance.wrapper.dispatch.vkGetDeviceProcAddr) catch unreachable;
            const device = Device.init(_device, vkd);

            self.logical_device = LogicalDevice {
                .device = device,
                .physical_device = physical_device,
                .graphics_queue = graphics_queue,
            };
        }
        self.create_logical_device_cmd_queue.clearRetainingCapacity();    
    }

    pub fn handle_create_render_target_cmds(self: *Renderer) void
    {
        for (self.create_render_target_cmd_queue.items) |cmd| 
        {            
            var surface: vk.SurfaceKHR = undefined;
            _ = glfw.createWindowSurface(self.context.?.instance.handle, cmd.window.*, null, &surface);

            var image_count: u32 = 3; 
            const swap_chain_create_info = vk.SwapchainCreateInfoKHR {
                .surface = surface,
                .min_image_count = image_count,
                .image_format = vk.Format.r8g8b8a8_unorm,
                .image_color_space = vk.ColorSpaceKHR.colorspace_srgb_nonlinear_khr,
                .image_extent = vk.Extent2D{ .width = 800, .height = 600 },
                .image_array_layers = 1,
                .image_usage = .{ .color_attachment_bit = true },
                .image_sharing_mode = vk.SharingMode.exclusive,
                .pre_transform = .{ .identity_bit_khr = true },
                .composite_alpha = .{ .opaque_bit_khr = true },
                .present_mode = vk.PresentModeKHR.fifo_khr,
                .clipped = vk.TRUE,
                .old_swapchain = vk.SwapchainKHR.null_handle,
            };

            const swapchain = self.logical_device.?.device.createSwapchainKHR(&swap_chain_create_info, null) catch |err| {
                logger.err("Failed to create swapchain: {?}", .{err});
                std.process.exit(1);
            };

            const swapchain_images = self.context.?.arena.allocator().alloc(vk.Image, image_count) catch unreachable;
            const res = self.logical_device.?.device.getSwapchainImagesKHR(swapchain, &image_count, swapchain_images.ptr) catch |e| {
                logger.err("Failed to get swapchain images: {?}", .{e});
                std.process.exit(1);
            };
            
            if (res != vk.Result.success) {
                logger.err("Failed to get swapchain images: {?}", .{res});
                std.process.exit(1);
            }

            var image_views = std.ArrayList(vk.ImageView).init(self.context.?.arena.allocator());

            for (swapchain_images) |image| 
            {
                const image_view_create_info = vk.ImageViewCreateInfo {
                    .flags = .{},
                    .image = image,
                    .view_type = .@"2d",
                    .format = vk.Format.r8g8b8a8_unorm,
                    .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
                    .subresource_range = .{
                        .aspect_mask = .{ .color_bit = true },
                        .base_mip_level = 0,
                        .level_count = 1,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                };

                const image_view = self.logical_device.?.device.createImageView(&image_view_create_info, null) catch |e| {
                    logger.err("Failed to create image view: {?}", .{e});
                    std.process.exit(1);
                };

                image_views.append(image_view) catch |e| {
                    logger.err("Failed to append image view: {?}", .{e});
                    std.process.exit(1);
                };
            }

            var image_arr = std.ArrayList(vk.Image).init(self.context.?.arena.allocator());
            image_arr.appendSlice(swapchain_images) catch unreachable;

            self.render_target = RenderTarget {
                .surface = surface,
                .images = image_arr,
                .format = vk.Format.r8g8b8a8_unorm,
                .extent = vk.Extent2D{ .width = 800, .height = 600 },
                .swapchain = swapchain,
                .image_views = image_views,
            };
            logger.debug("Target Created", .{});
        }
        self.create_render_target_cmd_queue.clearRetainingCapacity();    
    }

    pub fn shutdown(self: *Renderer) void
    {
        if (self.render_target != null)     
        {   
            for (self.render_target.?.image_views.items) |image_view| 
            {
                self.logical_device.?.device.destroyImageView(image_view, null);
            }
            self.render_target.?.image_views.deinit();
            self.render_target.?.images.deinit();
            self.logical_device.?.device.destroySwapchainKHR(self.render_target.?.swapchain, null);
            self.context.?.instance.destroySurfaceKHR(self.render_target.?.surface, null);            
        }

        if (self.logical_device != null)     
        {   
            self.logical_device.?.device.destroyDevice(null);
        }

        if (self.context != null)     
        {  
            self.context.?.instance.destroyInstance(null);
        }
    }
};

fn debug_callback(_: vk.DebugUtilsMessageSeverityFlagsEXT, _: vk.DebugUtilsMessageTypeFlagsEXT, p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(vk.vulkan_call_conv) vk.Bool32 
{
    if (p_callback_data != null) 
    {
        logger.debug("Validation Layer: {?s}", .{p_callback_data.?.p_message});
    }

    return vk.FALSE;
}
