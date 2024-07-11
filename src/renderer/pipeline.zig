const std = @import("std");

const vk = @import("vulkan");

const renderer = @import("renderer.zig");

pub const Pipeline = struct 
{
    pipeline_layout: vk.PipelineLayout = .null_handle,
    vk_pipeline: vk.Pipeline = .null_handle,
    command_pool: vk.CommandPool = .null_handle,
    command_buffer: vk.CommandBuffer = .null_handle,
    image_available_semaphore: vk.Semaphore = .null_handle,
    render_finished_semaphore: vk.Semaphore = .null_handle,
    in_flight_fence: vk.Fence = .null_handle,

    pub fn create_pipeline(allocator: *std.mem.Allocator, logical_device: *renderer.logical_device.LogicalDevice, render_pass: *renderer.render_pass.RenderPass) !Pipeline
    {
        const vert_shader_code align(4) = @embedFile("../shaders/vert.spv").*;
        const vert_shader_module: vk.ShaderModule = renderer.create_shader_module(&logical_device.vk_device, &vert_shader_code);
        defer logical_device.vk_device.destroyShaderModule( vert_shader_module, null);

        const frag_shader_code align(4) = @embedFile("../shaders/frag.spv").*;
        const frag_shader_module: vk.ShaderModule = renderer.create_shader_module(&logical_device.vk_device, &frag_shader_code);
        defer logical_device.vk_device.destroyShaderModule( frag_shader_module, null);

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .flags = .{},
                .stage = .{ .vertex_bit = true },
                .module = vert_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .flags = .{},
                .stage = .{ .fragment_bit = true },
                .module = frag_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
        };

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .flags = .{},
            .vertex_binding_description_count = 0,
            .p_vertex_binding_descriptions = undefined,
            .vertex_attribute_description_count = 0,
            .p_vertex_attribute_descriptions = undefined,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .flags = .{},
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = undefined,
            .scissor_count = 1,
            .p_scissors = undefined,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .flags = .{},
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true },
            .front_face = .clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .flags = .{},
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 1,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const color_blend_attachment = [_]vk.PipelineColorBlendAttachmentState{.{
            .blend_enable = vk.FALSE,
            .src_color_blend_factor = .one,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        }};

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .flags = .{},
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = color_blend_attachment.len,
            .p_attachments = &color_blend_attachment,
            .blend_constants = [_]f32{ 0, 0, 0, 0 },
        };
        const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .flags = .{},
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        const pipeline_layout = try logical_device.vk_device.createPipelineLayout( &.{
            .flags = .{},
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        }, null);

        const pipeline_info = [_]vk.GraphicsPipelineCreateInfo{.{
            .flags = .{},
            .stage_count = shader_stages.len,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_info,
            .p_input_assembly_state = &input_assembly,
            .p_tessellation_state = null,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterizer,
            .p_multisample_state = &multisampling,
            .p_depth_stencil_state = null,
            .p_color_blend_state = &color_blending,
            .p_dynamic_state = &dynamic_state,
            .layout = pipeline_layout,
            .render_pass = render_pass.vk_render_pass,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        }};

        const pipelines: []vk.Pipeline = try allocator.alloc(vk.Pipeline, pipeline_info.len);
        defer allocator.free(pipelines);
        _ = try logical_device.vk_device.createGraphicsPipelines(
            .null_handle,
            pipeline_info.len,
            &pipeline_info,
            null,
            pipelines.ptr
        );

        const command_pool = try logical_device.vk_device.createCommandPool( &.{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = logical_device.queues.get(renderer.QueueType.Graphics).?.index,
        }, null);

        const command_buffers: []vk.CommandBuffer = try allocator.alloc(vk.CommandBuffer, 1);
        defer allocator.free(command_buffers);
        try logical_device.vk_device.allocateCommandBuffers(&.{
            .command_pool = command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        }, command_buffers.ptr);

        return Pipeline 
        {
            .pipeline_layout = pipeline_layout,
            .vk_pipeline = pipelines[0],
            .command_pool = command_pool,
            .command_buffer = command_buffers[0],
            .image_available_semaphore = try logical_device.vk_device.createSemaphore( &.{ .flags = .{} }, null),
            .render_finished_semaphore = try logical_device.vk_device.createSemaphore( &.{ .flags = .{} }, null),
            .in_flight_fence = try logical_device.vk_device.createFence( &.{ .flags = .{ .signaled_bit = true } }, null)
        };
    }

    pub fn record_commandbuffer(self: *Pipeline, vk_device: *renderer.Device, render_pass: *renderer.render_pass.RenderPass, extent: *vk.Extent2D, image_index: u32) !void 
    {
        try vk_device.beginCommandBuffer(self.command_buffer, &.{
            .flags = .{},
            .p_inheritance_info = null,
        });

        const clear_values = [_]vk.ClearValue{.{
            .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
        }};

        const render_pass_info = vk.RenderPassBeginInfo{
            .render_pass = render_pass.vk_render_pass,
            .framebuffer = render_pass.framebuffers[image_index],
            .render_area = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = extent.*,
            },  
            .clear_value_count = clear_values.len,
            .p_clear_values = &clear_values,
        };

        vk_device.cmdBeginRenderPass(self.command_buffer, &render_pass_info, .@"inline");
        {
           vk_device.cmdBindPipeline(self.command_buffer, .graphics, self.vk_pipeline);

            const viewports = [_]vk.Viewport{.{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(extent.width),
                .height = @floatFromInt(extent.height),
                .min_depth = 0,
                .max_depth = 1,
            }};
            vk_device.cmdSetViewport(self.command_buffer, 0, viewports.len, &viewports);

            const scissors = [_]vk.Rect2D{.{
                .offset = .{ .x = 0, .y = 0 },
                .extent = extent.*,
            }};
            vk_device.cmdSetScissor(self.command_buffer, 0, scissors.len, &scissors);

            vk_device.cmdDraw(self.command_buffer, 3, 1, 0, 0);
        }
        vk_device.cmdEndRenderPass(self.command_buffer);

        try vk_device.endCommandBuffer(self.command_buffer);
    }

    

    pub fn deinit(self: *Pipeline, vk_device: *renderer.Device) void
    {
        vk_device.destroySemaphore( self.render_finished_semaphore, null);
        vk_device.destroySemaphore( self.image_available_semaphore, null);
        vk_device.destroyFence( self.in_flight_fence, null);

        vk_device.destroyCommandPool( self.command_pool, null);
        vk_device.destroyPipeline( self.vk_pipeline, null);
        vk_device.destroyPipelineLayout( self.pipeline_layout, null);
    }
};