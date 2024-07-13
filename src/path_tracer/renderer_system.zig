const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("mach-glfw");

const logger = @import("../common/logger.zig");

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
        .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
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
        .resetCommandBuffer = true,
        .queueSubmit = true,
        .queuePresentKHR = true,
        
        

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

pub const RecordCmdBuffFunc = fn (*Renderer, vk.CommandBuffer, *RenderPassGroup, vk.Pipeline, u32) void;

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

pub const SyncItems = struct {
    image_available_semaphore: vk.Semaphore = undefined,
    render_finished_semaphore: vk.Semaphore = undefined,
    in_flight_fence: vk.Fence = undefined,
};

pub const LogicalDevice = struct {
    device: Device,
    physical_device: vk.PhysicalDevice,
    queue_index: u8,
    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
};

pub const SwapChainSupportDetails = struct {
    capabilities: vk.SurfaceCapabilitiesKHR = undefined,
    formats: ?[]vk.SurfaceFormatKHR = null,
    present_modes: ?[]vk.PresentModeKHR = null,
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

    pub fn init(allocator: std.mem.Allocator, device: *Device, format: vk.Format, views: *std.ArrayList(vk.ImageView)) RenderPassGroup
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

    pub fn draw_frame(
        self: *Renderer,
        command_buffer: vk.CommandBuffer,
        render_pass_group: *RenderPassGroup,
        pipeline: vk.Pipeline, 
        sync_items: *SyncItems,
        record_command_buffer: *const RecordCmdBuffFunc) void
    {
        _ = self.logical_device.?.device.waitForFences(1, @ptrCast(&sync_items.in_flight_fence), vk.TRUE, std.math.maxInt(u64)) catch unreachable;
        self.logical_device.?.device.resetFences(1, @ptrCast(&sync_items.in_flight_fence)) catch unreachable;

        const result = self.logical_device.?.device.acquireNextImageKHR(self.render_target.?.swapchain, std.math.maxInt(u64), sync_items.image_available_semaphore, .null_handle) catch unreachable;

        self.logical_device.?.device.resetCommandBuffer(command_buffer, .{}) catch unreachable;
        record_command_buffer(self, command_buffer, render_pass_group, pipeline, result.image_index);

        const wait_semaphores = [_]vk.Semaphore{sync_items.image_available_semaphore};
        const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
        const signal_semaphores = [_]vk.Semaphore{sync_items.render_finished_semaphore};

        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = wait_semaphores.len,
            .p_wait_semaphores = &wait_semaphores,
            .p_wait_dst_stage_mask = &wait_stages,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&command_buffer),
            .signal_semaphore_count = signal_semaphores.len,
            .p_signal_semaphores = &signal_semaphores,
        };
        _ = self.logical_device.?.device.queueSubmit(self.logical_device.?.graphics_queue, 1, &[_]vk.SubmitInfo{submit_info}, sync_items.in_flight_fence) catch unreachable;

        const swapchains = [_]vk.SwapchainKHR{self.render_target.?.swapchain};
        _ = self.logical_device.?.device.queuePresentKHR(self.logical_device.?.present_queue, &.{
            .wait_semaphore_count = signal_semaphores.len,
            .p_wait_semaphores = &signal_semaphores,
            .swapchain_count = 1,
            .p_swapchains = &swapchains,
            .p_image_indices = @ptrCast(&result.image_index),
            .p_results = null,
        }) catch unreachable;
    }

    pub fn handle_create_logical_device_cmds(self: *Renderer) void
    {
        for (self.create_logical_device_cmd_queue.items) |_| 
        {            
            const queue_priority = [_]f32{1};

            var queue_create_info = [_]vk.DeviceQueueCreateInfo{
                .{
                    .flags = .{},
                    .queue_family_index = 0,
                    .queue_count = 1,
                    .p_queue_priorities = &queue_priority,
                },
                .{
                    .flags = .{},
                    .queue_family_index = 0,
                    .queue_count = 1,
                    .p_queue_priorities = &queue_priority,
                },
            };

            var device_extensions = std.ArrayList([*:0]const u8).init(self.context.?.arena.allocator());
            device_extensions.append("VK_KHR_swapchain") catch unreachable;

            var create_info = vk.DeviceCreateInfo{
                .flags = .{},
                .queue_create_info_count = queue_create_info.len,
                .p_queue_create_infos = &queue_create_info,
                .enabled_layer_count = 0,
                .pp_enabled_layer_names = undefined,
                .enabled_extension_count = @intCast(device_extensions.items.len),
                .pp_enabled_extension_names = device_extensions.items.ptr,
                .p_enabled_features = null,
            };

            const _device = self.context.?.instance.createDevice(self.context.?.physical_devices.items[0], &create_info, null) catch unreachable;

            const vkd = self.context.?.arena.allocator().create(DeviceDispatch) catch unreachable;
            vkd.* = DeviceDispatch.load(_device, self.context.?.instance.wrapper.dispatch.vkGetDeviceProcAddr) catch unreachable;
            const device = Device.init(_device, vkd);

            self.logical_device = LogicalDevice {
                .device = device,
                .physical_device = self.context.?.physical_devices.items[0],
                .queue_index = 0,
                .graphics_queue = device.getDeviceQueue(0, 0),
                .present_queue = device.getDeviceQueue(0, 0),
            };
        }
        self.create_logical_device_cmd_queue.clearRetainingCapacity();    
    }

    fn choose_swap_extent(self: *Renderer, capabilities: vk.SurfaceCapabilitiesKHR, window: glfw.Window) !vk.Extent2D {
        _ = self; // autofix
        if (capabilities.current_extent.width != 0xFFFF_FFFF) {
            return capabilities.current_extent;
        } else {
            const window_size = try window.?.getFramebufferSize();

            return vk.Extent2D{
                .width = std.math.clamp(window_size.width, capabilities.min_image_extent.width, capabilities.max_image_extent.width),
                .height = std.math.clamp(window_size.height, capabilities.min_image_extent.height, capabilities.max_image_extent.height),
            };
        }
    }

    fn create_image_views(self: *Renderer) []vk.ImageView {
        var swap_chain_image_views = try self.context.?.arena.allocator().alloc(vk.ImageView, self.swap_chain_images.?.len);

        for (self.swap_chain_images.?, 0..) |image, i| {
            swap_chain_image_views.?[i] = try self.logical_device.?.device.createImageView(self.device, &.{
                .flags = .{},
                .image = image,
                .view_type = .@"2d",
                .format = self.swap_chain_image_format,
                .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            }, null);
        }

        return swap_chain_image_views;
    }

    pub fn handle_create_render_target_cmds(self: *Renderer) void
    {
        for (self.create_render_target_cmd_queue.items) |cmd| 
        { 
            var surface: vk.SurfaceKHR = .null_handle;
            _ = glfw.createWindowSurface(self.context.?.instance.handle, cmd.window.*, null, &surface);

            const swap_chain_support = self.query_swapchain_support(self.logical_device.?.physical_device, surface);

            const surface_format: vk.SurfaceFormatKHR = vk.SurfaceFormatKHR{ .format = vk.Format.r8g8b8a8_unorm, .color_space = vk.ColorSpaceKHR.srgb_nonlinear_khr };
            const present_mode: vk.PresentModeKHR = vk.PresentModeKHR.fifo_khr;
            const extent: vk.Extent2D = try self.choose_swap_extent(swap_chain_support.capabilities, surface);

            var image_count = swap_chain_support.capabilities.min_image_count + 1;
            if (swap_chain_support.capabilities.max_image_count > 0) {
                image_count = std.math.min(image_count, swap_chain_support.capabilities.max_image_count);
            }

            const indices = try self.findQueueFamilies(self.physical_device);
            const queue_family_indices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
            const sharing_mode: vk.SharingMode = if (indices.graphics_family.? != indices.present_family.?)
                .concurrent
            else
                .exclusive;

            const swapchain = self.vkd.createSwapchainKHR(self.device, &.{
                .flags = .{},
                .surface = self.surface,
                .min_image_count = image_count,
                .image_format = surface_format.format,
                .image_color_space = surface_format.color_space,
                .image_extent = extent,
                .image_array_layers = 1,
                .image_usage = .{ .color_attachment_bit = true },
                .image_sharing_mode = sharing_mode,
                .queue_family_index_count = queue_family_indices.len,
                .p_queue_family_indices = &queue_family_indices,
                .pre_transform = swap_chain_support.capabilities.current_transform,
                .composite_alpha = .{ .opaque_bit_khr = true },
                .present_mode = present_mode,
                .clipped = vk.TRUE,
                .old_swapchain = .null_handle,
            }, null) catch unreachable;

            const get_image_res = self.logical_device.?.device.getSwapchainImagesKHR(swapchain, &image_count, null) catch unreachable;

            self.render_target = RenderTarget {
                .surface = surface,
                .images = get_image_res.?,
                .format = surface_format.format,
                .extent = extent,
                .swapchain = swapchain,
                .image_views = self.create_image_views(),
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
