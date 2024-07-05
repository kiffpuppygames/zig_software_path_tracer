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

    pub fn create_render_target(allocator: *std.mem.Allocator, ctx: *renderer.renderer_context.RendererContext, logical_device: *renderer.logical_device.LogicalDevice, window: renderer.Window) !RenderTarget
    {
        const surface_format: vk.SurfaceFormatKHR = choose_swap_surface_format(logical_device.swapchain_support_details.formats);
        const present_mode: vk.PresentModeKHR = choose_swap_present_mode(logical_device.swapchain_support_details.present_modes);
        const extent: vk.Extent2D = choose_swap_extent(logical_device.swapchain_support_details.capabilities, @constCast(&window.glfw_window));

        var image_count = logical_device.swapchain_support_details.capabilities.min_image_count + 1;
        if (logical_device.swapchain_support_details.capabilities.max_image_count > 0 and logical_device.swapchain_support_details.capabilities.max_image_count < image_count) 
        {
            image_count = logical_device.swapchain_support_details.capabilities.max_image_count;
        }

        const indices = try renderer.find_queue_families(&ctx.instance, allocator, logical_device.physical_device, window.surface);
        const queue_family_indices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
        const sharing_mode: vk.SharingMode = if (indices.graphics_family.? != indices.present_family.?)
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
            .queue_family_index_count = queue_family_indices.len,
            .p_queue_family_indices = &queue_family_indices,
            .pre_transform = logical_device.swapchain_support_details.capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = .null_handle,
        }, null);

        const swapchain_images = try logical_device.vk_device.getSwapchainImagesAllocKHR(swapchain, allocator.*);

        return RenderTarget 
        {
            .window = window,
            .swapchain = swapchain,
            .images = swapchain_images,
            .image_views = try create_image_views(allocator, logical_device, swapchain_images.ptr, @intCast(swapchain_images.len), surface_format.format),
            .format = surface_format.format,
            .extent = extent,
        };
    }

    fn choose_swap_surface_format(available_formats: []vk.SurfaceFormatKHR) vk.SurfaceFormatKHR 
    {
        for (available_formats) |available_format| {
            if (available_format.format == .r8g8b8a8_srgb and available_format.color_space == .srgb_nonlinear_khr) 
            {
                return available_format;
            }
        }

        return available_formats[0];
    }

    fn choose_swap_present_mode(available_present_modes: []vk.PresentModeKHR) vk.PresentModeKHR {
        for (available_present_modes) |available_present_mode| {
            if (available_present_mode == .mailbox_khr) {
                return available_present_mode;
            }
        }

        return .fifo_khr;
    }

    fn choose_swap_extent(capabilities: vk.SurfaceCapabilitiesKHR, window: *glfw.Window) vk.Extent2D {
        if (capabilities.current_extent.width != 0xFFFF_FFFF) {
            return capabilities.current_extent;
        } else {
            const window_size = window.getFramebufferSize();

            return vk.Extent2D{
                .width = std.math.clamp(window_size.width, capabilities.min_image_extent.width, capabilities.max_image_extent.width),
                .height = std.math.clamp(window_size.height, capabilities.min_image_extent.height, capabilities.max_image_extent.height),
            };
        }
    }

    fn create_image_views(allocator: *std.mem.Allocator, logical_device: *renderer.logical_device.LogicalDevice, swapchain_images: [*]vk.Image, image_count: u32, format: vk.Format) ![]vk.ImageView 
    {
        const swapchain_image_views = try allocator.alloc(vk.ImageView, image_count);

        for (swapchain_images, 0..image_count) |image, i| {
            swapchain_image_views[i] = try logical_device.vk_device.createImageView( &.{
                .flags = .{},
                .image = image,
                .view_type = .@"2d",
                .format = format,
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

        return swapchain_image_views;
    }

    pub fn deinit(self: *RenderTarget, allocator: *std.mem.Allocator, logical_device: *renderer.logical_device.LogicalDevice) void 
    {
        for (self.image_views) |image_view| {
            logical_device.vk_device.destroyImageView(image_view, null);
        }
        allocator.free(self.image_views);

        for (self.images) |image| {
            logical_device.vk_device.destroyImage(image, null);
        }
        allocator.free(self.images);

        logical_device.vk_device.destroySwapchainKHR(self.swapchain, null);
        self.window.glfw_window.destroySurfaceKHR(self.window.surface, null);
        glfw.destroyWindow(self.window.glfw_window);

        
        
    }
};