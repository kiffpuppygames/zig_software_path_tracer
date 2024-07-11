
const std = @import("std");

const vk = @import("vulkan");

const renderer = @import("renderer.zig");

pub const RenderPass = struct 
{
    vk_render_pass: vk.RenderPass = .null_handle,
    framebuffers: []vk.Framebuffer = undefined,    

    pub fn create_render_pass(allocator: *const std.mem.Allocator, target: *const renderer.render_target.RenderTarget, vk_device: *const renderer.Device) !RenderPass
    {
        const color_attachment = [_]vk.AttachmentDescription{.{
            .flags = .{},
            .format = target.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
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

        const subpass = [_]vk.SubpassDescription{.{
            .flags = .{},
            .pipeline_bind_point = .graphics,
            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .color_attachment_count = color_attachment_ref.len,
            .p_color_attachments = &color_attachment_ref,
            .p_resolve_attachments = null,
            .p_depth_stencil_attachment = null,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        }};

        const dependencies = [_]vk.SubpassDependency{.{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true },
            .dependency_flags = .{},
        }};

        const vk_render_pass = try vk_device.createRenderPass( &.{
            .flags = .{},
            .attachment_count = color_attachment.len,
            .p_attachments = &color_attachment,
            .subpass_count = subpass.len,
            .p_subpasses = &subpass,
            .dependency_count = dependencies.len,
            .p_dependencies = &dependencies,
        }, null);

        const framebuffers = try allocator.alloc(vk.Framebuffer, target.image_views.len);

        for (framebuffers, 0..) |*framebuffer, i| {
            const attachments = [_]vk.ImageView{target.image_views[i]};

            framebuffer.* = try vk_device.createFramebuffer( &.{
                .flags = .{},
                .render_pass = vk_render_pass,
                .attachment_count = attachments.len,
                .p_attachments = &attachments,
                .width = target.extent.width,
                .height = target.extent.height,
                .layers = 1,
            }, null);
        }

        return RenderPass 
        {
            .vk_render_pass = vk_render_pass,
            .framebuffers = framebuffers,
        };
    }

    pub fn deinit(self: *RenderPass, allocator: *std.mem.Allocator, vk_device: *renderer.Device) void
    {
        for (self.framebuffers) |framebuffer| 
        {
            vk_device.destroyFramebuffer(framebuffer, null);
        }

        vk_device.destroyRenderPass(self.vk_render_pass, null);
        allocator.free(self.framebuffers);
    }
};