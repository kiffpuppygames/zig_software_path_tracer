const std = @import("std");
const builtin = @import("builtin");

const glfw = @import("mach-glfw");
const vk = @import("vulkan");

pub const api = @import("api.zig");
pub const renderer_context = @import("renderer_context.zig");
pub const logical_device = @import("logical_device.zig");
pub const render_target = @import("render_target.zig");
pub const render_pass = @import("render_pass.zig");
pub const pipeline = @import("pipeline.zig");
pub const image_pipeline = @import("image_pipeline.zig");

pub const VALIDATION_LAYERS = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
pub const DEVICE_EXTENSIONS = [_][*:0]const u8{ vk.extensions.khr_swapchain.name, vk.extensions.ext_descriptor_indexing.name };

pub const ENABLE_VALIDATION_LAYERS: bool = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    else => false,
};

pub const VulkanEntryPoint = vk.BaseWrapper(api.API_DEFINITION);
pub const InstanceDispatch = vk.InstanceWrapper(api.API_DEFINITION);

pub const Instance = vk.InstanceProxy(api.API_DEFINITION);

pub const DeviceDispatch = vk.DeviceWrapper(api.API_DEFINITION);
pub const Device = vk.DeviceProxy(api.API_DEFINITION);

pub const QueueType = enum(u32) {
    Graphics = 0,
    Present = 1,
};

pub const Queue = struct {
    queue_type: QueueType = undefined,
    vk_queue: vk.Queue = .null_handle,
    index: u8 = 0,
    queue_priority: f32 = 1.0,
};

pub const Window = struct {
    glfw_window: glfw.Window = undefined,
    surface: vk.SurfaceKHR = .null_handle,
};

pub const PhysicalDevice = struct {
    vk_physical_device: vk.PhysicalDevice = .null_handle,
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,
    properties: vk.PhysicalDeviceProperties = undefined,
    capabilities: vk.SurfaceCapabilitiesKHR = undefined,
    formats: []vk.SurfaceFormatKHR = undefined,
    present_modes: []vk.PresentModeKHR = undefined,

    pub fn is_complete(self: *const PhysicalDevice) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

pub fn create_shader_module(vk_device: *const Device, code: []align(@alignOf(u32)) const u8) vk.ShaderModule {
    const vert_mod_create_info = vk.ShaderModuleCreateInfo{
        .code_size = code.len,
        .p_code = std.mem.bytesAsSlice(u32, code).ptr,
    };
    const vert_shader_mod: vk.ShaderModule = vk_device.createShaderModule(&vert_mod_create_info, null) catch unreachable;
    return vert_shader_mod;
}
