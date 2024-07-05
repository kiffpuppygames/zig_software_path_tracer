const std = @import("std");

const glfw = @import("mach-glfw");
const vk = @import("vulkan");

pub const renderer_context = @import("renderer_context.zig");
pub const logical_device = @import("logical_device.zig");
pub const render_target = @import("render_target.zig");

pub const Window = struct 
{
    glfw_window: glfw.Window = undefined,    
    surface: vk.SurfaceKHR = .null_handle,
};

const QueueFamilyIndices = struct 
{
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,

    pub fn is_complete(self: *const QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

pub const SwapChainSupportDetails = struct 
{
    capabilities: vk.SurfaceCapabilitiesKHR = undefined,
    formats: []vk.SurfaceFormatKHR = undefined,
    present_modes: []vk.PresentModeKHR = undefined
};

pub fn find_queue_families(instance: *renderer_context.Instance, allocator: *std.mem.Allocator, device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !QueueFamilyIndices 
{
    var indices: QueueFamilyIndices = .{};

    var queue_family_count: u32 = 0;
    instance.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

    const queue_families = try allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
    defer allocator.free(queue_families);
    instance.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

    for (queue_families, 0..) |queue_family, i| 
    {
        if (indices.graphics_family == null and queue_family.queue_flags.graphics_bit) 
        {
            indices.graphics_family = @intCast(i);
        } 
        else if (indices.present_family == null and (try instance.getPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), surface)) == vk.TRUE) 
        {
            indices.present_family = @intCast(i);
        }

        if (indices.is_complete()) {
            break;
        }
    }

    return indices;
}

pub fn query_swapchain_support(instance: *renderer_context.Instance, allocator: *std.mem.Allocator, device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !SwapChainSupportDetails 
{
    const details = SwapChainSupportDetails 
    { 
        .capabilities = try instance.getPhysicalDeviceSurfaceCapabilitiesKHR(device, surface),
        .formats = try instance.getPhysicalDeviceSurfaceFormatsAllocKHR(device, surface, allocator.*),
        .present_modes = try instance.getPhysicalDeviceSurfacePresentModesAllocKHR(device, surface, allocator.*),
    };

    return details;
}