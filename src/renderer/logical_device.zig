const std = @import("std");

const vk = @import("vulkan");

const api = @import("api.zig");
const renderer = @import("renderer.zig");

pub const DeviceDispatch = vk.DeviceWrapper(api.API_DEFINITION);

pub const Device = vk.DeviceProxy(api.API_DEFINITION);

pub const Queue = struct
{
    vk_queue: vk.Queue = .null_handle,
    index: u8 = 0,
    queue_priority: f32 = 1.0, 
};


pub const LogicalDevice = struct 
{
    vk_device: Device = undefined,
    physical_device: vk.PhysicalDevice = .null_handle,
    swapchain_support_details: renderer.SwapChainSupportDetails = undefined,
    graphics_queue: Queue = undefined,
    present_queue: Queue = undefined,

    _vkd: *DeviceDispatch = undefined,

    pub fn create_logical_device(ctx: *renderer.renderer_context.RendererContext, allocator: *std.mem.Allocator, physical_device: vk.PhysicalDevice, swapchain_support_details: renderer.SwapChainSupportDetails, surface: vk.SurfaceKHR) !LogicalDevice 
    {
        const indices = try renderer.find_queue_families(&ctx.instance, allocator, physical_device, surface);
        const queue_priority = [_]f32{1};

        var queue_create_info = [_]vk.DeviceQueueCreateInfo{
            .{
                .flags = .{},
                .queue_family_index = indices.graphics_family.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priority,
            },
            .{
                .flags = .{},
                .queue_family_index = indices.present_family.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priority,
            },
        };

        var create_info = vk.DeviceCreateInfo 
        {
            .flags = .{},
            .queue_create_info_count = queue_create_info.len,
            .p_queue_create_infos = &queue_create_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = renderer.renderer_context.DEVICE_EXTENSIONS.len,
            .pp_enabled_extension_names = &renderer.renderer_context.DEVICE_EXTENSIONS,
            .p_enabled_features = null,
        };

        if (renderer.renderer_context.ENABLE_VALIDATION_LAYERS) 
        {
            create_info.enabled_layer_count = renderer.renderer_context.VALIDATION_LAYERS.len;
            create_info.pp_enabled_layer_names = &renderer.renderer_context.VALIDATION_LAYERS;
        }

        const _device = ctx.instance.createDevice(physical_device, &create_info, null) catch unreachable;
        const vkd = allocator.create(renderer.logical_device.DeviceDispatch) catch unreachable;
        vkd.* = renderer.logical_device.DeviceDispatch.load(_device, ctx.instance.wrapper.dispatch.vkGetDeviceProcAddr) catch unreachable;
        const device = renderer.logical_device.Device.init(_device, vkd);

        const graphics_queue = device.getDeviceQueue(indices.graphics_family.?, 0);
        const present_queue = device.getDeviceQueue(indices.present_family.?, 0);

        return LogicalDevice 
        {
            .vk_device = device,
            .physical_device = physical_device,
            .swapchain_support_details = swapchain_support_details,
            .graphics_queue = Queue{ .vk_queue = graphics_queue, .index = 0, .queue_priority = 1.0 },
            .present_queue = Queue{ .vk_queue = present_queue, .index = 0, .queue_priority = 1.0 },
            ._vkd = vkd,
        };
    }

    pub fn deinit(self: *LogicalDevice, allocator: *std.mem.Allocator) void 
    {
        allocator.free(self.swapchain_support_details.formats);
        allocator.free(self.swapchain_support_details.present_modes);

        self.vk_device.destroyDevice(null);
        allocator.destroy(self._vkd);
    }
};

