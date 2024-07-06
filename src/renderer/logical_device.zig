const std = @import("std");

const vk = @import("vulkan");

const api = @import("api.zig");
const renderer = @import("renderer.zig");

pub const LogicalDevice = struct 
{
    vk_device: renderer.Device = undefined,
    physical_device: renderer.PhysicalDevice = undefined,
    queues: std.AutoArrayHashMap(renderer.QueueType, renderer.Queue) = undefined,

    _vkd: *renderer.DeviceDispatch = undefined,

    pub fn create_logical_device(
        ctx: *renderer.renderer_context.RendererContext, 
        allocator: *std.mem.Allocator, 
        physical_device: renderer.PhysicalDevice
    ) !LogicalDevice 
    {
        const queue_priority = [_]f32{1};

        var queue_create_info = [_]vk.DeviceQueueCreateInfo{
            .{
                .flags = .{},
                .queue_family_index = physical_device.graphics_family.?,
                .queue_count = 1,
                .p_queue_priorities = &queue_priority,
            },
            .{
                .flags = .{},
                .queue_family_index = physical_device.present_family.?,
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
            .enabled_extension_count = renderer.DEVICE_EXTENSIONS.len,
            .pp_enabled_extension_names = &renderer.DEVICE_EXTENSIONS,
            .p_enabled_features = null,
        };

        if (renderer.ENABLE_VALIDATION_LAYERS) 
        {
            create_info.enabled_layer_count = renderer.VALIDATION_LAYERS.len;
            create_info.pp_enabled_layer_names = &renderer.VALIDATION_LAYERS;
        }

        const _device = ctx.instance.createDevice(physical_device.vk_physical_device, &create_info, null) catch unreachable;
        const vkd = allocator.create(renderer.DeviceDispatch) catch unreachable;
        vkd.* = renderer.DeviceDispatch.load(_device, ctx.instance.wrapper.dispatch.vkGetDeviceProcAddr) catch unreachable;
        const device = renderer.Device.init(_device, vkd);

        const graphics_queue = device.getDeviceQueue(physical_device.graphics_family.?, 0);
        const present_queue = device.getDeviceQueue(physical_device.present_family.?, 0);

        var queues = std.AutoArrayHashMap(renderer.QueueType, renderer.Queue).init(allocator.*);
        try queues.put(renderer.QueueType.Graphics, renderer.Queue{ .queue_type = renderer.QueueType.Graphics, .vk_queue = graphics_queue, .index = 0, .queue_priority = 1.0 });
        try queues.put(renderer.QueueType.Present, renderer.Queue{ .queue_type = renderer.QueueType.Present, .vk_queue = present_queue, .index = 0, .queue_priority = 1.0 });

        return LogicalDevice 
        {
            .vk_device = device,
            .physical_device = physical_device,
            .queues = queues,
            ._vkd = vkd,
        };
    }

    pub fn deinit(self: *LogicalDevice, allocator: *std.mem.Allocator) void 
    {
        allocator.free(self.physical_device.formats);
        allocator.free(self.physical_device.present_modes);
        self.queues.deinit();

        self.vk_device.destroyDevice(null);
        allocator.destroy(self._vkd);
    }
};

