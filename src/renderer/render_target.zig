const std = @import("std");

const glfw = @import("mach-glfw");
const vk = @import("vulkan");

const renderer = @import("renderer.zig");

pub const RenderTarget = struct 
{
    window: renderer.Window,
    swapchain: vk.SwapchainKHR,
    images: []vk.Image,
    image_views: []vk.ImageView,
    format: vk.Format,
    extent: vk.Extent2D,

    pub fn create_render_target(allocator: *std.mem.Allocator, logical_device: *renderer.logical_device.LogicalDevice, window: renderer.Window) !RenderTarget
    {
        var surface_format: vk.SurfaceFormatKHR = logical_device.physical_device.formats[0];
        for (logical_device.physical_device.formats) |available_format| {
            if (available_format.format == .r8g8b8a8_srgb and available_format.color_space == .srgb_nonlinear_khr) 
            {
                surface_format = available_format;
            }
        }
        
        var present_mode: vk.PresentModeKHR = vk.PresentModeKHR.fifo_khr;
        for (logical_device.physical_device.present_modes) |available_present_mode| {
            if (available_present_mode == .mailbox_khr) {
                present_mode = available_present_mode;
            }
        }  

        const window_size = window.glfw_window.getFramebufferSize();
        var extent: vk.Extent2D = vk.Extent2D 
        {
            .width = std.math.clamp(window_size.width, logical_device.physical_device.capabilities.min_image_extent.width, logical_device.physical_device.capabilities.max_image_extent.width),
            .height = std.math.clamp(window_size.height, logical_device.physical_device.capabilities.min_image_extent.height, logical_device.physical_device.capabilities.max_image_extent.height),
        };        
        if (logical_device.physical_device.capabilities.current_extent.width != 0xFFFF_FFFF) 
        {
            extent = logical_device.physical_device.capabilities.current_extent;
        } 

        var image_count = logical_device.physical_device.capabilities.min_image_count + 1;
        if (logical_device.physical_device.capabilities.max_image_count > 0 and logical_device.physical_device.capabilities.max_image_count < image_count) 
        {
            image_count = logical_device.physical_device.capabilities.max_image_count;
        }

        const indices: []u32 = try allocator.alloc(u32, logical_device.queues.count());
        defer allocator.free(indices);
        for (logical_device.queues.values(), 0..) |queue, i| 
        {
            indices[i] = queue.index;
        }

        const sharing_mode: vk.SharingMode = if (logical_device.queues.get(.Graphics).?.index != logical_device.queues.get(.Present).?.index)
            .concurrent
        else
            .exclusive;

        const swapchain = try logical_device.vk_device.createSwapchainKHR(&.{
            .flags = .{},
            .surface = window.surface,
            .min_image_count = image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true },
            .image_sharing_mode = sharing_mode,
            .queue_family_index_count = @intCast(indices.len),
            .p_queue_family_indices = indices.ptr,
            .pre_transform = logical_device.physical_device.capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = .null_handle,
        }, null);

        const swapchain_images = try logical_device.vk_device.getSwapchainImagesAllocKHR(swapchain, allocator.*);

        const swapchain_image_views = try allocator.alloc(vk.ImageView, image_count);
        for (swapchain_images, 0..image_count) |image, i| 
        {
            swapchain_image_views[i] = try logical_device.vk_device.createImageView( &.{
                .flags = .{},
                .image = image,
                .view_type = .@"2d",
                .format = surface_format.format,
                .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            }, 
            null);
        }

        return RenderTarget 
        {
            .window = window,
            .swapchain = swapchain,
            .images = swapchain_images,
            .image_views = swapchain_image_views,
            .format = surface_format.format,
            .extent = extent,
        };
    }

    pub fn deinit(self: *RenderTarget, allocator: *std.mem.Allocator, instance: *renderer.Instance, vk_device: *renderer.Device) void 
    {
        for (self.image_views) |image_view| {
            vk_device.destroyImageView(image_view, null);
        }
        allocator.free(self.image_views);

        // for (self.images) |image| {
        //     vk_device.destroyImage(image, null);
        // }
        allocator.free(self.images);

        vk_device.destroySwapchainKHR(self.swapchain, null);
        instance.destroySurfaceKHR(self.window.surface, null);
        self.window.glfw_window.destroy();
    }
};