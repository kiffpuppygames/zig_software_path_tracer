const std = @import("std");


const glfw = @import("mach-glfw");
const vk = @import("vulkan");

const logger = @import("../common/common.zig").logger;
const renderer = @import("renderer.zig");

pub const RendererContext = struct 
{
    entry_point: renderer.VulkanEntryPoint = undefined,
    instance: renderer.Instance = undefined,
    _vki: *renderer.InstanceDispatch = undefined,
    _debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle,

    pub fn create_renderer_context(allocator: *std.mem.Allocator) !RendererContext 
    {
        //const vk_proc: *const fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction = @ptrCast(&glfw.getInstanceProcAddress);
        const entry_point = try renderer.VulkanEntryPoint.load(@as(vk.PfnGetInstanceProcAddr, @ptrCast(&glfw.getInstanceProcAddress)));

        const available_layers = try entry_point.enumerateInstanceLayerPropertiesAlloc(allocator.*);
        defer allocator.free(available_layers);

        var validation_layer_supported: bool = false;
        for (renderer.VALIDATION_LAYERS) |layer_name| 
        {
            for (available_layers) |layer_properties| 
            {
                const available_len = std.mem.indexOfScalar(u8, &layer_properties.layer_name, 0).?;
                const available_layer_name = layer_properties.layer_name[0..available_len];
                if (std.mem.eql(u8, std.mem.span(layer_name), available_layer_name)) 
                {
                    validation_layer_supported = true;
                    break;
                }
            }
        }

        if (renderer.ENABLE_VALIDATION_LAYERS and !validation_layer_supported) 
        {
            return error.MissingValidationLayer;
        }

        const app_info = vk.ApplicationInfo{
            .p_application_name = "Hello Triangle",
            .application_version = vk.makeApiVersion(1, 0, 0, 0),
            .p_engine_name = "No Engine",
            .engine_version = vk.makeApiVersion(1, 0, 0, 0),
            .api_version = vk.API_VERSION_1_2,
        };

        const glfw_exts = glfw.getRequiredInstanceExtensions();
        var instance_extensions = try std.ArrayList([*:0]const u8).initCapacity(allocator.*, glfw_exts.?.len + 1);
        defer instance_extensions.deinit();
        try instance_extensions.appendSlice(glfw_exts.?);

        if (renderer.ENABLE_VALIDATION_LAYERS) {
            try instance_extensions.append(vk.extensions.ext_debug_utils.name);
        }        

        var instance_create_info = vk.InstanceCreateInfo{
            .flags = .{},
            .p_application_info = &app_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = @intCast(instance_extensions.items.len),
            .pp_enabled_extension_names = instance_extensions.items.ptr,
        };

        var debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = undefined;
        if (renderer.ENABLE_VALIDATION_LAYERS) {
            instance_create_info.enabled_layer_count = renderer.VALIDATION_LAYERS.len;
            instance_create_info.pp_enabled_layer_names = &renderer.VALIDATION_LAYERS;

            debug_create_info = vk.DebugUtilsMessengerCreateInfoEXT {
                .flags = .{},
                .message_severity = .{
                    .verbose_bit_ext = true,
                    .warning_bit_ext = true,
                    .error_bit_ext = true,
                },
                .message_type = .{
                    .general_bit_ext = true,
                    .validation_bit_ext = true,
                    .performance_bit_ext = true,
                },
                .pfn_user_callback = debug_callback,
                .p_user_data = null,
            };

            instance_create_info.p_next = &debug_create_info;
        }

        const _instance = try entry_point.createInstance(&instance_create_info, null);

        const _vki = try allocator.create(renderer.InstanceDispatch);
        
        _vki.* = try renderer.InstanceDispatch.load(_instance, entry_point.dispatch.vkGetInstanceProcAddr);
        const instance = renderer.Instance.init(_instance, _vki);

        var debug_messenger: vk.DebugUtilsMessengerEXT = .null_handle;
        if (renderer.ENABLE_VALIDATION_LAYERS) 
        {
            debug_messenger = try instance.createDebugUtilsMessengerEXT( &debug_create_info, null);
        }        

        return RendererContext { .entry_point = entry_point, .instance = instance, ._vki = _vki, ._debug_messenger = debug_messenger };
    }

    pub fn is_device_suitable(self: *RendererContext, allocator: *std.mem.Allocator, device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !struct { bool, renderer.PhysicalDevice } 
    {
        var physical_device: renderer.PhysicalDevice = .{};

        var queue_family_count: u32 = 0;
        self.instance.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        const queue_families = try allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
        defer allocator.free(queue_families);
        self.instance.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

        for (queue_families, 0..) |queue_family, i| 
        {
            if (physical_device.graphics_family == null and queue_family.queue_flags.graphics_bit) 
            {
                physical_device.graphics_family = @intCast(i);
            } 
            else if (physical_device.present_family == null and (try self.instance.getPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), surface)) == vk.TRUE) 
            {
                physical_device.present_family = @intCast(i);
            }

            if (physical_device.is_complete()) {
                break;
            }
        }

        const required_extensions = renderer.DEVICE_EXTENSIONS[0..];
        const available_extensions = try self.instance.enumerateDeviceExtensionPropertiesAlloc(device, null, allocator.*);
        defer allocator.free(available_extensions);
        
        var extensions_supported = false;
        for (required_extensions) |required_extension| 
        {
            var extension_found: bool = false;
            for (available_extensions) |available_extension| 
            {
                const len = std.mem.indexOfScalar(u8, &available_extension.extension_name, 0).?;
                const available_extension_name = available_extension.extension_name[0..len];
                if (std.mem.eql(u8, std.mem.span(required_extension), available_extension_name)) 
                {
                    extension_found = true;
                    break;
                }
            }
            extensions_supported = extension_found;
        }

        var swap_chain_adequate = false;
        if (extensions_supported) 
        { 
            physical_device.vk_physical_device = device;
            physical_device.capabilities = try self.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(device, surface);
            physical_device.formats = try self.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(device, surface, allocator.*);
            physical_device.present_modes = try self.instance.getPhysicalDeviceSurfacePresentModesAllocKHR(device, surface, allocator.*);
       
            swap_chain_adequate = physical_device.formats.len > 0 and physical_device.present_modes.len > 0;
        }
        const res = physical_device.is_complete() and extensions_supported and swap_chain_adequate;
        return .{ res, physical_device };
    }

    pub fn deinit(self: *RendererContext, allocator: *std.mem.Allocator) void 
    {
        if (renderer.ENABLE_VALIDATION_LAYERS) 
        {
            self.instance.destroyDebugUtilsMessengerEXT(self._debug_messenger, null);
        }

        self.instance.destroyInstance(null);
        allocator.destroy(self._vki);
    }

    fn debug_callback(_: vk.DebugUtilsMessageSeverityFlagsEXT, _: vk.DebugUtilsMessageTypeFlagsEXT, p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(vk.vulkan_call_conv) vk.Bool32 {
        if (p_callback_data != null) 
        {
            logger.debug("validation layer: {?s}", .{p_callback_data.?.p_message});
        }
        return vk.FALSE;
    }
};