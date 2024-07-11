const std = @import("std");

const vk = @import("vulkan");

const api = @import("api.zig");
const renderer = @import("renderer.zig");
const logger = @import("../common/common.zig").logger;

pub const LogicalDevice = struct 
{
    vk_device: renderer.Device = undefined,
    physical_device: renderer.PhysicalDevice = undefined,
    graphics_queue: renderer.Queue = undefined,

    _vkd: *renderer.DeviceDispatch = undefined,

    pub fn create_logical_device(
        ctx: *const renderer.renderer_context.RendererContext, 
        allocator: *const std.mem.Allocator, 
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

        if (renderer.ENABLE_VALIDATION_LAYERS)
        {
            logger.debug("Device Extensions:", .{});
            for (renderer.DEVICE_EXTENSIONS) |ext| 
            {
                logger.debug("\t{?s}", .{ext});    
            }
        }

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

        const _device = ctx.instance.createDevice(physical_device.vk_physical_device, &create_info, null) catch unreachable;
        const vkd = allocator.create(renderer.DeviceDispatch) catch unreachable;
        vkd.* = renderer.DeviceDispatch.load(_device, ctx.instance.wrapper.dispatch.vkGetDeviceProcAddr) catch unreachable;
        const device = renderer.Device.init(_device, vkd);

        const graphics_queue = device.getDeviceQueue(physical_device.graphics_family.?, 0);
        
        return LogicalDevice 
        {
            .vk_device = device,
            .physical_device = physical_device,
            .graphics_queue = renderer.Queue{ .queue_type = renderer.QueueType.Graphics, .vk_queue = graphics_queue, .index = 0, .queue_priority = 1.0 },
            ._vkd = vkd,
        };
    }

    pub fn deinit(self: *LogicalDevice, allocator: *std.mem.Allocator) void 
    {
        allocator.free(self.physical_device.formats);
        allocator.free(self.physical_device.present_modes);

        self.vk_device.destroyDevice(null);     
        allocator.destroy(self._vkd);
    }
};

